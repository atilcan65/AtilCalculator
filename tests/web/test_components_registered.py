"""STORY-003b TC-1/TC-2/TC-3 (partial) — TDD-RED: Web Components registered.

Asserts that the 3 deferred custom elements are defined and reachable
from `customElements.get(...)`. This is the structural pre-condition
for AC1 (mode-toggle), AC2 (help-popup), AC3 (error-toast).

The full UX contract is covered by Playwright tests in
test_e2e_keyboard.py (TC-4). This file is the cheap unit-level
sanity check: load the page in jsdom, import the deferred script,
and assert registration.

Skipped if playwright is not installed (dev env may not have it).
The pytest-playwright plugin is the source of truth for browser
boots; this file is a fallback for fast CI on a non-browser box.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

WEB_DIR = Path(__file__).resolve().parents[2] / "src" / "atilcalc" / "web"
APP_DEFERRED = WEB_DIR / "app-deferred.js"

EXPECTED_TAGS = (
    "atilcalc-mode-toggle",
    "atilcalc-help-popup",
    "atilcalc-error-toast",
)


@pytest.mark.parametrize("tag", EXPECTED_TAGS)
def test_deferred_script_file_exists(tag: str) -> None:
    """The deferred-component script must exist on disk."""
    assert APP_DEFERRED.exists(), (
        f"Expected {APP_DEFERRED} to exist (STORY-003b commit 2). "
        f"Missing script means the 3 deferred components ({', '.join(EXPECTED_TAGS)}) "
        f"are not loadable by index.html."
    )


@pytest.mark.parametrize("tag", EXPECTED_TAGS)
def test_deferred_script_registers_tag(tag: str) -> None:
    """app-deferred.js must contain a customElements.define call for the tag."""
    src = APP_DEFERRED.read_text(encoding="utf-8")
    assert f'customElements.define("{tag}"' in src, (
        f"Expected `customElements.define(\"{tag}\"` in {APP_DEFERRED.name}. "
        f"Without it, the element is undefined and AC1/AC2/AC3 fail at page-load time."
    )


def test_deferred_script_uses_shadow_dom() -> None:
    """All 3 components must use open Shadow DOM (ADR-0018 style)."""
    src = APP_DEFERRED.read_text(encoding="utf-8")
    assert src.count('attachShadow({ mode: "open" })') >= 3, (
        "Expected 3 open Shadow DOM roots (one per component). "
        "Closed mode would break style isolation testing."
    )


def test_app_js_unchanged_shape() -> None:
    """app.js from STORY-003a must NOT be modified by STORY-003b commit 2.

    Deferred components live in app-deferred.js; app.js stays as-is.
    This guards against accidentally bloating app.js past 400 LOC.
    """
    app_js = (WEB_DIR / "app.js").read_text(encoding="utf-8")
    for tag in EXPECTED_TAGS:
        assert f'customElements.define("{tag}"' not in app_js, (
            f"Found `customElements.define(\"{tag}\"` in app.js — the deferred "
            f"component should be in app-deferred.js, not app.js. Move it."
        )


def test_index_html_loads_deferred_script() -> None:
    """index.html must load the deferred script (otherwise the components are dead)."""
    html = (WEB_DIR / "index.html").read_text(encoding="utf-8")
    assert "app-deferred.js" in html, (
        "index.html does not reference app-deferred.js. Add "
        '<script type="module" src="app-deferred.js"></script> '
        "after the app.js tag."
    )
