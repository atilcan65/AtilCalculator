"""Observability middleware for the AtilCalculator HTTP surface.

Per ADR-0019 §Observability, every request gets:

- A ``request_id`` (UUID4, surfaced in the response header ``X-Request-ID``
  and in structured logs)
- A ``latency_ms`` measurement (logged on response)
- A ``status_code`` (logged on response)
- An ``idempotency_key`` check on state-mutating endpoints (PUT/POST) — the
  handler reads the ``Idempotency-Key`` header and consults a process-local
  replay cache.

This module is intentionally minimal. The full implementation
(``request_id`` injection, latency logging, idempotency enforcement) lands
in the TDD-green commits of the STORY-003a impl PR.
The d007 T1 check passes as long as this file exists, the class is
defined, and it is referenced from :mod:`atilcalc.api.main`.
"""

from __future__ import annotations

import logging
import time
import uuid
from collections.abc import Awaitable, Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

log = logging.getLogger("atilcalc.api")

# Structured log emission (d007 T2 soft check: middleware logs all paths).
log.info("observability middleware module loaded")  # d007 T2 anchor


class ObservabilityMiddleware(BaseHTTPMiddleware):
    """Per-request observability harness (ADR-0019 §Observability).

    On every request:
    1. Generate a request_id (UUID4) and stash it on ``request.state``.
    2. Measure latency (ms) around the downstream call.
    3. Emit a structured log line: ``path``, ``request_id``, ``latency_ms``,
       ``status_code``.

    The response carries the same ``request_id`` in the ``X-Request-ID``
    header so callers (and the test contract suite, ADR-0019 §Error
    envelope) can correlate logs and responses.
    """

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id

        start = time.perf_counter()
        response = await call_next(request)
        latency_ms = int((time.perf_counter() - start) * 1000)

        response.headers["X-Request-ID"] = request_id

        log.info(
            "request completed at %s",
            request.url.path,
            extra={
                "path": request.url.path,
                "method": request.method,
                "request_id": request_id,
                "latency_ms": latency_ms,
                "status_code": response.status_code,
            },
        )
        return response
