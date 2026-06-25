"""Parametrised pytest regression suite for STORY-316 (console-script install).

TDD discipline:
- This file is the TDD RED deliverable: it MUST FAIL before
  ``pyproject.toml`` has ``[project.scripts] atilcalc = "atilcalc.cli:main"``
  AND ``pip install -e .[dev]`` has been run.
- The implementer adds the ``[project.scripts]`` entry (and the spec's
  README update); this suite turns GREEN after a fresh
  ``pip install -e .[dev]``.

Refs: Issue #316, ARCH-310/311 config-alignment reviews, ADR-0017 §Tech stack.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]


def _console_script_path() -> str | None:
    """Locate the ``atilcalc`` console-script entry on PATH.

    Returns the resolved path (or None if not installed).
    """
    return shutil.which("atilcalc")


def _run_via_module(*args: str, timeout: float = 10.0) -> subprocess.CompletedProcess:
    """Invoke ``python -m atilcalc`` — the always-available entry path."""
    return subprocess.run(
        [sys.executable, "-m", "atilcalc", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=REPO_ROOT,
    )


def _run_via_console_script(*args: str, timeout: float = 10.0) -> subprocess.CompletedProcess:
    """Invoke the installed ``atilcalc`` console-script entry."""
    return subprocess.run(
        ["atilcalc", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


# Skip the whole module when the console-script is not installed.
# This mirrors the `python -m atilcalc` portability pattern used by
# tests/cli/test_basic_arithmetic.py — tests skip cleanly when the
# install step has not been run, instead of failing the suite.
pytestmark = pytest.mark.skipif(
    _console_script_path() is None,
    reason=(
        "atilcalc console-script not installed (run `pip install -e .[dev]` first). "
        "See Issue #316 spec §How sub-task 2."
    ),
)


# ---------------------------------------------------------------------------
# TC-1: AC1 — `which atilcalc` returns a path after `pip install -e .[dev]`
# ---------------------------------------------------------------------------


def test_console_script_installed() -> None:
    """AC1: ``which atilcalc`` returns a path containing 'atilcalc'.

    Sister test to the shell-script d-test in scripts/tests/d036d-cli-console-script.sh.
    The shell sister covers the install-script side (which check); this pytest
    sister covers the same contract from the Python-side for symmetry with
    tests/cli/test_basic_arithmetic.py etc.
    """
    path = _console_script_path()
    assert path is not None, "atilcalc console-script not on PATH"
    assert "atilcalc" in path, f"unexpected resolved path: {path}"
    assert Path(path).exists(), f"resolved path does not exist: {path}"


# ---------------------------------------------------------------------------
# TC-2: AC2 — `atilcalc 1 + 2` → stdout `3` (matches `python -m atilcalc 1 + 2`)
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("1 + 2", "3"),  # baseline sanity
        ("0.1 + 0.2", "0.3"),  # M1 acceptance (exact Decimal precision)
        ("10 / 4", "2.5"),  # division (matches python -m baseline)
    ],
)
def test_console_script_matches_module_invocation(expr: str, expected: str) -> None:
    """AC2: console-script behavior mirrors ``python -m atilcalc``.

    Drift detector: catches cases where the console-script entry accidentally
    shadows the module path (e.g., wrong callable, wrong argv handling).
    """
    via_module = _run_via_module(expr)
    via_script = _run_via_console_script(expr)

    assert via_module.returncode == 0, (
        f"module invocation failed: rc={via_module.returncode} "
        f"stderr={via_module.stderr!r}"
    )
    assert via_script.returncode == via_module.returncode, (
        f"exit-code drift: module={via_module.returncode} "
        f"script={via_script.returncode} stderr={via_script.stderr!r}"
    )
    # Stdout must match — drift detector for argv handling + entry point.
    assert via_script.stdout.strip() == via_module.stdout.strip(), (
        f"stdout drift for expr={expr!r}: "
        f"module={via_module.stdout!r} script={via_script.stdout!r}"
    )
    # Sanity: expected value matches the M1 baseline.
    assert via_script.stdout.strip() == expected, (
        f"unexpected result for expr={expr!r}: got={via_script.stdout!r} "
        f"expected={expected!r}"
    )
