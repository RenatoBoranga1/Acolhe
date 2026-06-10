from __future__ import annotations

from collections import defaultdict

from fastapi import WebSocket


class SupportRealtimeManager:
    def __init__(self) -> None:
        self._connections: dict[str, list[WebSocket]] = defaultdict(list)

    async def connect(self, session_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections[session_id].append(websocket)

    def disconnect(self, session_id: str, websocket: WebSocket) -> None:
        connections = self._connections.get(session_id, [])
        if websocket in connections:
            connections.remove(websocket)
        if not connections and session_id in self._connections:
            del self._connections[session_id]

    async def broadcast(self, session_id: str, payload: dict) -> None:
        for connection in list(self._connections.get(session_id, [])):
            await connection.send_json(payload)


realtime_manager = SupportRealtimeManager()
