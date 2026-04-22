from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.settings.schemas import ExportBundleResponse, SettingsResponse, SettingsUpdateRequest
from app.modules.settings.service import SettingsService

router = APIRouter()
service = SettingsService()


@router.get("", response_model=SettingsResponse)
def get_settings(session: Session = Depends(get_db)) -> SettingsResponse:
    return service.get(session)


@router.post("", response_model=SettingsResponse)
def update_settings(
    payload: SettingsUpdateRequest,
    session: Session = Depends(get_db),
) -> SettingsResponse:
    try:
        return service.update(session, payload)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/export", response_model=ExportBundleResponse)
def export_bundle(session: Session = Depends(get_db)) -> ExportBundleResponse:
    return service.export_bundle(session)


@router.delete("/purge")
def purge_data(session: Session = Depends(get_db)) -> dict[str, str]:
    try:
        return service.purge(session)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
