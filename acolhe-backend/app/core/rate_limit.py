from __future__ import annotations

import time
from collections import defaultdict, deque

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, max_requests_per_minute: int) -> None:
        super().__init__(app)
        self.max_requests_per_minute = max_requests_per_minute
        self.requests: dict[str, deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next):
        client_host = request.client.host if request.client else "local"
        key = f"{client_host}:{request.url.path}"
        now = time.time()
        queue = self.requests[key]
        while queue and now - queue[0] > 60:
            queue.popleft()
        if len(queue) >= self.max_requests_per_minute:
            return JSONResponse(
                status_code=429,
                content={"detail": "Muitas requisições. Tente novamente em instantes."},
            )
        queue.append(now)
        return await call_next(request)
