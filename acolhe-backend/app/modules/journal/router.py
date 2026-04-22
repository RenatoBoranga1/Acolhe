from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.journal.schemas import (
    IncidentRecordCreate,
    IncidentRecordResponse,
    IncidentSummaryResponse,
)
from app.modules.journal.service import JournalService

router = APIRouter()
service = JournalService()


@router.get("", response_model=list[IncidentRecordResponse])
def list_records(session: Session = Depends(get_db)) -> list[IncidentRecordResponse]:
    return service.list_records(session)


@router.post("", response_model=IncidentRecordResponse)
def create_record(
    payload: IncidentRecordCreate,
    session: Session = Depends(get_db),
) -> IncidentRecordResponse:
    try:
        return service.create_record(session, payload)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/{record_id}/summary", response_model=IncidentSummaryResponse)
def generate_summary(record_id: str, session: Session = Depends(get_db)) -> IncidentSummaryResponse:
    try:
        return service.generate_summary(session, record_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
