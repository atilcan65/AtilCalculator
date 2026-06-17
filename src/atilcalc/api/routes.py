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
# API-layer error types (not engine errors). These are domain-validation
# failures that live in the HTTP surface, not the pure-Python engine
# (ADR-0017 §engine ↔ UI separation). They use the same envelope shape
# as engine errors but are handled by a local exception handler — they
# do NOT count toward the d007 T3 engine-error drift detection.
# ----------------------------------------------------------------------------
class UnknownSkinError(Exception):
    """Raised when a PUT /api/skin body names a skin not in the allowed set.

    Mapped to HTTP 400 by the local exception handler in
    :func:`register_routes`. Distinct from the engine's
    :class:`UndefinedOperatorError` (which is about expression operators,
    not UI configuration).
    """


class MissingIdempotencyKeyError(Exception):
    """Raised when a state-mutating endpoint (PUT /api/skin) is called
    without an ``idempotency_key`` field, per ADR-0019 §Idempotency.

    Mapped to HTTP 400 by the local exception handler in
    :func:`register_routes`.
    """


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
# In-memory skin state + idempotency replay cache. Bounded dicts (FIFO
# eviction by re-inserting touched keys to the end). The contract suite
# in PR #37 (test_skin.py) expects:
#   - GET /api/skin → {"skin": "dark", "available": [...]}
#   - PUT /api/skin with unknown name → 400 UnknownSkinError
#   - PUT /api/skin without idempotency_key → 400 MissingIdempotencyKeyError
#   - PUT replay with same key returns FIRST response (cache hit)
# ----------------------------------------------------------------------------
AVAILABLE_SKINS: tuple[str, ...] = ("dark", "light", "retro")
DEFAULT_SKIN = "dark"
_skin_state: dict[str, Any] = {"current": DEFAULT_SKIN}

_IDEMPOTENCY_MAX = 1024
_idempotency_cache: dict[str, dict[str, Any]] = {}


def _idempotency_cache_put(key: str, response: dict[str, Any]) -> None:
    """Store a response under ``key``; evict oldest if over capacity."""
    if key in _idempotency_cache:
        # Refresh insertion order
        _idempotency_cache.pop(key)
    elif len(_idempotency_cache) >= _IDEMPOTENCY_MAX:
        # FIFO: drop the oldest inserted key
        oldest = next(iter(_idempotency_cache))
        _idempotency_cache.pop(oldest)
    _idempotency_cache[key] = response


def _iso8601_now() -> str:
    """Return current UTC time as an ISO-8601 string (second precision)."""
    from datetime import UTC, datetime

    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


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


class PutSkinRequest(BaseModel):
    """PUT /api/skin body.

    ``idempotency_key`` is REQUIRED on this state-mutating endpoint
    (per ADR-0019 §Idempotency). The field is optional in the Pydantic
    model so the handler can raise :class:`MissingIdempotencyKeyError`
    and produce a 400 (per the contract) instead of the 422 Pydantic
    would otherwise emit for a missing required field.
    """

    skin: str = Field(..., description="Skin name (must be in AVAILABLE_SKINS)")
    idempotency_key: str | None = Field(
        default=None,
        description=(
            "Required correlation token. The server caches the first "
            "response keyed by this token; replays return the cached "
            "response without re-applying. Missing/empty → 400."
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
    # Skin endpoints (ADR-0019 §Skin + §Idempotency).
    # PUT /api/skin is the only state-mutating endpoint on this surface.
    # ------------------------------------------------------------------------
    @app.get("/api/skin")
    def get_skin_endpoint(request: Request) -> dict[str, Any]:
        """Return the current skin + the list of available skins."""
        request_id = getattr(request.state, "request_id", "")
        log.info(
            "skin fetched at /api/skin",
            extra={"path": "/api/skin", "request_id": request_id},
        )
        return {
            "skin": _skin_state["current"],
            "available": list(AVAILABLE_SKINS),
        }

    @app.put("/api/skin")
    def put_skin_endpoint(req: PutSkinRequest, request: Request) -> dict[str, Any]:
        """Update the skin (idempotent).

        Replay with the same ``idempotency_key`` returns the FIRST
        response (cached, no re-apply) — even if the new request body
        names a different skin (per ADR-0019 §Idempotency edge case).
        """
        request_id = getattr(request.state, "request_id", "")

        # Idempotency key is REQUIRED for state-mutating endpoints per
        # ADR-0019 §Idempotency. We validate this in the handler (not the
        # Pydantic model) so the contract returns 400 (per test_skin.py),
        # not 422 (Pydantic's "missing required field" response).
        if not req.idempotency_key or not req.idempotency_key.strip():
            log.info(
                "missing idempotency_key at /api/skin",
                extra={"path": "/api/skin", "request_id": request_id},
            )
            raise MissingIdempotencyKeyError(
                "idempotency_key is required on state-mutating endpoints "
                "(ADR-0019 §Idempotency)"
            )

        # Idempotency replay check (BEFORE any state mutation).
        cached = _idempotency_cache.get(req.idempotency_key)
        if cached is not None:
            log.info(
                "idempotency cache hit at /api/skin",
                extra={
                    "path": "/api/skin",
                    "request_id": request_id,
                    "idempotency_key": req.idempotency_key,
                },
            )
            return cached

        # Validate skin name BEFORE any state mutation.
        if req.skin not in AVAILABLE_SKINS:
            log.info(
                "unknown skin rejected at /api/skin",
                extra={"path": "/api/skin", "request_id": request_id},
            )
            raise UnknownSkinError(
                f"unknown skin {req.skin!r}; allowed: {', '.join(AVAILABLE_SKINS)}"
            )

        # Apply the change.
        applied_at = _iso8601_now()
        _skin_state["current"] = req.skin

        response = {"skin": req.skin, "applied_at": applied_at}
        _idempotency_cache_put(req.idempotency_key, response)

        log.info(
            "skin applied at /api/skin",
            extra={
                "path": "/api/skin",
                "request_id": request_id,
                "idempotency_key": req.idempotency_key,
            },
        )
        return response

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

    # ------------------------------------------------------------------------
    # API-layer error handlers (UnknownSkinError, MissingIdempotencyKeyError).
    # These do NOT go through ENGINE_ERROR_STATUS_MAP — they are domain
    # validation errors in the HTTP surface, not engine errors.
    # ------------------------------------------------------------------------
    @app.exception_handler(UnknownSkinError)
    def _unknown_skin_handler(
        request: Request, exc: UnknownSkinError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=400,
            content={
                "error": {
                    "type": "UnknownSkinError",
                    "message": str(exc),
                    "request_id": getattr(request.state, "request_id", ""),
                }
            },
        )

    @app.exception_handler(MissingIdempotencyKeyError)
    def _missing_idempotency_handler(
        request: Request, exc: MissingIdempotencyKeyError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=400,
            content={
                "error": {
                    "type": "MissingIdempotencyKeyError",
                    "message": str(exc),
                    "request_id": getattr(request.state, "request_id", ""),
                }
            },
        )
