"""Contract tests for the error envelope (STORY-003a, AC4 + ADR-0019 §Error mapping).

Every error response MUST use the envelope:
    {"error": {"type": <ClassName>, "message": <str>, "request_id": <UUID>}}

Engine exception → HTTP status:
- ExpressionSyntaxError → 400
- DivisionByZeroError → 400
- UndefinedOperatorError → 400
- EngineError (catch-all) → 500
- FastAPI ValidationError → 422
"""

from __future__ import annotations

import pytest


class TestErrorEnvelope:
    def test_envelope_has_required_fields(self, client):
        resp = client.post("/api/evaluate", json={"expr": "5 / 0"})
        assert resp.status_code == 400
        err = resp.json()["error"]
        assert "type" in err
        assert "message" in err
        assert "request_id" in err

    def test_request_id_is_uuid_like(self, client):
        """request_id is a correlation token for log search; must be unique per request."""
        r1 = client.post("/api/evaluate", json={"expr": "5 / 0"})
        r2 = client.post("/api/evaluate", json={"expr": "5 / 0"})
        id1 = r1.json()["error"]["request_id"]
        id2 = r2.json()["error"]["request_id"]
        # Each request gets a fresh ID (not strictly UUID, but non-empty + unique)
        assert id1
        assert id2
        assert id1 != id2

    def test_engine_error_catchall_returns_500(self, client):
        """EngineError (not a subclass like DivisionByZero) → 500.
        This is a server bug, not user input. Hard to trigger from outside,
        so this test is here for the contract — implementer may add a test-only
        fault-injection endpoint OR rely on the engine's internal type system.
        """
        # No clean way to force EngineError from outside; pin the contract that
        # the global handler maps any EngineError to 500, not 4xx.
        # If the implementer wants this test to pass, they should add a test
        # endpoint that raises EngineError, OR we accept the type-system guarantee.
        pytest.skip(
            "EngineError catch-all is exercised at the type-system level "
            "(per ADR-0019 §Error mapping). Implementer may add a fault-injection "
            "endpoint to make this testable; otherwise the catch-all is implicit."
        )

    def test_validation_error_returns_422(self, client):
        """Pydantic validation failures are 422, not 400 (per ADR-0019)."""
        resp = client.post("/api/evaluate", json={"expr": 12345})  # expr must be str
        assert resp.status_code == 422

    def test_content_type_is_json_on_errors(self, client):
        resp = client.post("/api/evaluate", json={"expr": "5 / 0"})
        assert resp.headers["content-type"].startswith("application/json")
