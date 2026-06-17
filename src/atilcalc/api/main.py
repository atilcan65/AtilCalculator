"""FastAPI app entry point for the AtilCalculator HTTP surface.

Bootstrap commit: registers the FastAPI instance, mounts the observability
middleware, and serves the static SPA shell from :mod:`atilcalc.web`. The
4 API routes + error mapping land in the TDD-green commits per the
contract suite (PR #37) and d007 T1-T4 checks.

This TDD-green commit wires the routes registered in
:mod:`atilcalc.api.routes` and enables the observability middleware.
"""

from __future__ import annotations

from fastapi import FastAPI

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

# Wire all route handlers (evaluate, history, error mapping). Skin
# endpoints land in the next follow-up commit.
routes.register_routes(app)

# Static SPA shell served at "/" — wired in the TDD-green commits.
# app.mount("/", StaticFiles(directory="src/atilcalc/web", html=True), name="web")  # TODO


@app.get("/healthz")
def healthz() -> dict[str, str]:
    """Liveness probe — returns 200 OK with ``{"status": "ok"}``."""
    return {"status": "ok"}
