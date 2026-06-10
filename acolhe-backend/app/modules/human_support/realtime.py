from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from datetime import UTC, datetime

from fastapi import WebSocket


@dataclass(slots=True)
class SupportRealtimeConnection:
    websocket: WebSocket
    actor: str
    user_id: str | None
    room: str
    joined_at: datetime


class SupportRealtimeManager:
    def __init__(self) -> None:
        self._rooms: dict[str, list[SupportRealtimeConnection]] = defaultdict(list)

    async def connect(
        self,
        *,
        room: str,
        websocket: WebSocket,
        actor: str,
        user_id: str | None,
    ) -> SupportRealtimeConnection:
        await websocket.accept()
        connection = SupportRealtimeConnection(
            websocket=websocket,
            actor=actor,
            user_id=user_id,
            room=room,
            joined_at=datetime.now(UTC),
        )
        self._rooms[room].append(connection)
        return connection

    def disconnect(self, connection: SupportRealtimeConnection) -> None:
        room_connections = self._rooms.get(connection.room, [])
        if connection in room_connections:
            room_connections.remove(connection)
        if not room_connections and connection.room in self._rooms:
            del self._rooms[connection.room]

    def count_room_connections(self, room: str) -> int:
        return len(self._rooms.get(room, []))

    def count_user_connections(self, user_id: str | None) -> int:
        if user_id is None:
            return 0
        return sum(
            1
            for connections in self._rooms.values()
            for connection in connections
            if connection.user_id == user_id
        )

    async def broadcast(
        self,
        room: str,
        payload: dict,
        *,
        exclude: WebSocket | None = None,
    ) -> None:
        stale: list[SupportRealtimeConnection] = []
        for connection in list(self._rooms.get(room, [])):
            if exclude is not None and connection.websocket == exclude:
                continue
            try:
                await connection.websocket.send_json(payload)
            except Exception:
                stale.append(connection)
        for connection in stale:
            self.disconnect(connection)


realtime_manager = SupportRealtimeManager()
