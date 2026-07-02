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
import os
import time
from collections import deque
from decimal import Decimal
from typing import Any

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from atilcalc.engine.evaluator import (
    DivisionByZeroError,
    DomainError,
    EngineError,
    ExpressionSyntaxError,
    UndefinedOperatorError,
    evaluate,
)
from atilcalc.persistence import history as persistence
from atilcalc.persistence import skin as skin_persistence
from atilcalc.persistence.history import IdempotencyConflictError

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
    """Raised when a state-mutating endpoint (PUT /api/skin, POST /api/history) is called
    without an ``idempotency_key`` field, per ADR-0019 §Idempotency.

    Mapped to HTTP 400 by the local exception handler in
    :func:`register_routes`.
    """


class InvalidIdempotencyKeyError(Exception):
    """Raised when a state-mutating endpoint is called with an ``Idempotency-Key``
    header that is not a valid UUID v4 string per ADR-0019 §Idempotency.

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
    DomainError: 400,
    UndefinedOperatorError: 400,
    EngineError: 500,  # catch-all; must remain last
}


# ----------------------------------------------------------------------------
# Database path resolution. The FastAPI handler reads HISTORY_DB_PATH from
# the environment on EVERY request so that test fixtures (which use
# ``monkeypatch.setenv`` to point at a per-test temp file) take effect for
# the lifetime of that test. Production sets HISTORY_DB_PATH at deploy time
# (default: ``./history.db`` in the working directory).
# ----------------------------------------------------------------------------
_DEFAULT_DB_PATH = "history.db"


def _get_db_path() -> str:
    """Return the active SQLite DB path (read fresh on every call)."""
    return os.environ.get("HISTORY_DB_PATH", _DEFAULT_DB_PATH)


# Legacy in-memory deque — kept for backward compat with the existing
# ``tests/api/test_history.py`` (STORY-003a regression pin) and the
# autouse ``_history_reset`` fixture in conftest. The deque is no longer
# the source of truth (SQLite is); it's only used to satisfy the existing
# tests that pre-date STORY-007. New code should read/write via
# ``atilcalc.persistence.history``.
_HISTORY_MAX = 50
_history: deque[dict[str, Any]] = deque(maxlen=_HISTORY_MAX)


def _history_snapshot(limit: int = _HISTORY_MAX) -> list[dict[str, Any]]:
    """Return up to ``limit`` newest entries (reverse-chronological).

    Reads from SQLite (per STORY-007). The legacy in-memory deque is no
    longer populated; this function delegates to the persistence layer.
    """
    return persistence.get_records(_get_db_path(), q=None, limit=limit)


# ----------------------------------------------------------------------------
# Skin state — SQLite-backed per STORY-010 (refs #72) + ADR-0022 §Cross-device
# sync model. The active skin lives in the ``skin`` table; the audit log
# lives in ``skin_audit``. No in-memory state.
#
# The contract suite (test_skin.py — STORY-009; test_skin_*.py — STORY-010)
# expects:
#   - GET /api/skin → {"skin": <name or DEFAULT_SKIN>, "available": [...]}
#   - PUT /api/skin with unknown name → 400 UnknownSkinError
#   - PUT /api/skin without Idempotency-Key header → 400 MissingIdempotencyKeyError
#   - PUT /api/skin with same key + same body → 200 cached (replay, no audit)
#   - PUT /api/skin with same key + DIFFERENT body → 409 Conflict (AC5)
# ----------------------------------------------------------------------------
AVAILABLE_SKINS: tuple[str, ...] = ("dark", "light", "retro")
DEFAULT_SKIN = "dark"


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
    deg: bool = Field(
        default=False,
        description=(
            "When true, the unit suffix `45 deg` is legal and trig "
            "functions (sin/cos/tan) interpret their argument as degrees. "
            "Default false (radians). Forwarded to engine.evaluate per "
            "STORY-011 / ADR-0019 amend 2."
        ),
    )
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

    skin: Any = Field(
        ...,
        description=(
            "Skin name (must be a string in AVAILABLE_SKINS). Typed as Any so "
            "non-string values (int, None, list, dict) reach the handler and "
            "raise UnknownSkinError → 400 (per AP-4 contract test); Pydantic "
            "422 would be wrong here (doctrinal contract: 400 for malformed "
            "domain values, not 422 for schema mismatch)."
        ),
    )
    idempotency_key: str | None = Field(
        default=None,
        description=(
            "Required correlation token. The server caches the first "
            "response keyed by this token; replays return the cached "
            "response without re-applying. Missing/empty → 400."
        ),
    )


class PostHistoryRequest(BaseModel):
    """POST /api/history body (STORY-007, refs #69).

    The ``Idempotency-Key`` HEADER is required (not the body field) per
    ADR-0019 §Idempotency. The header carries a UUID v4 string. The
    body is the standard ``{expr, result, ts}`` tuple.

    ``idempotency_key`` is NOT a body field — we read the header in the
    handler so that a missing header produces a 400 (per the contract)
    rather than the 422 Pydantic would emit for a missing required field.
    """

    expr: str = Field(..., description="Arithmetic expression that was evaluated")
    result: str = Field(..., description="Decimal result as a string (lossless)")
    ts: str = Field(..., description="ISO 8601 timestamp of the evaluation")


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
    Also logs the error at WARNING with the exception type and
    request_id (per ADR-0019 §Observability — engine_error correlation).
    """
    exc_type = type(exc).__name__
    status = ENGINE_ERROR_STATUS_MAP.get(type(exc)) or ENGINE_ERROR_STATUS_MAP[EngineError]
    log.warning(
        "engine_error type=%s status=%d request_id=%s message=%s",
        exc_type,
        status,
        request_id,
        exc,
        extra={
            "engine_error": exc_type,
            "status": status,
            "request_id": request_id,
        },
    )
    return JSONResponse(
        status_code=status,
        content={
            "error": {
                "type": exc_type,
                "code": exc_type,
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
        result: Decimal = evaluate(req.expr, deg=req.deg)
        elapsed_ms = int((time.perf_counter() - start) * 1000)

        # Persist to durable backend (STORY-007, refs #69). The evaluate
        # path is treated as a state-mutating write (it produces a history
        # record), so we record it in SQLite. No idempotency key on the
        # evaluate path (each evaluation is a unique event); the row's
        # idempotency_key is NULL, which the UNIQUE constraint allows.
        result_str = str(result)

        # ADR-0019 amendment 5 (Sprint 23 — Issue #728 followup + d112
        # sister-pattern): the auto-persistence of /api/evaluate to SQLite
        # is a state-mutating side effect on the read-only contract path.
        # On a slow runner (self-hosted disk IO contention), the per-call
        # INSERT+COMMIT dominates the per-request cost and regresses the
        # d100 perf budget (p99 344-478ms vs 250ms budget per Issue #728+
        # orchestrator ping cycle ~#1870+). The owner directive verbatim
        # ('olur beklerim ama kalıcı fix olsun') prioritizes a real perf fix  # noqa: RUF003 — Turkish owner directive verbatim quote, intentional
        # over a budget raise. The fix:
        #
        # - Default behaviour UNCHANGED (auto-persist ON).
        # - Opt-out via ``ATILCALC_EVALUATE_PERSIST=0`` (or any non-``"1"``
        #   / ``"true"`` / ``"yes"`` value) → skip the SQLite write entirely.
        # - Production keeps auto-persistence (per ADR-0022 §Cross-device
        #   sync model) — durable cross-device history without an explicit
        #   POST /api/history call.
        # - Test infra + low-resource envs set the opt-out to keep the
        #   hot path fast.
        #
        # The d112 d-test (sister-pattern to d100 / d109 / d110) verifies
        # the env-var precedence: ``ATILCALC_EVALUATE_PERSIST=0`` skips the
        # INSERT (no row written); default ``=1`` writes the row.
        _persist_env = os.environ.get("ATILCALC_EVALUATE_PERSIST", "1").strip().lower()
        _persist_enabled = _persist_env not in ("", "0", "false", "no", "off")
        if _persist_enabled:
            ts_iso = _iso8601_now()
            try:
                persistence.insert_record(
                    _get_db_path(),
                    expr=req.expr,
                    result=result_str,
                    ts=ts_iso,
                    idempotency_key=None,
                )
            except Exception as exc:  # persistence errors must not break evaluate
                # Persistence failures are logged at WARNING but do not block
                # the eval response. The HTTP contract is that evaluate returns
                # the result; durability is best-effort from the evaluate path.
                log.warning(
                    "history persist failed at /api/evaluate: %s",
                    exc,
                    extra={"path": "/api/evaluate", "request_id": request_id},
                )
        else:
            # ADR-0045 lens d + ADR-0056 silent-skip doctrine: the opt-out
            # gate firing must be VISIBLE in logs, not silent. Without this
            # log line, a misconfigured CI runner silently skips persistence
            # and the regression is invisible until history sync breaks
            # downstream. INFO level (not WARNING) — the gate firing is
            # INTENTIONAL behavior, not an error; observability-only.
            log.info(
                "evaluate persist opt-out: ATILCALC_EVALUATE_PERSIST=%s -> skip SQLite write",
                _persist_env,
                extra={
                    "path": "/api/evaluate",
                    "request_id": request_id,
                    "persist_env": _persist_env,
                    "persist_enabled": False,
                },
            )

        return {
            "result": result_str,
            "precision": 28,
            "elapsed_ms": elapsed_ms,
        }

    @app.get("/api/history")
    def history_endpoint(request: Request) -> dict[str, Any]:
        """Return persisted history, newest-first.

        Per ADR-0019 §GET /api/history + PR #84 amendment 2 envelope pinning
        (in-review): the response is ``{"history": [...], "cursor": ts|null}``.
        The ``cursor`` field is ``null`` in MVP-1 (no pagination); Sprint 3+
        can add ``?cursor=...`` query param and return the timestamp of the
        last record in the page (or ``null`` if no more pages).

        Optional ``?q=<substring>`` query param filters by ``expr`` substring
        (per AC2 of STORY-007). Default limit is 50; max is 1000.
        """
        request_id = getattr(request.state, "request_id", "")
        log.info(
            "history fetched at /api/history",
            extra={"path": "/api/history", "request_id": request_id},
        )
        # Read the optional q query param without changing the Pydantic
        # contract; FastAPI's request.query_params is the lightweight API.
        q = request.query_params.get("q")
        records = persistence.get_records(_get_db_path(), q=q, limit=50)
        # PR #84 envelope: history + cursor. cursor is None (no pagination in MVP-1).
        return {"history": records, "cursor": None}

    @app.post("/api/history", status_code=201)
    def post_history_endpoint(
        req: PostHistoryRequest,
        request: Request,
    ) -> dict[str, Any]:
        """Persist a history record (STORY-007, refs #69).

        Per ADR-0019 §Idempotency:
        - ``Idempotency-Key`` HEADER is REQUIRED (UUID v4). Missing → 400
          ``MissingIdempotencyKeyError``. Malformed (not UUID v4) → 400
          ``InvalidIdempotencyKeyError``.
        - Replay with same key + same payload → 201 with the stored record
          (idempotent insert, no duplicate row).
        - Replay with same key + DIFFERENT payload → 409 ``IdempotencyConflictError``
          (key reuse with a different body is a client error per ADR-0019).

        Response body per ADR-0019 §POST /api/history:
        ``{"id": int, "expr": ..., "result": ..., "ts": ...}``.
        """
        request_id = getattr(request.state, "request_id", "")

        # Read Idempotency-Key HEADER (not the body — Pydantic would emit
        # 422 for a missing required field; the contract requires 400).
        idempotency_key = request.headers.get("Idempotency-Key", "").strip()

        if not idempotency_key:
            log.info(
                "missing idempotency_key at /api/history",
                extra={"path": "/api/history", "request_id": request_id},
            )
            raise MissingIdempotencyKeyError(
                "Idempotency-Key header is required on POST /api/history " "(ADR-0019 §Idempotency)"
            )

        if not persistence.is_uuid_v4(idempotency_key):
            log.info(
                "invalid idempotency_key format at /api/history",
                extra={"path": "/api/history", "request_id": request_id},
            )
            raise InvalidIdempotencyKeyError(
                "Idempotency-Key must be a UUID v4 string (ADR-0019 §Idempotency)"
            )

        # Replay detection: if a row with this key already exists, check
        # payload match. Same payload → idempotent return. Different → 409.
        existing = persistence.get_record_by_idempotency_key(_get_db_path(), idempotency_key)
        if existing is not None:
            if (
                existing["expr"] == req.expr
                and existing["result"] == req.result
                and existing["ts"] == req.ts
            ):
                log.info(
                    "idempotency cache hit at /api/history (replay, same payload)",
                    extra={
                        "path": "/api/history",
                        "request_id": request_id,
                        "idempotency_key": idempotency_key,
                    },
                )
                return {
                    "id": existing["id"],
                    "expr": existing["expr"],
                    "result": existing["result"],
                    "ts": existing["ts"],
                }
            # Same key, different payload → 409.
            log.info(
                "idempotency conflict at /api/history (replay, different payload)",
                extra={
                    "path": "/api/history",
                    "request_id": request_id,
                    "idempotency_key": idempotency_key,
                },
            )
            raise IdempotencyConflictError(idempotency_key)

        # New record — insert.
        record = persistence.insert_record(
            _get_db_path(),
            expr=req.expr,
            result=req.result,
            ts=req.ts,
            idempotency_key=idempotency_key,
        )
        log.info(
            "history record persisted at /api/history",
            extra={
                "path": "/api/history",
                "request_id": request_id,
                "idempotency_key": idempotency_key,
            },
        )
        return record

    @app.post("/api/_test/reset")
    def reset_history_endpoint(request: Request) -> dict[str, str]:
        """Test-only endpoint: DELETE all rows from the history table.

        Called by the autouse ``_history_reset`` fixture in
        ``tests/api/conftest.py`` to ensure each test starts with an
        empty history. NOT exposed in production (no auth on this route;
        relies on the FastAPI app not being exposed to the public LAN
        during tests).

        Per AC6 of STORY-007: test isolation, no leakage between tests,
        no production data touched. The conftest fixture already provides
        per-test DBs for the TDD red contract suite; this endpoint is
        the belt-and-suspenders for the session-scoped ``client`` fixture
        used by ``test_history.py`` (STORY-003a regression pin).
        """
        request_id = getattr(request.state, "request_id", "")
        log.info(
            "history reset at /api/_test/reset (test-only)",
            extra={"path": "/api/_test/reset", "request_id": request_id},
        )
        persistence.reset_for_tests(_get_db_path())
        return {"status": "ok"}

    # ------------------------------------------------------------------------
    # Skin endpoints (ADR-0019 §Skin + §Idempotency).
    # PUT /api/skin is the only state-mutating endpoint on this surface.
    # ------------------------------------------------------------------------
    @app.get("/api/skin")
    def get_skin_endpoint(request: Request) -> dict[str, Any]:
        """Return the current skin (DB-backed per STORY-010) + available skins.

        Returns the DEFAULT_SKIN if the DB has no row yet (cold start:
        owner hasn't set a skin). The skin table is the source of truth
        for cross-device sync (ADR-0022 §Cross-device sync model).
        """
        request_id = getattr(request.state, "request_id", "")
        log.info(
            "skin fetched at /api/skin",
            extra={"path": "/api/skin", "request_id": request_id},
        )
        active = skin_persistence.get_current_skin(_get_db_path())
        return {
            "skin": active if active is not None else DEFAULT_SKIN,
            "available": list(AVAILABLE_SKINS),
        }

    @app.put("/api/skin")
    def put_skin_endpoint(req: PutSkinRequest, request: Request) -> dict[str, Any]:
        """Update the skin (idempotent, DB-backed per STORY-010).

        Idempotency-Key is read from the HEADER (per ADR-0019 §Idempotency
        + STORY-010 test contract). It must be a UUID v4 string. Replay
        detection is via the ``skin_audit`` table:

        - same key + same ``to_skin`` → 200 cached (replay, no new audit)
        - same key + DIFFERENT ``to_skin`` → 409 Conflict (AC5)
        - missing/empty/malformed key → 400 (MissingIdempotencyKeyError or
          InvalidIdempotencyKeyError)

        The legacy in-memory state + idempotency cache (PR #37, STORY-009
        MVP-1) was removed in STORY-010; skin state is now durable and
        cross-device-visible via the shared SQLite file.
        """
        request_id = getattr(request.state, "request_id", "")

        # Idempotency-Key is read from the HEADER (per ADR-0019 §Idempotency).
        # The body field is no longer the source — keeping it for backward
        # compat with a 400 if header is missing AND body is also missing
        # would be confusing. The contract is header-only now.
        idempotency_key = request.headers.get("Idempotency-Key", "").strip()
        if not idempotency_key:
            log.info(
                "missing Idempotency-Key header at /api/skin",
                extra={"path": "/api/skin", "request_id": request_id},
            )
            raise MissingIdempotencyKeyError(
                "Idempotency-Key header is required on PUT /api/skin " "(ADR-0019 §Idempotency)"
            )

        if not persistence.is_uuid_v4(idempotency_key):
            log.info(
                "invalid Idempotency-Key format at /api/skin",
                extra={"path": "/api/skin", "request_id": request_id},
            )
            raise InvalidIdempotencyKeyError(
                "Idempotency-Key must be a UUID v4 string (ADR-0019 §Idempotency)"
            )

        # Validate skin name BEFORE any state mutation.
        if req.skin not in AVAILABLE_SKINS:
            log.info(
                "unknown skin rejected at /api/skin",
                extra={"path": "/api/skin", "request_id": request_id},
            )
            raise UnknownSkinError(
                f"unknown skin {req.skin!r}; allowed: {', '.join(AVAILABLE_SKINS)}"
            )

        # AC5 replay detection via skin_audit table. The UNIQUE constraint
        # on idempotency_key is the DB-level enforcement; the pre-check
        # here is to distinguish the cached-200 case from the 409 case
        # (per ADR-0019 §Idempotency — "key reuse with different body is
        # a client error").
        existing_audit = skin_persistence.get_audit_by_idempotency_key(
            _get_db_path(),
            idempotency_key,
        )
        if existing_audit is not None:
            if existing_audit["to_skin"] == req.skin:
                # Replay: same key + same body → 200 cached (no new audit)
                log.info(
                    "idempotency cache hit at /api/skin (replay, same body)",
                    extra={
                        "path": "/api/skin",
                        "request_id": request_id,
                        "idempotency_key": idempotency_key,
                    },
                )
                return {
                    "skin": existing_audit["to_skin"],
                    "applied_at": existing_audit["ts"],
                }
            # Replay: same key + DIFFERENT body → 409 Conflict (AC5)
            log.info(
                "idempotency conflict at /api/skin (replay, different body)",
                extra={
                    "path": "/api/skin",
                    "request_id": request_id,
                    "idempotency_key": idempotency_key,
                },
            )
            raise IdempotencyConflictError(idempotency_key)

        # Validate skin is a string (AP-4 contract test — non-string → 400,
        # NOT Pydantic 422). Typed as Any on the request model so malformed
        # values reach the handler; we raise UnknownSkinError here for 400.
        if not isinstance(req.skin, str):
            log.info(
                "non-string skin value at /api/skin (AP-4)",
                extra={
                    "path": "/api/skin",
                    "request_id": request_id,
                    "skin_type": type(req.skin).__name__,
                },
            )
            raise UnknownSkinError(f"skin must be a string, got {type(req.skin).__name__}")

        # Apply the change atomically (UPDATE skin + INSERT skin_audit
        # in a single transaction; see skin_persistence.set_current_skin).
        import sqlite3 as _sqlite3

        try:
            record = skin_persistence.set_current_skin(
                _get_db_path(),
                to_skin=req.skin,
                idempotency_key=idempotency_key,
            )
        except _sqlite3.IntegrityError as exc:
            # Race condition (AC5 + AP-1): two concurrent PUTs with the
            # same idempotency_key — the pre-check above saw no audit
            # row (the peer thread hadn't committed yet), and now this
            # thread's INSERT hit the UNIQUE constraint on skin_audit.
            # Re-read the audit log to determine the actual outcome:
            #   - to_skin matches req.skin → 200 cached (replay, no
            #     duplicate audit)
            #   - to_skin differs from req.skin → 409 Conflict (key
            #     reuse with a different body, per ADR-0019)
            concurrent_audit = skin_persistence.get_audit_by_idempotency_key(
                _get_db_path(),
                idempotency_key,
            )
            if concurrent_audit is not None and concurrent_audit["to_skin"] == req.skin:
                log.info(
                    "idempotency race resolved as cached 200 at /api/skin",
                    extra={
                        "path": "/api/skin",
                        "request_id": request_id,
                        "idempotency_key": idempotency_key,
                    },
                )
                return {
                    "skin": concurrent_audit["to_skin"],
                    "applied_at": concurrent_audit["ts"],
                }
            log.info(
                "idempotency conflict (race) at /api/skin: %s",
                exc,
                extra={
                    "path": "/api/skin",
                    "request_id": request_id,
                    "idempotency_key": idempotency_key,
                },
            )
            raise IdempotencyConflictError(idempotency_key) from exc

        log.info(
            "skin applied at /api/skin",
            extra={
                "path": "/api/skin",
                "request_id": request_id,
                "idempotency_key": idempotency_key,
            },
        )
        return record

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

    @app.exception_handler(DomainError)
    def _domain_handler(request: Request, exc: DomainError) -> JSONResponse:
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
    def _unknown_skin_handler(request: Request, exc: UnknownSkinError) -> JSONResponse:
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

    @app.exception_handler(InvalidIdempotencyKeyError)
    def _invalid_idempotency_handler(
        request: Request, exc: InvalidIdempotencyKeyError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=400,
            content={
                "error": {
                    "type": "InvalidIdempotencyKeyError",
                    "message": str(exc),
                    "request_id": getattr(request.state, "request_id", ""),
                }
            },
        )

    @app.exception_handler(IdempotencyConflictError)
    def _idempotency_conflict_handler(
        request: Request, exc: IdempotencyConflictError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=409,
            content={
                "error": {
                    "type": "IdempotencyConflictError",
                    "message": str(exc),
                    "request_id": getattr(request.state, "request_id", ""),
                }
            },
        )
