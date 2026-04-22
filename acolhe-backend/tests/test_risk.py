from __future__ import annotations


def test_critical_risk_assessment(client) -> None:
    response = client.post(
        "/api/v1/chat/risk-assessment",
        json={"message": "Estou presa e ele esta aqui na minha porta. Quero morrer."},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["level"] == "critical"
    assert data["requires_immediate_action"] is True
