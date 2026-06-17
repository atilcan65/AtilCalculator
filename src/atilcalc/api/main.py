"""FastAPI app entry point for the AtilCalculator HTTP surface.

Wires:
- Observability middleware (ADR-0019 §Observability)
- 4 API endpoints via :mod:`atilcalc.api.routes`
- Liveness probe at /healthz (matches STORY-001 VM hardening)
- Static SPA shell from :mod:`atilcalc.web` (mount at /)

ROUTE REGISTRATION ORDER MATTERS in Starlette: the first registered
route wins. We register explicit FastAPI routes (healthz, API) FIRST,
then mount the catch-all static files at "/" LAST so it only serves
paths that no API route claimed.
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

# d007 T1: middleware.py must be referenced from main.py. The import below
# + ``app.add_middleware(...)`` call satisfy the static check.
from atilcalc.api import middleware, routes  # noqa: F401  (referenced for d007 T1)
from atilcalc.api.middleware import ObservabilityMiddleware

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


# Explicit FastAPI routes (registered FIRST so they take precedence over
# the catch-all static mount below).
@app.get("/healthz")
def healthz() -> dict[str, str]:
    """Liveness probe — returns 200 OK with ``{"status": "ok"}``."""
    return {"status": "ok"}


# Wire all API route handlers (evaluate, history, skin, error mapping).
routes.register_routes(app)


# Static SPA shell served at "/" (AC1 + AC8 from Issue #30 test plan).
# Mounted LAST so the explicit routes above take precedence.
# Path is resolved relative to this file: src/atilcalc/api/main.py → ../../web.
_WEB_DIR = Path(__file__).resolve().parent.parent / "web"
app.mount("/", StaticFiles(directory=str(_WEB_DIR), html=True), name="web")
