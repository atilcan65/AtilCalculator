# STORY-008: History UI wiring (render + substring search + click-to-load)

## User Story
As a **P1 — Atil (owner-operator)**,
I want **the `<atilcalc-history>` Web Component to render my persistent history (from STORY-007), search it as I type, and click any record to load it back into the input line**,
So that **I can navigate my calculation history with keyboard + mouse, find past results instantly, and reuse them without retyping (M2 + M5)**.

## Why now
The `<atilcalc-history>` Web Component shell shipped in Sprint 1 (STORY-003a, Issue #30) but it's wired to the in-memory deque. With STORY-007 persisting records to SQLite, the UI needs to be rewired to the backend (`GET /api/history` per ADR-0019) and gain the M5-required affordances (substring search, click-to-load).

## Acceptance Criteria
- **AC1** — GIVEN the persistent history has N records WHEN the user opens the calculator THEN `<atilcalc-history>` renders the latest 50 records in reverse-chronological order via `GET /api/history?limit=50`.
- **AC2** — GIVEN the user types into the search input (e.g., `0.1`) WHEN 100ms passes (debounce) THEN the history view filters to records matching the substring (`GET /api/history?q=0.1`); matching renders in <100ms p95.
- **AC3** — GIVEN a history record is visible WHEN the user clicks it (mouse) or presses Enter on it (keyboard) THEN the `expr` field is loaded into the input line AND the result line shows the historical `result` (click-to-load behavior).
- **AC4** — GIVEN a new evaluation completes WHEN the response arrives THEN the history view prepends the new record without requiring a full re-fetch (optimistic local append + background re-sync to reconcile with backend).
- **AC5** — GIVEN the history has >50 records WHEN the user scrolls to the bottom of the list THEN the view lazy-loads the next page (`GET /api/history?limit=50&before=<ts>`) — infinite scroll, no pagination UI.
- **AC6** — GIVEN the network call fails (`GET /api/history` returns 5xx) WHEN the user retries THEN a toast appears ("History unavailable, retrying…") AND the request is auto-retried with exponential backoff (max 3 retries, then surface persistent error).

## Out of scope
- History edit/delete (records are immutable post-creation — append-only).
- History export/import (Sprint 3+).
- History analytics (frequency, top expressions) — out of MVP.
- Cross-user history isolation (single-user MVP).

## Open questions
- [ ] **Designer (PM-led)**: Visual treatment of search input — single-line above the list vs inline filter? PM proposes single-line above (keyboard-first: `/` to focus). → PM mockup + architect review.
- [ ] **Developer**: Optimistic-append conflict resolution — if backend's record order differs from optimistic insert (e.g., another tab added a record simultaneously), how to reconcile? Suggestion: trust backend on next page refresh; show a subtle "syncing…" indicator during re-fetch. → developer

## Mockups / references
- `<atilcalc-history>` Web Component spec (Sprint 1 STORY-003a, Issue #30 body)
- ADR-0019 §GET /api/history response shape: `{"history": [{"expr", "result", "ts"}]}`
- vision.md M5 acceptance test (substring search, click-to-load)

## Dependencies
- **Upstream**: STORY-007 (SQLite persistence — backend must exist before wiring)
- **Downstream**: Sprint 3+ polish — M5 perf validation with real 1000+ record corpus

## Metrics of success
- **Leading**: substring search response time p95 <100ms (M5 target).
- **Leading**: click-to-load latency (click → input populated) <50ms.
- **Lagging**: M2 stickiness — owner actually uses history navigation (vs. retyping) for ≥30% of calculations.
- **Lagging**: M5 perf validation with 1000+ records post-launch.