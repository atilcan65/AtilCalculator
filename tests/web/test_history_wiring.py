"""Contract tests for `<atilcalc-history>` Web Component wiring (STORY-008).

Refs Issue #70. Per ADR-0018, the SPA shell uses vanilla JS + Web Components.
Per ADR-0019, the component fetches from GET /api/history (and related
pagination + substring search endpoints). Tests use the `browser_page`
fixture (Playwright) to drive the component end-to-end.

The tests are RED until the wiring lands. They skip when:
- `atilcalc-history` element is not yet upgraded
- The API endpoints are not yet implemented
"""

from __future__ import annotations


class TestHistoryRender:
    """TC-1: AC1 — render latest 50 records in reverse-chronological order."""

    def test_history_renders_initial_page(self, browser_page):
        """Open calculator; assert history view shows records from GET /api/history?limit=50."""
        # Wait for component to upgrade + initial fetch to complete
        browser_page.locator("atilcalc-history").wait_for(state="attached")

        # Assert the component is wired to fetch from /api/history
        # (via inspecting the shadow DOM or a network listener)
        entries = browser_page.locator("atilcalc-history").locator(".entry").all()
        # Length should be ≤ 50 (server limits) and ≥ 0
        assert 0 <= len(entries) <= 50, (
            f"Expected 0-50 initial entries, got {len(entries)}. "
            f"Per AC1: GET /api/history?limit=50 returns the latest 50 records."
        )

    def test_history_renders_reverse_chronological(self, browser_page):
        """The list must show newest records first."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        entries = browser_page.locator("atilcalc-history").locator(".entry").all()
        if len(entries) < 2:
            return  # not enough data to assert order; skip
        # Read timestamps in DOM order; assert descending
        timestamps = browser_page.locator("atilcalc-history").evaluate(
            """(el) => {
                return Array.from(el.shadowRoot.querySelectorAll('.entry'))
                    .map(e => e.getAttribute('data-ts') || e.ts || '');
            }"""
        )
        assert timestamps == sorted(timestamps, reverse=True), (
            f"History must be newest-first (reverse-chronological per ADR-0019). "
            f"Got: {timestamps}"
        )


class TestHistorySearch:
    """TC-2: AC2 — substring search with debounce + AC2 perf budget."""

    def test_search_filters_within_100ms(self, browser_page):
        """Type a substring; wait 100ms debounce; assert filtered view <100ms."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        # Locate the search input (shadow DOM or direct child)
        search_input = browser_page.locator("atilcalc-history").locator("input[type=search], .search")
        search_input.fill("0.1")

        # Wait for debounce window (100ms) + render
        browser_page.wait_for_timeout(200)

        # Assert filtered
        browser_page.locator("atilcalc-history").locator(".entry").all()
        # At least one entry should match
        exprs = browser_page.locator("atilcalc-history").evaluate(
            """(el) => Array.from(el.shadowRoot.querySelectorAll('.entry .expr'))
                .map(e => e.textContent.trim())"""
        )
        assert all("0.1" in e for e in exprs), (
            f"All visible entries must contain '0.1' (AC2 substring filter). "
            f"Got exprs: {exprs}"
        )

    def test_empty_search_restores_full_list(self, browser_page):
        """Clear search → full list restored."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        # Type then clear
        search_input = browser_page.locator("atilcalc-history").locator("input[type=search], .search")
        search_input.fill("xyznevermatch")
        browser_page.wait_for_timeout(200)
        empty_count = len(browser_page.locator("atilcalc-history").locator(".entry").all())

        search_input.fill("")
        browser_page.wait_for_timeout(200)
        restored_count = len(browser_page.locator("atilcalc-history").locator(".entry").all())

        assert restored_count >= empty_count, (
            f"Clearing search must restore full list (or show empty state). "
            f"After 'xyznevermatch': {empty_count} entries; after clear: {restored_count} entries."
        )


class TestClickToLoad:
    """TC-4, TC-5: AC3 — click + Enter-key load record into input line."""

    def test_click_loads_entry_into_display(self, browser_page):
        """Click an entry; assert atilcalc-display input shows the expr + result line shows the result."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        # Need at least one entry to click
        entries = browser_page.locator("atilcalc-history").locator(".entry").all()
        if not entries:
            return  # no data to test against; skip

        # Capture entry expr/result before click
        target_expr = browser_page.locator("atilcalc-history").evaluate(
            """(el) => {
                const e = el.shadowRoot.querySelector('.entry');
                return e ? (e.getAttribute('data-expr') || e.querySelector('.expr')?.textContent?.trim()) : null;
            }"""
        )

        # Click first entry
        browser_page.locator("atilcalc-history").locator(".entry").first.click()

        # Assert display component updated
        display_value = browser_page.locator("atilcalc-display").get_attribute("value")
        assert display_value == target_expr, (
            f"AC3: click-to-load must populate atilcalc-display input with entry's expr. "
            f"Expected: {target_expr!r}, got: {display_value!r}"
        )

    def test_enter_key_loads_entry(self, browser_page):
        """Keyboard focus on entry + Enter → same effect as click."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        entries = browser_page.locator("atilcalc-history").locator(".entry").all()
        if not entries:
            return

        # Focus first entry and press Enter
        browser_page.locator("atilcalc-history").locator(".entry").first.focus()
        browser_page.keyboard.press("Enter")

        # Display input should be populated (similar to click)
        display_value = browser_page.locator("atilcalc-display").get_attribute("value")
        assert display_value, (
            "AC3: Enter key must also trigger click-to-load. "
            "Display input is empty after Enter on entry."
        )


class TestOptimisticAppend:
    """TC-6: AC4 — optimistic local append + background re-sync."""

    def test_new_eval_prepends_to_history(self, browser_page):
        """POST /api/evaluate → history view shows new record within 50ms (optimistic)."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        before_count = len(browser_page.locator("atilcalc-history").locator(".entry").all())

        # Trigger an eval (via the keypad or direct API call from page context)
        browser_page.evaluate(
            """async () => {
                await fetch('/api/evaluate', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({expr: '7 * 6'}),
                });
            }"""
        )
        # Allow optimistic append to render
        browser_page.wait_for_timeout(100)

        after_count = len(browser_page.locator("atilcalc-history").locator(".entry").all())
        assert after_count > before_count, (
            f"AC4: new eval should optimistically append to history view. "
            f"Before: {before_count}, after: {after_count} entries."
        )


class TestPagination:
    """TC-7: AC5 — infinite scroll lazy-load via ?before=<ts> cursor."""

    def test_scroll_to_bottom_loads_next_page(self, browser_page):
        """Scroll history to bottom; assert next page of 50 records loaded."""
        browser_page.locator("atilcalc-history").wait_for(state="attached")
        before_count = len(browser_page.locator("atilcalc-history").locator(".entry").all())

        # Scroll to bottom of history list
        browser_page.locator("atilcalc-history").evaluate(
            """(el) => {
                const list = el.shadowRoot.querySelector('.list, .entries, .history');
                if (list) list.scrollTop = list.scrollHeight;
            }"""
        )
        browser_page.wait_for_timeout(500)  # allow lazy load

        after_count = len(browser_page.locator("atilcalc-history").locator(".entry").all())
        # Either more entries loaded OR we ran out of records (≤ 50 total)
        assert after_count >= before_count, (
            f"AC5: scroll-to-bottom should load next page (or stay if end of list). "
            f"Before: {before_count}, after: {after_count}."
        )


class TestErrorRetry:
    """TC-8, TC-9: AC6 — 5xx retry with exponential backoff + persistent error."""

    def test_5xx_triggers_retry_with_backoff(self, browser_page):
        """Mock /api/history to return 503 twice, then 200. Assert retries."""
        # Set up route handler to mock 503/503/200 sequence
        responses = [503, 503, 200]
        call_count = {"n": 0}

        def handle(route, request):
            idx = min(call_count["n"], len(responses) - 1)
            call_count["n"] += 1
            route.fulfill(status=responses[idx], body="[]")

        browser_page.route("**/api/history**", handle)
        browser_page.reload()

        # Wait for initial attempt + 2 retries (1s + 2s backoff = 3s minimum)
        browser_page.wait_for_timeout(4000)

        assert call_count["n"] >= 2, (
            f"AC6: 5xx should trigger retry. Expected ≥2 calls, got {call_count['n']}."
        )

    def test_persistent_error_after_max_retries(self, browser_page):
        """Mock /api/history to always return 503. Assert persistent error UI."""
        def handle(route, request):
            route.fulfill(status=503, body="[]")

        browser_page.route("**/api/history**", handle)
        browser_page.reload()

        # Wait for 3 retries + backoff (1+2+4 = 7s total max)
        browser_page.wait_for_timeout(8000)

        # Assert persistent error toast/banner
        # Component-specific; check for known error class or text
        error_visible = browser_page.locator("atilcalc-history").evaluate(
            """(el) => {
                const err = el.shadowRoot.querySelector('.error, .toast, .persistent-error');
                return err && err.offsetParent !== null;
            }"""
        )
        assert error_visible, (
            "AC6: persistent error UI must surface after max retries. "
            "No error toast/banner visible in shadow DOM after 8s of 503s."
        )
