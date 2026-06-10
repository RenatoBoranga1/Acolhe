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


def test_human_support_dashboards_and_realtime(client) -> None:
    initial_chat = client.post(
        "/api/v1/chat/message",
        json={
            "message": "Quero falar com uma pessoa da rede porque estou insegura para encontrar essa pessoa de novo."
        },
    )
    conversation_id = initial_chat.json()["conversation_id"]

    request_response = client.post(
        "/api/v1/support/request",
        json={
            "conversation_id": conversation_id,
            "consent_to_human_handoff": True,
            "requester_alias": "Pessoa atendida",
        },
    )
    request_id = request_response.json()["id"]

    supporter_dashboard = client.get("/api/v1/supporter/dashboard")
    assert supporter_dashboard.status_code == 200
    dashboard_payload = supporter_dashboard.json()
    assert any(item["request"]["id"] == request_id for item in dashboard_payload["queue"])
    assert "metrics" in dashboard_payload

    with client.websocket_connect("/api/v1/ws/support/user") as user_socket:
        initial_event = user_socket.receive_json()
        assert initial_event["event"] == "REQUEST_UPDATED"
        assert initial_event["payload"]["request"]["id"] == request_id

        accepted = client.post(f"/api/v1/supporter/request/{request_id}/accept")
        assert accepted.status_code == 200
        session_id = accepted.json()["id"]

        assigned_event = user_socket.receive_json()
        assert assigned_event["event"] == "SESSION_ASSIGNED"
        assert assigned_event["payload"]["id"] == session_id

    with client.websocket_connect(
        f"/api/v1/ws/support/session/{session_id}?actor=user"
    ) as session_socket:
        snapshot_event = session_socket.receive_json()
        assert snapshot_event["event"] == "SESSION_SNAPSHOT"
        assert snapshot_event["payload"]["id"] == session_id

        session_socket.send_json({"event": "typing", "is_typing": True})
        typing_event = session_socket.receive_json()
        assert typing_event["event"] == "USER_TYPING"
        assert typing_event["payload"]["is_typing"] is True


def test_supporter_message_moderation_alert_reaches_admin_views(client) -> None:
    initial_chat = client.post(
        "/api/v1/chat/message",
        json={
            "message": "Preciso registrar o que aconteceu e depois conversar com uma pessoa real."
        },
    )
    conversation_id = initial_chat.json()["conversation_id"]

    request_response = client.post(
        "/api/v1/support/request",
        json={
            "conversation_id": conversation_id,
            "consent_to_human_handoff": True,
            "requester_alias": "Pessoa atendida",
        },
    )
    request_id = request_response.json()["id"]

    accepted = client.post(f"/api/v1/supporter/request/{request_id}/accept")
    session_id = accepted.json()["id"]

    flagged_message = client.post(
        f"/api/v1/supporter/session/{session_id}/messages",
        json={"content": "Voce precisa denunciar agora."},
    )
    assert flagged_message.status_code == 200
    assert flagged_message.json()["is_flagged"] is True

    moderation_alerts = client.get("/api/v1/admin/support/moderation-alerts")
    assert moderation_alerts.status_code == 200
    alerts_payload = moderation_alerts.json()
    assert any(item["message_id"] == flagged_message.json()["id"] for item in alerts_payload)

    admin_dashboard = client.get("/api/v1/admin/support/dashboard")
    assert admin_dashboard.status_code == 200
    dashboard_payload = admin_dashboard.json()
    assert dashboard_payload["moderation_alerts"]
