# ADR-0023 — Frontend architecture: theming model, skin system, Web Component contracts

**Status:** Accepted (via PR #83, 2026-06-18T20:44:24Z, merged by @atilcan65)
**Date:** 2026-06-18
**Deciders:** @architect (drafting), @product-manager (verdict on M4 + skin palette ownership), @developer (verdict on Web Component contracts + cross-component event bus), @tester (verdict on skin transition perf budget + TDD red alignment with PR #81)
**Supersedes:** [ADR-0018](ADR-0018-front-end-framework.md) §Open questions (CSS organization + testing harness + minification) — those questions are now resolved by this ADR
**Related:** [ADR-0017](ADR-0017-tech-stack.md) §Concrete stack (vanilla JS + Web Components); [ADR-0018](ADR-0018-front-end-framework.md) (front-end framework choice — vanilla JS + Web Components); [ADR-0019](ADR-0019-api-contract.md) §GET /api/skin + §PUT /api/skin; [ADR-0022](ADR-0022-persistence-layer.md) (R-5 persistence — `skin` table for cross-device skin preference); [Issue #71](https://github.com/atilcan65/AtilCalculator/issues/71) STORY-009 (skin system); [Issue #72](https://github.com/atilcan65/AtilCalculator/issues/72) STORY-010 (skin persistence); [PR #49](https://github.com/atilcan65/AtilCalculator/pull/49) (Sprint 1 STORY-003b — initial skin system shipped); [PR #81](https://github.com/atilcan65/AtilCalculator/pull/81) (STORY-008 TDD red contract suite)

---

## Context

ADR-0018 chose **vanilla JS + Web Components** as the front-end framework for MVP-1. It deliberately left three open questions:

1. **CSS organization** — per-component scoped via Shadow DOM vs global `theme.css`
2. **Testing harness** — Web Components + ES modules testable via Playwright; no unit test runner
3. **Minification** — ship readable `.js` in production for MVP-1

Sprint 1 STORY-003b (PR #49) shipped an **initial skin system** that resolves the first question in practice (CSS custom properties on `:root` + per-component Shadow DOM with fallback values). Sprint 2 STORY-009 (Issue #71) needs a 3-skin system (Dark, Light, Retro) with <500ms transition (M4) and a `<atilcalc-mode-toggle>` component already shipped in PR #49. STORY-010 (Issue #72) needs cross-device skin preference persistence (covered by ADR-0022's `skin` table).

Vision invariants this ADR must satisfy:

| Metric | Source | Constraint |
|---|---|---|
| **M3** (keyboard-only) | vision §M3 | All skin UI must be keyboard-accessible; no mouse-only skin switcher |
| **M4** (skin transition) | vision §M4 | <500ms transition, no flicker, ≥3 skins, persistent across sessions + devices |
| **M5** (history performance) | vision §M5 | Skin swap must not block history rendering (independent concerns) |

Cross-cutting constraints:

- **Engine ↔ UI separation invariant** (ADR-0017): engine is server-side; web shell is a thin client. The skin system runs entirely client-side.
- **Zero-dep stack** (ADR-0017 + ADR-0018): no `package.json`, no build step, no CDN. The browser parses `src/atilcalc/web/*.js` + `*.css` directly.
- **CSS custom properties on `:root`** (PR #49 + ADR-0018 pre-lean): skin palette is a set of 14 CSS variables (`--calc-bg`, `--calc-fg`, etc.) consumed by `styles.css` + per-component Shadow DOM CSS.
- **GPU-compositable transitions only** (PR #49): `background` + `color` only; no `box-shadow` or `filter` (would force layout/paint).

Sizing ceremony output (Issue #76, Issue #80): PM recommendation is CSS variables (smallest surface, Web Component-friendly). Dev concurs. Shadow DOM tokens and theme JSON are alternatives but heavier.

---

## Decision

**Codify the CSS custom properties on `:root` + global `styles.css` + per-component Shadow DOM with fallback values pattern** as the canonical theming model. Skin swap = one `applySkin()` function that sets 14 CSS custom properties on `:root` and triggers a 200ms GPU-compositable transition. Web Component contracts follow a standard pattern: `atilcalc-*` custom element names, `skin:change` / `engine:error` / `help:open` document-level CustomEvents, open Shadow DOM with `:host { ... }` styles.

### Theming model — CSS custom properties on `:root`

```
src/atilcalc/web/
  index.html
  styles.css           # 14 :root CSS variables (default = dark) + body transition
  theme.js             # PALETTES object (3 skins) + applySkin() + initTheme()
  app.js               # entry point + engine HTTP client
  app-deferred.js      # <atilcalc-mode-toggle>, <atilcalc-help-popup>, <atilcalc-error-toast>
  ...
```

**Three skin palettes** (defined in `theme.js`):

| Skin | Background | Foreground | Aesthetic |
|---|---|---|---|
| `dark` | `#121212` | `#f0f0f0` | Default (AtilCalculator since STORY-001). Low-light, high-contrast. |
| `light` | `#ffffff` | `#1a1a1a` | Daytime reading. |
| `retro` | `#0a1a0a` | `#33ff33` | Green CRT terminal (Atil-suggested retro look from backlog grooming #22). |

**14 CSS custom properties** (the palette surface):

```css
:root {
  --calc-bg: <palette.bg>;
  --calc-fg: <palette.fg>;
  --calc-display-bg: ...;
  --calc-display-fg: ...;
  --calc-keypad-bg: ...;
  --calc-keypad-fg: ...;
  --calc-keypad-border: ...;
  --calc-keypad-hover: ...;
  --calc-op-bg: ...;
  --calc-eq-bg: ...;
  --calc-clr-bg: ...;
  --calc-history-bg: ...;
  --calc-history-fg: ...;
}
```

**Skin swap mechanism**:

```js
function applySkin(skin) {
  const palette = PALETTES[skin] || PALETTES.dark;
  for (const [prop, value] of Object.entries(palette)) {
    document.documentElement.style.setProperty(prop, value);
  }
  document.body.dataset.skin = skin;
}
```

**Skin transition** (200ms GPU-compositable):

```css
body {
  background: var(--calc-bg);
  color: var(--calc-fg);
  transition: background 200ms ease, color 200ms ease;
}
```

Per Web standards + PR #49 comments, **only `background` and `color` are transitioned** because they are GPU-compositable. `box-shadow` and `filter` would force layout/paint (expensive on large surfaces). 200ms << 500ms M4 budget, well under it.

### Web Component contracts

**Naming**: `<atilcalc-*>` (kebab-case, `atilcalc-` prefix). Each custom element class is `AtilcalcPascalCase` (e.g., `AtilcalcModeToggle`).

**Shadow DOM mode**: `open` (not `closed`). Open Shadow DOM allows DevTools inspection + easier debugging for the owner. This matches the Sprint 1 convention (PR #49, all 3 deferred components).

**CSS-in-Shadow-DOM pattern**: every component's Shadow DOM CSS uses CSS custom properties with **fallback values** (e.g., `background: var(--calc-keypad-bg, #2a2a2a);`). The fallback ensures the component renders correctly even if the global `theme.js` hasn't initialized yet (e.g., before `<body>` renders).

**Custom events** (document-level, dispatched via `document.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }))`):

| Event | Source | Detail | Consumer |
|---|---|---|---|
| `skin:change` | `<atilcalc-mode-toggle>` | `{ skin: "dark" \| "light" \| "retro" }` | `theme.js` `applySkin()` |
| `engine:error` | engine HTTP client (app.js) | `{ type: "NetworkError" \| "ValidationError" \| ..., message: "..." }` | `<atilcalc-error-toast>` |
| `engine:error:clear` | engine HTTP client | `{}` | `<atilcalc-error-toast>` |
| `help:open` | keyboard FSM (app.js) | `{}` | `<atilcalc-help-popup>` |
| `help:close` | keyboard FSM / dialog close | `{}` | `<atilcalc-help-popup>` |

All events use `bubbles: true, composed: true` so they cross Shadow DOM boundaries.

**Attribute patterns**:

- `active` on `<atilcalc-mode-toggle>` — currently selected skin (reflects UI state).
- `duration` on `<atilcalc-error-toast>` — auto-dismiss timeout in ms (default 5000).
- `open` on `<atilcalc-help-popup>` — boolean attribute, presence = open.

**Constructor pattern**: every component calls `this.attachShadow({ mode: "open" })` in the constructor. `connectedCallback()` is idempotent (checks `if (this.shadowRoot.innerHTML) return;` before populating). `attributeChangedCallback()` is wired for components with `static get observedAttributes()`.

**No polyfill / no framework wrappers**: Web Components are a W3C standard, natively supported in all modern browsers. No `lit-html`, no `Stencil`, no `Polymer` — keep the dep-free invariant.

### Skin storage model

Two layers, matching STORY-009 + STORY-010:

| Layer | Story | Storage | Lifecycle |
|---|---|---|---|
| **In-memory (STORY-009)** | STORY-009 | `document.body.dataset.skin` + `:root` CSS variables | Lost on page reload |
| **Persistent (STORY-010)** | STORY-010 | `skin` table (ADR-0022 §Schema) at `/api/skin` (ADR-0019 §PUT /api/skin) | Cross-session + cross-device via NFS |

**Flow on page load** (STORY-010 implementation PR):

1. `<atilcalc-mode-toggle>` initializes with `active="dark"` (default).
2. `theme.js` calls `applySkin("dark")` immediately (no flicker).
3. `app.js` fetches `GET /api/skin` → returns `{"skin": "light"}` (or whatever the persisted value is).
4. `app.js` calls `<atilcalc-mode-toggle>.setAttribute("active", "light")` → triggers `skin:change` event → `theme.js` `applySkin("light")` → 200ms transition.
5. Page is now styled with the persisted skin.

**Flow on skin change** (STORY-009 + STORY-010):

1. User clicks `<atilcalc-mode-toggle>` button → `setAttribute("active", "light")` + `document.body.dataset.skin = "light"` + `dispatchEvent("skin:change")`.
2. `theme.js` listener catches `skin:change` → `applySkin("light")` → 200ms transition.
3. (STORY-010) `app.js` listener catches `skin:change` → `PUT /api/skin` with `{"skin": "light"}` → persists across devices.

**No localStorage**: per PM recommendation in Issue #72 design question, SQLite backend is the only skin storage. localStorage is per-browser, doesn't satisfy M4 cross-device clause.

### Performance budget (M4)

| Operation | Target | Implementation | Measured by |
|---|---|---|---|
| Skin swap (visual transition) | <500ms (M4) | 200ms `background` + `color` transition | TC-1 in PR #81 + perf probe |
| Skin swap (JS work) | <16ms (1 frame at 60fps) | 14 `setProperty()` calls + 1 `dataset` write | TC-1 in PR #81 |
| Cold page load + initial skin | <100ms (no flicker) | `applySkin()` called synchronously in `initTheme()` from `<script type="module">` | TC-1 in PR #81 |
| `GET /api/skin` round-trip | <50ms p99 | ADR-0019 §GET /api/skin | TC-1 in PR #81 |

### Engine ↔ persistence boundary (refresher, no new contract)

- Engine: server-side, stdlib-only (ADR-0017).
- Persistence: server-side, `src/atilcalc/persistence/` (ADR-0022).
- Web shell: client-side, vanilla JS + Web Components, no engine/persistence imports.
- The only server-side endpoints the web shell calls are defined in ADR-0019 (engine HTTP) + ADR-0022 (persistence HTTP). The web shell never opens a database connection.

---

## Rationale

### Why CSS custom properties on `:root` (vs Shadow DOM tokens / theme JSON)

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **CSS custom properties on `:root` (CHOSEN)** | Browser-native; sub-frame swap; no build step; zero deps; per-component Shadow DOM can opt-in via `var(--prop, fallback)`; PM recommendation; already partially implemented in PR #49 | All 14 variables live in one place — drift risk if components add custom vars | **Best fit** for vanilla JS + Web Components + zero-dep stack |
| Shadow DOM tokens (`::part()` API) | True encapsulation; skins scoped per component | Requires `exportparts` declarations; cross-component skin swap (e.g., `<body>` background) doesn't fit; PM rejected as heavier | **Rejected** — over-engineered for 14-var palette |
| Theme JSON + dynamic stylesheet generation | Programmatic; can be served from API | Adds JSON → CSS compile step; runtime overhead; complicates DevTools; CSS custom properties give the same programmability without the indirection | **Rejected** — adds complexity for no win |

### Why 200ms transition on `background` + `color` only

Per Web platform research (CSS specs + Chrome DevTools perf guidance):

- `background` + `color` are **GPU-compositable** (the browser can offload the transition to the compositor; main thread is free for input handling).
- `box-shadow` + `filter` + `border-radius` force **layout/paint** on the main thread for every animation frame; at 60fps this can block input handling on low-end devices (the owner's VM is constrained).
- 200ms << 500ms M4 budget; gives the user a perceivable "transition" effect without feeling slow.

### Why open Shadow DOM (not closed)

- **DevTools**: open Shadow DOM is inspectable in Chrome DevTools. Closed Shadow DOM is opaque to the owner + any future contributors.
- **Debugging**: open Shadow DOM allows ad-hoc queries in the console (`document.querySelector("atilcalc-mode-toggle").shadowRoot.querySelector("button[data-skin='dark']")`).
- **W3C recommendation**: W3C Web Components specs favor open Shadow DOM for general-purpose components; closed is reserved for components with security boundaries (we have none — all UI).

### Why no `lit-html` / framework wrappers

- ADR-0017 + ADR-0018 chose vanilla JS + Web Components specifically to avoid the 30–45KB runtime + toolchain cost of React/Vue/Svelte.
- `lit-html` is ~5KB but still adds a dep, a learning curve, and a build consideration if you want to ship `lit` as ESM.
- The hand-rolled `connectedCallback()` + `attributeChangedCallback()` pattern is ~10 lines per component. For ~6 components, that's 60 lines of overhead — cheaper than 5KB of `lit` runtime + a learning curve.

### Why no localStorage for skin persistence (STORY-010)

Per Issue #72 design question and PM recommendation:
- localStorage is **per-browser** (cleared if user switches browsers; not synced across browsers on the same device).
- localStorage is **per-device** (does not satisfy M4 cross-device clause).
- SQLite via ADR-0022 is the unified storage backend (per Issue #80 R-5 commitment: bundling STORY-010 with STORY-007 persistence).

### Why no `package.json` / build step

- ADR-0017 + ADR-0018 explicitly chose zero-dep + no build step. The browser parses `src/atilcalc/web/*.js` directly.
- This ADR does NOT reopen that decision. A `package.json` would require a follow-up ADR.

---

## Alternatives considered

### A. CSS custom properties on `:root` + open Shadow DOM (chosen)

- **Pros**: zero deps; sub-frame skin swap; DevTools-inspectable; Web-standard; aligns with PM + dev consensus from Issue #76 sizing; partially implemented in PR #49 (Sprint 1)
- **Cons**: 14-variable palette must stay synchronized between `theme.js` and `styles.css`; drift risk if components add new vars without updating both
- **Verdict**: chosen

### B. Shadow DOM tokens (`::part()` API) per component

- **Pros**: true encapsulation; skin can scope per component
- **Cons**: cross-component skin swap (body background, document-level theming) doesn't fit; `exportparts` adds complexity; heavier than global CSS variables for 14-var palette
- **Verdict**: rejected (PM lean at Issue #76 sizing)

### C. Theme JSON + dynamic stylesheet generation

- **Pros**: programmatic; can be served from API; dynamic skins without rebuild
- **Cons**: adds JSON→CSS compile step; runtime overhead; complicates DevTools; CSS custom properties give the same programmability
- **Verdict**: rejected

### D. `<picture>` + media-query-based skin (no JS swap)

- **Pros**: zero JS for skin swap; follows OS preference
- **Cons**: doesn't allow user override; no third "retro" option (OS is dark/light only); doesn't satisfy "user picks a skin" requirement
- **Verdict**: rejected (Story-009 spec requires user-pickable skin)

### E. Svelte 5 components (open ADR-0018)

- **Pros**: ergonomic; compiled
- **Cons**: requires build step; contradicts ADR-0018; reopens an accepted decision
- **Verdict**: rejected (ADR-0018 closed this option)

---

## Consequences

### Positive

- **Zero new deps**. The skin system + Web Component contracts are pure stdlib browser APIs.
- **M4 <500ms transition** cleared with 60% headroom (200ms transition << 500ms budget).
- **M3 keyboard-only** preserved: `<atilcalc-mode-toggle>` is keyboard-accessible (Tab to focus, Enter/Space to activate button).
- **M4 cross-device** satisfied by ADR-0022 `skin` table + `GET /api/skin` + `PUT /api/skin` (no localStorage).
- **DevTools-friendly** for the owner (open Shadow DOM, no source maps, no build artifacts).
- **Story-009 (STORY-009 spec) + STORY-010** are mechanically implementable against this ADR.
- **No ADR-0018 reopen needed** — this ADR clarifies ADR-0018's §Open questions, doesn't change the framework decision.

### Negative

- **14-variable palette drift risk**: if a component adds a new CSS variable, both `theme.js` (3 palettes) and `styles.css` (defaults) need to be updated. Mitigated by: a single source of truth file `src/atilcalc/web/palette.js` exporting both the default values and the 3 palettes (proposed for STORY-009 implementation PR).
- **No dark-mode auto-detection** (`prefers-color-scheme`): the user must explicitly pick a skin via `<atilcalc-mode-toggle>`. Mitigated by: ADR-0018 chose this trade-off; revisit in Sprint 3+ if owner requests it.
- **No third-party skin marketplace**: the 3 skins (dark, light, retro) are hardcoded in `theme.js`. Adding a 4th skin = code change. Acceptable for MVP-1; user-extensible skins are Sprint 3+ stretch.
- **Skin storage is SQLite only**: STORY-010 can't fall back to localStorage if the API is unreachable. Mitigated by: ADR-0019 §Error envelope (5xx returns retryable=true; UI shows error toast; user stays on last-applied skin).

### Out of scope (deferred to follow-up tickets)

| Item | Sprint | Owner |
|---|---|---|
| User-extensible skins (custom palette JSON upload) | Sprint 3+ | @product-manager scope call |
| `prefers-color-scheme` auto-detection | Sprint 3+ | @developer (small follow-up) |
| Skin transition sound effect (click feedback) | not in MVP | n/a |
| Per-component skin override (override palette for `<atilcalc-display>` only) | Sprint 3+ | not justified by use case |
| STORY-009 implementation PR (skin system + 3 palettes) | Sprint 2 P1 | @developer (unblocked by this ADR) |
| STORY-010 implementation PR (skin persistence via ADR-0022) | Sprint 2 P1 | @developer (unblocked by this ADR + ADR-0022) |

### Follow-up tickets to file

- [ ] STORY-009 implementation PR (developer-owned; against this ADR's skin model)
- [ ] STORY-010 implementation PR (developer-owned; `PUT /api/skin` + cross-device via ADR-0022)
- [ ] Optional follow-up: refactor `theme.js` to single source of truth `palette.js` (architect P3 #1)
- [ ] CI gate: smoke test for skin swap (`tests/web/test_skin_swap.py` using Playwright) — covered by PR #81 TDD red contract

---

## What this ADR commits to *now*

- **Theming model**: CSS custom properties on `:root` (14-variable palette) + global `styles.css` + per-component Shadow DOM with `var(--prop, fallback)`.
- **3 skin palettes**: dark (default), light, retro (terminal-green).
- **Skin swap mechanism**: `applySkin()` in `theme.js` sets 14 CSS variables + `document.body.dataset.skin`; `<atilcalc-mode-toggle>` dispatches `skin:change` event.
- **Skin transition**: 200ms GPU-compositable (`background` + `color` only).
- **Web Component contracts**: `<atilcalc-*>` naming, open Shadow DOM, `:host { ... }` styles, document-level CustomEvents (`skin:change`, `engine:error`, `help:open`), `connectedCallback()` idempotent pattern.
- **Skin storage**: in-memory (STORY-009) + persistent SQLite via ADR-0022 (STORY-010). No localStorage.
- **No `package.json` / build step** (preserves ADR-0017 + ADR-0018).
- **No new dev/runtime deps**.

---

## Cross-references

- **Framework choice**: [ADR-0018](ADR-0018-front-end-framework.md) (vanilla JS + Web Components — accepted)
- **Tech stack**: [ADR-0017](ADR-0017-tech-stack.md) §Concrete stack (zero-dep engine ↔ UI separation)
- **HTTP API**: [ADR-0019](ADR-0019-api-contract.md) §GET /api/skin + §PUT /api/skin (skin HTTP contract)
- **Persistence**: [ADR-0022](ADR-0022-persistence-layer.md) §Schema (`skin` table) + §Cross-device sync (NFS)
- **Initial skin system**: [PR #49](https://github.com/atilcan65/AtilCalculator/pull/49) (Sprint 1 STORY-003b — 3 deferred components shipped)
- **TDD contract**: [PR #81](https://github.com/atilcan65/AtilCalculator/pull/81) (STORY-008 TDD red — 21 tests; skin swap + history + pagination)
- **Sizing output**: [Issue #76](https://github.com/atilcan65/AtilCalculator/issues/76) (architect + developer + tester columns; PM rec = CSS variables)
- **Architect pre-work**: [Issue #80](https://github.com/atilcan65/AtilCalculator/issues/80) (this ADR is the second of 3)
- **Stories unblocked**: [Issue #71](https://github.com/atilcan65/AtilCalculator/issues/71) (STORY-009); [Issue #72](https://github.com/atilcan65/AtilCalculator/issues/72) (STORY-010)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
