"""Contract tests for the keyboard FSM (STORY-003a, AC2 + AC3 + AC5 + AC6).

Per the test plan, the FSM has 3 states: idle, entering, evaluated. Allowed
keys: 0-9, + - * /, ( ), Enter, Escape, Backspace, . — anything else is
ignored. State transitions:

- idle:      (no input)
- entering:  digit/op/paren typed → builds the expression
- evaluated: Enter pressed → result displayed; next digit resets to entering

Implementer may use Playwright (recommended for full coverage) or jsdom
(cheaper but less realistic). The contract is the same.
"""

from __future__ import annotations

import pytest


class TestKeyboardInput:
    """TC-2 / TC-3: digit + operator keys insert into the input line."""

    def test_single_digit_inserts(self, browser_page):
        browser_page.keyboard.press("5")
        display = browser_page.locator("atilcalc-display")
        assert display.get_attribute("value") == "5"

    def test_multiple_digits_concatenate(self, browser_page):
        for d in "001":
            browser_page.keyboard.press(d)
        display = browser_page.locator("atilcalc-display")
        assert display.get_attribute("value") == "001"

    def test_decimal_point_inserts(self, browser_page):
        for k in "1.5":
            browser_page.keyboard.press(k)
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "1.5"

    def test_operator_inserts_into_input(self, browser_page):
        for k in "1+2":
            browser_page.keyboard.press(k)
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "1+2"

    def test_all_arithmetic_operators_allowed(self, browser_page):
        for k in "1+2-3*4/5":
            browser_page.keyboard.press(k)
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "1+2-3*4/5"

    def test_parens_insert(self, browser_page):
        for k in "(1+2)":
            browser_page.keyboard.press(k)
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "(1+2)"

    def test_unknown_key_ignored(self, browser_page):
        """Keys outside the allowlist must not appear in the input line."""
        for k in "1x2":  # 'x' is not in MVP-1
            browser_page.keyboard.press(k)
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "12"


class TestKeyboardNavigation:
    """TC-5 / TC-6: Esc clears, Backspace deletes last char."""

    def test_escape_clears_input(self, browser_page):
        for k in "1+2":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Escape")
        assert browser_page.locator("atilcalc-display").get_attribute("value") == ""

    def test_escape_on_empty_input_is_noop(self, browser_page):
        browser_page.keyboard.press("Escape")
        assert browser_page.locator("atilcalc-display").get_attribute("value") == ""

    def test_backspace_drops_last_char(self, browser_page):
        for k in "1+2":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Backspace")
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "1+"

    def test_backspace_on_empty_is_noop(self, browser_page):
        browser_page.keyboard.press("Backspace")
        assert browser_page.locator("atilcalc-display").get_attribute("value") == ""


class TestKeyboardEvaluate:
    """TC-4: Enter triggers POST /api/evaluate; result appears in display."""

    def test_enter_triggers_evaluation(self, browser_page):
        for k in "1+2":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Enter")
        # display.result is the post-evaluation line
        result = browser_page.locator("atilcalc-display").get_attribute("result")
        assert result == "3"

    def test_enter_evaluates_decimal_0_1_plus_0_2(self, browser_page):
        """AC7 regression pin: 0.1 + 0.2 → "0.3" exactly, no float drift."""
        for k in "0.1+0.2":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Enter")
        result = browser_page.locator("atilcalc-display").get_attribute("result")
        assert result == "0.3"
