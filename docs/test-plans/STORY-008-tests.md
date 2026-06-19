# Test Plan: STORY-008 — History UI wiring (render + substring search + click-to-load)

## Scope
- **In scope**: AC1 (render latest 50 records reverse-chronological), AC2 (substring search with debounce), AC3 (click-to-load + Enter-key load), AC4 (optimistic local append + background re-sync), AC5 (infinite scroll pagination via `before=<ts>` cursor), AC6 (error retry with exponential backoff + persistent error surface).
- **Out of scope**: history edit/delete (records immutable), history export/import (Sprint 3+), analytics (out of MVP), cross-user isolation (auth ADR deferred).

## Test Cases

### TC-1: AC1 — render latest 50 records
- **Setup**: backend pre-seeded with N records (N ≥ 50).
- **Steps**:
  1. Open `<atilcalc-history>`.
  2. Wait for initial fetch (or stub it).
  3. Assert exactly 50 records rendered (or N if N < 50).
  4. Assert reverse-chronological order (newest first).
- **Expected**: GET /api/history?limit=50 returns 50 newest; component renders them in order.

### TC-2: AC2 — substring search with debounce
- **Setup**: backend pre-seeded with 100 records; component mounted.
- **Steps**:
  1. Type `0.1` into search input.
  2. Wait 100ms (debounce window).
  3. Assert component shows only matching records (expr contains `0.1`).
  4. Measure latency from debounce-fire to render: assert <100ms p95.
- **Expected**: `GET /api/history?q=0.1` returns matches; component re-renders within 100ms.

### TC-3: AC2 — empty search restores full list
- **Setup**: TC-2 state (search filtered).
- **Steps**:
  1. Clear search input.
  2. Wait 100ms.
  3. Assert full list restored.
- **Expected**: `GET /api/history` (no q) returns full list; component shows it.

### TC-4: AC3 — click-to-load
- **Setup**: history rendered with N records.
- **Steps**:
  1. Click record R (expr=X, result=Y).
  2. Assert `<atilcalc-display>` input value === X.
  3. Assert result line shows Y.
- **Expected**: click event fires; component dispatches `load-history-entry` event with `{expr, result}`; parent (display component) populates input + result line.

### TC-5: AC3 — Enter-key load
- **Setup**: history rendered; record R is keyboard-focused (via tab/arrow).
- **Steps**:
  1. Press Enter.
  2. Assert same effect as click.
- **Expected**: keyboard parity with mouse.

### TC-6: AC4 — optimistic append after eval
- **Setup**: history mounted; user evaluates `2 + 2` → `4`.
- **Steps**:
  1. POST /api/evaluate → 200 with `result=4`.
  2. Component receives notification (event or polling).
  3. Assert history view prepends `{expr: "2 + 2", result: "4"}` immediately (optimistic).
  4. Background re-fetch via GET /api/history reconciles.
- **Expected**: new record visible within 50ms of eval; no full-page flicker; reconcile is silent if backend matches.

### TC-7: AC5 — infinite scroll pagination
- **Setup**: backend has 200 records; component shows latest 50.
- **Steps**:
  1. Scroll to bottom of history list.
  2. Assert next 50 records loaded (total 100 visible).
  3. Continue scrolling; assert next 50 loaded (total 150).
  4. Final scroll; assert remaining 50 loaded (total 200).
- **Expected**: `GET /api/history?limit=50&before=<oldest_ts>` returns next page; component appends; no pagination UI.

### TC-8: AC6 — 5xx retry with exponential backoff
- **Setup**: backend configured to return 503 on first 2 calls, 200 on 3rd.
- **Steps**:
  1. Trigger history fetch.
  2. Assert retry 1 after ~250ms.
  3. Assert retry 2 after ~500ms.
  4. Assert success on 3rd attempt.
  5. Assert toast NOT shown after success.
- **Expected**: exponential backoff (250ms, 500ms, 1000ms); toast appears only on retries; cleared on success.

### TC-9: AC6 — persistent error after max retries
- **Setup**: backend always returns 503.
- **Steps**:
  1. Trigger history fetch.
  2. Assert retry 1, 2, 3 happen (with backoff).
  3. After retry 3 fails: persistent toast "History unavailable".
  4. User retries manually → same toast persists.
- **Expected**: max 3 retries per AC6 spec; persistent error visible to user.

## Adversarial Probes

### AP-1: 5xx on first page but 200 on subsequent pages
- Component should show first page (succeeded) but suppress optimistic state for failed page.

### AP-2: Search query returns 0 results
- Component should show empty state ("No matches") rather than blank list.

### AP-3: Concurrent optimistic appends
- User evals two expressions in quick succession (e.g., parallel POST).
- Component should append both in order; backend re-sync reconciles.

### AP-4: Very long record list (10k+)
- Pagination should handle; no DOM blowup; virtual scrolling if needed.

### AP-5: Special characters in search
- Query like `0.1 + 0.2` (with spaces, `+`) should match correctly.
- Query with regex special chars (`.*`, `[`) should be treated as literal substring (no regex).

### AP-6: Rapid typing (10 chars in 1 second)
- Debounce should still fire only once after 100ms of no input.

### AP-7: Optimistic append then backend rejects (e.g., DB write fails)
- Component should rollback optimistic entry; show error toast.

## Performance Concerns

### Perf-1: AC5 lazy load
- 50-record page render must complete in <100ms (M5 budget applies to substring search; pagination render should be similar).
- Virtual scrolling required if list > 1000 items.

### Perf-2: AC4 optimistic append
- Local DOM update must be <16ms (one frame at 60fps).

### Perf-3: AC6 retry backoff
- Backoff base 250ms, factor 2: total wait before final failure ~1.75s (250+500+1000).
- Max 3 retries per AC6 spec.

## Regression Risk

- **`<atilcalc-history>` component (STORY-003a, Issue #30)**: existing tests in `tests/web/test_components.py::test_history_renders_entries` push entries via `pushEntry()`. After STORY-008, the component should fetch from API. The old `pushEntry()` method may be removed or repurposed. **Action**: update or remove `test_history_renders_entries` when wiring lands.
- **`tests/api/test_history.py` (STORY-003a)**: in-memory deque tests. After STORY-007, the deque is gone. These tests should already be skipped/failing. **Action**: cross-check during #79 merge.
- **`tests/api/test_history_endpoint.py` (STORY-007, PR #79)**: `test_get_history_after_post` etc. depend on POST → GET roundtrip. STORY-008 wiring should NOT regress these.
- **Optimistic append vs backend reconcile**: if backend record order differs, component may show duplicate entries briefly. Pin behavior in test (e.g., wait for re-fetch to settle).

## Test Files to Land

| File | Purpose | ACs |
|---|---|---|
| `tests/web/test_history_wiring.py` | Component behavior: render, search, click-to-load, optimistic, pagination, retry | AC1-AC6 |
| `tests/api/test_history_pagination.py` | `?before=<ts>` cursor pagination API contract | AC5 |
| `tests/api/test_history_retry.py` | 5xx response + retry logic (mocked) | AC6 |

## Pre-Lock Blockers

1. **PR #79 (STORY-007 test plan) merge** — STORY-008 tests use the `_temp_db` fixture from PR #79 for seeding records. Until PR #79 merges, STORY-008 tests skip in the persistence layer.
2. **Web Component API surface** — `<atilcalc-history>`'s public methods (fetch, search, append, paginate) need to be defined by the implementer. Tests assume an event-driven model (component dispatches `load-history-entry` on click). **Action**: confirm with @architect / @developer at handoff time.

## Out-of-Scope Tests (NOT in this plan)

- History edit/delete (records immutable)
- History export/import (Sprint 3+)
- Cross-user isolation (auth ADR)
- Visual regression (per-skin rendering — separate concern in STORY-009)