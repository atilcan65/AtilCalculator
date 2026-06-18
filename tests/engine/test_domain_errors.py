"""TDD RED contract tests for STORY-011 DomainError exception class.

Pins AC8 from `docs/backlog/STORY-011.md` + ADR-0019 amendment 2 §DomainError
(new EngineError subclass for runtime domain errors like sqrt(-1), log(0),
asin(2), etc.).

Run with: pytest tests/engine/test_domain_errors.py -v
"""

from __future__ import annotations

import pytest

# TDD red guard — module-level skip ensures CI is green while the impl
# PR lands. Implementation PR must add `DomainError` to
# `src/atilcalc/engine/evaluator.py` per ADR-0019 amend 2 §DomainError,
# then remove this guard.
try:
    from atilcalc.engine.evaluator import DomainError  # noqa: F401
except ImportError:
    pytest.skip(
        "STORY-011 TDD red — DomainError not yet implemented per ADR-0019 amend 2. "
        "Implementation PR will unskip by landing DomainError subclass of EngineError.",
        allow_module_level=True,
    )


# ---------------------------------------------------------------------------
# DomainError class existence + hierarchy
# ---------------------------------------------------------------------------
class TestDomainErrorClass:
    """DomainError exists, subclasses EngineError, is distinct from
    UndefinedOperatorError (which is for FUTURE operators that parse but
    cannot dispatch, per PR #63).
    """

    def test_domain_error_subclass_of_engine_error(self) -> None:
        from atilcalc.engine.evaluator import DomainError, EngineError
        assert issubclass(DomainError, EngineError), (
            "DomainError must subclass EngineError (ADR-0019 amendment 2)"
        )

    def test_domain_error_distinct_from_undefined_operator_error(self) -> None:
        """DomainError is semantically distinct from UndefinedOperatorError.

        UndefinedOperatorError: FUTURE operator parses but cannot dispatch
                                (e.g., `2^3` before exponent is implemented)
        DomainError:           runtime domain error (sqrt(-1), log(0), etc.)
        """
        from atilcalc.engine.evaluator import (
            DomainError,
            UndefinedOperatorError,
        )
        assert DomainError is not UndefinedOperatorError, (
            "DomainError must be a distinct class from UndefinedOperatorError"
        )
        assert not issubclass(DomainError, UndefinedOperatorError), (
            "DomainError must NOT subclass UndefinedOperatorError"
        )

    def test_domain_error_inherits_engine_error_for_catch_all(self) -> None:
        """A `except EngineError` block must catch DomainError.

        This ensures the HTTP layer's catch-all 500 handler will catch
        DomainError too (then re-raise to the typed handler for 400).
        """
        from atilcalc.engine.evaluator import DomainError, EngineError, evaluate
        # Use pytest.raises(DomainError) — DomainError IS-A EngineError,
        # so this proves the EngineError catch-all would also catch it.
        with pytest.raises(DomainError) as excinfo:
            evaluate("sqrt(-1)")
        # Verify the caught exception is also an EngineError (for the
        # catch-all handler to work).
        assert isinstance(excinfo.value, EngineError), (
            f"DomainError must also be an EngineError (for catch-all 500 handler); "
            f"got MRO: {type(excinfo.value).__mro__}"
        )


# ---------------------------------------------------------------------------
# TC-8: DomainError raised for domain errors
# ---------------------------------------------------------------------------
class TestDomainErrorRaised:
    """DomainError raised for sqrt(-1), log(0), log(-2), asin(2), acos(-1.5)."""

    @pytest.mark.parametrize(
        "expr",
        [
            "sqrt(-1)",    # sqrt of negative
            "log(0)",      # log undefined at 0
            "log(-2)",     # log of negative
            "asin(2)",     # asin undefined for |x| > 1
            "acos(-1.5)",  # acos undefined for |x| > 1
        ],
    )
    def test_domain_error_for_invalid_domain(self, expr: str) -> None:
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate(expr)


# ---------------------------------------------------------------------------
# TC-9: tan(90 deg) raises DomainError
# ---------------------------------------------------------------------------
class TestTan90Deg:
    """tan(90 deg) = tan(π/2) = ∞ → DomainError (not silent Infinity)."""

    def test_tan_90_deg_raises_domain_error(self) -> None:
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("tan(90 deg)", deg=True)

    def test_tan_pi_over_2_rad_raises_domain_error(self) -> None:
        """tan(π/2 rad) ≈ tan(1.5707963267948966) raises DomainError."""
        from atilcalc.engine.evaluator import DomainError, evaluate
        # π/2 to 16 digits: 1.5707963267948966
        with pytest.raises(DomainError):
            evaluate("tan(1.5707963267948966)", deg=False)


# ---------------------------------------------------------------------------
# Adversarial probes
# ---------------------------------------------------------------------------
class TestDomainErrorAdversarial:
    """AP-6: NaN propagation check. AP-12: log(0) vs log(1e-1000)."""

    def test_ap6_sqrt_neg_one_does_not_return_nan(self) -> None:
        """AP-6: sqrt(-1) MUST raise DomainError, NOT return Decimal('NaN').

        Silently returning NaN would propagate through arithmetic and corrupt
        the user's session; explicit DomainError is required for UX clarity.
        """
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            result = evaluate("sqrt(-1)")
        # Defense-in-depth: if implementation forgets to raise, this catches
        # NaN silently being returned.
        if "result" in dir():
            assert not result.is_nan(), (
                "sqrt(-1) returned NaN — must raise DomainError instead"
            )

    def test_ap12_log_zero_raises_domain_error_not_underflow(self) -> None:
        """AP-12: log(0) raises DomainError, NOT a tiny positive Decimal.

        log(0) is -infinity mathematically; returning 1E-1000 would be wrong.
        """
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("log(0)")

    def test_ap14_deg_suffix_in_rad_mode_raises_domain_error(self) -> None:
        """AP-14: `45 deg` in rad mode (deg=False) raises DomainError.

        PM recommendation: strict mode prevents accidental unit confusion.
        Silently ignoring the unit suffix would be a UX hazard.
        """
        from atilcalc.engine.evaluator import DomainError, evaluate
        with pytest.raises(DomainError):
            evaluate("45 deg", deg=False)
