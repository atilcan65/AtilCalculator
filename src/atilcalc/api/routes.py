"""HTTP route handlers for the AtilCalculator API surface.

Per ADR-0019 §API contract, the 4 (or 5) endpoints are:

- ``POST /api/evaluate``   — accept ``{"expr": "..."}``, return ``{"result": "..."}``
- ``GET  /api/history``    — return last N evaluations (in-memory deque)
- ``GET  /api/skin``       — return current skin config
- ``PUT  /api/skin``       — update skin config (idempotent, accepts Idempotency-Key)

Plus the engine error envelope:

- :class:`EngineError` subclasses → HTTP status mapping per ADR-0019 §Error mapping
- :class:`ExpressionSyntaxError`     → 400
- :class:`DivisionByZeroError`       → 400
- :class:`UndefinedOperatorError`    → 400
- :class:`EngineError` (catch-all)   → 500
- Pydantic :class:`ValidationError`  → 422 (FastAPI default)

The bootstrap commit leaves this module as a stub; the TDD-green
commits will fill in handlers + error mapping per the contract suite
(PR #37) + d007 T2/T3/T4 checks.
"""
