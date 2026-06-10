from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.database import get_db, session_scope
from app.modules.human_support.schemas import (
    AdminDashboardPayload,
    GenericSupportActionResponse,
    HumanChatSessionPayload,
    HumanMessageCreate,
    HumanMessagePayload,
    QueueItemPayload,
    SessionCloseRequest,
    SessionTransferRequest,
    SupportModerationAlertPayload,
    SupportRealtimeEnvelope,
    SupportReportPayload,
    SupportReportRequest,
    SupportRequestCreate,
    SupportRequestPayload,
    SupportRequestStatusPayload,
    SupporterDashboardPayload,
    SupporterGuidelinesAckResponse,
    SupporterProfilePayload,
    SupporterStatusUpdate,
    SupporterVerifyRequest,
)
from app.modules.human_support.service import HumanSupportService
from app.modules.human_support.services.realtime_service import SupportRealtimeEvents

router = APIRouter()
service = HumanSupportService()


def _user_id(session: Session, requested_user_id: str | None) -> str:
    return service.queue_service.current_user(session, requested_user_id).id


def _support_identity(
    session: Session,
    *,
    requested_user_id: str | None,
    allowed_role_types: list[str],
) -> tuple[str, str]:
    user, profile = service.profile_service.support_actor(
        session,
        requested_user_id=requested_user_id,
        allowed_role_types=allowed_role_types,
    )
    return user.id, profile.role_type


async def _publish_user_request_status(session: Session, user_id: str) -> None:
    snapshot = service.get_current_request(session, user_id=user_id)
    await service.realtime_service.publish_user_request_update(
        user_id=user_id,
        payload=snapshot.model_dump(mode="json"),
    )


async def _publish_session_snapshot(session: Session, session_id: str, user_id: str) -> None:
    snapshot = service.get_session_for_user(session, session_id=session_id, user_id=user_id)
    await service.realtime_service.publish_session_snapshot(
        session_id,
        snapshot.model_dump(mode="json"),
    )


async def _publish_supporter_dashboard(session: Session, supporter_user_id: str) -> None:
    _, role_type = _support_identity(
        session,
        requested_user_id=supporter_user_id,
        allowed_role_types=["supporter", "specialist", "admin"],
    )
    if role_type == "admin":
        await _publish_admin_dashboard(session, supporter_user_id)
        return
    dashboard = service.get_supporter_dashboard(
        session,
        supporter_user_id=supporter_user_id,
    )
    await service.realtime_service.publish_dashboard_snapshot(
        role_type=role_type,
        user_id=supporter_user_id,
        payload=dashboard.model_dump(mode="json"),
    )


async def _publish_admin_dashboard(session: Session, admin_user_id: str) -> None:
    dashboard = service.get_admin_dashboard(session, admin_user_id=admin_user_id)
    await service.realtime_service.publish_dashboard_snapshot(
        role_type="admin",
        user_id=admin_user_id,
        payload=dashboard.model_dump(mode="json"),
    )


async def _publish_all_dashboards(session: Session) -> None:
    profiles = service.profile_service.repository.list_supporter_profiles(
        session,
        role_types=["supporter", "specialist", "admin"],
    )
    for profile in profiles:
        if profile.role_type == "admin":
            await _publish_admin_dashboard(session, profile.user_id)
        else:
            await _publish_supporter_dashboard(session, profile.user_id)


async def _publish_moderation_alert_if_needed(
    session: Session,
    *,
    message_id: str,
) -> None:
    alerts = service.moderation_service.repository.list_moderation_alerts(
        session,
        status="open",
        limit=20,
    )
    alert = next((item for item in alerts if item.message_id == message_id), None)
    if alert is None:
        return
    admin_user_ids = [
        profile.user_id
        for profile in service.moderation_service.repository.list_supporter_profiles(
            session,
            role_types=["admin"],
        )
    ]
    if not admin_user_ids:
        return
    payload = service.moderation_service.build_moderation_alert_payload(alert)
    await service.realtime_service.publish_moderation_alert(
        admin_user_ids=admin_user_ids,
        payload=payload.model_dump(mode="json"),
    )


def _envelope(event: str, payload: dict) -> dict:
    return SupportRealtimeEnvelope(event=event, payload=payload).model_dump(mode="json")


@router.post("/support/request", response_model=SupportRequestPayload)
async def request_support(
    payload: SupportRequestCreate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupportRequestPayload:
    try:
        request = service.request_support(session, payload=payload, user_id=x_acolhe_user_id)
        await _publish_user_request_status(session, request.user_id)
        await _publish_all_dashboards(session)
        return request
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/support/request/current", response_model=SupportRequestStatusPayload)
def get_current_support_request(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupportRequestStatusPayload:
    return service.get_current_request(session, user_id=x_acolhe_user_id)


@router.post("/support/request/{request_id}/cancel", response_model=GenericSupportActionResponse)
async def cancel_support_request(
    request_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        response = service.cancel_request(
            session,
            request_id=request_id,
            user_id=x_acolhe_user_id,
        )
        await _publish_user_request_status(session, _user_id(session, x_acolhe_user_id))
        await _publish_all_dashboards(session)
        return response
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
async def post_support_message_as_user(
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
        user_id = _user_id(session, x_acolhe_user_id)
        await service.realtime_service.publish_message_event(
            session_id=session_id,
            actor_role="user",
            message_payload=message.model_dump(mode="json"),
        )
        await _publish_session_snapshot(session, session_id, user_id)
        await _publish_user_request_status(session, user_id)
        await _publish_all_dashboards(session)
        return message
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/support/session/{session_id}/close", response_model=GenericSupportActionResponse)
async def close_support_session_as_user(
    session_id: str,
    payload: SessionCloseRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        response = service.close_session_as_user(
            session,
            session_id=session_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
        user_id = _user_id(session, x_acolhe_user_id)
        await service.realtime_service.publish_session_closed(
            session_id=session_id,
            payload={"reason": payload.reason, "closed_by": "user"},
        )
        await _publish_user_request_status(session, user_id)
        await _publish_all_dashboards(session)
        return response
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/support/session/{session_id}/report", response_model=SupportReportPayload)
async def report_supporter(
    session_id: str,
    payload: SupportReportRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupportReportPayload:
    try:
        report = service.report_supporter(
            session,
            session_id=session_id,
            payload=payload,
            user_id=x_acolhe_user_id,
        )
        await _publish_all_dashboards(session)
        return report
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


@router.get("/supporter/dashboard", response_model=SupporterDashboardPayload)
def get_supporter_dashboard(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterDashboardPayload:
    try:
        return service.get_supporter_dashboard(
            session,
            supporter_user_id=x_acolhe_user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/supporter/guidelines/acknowledge", response_model=SupporterGuidelinesAckResponse)
async def acknowledge_supporter_guidelines(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterGuidelinesAckResponse:
    try:
        response = service.acknowledge_guidelines(
            session,
            supporter_user_id=x_acolhe_user_id,
        )
        await _publish_supporter_dashboard(
            session,
            _support_identity(
                session,
                requested_user_id=x_acolhe_user_id,
                allowed_role_types=["supporter", "specialist", "admin"],
            )[0],
        )
        await _publish_all_dashboards(session)
        return response
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/supporter/status", response_model=SupporterProfilePayload)
async def update_supporter_status(
    payload: SupporterStatusUpdate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        profile = service.update_supporter_status(
            session,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
        supporter_user_id, role_type = _support_identity(
            session,
            requested_user_id=x_acolhe_user_id,
            allowed_role_types=["supporter", "specialist", "admin"],
        )
        await service.realtime_service.publish_dashboard_snapshot(
            role_type=role_type,
            user_id=supporter_user_id,
            payload=service.get_supporter_dashboard(
                session,
                supporter_user_id=supporter_user_id,
            ).model_dump(mode="json"),
        )
        await _publish_all_dashboards(session)
        return profile
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
async def accept_support_request(
    request_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanChatSessionPayload:
    try:
        human_session = service.accept_request(
            session,
            request_id=request_id,
            supporter_user_id=x_acolhe_user_id,
        )
        await service.realtime_service.publish_session_assigned(
            session_id=human_session.id,
            user_id=human_session.user_id,
            payload=human_session.model_dump(mode="json"),
        )
        await _publish_user_request_status(session, human_session.user_id)
        await _publish_session_snapshot(session, human_session.id, human_session.user_id)
        await _publish_all_dashboards(session)
        return human_session
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
async def post_supporter_message(
    session_id: str,
    payload: HumanMessageCreate,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> HumanMessagePayload:
    try:
        message = service.post_supporter_message(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
        human_session = service.session_service.repository.get_session(session, session_id)
        if human_session is None:
            raise ValueError("Sessao nao encontrada para envio realtime.")
        await service.realtime_service.publish_message_event(
            session_id=session_id,
            actor_role=message.sender_role,
            message_payload=message.model_dump(mode="json"),
        )
        await _publish_session_snapshot(session, session_id, human_session.user_id)
        await _publish_user_request_status(session, human_session.user_id)
        if message.is_flagged:
            await _publish_moderation_alert_if_needed(session, message_id=message.id)
        await _publish_all_dashboards(session)
        return message
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/supporter/session/{session_id}/transfer", response_model=GenericSupportActionResponse)
async def transfer_support_session(
    session_id: str,
    payload: SessionTransferRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        response = service.transfer_session(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
        human_session = service.session_service.repository.get_session(session, session_id)
        if human_session is not None:
            await service.realtime_service.publish_session_transferred(
                session_id=session_id,
                payload={
                    "reason": payload.reason,
                    "target_specialty": payload.target_specialty,
                },
            )
            await _publish_user_request_status(session, human_session.user_id)
        await _publish_all_dashboards(session)
        return response
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/supporter/session/{session_id}/close", response_model=GenericSupportActionResponse)
async def close_support_session_as_supporter(
    session_id: str,
    payload: SessionCloseRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> GenericSupportActionResponse:
    try:
        response = service.close_session_as_supporter(
            session,
            session_id=session_id,
            payload=payload,
            supporter_user_id=x_acolhe_user_id,
        )
        human_session = service.session_service.repository.get_session(session, session_id)
        if human_session is not None:
            await service.realtime_service.publish_session_closed(
                session_id=session_id,
                payload={"reason": payload.reason, "closed_by": "supporter"},
            )
            await _publish_user_request_status(session, human_session.user_id)
        await _publish_all_dashboards(session)
        return response
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


@router.get("/admin/support/moderation-alerts", response_model=list[SupportModerationAlertPayload])
def get_admin_moderation_alerts(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> list[SupportModerationAlertPayload]:
    try:
        return service.list_moderation_alerts(session, admin_user_id=x_acolhe_user_id)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.get("/admin/support/dashboard", response_model=AdminDashboardPayload)
def get_admin_support_dashboard(
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> AdminDashboardPayload:
    try:
        return service.get_admin_dashboard(session, admin_user_id=x_acolhe_user_id)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc


@router.post("/admin/supporter/{profile_id}/verify", response_model=SupporterProfilePayload)
async def verify_supporter(
    profile_id: str,
    payload: SupporterVerifyRequest,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        profile = service.verify_supporter(
            session,
            profile_id=profile_id,
            payload=payload,
            admin_user_id=x_acolhe_user_id,
        )
        await _publish_all_dashboards(session)
        return profile
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/admin/supporter/{profile_id}/suspend", response_model=SupporterProfilePayload)
async def suspend_supporter(
    profile_id: str,
    session: Session = Depends(get_db),
    x_acolhe_user_id: str | None = Header(default=None, alias="X-Acolhe-User-Id"),
) -> SupporterProfilePayload:
    try:
        profile = service.verify_supporter(
            session,
            profile_id=profile_id,
            payload=SupporterVerifyRequest(
                role_type="supporter",
                specialties=[],
                verification_status="suspended",
            ),
            admin_user_id=x_acolhe_user_id,
        )
        await _publish_all_dashboards(session)
        return profile
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


async def _dashboard_snapshot_payload(
    *,
    resolved_role: str,
    resolved_user_id: str,
) -> dict:
    with session_scope() as db_session:
        if resolved_role == "admin":
            dashboard = service.get_admin_dashboard(
                db_session,
                admin_user_id=resolved_user_id,
            )
        else:
            dashboard = service.get_supporter_dashboard(
                db_session,
                supporter_user_id=resolved_user_id,
            )
    return dashboard.model_dump(mode="json")


def _apply_presence_on_connect(
    *,
    session: Session,
    resolved_user_id: str,
    resolved_role: str,
) -> None:
    if resolved_role not in {"supporter", "specialist", "admin"}:
        return
    _, profile = service.profile_service.support_actor(
        session,
        requested_user_id=resolved_user_id,
        allowed_role_types=["supporter", "specialist", "admin"],
    )
    active_count = service.profile_service.repository.count_active_sessions_for_supporter(
        session,
        profile.id,
    )
    status = "busy" if active_count > 0 else ("online" if profile.is_available else "away")
    service.realtime_service.set_presence(resolved_user_id, status)


def _apply_presence_on_disconnect(
    *,
    session: Session,
    resolved_user_id: str,
    resolved_role: str,
) -> None:
    if resolved_role not in {"supporter", "specialist", "admin"}:
        return
    if service.realtime_service.manager.count_user_connections(resolved_user_id) > 0:
        return
    _, profile = service.profile_service.support_actor(
        session,
        requested_user_id=resolved_user_id,
        allowed_role_types=["supporter", "specialist", "admin"],
    )
    status = "away" if profile.is_available else "offline"
    service.realtime_service.set_presence(resolved_user_id, status)


async def _send_initial_snapshot(
    *,
    websocket: WebSocket,
    event: str,
    payload: dict,
) -> None:
    await websocket.send_json(_envelope(event, payload))


@router.websocket("/ws/support/user")
async def support_user_websocket(
    websocket: WebSocket,
    user_id: str | None = None,
) -> None:
    with session_scope() as db_session:
        resolved_user_id = _user_id(db_session, user_id)
    connection = await service.realtime_service.connect(
        websocket=websocket,
        room=service.realtime_service.user_room(resolved_user_id),
        actor="user",
        user_id=resolved_user_id,
    )
    try:
        with session_scope() as db_session:
            snapshot = service.get_current_request(db_session, user_id=resolved_user_id)
        await _send_initial_snapshot(
            websocket=websocket,
            event=SupportRealtimeEvents.request_updated,
            payload=snapshot.model_dump(mode="json"),
        )
        while True:
            payload = await websocket.receive_json()
            if payload.get("event") == "ping":
                await websocket.send_json(_envelope("pong", {}))
    except WebSocketDisconnect:
        service.realtime_service.disconnect(connection)


@router.websocket("/ws/support/dashboard")
async def support_dashboard_websocket(
    websocket: WebSocket,
    role: str = "supporter",
    user_id: str | None = None,
) -> None:
    allowed_role_types = ["admin"] if role == "admin" else ["supporter", "specialist", "admin"]
    with session_scope() as db_session:
        resolved_user_id, resolved_role = _support_identity(
            db_session,
            requested_user_id=user_id,
            allowed_role_types=allowed_role_types,
        )
        _apply_presence_on_connect(
            session=db_session,
            resolved_user_id=resolved_user_id,
            resolved_role=resolved_role,
        )
    connection = await service.realtime_service.connect(
        websocket=websocket,
        room=service.realtime_service.dashboard_room(resolved_role, resolved_user_id),
        actor=resolved_role,
        user_id=resolved_user_id,
    )
    try:
        payload = await _dashboard_snapshot_payload(
            resolved_role=resolved_role,
            resolved_user_id=resolved_user_id,
        )
        await _send_initial_snapshot(
            websocket=websocket,
            event=SupportRealtimeEvents.dashboard_snapshot,
            payload=payload,
        )
        with session_scope() as db_session:
            await _publish_all_dashboards(db_session)
        while True:
            received = await websocket.receive_json()
            if received.get("event") == "ping":
                await websocket.send_json(_envelope("pong", {}))
    except WebSocketDisconnect:
        service.realtime_service.disconnect(connection)
        with session_scope() as db_session:
            _apply_presence_on_disconnect(
                session=db_session,
                resolved_user_id=resolved_user_id,
                resolved_role=resolved_role,
            )
            await _publish_all_dashboards(db_session)


@router.websocket("/ws/support/session/{session_id}")
async def support_session_websocket(
    websocket: WebSocket,
    session_id: str,
    actor: str = "user",
    user_id: str | None = None,
) -> None:
    is_support_actor = actor in {"supporter", "specialist", "admin"}
    with session_scope() as db_session:
        if is_support_actor:
            resolved_user_id, resolved_role = _support_identity(
                db_session,
                requested_user_id=user_id,
                allowed_role_types=["supporter", "specialist", "admin"],
            )
            _apply_presence_on_connect(
                session=db_session,
                resolved_user_id=resolved_user_id,
                resolved_role=resolved_role,
            )
        else:
            resolved_user_id = _user_id(db_session, user_id)
            resolved_role = "user"
    connection = await service.realtime_service.connect(
        websocket=websocket,
        room=service.realtime_service.session_room(session_id),
        actor=resolved_role,
        user_id=resolved_user_id,
    )
    try:
        with session_scope() as db_session:
            if is_support_actor:
                snapshot = service.get_session_for_supporter(
                    db_session,
                    session_id=session_id,
                    supporter_user_id=resolved_user_id,
                )
            else:
                snapshot = service.get_session_for_user(
                    db_session,
                    session_id=session_id,
                    user_id=resolved_user_id,
                )
        await _send_initial_snapshot(
            websocket=websocket,
            event=SupportRealtimeEvents.session_snapshot,
            payload=snapshot.model_dump(mode="json"),
        )
        while True:
            payload = await websocket.receive_json()
            event = str(payload.get("event", "")).strip().lower()
            if event == "ping":
                await websocket.send_json(_envelope("pong", {}))
                continue
            if event == "typing":
                await service.realtime_service.publish_typing(
                    session_id=session_id,
                    actor=resolved_role,
                    is_typing=bool(payload.get("is_typing", True)),
                )
                continue
            if event != "message":
                await websocket.send_json(
                    _envelope(
                        "error",
                        {"message": "Evento de websocket nao suportado."},
                    )
                )
                continue
            content = str(payload.get("content", "")).strip()
            with session_scope() as db_session:
                if is_support_actor:
                    message = service.post_supporter_message(
                        db_session,
                        session_id=session_id,
                        payload=HumanMessageCreate(content=content),
                        supporter_user_id=resolved_user_id,
                    )
                    human_session = service.session_service.repository.get_session(
                        db_session,
                        session_id,
                    )
                    if message.is_flagged:
                        await _publish_moderation_alert_if_needed(
                            db_session,
                            message_id=message.id,
                        )
                else:
                    message = service.post_user_message(
                        db_session,
                        session_id=session_id,
                        payload=HumanMessageCreate(content=content),
                        user_id=resolved_user_id,
                    )
                    human_session = service.session_service.repository.get_session(
                        db_session,
                        session_id,
                    )
                if human_session is None:
                    raise ValueError("Sessao nao encontrada para atualizar a conversa.")
                await service.realtime_service.publish_message_event(
                    session_id=session_id,
                    actor_role=message.sender_role,
                    message_payload=message.model_dump(mode="json"),
                )
                await _publish_session_snapshot(
                    db_session,
                    session_id,
                    human_session.user_id,
                )
                await _publish_user_request_status(db_session, human_session.user_id)
                await _publish_all_dashboards(db_session)
    except WebSocketDisconnect:
        service.realtime_service.disconnect(connection)
        if is_support_actor:
            with session_scope() as db_session:
                _apply_presence_on_disconnect(
                    session=db_session,
                    resolved_user_id=resolved_user_id,
                    resolved_role=resolved_role,
                )
                await _publish_all_dashboards(db_session)
    except ValueError as exc:
        await websocket.send_json(_envelope("error", {"message": str(exc)}))
        service.realtime_service.disconnect(connection)
        await websocket.close()
