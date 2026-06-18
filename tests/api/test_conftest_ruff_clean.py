"""STORY-003a follow-up / Issue #52 — TDD-RED: tests/api/conftest.py is lint-clean.

Discovered via PR #39 CI failure (2026-06-18T07:08Z): two ruff
violations pre-existed in main since PR #42:

  tests/api/conftest.py:58:5: SIM105 Use `contextlib.suppress(Exception)`
                              instead of `try`-`except`-`pass`
  tests/api/conftest.py:64:5: PT022 No teardown in fixture `_history_reset`,
                              use `return` instead of `yield`

This regression pin ensures they don't regress: any future change to
conftest.py that re-introduces a `try/except/pass` or a yield-only
fixture will fail this test (and the underlying CI ruff check).

Test strategy: subprocess-call `ruff check tests/api/conftest.py`
and assert exit code 0. We pin the path so a stray change elsewhere
in tests/api/ doesn't shadow the regression.
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFTEST_PY = REPO_ROOT / "tests" / "api" / "conftest.py"


def test_ruff_available() -> None:
    """ruff must be on PATH (it's a dev dep per pyproject.toml)."""
    assert shutil.which("ruff") is not None, (
        "ruff is not on PATH. Install it via `pip install -e \".[dev]\"`."
    )


def test_conftest_py_exists() -> None:
    """The file under test must exist on disk."""
    assert CONFTEST_PY.exists(), f"Expected {CONFTEST_PY} to exist."


def test_conftest_ruff_clean() -> None:
    """`ruff check tests/api/conftest.py` must exit 0.

    Issue #52 regression pin. The specific rules that previously
    failed (SIM105, PT022) are part of the project's `[tool.ruff.lint]`
    select list (see pyproject.toml). Any future rule that fires on
    conftest.py will also be caught by this test.
    """
    result = subprocess.run(
        ["ruff", "check", str(CONFTEST_PY)],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
        check=False,
    )
    assert result.returncode == 0, (
        f"ruff check on tests/api/conftest.py returned {result.returncode}.\n"
        f"stdout: {result.stdout}\n"
        f"stderr: {result.stderr}\n"
        f"Issue #52: the historical violations were SIM105 (try/except/pass) "
        f"and PT022 (yield-only fixture). The refactor uses "
        f"contextlib.suppress(Exception) + return instead of yield."
    )


def test_conftest_uses_contextlib_suppress() -> None:
    """After the fix, conftest.py must use contextlib.suppress, not try/except/pass.

    Structural pin: read the file and assert it imports contextlib and
    uses it. A future regression that reverts to try/except/pass would
    be caught by both this test AND test_conftest_ruff_clean above.
    """
    src = CONFTEST_PY.read_text(encoding="utf-8")
    assert "import contextlib" in src, (
        "tests/api/conftest.py must import contextlib (Issue #52 fix uses "
        "contextlib.suppress(Exception) instead of try/except/pass)."
    )
    assert "contextlib.suppress" in src, (
        "tests/api/conftest.py must call contextlib.suppress (SIM105 regression pin)."
    )
    # The historical anti-pattern MUST NOT reappear
    bad_pattern_1 = "except Exception:\n        pass"
    bad_pattern_2 = "except Exception:\n            pass"
    assert bad_pattern_1 not in src, (
        f"tests/api/conftest.py contains `{bad_pattern_1!r}` — the exact "
        f"anti-pattern Issue #52 fixed. Use contextlib.suppress(Exception) instead."
    )
    assert bad_pattern_2 not in src, (
        f"tests/api/conftest.py contains `{bad_pattern_2!r}` — same anti-pattern "
        f"as Issue #52, different indent level. Use contextlib.suppress(Exception)."
    )


def test_conftest_history_reset_uses_return_not_yield() -> None:
    """After the fix, _history_reset must end with `return`, not `yield` (PT022)."""
    src = CONFTEST_PY.read_text(encoding="utf-8")
    # Find the _history_reset fixture body
    start = src.find("def _history_reset")
    assert start != -1, "_history_reset fixture not found in conftest.py"
    # Extract the function body (strip the docstring first, since the docstring
    # is allowed to mention "yield" in explanatory prose).
    body = src[start:]
    # Strip the docstring (between """ ... """)
    import re
    body_no_doc = re.sub(r'""".*?"""', "", body, count=1, flags=re.DOTALL)
    # The function should end with a non-yield statement (PT022 regression pin)
    # If `yield` appears as a statement in the code (not in a docstring/comment),
    # it's a yield-only fixture = PT022 violation.
    assert not re.search(r"^\s*yield\s*$", body_no_doc, flags=re.MULTILINE), (
        "_history_reset fixture ends with `yield` (yield-only fixture) — that's "
        "the PT022 violation Issue #52 fixed. Use `return` instead."
    )
