# STORY-009: Skin system — ≥3 built-in skins (Dark, Light, Retro) + mode-toggle wired

## User Story
As a **P1 — Atil (owner-operator, dark/light/retro preference changes day to day)**,
I want **3 visually distinct, complete skins (Dark, Light, Retro/terminal-green), switchable via the `<atilcalc-mode-toggle>` component, with <500ms transition and no visual flicker**,
So that **my calculator matches my reading-style preference today, and switching is instant + flicker-free (M4 acceptance)**.

## Why now
`<atilcalc-mode-toggle>` shipped in Sprint 1 (STORY-003b, Issue #31) but the skin **catalog** and CSS-variable-set files don't exist yet — only the toggle UI. ADR-0019 §GET /api/skin + §PUT /api/skin endpoints are defined but return a hardcoded single skin. M4 (≥3 skins + <500ms transition + persistent) requires the catalog.

## Acceptance Criteria
- **AC1** — GIVEN the repository has 3 skin files in `src/atilcalc/web/skins/{dark,light,retro}.css` WHEN the FastAPI server starts THEN `GET /api/skin` returns `{"skin": "dark", "available": ["dark", "light", "retro"]}` with the active skin + full list.
- **AC2** — GIVEN the user clicks `<atilcalc-mode-toggle>` (or presses the keyboard shortcut, e.g., `Ctrl+S`) WHEN a skin is selected THEN the browser applies the new CSS variables within 500ms (M4 perf budget); no visual flicker (test: `requestAnimationFrame` measurement before/after).
- **AC3** — GIVEN the active skin is `dark` WHEN the page reloads THEN the `dark` skin is still applied (skin preference persists at minimum per-session; cross-session is STORY-010).
- **AC4** — GIVEN the user calls `PUT /api/skin` with `{"skin": "retro", "idempotency_key": "<uuid>"}` WHEN the request succeeds THEN `GET /api/skin` returns `{"skin": "retro"}` and a subsequent retry with the same idempotency_key returns the cached response without re-applying (per ADR-0019 §Idempotency keys).
- **AC5** — GIVEN `PUT /api/skin` is called with `{"skin": "neon"}` (not in available list) WHEN the server validates THEN it returns HTTP 400 with `{"error": {"type": "UnknownSkinError", "message": "Unknown skin: neon", "request_id": "..."}}` per ADR-0019 §Error envelope.
- **AC6** — GIVEN a new skin file is added to `src/atilcalc/web/skins/` WHEN the server restarts THEN the new skin is automatically picked up (no code changes — skins are CSS-variable-set files, registration by filename discovery).
- **AC7** — GIVEN all 3 skins are defined WHEN visual QA is run THEN each skin: (a) has ≥8:1 contrast ratio for primary text on background (WCAG AAA), (b) is keyboard-focus-visible (Tab key outlines all interactive elements), (c) renders all Web Components (`<atilcalc-display>`, `<atilcalc-keypad>`, `<atilcalc-history>`, `<atilcalc-mode-toggle>`, `<atilcalc-help-popup>`, `<atilcalc-error-toast>`) consistently.

## Out of scope
- User-created custom skins (explicit out of MVP per vision §Out-of-scope; new skin = developer adds a CSS file).
- Skin marketplace / community skins.
- Per-component skin overrides (skins are global).
- Animated skin transitions (cross-fade etc.) — not required by M4; instant swap with no flicker satisfies the criterion.

## Open questions
- [ ] **Designer (PM-led)**: Skin palette specs (Dark/Light/Retro exact colors) — PM proposes hex values + contrast verification; architect reviews for WCAG AAA. → PM + architect
- [ ] **Architect**: Skin storage in MVP-1 — SQLite (sprint 2 backend from STORY-007) or in-memory (matching MVP-1's no-persistence posture)? Recommendation: in-memory for STORY-009, SQLite in STORY-010 (cross-device persistence). → architect
- [ ] **Developer**: CSS variable naming convention (e.g., `--color-bg`, `--color-fg`, `--font-mono`) — establish before skin files written so all 3 skins use the same variable set. → developer + architect

## Mockups / references
- vision.md §M4 acceptance criteria
- ADR-0019 §GET /api/skin + §PUT /api/skin endpoints
- ADR-0019 §Idempotency keys (PUT /api/skin requires key)
- `<atilcalc-mode-toggle>` Web Component spec (Sprint 1 STORY-003b, Issue #31)

## Dependencies
- **Upstream**:
  - ADR-0019 R-3 HTTP API contract (Accepted)
  - `<atilcalc-mode-toggle>` Web Component (Sprint 1, shipped)
- **Downstream**:
  - STORY-010 (skin preference persistence — needs the system to exist)

## Metrics of success
- **Leading**: skin switch latency p99 <500ms (M4 target).
- **Leading**: visual flicker count = 0 per switch (test via `requestAnimationFrame` measurement).
- **Lagging**: M4 acceptance — owner actively switches skins at least 1× per week.
- **Lagging**: WCAG AAA contrast verification passes for all 3 skins × all 6 Web Components.