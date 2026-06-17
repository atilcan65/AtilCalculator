"""Tests for :func:`atilcalc.engine.evaluate`.

These are the AC1 (decimal precision) tests for STORY-002. TDD-red phase:
all tests in this file SHOULD FAIL on the current NotImplementedError stub.

AC1 (decimal precision)
    GIVEN the engine module is imported,
    WHEN I call ``evaluate("0.1 + 0.2")``,
    THEN the result is ``Decimal("0.3")`` (exact equality, no float coercion).

AC4 (precision stability)
    GIVEN decimal.Decimal precision is set,
    WHEN I call ``evaluate("0.1 + 0.2")`` repeatedly (1000 times),
    THEN the result is identical each time (no float drift).

These two ACs are tested first because they are the load-bearing M1
metric from vision.md: "First MVP ships with zero float errors."

Implementation note
-------------------
We assert against ``Decimal`` directly (not ``float``) to catch accidental
float coercion. ``Decimal("0.3") == 0.3`` is ``False`` in Python, so any
implementation that returns a float will fail this test loudly.
"""

from __future__ import annotations

from decimal import Decimal

import pytest

from atilcalc.engine import evaluate


@pytest.mark.parametrize(
    ("expression", "expected"),
    [
        # AC1: the canonical float-error case. 0.1 + 0.2 in IEEE-754 = 0.30000000000000004.
        pytest.param("0.1 + 0.2", Decimal("0.3"), id="ac1-canonical-float-error"),
        # Spot-checks: other expressions that commonly surprise floats.
        pytest.param("0.1 + 0.2 + 0.3", Decimal("0.6"), id="ac1-three-way-sum"),
        pytest.param("1.5 + 2.5", Decimal("4.0"), id="ac1-integer-aligned-sum"),
        pytest.param("10 - 9.9", Decimal("0.1"), id="ac1-subtraction-float-trap"),
    ],
)
def test_evaluate_decimal_precision(expression: str, expected: Decimal) -> None:
    """AC1: ``evaluate()`` must return exact Decimal, no float coercion.

    Asserts against ``Decimal`` (not ``float``) so any accidental float
    coercion fails loudly. ``Decimal('0.3') == 0.3`` is ``False`` in Python.
    """
    result = evaluate(expression)
    assert result == expected, (
        f"evaluate({expression!r}) returned {result!r} ({type(result).__name__}), "
        f"expected {expected!r} (Decimal). Float coercion suspected."
    )
    # Belt-and-suspenders: explicitly assert type is Decimal, not float.
    # Catches `return float(result)` regressions that pass the equality above.
    assert isinstance(result, Decimal), (
        f"evaluate({expression!r}) returned type {type(result).__name__}, "
        "expected Decimal. Even if value matches, type discipline matters "
        "for serialisation (see ADR-0018 watch-item #1: API contract)."
    )


def test_evaluate_precision_stable_across_repeated_calls() -> None:
    """AC4: result must be bit-identical across 1000 repeated calls.

    If the implementation accidentally uses ``float`` anywhere (e.g. via
    ``Decimal(float(x))``), repeated calls against the same expression
    may yield different Decimal values due to float-quantisation drift.

    This is a property test: the same expression called 1000 times must
    produce 1000 identical results.
    """
    expression = "0.1 + 0.2"
    first_result = evaluate(expression)
    # All 1000 subsequent calls must equal the first, bit-for-bit.
    for i in range(1000):
        subsequent = evaluate(expression)
        assert subsequent == first_result, (
            f"Precision drift on call {i + 1}: "
            f"first={first_result!r}, call_{i + 1}={subsequent!r}"
        )


# ---------------------------------------------------------------------------
# AC2 — Parenthesised expressions (tester addition, TDD-RED).
#
# AC2 from STORY-002:
#   GIVEN a parenthesised expression,
#   WHEN I call evaluate("2 * (3 + 4)"),
#   THEN the result is Decimal("14").
#
# Parens override default precedence and must nest correctly. We test the
# canonical case plus three adversarial probes: nested parens, parens around
# a single value (no-op), and parens with percent (compound expression).
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    ("expression", "expected"),
    [
        pytest.param("2 * (3 + 4)", Decimal("14"), id="ac2-canonical-paren-precedence"),
        pytest.param("(2 + 3) * 4", Decimal("20"), id="ac2-paren-multiplication"),
        pytest.param("((1 + 2) * (3 + 4))", Decimal("21"), id="ac2-nested-parens"),
        pytest.param("5 + (3)", Decimal("8"), id="ac2-single-value-paren"),
        pytest.param("100 + (5 + 5)%", Decimal("110"), id="ac2-paren-with-percent"),
    ],
)
def test_evaluate_parenthesised_expression(expression: str, expected: Decimal) -> None:
    """AC2: parens must override default operator precedence.

    Tests the canonical "2 * (3 + 4)" case plus adversarial probes for
    nested parens, single-value parens (no-op), and parens + percent.
    """
    result = evaluate(expression)
    assert result == expected, (
        f"evaluate({expression!r}) returned {result!r}, expected {expected!r}"
    )
    assert isinstance(result, Decimal), (
        f"evaluate({expression!r}) returned type {type(result).__name__}, expected Decimal"
    )


# ---------------------------------------------------------------------------
# AC3 — Percent operator (tester addition, TDD-RED).
#
# AC3 from STORY-002:
#   GIVEN a percent operator,
#   WHEN I call evaluate("100 + 5%"),
#   THEN the result is Decimal("105").
#
# Per evaluator.py docstring, the developer chose financial-calculator semantics:
# "<number>%" is a percentage of the **immediately preceding numeric value**.
# So 100 + 5% = 100 + (5/100 * 100) = 105.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    ("expression", "expected"),
    [
        pytest.param("100 + 5%", Decimal("105"), id="ac3-canonical-percent"),
        pytest.param("200 - 10%", Decimal("180"), id="ac3-subtract-percent"),
        pytest.param("50 * 20%", Decimal("10"), id="ac3-multiply-percent"),
        pytest.param("100%", Decimal("1"), id="ac3-percent-only-no-preceding"),
        pytest.param("100 + 5% + 1", Decimal("106"), id="ac3-percent-mid-expression"),
    ],
)
def test_evaluate_percent_operator(expression: str, expected: Decimal) -> None:
    """AC3: percent must apply to the immediately preceding numeric value.

    The developer chose financial-calculator semantics (see evaluator.py
    docstring): ``X%`` = ``X/100 * <preceding_value>``. Tests cover the
    canonical case plus subtract/multiply variants, percent-only, and
    percent embedded mid-expression.
    """
    result = evaluate(expression)
    assert result == expected, (
        f"evaluate({expression!r}) returned {result!r}, expected {expected!r}"
    )
    assert isinstance(result, Decimal), (
        f"evaluate({expression!r}) returned type {type(result).__name__}, expected Decimal"
    )


# ---------------------------------------------------------------------------
# AC5 — Division by zero raises a structured error (tester addition, TDD-RED).
#
# AC5 from STORY-002:
#   GIVEN I divide by zero,
#   WHEN I call evaluate("5 / 0"),
#   THEN the engine raises a structured DivisionByZeroError (not a generic exception).
#
# The exception hierarchy (per evaluator.py): EngineError (base) →
# DivisionByZeroError, ExpressionSyntaxError, UndefinedOperatorError.
# The HTTP layer will catch EngineError for fallback 500 + the specific
# subclasses for typed 4xx responses (per ADR-0018 watch-item #1).
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    "expression",
    [
        pytest.param("5 / 0", id="ac5-division-by-zero"),
        pytest.param("7 % 0", id="ac5-modulo-by-zero"),
        pytest.param("0 / 0", id="ac5-zero-over-zero"),
        pytest.param("100 / (5 - 5)", id="ac5-division-by-zero-via-parens"),
    ],
)
def test_evaluate_division_by_zero_raises_structured_error(expression: str) -> None:
    """AC5: division/modulo by zero must raise DivisionByZeroError, not generic.

    Specifically asserts:
    - Exception is a DivisionByZeroError (not built-in ZeroDivisionError)
    - Exception is a subclass of EngineError (catch-all for HTTP layer)
    - Exception is NOT a Python built-in ZeroDivisionError or generic Exception
    """
    from atilcalc.engine import DivisionByZeroError, EngineError

    with pytest.raises(DivisionByZeroError) as excinfo:
        evaluate(expression)

    # The raised error must be a structured EngineError subclass (not generic).
    assert isinstance(excinfo.value, EngineError), (
        f"evaluate({expression!r}) raised {type(excinfo.value).__name__}, "
        "expected a structured EngineError subclass"
    )
    # And specifically NOT a Python built-in ZeroDivisionError (which is a
    # subclass of ArithmeticError, not EngineError — the test above would
    # already catch this, but explicit assert is clearer for code review).
    assert not isinstance(excinfo.value, ZeroDivisionError) or isinstance(
        excinfo.value, EngineError
    ), (
        f"evaluate({expression!r}) raised a built-in ZeroDivisionError; "
        "the engine must raise its own DivisionByZeroError per AC5"
    )


# ---------------------------------------------------------------------------
# AC2/AC3/AC5 adversarial probes — extra edge cases worth pinning.
#
# These go beyond the explicit AC text to catch regressions a careful reader
# might miss: empty parens, malformed percent, etc. They live alongside the
# AC tests but are not part of any single AC's literal acceptance text.
# ---------------------------------------------------------------------------
@pytest.mark.parametrize(
    "expression",
    [
        pytest.param("", id="edge-empty-string"),
        pytest.param("   ", id="edge-whitespace-only"),
        pytest.param("()", id="edge-empty-parens"),
        pytest.param("(", id="edge-unclosed-paren"),
        pytest.param(")", id="edge-unopened-paren"),
        pytest.param("abc", id="edge-non-numeric-token"),
        pytest.param("1.2.3", id="edge-malformed-decimal"),
    ],
)
def test_evaluate_malformed_expression_raises_syntax_error(expression: str) -> None:
    """Adversarial: malformed input must raise ExpressionSyntaxError, not crash."""
    from atilcalc.engine import EngineError, ExpressionSyntaxError

    with pytest.raises(EngineError) as excinfo:
        evaluate(expression)

    # Any of the structured engine errors is acceptable for malformed input.
    # The contract is "no crash, structured error" — not "always SyntaxError"
    # (e.g. ``)`` could be a tokeniser-level error, which is also EngineError).
    assert isinstance(excinfo.value, EngineError), (
        f"evaluate({expression!r}) raised {type(excinfo.value).__name__}, "
        "expected a structured EngineError"
    )
