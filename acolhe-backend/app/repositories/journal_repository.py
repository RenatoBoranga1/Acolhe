from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import IncidentRecord


class JournalRepository:
    def list_records(self, session: Session, user_id: str) -> list[IncidentRecord]:
        stmt = (
            select(IncidentRecord)
            .where(IncidentRecord.user_id == user_id, IncidentRecord.is_deleted.is_(False))
            .order_by(IncidentRecord.created_at.desc())
        )
        return list(session.scalars(stmt))

    def create_record(self, session: Session, record: IncidentRecord) -> IncidentRecord:
        session.add(record)
        session.commit()
        session.refresh(record)
        return record

    def get_record(self, session: Session, record_id: str) -> IncidentRecord | None:
        return session.get(IncidentRecord, record_id)

    def save(self, session: Session, record: IncidentRecord) -> IncidentRecord:
        session.add(record)
        session.commit()
        session.refresh(record)
        return record
