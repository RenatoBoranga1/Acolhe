from __future__ import annotations


def test_human_support_request_queue_and_session_flow(client) -> None:
    initial_chat = client.post(
        "/api/v1/chat/message",
        json={
            "message": "Estou com medo de encontrar essa pessoa hoje e queria falar com uma pessoa real."
        },
    )
    assert initial_chat.status_code == 200
    conversation_id = initial_chat.json()["conversation_id"]

    request_response = client.post(
        "/api/v1/support/request",
        json={
            "conversation_id": conversation_id,
            "consent_to_human_handoff": True,
            "requester_alias": "Pessoa atendida",
        },
    )
    assert request_response.status_code == 200
    request_data = request_response.json()
    assert request_data["status"] == "waiting"
    assert request_data["safe_summary"]["risk_level"] in {"moderate", "high"}
    assert request_data["priority_score"] >= 0.5

    current_response = client.get("/api/v1/support/request/current")
    assert current_response.status_code == 200
    assert current_response.json()["request"]["id"] == request_data["id"]

    queue_response = client.get("/api/v1/supporter/queue")
    assert queue_response.status_code == 200
    queue_data = queue_response.json()
    assert any(item["request"]["id"] == request_data["id"] for item in queue_data)

    session_response = client.post(
        f"/api/v1/supporter/request/{request_data['id']}/accept"
    )
    assert session_response.status_code == 200
    session_data = session_response.json()
    assert session_data["status"] == "active"
    assert session_data["safe_summary"]["summary_text"]
    session_id = session_data["id"]

    user_message = client.post(
        f"/api/v1/support/session/{session_id}/messages",
        json={"content": "Estou sozinha agora e muito nervosa."},
    )
    assert user_message.status_code == 200
    assert user_message.json()["sender_role"] == "user"

    supporter_message = client.post(
        f"/api/v1/supporter/session/{session_id}/messages",
        json={"content": "Vamos priorizar sua seguranca agora e pensar em quem pode ficar com voce."},
    )
    assert supporter_message.status_code == 200
    assert supporter_message.json()["sender_role"] in {"supporter", "specialist"}

    refreshed_session = client.get(f"/api/v1/support/session/{session_id}")
    assert refreshed_session.status_code == 200
    assert len(refreshed_session.json()["messages"]) >= 2

    report_response = client.post(
        f"/api/v1/support/session/{session_id}/report",
        json={
            "reason": "other",
            "description": "Teste de denuncia segura da sessao.",
        },
    )
    assert report_response.status_code == 200
    assert report_response.json()["status"] == "open"

    admin_reports = client.get("/api/v1/admin/support/reports")
    assert admin_reports.status_code == 200
    assert any(item["session_id"] == session_id for item in admin_reports.json())

    close_response = client.post(
        f"/api/v1/support/session/{session_id}/close",
        json={"reason": "Encerrado pela pessoa atendida"},
    )
    assert close_response.status_code == 200

    current_after_close = client.get("/api/v1/support/request/current")
    assert current_after_close.status_code == 200
    assert current_after_close.json()["request"] is None


def test_human_support_guidelines_and_status_flow(client) -> None:
    profile = client.get("/api/v1/supporter/profile")
    assert profile.status_code == 200
    assert profile.json()["role_type"] in {"supporter", "admin", "specialist"}

    acknowledge = client.post("/api/v1/supporter/guidelines/acknowledge")
    assert acknowledge.status_code == 200
    assert acknowledge.json()["accepted"] is True
    assert acknowledge.json()["profile"]["training_completed"] is True

    status = client.post(
        "/api/v1/supporter/status",
        json={"is_available": True, "max_active_sessions": 3},
    )
    assert status.status_code == 200
    data = status.json()
    assert data["is_available"] is True
    assert data["max_active_sessions"] == 3
