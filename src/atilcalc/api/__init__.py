"""AtilCalculator HTTP surface (STORY-003a).

Wraps the pure-Python engine (:mod:`atilcalc.engine`) with a FastAPI app
that exposes the 4 endpoints pinned by ADR-0019 §API contract:

- ``GET  /healthz``              — liveness probe
- ``POST /api/evaluate``         — evaluate an expression, return result
- ``GET  /api/history``          — last N evaluations (in-memory)
- ``GET  /api/skin``             — current skin config
- ``PUT  /api/skin``             — update skin config (idempotent)
- ``GET  /``                     — static SPA shell (web/ directory)

The engine is imported; the engine never imports from here. The
architectural invariant (ADR-0017 §engine ↔ UI separation) is preserved.
"""
