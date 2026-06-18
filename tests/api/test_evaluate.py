"""Contract tests for POST /api/evaluate (STORY-003a, AC4 + AC7).

Per ADR-0019, the endpoint:
- Request: ``{"expr": "<expression string>"}``
- Success: ``200 {"result": "<decimal-as-string>", "precision": 28, "elapsed_ms": int}``
- Error: ``400 {"error": {"type": <ClassName>, "message": ..., "request_id": ...}}``
- Engine roundtrip: ``0.1 + 0.2`` → ``"0.3"`` (lossless string, no float coercion).
"""

from __future__ import annotations


class TestEvaluateHappyPath:
    """TC-4: POST /api/evaluate returns the engine result."""

    def test_evaluate_simple_addition(self, client):
        resp = client.post("/api/evaluate", json={"expr": "2 + 2"})
        assert resp.status_code == 200
        body = resp.json()
        assert body["result"] == "4"
        assert body["precision"] == 28
        assert isinstance(body["elapsed_ms"], int)

    def test_evaluate_decimal_precision_0_1_plus_0_2(self, client):
        """AC7: ``0.1 + 0.2`` → ``"0.3"`` exactly, no trailing zeros lost."""
        resp = client.post("/api/evaluate", json={"expr": "0.1 + 0.2"})
        assert resp.status_code == 200
        assert resp.json()["result"] == "0.3"

    def test_evaluate_percent_hybrid(self, client):
        """AC3 (engine): ``100 + 5%`` → ``"105"`` (Windows-calc semantics)."""
        resp = client.post("/api/evaluate", json={"expr": "100 + 5%"})
        assert resp.status_code == 200
        assert resp.json()["result"] == "105"

    def test_evaluate_nested_parens(self, client):
        resp = client.post("/api/evaluate", json={"expr": "2 * (3 + 4)"})
        assert resp.status_code == 200
        assert resp.json()["result"] == "14"

    def test_evaluate_complex_expression(self, client):
        resp = client.post("/api/evaluate", json={"expr": "((1 + 2) * (3 + 4)) - 5"})
        assert resp.status_code == 200
        assert resp.json()["result"] == "16"


class TestEvaluateErrors:
    """TC-4: error envelope per ADR-0019 §Error mapping."""

    def test_evaluate_division_by_zero_returns_400(self, client):
        resp = client.post("/api/evaluate", json={"expr": "5 / 0"})
        assert resp.status_code == 400
        body = resp.json()
        assert "error" in body
        assert body["error"]["type"] == "DivisionByZeroError"
        assert "message" in body["error"]
        assert "request_id" in body["error"]

    def test_evaluate_syntax_error_returns_400(self, client):
        resp = client.post("/api/evaluate", json={"expr": "2 +"})
        assert resp.status_code == 400
        body = resp.json()
        assert body["error"]["type"] == "ExpressionSyntaxError"

    def test_evaluate_undefined_operator_returns_400(self, client):
        """Sprint 2+ operator; for 003a, must explicitly error, not silently return."""
        resp = client.post("/api/evaluate", json={"expr": "2 ^ 3"})
        assert resp.status_code == 400
        body = resp.json()
        assert body["error"]["type"] == "UndefinedOperatorError"

    def test_evaluate_missing_expr_field_returns_422(self, client):
        """FastAPI pydantic validation: malformed request body → 422 (not 400)."""
        resp = client.post("/api/evaluate", json={})
        assert resp.status_code == 422

    def test_evaluate_malformed_json_returns_422(self, client):
        resp = client.post(
            "/api/evaluate",
            content=b"not json",
            headers={"Content-Type": "application/json"},
        )
        assert resp.status_code == 422


class TestEvaluateDecimalSerialization:
    """AC7 regression pin: Decimal is serialised as a STRING, not a JSON number."""

    def test_result_is_string_not_number(self, client):
        """If the implementer serialises Decimal as a JSON number, the float
        coercion in the browser kills the AC7 guarantee. This test pins the
        contract that ``result`` is always a string.
        """
        resp = client.post("/api/evaluate", json={"expr": "0.1 + 0.2"})
        assert resp.status_code == 200
        result = resp.json()["result"]
        assert isinstance(result, str), f"result must be string, got {type(result).__name__}"

    def test_long_decimal_round_trips_exactly(self, client):
        """A 30-digit computation must not lose precision in serialisation."""
        resp = client.post("/api/evaluate", json={"expr": "1 / 3"})
        assert resp.status_code == 200
        result = resp.json()["result"]
        # All 28 digits of Decimal(prec=28) preserved
        assert len(result) >= 10, f"expected ≥10 chars, got {result!r}"
