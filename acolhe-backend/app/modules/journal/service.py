from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import IncidentRecord, User
from app.modules.journal.schemas import IncidentRecordCreate, IncidentRecordResponse, IncidentSummaryResponse
from app.repositories.auth_repository import AuthRepository
from app.repositories.journal_repository import JournalRepository


class JournalService:
    def __init__(self) -> None:
        self.auth_repository = AuthRepository()
        self.repository = JournalRepository()

    def _current_user(self, session: Session) -> User:
        user = self.auth_repository.get_primary_user(session)
        if user is None:
            raise ValueError("Usuaria nao encontrada.")
        return user

    def _serialize(self, record: IncidentRecord) -> IncidentRecordResponse:
        return IncidentRecordResponse(
            id=record.id,
            occurred_on=record.occurred_on,
            occurred_at=record.occurred_at,
            location=record.location,
            description=record.description,
            people_involved=record.people_involved,
            witnesses=record.witnesses,
            attachments=record.attachments,
            observations=record.observations,
            perceived_impacts=record.perceived_impacts,
            chronological_summary=record.chronological_summary,
            created_at=record.created_at,
            updated_at=record.updated_at,
        )

    def list_records(self, session: Session) -> list[IncidentRecordResponse]:
        user = self._current_user(session)
        return [self._serialize(item) for item in self.repository.list_records(session, user.id)]

    def create_record(self, session: Session, payload: IncidentRecordCreate) -> IncidentRecordResponse:
        user = self._current_user(session)
        record = IncidentRecord(user_id=user.id, **payload.model_dump())
        return self._serialize(self.repository.create_record(session, record))

    def generate_summary(self, session: Session, record_id: str) -> IncidentSummaryResponse:
        record = self.repository.get_record(session, record_id)
        if record is None or record.is_deleted:
            raise ValueError("Registro nao encontrado.")

        details: list[str] = []
        if record.occurred_on:
            details.append(f"Data aproximada: {record.occurred_on.isoformat()}.")
        if record.occurred_at:
            details.append(f"Horario aproximado: {record.occurred_at}.")
        if record.location:
            details.append(f"Local: {record.location}.")
        if record.people_involved:
            details.append(f"Pessoas envolvidas: {', '.join(record.people_involved)}.")
        if record.witnesses:
            details.append(f"Testemunhas citadas: {', '.join(record.witnesses)}.")
        details.append(f"Descricao principal: {record.description.strip()}.")
        if record.perceived_impacts:
            details.append(f"Impactos percebidos: {', '.join(record.perceived_impacts)}.")
        if record.observations:
            details.append(f"Observacoes adicionais: {record.observations.strip()}.")

        summary = " ".join(details)
        record.chronological_summary = summary
        self.repository.save(session, record)
        return IncidentSummaryResponse(
            record_id=record.id,
            label="Rascunho pessoal",
            disclaimer="Nao e documento oficial.",
            summary=summary,
        )
