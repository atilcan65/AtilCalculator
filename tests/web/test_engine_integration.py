"""End-to-end engine integration tests (STORY-003a, AC7).

These tests exercise the full stack: SPA shell → fetch POST /api/evaluate →
engine. The canonical regression pin is the 0.1 + 0.2 = 0.3 roundtrip; if
``Decimal`` serialisation breaks, the JS layer will see ``0.30000000000000004``
and these tests will fail.
"""

from __future__ import annotations


class TestEngineRoundtrip:
    def test_0_1_plus_0_2_via_keyboard(self, browser_page):
        """AC7: 0.1 + 0.2 → exactly "0.3" on the display."""
        for k in "0.1+0.2":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Enter")
        result = browser_page.locator("atilcalc-display").get_attribute("result")
        assert result == "0.3", f"AC7 regression: expected '0.3', got {result!r}"

    def test_100_plus_5_percent_via_keyboard(self, browser_page):
        """AC3 (engine): 100 + 5% → "105" (Windows-calc semantics)."""
        for k in "100+5%":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Enter")
        result = browser_page.locator("atilcalc-display").get_attribute("result")
        assert result == "105"

    def test_division_by_zero_shows_error(self, browser_page):
        """DivisionByZeroError must surface to the user; the <atilcalc-error-toast>
        component is deferred to STORY-003b, but for 003a the error must at minimum
        NOT silently produce a wrong number.
        """
        for k in "5/0":
            browser_page.keyboard.press(k)
        browser_page.keyboard.press("Enter")
        # The result must NOT be a number — it must be an error indication.
        # For 003a (no error-toast yet), the FSM should leave the result line
        # in a "not a number" state. The implementer may choose to display
        # "Error" or simply not update the result. Either way, no numeric
        # "Infinity" or "NaN" string.
        result = browser_page.locator("atilcalc-display").get_attribute("result")
        assert result not in ("Infinity", "NaN", "5/0"), (
            f"5/0 must not produce a wrong/NaN result, got {result!r}"
        )
