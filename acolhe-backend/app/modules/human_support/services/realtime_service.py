from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime

from fastapi import WebSocket

from app.modules.human_support.realtime import (
    SupportRealtimeConnection,
    SupportRealtimeManager,
    realtime_manager,
)


class SupportRealtimeEvents:
    message_received = "MESSAGE_RECEIVED"
    message_sent = "MESSAGE_SENT"
    session_assigned = "SESSION_ASSIGNED"
    session_transferred = "SESSION_TRANSFERRED"
    session_closed = "SESSION_CLOSED"
    user_typing = "USER_TYPING"
    supporter_typing = "SUPPORTER_TYPING"
    supporter_connected = "SUPPORTER_CONNECTED"
    supporter_disconnected = "SUPPORTER_DISCONNECTED"
    queue_updated = "QUEUE_UPDATED"
    dashboard_snapshot = "DASHBOARD_SNAPSHOT"
    session_snapshot = "SESSION_SNAPSHOT"
    request_updated = "REQUEST_UPDATED"
    presence_updated = "PRESENCE_UPDATED"
    moderation_alert = "MODERATION_ALERT"
    system_notice = "SYSTEM_NOTICE"


@dataclass(slots=True)
class SupporterPresenceState:
    status: str
    updated_at: datetime


class SupportRealtimeService:
    def __init__(self, manager: SupportRealtimeManager | None = None) -> None:
        self.manager = manager or realtime_manager
        self._presence: dict[str, SupporterPresenceState] = {}
        self._typing_state: dict[str, dict[str, bool]] = defaultdict(dict)

    @staticmethod
    def session_room(session_id: str) -> str:
        return f"session:{session_id}"

    @staticmethod
    def user_room(user_id: str) -> str:
        return f"user:{user_id}"

    @staticmethod
    def dashboard_room(role_type: str, user_id: str) -> str:
        return f"dashboard:{role_type}:{user_id}"

    async def connect(
        self,
        *,
        websocket: WebSocket,
        room: str,
        actor: str,
        user_id: str | None,
    ) -> SupportRealtimeConnection:
        return await self.manager.connect(
            room=room,
            websocket=websocket,
            actor=actor,
            user_id=user_id,
        )

    def disconnect(self, connection: SupportRealtimeConnection) -> None:
        self.manager.disconnect(connection)

    def set_presence(self, user_id: str, status: str) -> SupporterPresenceState:
        state = SupporterPresenceState(status=status, updated_at=datetime.now(UTC))
        self._presence[user_id] = state
        return state

    def get_presence(self, user_id: str) -> SupporterPresenceState:
        return self._presence.get(
            user_id,
            SupporterPresenceState(status="offline", updated_at=datetime.now(UTC)),
        )

    async def publish(self, room: str, *, event: str, payload: dict) -> None:
        await self.manager.broadcast(room, {"event": event, "payload": payload})

    async def publish_session_snapshot(self, session_id: str, payload: dict) -> None:
        await self.publish(
            self.session_room(session_id),
            event=SupportRealtimeEvents.session_snapshot,
            payload=payload,
        )

    async def publish_dashboard_snapshot(
        self,
        *,
        role_type: str,
        user_id: str,
        payload: dict,
    ) -> None:
        await self.publish(
            self.dashboard_room(role_type, user_id),
            event=SupportRealtimeEvents.dashboard_snapshot,
            payload=payload,
        )

    async def publish_user_request_update(self, *, user_id: str, payload: dict) -> None:
        await self.publish(
            self.user_room(user_id),
            event=SupportRealtimeEvents.request_updated,
            payload=payload,
        )

    async def publish_session_assigned(
        self, *, session_id: str, user_id: str, payload: dict
    ) -> None:
        await self.publish(
            self.user_room(user_id),
            event=SupportRealtimeEvents.session_assigned,
            payload=payload,
        )
        await self.publish(
            self.session_room(session_id),
            event=SupportRealtimeEvents.session_assigned,
            payload=payload,
        )

    async def publish_message_event(
        self,
        *,
        session_id: str,
        actor_role: str,
        message_payload: dict,
    ) -> None:
        await self.publish(
            self.session_room(session_id),
            event=SupportRealtimeEvents.message_received,
            payload=message_payload,
        )
        await self.publish(
            self.session_room(session_id),
            event=SupportRealtimeEvents.message_sent,
            payload={"actor_role": actor_role, "message": message_payload},
        )

    async def publish_typing(
        self,
        *,
        session_id: str,
        actor: str,
        is_typing: bool,
    ) -> None:
        event = (
            SupportRealtimeEvents.supporter_typing
            if actor in {"supporter", "specialist", "admin"}
            else SupportRealtimeEvents.user_typing
        )
        self._typing_state[session_id][actor] = is_typing
        await self.publish(
            self.session_room(session_id),
            event=event,
            payload={"actor": actor, "is_typing": is_typing},
        )

    async def publish_supporter_connection(
        self,
        *,
        session_id: str | None,
        event: str,
        payload: dict,
    ) -> None:
        if session_id is not None:
            await self.publish(self.session_room(session_id), event=event, payload=payload)

    async def publish_session_closed(self, *, session_id: str, payload: dict) -> None:
        await self.publish(
            self.session_room(session_id),
            event=SupportRealtimeEvents.session_closed,
            payload=payload,
        )

    async def publish_session_transferred(
        self, *, session_id: str, payload: dict
    ) -> None:
        await self.publish(
            self.session_room(session_id),
            event=SupportRealtimeEvents.session_transferred,
            payload=payload,
        )

    async def publish_moderation_alert(
        self,
        *,
        admin_user_ids: list[str],
        payload: dict,
    ) -> None:
        for admin_user_id in admin_user_ids:
            await self.publish(
                self.dashboard_room("admin", admin_user_id),
                event=SupportRealtimeEvents.moderation_alert,
                payload=payload,
            )
