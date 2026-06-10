from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.database import get_db, session_scope
from app.modules.human_support.realtime import realtime_manager
from app.modules.human_support.schemas import (
    GenericSupportActionResponse,
    HumanChatSessionPayload,
    HumanMessageCreate,
    HumanMessagePayload,
    QueueItemPayload,
    SessionCloseRequest,
    SessionTransferRequest,
    SupportReportPayload,
    SupportReportRequest,
    SupportRequestCreate,
    SupportRequestPayload,
    SupportRequestStatusPayload,
    SupporterGuidelinesAckResponse,
    SupporterProfilePayload,
    SupporterStatusUpdate,
    SupporterVerifyRequest,
)
from app.modules.human_support.service import HumanSupportService

router = APIRouter()
service = HumanSupportService()


@router.post("/support/request", response_model=SupportRequestPayload)
def request_support(
    payload: SupportRequestCreate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupportRequestPayload:
    try:
        return service.request_support(session, payload=payload, user_id=x_acolhe_user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/support/request/current", response_model=SupportRequestStatusPayload)
def get_current_support_request(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupportRequestStatusPayload:
    return service.get_current_request(session, user_id=x_acolhe_user_id)


@router.post("/support/request/{request_id}/cancel", response_model=GenericSupportActionResponse)
def cancel_support_request(
    request_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        return service.cancel_request(
            session,
            request_id=request_id,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/support/session/{session_id}", response_model=HumanChatSessionPayload)
def get_support_session(
    session_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanChatSessionPayload:
    try:
        return service.get_session_for_user(
            session,
            session_id=session_id,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/support/session/{session_id}/messages", response_model=HumanMessagePayload)
def post_support_message_as_user(
    session_id: str,
    payload: HumanMessageCreate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanMessagePayload:
    try:
        message = service.post_user_message(
            session,
            session_id=session_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return message


@router.post("/support/session/{session_id}/close", response_model=GenericSupportActionResponse)
def close_support_session_as_user(
    session_id: str,
    payload: SessionCloseRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        return service.close_session_as_user(
            session,
            session_id=session_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/support/session/{session_id}/report", response_model=SupportReportPayload)
def report_supporter(
    session_id: str,
    payload: SupportReportRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupportReportPayload:
    try:
        return service.report_supporter(
            session,
            session_id=session_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/supporter/queue", response_model=list[QueueItemPayload])
def get_supporter_queue(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> list[QueueItemPayload]:
    try:
        return service.list_queue(session, supporter_user_id=x_acolhe_user_id)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/supporter/guidelines/acknowledge", response_model=SupporterGuidelinesAckResponse)
def acknowledge_supporter_guidelines(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterGuidelinesAckResponse:
    try:
        return service.acknowledge_guidelines(
            session,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/supporter/status", response_model=SupporterProfilePayload)
def update_supporter_status(
    payload: SupporterStatusUpdate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        return service.update_supporter_status(
            session,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/supporter/profile", response_model=SupporterProfilePayload)
def get_supporter_profile(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        return service.get_supporter_profile(
            session,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/supporter/request/{request_id}/accept", response_model=HumanChatSessionPayload)
def accept_support_request(
    request_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanChatSessionPayload:
    try:
        return service.accept_request(
            session,
            request_id=request_id,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/supporter/sessions/active", response_model=list[HumanChatSessionPayload])
def get_active_supporter_sessions(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> list[HumanChatSessionPayload]:
    try:
        return service.list_active_sessions(
            session,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.get("/supporter/session/{session_id}", response_model=HumanChatSessionPayload)
def get_supporter_session(
    session_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanChatSessionPayload:
    try:
        return service.get_session_for_supporter(
            session,
            session_id=session_id,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/supporter/session/{session_id}/messages", response_model=HumanMessagePayload)
def post_supporter_message(
    session_id: str,
    payload: HumanMessageCreate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanMessagePayload:
    try:
        return service.post_supporter_message(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/supporter/session/{session_id}/transfer", response_model=GenericSupportActionResponse)
def transfer_support_session(
    session_id: str,
    payload: SessionTransferRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        return service.transfer_session(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/supporter/session/{session_id}/close", response_model=GenericSupportActionResponse)
def close_support_session_as_supporter(
    session_id: str,
    payload: SessionCloseRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        return service.close_session_as_supporter(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/admin/support/queue", response_model=list[QueueItemPayload])
def get_admin_support_queue(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> list[QueueItemPayload]:
    try:
        return service.get_admin_queue(session, admin_user_id=x_acolhe_user_id)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.get("/admin/support/reports", response_model=list[SupportReportPayload])
def get_admin_support_reports(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> list[SupportReportPayload]:
    try:
        return service.list_reports(session, admin_user_id=x_acolhe_user_id)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/admin/supporter/{profile_id}/verify", response_model=SupporterProfilePayload)
def verify_supporter(
    profile_id: str,
    payload: SupporterVerifyRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        return service.verify_supporter(
            session,
            profile_id=profile_id,
            payload=payload,
            admin_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/admin/supporter/{profile_id}/suspend", response_model=SupporterProfilePayload)
def suspend_supporter(
    profile_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        return service.verify_supporter(
            session,
            profile_id=profile_id,
            payload=SupporterVerifyRequest(
                role_type="supporter",
                specialties=[],
                verification_status="suspended",
            ),
            admin_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.websocket("/ws/support/session/{session_id}")
async def support_session_websocket(
    websocket: WebSocket,
    session_id: str,
    actor: str = "user",
    user_id: str | None = None,
) -> None:
    await realtime_manager.connect(session_id, websocket)
    try:
        with session_scope() as db_session:
            if actor == "supporter":
                snapshot = service.get_session_for_supporter(
                    db_session,
                    session_id=session_id,
                    supporter_user_id=user_id,
                )
            else:
                snapshot = service.get_session_for_user(
                    db_session,
                    session_id=session_id,
                    user_id=user_id,
                )
        await websocket.send_json(
            {"event": "session_snapshot", "payload": snapshot.model_dump(mode="json")}
        )
        while True:
            payload = await websocket.receive_json()
            event = payload.get("event")
            if event == "typing":
                await realtime_manager.broadcast(
                    session_id,
                    {
                        "event": "typing",
                        "payload": {
                            "actor": actor,
                            "is_typing": bool(payload.get("is_typing", True)),
                        },
                    },
                )
                continue
            if event != "message":
                await websocket.send_json(
                    {
                        "event": "error",
                        "payload": {"message": "Evento de websocket nao suportado."},
                    }
                )
                continue
            content = str(payload.get("content", "")).strip()
            with session_scope() as db_session:
                if actor == "supporter":
                    message = service.post_supporter_message(
                        db_session,
                        session_id=session_id,
                        payload=HumanMessageCreate(content=content),
                        supporter_user_id=user_id,
                    )
                else:
                    message = service.post_user_message(
                        db_session,
                        session_id=session_id,
                        payload=HumanMessageCreate(content=content),
                        user_id=user_id,
                    )
            await realtime_manager.broadcast(
                session_id,
                {"event": "message", "payload": message.model_dump(mode="json")},
            )
    except WebSocketDisconnect:
        realtime_manager.disconnect(session_id, websocket)
    except ValueError as exc:
        await websocket.send_json({"event": "error", "payload": {"message": str(exc)}})
        realtime_manager.disconnect(session_id, websocket)
        await websocket.close()
