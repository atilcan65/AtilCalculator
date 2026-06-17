"""Contract tests for the 3 Web Components (STORY-003a, AC1).

Per ADR-0018, the SPA shell uses vanilla JS + Web Components:
- <atilcalc-display>  : the input/result line
- <atilcalc-keypad>   : the on-screen button grid (mouse + keyboard mirror)
- <atilcalc-history>  : the last-N evaluations list
"""

from __future__ import annotations

import pytest


class TestWebComponentsPresent:
    def test_display_component_defined(self, browser_page):
        """The custom element must be registered + upgrade on parse."""
        exists = browser_page.evaluate("""() => {
            return customElements.get('atilcalc-display') !== undefined;
        }""")
        assert exists is True

    def test_keypad_component_defined(self, browser_page):
        exists = browser_page.evaluate("""() => {
            return customElements.get('atilcalc-keypad') !== undefined;
        }""")
        assert exists is True

    def test_history_component_defined(self, browser_page):
        exists = browser_page.evaluate("""() => {
            return customElements.get('atilcalc-history') !== undefined;
        }""")
        assert exists is True


class TestWebComponentRendering:
    def test_display_renders_input(self, browser_page):
        browser_page.locator("atilcalc-display").evaluate(
            "(el) => { el.setInput('42'); }"
        )
        # The element's textContent / value attribute reflects the input
        assert browser_page.locator("atilcalc-display").get_attribute("value") == "42"

    def test_history_renders_entries(self, browser_page):
        browser_page.locator("atilcalc-history").evaluate(
            """(el) => {
                el.pushEntry('1+1', '2');
                el.pushEntry('2+2', '4');
            }"""
        )
        # The element's shadow DOM should contain the entries
        items = browser_page.locator("atilcalc-history").locator(".entry").all()
        assert len(items) >= 2
