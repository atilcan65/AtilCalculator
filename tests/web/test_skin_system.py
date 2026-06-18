"""STORY-003b TC-1/TC-6 — TDD-RED: skin system + transition contract.

AC1: clicking <atilcalc-mode-toggle> swaps the skin (dark ↔ light ↔ retro).
AC6: transition completes in <500ms with no visual flicker.

This file is the structural pre-condition check (file exists, exports a
listener, has the 3 palettes). The full Playwright transition timing
test lands in test_e2e_keyboard.py TC-4 / test_skin_transition.py TC-6.
"""

from __future__ import annotations

from pathlib import Path

import pytest

WEB_DIR = Path(__file__).resolve().parents[2] / "src" / "atilcalc" / "web"
THEME_JS = WEB_DIR / "theme.js"

EXPECTED_SKINS = ("dark", "light", "retro")


def test_theme_js_exists() -> None:
    """theme.js must exist on disk."""
    assert THEME_JS.exists(), (
        f"Expected {THEME_JS} to exist (STORY-003b commit 3). "
        f"It owns the skin swap and CSS custom property transitions."
    )


@pytest.mark.parametrize("skin", EXPECTED_SKINS)
def test_theme_js_defines_palette(skin: str) -> None:
    """theme.js must export a PALETTE object with entries for each skin."""
    src = THEME_JS.read_text(encoding="utf-8")
    # JS object literal style: `dark: {` (no quotes around the key).
    # Also accept quoted forms for completeness.
    has_entry = (
        f"{skin}:" in src
        or f'"{skin}":' in src
        or f"'{skin}':" in src
    )
    assert has_entry, (
        f"theme.js must define a palette entry for skin={skin!r}. "
        f"Missing palette means the <atilcalc-mode-toggle> click will be a no-op."
    )


def test_theme_js_listens_for_skin_change() -> None:
    """theme.js must subscribe to the skin:change CustomEvent."""
    src = THEME_JS.read_text(encoding="utf-8")
    assert "skin:change" in src, (
        "theme.js does not listen for the 'skin:change' event emitted by "
        "<atilcalc-mode-toggle>. The skin system is disconnected from the UI."
    )


def test_theme_js_uses_css_custom_properties() -> None:
    """theme.js must set CSS custom properties on :root, not hardcode colors inline."""
    src = THEME_JS.read_text(encoding="utf-8")
    assert "documentElement.style.setProperty" in src, (
        "theme.js must use documentElement.style.setProperty('--calc-...', value) "
        "to swap palettes. Inline color assignment would break the existing "
        "CSS variable contract from styles.css."
    )
    # Per the docstring, the only properties skin owns are the --calc-... tokens.
    assert "--calc-bg" in src, "theme.js must set --calc-bg at minimum."


def test_index_html_loads_theme_script() -> None:
    """index.html must load theme.js after app-deferred.js."""
    html = (WEB_DIR / "index.html").read_text(encoding="utf-8")
    assert "theme.js" in html, (
        "index.html does not reference theme.js. Add "
        '<script type="module" src="theme.js"></script> '
        "after the app-deferred.js tag (theme.js is a passive listener)."
    )
