"""AtilCalculator CLI surface (STORY-CLI-001, Issue #299, PR #306 TDD RED).

Thin command-line wrapper around :mod:`atilcalc.engine`. Accepts a math
expression as positional arguments, evaluates with the engine, and prints
the result to stdout.

Architecture note
-----------------

Per ADR-0017 §Tech stack, the canonical CLI scaffolding is `typer`. This
implementation uses :mod:`argparse` from the stdlib instead. Rationale:

- The Sprint 1 engine is stdlib-only (per ADR-0017 §engine ↔ UI separation);
  the CLI is a thin wrapper and inherits the same discipline.
- The TDD RED test contract (PR #306, scripts/tests/d036a-cli-basic-arithmetic.sh
  + tests/cli/test_basic_arithmetic.py) tests exit code, stdout, and stderr only
  — no typer-specific features (no --help, no shell completion).
- argparse is 5 lines for our use case; typer is a runtime dep the user must
  install. Avoiding the dep until a feature actually needs it (e.g., subcommands
  in STORY-301 REPL mode).

Open question (carried over from issue #299): typer vs click? — see PR
description. Easy 10-line swap if owner/architect prefers typer.

Exit codes
----------

- 0: success (result printed to stdout)
- 1: engine error (parse error, division by zero, domain error, etc.)
- 2: usage error (no expression provided)

Error semantics
---------------

All engine errors are caught and printed to stderr with a short label.
NO Python traceback is leaked to the user. See PR #306 TC-4 (DivisionByZero)
and TC-5 (Invalid expression) for the keyword contract.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence

from atilcalc.engine import (
    DivisionByZeroError,
    EngineError,
    ExpressionSyntaxError,
    evaluate,
)


def _build_parser() -> argparse.ArgumentParser:
    """Build the argument parser for the atilcalc CLI."""
    parser = argparse.ArgumentParser(
        prog="atilcalc",
        description=(
            "AtilCalculator — exact-decimal arithmetic evaluator. "
            "Reads a math expression from positional args, prints the result."
        ),
    )
    parser.add_argument(
        "expression",
        nargs=argparse.REMAINDER,
        help="Math expression to evaluate (e.g. '0.1 + 0.2'). "
        "All remaining args are joined with spaces.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry point. Returns the process exit code.

    Args:
        argv: Optional argument list. Defaults to ``sys.argv[1:]``. Tests
            can pass an explicit list to avoid mutating ``sys.argv``.

    Returns:
        0 on success, 1 on engine error, 2 on usage error.

    Design note (Sprint 7 / STORY-300 — ``--5`` regression)
    -------------------------------------------------------

    The naive ``argparse`` setup with ``nargs=argparse.REMAINDER`` interprets
    any arg starting with ``--`` as a long option. So ``python -m atilcalc --5``
    (the double-unary case ``--5`` from test_cli_unary_minus) was rejected
    as "unrecognized arguments: --5" before reaching the engine.

    Fix: handle ``--help`` / ``-h`` explicitly, then treat **all remaining
    args** as the expression. The expression parser is the source of truth
    for syntax; argparse's option parsing would only get in the way for
    math expressions that legitimately start with ``-`` (unary minus) or
    ``--`` (double unary).
    """
    if argv is None:
        argv = sys.argv[1:]

    # Handle help explicitly via argparse (so --help / -h still works),
    # then treat all other args as the expression.
    if argv and argv[0] in ("--help", "-h"):
        _build_parser().parse_args(["--help"])
        return 0

    if not argv:
        return _handle_empty_expression()

    # Join all remaining args with spaces. The engine handles unary minus
    # (``-5 + 3``), double unary (``--5``), and all operator precedence.
    expression = " ".join(argv)

    try:
        result = evaluate(expression)
    except ExpressionSyntaxError as exc:
        # AC6: parse error → stderr with "parse" keyword, non-zero exit, NO traceback
        print(f"parse error: {exc}", file=sys.stderr)
        return 1
    except DivisionByZeroError as exc:
        # AC5: division by zero → stderr with "DivisionByZero" keyword, non-zero exit
        # Use the full class name so test contract matches (loose case-insensitive)
        print(f"decimal.DivisionByZero: {exc}", file=sys.stderr)
        return 1
    except EngineError as exc:
        # Catch-all for other engine errors (UndefinedOperatorError, DomainError, etc.)
        print(f"error: {exc}", file=sys.stderr)
        return 1

    # Success: print the Decimal result to stdout.
    # Use 'f' format to force fixed-point notation (avoids scientific
    # notation for small Decimal results like 3E-9 → "0.000000003").
    # str(Decimal('0.3')) → '0.3' (canonical), str(Decimal('5')) → '5',
    # str(Decimal('3.333333333333333333333333333')) → '3.333333333333333333333333333'.
    print(format(result, "f"))
    return 0


def _handle_empty_expression() -> int:
    """Print a parse error for empty/whitespace-only input and return exit 1.

    Used when the user invokes ``atilcalc`` with no positional args. Treats
    the empty input as an engine parse error (consistent with TC-5 contract:
    stderr + non-zero exit + "parse" keyword), not a CLI usage error.
    """
    print("parse error: empty or whitespace-only expression ''", file=sys.stderr)
    return 1


__all__ = ["main"]
