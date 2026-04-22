from __future__ import annotations


def test_create_trusted_contact(client) -> None:
    response = client.post(
        "/api/v1/trusted-contacts",
        json={
            "name": "Paula Mendes",
            "relationship": "Amiga",
            "phone": "+55 11 97777-9900",
            "email": "paula@example.com",
            "priority": 1,
            "ready_message": "Oi, preciso do seu apoio. Passei por uma situacao dificil e gostaria de conversar com voce.",
        },
    )
    assert response.status_code == 200
    created = response.json()
    assert created["name"] == "Paula Mendes"

    listing = client.get("/api/v1/trusted-contacts")
    assert listing.status_code == 200
    assert any(item["name"] == "Paula Mendes" for item in listing.json())
