"""Parametrised pytest regression suite for STORY-300 / STORY-CLI-002.

Maps to docs/test-plans/STORY-300-tests.md (5 TCs, 18 pytest cases).

TDD discipline:
- This file is the TDD RED deliverable: it MUST FAIL before src/atilcalc/parser/ exists.
- Each test invokes `python -m atilcalc <expr>` as a subprocess (portable; no install step).
- The implementer writes `src/atilcalc/parser/__init__.py` (recursive descent parser
  with operator precedence per docs/test-plans/STORY-300-tests.md) to make these
  tests pass (TDD GREEN).

Refs: Issue #300, PR #303 (test plan), docs/backlog/STORY-CLI-002.md, ADR-0017.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_cli(*args: str, timeout: float = 10.0) -> subprocess.CompletedProcess:
    """Invoke `python -m atilcalc` with the given args; return CompletedProcess.

    Uses `python -m` (not the installed `atilcalc` binary) for portability:
    tests run from a fresh checkout without `pip install -e .[dev]` first.
    Captures stdout/stderr as text. Raises subprocess.TimeoutExpired on hang.
    """
    return subprocess.run(
        [sys.executable, "-m", "atilcalc", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=REPO_ROOT,
    )


# ---------------------------------------------------------------------------
# TC-1: AC1-AC5 — Precedence rules (parametrised, 6 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("2 + 3 * 4", "14"),  # AC1: mul before add
        ("(2 + 3) * 4", "20"),  # AC2: parens override
        ("2 + 3 + 4 * 5", "25"),  # AC3: left-to-right same-precedence
        ("10 - 2 * 3", "4"),  # AC4: subtraction precedence
        ("100 / 5 / 2", "10"),  # AC5: left-to-right division
        ("2 ** 3", "8"),  # AC6: power operator (integer exp)
    ],
)
def test_cli_precedence_basic(expr: str, expected: str) -> None:
    """TC-1: AC1-AC5 — Precedence rules (6 cases)."""
    result = _run_cli(expr)
    assert result.returncode == 0, f"non-zero exit: {result.stderr}"
    assert result.stdout.strip() == expected


# ---------------------------------------------------------------------------
# TC-2: AC6 — Power operator edge cases (parametrised, 4 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("2 ** 10", "1024"),  # large power
        ("0.5 ** 2", "0.25"),  # decimal base
        ("2 ** 0", "1"),  # zero exponent
        ("2 ** -1", "0.5"),  # negative exponent
    ],
)
def test_cli_power_operator(expr: str, expected: str) -> None:
    """TC-2: AC6 — Power operator edge cases (4 cases)."""
    result = _run_cli(expr)
    assert result.returncode == 0, f"non-zero exit: {result.stderr}"
    assert result.stdout.strip() == expected


# ---------------------------------------------------------------------------
# TC-3: AC8 — Unbalanced parens error path (parametrised, 3 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "expr",
    [
        "(1 + 2",  # missing close
        "1 + 2)",  # extra close
        "((1 + 2)",  # nested unbalanced
    ],
)
def test_cli_unbalanced_parens(expr: str) -> None:
    """TC-3: AC8 — Unbalanced parens → parse error, non-zero exit, NO traceback."""
    result = _run_cli(expr)
    assert result.returncode != 0, "expected non-zero exit for unbalanced parens"
    # No Python traceback leak
    assert "Traceback" not in result.stdout
    assert "Traceback" not in result.stderr
    # stderr should be non-empty
    assert result.stderr, "expected non-empty stderr for unbalanced parens"
    # Tight check: must mention parse/unbalanced (NOT just "error" — that
    # would match "ModuleNotFoundError" in TDD RED state)
    stderr_norm = result.stderr.lower().replace(" ", "").replace("_", "")
    assert (
        "parse" in stderr_norm
        or "unbalanced" in stderr_norm
        or "paren" in stderr_norm
    ), f"expected stderr to mention parse/unbalanced/paren, got: {result.stderr!r}"


# ---------------------------------------------------------------------------
# TC-4: AC9 — Unary minus (parametrised, 4 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("-5 + 3", "-2"),  # unary minus binds tighter than binary
        ("5 + -3", "2"),  # unary in second position
        ("--5", "5"),  # double unary (negation of negation)
        ("-(2 + 3)", "-5"),  # unary on parenthesized expression
    ],
)
def test_cli_unary_minus(expr: str, expected: str) -> None:
    """TC-4: AC9 — Unary minus (4 cases)."""
    result = _run_cli(expr)
    assert result.returncode == 0, f"non-zero exit: {result.stderr}"
    assert result.stdout.strip() == expected


# ---------------------------------------------------------------------------
# TC-5: AC7 — Parametrised regression suite ≥18 cases
# (Union of TC-1, TC-2, TC-4 — single parametrised test for coverage)
# ---------------------------------------------------------------------------

REGRESSION_CASES = [
    # Precedence (TC-1)
    ("2 + 3 * 4", "14", 0),
    ("(2 + 3) * 4", "20", 0),
    ("2 + 3 + 4 * 5", "25", 0),
    ("10 - 2 * 3", "4", 0),
    ("100 / 5 / 2", "10", 0),
    ("2 ** 3", "8", 0),
    # Power (TC-2)
    ("2 ** 10", "1024", 0),
    ("0.5 ** 2", "0.25", 0),
    ("2 ** 0", "1", 0),
    ("2 ** -1", "0.5", 0),
    # Unary minus (TC-4)
    ("-5 + 3", "-2", 0),
    ("5 + -3", "2", 0),
    ("--5", "5", 0),
    ("-(2 + 3)", "-5", 0),
    # Mixed extra (TC-5 expansion)
    ("1 + 2 * 3 - 4", "3", 0),
    ("(1 + 2) * (3 - 4)", "-3", 0),
    ("2 * 3 + 4 * 5", "26", 0),
    ("(2 + 3 + 4) * 2", "18", 0),
]


@pytest.mark.parametrize(("expr", "expected", "expected_exit"), REGRESSION_CASES)
def test_cli_precedence_regression(expr: str, expected: str, expected_exit: int) -> None:
    """TC-5: AC7 — Parametrised regression suite (18 cases)."""
    result = _run_cli(expr)
    assert result.returncode == expected_exit, (
        f"expr={expr!r} got exit {result.returncode}, want {expected_exit}; "
        f"stderr={result.stderr!r}"
    )
    if expected_exit == 0:
        assert result.stdout.strip() == expected, (
            f"expr={expr!r} got stdout={result.stdout.strip()!r}, want {expected!r}"
        )
