"""Expression evaluator and engine exception hierarchy.

Public surface
--------------

- :func:`evaluate` — entry point for parsing and evaluating an expression.
- :class:`EngineError` — base class for all engine errors (catch-all).
- :class:`SyntaxError_` — raised when the input cannot be tokenised/parsed.
- :class:`DivisionByZeroError` — raised when division/modulo by zero occurs.
- :class:`UndefinedOperatorError` — raised when an operator is not in MVP-1 scope.

The exception hierarchy is deliberately structured (not generic ``ValueError``)
so the HTTP layer can map each error to a distinct status code + error envelope
per ADR-0018 watch-item #1 (API contract; pending architect's R-N ADR).
"""

from __future__ import annotations

from decimal import Decimal


class EngineError(Exception):
    """Base class for all AtilCalculator engine errors.

    The HTTP layer should catch this base class for fallback 500 handling,
    and the specific subclasses for typed 4xx responses.
    """


class ExpressionSyntaxError(EngineError):
    """Raised when the input expression cannot be tokenised or parsed.

    Named ``ExpressionSyntaxError`` rather than ``SyntaxError`` to avoid
    shadowing Python's built-in ``SyntaxError`` class. Users who want the
    built-in can still ``import builtins`` and access it there.

    Examples: ``"2+"``, ``"abc"``, ``"("``, ``"1.2.3"``.
    """


class DivisionByZeroError(EngineError):
    """Raised when division or modulo by zero is attempted.

    Examples: ``"5 / 0"``, ``"7 % 0"``.

    Per STORY-002 AC5: the engine must raise this structured error, NOT
    a generic ``ZeroDivisionError`` from ``decimal.Decimal``.
    """


class UndefinedOperatorError(EngineError):
    """Raised when an operator is used that is out of MVP-1 scope.

    Examples (all Sprint 2+): unary minus ``"-5"``, exponent ``"2^3"``,
    factorial ``"5!"``, trig ``"sin(0)"``.

    Surfacing these explicitly prevents silent wrong answers: a user typing
    ``"2^3"`` expecting ``8`` gets a clear error rather than a parse
    failure or a wrong fallback.
    """


def evaluate(expression: str) -> Decimal:
    """Parse and evaluate a math expression, returning a Decimal result.

    Supported operators (MVP-1 / Sprint 1):
        +  addition
        -  subtraction
        *  multiplication
        /  division
        %  percent (postfix; ``100 + 5%`` → ``100 + 0.05*100 = 105``)
        ( )  parentheses (override default precedence)

    Percent semantics (per STORY-002 open question, decided by @developer):
        ``<number>%`` is interpreted as a percentage of the **immediately
        preceding numeric value** (financial-calculator convention).
        ``100 + 5%`` therefore parses as ``100 + (5/100 * 100) = 105``.
        This satisfies AC3 and matches owner-operator intuition for
        financial calculations.

    Args:
        expression: A math expression string. Whitespace is ignored.
            Tokens must be decimal numbers (e.g. ``0.1``, ``3.14``, ``42``)
            and operators from the supported set.

    Returns:
        A :class:`decimal.Decimal` with the exact evaluation result.
        Decimal precision is preserved end-to-end (no float coercion).

    Raises:
        ExpressionSyntaxError: If the expression cannot be tokenised or parsed.
            Examples: ``"2+"``, ``"abc"``, ``"("``.
        DivisionByZeroError: If a division or modulo by zero is attempted.
            Examples: ``"5 / 0"``, ``"7 % 0"``.
        UndefinedOperatorError: If an out-of-scope operator is used.

    Examples:
        >>> evaluate("0.1 + 0.2")
        Decimal('0.3')
        >>> evaluate("2 * (3 + 4)")
        Decimal('14')
        >>> evaluate("100 + 5%")
        Decimal('105')
        >>> evaluate("5 / 0")  # doctest: +IGNORE_EXCEPTION_DETAIL
        atilcalc.engine.DivisionByZeroError
    """
    raise NotImplementedError("evaluate() scaffolded for STORY-002; TDD red phase")
