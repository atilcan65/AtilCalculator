"""STORY-003b TC-2/TC-3 (FSM extensions) — TDD-RED.

AC2: `?` opens the help pop-up.
AC3: engine errors are dispatched as `engine:error` events.

The 3-state FSM from STORY-003a (idle / entering / evaluated) must
keep working unchanged; this commit ADDS two new bindings
(`?` → help:open, evaluate-failure → engine:error) and a new key
branch.

Tested as a structural contract: app.js must contain the new keys,
the new event dispatches, and must NOT regress the existing 3-state
behaviour. The full Playwright E2E with real key dispatch is in
test_e2e_keyboard.py.
"""

from __future__ import annotations

from pathlib import Path

import pytest

WEB_DIR = Path(__file__).resolve().parents[2] / "src" / "atilcalc" / "web"
APP_JS = WEB_DIR / "app.js"


def test_app_js_dispatches_help_open_on_question_mark() -> None:
    """AC2: pressing `?` must dispatch a `help:open` document-level event."""
    src = APP_JS.read_text(encoding="utf-8")
    assert "help:open" in src, (
        "app.js does not dispatch a `help:open` event when `?` is pressed. "
        "AC2 (help pop-up) requires the FSM to bridge `?` → <atilcalc-help-popup>."
    )


def test_app_js_dispatches_engine_error_on_failed_evaluate() -> None:
    """AC3: a non-2xx /api/evaluate response must emit `engine:error`."""
    src = APP_JS.read_text(encoding="utf-8")
    assert "engine:error" in src, (
        "app.js does not dispatch an `engine:error` event on a failed evaluate. "
        "AC3 (error-toast) requires the FSM to bridge fetch failures → toast."
    )


def test_app_js_question_mark_in_keydown_switch() -> None:
    """The `?` key must have its own branch in the keydown handler."""
    src = APP_JS.read_text(encoding="utf-8")
    assert 'ev.key === "?"' in src or "ev.key === '?'" in src, (
        "app.js does not have a dedicated `?` branch in the keydown handler. "
        "Without it, the `?` character is silently ignored (it isn't in "
        "ALLOWED_KEYS, so it would hit the unknown-keys fallthrough)."
    )


def test_app_js_preserves_existing_3_state_fsm() -> None:
    """The original STATE.IDLE/ENTERING/EVALUATED must still exist."""
    src = APP_JS.read_text(encoding="utf-8")
    for state in ("STATE.IDLE", "STATE.ENTERING", "STATE.EVALUATED"):
        assert state in src, (
            f"Regression: {state} no longer present in app.js. The 3-state FSM "
            f"from STORY-003a (PR #42) must keep working unchanged."
        )


def test_app_js_preserves_allowed_keys_set() -> None:
    """ALLOWED_KEYS must still contain the original 0-9 + operators."""
    src = APP_JS.read_text(encoding="utf-8")
    assert "ALLOWED_KEYS" in src, "ALLOWED_KEYS constant missing from app.js."
    for k in ("+", "-", "*", "/", "(", ")", "."):
        assert f'"{k}"' in src, f"ALLOWED_KEYS missing operator {k!r}."


def test_app_js_evaluate_emits_engine_error_on_4xx_5xx() -> None:
    """The `evaluate()` function must dispatch `engine:error` on a failed POST."""
    src = APP_JS.read_text(encoding="utf-8")
    eval_idx = src.find("async function evaluate")
    assert eval_idx != -1, "evaluate() function not found in app.js."
    eval_body = src[eval_idx:]
    assert "!resp.ok" in eval_body or "resp.status" in eval_body, (
        "evaluate() must check response status and dispatch engine:error on failure."
    )
    assert "engine:error" in eval_body, (
        "evaluate() body does not dispatch engine:error on failure (AC3)."
    )
