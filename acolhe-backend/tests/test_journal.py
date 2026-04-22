from __future__ import annotations


def test_create_record_and_generate_summary(client) -> None:
    created = client.post(
        "/api/v1/incident-records",
        json={
            "occurred_on": "2026-04-18",
            "occurred_at": "19:30",
            "location": "Escritorio",
            "description": "Meu chefe fez comentarios insistentes, encostou sem permissao e eu me senti acuada.",
            "people_involved": ["Chefe"],
            "witnesses": ["Colega da recepcao"],
            "attachments": ["print_mensagem_01.png"],
            "observations": "Sai mais cedo e fiquei com medo de voltar sozinha.",
            "perceived_impacts": ["medo", "ansiedade"],
        },
    )
    assert created.status_code == 200
    record_id = created.json()["id"]

    summary = client.post(f"/api/v1/incident-records/{record_id}/summary")
    assert summary.status_code == 200
    data = summary.json()
    assert data["record_id"] == record_id
    assert data["label"] == "Rascunho pessoal"
    assert "Nao e documento oficial." == data["disclaimer"]
