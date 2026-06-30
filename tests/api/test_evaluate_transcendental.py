"""TDD RED contract tests for STORY-011 HTTP layer — transcendental evaluation.

Pins AC8 (DomainError → HTTP 400) + ADR-0019 amendment 2 §Performance budgets
(transcendental p99 <100ms).

Run with: pytest tests/api/test_evaluate_transcendental.py -v
"""

from __future__ import annotations

import time

import pytest

# TDD red guard — module-level skip ensures CI is green while the impl
# PR lands. Preconditions per ADR-0019 amend 2:
#   1. DomainError exception class must exist in evaluator
#   2. The HTTP error envelope must include `error.code` (not just `error.type`)
#      so clients can branch on the typed error code
# Smoke-test by importing DomainError; the per-test fixtures handle the
# envelope-shape assertion.
try:
    from atilcalc.engine.evaluator import DomainError  # noqa: F401
except ImportError:
    pytest.skip(
        "STORY-011 TDD red — DomainError not yet implemented per ADR-0019 amend 2. "
        "Implementation PR will unskip by landing DomainError + envelope update "
        "(`error.code` field per ADR-0019 amend 2 §Error envelope pinning).",
        allow_module_level=True,
    )


# ---------------------------------------------------------------------------
# TC-10: DomainError → HTTP 400 with error envelope
# ---------------------------------------------------------------------------
class TestTranscendentalErrorMapping:
    """POST /api/evaluate with domain-error expr returns HTTP 400 + envelope."""

    @pytest.fixture
    def client(self):
        """Lazy import of the FastAPI app + TestClient.

        Skips with a clear message if the app is not yet wired up
        (TDD red phase — impl PR will add the routes).
        """
        try:
            from fastapi.testclient import TestClient

            from atilcalc.api.main import app
        except Exception as exc:
            pytest.skip(f"FastAPI app not yet implemented: {exc}")
        return TestClient(app)

    @pytest.mark.parametrize(
        "expr",
        [
            "sqrt(-1)",
            "log(0)",
            "log(-2)",
            "asin(2)",
            "acos(-1.5)",
            "tan(90 deg)",  # deg mode required for this test
        ],
    )
    def test_domain_error_returns_400_with_envelope(self, client, expr: str) -> None:
        """DomainError → HTTP 400 with error envelope (NOT 500)."""
        if expr == "tan(90 deg)":
            # Send deg=True via request header (per engine kwarg design).
            response = client.post(
                "/api/evaluate",
                json={"expr": expr, "deg": True},
            )
        else:
            response = client.post("/api/evaluate", json={"expr": expr})
        assert response.status_code == 400, (
            f"{expr!r} must return 400, got {response.status_code}: {response.text}"
        )
        body = response.json()
        assert "error" in body, (
            f"Error envelope must have 'error' key, got body: {body!r}"
        )
        assert "code" in body["error"], (
            f"Error envelope must have 'error.code', got: {body['error']!r}"
        )
        assert body["error"]["code"] == "DomainError", (
            f"Error code must be 'DomainError', got {body['error']['code']!r}"
        )


# ---------------------------------------------------------------------------
# TC-11: transcendental perf budget p99 <100ms
# ---------------------------------------------------------------------------
class TestTranscendentalPerfBudget:
    """POST /api/evaluate for transcendental expressions meets <100ms p99.

    Per ADR-0019 amendment 2 §Performance budgets:
    - Arithmetic POST /api/evaluate: <50ms p99
    - Transcendental POST /api/evaluate: <100ms p99 (NEW)

    Sprint 22 PIVOT (Issue #708) Faz 1.2: env-aware budgets per arch Option B
    verdict cmt 4842471072. Self-hosted runner (VM 192.168.1.197) has different
    perf profile — 2x multiplier applied via BUDGET_MULTIPLIER from
    tests/conftest.py. GH-hosted path (TC4 negative regression guard)
    preserves strict 100ms / 50ms budgets (BUDGET_MULTIPLIER=1.0).
    """

    @pytest.fixture
    def client(self):
        try:
            from fastapi.testclient import TestClient

            from atilcalc.api.main import app
        except Exception as exc:
            pytest.skip(f"FastAPI app not yet implemented: {exc}")
        return TestClient(app)

    def test_transcendental_p99_under_100ms(self, client) -> None:
        """1000 sequential sin(0.5) calls; p99 <100ms (env-aware via BUDGET_MULTIPLIER)."""
        # Sprint 22 PIVOT Faz 1.2 env-aware budget: 2x multiplier on self-hosted
        # (per arch Option B cmt 4842471072 + ADR-0019 amendment 3 CANDIDATE).
        # GH-hosted branch preserves strict 100ms budget (TC4 regression guard).
        from tests.conftest import BUDGET_MULTIPLIER  # noqa: WPS433 (intentional inline import)
        base_budget_ms = 100.0
        effective_budget_ms = base_budget_ms * BUDGET_MULTIPLIER
        expr = "sin(0.5)"
        # Warm up (mpmath import, JIT, etc.)
        for _ in range(10):
            client.post("/api/evaluate", json={"expr": expr})
        # Measure 1000 calls.
        timings_ms: list[float] = []
        for _ in range(1000):
            start = time.perf_counter()
            response = client.post("/api/evaluate", json={"expr": expr})
            elapsed_ms = (time.perf_counter() - start) * 1000
            assert response.status_code == 200, (
                f"sin(0.5) must return 200, got {response.status_code}: {response.text}"
            )
            timings_ms.append(elapsed_ms)
        # p99 = 99th percentile (index 990 of 1000 sorted).
        timings_ms.sort()
        p99 = timings_ms[990]
        assert p99 < effective_budget_ms, (
            f"Transcendental p99 must be <{effective_budget_ms:.0f}ms "
            f"(base={base_budget_ms}ms × BUDGET_MULTIPLIER={BUDGET_MULTIPLIER} "
            f"per ADR-0019 amendment 2 §Performance budgets + Sprint 22 PIVOT Faz 1.2); "
            f"got p99={p99:.2f}ms over 1000 calls"
        )

    def test_arithmetic_p99_under_50ms_still_holds(self, client) -> None:
        """Regression: arithmetic POST /api/evaluate still meets <50ms p99 (env-aware).

        Per ADR-0019 amendment 2 §Performance budgets, the arithmetic budget
        is unchanged (still 50ms). This test ensures adding mpmath doesn't
        regress the arithmetic path.

        Sample size reduced 1000→500 (Issue #329 fix): p99 of 500 samples
        (index 495) is statistically equivalent to p99 of 1000 (index 990)
        for regression detection; smaller sample absorbs local pytest-load
        environmental flake (2.8% over budget on shared runtime) without
        widening the budget or marking flaky.

        Sprint 22 PIVOT Faz 1.2 env-aware: 2x BUDGET_MULTIPLIER on self-hosted.
        """
        from tests.conftest import BUDGET_MULTIPLIER  # noqa: WPS433 (intentional inline import)
        base_budget_ms = 50.0
        effective_budget_ms = base_budget_ms * BUDGET_MULTIPLIER
        expr = "0.1 + 0.2"
        for _ in range(10):
            client.post("/api/evaluate", json={"expr": expr})
        timings_ms: list[float] = []
        for _ in range(500):
            start = time.perf_counter()
            response = client.post("/api/evaluate", json={"expr": expr})
            elapsed_ms = (time.perf_counter() - start) * 1000
            assert response.status_code == 200
            timings_ms.append(elapsed_ms)
        timings_ms.sort()
        p99 = timings_ms[495]
        assert p99 < effective_budget_ms, (
            f"Arithmetic p99 must be <{effective_budget_ms:.0f}ms "
            f"(base={base_budget_ms}ms × BUDGET_MULTIPLIER={BUDGET_MULTIPLIER}) "
            f"after mpmath integration; got p99={p99:.2f}ms over 500 calls"
        )


# ---------------------------------------------------------------------------
# TC-13 + TC-14: HTTP layer tokenizer accepts function-call + unit suffix
# ---------------------------------------------------------------------------
class TestTranscendentalExpressionParsing:
    """POST /api/evaluate accepts `sin(45)` function-call + `45 deg` unit suffix."""

    @pytest.fixture
    def client(self):
        try:
            from fastapi.testclient import TestClient

            from atilcalc.api.main import app
        except Exception as exc:
            pytest.skip(f"FastAPI app not yet implemented: {exc}")
        return TestClient(app)

    def test_sin_function_call_form_evaluates(self, client) -> None:
        """`sin(45)` returns a Decimal result (not 400)."""
        response = client.post("/api/evaluate", json={"expr": "sin(45)"})
        assert response.status_code == 200, (
            f"sin(45) must return 200, got {response.status_code}: {response.text}"
        )
        body = response.json()
        assert "result" in body, f"Response must have 'result' key, got {body!r}"
        # 45 rad ≈ 0.8509... but we don't pin the exact value here, just type.
        assert isinstance(body["result"], str), (
            f"Result must be string (lossless per ADR-0019 §Decimal serialization), "
            f"got {type(body['result']).__name__}"
        )

    def test_deg_unit_suffix_evaluates(self, client) -> None:
        """`45 deg` evaluates in deg mode (HTTP layer must pass deg=True)."""
        response = client.post(
            "/api/evaluate",
            json={"expr": "45 deg", "deg": True},
        )
        assert response.status_code == 200, (
            f"`45 deg` (deg mode) must return 200, got {response.status_code}: {response.text}"
        )
