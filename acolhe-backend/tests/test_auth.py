from __future__ import annotations


def test_pin_setup_and_verify(client) -> None:
    setup = client.post(
        "/api/v1/auth/pin/setup",
        json={"pin": "1357", "display_name": "Renata"},
    )
    assert setup.status_code == 200
    assert setup.json()["user"]["display_name"] == "Renata"

    valid = client.post("/api/v1/auth/pin/verify", json={"pin": "1357"})
    assert valid.status_code == 200
    assert valid.json()["valid"] is True

    invalid = client.post("/api/v1/auth/pin/verify", json={"pin": "9999"})
    assert invalid.status_code == 200
    assert invalid.json()["valid"] is False
