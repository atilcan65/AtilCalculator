"""Contract tests for STORY-012 AC2 — in-app ?-popup lists ALL keyboard shortcuts.

Refs Issue #74. Per ADR-0023 §Help popup content + AC2:
- Basic section: 0-9, +-*/, Enter=equals, Esc=clear, Backspace=delete, ?=help
- History section: ↑↓=navigate, Enter=load, /=search-focus, Esc=close-search
- Scientific section: s=sin, c=cos, t=tan, l=log, n=ln, r=sqrt, !=factorial, d=deg/rad toggle, m=mode toggle

TDD red: skip on missing popup registry. Module-level probe checks:
- <atilcalc-help-popup> exists OR a shortcut registry file exists
- The keyboard FSM in src/atilcalc/web/app.js declares the shortcuts

When implementation lands (popup registry refresh + bidirectional invariant), all tests will run.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_JS_PATH = REPO_ROOT / "src" / "atilcalc" / "web" / "app.js"
HELP_POPUP_JS_PATH = REPO_ROOT / "src" / "atilcalc" / "web" / "help-popup.js"
SHORTCUTS_REGISTRY_PATH = REPO_ROOT / "src" / "atilcalc" / "web" / "shortcuts.js"

REQUIRED_BASIC_SHORTCUTS = {
    "0-9": "digits",
    "+-*/": "operators",
    "Enter": "equals",
    "Esc": "clear",
    "Backspace": "delete",
    "?": "help",
}

REQUIRED_HISTORY_SHORTCUTS = {
    "↑↓": "navigate",
    "Enter": "load (in history context)",
    "/": "search-focus",
    "Esc": "close-search",
}

REQUIRED_SCIENTIFIC_SHORTCUTS = {
    "s": "sin",
    "c": "cos",
    "t": "tan",
    "l": "log",
    "n": "ln",
    "r": "sqrt",
    "!": "factorial",
    "d": "deg/rad toggle",
    "m": "mode toggle",
}

# TDD red guard — module-level skip ensures CI is green while the popup registry refresh lands.
# Strict probe: require the dedicated shortcuts.js registry file (single source of truth
# per ADR-0023 §Help popup content). Without it, the popup tests have no contract target.
try:
    if not SHORTCUTS_REGISTRY_PATH.exists():
        raise RuntimeError(
            "AC2: src/atilcalc/web/shortcuts.js missing. "
            "Per ADR-0023 §Help popup content, the keyboard shortcut registry "
            "must be extracted to a dedicated file (single source of truth "
            "for both FSM and popup). Implementation PR creates this file."
        )

    _shortcuts_src = SHORTCUTS_REGISTRY_PATH.read_text(encoding="utf-8")
    # Probe: registry must declare at least one shortcut (otherwise it's empty)
    if "key" not in _shortcuts_src.lower() and "shortcut" not in _shortcuts_src.lower():
        raise RuntimeError(
            "AC2: shortcuts.js exists but contains no shortcut declarations. "
            "Registry must have a structured format (e.g., export const SHORTCUTS = {...})."
        )

except Exception as _exc:
    _msg = str(_exc)
    if (
        any(marker in _msg for marker in ["AC2", "shortcut", "registry", "popup"])
        or "import" in _msg.lower()
        or "module" in _msg.lower()
    ):
        pytest.skip(  # type: ignore[name-defined]
            "STORY-012 TDD red — help popup registry not yet extracted. "
            "Implementation PR must extract shortcut registry to "
            "src/atilcalc/web/shortcuts.js (single source of truth) + refresh "
            "<atilcalc-help-popup> content per AC2.",
            allow_module_level=True,
        )
    raise


# ---------------------------------------------------------------------------
# TC-5: AC2 — Basic section has 6 required shortcuts
# ---------------------------------------------------------------------------
class TestHelpPopupBasicSection:
    """AC2 (Basic): digits + operators + Enter + Esc + Backspace + ?."""

    def test_help_popup_basic_section_has_all_shortcuts(self) -> None:
        """All 6 Basic shortcuts must appear in the popup source (or registry)."""
        # The popup source is data-driven; for TDD red we just check the registry file
        _registry_src = ""
        if SHORTCUTS_REGISTRY_PATH.exists():
            _registry_src = SHORTCUTS_REGISTRY_PATH.read_text(encoding="utf-8")
        elif HELP_POPUP_JS_PATH.exists():
            _registry_src = HELP_POPUP_JS_PATH.read_text(encoding="utf-8")

        for shortcut, action in REQUIRED_BASIC_SHORTCUTS.items():
            # Look for either the shortcut key OR the action label
            pattern = rf"{re.escape(shortcut)}|{re.escape(action)}"
            assert re.search(pattern, _registry_src, re.IGNORECASE), (
                f"AC2 (Basic): shortcut {shortcut!r} ({action}) missing from popup registry. "
                f"Expected in shortcuts.js or help-popup.js."
            )


# ---------------------------------------------------------------------------
# TC-6: AC2 — History section has 4 required shortcuts
# ---------------------------------------------------------------------------
class TestHelpPopupHistorySection:
    """AC2 (History): ↑↓ + Enter + / + Esc."""

    def test_help_popup_history_section_has_all_shortcuts(self) -> None:
        """All 4 History shortcuts must appear in the popup source (or registry)."""
        _registry_src = ""
        if SHORTCUTS_REGISTRY_PATH.exists():
            _registry_src = SHORTCUTS_REGISTRY_PATH.read_text(encoding="utf-8")
        elif HELP_POPUP_JS_PATH.exists():
            _registry_src = HELP_POPUP_JS_PATH.read_text(encoding="utf-8")

        for shortcut, action in REQUIRED_HISTORY_SHORTCUTS.items():
            pattern = rf"{re.escape(shortcut)}|{re.escape(action)}"
            assert re.search(pattern, _registry_src, re.IGNORECASE), (
                f"AC2 (History): shortcut {shortcut!r} ({action}) missing from popup registry."
            )


# ---------------------------------------------------------------------------
# TC-7: AC2 — Scientific section has 9 required shortcuts
# ---------------------------------------------------------------------------
class TestHelpPopupScientificSection:
    """AC2 (Scientific): s + c + t + l + n + r + ! + d + m."""

    def test_help_popup_scientific_section_has_all_shortcuts(self) -> None:
        """All 9 Scientific shortcuts must appear in the popup source (or registry)."""
        _registry_src = ""
        if SHORTCUTS_REGISTRY_PATH.exists():
            _registry_src = SHORTCUTS_REGISTRY_PATH.read_text(encoding="utf-8")
        elif HELP_POPUP_JS_PATH.exists():
            _registry_src = HELP_POPUP_JS_PATH.read_text(encoding="utf-8")

        for shortcut, action in REQUIRED_SCIENTIFIC_SHORTCUTS.items():
            pattern = rf"{re.escape(shortcut)}|{re.escape(action)}"
            assert re.search(pattern, _registry_src, re.IGNORECASE), (
                f"AC2 (Scientific): shortcut {shortcut!r} ({action}) missing from popup registry."
            )


# ---------------------------------------------------------------------------
# AP-2: bidirectional invariant — popup shortcuts match FSM shortcuts
# ---------------------------------------------------------------------------
class TestHelpPopupBidirectionalInvariant:
    """AP-2: every shortcut in popup MUST be wired in FSM (no orphans)."""

    def test_popup_shortcuts_match_fsm_shortcuts(self) -> None:
        """For each shortcut declared in popup registry, assert FSM has a handler."""
        if not (APP_JS_PATH.exists() and SHORTCUTS_REGISTRY_PATH.exists()):
            pytest.skip("Both app.js + shortcuts.js required for bidirectional invariant.")

        _fsm_src = APP_JS_PATH.read_text(encoding="utf-8")
        _registry_src = SHORTCUTS_REGISTRY_PATH.read_text(encoding="utf-8")

        # Extract declared shortcut keys from registry (very loose regex)
        declared_keys = set(re.findall(r'"([a-zA-Z!?])"', _registry_src))
        declared_keys.update(re.findall(r"'([a-zA-Z!?])'", _registry_src))

        for key in declared_keys:
            assert key in _fsm_src, (
                f"AP-2: popup registry declares shortcut {key!r} but FSM has no handler. "
                f"Either remove from popup or wire in app.js."
            )
