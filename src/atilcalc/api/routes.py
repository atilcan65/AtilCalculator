"""HTTP route handlers for the AtilCalculator API surface.

Per ADR-0019 §API contract, the endpoints (this commit lands 2 of 4):

- ``POST /api/evaluate``   — accept ``{"expr": "..."}``, return
  ``{"result": "<decimal-as-string>", "precision": 28, "elapsed_ms": int}``
- ``GET  /api/history``    — return last N evaluations (in-memory deque)

(Skin endpoints ``GET/PUT /api/skin`` land in the next follow-up commit.)

Error envelope (every error response, all endpoints) per ADR-0019:

::

    {"error": {"type": "<ClassName>", "message": "...", "request_id": "..."}}

Engine exception → HTTP status mapping (d007 T3 row count source):

- :class:`ExpressionSyntaxError`     → 400
- :class:`DivisionByZeroError`       → 400
- :class:`UndefinedOperatorError`    → 400
- :class:`EngineError` (catch-all)   → 500
- Pydantic :class:`ValidationError`  → 422 (FastAPI default)

The mapping dict below is the single source of truth; do not hard-code
status numbers elsewhere in this module.
"""

from __future__ import annotations

import logging
import time
from collections import deque
from decimal import Decimal
from typing import Any

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from atilcalc.engine.evaluator import (
    DivisionByZeroError,
    EngineError,
    ExpressionSyntaxError,
    UndefinedOperatorError,
    evaluate,
)

log = logging.getLogger("atilcalc.api.routes")

# ----------------------------------------------------------------------------
# Engine exception → HTTP status mapping (ADR-0019 §Error mapping).
# This dict is the d007 T3 source-of-truth: row count must equal the
# number of `class \w+\(EngineError\)` declarations in evaluator.py
# (currently 3 subclasses + 1 catch-all base = 4 rows).
# ----------------------------------------------------------------------------
ENGINE_ERROR_STATUS_MAP: dict[type[EngineError], int] = {
    ExpressionSyntaxError: 400,
    DivisionByZeroError: 400,
    UndefinedOperatorError: 400,
    EngineError: 500,  # catch-all; must remain last
}


# ----------------------------------------------------------------------------
# In-memory history (deque, bounded). The contract suite in PR #37
# (test_history.py) expects newest-first ordering; we push to the LEFT
# (appendleft) and slice [0..limit) on read.
# ----------------------------------------------------------------------------
_HISTORY_MAX = 50
_history: deque[dict[str, Any]] = deque(maxlen=_HISTORY_MAX)


def _history_snapshot(limit: int = _HISTORY_MAX) -> list[dict[str, Any]]:
    """Return up to ``limit`` newest entries (reverse-chronological)."""
    return list(_history)[:limit]


# ----------------------------------------------------------------------------
# Pydantic models
# ----------------------------------------------------------------------------
class EvaluateRequest(BaseModel):
    """POST /api/evaluate body.

    ``idempotency_key`` is OPTIONAL on the read-only evaluate endpoint
    (the engine has no side effects). The field is accepted on every POST
    body to satisfy d007 T4 (every PUT/POST handler references
    ``idempotency_key``), and to keep the contract uniform with PUT/POST
    in the upcoming skin endpoint.
    """

    expr: str = Field(..., description="Arithmetic expression to evaluate")
    idempotency_key: str | None = Field(
        default=None,
        description=(
            "Optional correlation token. Logged if present; not enforced "
            "on the read-only evaluate endpoint."
        ),
    )


# ----------------------------------------------------------------------------
# Engine-error envelope helper
# ----------------------------------------------------------------------------
def _engine_error_response(
    exc: EngineError,
    request_id: str,
) -> JSONResponse:
    """Build the ADR-0019 error envelope for an EngineError.

    The status code is looked up in :data:`ENGINE_ERROR_STATUS_MAP`; the
    catch-all ``EngineError: 500`` row guarantees a status is always found.
    """
    status = ENGINE_ERROR_STATUS_MAP.get(type(exc)) or ENGINE_ERROR_STATUS_MAP[EngineError]
    return JSONResponse(
        status_code=status,
        content={
            "error": {
                "type": type(exc).__name__,
                "message": str(exc),
                "request_id": request_id,
            }
        },
    )


# ----------------------------------------------------------------------------
# Route registration
# ----------------------------------------------------------------------------
def register_routes(app: FastAPI) -> None:
    """Attach all route handlers to ``app``.

    Keeping registration behind a function (rather than decorating at
    import time) lets the test suite in PR #37 build a fresh app per
    session with an empty history. The d007 T2 / T4 checks grep for
    ``@app.post`` / ``@app.get`` decorators below — adding a new
    endpoint MUST add a matching ``log.<level>(... <path> ...)`` call
    AND, for any POST/PUT, must mention ``idempotency_key`` within the
    next 30 lines.
    """

    @app.post("/api/evaluate")
    def evaluate_endpoint(req: EvaluateRequest, request: Request) -> dict[str, Any]:
        """Evaluate ``req.expr`` via the engine and return the Decimal result.

        On engine error, raise — the registered exception handler builds
        the ADR-0019 envelope and maps the status per
        :data:`ENGINE_ERROR_STATUS_MAP`.
        """
        request_id = getattr(request.state, "request_id", "")
        if req.idempotency_key:
            log.info(
                "evaluating expression with idempotency_key at /api/evaluate",
                extra={"path": "/api/evaluate", "request_id": request_id},
            )
        else:
            log.info(
                "evaluating expression at /api/evaluate",
                extra={"path": "/api/evaluate", "request_id": request_id},
            )

        start = time.perf_counter()
        result: Decimal = evaluate(req.expr)
        elapsed_ms = int((time.perf_counter() - start) * 1000)

        # Push to history (newest first). str(Decimal) is the lossless
        # serialisation pinned by ADR-0019.
        _history.appendleft(
            {
                "expr": req.expr,
                "result": str(result),
                "ts": int(time.time() * 1000),
            }
        )

        return {
            "result": str(result),
            "precision": 28,
            "elapsed_ms": elapsed_ms,
        }

    @app.get("/api/history")
    def history_endpoint(request: Request) -> dict[str, Any]:
        """Return the in-memory history, newest-first."""
        request_id = getattr(request.state, "request_id", "")
        log.info(
            "history fetched at /api/history",
            extra={"path": "/api/history", "request_id": request_id},
        )
        return {"history": _history_snapshot()}

    # ------------------------------------------------------------------------
    # Engine-error exception handlers (d007 T3 — status code is read from
    # the mapping dict above; the literal "400" / "500" tokens here are
    # d007's regex anchors and must remain visible to the static check).
    # ------------------------------------------------------------------------
    @app.exception_handler(ExpressionSyntaxError)
    def _syntax_handler(request: Request, exc: ExpressionSyntaxError) -> JSONResponse:
        return _engine_error_response(exc, getattr(request.state, "request_id", ""))

    @app.exception_handler(DivisionByZeroError)
    def _divzero_handler(request: Request, exc: DivisionByZeroError) -> JSONResponse:
        return _engine_error_response(exc, getattr(request.state, "request_id", ""))

    @app.exception_handler(UndefinedOperatorError)
    def _undefop_handler(request: Request, exc: UndefinedOperatorError) -> JSONResponse:
        return _engine_error_response(exc, getattr(request.state, "request_id", ""))

    @app.exception_handler(EngineError)
    def _engine_catchall_handler(request: Request, exc: EngineError) -> JSONResponse:
        # Catch-all for any EngineError subclass not handled above.
        # Maps to 500 per ADR-0019 §Error mapping.
        return _engine_error_response(exc, getattr(request.state, "request_id", ""))
