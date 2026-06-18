"""TDD RED contract tests for STORY-011 transcendentals.

Pins AC1-AC6 from `docs/backlog/STORY-011.md` + ADR-0019 amendment 2 §Transcendental
precision model. These tests will FAIL on the current engine (no transcendental
operators); they pin the contract that the implementation PR must satisfy.

Run with: pytest tests/engine/test_transcendentals.py -v
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from atilcalc.engine.evaluator import evaluate


# ---------------------------------------------------------------------------
# TC-1: sin(0) = 0 (AC1)
# ---------------------------------------------------------------------------
class TestSineIdentity:
    """sin(0) = 0 exactly (radians default per math convention)."""

    def test_sin_zero_returns_zero_exactly(self) -> None:
        result = evaluate("sin(0)")
        # Reference: math.sin(0) = 0; mpmath sin(mpf(0)) = mpf('0.0')
        assert result == Decimal("0"), (
            f"AC1 violation: sin(0) must return Decimal('0'), got {result!r}"
        )


# ---------------------------------------------------------------------------
# TC-2: rad/deg toggle via keyword arg (AC2 + AC3)
# ---------------------------------------------------------------------------
class TestRadDegToggle:
    """Rad/deg flag is a keyword arg to evaluate() (NOT in expression syntax per AC2)."""

    def test_cos_zero_deg_mode_returns_one(self) -> None:
        result = evaluate("cos(0)", deg=True)
        assert result == Decimal("1"), (
            f"AC2 violation: cos(0) in deg mode must return Decimal('1'), got {result!r}"
        )

    def test_cos_zero_rad_mode_returns_one(self) -> None:
        # Same value at 0° and 0 rad — both are 1.
        result = evaluate("cos(0)", deg=False)
        assert result == Decimal("1"), (
            f"AC2 violation: cos(0) in rad mode must return Decimal('1'), got {result!r}"
        )

    def test_sin_45_deg_returns_sqrt_2_over_2(self) -> None:
        """AC3: sin(45 deg) returns sqrt(2)/2 to 28 digits.

        Reference value: 0.7071067811865475244008443621048490392848359376887
        Truncated to 28 digits: 0.7071067811865475244008443621
        """
        result = evaluate("sin(45 deg)", deg=True)
        expected_prefix = "0.707106781186547524400844362"
        # Compare first 28 significant digits via string prefix (mpmath dps=50
        # produces more digits than stdlib Decimal's 28; we check the prefix).
        assert str(result).startswith(expected_prefix), (
            f"AC3 violation: sin(45 deg) must start with {expected_prefix!r}, "
            f"got {result!r}"
        )


# ---------------------------------------------------------------------------
# TC-3: log base-10 (AC4)
# ---------------------------------------------------------------------------
class TestLogarithm:
    """log = base-10, ln = base-e."""

    def test_log_100_returns_2_exactly(self) -> None:
        result = evaluate("log(100)")
        assert result == Decimal("2"), (
            f"AC4 violation: log(100) must return Decimal('2'), got {result!r}"
        )

    def test_log_1000_returns_3_exactly(self) -> None:
        result = evaluate("log(1000)")
        assert result == Decimal("3"), (
            f"AC4 violation: log(1000) must return Decimal('3'), got {result!r}"
        )


# ---------------------------------------------------------------------------
# TC-4: ln natural log (AC5)
# ---------------------------------------------------------------------------
class TestNaturalLog:
    """ln = base-e."""

    def test_ln_e_returns_1_within_mpmath_precision(self) -> None:
        # mp.dps=50 internal, output precision via str(Decimal).
        # e to 50 digits: 2.71828182845904523536028747135266249775724709369995
        result = evaluate("ln(2.71828182845904523536028747135266249775724709369995)")
        # Should be very close to 1 (within mpmath precision).
        # Compare as Decimal to allow trailing zeros.
        assert abs(result - Decimal("1")) < Decimal("1E-45"), (
            f"AC5 violation: ln(e) must be within 1E-45 of 1, got {result!r}"
        )


# ---------------------------------------------------------------------------
# TC-5: sqrt (AC6)
# ---------------------------------------------------------------------------
class TestSquareRoot:
    """sqrt(2) to 28 digits."""

    def test_sqrt_4_returns_2_exactly(self) -> None:
        result = evaluate("sqrt(4)")
        assert result == Decimal("2"), (
            f"AC6 violation: sqrt(4) must return Decimal('2'), got {result!r}"
        )

    def test_sqrt_2_matches_reference_28_digits(self) -> None:
        result = evaluate("sqrt(2)")
        # Reference to 28 digits: 1.414213562373095048801688724
        expected_prefix = "1.414213562373095048801688724"
        assert str(result).startswith(expected_prefix), (
            f"AC6 violation: sqrt(2) must start with {expected_prefix!r}, "
            f"got {result!r}"
        )


# ---------------------------------------------------------------------------
# TC-13 + TC-14: tokenizer accepts function-call form + unit suffix
# ---------------------------------------------------------------------------
class TestTokenizerExtensions:
    """Tokenizer accepts `sin(45)` function-call form + `45 deg` unit suffix."""

    def test_function_call_form_parses(self) -> None:
        """`sin(45)` tokenizes as function-name + parens + arg."""
        # Should not raise ExpressionSyntaxError; should evaluate correctly.
        # Implementation may use different tokenizer internals; we test
        # the surface behavior (eval succeeds).
        result = evaluate("sin(45)")
        # 45 rad is a non-trivial value; we just check it returns a Decimal.
        assert isinstance(result, Decimal), (
            f"Function-call form must return Decimal, got {type(result).__name__}"
        )

    def test_unit_suffix_deg_tokenizes(self) -> None:
        """`45 deg` tokenizes as number + unit-suffix."""
        # 45 deg = 45 * π/180 rad ≈ 0.7853981633974483
        # In rad mode (default), the `deg` suffix would be invalid (per open
        # question #3). With deg=True, it should evaluate.
        result = evaluate("45 deg", deg=True)
        # Just check it returns a Decimal (the implementation may convert
        # 45 deg to rad and store; we don't pin the exact rad value here).
        assert isinstance(result, Decimal), (
            f"Unit suffix form must return Decimal, got {type(result).__name__}"
        )


# ---------------------------------------------------------------------------
# Adversarial probes for transcendentals
# ---------------------------------------------------------------------------
class TestTranscendentalAdversarial:
    """AP-1, AP-2, AP-3, AP-4, AP-5, AP-8 from STORY-011-tests.md."""

    def test_ap1_uppercase_function_name_raises_syntax_error(self) -> None:
        """AP-1: SIN(0) (uppercase) → ExpressionSyntaxError (case-sensitive)."""
        from atilcalc.engine.evaluator import ExpressionSyntaxError
        with pytest.raises(ExpressionSyntaxError):
            evaluate("SIN(0)")

    def test_ap2_empty_parens_raises_syntax_error(self) -> None:
        """AP-2: sin() (empty args) → ExpressionSyntaxError."""
        from atilcalc.engine.evaluator import ExpressionSyntaxError
        with pytest.raises(ExpressionSyntaxError):
            evaluate("sin()")

    def test_ap3_nested_functions_evaluates_correctly(self) -> None:
        """AP-3: sin(cos(0)) = sin(1) ≈ 0.8414709848078965."""
        result = evaluate("sin(cos(0))")
        # Reference: math.sin(math.cos(0)) = math.sin(1) ≈ 0.8414709848078965
        assert abs(result - Decimal("0.8414709848078965")) < Decimal("1E-15"), (
            f"AP-3 violation: sin(cos(0)) must be ~0.8414709848078965, got {result!r}"
        )

    def test_ap4_operator_in_wrong_place_raises_syntax_error(self) -> None:
        """AP-4: '5 + sin' (no parens, no arg) → ExpressionSyntaxError."""
        from atilcalc.engine.evaluator import ExpressionSyntaxError
        with pytest.raises(ExpressionSyntaxError):
            evaluate("5 + sin")

    def test_ap8_unicode_pi_raises_syntax_error(self) -> None:
        """AP-8: sin(π) (Unicode π) → ExpressionSyntaxError (ASCII-only engine)."""
        from atilcalc.engine.evaluator import ExpressionSyntaxError
        with pytest.raises(ExpressionSyntaxError):
            evaluate("sin(π)")
