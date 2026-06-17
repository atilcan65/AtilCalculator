"""AtilCalculator expression engine.

Pure-Python, no-I/O expression evaluator with ``decimal.Decimal`` precision.

Public API
----------

- :func:`evaluate` — parse and evaluate a math expression string, returning
  a :class:`decimal.Decimal` result.
- :class:`EngineError` — base class for all engine-raised errors.
- :class:`ExpressionSyntaxError` — expression could not be parsed.
- :class:`DivisionByZeroError` — division or modulo by zero.
- :class:`UndefinedOperatorError` — operator not supported in MVP-1.

Implementation choice
---------------------

Per ADR-0017 §Math-engine implementation choice: hand-written recursive-descent
parser for ``+ - * / % ( )``. Out-of-scope operators (unary minus, exponentiation,
trig, log, factorial) raise :class:`UndefinedOperatorError` so the surface
is explicit rather than silently wrong.

Sprint 1 (MVP-1) scope:
    + - * / % ( )

Sprint 2+ scope (deferred per vision):
    unary minus, ^ (exponent), ! (factorial), sin/cos/tan/log/sqrt
"""

from atilcalc.engine.evaluator import (
    DivisionByZeroError,
    EngineError,
    ExpressionSyntaxError,
    UndefinedOperatorError,
    evaluate,
)

__all__ = [
    "DivisionByZeroError",
    "EngineError",
    "ExpressionSyntaxError",
    "UndefinedOperatorError",
    "evaluate",
]
