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
