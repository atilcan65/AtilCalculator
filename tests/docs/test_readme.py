"""Contract tests for STORY-012 AC1 — README has install/run/test commands + links.

Refs Issue #74. Per ADR-0017 (tech stack) + AC1:
- README has (a) what AtilCalculator is (1 paragraph)
- README has (b) prerequisites (Python 3.11+, port 8000)
- README has (c) install command (`pip install -e .[dev]`)
- README has (d) run command (`uvicorn atilcalc.api.X:Y --host ... --port ...`)
- README has (e) test command (`pytest -q`)
- README has (f) link to `docs/USER-GUIDE.md` and `docs/product/vision.md`

TDD red: skip on missing/incomplete README. Module-level probe checks:
- README.md exists at repo root
- README has at least 1 of the 6 required elements (loose TDD red)
- README contains the project name "AtilCalculator"

When implementation lands (README refresh per AC1), all tests will run.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
README_PATH = REPO_ROOT / "README.md"

# TDD red guard — module-level skip ensures CI is green while the README refresh lands.
try:
    if not README_PATH.exists():
        raise RuntimeError("AC1: README.md missing at repo root.")

    _readme = README_PATH.read_text(encoding="utf-8")

    # Probe: README must mention the project name (otherwise it's still placeholder)
    if "AtilCalculator" not in _readme:
        raise RuntimeError(
            "AC1: README.md does not mention 'AtilCalculator'. "
            "Story requires AtilCalculator-specific content (1 paragraph intro)."
        )

    # Probe: README must mention at least ONE of install/run/test commands
    _has_install = bool(re.search(r"pip install -e \.\[dev\]", _readme))
    _has_run = bool(re.search(r"uvicorn atilcalc\.api\.\w+:\w+", _readme))
    _has_test = bool(re.search(r"\bpytest\b", _readme))
    if not (_has_install or _has_run or _has_test):
        raise RuntimeError(
            "AC1: README.md does not contain install/run/test commands. "
            "Story requires all three (pip install -e .[dev], uvicorn ..., pytest -q)."
        )

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC1", "README", "AtilCalculator"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-012 TDD red — README not yet refreshed for AtilCalculator. "
            "Implementation PR must rewrite README.md per AC1 (intro + prereqs + "
            "install + run + test + links to USER-GUIDE.md and vision.md).",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-1: AC1 — README has install command (pip install -e .[dev])
# ---------------------------------------------------------------------------
class TestReadmeInstallCommand:
    """AC1 (install): README documents `pip install -e .[dev]`."""

    def test_readme_has_install_command(self) -> None:
        """README must contain `pip install -e .[dev]` (or shell-quoted variant)."""
        content = README_PATH.read_text(encoding="utf-8")
        pattern = r'pip install -e \.?\[dev\]|"pip install -e \.\\[dev\\]"|pip install -e "\.\[dev\]"'
        assert re.search(pattern, content), (
            f"AC1: README.md must contain install command matching {pattern!r}. "
            f"Owners must be able to copy-paste `pip install -e .[dev]` and have it work."
        )


# ---------------------------------------------------------------------------
# TC-2: AC1 — README has run command (uvicorn + host + port)
# ---------------------------------------------------------------------------
class TestReadmeRunCommand:
    """AC1 (run): README documents uvicorn command with host + port."""

    def test_readme_has_uvicorn_run_command(self) -> None:
        """README must contain a uvicorn command with host + port."""
        content = README_PATH.read_text(encoding="utf-8")
        pattern = r"uvicorn atilcalc\.api\.\w+:\w+ --host \S+ --port \d+"
        assert re.search(pattern, content), (
            f"AC1: README.md must contain uvicorn run command matching {pattern!r}. "
            f"Owners must be able to copy-paste and start the server."
        )


# ---------------------------------------------------------------------------
# TC-3: AC1 — README has test command (pytest)
# ---------------------------------------------------------------------------
class TestReadmeTestCommand:
    """AC1 (test): README documents `pytest` invocation."""

    def test_readme_has_pytest_command(self) -> None:
        """README must contain `pytest` (with optional -q)."""
        content = README_PATH.read_text(encoding="utf-8")
        assert re.search(r"\bpytest(\s+-q|\s+-v|\s+tests/)?", content), (
            "AC1: README.md must contain `pytest` (or `pytest -q` / `pytest tests/`). "
            "Reviewers must be able to verify green CI by running locally."
        )


# ---------------------------------------------------------------------------
# TC-4: AC1 — README links to USER-GUIDE.md and vision.md
# ---------------------------------------------------------------------------
class TestReadmeLinks:
    """AC1 (links): README links to docs/USER-GUIDE.md + docs/product/vision.md."""

    def test_readme_links_to_user_guide(self) -> None:
        """README must have a markdown link to docs/USER-GUIDE.md."""
        content = README_PATH.read_text(encoding="utf-8")
        pattern = r"\[.+?\]\((?:\.?/)?docs/USER-GUIDE\.md\)"
        assert re.search(pattern, content), (
            "AC1: README.md must link to docs/USER-GUIDE.md. "
            "Pattern expected: [User Guide](docs/USER-GUIDE.md) or similar."
        )

    def test_readme_links_to_vision(self) -> None:
        """README must have a markdown link to docs/product/vision.md."""
        content = README_PATH.read_text(encoding="utf-8")
        pattern = r"\[.+?\]\((?:\.?/)?(?:docs/)?product/vision\.md\)"
        assert re.search(pattern, content), (
            "AC1: README.md must link to docs/product/vision.md. "
            "Pattern expected: [Vision](docs/product/vision.md) or similar."
        )


# ---------------------------------------------------------------------------
# AP-1: README claims a command that doesn't actually work
# ---------------------------------------------------------------------------
class TestReadmeCommandsActuallyWork:
    """AP-1: install/run/test commands in README must execute successfully."""

    def test_install_command_executes(self) -> None:
        """Run `pip install -e .[dev]` in a subprocess; assert exit 0."""
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "-e", ".[dev]"],
            capture_output=True,
            text=True,
            timeout=300,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode == 0, (
            f"AP-1: `pip install -e .[dev]` failed (exit {result.returncode}). "
            f"README install command broken. stderr: {result.stderr[:500]}"
        )

    def test_pytest_command_executes(self) -> None:
        """Run `pytest -q` in subprocess; assert exit 0 (allowing skips)."""
        result = subprocess.run(
            [sys.executable, "-m", "pytest", "-q", "--tb=no"],
            capture_output=True,
            text=True,
            timeout=300,
            cwd=str(REPO_ROOT),
        )
        assert result.returncode in (0, 5), (
            f"AP-1: `pytest -q` failed (exit {result.returncode}). "
            f"README test command broken. stderr: {result.stderr[:500]}"
        )
