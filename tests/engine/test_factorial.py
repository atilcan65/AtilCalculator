"""TDD RED contract tests for STORY-011 factorial.

Pins AC7 from `docs/backlog/STORY-011.md` + ADR-0019 amendment 2 §Factorial cap
(170! max, 171! raises DomainError).

Run with: pytest tests/engine/test_factorial.py -v
"""

from __future__ import annotations

from decimal import Decimal

import pytest


# ---------------------------------------------------------------------------
# TC-6: factorial happy path (AC7)
# ---------------------------------------------------------------------------
class TestFactorialHappyPath:
    """n! for n in [0, 170] returns lossless Decimal."""

    def test_factorial_5_returns_120(self) -> None:
        from atilcalc.engine.evaluator import evaluate
        result = evaluate("5!")
        assert result == Decimal("120"), (
            f"AC7 violation: 5! must return Decimal('120'), got {result!r}"
        )

    def test_factorial_0_returns_1(self) -> None:
        """Base case: 0! = 1."""
        from atilcalc.engine.evaluator import evaluate
        result = evaluate("0!")
        assert result == Decimal("1"), (
            f"AC7 violation: 0! must return Decimal('1'), got {result!r}"
        )

    def test_factorial_1_returns_1(self) -> None:
        from atilcalc.engine.evaluator import evaluate
        result = evaluate("1!")
        assert result == Decimal("1"), (
            f"AC7 violation: 1! must return Decimal('1'), got {result!r}"
        )

    def test_factorial_10_returns_3628800(self) -> None:
        from atilcalc.engine.evaluator import evaluate
        result = evaluate("10!")
        assert result == Decimal("3628800"), (
            f"AC7 violation: 10! must return Decimal('3628800'), got {result!r}"
        )


# ---------------------------------------------------------------------------
# TC-7: factorial cap at 170 (ADR-0019 amendment 2 §Factorial cap)
# ---------------------------------------------------------------------------
class TestFactorialCap:
    """170! = Decimal (lossless). 171! = DomainError."""

    def test_factorial_170_returns_decimal_lossless(self) -> None:
        """170! is the IEEE-754 double boundary; must return lossless Decimal.

        Reference: 170! has 306 digits, value
        72574156153079940073595732691320735353014058904952782699891249513134265645908115987280984932579
        76320782910650139386382930033748725527711695327743709073045832057036657507617784749870056915
        3086718501487611316568677680740669454907663576034000
        """
        from atilcalc.engine.evaluator import evaluate
        result = evaluate("170!")
        assert isinstance(result, Decimal), (
            f"170! must return Decimal, got {type(result).__name__}"
        )
        # 170! is approximately 7.2574e+306. Check magnitude.
        assert Decimal("1E306") < result < Decimal("1E307"), (
            f"170! must be ~7.25E+306, got magnitude {result!r}"
        )

    def test_factorial_171_raises_domain_error(self) -> None:
        """171! overflows IEEE-754 double boundary; per ADR-0019 amendment 2
        §Factorial cap, this raises DomainError (NOT silent Infinity).
        """
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("171!")

    def test_factorial_negative_raises_domain_error(self) -> None:
        """(-1)! is undefined; per amendment 2, raises DomainError."""
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("(-1)!")

    def test_factorial_very_negative_raises_domain_error(self) -> None:
        """(-100)! is undefined; per amendment 2, raises DomainError."""
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("(-100)!")


# ---------------------------------------------------------------------------
# Adversarial probes for factorial
# ---------------------------------------------------------------------------
class TestFactorialAdversarial:
    """AP-9, AP-10, AP-11 from STORY-011-tests.md."""

    def test_ap9_very_large_factorial_raises_domain_error(self) -> None:
        """AP-9: 1000! raises DomainError (cap is 170, not 1000)."""
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("1000!")

    def test_ap11_float_factorial_raises_domain_error(self) -> None:
        """AP-11: 0.9999999999999999! (non-integer) raises DomainError.

        n must be a non-negative integer; floats near the boundary are
        ambiguous and should be rejected.
        """
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("0.9999999999999999!")

    def test_ap11_float_factorial_one_dot_five_raises_domain_error(self) -> None:
        """AP-11 variant: 1.5! (non-integer) raises DomainError."""
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("1.5!")
