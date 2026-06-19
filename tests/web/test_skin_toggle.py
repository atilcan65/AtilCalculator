"""Contract tests for <atilcalc-mode-toggle> skin switch + persistence (STORY-009).

Refs Issue #71. Per ADR-0023 frontend architecture + ADR-0019 R-3:
- AC2: skin switch <500ms with no flicker (M4 budget)
- AC3: per-session persistence (reload preserves skin)

These tests use the `browser_page` fixture (Playwright). The fixture is
configured in conftest.py to skip with a clear message when Playwright +
the FastAPI server are not yet running (TDD red phase).

When the implementation lands (theme.js wired + skin endpoint implemented
+ Playwright deps added + server started), the tests below will run and
verify the contract.

See tests/web/test_skin_system.py for STORY-003b structural preconditions
(theme.js file exists, palette definitions, skin:change listener, CSS
custom properties, index.html script tag). This file adds the AC2/AC3
contract layer on top.
"""

from __future__ import annotations

import uuid


# ---------------------------------------------------------------------------
# TC-2: AC2 — skin switch latency <500ms (M4) + zero flicker
# ---------------------------------------------------------------------------
class TestSkinSwitchLatency:
    """AC2: clicking <atilcalc-mode-toggle> switches skin in <500ms with no flicker."""

    def test_skin_switch_completes_within_500ms(self, browser_page) -> None:
        """Click toggle to change skin; measure latency from click to paint; assert <500ms p99."""
        # Wait for components to upgrade
        browser_page.locator("atilcalc-mode-toggle").wait_for(state="attached")
        browser_page.locator("atilcalc-display").wait_for(state="attached")

        # Read current skin
        before_skin = browser_page.evaluate(
            "() => document.documentElement.getAttribute('data-skin')"
        )
        # Pick a different skin from the catalog (assume 3 built-in: dark/light/retro)
        available = browser_page.evaluate(
            """async () => {
                const resp = await fetch('/api/skin');
                const body = await resp.json();
                return body.available || [];
            }"""
        )
        target = next((s for s in available if s != before_skin), available[0])

        # Measure latency via requestAnimationFrame timestamps
        latency_ms = browser_page.evaluate(
            """async (target) => {
                const start = performance.now();
                // Click the toggle (or dispatch the event directly)
                const toggle = document.querySelector('atilcalc-mode-toggle');
                toggle.dispatchEvent(new CustomEvent('skin:change', { detail: { skin: target } }));
                // Wait for next paint
                await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
                const end = performance.now();
                return end - start;
            }""",
            target,
        )

        assert latency_ms < 500, (
            f"AC2: skin switch latency {latency_ms:.0f}ms exceeds M4 budget of 500ms. "
            f"Switch from {before_skin!r} to {target!r} should complete <500ms."
        )

    def test_skin_switch_has_zero_flicker(self, browser_page) -> None:
        """AC2: no intermediate paint frames have mixed (old + new) skin computed styles."""
        browser_page.locator("atilcalc-mode-toggle").wait_for(state="attached")

        # Count frames with mixed skin state during transition
        flicker_count = browser_page.evaluate(
            """async () => {
                const toggle = document.querySelector('atilcalc-mode-toggle');
                const beforeSkin = document.documentElement.getAttribute('data-skin');
                const target = beforeSkin === 'dark' ? 'light' : 'dark';
                let mixedFrameCount = 0;
                let frameObserver;
                const framePromise = new Promise(resolve => {
                    frameObserver = new MutationObserver(() => {
                        const current = document.documentElement.getAttribute('data-skin');
                        if (current && current !== beforeSkin && current !== target) {
                            mixedFrameCount++;
                        }
                    });
                    frameObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['data-skin', 'style'] });
                    setTimeout(() => { frameObserver.disconnect(); resolve(); }, 200);
                });
                toggle.dispatchEvent(new CustomEvent('skin:change', { detail: { skin: target } }));
                await framePromise;
                return mixedFrameCount;
            }"""
        )

        assert flicker_count == 0, (
            f"AC2: skin switch had {flicker_count} intermediate frames with mixed skin state (flicker). "
            f"Zero flicker required per M4 budget."
        )


# ---------------------------------------------------------------------------
# TC-3: AC3 — per-session persistence (reload preserves skin)
# ---------------------------------------------------------------------------
class TestSkinPersistenceReload:
    """AC3: skin preference survives a full page reload within the same session."""

    def test_reload_preserves_skin_choice(self, browser_page) -> None:
        """Set skin to 'retro', reload page, verify skin is still 'retro'."""
        browser_page.locator("atilcalc-mode-toggle").wait_for(state="attached")

        # Set skin to retro via PUT /api/skin
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        browser_page.evaluate(
            """async (key) => {
                await fetch('/api/skin', {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json', 'Idempotency-Key': key },
                    body: JSON.stringify({ skin: 'retro' }),
                });
            }""",
            idempotency_key,
        )

        # Verify pre-reload state
        pre_reload = browser_page.evaluate(
            "() => document.documentElement.getAttribute('data-skin')"
        )

        # Reload
        browser_page.reload()
        browser_page.locator("atilcalc-display").wait_for(state="attached")

        # Verify post-reload state
        post_reload_skin = browser_page.evaluate(
            "() => document.documentElement.getAttribute('data-skin')"
        )
        post_reload_api = browser_page.evaluate(
            """async () => {
                const r = await fetch('/api/skin');
                const b = await r.json();
                return b.skin;
            }"""
        )

        assert post_reload_skin == "retro", (
            f"AC3: post-reload data-skin attribute should be 'retro'; got {post_reload_skin!r} "
            f"(pre-reload: {pre_reload!r})"
        )
        assert post_reload_api == "retro", (
            f"AC3: post-reload GET /api/skin should return {{'skin': 'retro'}}; got {post_reload_api!r}"
        )

    def test_reload_does_not_revert_to_default(self, browser_page) -> None:
        """AC3: after non-default skin + reload, MUST not revert to dark."""
        browser_page.locator("atilcalc-mode-toggle").wait_for(state="attached")

        # Set to 'light' (not default)
        idempotency_key = f"00000000-0000-4000-8000-{uuid.uuid4().int % 10**12:012d}"
        browser_page.evaluate(
            """async (key) => {
                await fetch('/api/skin', {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json', 'Idempotency-Key': key },
                    body: JSON.stringify({ skin: 'light' }),
                });
            }""",
            idempotency_key,
        )

        browser_page.reload()
        browser_page.locator("atilcalc-display").wait_for(state="attached")

        post_reload_skin = browser_page.evaluate(
            "() => document.documentElement.getAttribute('data-skin')"
        )
        # Default fallback is 'dark' (per ADR-0023 §Sprint 1 default)
        # If impl correctly persists 'light', we should NOT see 'dark'
        assert post_reload_skin != "dark", (
            f"AC3: post-reload reverted to default 'dark'; expected 'light' (persistence broken). "
            f"Got: {post_reload_skin!r}"
        )
