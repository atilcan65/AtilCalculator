"""STORY-003b TC-4 — TDD-RED: Playwright E2E for keyboard input flow.

AC4: an E2E test that exercises digit entry → result via keyboard.

This is the load-bearing regression pin for the deferred-components
commit. It boots a real uvicorn server in a subprocess (on a free
port), opens Chromium against http://127.0.0.1:<port>/, dispatches
real keyboard events, and asserts the <atilcalc-display> result.

The test is skipped if `playwright` is not installed (CI may not
have a browser). The full install command is:
    pip install -e ".[dev]" && playwright install chromium
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

playwright = pytest.importorskip("playwright", reason="playwright not installed")
from playwright.sync_api import (  # noqa: E402  (importorskip above)
    Browser,
    sync_playwright,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_SERVER_SH = REPO_ROOT / "scripts" / "run-server.sh"


def _free_port() -> int:
    """Return an OS-allocated free TCP port (SO_REUSEADDR)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _wait_for_healthz(base_url: str, timeout_s: float = 5.0) -> bool:
    """Poll /healthz until 200 or timeout. Returns True on 200."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(f"{base_url}/healthz", timeout=0.5) as r:
                if r.status == 200:
                    return True
        except Exception:
            time.sleep(0.1)
    return False


@pytest.fixture(scope="module")
def server():
    """Boot a uvicorn subprocess on a free port, return its base URL.

    The server uses ATC_HOST=127.0.0.1 (loopback, dev-safe per ADR-0019
    security boundary) and a random free port. Cleanup kills the
    subprocess on teardown.
    """
    if not RUN_SERVER_SH.exists():
        pytest.skip(f"scripts/run-server.sh missing (expected at {RUN_SERVER_SH})")
    port = _free_port()
    env = {
        **os.environ,
        "ATC_HOST": "127.0.0.1",
        "ATC_PORT": str(port),
        "PATH": os.environ.get("PATH", ""),
    }
    proc = subprocess.Popen(
        ["bash", str(RUN_SERVER_SH)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    base_url = f"http://127.0.0.1:{port}"
    try:
        if not _wait_for_healthz(base_url, timeout_s=8.0):
            stdout, stderr = proc.communicate(timeout=1)
            pytest.fail(
                f"Server did not become healthy at {base_url} within 8s.\n"
                f"stdout: {stdout.decode(errors='replace')}\n"
                f"stderr: {stderr.decode(errors='replace')}"
            )
        yield base_url
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=1)


@pytest.fixture(scope="module")
def browser() -> Browser:
    """Launch a Chromium browser for the E2E session."""
    with sync_playwright() as p:
        b = p.chromium.launch(headless=True)
        try:
            yield b
        finally:
            b.close()


def _result_text(page) -> str:
    """Read the result line of <atilcalc-display> (in shadow DOM)."""
    return page.evaluate(
        """() => {
            const display = document.querySelector('atilcalc-display');
            if (!display || !display.shadowRoot) return '';
            const result = display.shadowRoot.getElementById('result');
            return result ? result.textContent : '';
        }"""
    )


def test_e2e_simple_addition(server, browser) -> None:
    """AC4 happy path: `1` `+` `2` `Enter` → result `3`."""
    page = browser.new_page()
    try:
        page.goto(server + "/", wait_until="load")
        page.wait_for_selector("atilcalc-display")
        # Bring the page to the front so keyboard events go to it.
        page.bring_to_front()
        page.locator("body").click()  # focus the page
        for key in ("1", "+", "2", "Enter"):
            page.keyboard.press(key)
        # Wait for the FSM to call /api/evaluate and update the display.
        page.wait_for_function(
            "() => { const d = document.querySelector('atilcalc-display');"
            "  return d && d.shadowRoot && d.shadowRoot.getElementById('result')"
            "    && d.shadowRoot.getElementById('result').textContent === '3'; }",
            timeout=3000,
        )
        assert _result_text(page) == "3", f"expected '3', got {_result_text(page)!r}"
    finally:
        page.close()


def test_e2e_three_term_addition(server, browser) -> None:
    """AC4 second case: `1` `+` `2` `+` `3` `Enter` → result `6`."""
    page = browser.new_page()
    try:
        page.goto(server + "/", wait_until="load")
        page.wait_for_selector("atilcalc-display")
        page.bring_to_front()
        page.locator("body").click()
        for key in ("1", "+", "2", "+", "3", "Enter"):
            page.keyboard.press(key)
        page.wait_for_function(
            "() => { const d = document.querySelector('atilcalc-display');"
            "  return d && d.shadowRoot && d.shadowRoot.getElementById('result')"
            "    && d.shadowRoot.getElementById('result').textContent === '6'; }",
            timeout=3000,
        )
        assert _result_text(page) == "6", f"expected '6', got {_result_text(page)!r}"
    finally:
        page.close()


def test_e2e_multiplication(server, browser) -> None:
    """AC4 third case: `7` `*` `8` `Enter` → result `56`."""
    page = browser.new_page()
    try:
        page.goto(server + "/", wait_until="load")
        page.wait_for_selector("atilcalc-display")
        page.bring_to_front()
        page.locator("body").click()
        for key in ("7", "*", "8", "Enter"):
            page.keyboard.press(key)
        page.wait_for_function(
            "() => { const d = document.querySelector('atilcalc-display');"
            "  return d && d.shadowRoot && d.shadowRoot.getElementById('result')"
            "    && d.shadowRoot.getElementById('result').textContent === '56'; }",
            timeout=3000,
        )
        assert _result_text(page) == "56", f"expected '56', got {_result_text(page)!r}"
    finally:
        page.close()
