from __future__ import annotations

from app.core.database import session_scope
from app.models import User


def test_chat_message_flow(client) -> None:
    response = client.post(
        "/api/v1/chat/message",
        json={"message": "Nao sei se o que aconteceu comigo foi assedio."},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["conversation_id"]
    assert data["assistant_message"]["role"] == "assistant"
    assert data["risk"]["level"] in {"moderate", "low"}
    assert len(data["suggestions"]) >= 3
    assert (
        "Sinto muito que voce esteja passando por isso."
        not in data["assistant_message"]["content"]
    )
    assert data["response_mode"] in {
        "calm_support",
        "structured_guidance",
        "decision_support",
        "safety_first",
        "grounding_mode",
    }
    assert data["situation_type"]
    assert data["conversation_context"]["current_risk_level"] == data["risk"]["level"]
    assert isinstance(data["fallback_used"], bool)
    assert isinstance(data["validation_repaired"], bool)


def test_chat_varies_response_in_same_conversation(client) -> None:
    first_response = client.post(
        "/api/v1/chat/message",
        json={"message": "Quero registrar o que aconteceu."},
    )
    assert first_response.status_code == 200
    first_data = first_response.json()

    second_response = client.post(
        "/api/v1/chat/message",
        json={
            "conversation_id": first_data["conversation_id"],
            "message": "Quero registrar o que aconteceu.",
        },
    )
    assert second_response.status_code == 200
    second_data = second_response.json()

    first_text = first_data["assistant_message"]["content"]
    second_text = second_data["assistant_message"]["content"]

    assert first_text != second_text
    assert first_text.split(".")[0] != second_text.split(".")[0]


def test_chat_uses_recent_history_for_context(client) -> None:
    response = client.post(
        "/api/v1/chat/message",
        json={
            "message": "Nao sei o que fazer agora.",
            "history": [
                {"role": "assistant", "content": "Podemos olhar para isso com calma."},
                {
                    "role": "user",
                    "content": "Estou com medo de encontrar essa pessoa hoje.",
                },
            ],
        },
    )

    assert response.status_code == 200
    data = response.json()
    content = data["assistant_message"]["content"].lower()

    assert "segur" in content or "local seguro" in content or "proteger" in content
    assert data["response_mode"] == "safety_first"


def test_chat_high_risk_reencounter_prioritizes_safety(client) -> None:
    response = client.post(
        "/api/v1/chat/message",
        json={
            "message": "Estou com medo porque ele disse que vai me encontrar hoje e estou sozinha."
        },
    )

    assert response.status_code == 200
    data = response.json()
    content = data["assistant_message"]["content"].lower()

    assert data["risk"]["level"] == "high"
    assert data["response_mode"] == "safety_first"
    assert "segur" in content
    assert "local seguro" in content or "pessoa de confianca" in content
    assert "Ligar para emergencia" in data["ctas"]


def test_chat_reporting_ambivalence_does_not_pressure_denunciation(client) -> None:
    response = client.post(
        "/api/v1/chat/message",
        json={"message": "Quero denunciar, mas nao consigo decidir."},
    )

    assert response.status_code == 200
    data = response.json()
    content = data["assistant_message"]["content"].lower()

    assert data["situation_type"] == "reporting_ambivalence"
    assert data["response_mode"] == "decision_support"
    assert "voce deve denunciar" not in content
    assert "denuncie" not in content
    assert "pressao" in content or "opcoes" in content or "decisao" in content


def test_chat_repeated_uncertainty_responses_stay_varied(client) -> None:
    first_response = client.post(
        "/api/v1/chat/message",
        json={
            "message": "Nao sei se estou exagerando, ele comenta sobre meu corpo toda semana."
        },
    )
    assert first_response.status_code == 200
    first_data = first_response.json()

    second_response = client.post(
        "/api/v1/chat/message",
        json={
            "conversation_id": first_data["conversation_id"],
            "message": "Ainda nao sei se isso foi assedio, porque esses comentarios continuam.",
        },
    )
    assert second_response.status_code == 200
    second_data = second_response.json()

    first_text = first_data["assistant_message"]["content"]
    second_text = second_data["assistant_message"]["content"]

    assert first_text != second_text
    assert first_text.split(".")[0] != second_text.split(".")[0]
    assert second_data["situation_type"] == "harassment_uncertainty"


def test_chat_conversation_crud_and_paginated_messages(client) -> None:
    created = client.post(
        "/api/v1/chat/conversations",
        json={"title": "Conversa de teste", "discreet_mode": False},
    )
    assert created.status_code == 200
    conversation_id = created.json()["id"]

    for index in range(5):
        response = client.post(
            "/api/v1/chat/message",
            json={
                "conversation_id": conversation_id,
                "message": f"Mensagem {index} sobre o que aconteceu no trabalho.",
            },
        )
        assert response.status_code == 200

    detail = client.get(f"/api/v1/chat/conversations/{conversation_id}")
    assert detail.status_code == 200
    assert detail.json()["id"] == conversation_id

    page_one = client.get(
        f"/api/v1/chat/conversations/{conversation_id}/messages?page=1&page_size=4"
    )
    assert page_one.status_code == 200
    page_one_data = page_one.json()
    assert page_one_data["conversation_id"] == conversation_id
    assert page_one_data["page"] == 1
    assert page_one_data["page_size"] == 4
    assert len(page_one_data["items"]) == 4
    assert page_one_data["has_more"] is True

    updated = client.patch(
        f"/api/v1/chat/conversations/{conversation_id}",
        json={"title": "Conversa renomeada"},
    )
    assert updated.status_code == 200
    assert updated.json()["title"] == "Conversa renomeada"

    delete_response = client.delete(f"/api/v1/chat/conversations/{conversation_id}")
    assert delete_response.status_code == 200
    assert delete_response.json()["deleted"] is True

    missing = client.get(f"/api/v1/chat/conversations/{conversation_id}")
    assert missing.status_code == 404


def test_chat_feedback_route_stores_feedback_for_assistant_message(client) -> None:
    response = client.post(
        "/api/v1/chat/message",
        json={"message": "Quero ajuda para organizar o que aconteceu."},
    )
    assert response.status_code == 200
    assistant_message_id = response.json()["assistant_message"]["id"]

    feedback = client.post(
        f"/api/v1/chat/messages/{assistant_message_id}/feedback",
        json={
            "rating": "helpful",
            "note": "A resposta me ajudou a pensar com clareza.",
        },
    )

    assert feedback.status_code == 200
    data = feedback.json()
    assert data["message_id"] == assistant_message_id
    assert data["stored"] is True


def test_chat_conversation_isolation_by_user_header(client) -> None:
    created = client.post(
        "/api/v1/chat/conversations",
        json={"title": "Privada", "discreet_mode": False},
    )
    assert created.status_code == 200
    conversation_id = created.json()["id"]

    with session_scope() as session:
        second_user = User(
            display_name="Outra usuaria",
            hashed_pin="hash",
        )
        session.add(second_user)
        session.commit()
        session.refresh(second_user)
        second_user_id = second_user.id

    forbidden = client.get(
        f"/api/v1/chat/conversations/{conversation_id}",
        headers={"X-Acolhe-User-Id": second_user_id},
    )
    assert forbidden.status_code == 404


def test_chat_emotional_crisis_keeps_response_short_and_grounding(client) -> None:
    response = client.post(
        "/api/v1/chat/message",
        json={"message": "Estou em panico, nao consigo parar de tremer e nem pensar."},
    )

    assert response.status_code == 200
    data = response.json()
    content = data["assistant_message"]["content"].lower()

    assert data["situation_type"] == "emotional_crisis"
    assert data["response_mode"] in {"grounding_mode", "safety_first"}
    assert len(content) < 420
    assert "respir" in content or "pausa" in content or "agora" in content
