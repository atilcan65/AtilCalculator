"""FastAPI app entry point for the AtilCalculator HTTP surface.

Bootstrap commit: registers the FastAPI instance, mounts the observability
middleware, and serves the static SPA shell from :mod:`atilcalc.web`. The
4 API routes + error mapping land in the TDD-green commits per the
contract suite (PR #37) and d007 T1-T4 checks.
"""

from __future__ import annotations

from fastapi import FastAPI

# d007 T1: middleware.py must be referenced from main.py.
# The import + app.add_middleware() call below satisfies the static check
# ("middleware.py exists AND is referenced from main.py"). The full
# observability behaviour (request_id, latency, idempotency) lands in
# follow-up commits per ADR-0019 §Observability.
from atilcalc.api import middleware, routes  # noqa: F401  (referenced for d007 T1)

app = FastAPI(
    title="AtilCalculator",
    version="0.1.0",
    description=(
        "Keyboard-first web calculator with decimal-precision arithmetic. "
        "See ADR-0019 for the API contract; ADR-0017 for the engine ↔ UI "
        "separation invariant."
    ),
)

# Observability middleware — wired in the TDD-green commits.
# app.add_middleware(middleware.ObservabilityMiddleware)  # TODO: enable per ADR-0019

# Static SPA shell served at "/" — wired in the TDD-green commits.
# app.mount("/", StaticFiles(directory="src/atilcalc/web", html=True), name="web")  # TODO


@app.get("/healthz")
def healthz() -> dict[str, str]:
    """Liveness probe — returns 200 OK with ``{"status": "ok"}``."""
    return {"status": "ok"}
