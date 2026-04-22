from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.modules.auth.schemas import (
    AuthPreferencesRequest,
    AuthStatusResponse,
    PinSetupRequest,
    PinVerifyRequest,
    PinVerifyResponse,
)
from app.modules.auth.service import AuthService

router = APIRouter()
service = AuthService()


@router.get("/status", response_model=AuthStatusResponse)
def auth_status(session: Session = Depends(get_db)) -> AuthStatusResponse:
    return AuthStatusResponse(user=service.get_status(session))


@router.post("/pin/setup", response_model=AuthStatusResponse)
def setup_pin(payload: PinSetupRequest, session: Session = Depends(get_db)) -> AuthStatusResponse:
    user = service.setup_pin(session, pin=payload.pin, display_name=payload.display_name)
    return AuthStatusResponse(user=user)


@router.post("/pin/verify", response_model=PinVerifyResponse)
def verify_pin(payload: PinVerifyRequest, session: Session = Depends(get_db)) -> PinVerifyResponse:
    valid, user = service.verify(session, pin=payload.pin)
    return PinVerifyResponse(
        valid=valid,
        message="PIN validado com sucesso." if valid else "PIN invalido.",
        user=user,
    )


@router.post("/preferences", response_model=AuthStatusResponse)
def update_preferences(
    payload: AuthPreferencesRequest,
    session: Session = Depends(get_db),
) -> AuthStatusResponse:
    try:
        user = service.update_preferences(
            session,
            biometrics_enabled=payload.biometrics_enabled,
            discreet_mode=payload.discreet_mode,
            auto_lock_minutes=payload.auto_lock_minutes,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return AuthStatusResponse(user=user)
