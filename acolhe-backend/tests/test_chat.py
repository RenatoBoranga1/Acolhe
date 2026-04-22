from __future__ import annotations


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
    assert "Sinto muito que voce esteja passando por isso." not in data["assistant_message"]["content"]
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
                {"role": "user", "content": "Estou com medo de encontrar essa pessoa hoje."},
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
        json={"message": "Estou com medo porque ele disse que vai me encontrar hoje e estou sozinha."},
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
        json={"message": "Nao sei se estou exagerando, ele comenta sobre meu corpo toda semana."},
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
