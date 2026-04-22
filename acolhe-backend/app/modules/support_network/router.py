from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.support_network.schemas import TrustedContactCreate, TrustedContactResponse
from app.modules.support_network.service import SupportNetworkService

router = APIRouter()
service = SupportNetworkService()


@router.get("", response_model=list[TrustedContactResponse])
def list_contacts(session: Session = Depends(get_db)) -> list[TrustedContactResponse]:
    return service.list_contacts(session)


@router.post("", response_model=TrustedContactResponse)
def create_contact(
    payload: TrustedContactCreate,
    session: Session = Depends(get_db),
) -> TrustedContactResponse:
    try:
        return service.create_contact(session, payload)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
