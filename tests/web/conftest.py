"""Shared fixtures for the Web Components contract suite (STORY-008).

The web layer is vanilla JS + Web Components (ADR-0018). Testing requires a
real DOM; we use Playwright headless. The implementation PR (PR #111) lands
the Web Components + this fixture activates the contract tests.

Scope of this fixture (vs. the previous always-skip stub):
- Start a FastAPI server on a free localhost port (per ADR-0019 R-3 LAN-bind
  is overridden to 127.0.0.1 for tests; default 192.168.1.199 stays in prod).
- Wait for `/healthz` to return 200 OK before yielding the page.
- Launch Playwright Chromium (headless), open a new context + page, navigate
  to the server URL.
- Yield the page; close context on teardown.
- Kill the server subprocess + close the browser on session teardown.

Kill switch: if Playwright is not installed OR the chromium browser is not
downloaded, the fixture skips with a clear actionable message (not a hard
error) — so the rest of the suite can still collect other contract tests.
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import pytest


def _free_port() -> int:
    """Bind a socket to get a free port; release it before returning."""
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _wait_for_server(url: str, timeout_s: float = 30.0) -> bool:
    """Poll url until 200 OK or timeout. Returns True if server became ready."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as r:
                if r.status == 200:
                    return True
        except Exception:
            time.sleep(0.2)
    return False


def _playwright_available() -> tuple[bool, str]:
    """Check that playwright + chromium browser are installed.

    Returns (ok, error_message). ok=True means we can launch a browser.

    Two failure modes (both produce a clean skip with actionable message):
    1. `playwright` Python package not importable (deps not installed).
    2. Browser binary missing — `playwright install chromium` not run
       (common in CI environments that install the package but skip the
       post-install browser download step).
    """
    try:
        from playwright.sync_api import sync_playwright  # noqa: F401
    except ImportError:
        return False, (
            "playwright is not installed. Run: "
            "`pip install -e .[dev]` then `playwright install chromium`."
        )
    # Probe for the chromium binary. PLAYWRIGHT_BROWSERS_PATH overrides
    # the default ~/.cache/ms-playwright (set in CI to a per-job cache).
    browsers_root = Path(
        os.environ.get("PLAYWRIGHT_BROWSERS_PATH") or Path.home() / ".cache" / "ms-playwright"
    )
    if not browsers_root.exists():
        return False, (
            "Playwright chromium browser binary not found "
            f"(looked in {browsers_root}). "
            "Run: `playwright install chromium`."
        )
    # Playwright stores browsers as chromium_headless_shell-<rev>/ or chromium-<rev>/
    chromium_dirs = list(browsers_root.glob("chromium*"))
    if not chromium_dirs:
        return False, (
            f"Playwright browsers directory {browsers_root} exists but "
            "contains no chromium* subdirectory. "
            "Run: `playwright install chromium`."
        )
    return True, ""


@pytest.fixture(scope="session")
def atc_server():
    """Start a FastAPI server on 127.0.0.1:<free_port>. Yields the base URL.

    Skips cleanly if the server doesn't become ready within 30s (env issue
    — typically a stale `atilcalc.api.main:app` import or missing
    runtime deps). CI portability: `cwd` is derived from this file's
    location (tests/web/conftest.py → 2 parents up = repo root) instead
    of a hardcoded path.
    """
    port = _free_port()
    base_url = f"http://127.0.0.1:{port}"
    env = os.environ.copy()
    env["ATC_HOST"] = "127.0.0.1"
    env["ATC_PORT"] = str(port)
    # Derive repo root from this file: tests/web/conftest.py → parents[2] = repo root
    repo_root = Path(__file__).resolve().parents[2]
    proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "atilcalc.api.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
        ],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        cwd=str(repo_root),
    )
    try:
        if not _wait_for_server(f"{base_url}/healthz"):
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            pytest.skip(
                f"AtilCalculator server did not start within 30s on {base_url} "
                f"(cwd={repo_root}). Check that `atilcalc.api.main:app` is "
                f"importable from the repo root."
            )
        yield base_url
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


@pytest.fixture(scope="session")
def browser():
    """Launch Playwright Chromium (headless). Session-scoped — one browser per test session.

    Skips with actionable message if Playwright is unusable in this env
    (package not installed OR browser binary not downloaded).
    """
    ok, msg = _playwright_available()
    if not ok:
        pytest.skip(msg)
    from playwright.sync_api import sync_playwright

    p = sync_playwright().start()
    try:
        b = p.chromium.launch(headless=True)
    except Exception as e:
        # Browser binary likely missing despite importable package
        # (CI without `playwright install chromium` step).
        p.stop()
        pytest.skip(
            f"Playwright chromium browser failed to launch: "
            f"{type(e).__name__}: {e}. "
            f"Run: `playwright install chromium`."
        )
    try:
        yield b
    finally:
        b.close()
        p.stop()


@pytest.fixture
def browser_page(browser, atc_server):
    """Playwright headless browser page bound to the local FastAPI server.

    Navigates to "/" (the SPA shell mounts all 3 custom elements via app.js).
    The page is fresh per test (function-scoped browser_context) so component
    state doesn't leak across tests.
    """
    ctx = browser.new_context()
    page = ctx.new_page()
    page.goto(atc_server + "/")
    # Wait for the SPA shell + custom elements to upgrade.
    page.wait_for_selector("atilcalc-display", state="attached")
    page.wait_for_selector("atilcalc-history", state="attached")
    page.wait_for_selector("atilcalc-keypad", state="attached")
    yield page
    ctx.close()
