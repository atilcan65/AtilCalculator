"""AtilCalculator REPL mode (STORY-CLI-003 / Issue #301).

Interactive read-eval-print loop: reads expressions from stdin line-by-line,
evaluates via :mod:`atilcalc.engine`, prints results + new prompt. Continues
on parse errors (does NOT exit). Exit via ``exit``/``quit``/``/exit``/``/quit``
or EOF (Ctrl-D).

Architecture note (ADR-0017 §stdlib-bias)
------------------------------------------

The Sprint 7 plan §Open question preferred stdlib ``input()`` over third-party
``prompt_toolkit``. Rationale:

- Sprint 7 scope is M3 spirit (basic interactive mode); Sprint 8+ may add
  arrow recall, tab completion, syntax highlighting.
- stdlib has zero install footprint, matches the engine module's stdlib-only
  discipline (ADR-0017 §engine ↔ UI separation).

Stdlib ``input(prompt)`` does NOT flush the prompt in non-tty mode (pipe).
For subprocess-driven tests (``subprocess.Popen`` + writable stdin), the
REPL must explicitly flush after printing the prompt. This module uses
``print(prompt, end="", flush=True)`` + ``sys.stdin.readline()`` instead
of ``input(prompt)`` for that reason.

Test contract
-------------

PR #317 (d036c-cli-repl.sh + tests/cli/test_repl.py, TDD RED by tester).
The REPL implementation makes those tests pass (TDD GREEN).

Mapping (test plan §Test Cases):

- TC-1 / AC1: prompt display — ``PROMPT`` constant + ``print(..., flush=True)``
- TC-2 / AC2: basic eval — engine.evaluate() per line, ``format(result, "f")``
- TC-3 / AC3: precedence eval — reuse STORY-300 engine behaviour
- TC-4 / AC4: exit commands — ``EXIT_COMMANDS`` constant
- TC-5 / AC5: EOF handling — ``sys.stdin.readline()`` returns "" on EOF
- TC-6 / AC6: parse error continuation — ``continue`` after stderr message
- TC-7 / AC7: /help slash-command — ``HELP_TEXT`` constant
- TC-8 / AC8: session-level — single ``run_repl()`` call, all events in one process
- TC-10: empty input — strip + skip if empty (no engine call, no error)

Type-safety (ADR-0017 §mypy --strict on engine)
-----------------------------------------------

Per ADR-0017, the engine module is ``mypy --strict``. The REPL is a thin
wrapper around the engine and does NOT need strict mode (it has I/O, so
the engine ↔ UI separation rule applies). The repl module opts OUT of
strict typing via the standard mypy override pattern (cli/repl stay permissive).
"""

from __future__ import annotations

import sys

from atilcalc.engine import (
    DivisionByZeroError,
    EngineError,
    ExpressionSyntaxError,
    evaluate,
)

# Prompt string. Per test plan §Design decisions: ``atilcalc> `` with trailing space.
# Test contract T1 + TC-1 are loose (accepts ``atilcalc>`` or ``>``).
PROMPT = "atilcalc> "

# Exit commands (bare + slash form per test plan §Open question).
EXIT_COMMANDS = frozenset({"exit", "quit", "/exit", "/quit"})

# /help slash-command output (TC-7). Must mention /help, /exit, /quit for
# the loose grep check ``grep -Eq '/help|/exit|/quit'``.
HELP_TEXT = """\
AtilCalculator REPL — interactive expression evaluator.

Usage:
  Type an expression and press Enter to evaluate it.
  Press Ctrl-D (Unix) or Ctrl-Z+Enter (Windows) to exit.

Commands:
  exit, quit       Exit the REPL
  /help            Show this help message
  /exit, /quit     Exit the REPL (slash form)

The REPL continues after parse errors — just type the next expression.
"""


def run_repl() -> int:
    """Run the REPL loop until exit command or EOF. Returns process exit code.

    Always returns 0 in the current contract (TC-4 + TC-5): exit commands and
    EOF both exit cleanly. Parse errors and division-by-zero do NOT exit
    (TC-6: REPL continues after error).
    """
    while True:
        # Print prompt with explicit flush (input() doesn't flush in pipe mode).
        print(PROMPT, end="", flush=True)

        # Read one line from stdin. Returns "" on EOF (closed pipe or Ctrl-D).
        line = sys.stdin.readline()
        if not line:
            # EOF — print newline after the last prompt, then exit cleanly.
            print()
            return 0

        # Normalize line endings (handle \r\n from Windows pipes too).
        line = line.rstrip("\n").rstrip("\r").strip()

        # TC-10: empty input (just Enter) → new prompt, no error, no engine call.
        if not line:
            continue

        # TC-4: exit commands (bare or slash form) → goodbye + exit 0.
        if line in EXIT_COMMANDS:
            print("Goodbye!")
            return 0

        # TC-7: /help slash-command → show help text + continue.
        if line == "/help":
            print(HELP_TEXT)
            continue

        # TC-2 / TC-3: evaluate expression via engine.
        # Engine errors → stderr message, REPL continues (TC-6).
        # Use the same error keyword labels as the CLI for consistency
        # (PR #306 contract: "parse" for parse errors, "DivisionByZero" for div-by-zero).
        try:
            result = evaluate(line)
        except ExpressionSyntaxError as exc:
            print(f"parse error: {exc}", file=sys.stderr, flush=True)
            continue
        except DivisionByZeroError as exc:
            print(f"decimal.DivisionByZero: {exc}", file=sys.stderr, flush=True)
            continue
        except EngineError as exc:
            print(f"error: {exc}", file=sys.stderr, flush=True)
            continue

        # Success: print Decimal result with fixed-point format (no scientific notation).
        # flush=True so subprocess tests see the output promptly.
        print(format(result, "f"), flush=True)


if __name__ == "__main__":
    raise SystemExit(run_repl())
