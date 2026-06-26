"""Parametrised pytest regression suite for ``atilcalc --version`` flag.

Issue: #382 (RETRO-005 #18c batch, PR #381 obs #381.4) — Sprint 7+ nice-to-have.

Why this test exists
--------------------
Per Issue #382 §381.4 rationale: ``atilcalc --version`` aids observability (lens
(f)) for downstream tooling (e.g., bug reports include the version). Sister
pattern to PR #381 / STORY-316 console-script — same entry point, just a
meta-flag.

TDD discipline:
- This file is the TDD RED deliverable: it MUST FAIL before ``--version`` is
  handled in ``src/atilcalc/cli/__init__.py``.
- Tests invoke ``python -m atilcalc --version`` (portable; no install step).
- After implementing the ``--version`` handler in ``main()``, this suite turns
  GREEN.

Refs: Issue #382 (PR #381 obs #381.4), ADR-0017 §Tech stack, src/atilcalc/__init__.py
(``__version__`` source of truth).
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]


def _run_cli(*args: str, timeout: float = 10.0) -> subprocess.CompletedProcess:
    """Invoke ``python -m atilcalc`` with the given args; return CompletedProcess.

    Uses ``python -m`` (not the installed ``atilcalc`` binary) for portability:
    tests run from a fresh checkout without ``pip install -e .[dev]`` first.
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
# TC-1: --version prints the version and exits 0
# ---------------------------------------------------------------------------


def test_version_flag_prints_version_and_exits_zero() -> None:
    """``atilcalc --version`` prints ``atilcalc <version>`` to stdout, exits 0.

    The ``__version__`` from src/atilcalc/__init__.py is the single source of
    truth. Output format: ``atilcalc X.Y.Z`` (one line, no trailing junk).
    """
    result = _run_cli("--version")
    assert result.returncode == 0, (
        f"--version must exit 0, got rc={result.returncode}: stderr={result.stderr!r}"
    )
    # Import the version constant directly so we don't depend on stdout parsing
    # to know what version is expected (single source of truth: atilcalc.__version__).
    from atilcalc import __version__

    expected_line = f"atilcalc {__version__}"
    assert result.stdout.strip() == expected_line, (
        f"--version stdout must be exactly {expected_line!r}, "
        f"got {result.stdout.strip()!r}"
    )


# ---------------------------------------------------------------------------
# TC-2: --version does NOT require an expression
# ---------------------------------------------------------------------------


def test_version_flag_works_without_expression() -> None:
    """``atilcalc --version`` does not trigger the empty-expression fallback.

    Regression guard: without the explicit ``--version`` handler, argparse would
    interpret ``--version`` as the start of the expression (nargs=REMAINDER), then
    fall through to the engine which would parse-error on "--version".
    """
    result = _run_cli("--version")
    # Empty-expression fallback returns rc=1 with "parse error: empty..."
    # We must NOT hit that path.
    assert "parse error" not in result.stderr, (
        f"--version must not trigger parse-error fallback; stderr={result.stderr!r}"
    )
    assert result.returncode != 1, (
        f"--version must not exit with engine-error code 1; "
        f"rc={result.returncode} stderr={result.stderr!r}"
    )


# ---------------------------------------------------------------------------
# TC-3: --version stdout matches semver-ish pattern
# ---------------------------------------------------------------------------


def test_version_output_matches_semver_pattern() -> None:
    """``atilcalc --version`` stdout matches ``^atilcalc \\d+\\.\\d+\\.\\d+$``.

    Loose version pattern (3 dotted integers) — locks the format so downstream
    tools can parse it. If we adopt CalVer later, the pattern can be loosened.
    """
    result = _run_cli("--version")
    assert result.returncode == 0, (
        f"--version must exit 0; rc={result.returncode} stderr={result.stderr!r}"
    )
    pattern = r"^atilcalc \d+\.\d+\.\d+$"
    assert re.match(pattern, result.stdout.strip()), (
        f"--version stdout {result.stdout.strip()!r} must match {pattern!r} "
        f"(downstream tooling depends on parseable format)"
    )


# ---------------------------------------------------------------------------
# TC-4: --version takes precedence over an expression
# ---------------------------------------------------------------------------


def test_version_flag_takes_precedence_over_expression() -> None:
    """``atilcalc --version 1 + 2`` still prints version (flag wins).

    Sister test to test_basic_arithmetic.py: even when extra args are present,
    ``--version`` must be honored (mirrors the ``--help`` / ``--repl``
    precedence pattern in src/atilcalc/cli/__init__.py).
    """
    result = _run_cli("--version", "1", "+", "2")
    assert result.returncode == 0, (
        f"--version with extra args must exit 0; "
        f"rc={result.returncode} stderr={result.stderr!r}"
    )
    from atilcalc import __version__

    assert result.stdout.strip() == f"atilcalc {__version__}", (
        f"--version with extra args must still print version; "
        f"got {result.stdout.strip()!r}"
    )
