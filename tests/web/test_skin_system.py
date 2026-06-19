"""STORY-003b TC-1/TC-6 + STORY-009 AC1/AC6/AC7 — skin system contract.

AC1 (STORY-003b): clicking <atilcalc-mode-toggle> swaps the skin (dark ↔ light ↔ retro).
AC6 (STORY-009): 3 skin files (dark, light, retro) live in src/atilcalc/web/skins/.
AC7 (STORY-009): each skin file documents WCAG AAA contrast.
Transition completes in <500ms with no visual flicker (covered by Playwright E2E tests).

This file is the structural pre-condition check:
- theme.js exists and dispatches skin swaps via data-skin attribute
- 3 CSS files exist in src/atilcalc/web/skins/
- Each CSS file defines :root[data-skin='<name>'] with --calc-* tokens
- theme.js listens for 'skin:change' CustomEvent
- index.html loads all 3 skin stylesheets + theme.js

The full Playwright transition timing test lands in test_e2e_keyboard.py TC-4 /
test_skin_transition.py TC-6. The CSS palette correctness test lives in
test_skin_visual.py (TC-1..TC-4) — this file is the FILE-EXISTS contract.
"""

from __future__ import annotations

from pathlib import Path

import pytest

WEB_DIR = Path(__file__).resolve().parents[2] / "src" / "atilcalc" / "web"
THEME_JS = WEB_DIR / "theme.js"
SKINS_DIR = WEB_DIR / "skins"

EXPECTED_SKINS = ("dark", "light", "retro")


def test_theme_js_exists() -> None:
    """theme.js must exist on disk."""
    assert THEME_JS.exists(), (
        f"Expected {THEME_JS} to exist (STORY-003b commit 3). "
        f"It owns the data-skin attribute swap on <html>."
    )


@pytest.mark.parametrize("skin", EXPECTED_SKINS)
def test_skin_css_file_exists(skin: str) -> None:
    """src/atilcalc/web/skins/<skin>.css must exist (STORY-009 AC6 + AC7).

    Palettes live in CSS files (:root[data-skin='<name>'] blocks), not in
    theme.js. Each skin must have its own file with full WCAG AAA palette.
    """
    css_path = SKINS_DIR / f"{skin}.css"
    assert css_path.exists(), (
        f"Missing {css_path} (STORY-009 AC6). "
        f"Each skin needs its own CSS file with :root[data-skin='{skin}'] "
        f"defining the full --calc-* palette (WCAG AAA verified per AC7)."
    )


@pytest.mark.parametrize("skin", EXPECTED_SKINS)
def test_skin_css_defines_root_data_skin_block(skin: str) -> None:
    """Each skin CSS file must define :root[data-skin='<name>'] { ... }."""
    css_path = SKINS_DIR / f"{skin}.css"
    if not css_path.exists():
        pytest.skip(f"{css_path} not present — see test_skin_css_file_exists")
    src = css_path.read_text(encoding="utf-8")
    assert f"[data-skin='{skin}']" in src or f'[data-skin="{skin}"]' in src, (
        f"{skin}.css must define :root[data-skin='{skin}'] block. "
        f"Without it, the data-skin attribute on <html> has no effect."
    )
    # At minimum, --calc-bg must be defined in the palette (contrast-anchor token).
    assert "--calc-bg" in src, (
        f"{skin}.css must define --calc-bg as the contrast anchor "
        f"for the WCAG AAA verification."
    )


def test_theme_js_listens_for_skin_change() -> None:
    """theme.js must subscribe to the skin:change CustomEvent."""
    src = THEME_JS.read_text(encoding="utf-8")
    assert "skin:change" in src, (
        "theme.js does not listen for the 'skin:change' event emitted by "
        "<atilcalc-mode-toggle>. The skin system is disconnected from the UI."
    )


def test_theme_js_sets_data_skin_attribute() -> None:
    """theme.js must set the data-skin attribute on <html>, not setProperty.

    Per STORY-009 AC6: palettes live in CSS files. theme.js flips the
    data-skin attribute on <html> and the right CSS cascade applies. Inline
    setProperty calls would duplicate the palette and break the single-source
    of truth (CSS files).
    """
    src = THEME_JS.read_text(encoding="utf-8")
    # New architecture: set data-skin attribute, not setProperty
    has_data_skin = (
        "data-skin" in src
        or "setAttribute" in src and "skin" in src
    )
    assert has_data_skin, (
        "theme.js must set data-skin attribute on <html> (setAttribute or "
        "documentElement.dataset.skin) to swap CSS palettes. Inline "
        "setProperty on --calc-* tokens was the old architecture "
        "(superseded by STORY-009 AC6)."
    )


def test_index_html_loads_theme_script_and_skins() -> None:
    """index.html must load theme.js + all 3 skin CSS files."""
    html = (WEB_DIR / "index.html").read_text(encoding="utf-8")
    assert "theme.js" in html, (
        "index.html does not reference theme.js. Add "
        '<script type="module" src="theme.js"></script> '
        "after the app-deferred.js tag (theme.js is a passive listener)."
    )
    for skin in EXPECTED_SKINS:
        assert f"skins/{skin}.css" in html, (
            f"index.html does not load skins/{skin}.css. Without the "
            f"stylesheet, the {skin} palette is invisible to the browser."
        )
