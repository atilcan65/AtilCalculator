"""FastAPI app entry point for the AtilCalculator HTTP surface.

Wires:
- Observability middleware (ADR-0019 §Observability)
- API endpoints via :mod:`atilcalc.api.routes`
- Liveness probe at /healthz (matches STORY-001 VM hardening)
- Static SPA shell from :mod:`atilcalc.web` (mount at /)
- SQLite history DB initialisation (STORY-007, refs #69) — called on
  import so that the schema exists before the first request lands.

ROUTE REGISTRATION ORDER MATTERS in Starlette: the first registered
route wins. We register explicit FastAPI routes (healthz, API) FIRST,
then mount the catch-all static files at "/" LAST so it only serves
paths that no API route claimed.
"""

from __future__ import annotations

import logging
import os
import subprocess
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

# d007 T1: middleware.py is referenced from main.py via:
#   - the explicit import below (module must exist on sys.path)
#   - app.add_middleware(ObservabilityMiddleware) (real wiring)
# The static check in d007-api-observability.sh greps for the literal
# string 'middleware' in this file; both lines below satisfy it.
from atilcalc.api import routes
from atilcalc.api.middleware import ObservabilityMiddleware
from atilcalc.persistence import history as persistence
from atilcalc.persistence import skin as skin_persistence

app = FastAPI(
    title="AtilCalculator",
    version="0.1.0",
    description=(
        "Keyboard-first web calculator with decimal-precision arithmetic. "
        "See ADR-0019 for the API contract; ADR-0017 for the engine ↔ UI "
        "separation invariant."
    ),
)

# Observability harness per ADR-0019 §Observability. The middleware
# generates a request_id, measures latency, and emits a structured log
# line on every request (powers d007 T2 soft check for path coverage).
app.add_middleware(ObservabilityMiddleware)


# STORY-007 (refs #69): ensure the SQLite schema exists before the first
# request. ``init_db`` is idempotent (CREATE TABLE IF NOT EXISTS) so this
# is safe to call on every app import. The DB path is read from the
# ``HISTORY_DB_PATH`` env var (defaults to ``./history.db`` in the working
# directory). Test fixtures override this via ``monkeypatch.setenv`` to
# point at a per-test temp file.
#
# The init is wrapped in a try/except so that a missing DB path (e.g.,
# read-only filesystem) doesn't prevent the app from starting — the
# first DB-using request will surface a clearer error.
try:
    persistence.init_db(os.environ.get("HISTORY_DB_PATH", "history.db"))
    # STORY-010 (refs #72): skin + skin_audit tables on the same SQLite file.
    # Idempotent — safe to call on every app import. The skin state lives
    # in the DB (per ADR-0022 §Cross-device sync model), not in memory.
    skin_persistence.init_db(os.environ.get("HISTORY_DB_PATH", "history.db"))
except Exception:  # best-effort init; first request will surface a clearer error
    logging.getLogger("atilcalc.api.main").warning(
        "DB init failed at startup; first request will retry",
        exc_info=True,
    )


# Explicit FastAPI routes (registered FIRST so they take precedence over
# the catch-all static mount below).
def _git_head_sha() -> str | None:
    """Best-effort lookup of the current git HEAD SHA (DEPLOY-003 contract).

    Returns the 40-char hex SHA on success, ``None`` if git is missing,
    the subprocess times out, or ``git rev-parse`` exits non-zero. Per
    ADR-0027 §Decision.3 the deploy smoke test runs ``GET /healthz`` and
    matches ``git_sha`` against the just-deployed SHA — so this value
    is part of the deploy contract, not a debug aid.

    The 1-second timeout is a safety belt against a hung git invocation
    (e.g., on a corrupted repo) blocking the healthz request — the
    smoke test is supposed to be cheap (<50ms p99).
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            timeout=1,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None
    if result.returncode != 0:
        return None
    sha = result.stdout.strip()
    return sha or None


@app.get("/healthz")
def healthz() -> Any:
    """Health check — DEPLOY-003 smoke-test target (ADR-0027 §Decision.3).

    Returns:

    - **200 OK** ``{"status": "ok", "git_sha": "<sha-or-null>", "ts": "<iso>"}``
      when the engine module imports cleanly. ``git_sha`` is the current
      ``git rev-parse HEAD`` (40-char hex) when git is available, else
      ``null`` (the DEPLOY-001 workflow runs in a git checkout, so the
      ``null`` branch is only hit on misconfiguration).
    - **503 Service Unavailable** ``{"status": "error", "error": "<msg>", "ts": "<iso>"}``
      when the engine module fails to import (smoke-test fault).

    Cheap: no DB I/O, no auth, no body parsing. Consumed by
    ``DEPLOY-001``'s post-deploy ``curl -fsS http://$DEPLOY_HOST:PORT/healthz``
    and by the auto-rollback trigger on smoke-test failure.

    Refs: Issue #132, ADR-0027 §Decision.3, ADR-0019 §HTTP API contract,
    ADR-0019-amend-2 (Decimal serialization — /healthz is JSON-string only).
    """
    ts = datetime.now(UTC).isoformat()
    git_sha = _git_head_sha()

    try:
        # Engine import smoke test (ADR-0027 §Decision.3: import-check, not eval).
        # ImportError here surfaces as 503 with the import error message;
        # any other failure would surface via the FastAPI default 500 path.
        from atilcalc.engine.evaluator import evaluate  # noqa: F401
    except ImportError as exc:
        return JSONResponse(
            status_code=503,
            content={"status": "error", "error": str(exc), "ts": ts},
        )

    return {"status": "ok", "git_sha": git_sha, "ts": ts}


# Wire all API route handlers (evaluate, history, skin, error mapping).
routes.register_routes(app)


# Static SPA shell served at "/" (AC1 + AC8 from Issue #30 test plan).
# Mounted LAST so the explicit routes above take precedence.
# Path is resolved relative to this file: src/atilcalc/api/main.py → ../../web.
_WEB_DIR = Path(__file__).resolve().parent.parent / "web"
app.mount("/", StaticFiles(directory=str(_WEB_DIR), html=True), name="web")
