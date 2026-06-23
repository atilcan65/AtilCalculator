"""Parametrised pytest regression suite for STORY-299 / STORY-CLI-001.

Maps to docs/test-plans/STORY-299-tests.md (8 TCs, 15 pytest cases).

TDD discipline:
- This file is the TDD RED deliverable: it MUST FAIL before src/atilcalc/cli/ exists.
- Each test invokes `python -m atilcalc <expr>` as a subprocess (portable; no install step).
- The implementer writes `src/atilcalc/cli/__init__.py` (typer app) + `src/atilcalc/__main__.py`
  + `pyproject.toml` `[project.scripts]` entry to make these tests pass (TDD GREEN).

Refs: Issue #299, PR #303 (test plan), docs/backlog/STORY-CLI-001.md, ADR-0017.
"""

from __future__ import annotations

import subprocess
import sys
from decimal import Decimal
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
# TC-1: AC1 — M1 baseline `0.1 + 0.2 == 0.3` (parametrised, 4 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("0.1 + 0.2", "0.3"),  # M1 acceptance
        ("0.1 + 0.2 + 0.3", "0.6"),  # chained addition exactness
        ("0.1 + 0.2 + 0.3 + 0.4", "1.0"),  # 4-term chain
        ("2 + 3", "5"),  # baseline integer (regression sanity)
    ],
)
def test_cli_basic_arithmetic_m1_baseline(expr: str, expected: str) -> None:
    """AC1: M1 baseline — exact Decimal precision, no float artifacts."""
    result = _run_cli(*expr.split())
    assert result.returncode == 0, f"non-zero exit: {result.stderr}"
    assert result.stdout.strip() == expected
    # Type assertion: stdout is a string, parseable as exact Decimal
    assert Decimal(result.stdout.strip()) == Decimal(expected)


# ---------------------------------------------------------------------------
# TC-2: AC2 — Integer/decimal arithmetic (parametrised, 4 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("1.5 * 3", "4.5"),  # no scientific notation
        ("2 + 3", "5"),  # integer arithmetic
        ("10 / 3", "3.333333333333333333333333333"),  # Decimal 28-digit precision
        ("100 - 50", "50"),
    ],
)
def test_cli_basic_arithmetic_integer_decimal(expr: str, expected: str) -> None:
    """AC2: integer/decimal arithmetic, exact Decimal precision."""
    result = _run_cli(*expr.split())
    assert result.returncode == 0, f"non-zero exit: {result.stderr}"
    assert result.stdout.strip() == expected


# ---------------------------------------------------------------------------
# TC-3: AC3 — Large numbers (parametrised, 2 cases)
# NOTE (Issue #309): `**` (power) is out-of-scope for STORY-299 — belongs to
# STORY-300 AC6. Originally TC-3 included `2 ** 64` as a "large number" example
# but that requires `**` operator. Removed; precision intent preserved with 2
# remaining cases (large integer multiplication + tiny decimal addition).
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("999999999 * 999999999", "999999998000000001"),  # 9-digit * 9-digit
        ("0.000000001 + 0.000000002", "0.000000003"),  # small numbers
    ],
)
def test_cli_basic_arithmetic_large_numbers(expr: str, expected: str) -> None:
    """AC3: large/small numbers, no float overflow, exact Decimal precision."""
    result = _run_cli(*expr.split())
    assert result.returncode == 0, f"non-zero exit: {result.stderr}"
    assert result.stdout.strip() == expected


# ---------------------------------------------------------------------------
# TC-4: AC5 — Division by zero error path (parametrised, 3 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "expr",
    [
        "1 / 0",  # direct division by zero
        "0 / 0",  # 0/0
        "1 / (2 - 2)",  # zero via expression
    ],
)
def test_cli_division_by_zero_error_path(expr: str) -> None:
    """AC5: division by zero → clear stderr mentioning DivisionByZero, non-zero exit, NO inf/Infinity in stdout."""
    result = _run_cli(*expr.split())
    assert result.returncode != 0, "expected non-zero exit for division by zero"
    # stdout must NOT contain inf or Infinity
    assert "inf" not in result.stdout.lower()
    assert "infinity" not in result.stdout.lower()
    # stderr should mention the Decimal error class (loose case-insensitive match)
    assert result.stderr, "expected non-empty stderr for division by zero"
    assert "divisionbyzero" in result.stderr.lower().replace(" ", "").replace("_", ""), (
        f"expected stderr to mention DivisionByZero, got: {result.stderr!r}"
    )


# ---------------------------------------------------------------------------
# TC-5: AC6 — Invalid expression error path (parametrised, 3 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "args",
    [
        ["1", "+", "+", "2"],  # double operator
        [""],  # empty expression
        ["abc"],  # unknown token
    ],
)
def test_cli_invalid_expression_error_path(args: list[str]) -> None:
    """AC6: invalid expression → clear stderr mentioning parse/error, non-zero exit, NO traceback to user."""
    result = _run_cli(*args)
    assert result.returncode != 0, "expected non-zero exit for invalid expression"
    # stdout should NOT leak a Python traceback
    assert "Traceback" not in result.stdout
    assert "Traceback" not in result.stderr
    # stderr should be non-empty
    assert result.stderr
    # stderr should mention parse/error (not the "No module named" boilerplate)
    stderr_lower = result.stderr.lower()
    assert "parse" in stderr_lower or "error" in stderr_lower, (
        f"expected stderr to mention parse/error, got: {result.stderr!r}"
    )


# ---------------------------------------------------------------------------
# TC-6: AC7 — Parametrised regression suite ≥15 cases
# (Union of TC-1, TC-2, TC-3, TC-4, TC-5 — single parametrised test for coverage)
# ---------------------------------------------------------------------------

REGRESSION_CASES = [
    # M1 baseline (TC-1)
    ("0.1 + 0.2", "0.3", 0),
    ("0.1 + 0.2 + 0.3", "0.6", 0),
    # Integer/decimal (TC-2)
    ("1.5 * 3", "4.5", 0),
    ("10 / 3", "3.333333333333333333333333333", 0),
    ("100 - 50", "50", 0),
    # Large numbers (TC-3)
    ("999999999 * 999999999", "999999998000000001", 0),
    ("0.000000001 + 0.000000002", "0.000000003", 0),
    # Division by zero (TC-4)
    ("1 / 0", "", 1),  # expect non-zero exit; stdout may be empty
    ("0 / 0", "", 1),
    # Invalid expression (TC-5)
    ("", "", 1),
    ("abc", "", 1),
    # Chained addition exactness (TC-1)
    ("0.1 + 0.2 + 0.3 + 0.4", "1.0", 0),
    # Parse error (TC-5)
    ("1 + + 2", "", 1),
    # Integer arithmetic
    ("2 + 3", "5", 0),
    # Compensating case (Issue #309 — replaces `2 ** 64`)
    ("1000000 * 1000000", "1000000000000", 0),  # large * large, no scientific notation
]


@pytest.mark.parametrize(("expr", "expected", "expected_exit"), REGRESSION_CASES)
def test_cli_regression_suite(expr: str, expected: str, expected_exit: int) -> None:
    """AC7: parametrised regression suite — 15 cases, covers M1, ops, error paths."""
    result = _run_cli(*expr.split())
    assert result.returncode == expected_exit, (
        f"expr={expr!r} got exit {result.returncode}, want {expected_exit}; "
        f"stderr={result.stderr!r}"
    )
    if expected_exit == 0:
        assert result.stdout.strip() == expected, (
            f"expr={expr!r} got stdout={result.stdout.strip()!r}, want {expected!r}"
        )
        # No inf/Infinity in stdout (regression guard)
        assert "inf" not in result.stdout.lower()
    else:
        # Error path: no Python traceback leak; stderr must be informative
        assert "Traceback" not in result.stdout
        assert "Traceback" not in result.stderr
        assert result.stderr, f"expr={expr!r}: expected non-empty stderr"
        stderr_lower = result.stderr.lower().replace(" ", "").replace("_", "")
        # Looser check than TC-4/TC-5: just expect a recognizable error keyword
        assert (
            "divisionbyzero" in stderr_lower
            or "parse" in stderr_lower
            or "error" in stderr_lower
        ), f"expr={expr!r}: expected informative stderr, got: {result.stderr!r}"
