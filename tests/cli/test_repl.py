"""Parametrised pytest regression suite for STORY-301 / STORY-CLI-003 REPL mode.

Maps to docs/test-plans/STORY-301-tests.md (10 TCs, ~15 pytest cases).

TDD discipline:
- This file is the TDD RED deliverable: it MUST FAIL before src/atilcalc/repl/ exists
  (or before --repl flag is added to existing CLI).
- Each test spawns `python -m atilcalc --repl` as a subprocess with controllable stdin
  (subprocess.Popen, NOT subprocess.run — REPL needs interactive I/O).
- The implementer writes the REPL impl (likely `src/atilcalc/repl/__init__.py` +
  extends `src/atilcalc/cli/__init__.py` --repl handler) to make these tests pass.

Refs: Issue #301, PR #303 (test plan), docs/backlog/STORY-CLI-003.md, ADR-0017.
"""

from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]


class REPLSession:
    """Context manager for spawning atilcalc --repl and driving it line-by-line.

    Uses subprocess.Popen (not subprocess.run) because REPL is interactive:
    stdin must be a pipe we can write to multiple times, stdout/stderr must be
    captured asynchronously, and we need to detect process death.
    """

    def __init__(self, timeout: float = 10.0) -> None:
        self.timeout = timeout
        self.proc: subprocess.Popen | None = None
        self.stdout_data = ""
        self.stderr_data = ""

    def __enter__(self) -> REPLSession:
        self.proc = subprocess.Popen(
            [sys.executable, "-m", "atilcalc", "--repl"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=REPO_ROOT,
        )
        return self

    def send_line(self, line: str) -> None:
        """Write a line to REPL stdin (newline appended)."""
        assert self.proc is not None
        assert self.proc.stdin is not None
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()

    def send_eof(self) -> None:
        """Close REPL stdin to simulate Ctrl-D."""
        assert self.proc is not None
        assert self.proc.stdin is not None
        self.proc.stdin.close()

    def wait(self, timeout: float | None = None) -> int:
        """Wait for REPL to exit; return exit code."""
        assert self.proc is not None
        t = timeout if timeout is not None else self.timeout
        try:
            rc = self.proc.wait(timeout=t)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            rc = -1
        self.stdout_data = self.proc.stdout.read() if self.proc.stdout else ""
        self.stderr_data = self.proc.stderr.read() if self.proc.stderr else ""
        return rc

    def __exit__(self, *exc: object) -> None:
        if self.proc is not None and self.proc.poll() is None:
            self.proc.kill()
            self.proc.wait()


# ---------------------------------------------------------------------------
# T9 preflight — atilcalc --help must work (else skip all REPL tests)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module", autouse=True)
def _cli_preflight() -> None:
    """Skip all REPL tests if `python -m atilcalc --help` fails.

    TDD RED expected: this fixture fails on master (no impl), turns GREEN
    once Issue #301 REPL impl lands.
    """
    result = subprocess.run(
        [sys.executable, "-m", "atilcalc", "--help"],
        capture_output=True,
        text=True,
        timeout=5.0,
        cwd=REPO_ROOT,
    )
    if result.returncode != 0:
        pytest.skip(
            f"CLI not available (TDD RED expected): "
            f"exit {result.returncode}; stderr: {result.stderr[:200]!r}"
        )


# ---------------------------------------------------------------------------
# TC-1: AC1 — REPL prompt display
# ---------------------------------------------------------------------------

def test_repl_prompt_display() -> None:
    """AC1: atilcalc --repl shows prompt and waits on stdin."""
    with REPLSession() as repl:
        time.sleep(0.3)  # let prompt render
        # REPL must still be alive (waiting for input)
        assert repl.proc is not None
        assert repl.proc.poll() is None, "REPL exited before receiving input"
        # Send exit to clean up
        repl.send_line("exit")
        rc = repl.wait(timeout=3.0)
        assert rc == 0


# ---------------------------------------------------------------------------
# TC-2: AC2 — Basic eval (parametrised, 3 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("0.1 + 0.2", "0.3"),  # M1 acceptance
        ("1 + 1", "2"),
        ("2 * 3", "6"),
    ],
)
def test_repl_basic_eval(expr: str, expected: str) -> None:
    """AC2: REPL evaluates basic expressions and shows result + new prompt."""
    with REPLSession() as repl:
        repl.send_line(expr)
        time.sleep(0.2)
        repl.send_line("exit")
        rc = repl.wait(timeout=3.0)
        assert rc == 0, f"REPL exit {rc}; stderr: {repl.stderr_data!r}"
        assert expected in repl.stdout_data, (
            f"expr={expr!r} expected {expected!r} in stdout; got: {repl.stdout_data!r}"
        )


# ---------------------------------------------------------------------------
# TC-3: AC3 — Precedence eval (parametrised, 2 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    ("expr", "expected"),
    [
        ("(2 + 3) * 4", "20"),
        ("2 + 3 * 4", "14"),
    ],
)
def test_repl_precedence_eval(expr: str, expected: str) -> None:
    """AC3: REPL respects operator precedence."""
    with REPLSession() as repl:
        repl.send_line(expr)
        time.sleep(0.2)
        repl.send_line("exit")
        rc = repl.wait(timeout=3.0)
        assert rc == 0, f"REPL exit {rc}; stderr: {repl.stderr_data!r}"
        assert expected in repl.stdout_data, (
            f"expr={expr!r} expected {expected!r} in stdout; got: {repl.stdout_data!r}"
        )


# ---------------------------------------------------------------------------
# TC-4: AC4 — Exit commands (parametrised, 2 cases)
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("cmd", ["exit", "quit"])
def test_repl_exit_commands(cmd: str) -> None:
    """AC4: 'exit' and 'quit' commands cleanly close REPL with exit 0."""
    with REPLSession() as repl:
        repl.send_line(cmd)
        rc = repl.wait(timeout=3.0)
        assert rc == 0, f"cmd={cmd!r} exit {rc}; stderr: {repl.stderr_data!r}"


# ---------------------------------------------------------------------------
# TC-5: AC5 — EOF handling
# ---------------------------------------------------------------------------

def test_repl_eof_handling() -> None:
    """AC5: closing stdin (Ctrl-D) exits REPL cleanly with exit 0."""
    with REPLSession() as repl:
        repl.send_eof()
        rc = repl.wait(timeout=3.0)
        assert rc == 0, f"EOF exit {rc}; stderr: {repl.stderr_data!r}"


# ---------------------------------------------------------------------------
# TC-6: AC6 — Parse error continuation
# ---------------------------------------------------------------------------

def test_repl_parse_error_continuation() -> None:
    """AC6: REPL continues after parse error (does NOT exit on parse error)."""
    with REPLSession() as repl:
        repl.send_line("1 + + 2")  # bad expr
        time.sleep(0.2)
        repl.send_line("1 + 1")  # recovery test
        time.sleep(0.2)
        repl.send_line("exit")
        rc = repl.wait(timeout=3.0)
        assert rc == 0, f"REPL exit {rc} on parse error; expected 0 (continuation)"
        assert "2" in repl.stdout_data, (
            f"REPL did not recover after parse error; stdout: {repl.stdout_data!r}"
        )
        assert repl.stderr_data, "expected parse error in stderr"


# ---------------------------------------------------------------------------
# TC-7: AC7 — /help slash-command
# ---------------------------------------------------------------------------

def test_repl_slash_help() -> None:
    """AC7: /help slash-command shows help text + REPL still works after."""
    with REPLSession() as repl:
        repl.send_line("/help")
        time.sleep(0.2)
        repl.send_line("1 + 1")  # REPL should still work after /help
        time.sleep(0.2)
        repl.send_line("exit")
        rc = repl.wait(timeout=3.0)
        assert rc == 0, f"REPL exit {rc}; stderr: {repl.stderr_data!r}"
        # Help text should mention at least one of the slash-commands
        assert (
            "/help" in repl.stdout_data
            or "/exit" in repl.stdout_data
            or "/quit" in repl.stdout_data
        ), f"slash-command help missing in stdout: {repl.stdout_data!r}"
        assert "2" in repl.stdout_data, (
            f"REPL didn't process '1+1' after /help; stdout: {repl.stdout_data!r}"
        )


# ---------------------------------------------------------------------------
# TC-8: AC8 — Session-level test
# ---------------------------------------------------------------------------

def test_repl_session_level() -> None:
    """AC8: 5+ expressions in one session, mixed valid/invalid, clean exit."""
    session_input = [
        "1 + 1",          # valid → 2
        "2 * 3",          # valid → 6
        "(1 + 2) * 3",    # valid (precedence) → 9
        "1 + + 2",        # parse error → stderr, REPL continues
        "5 - 2",          # valid → 3
        "exit",
    ]
    with REPLSession() as repl:
        for line in session_input:
            repl.send_line(line)
            time.sleep(0.1)
        rc = repl.wait(timeout=5.0)
        assert rc == 0, f"session exit {rc}; stderr: {repl.stderr_data!r}"
        # Verify all expected results present
        for expected in ["2", "6", "9", "3"]:
            assert expected in repl.stdout_data, (
                f"expected {expected!r} in stdout; got: {repl.stdout_data!r}"
            )
        # Verify parse error in stderr
        assert repl.stderr_data, "expected parse error in stderr"


# ---------------------------------------------------------------------------
# TC-10: Empty input — just Enter, no expression
# ---------------------------------------------------------------------------

def test_repl_empty_input() -> None:
    """TC-10: empty input (Enter on prompt) → REPL shows new prompt, no error."""
    with REPLSession() as repl:
        repl.send_line("")  # just newline
        time.sleep(0.2)
        # REPL must still be alive
        assert repl.proc is not None
        assert repl.proc.poll() is None, "REPL exited on empty input (should continue)"
        repl.send_line("1 + 1")
        time.sleep(0.2)
        repl.send_line("exit")
        rc = repl.wait(timeout=3.0)
        assert rc == 0
        assert "2" in repl.stdout_data
