"""AtilCalculator expression engine.

Pure-Python, no-I/O expression evaluator with ``decimal.Decimal`` precision.
mpmath is the documented exception to ADR-0017 §engine ↔ UI separation
(STD-lib-only invariant) for transcendental precision (ADR-0019 amend 2).

Public API
----------

- :func:`evaluate` — parse and evaluate a math expression string, returning
  a :class:`decimal.Decimal` result. Supports ``deg`` keyword for rad/deg
  toggle (Sprint 2 / STORY-011).
- :class:`EngineError` — base class for all engine-raised errors.
- :class:`ExpressionSyntaxError` — expression could not be parsed.
- :class:`DivisionByZeroError` — division or modulo by zero.
- :class:`UndefinedOperatorError` — operator not supported (FUTURE operators
  that parse but cannot dispatch — e.g., ``2^3`` before exponent is wired).
- :class:`DomainError` — runtime domain error in scientific functions
  (sqrt of negative, log of non-positive, tan at a pole, etc.).

Implementation choice
---------------------

Per ADR-0017 §Math-engine implementation choice: hand-written recursive-descent
parser. Sprint 2 (STORY-011) extends the grammar with:

- Transcendental functions: ``sin``, ``cos``, ``tan``, ``log`` (base 10),
  ``ln`` (base e), ``sqrt``.
- Inverse-trigonometric functions: ``asin``, ``acos`` (used by domain-error
  tests; not in the ACs but pinned in the TDD red contract).
- Factorial postfix: ``n!`` with a cap of 170 (ADR-0019 amend 2 §Factorial).
- Unary minus: ``-X`` (and inside parens, e.g., ``(-1)!``).
- Unit suffix: ``45 deg`` (only legal in deg mode; converts to radians).

Sprint 1 (MVP-1) scope:
    + - * / % ( )

Sprint 2 (MVP-2) scope (STORY-011):
    + - * / % ( )  sin cos tan log ln sqrt asin acos  X!  -X  45 deg
"""

from atilcalc.engine.evaluator import (
    DivisionByZeroError,
    DomainError,
    EngineError,
    ExpressionSyntaxError,
    UndefinedOperatorError,
    evaluate,
)

__all__ = [
    "DivisionByZeroError",
    "DomainError",
    "EngineError",
    "ExpressionSyntaxError",
    "UndefinedOperatorError",
    "evaluate",
]
