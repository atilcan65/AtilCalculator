# ADR-0018: Front-end framework for MVP-1 web shell

- **Status**: Proposed
- **Date**: 2026-06-17
- **Deciders**: @architect (@atilcan65 reviewed as product-manager for STORY-004 alignment)
- **Related**: [ADR-0017](./ADR-0017-tech-stack.md) (Accepted — engine ↔ UI separation, FastAPI HTTP surface); [docs/product/vision.md](../product/vision.md) §M3 (keyboard-only) + §M4 (skin swap <500ms); [Sprint 1 STORY-004](../sprints/sprint-01/plan.md#story-004--front-end-framework-adr-p1)

## Context

Sprint 1 STORY-003 (keyboard-first web shell) needs a front-end stack. Per ADR-0017, the FastAPI backend serves a static SPA shell that calls the engine via HTTP. Per vision §Top must-haves + §Operational Constraints, the front-end must be:

1. **Minimum-dependency stack** — no transitive supply-chain surface that an attacker can exploit on a LAN-exposed VM.
2. **AMD-friendly + low-memory** — owner runs on a Proxmox VM with constrained RAM; we will not add a 2MB React runtime on top of the FastAPI process.
3. **SPA, not SSR** — PM lean (confirmed in PR #8 review): the skin system needs client-side CSS variable swap (M4: <500ms), the keyboard-handler state machine (M3) lives in JS, and an SSR roundtrip flickers on skin change which fails M4.
4. **Owner-comfort, solo dev** — no JS build pipeline preferred; what the owner types in the repo should be what runs in the browser, modulo minification at most.
5. **Engine stays server-side** — ADR-0017 §engine ↔ UI separation invariant; front-end is a thin client.

STORY-004 explicitly asks for ≥3 options and a recommendation against these constraints.

## Options considered

| # | Option | Pros | Cons | Verdict |
|---|--------|------|------|---------|
| A | **Vanilla JS + Web Components** (custom elements + ES modules, zero deps) | Zero deps (no `package.json`, no `node_modules`); ships as plain `.html` + `.js` + `.css` in `src/atilcalc/web/`; Web Components are a W3C standard (browser-native); ES modules give us `import`/`export` for code organization; skin swap = toggle CSS custom properties on `:root` (sub-frame, satisfies M4); keyboard handler = single `keydown` listener on `document` with state machine in plain JS | Have to write the component base class ourselves; no JSX-like ergonomics; ~10–15% more LOC than a framework equivalent for the keyboard handler state machine | **✅ CHOSEN** |
| B | Vanilla JS + htmx (server-rendered HTML fragments, near-zero JS) | Smallest JS footprint possible (~14KB htmx minified, can be self-hosted); server-side templating keeps logic in Python; well-suited to forms-and-lists CRUD | **Conflicts with vision SPA** — htmx is fundamentally a server-rendered fragment model; would force a FastAPI roundtrip on every skin swap, failing M4; would force state on the server for keyboard input, complicating M3; PM explicitly chose SPA | ❌ Rejected |
| C | Svelte 5 (compiled, single-file components, `.svelte` → vanilla JS at build) | Best ergonomics-to-runtime ratio in industry; compiles to ~2KB gzip per component; reactive primitives map cleanly to engine result display | **Build step required** — violates owner-comfort + minimum-dep constraints; adds `node_modules` + `package.json` + Vite/Rollup; introduces a JS toolchain that the owner has to maintain; for an MVP-1 of ~6 components the build overhead dwarfs the ergonomic win | ❌ Rejected for MVP-1; revisit at MVP-2 if component count > 20 or state complexity grows |
| D | Single-file React or Vue via CDN (no build step) | Familiar API for any incoming contributor; React 18+ ships a usable build via esm.sh / unpkg | React 18 min+runtime = ~45KB gzip; Vue 3 = ~33KB gzip; both violate minimum-dep + AMD-friendly; CDN dependency at runtime conflicts with LAN-only / no-internet posture; JSX requires a build step anyway (so this is really "React without JSX, which is worse than vanilla") | ❌ Rejected |
| E | WASM / Pyodide for client-side engine | Zero server-side compute per keystroke; "engine in browser" feels like a calculator | **Overkill for MVP-1** — engine is a pure-function module that FastAPI calls in <10ms; round-tripping a WASM build adds complexity for no observable latency win; breaks ADR-0017 engine↔UI separation (engine would now have a JS-boundary interface); doubles the engine test matrix (Python + JS targets) | ❌ Rejected; ADR-0017 §engine stays server-side is reaffirmed |

## Decision

**Use vanilla JavaScript with Web Components (custom elements + ES modules) for the MVP-1 web shell.** No `package.json`. No `node_modules`. No build step. The browser is the runtime; the source files in `src/atilcalc/web/` are what the browser parses directly.

Concretely:

- `src/atilcalc/web/index.html` — single HTML shell, declares `<atilcalc-keypad>`, `<atilcalc-display>`, `<atilcalc-history>` custom elements.
- `src/atilcalc/web/components/*.js` — one file per component, using ES module `export class AtilcalcKeypad extends HTMLElement { ... }`.
- `src/atilcalc/web/styles/*.css` — per-component styles plus a `theme.css` exposing CSS custom properties (`--accent`, `--bg`, `--font-size`, etc.) for the skin system. Skin swap = `document.documentElement.style.setProperty(...)` — no network roundtrip, well under M4's 500ms budget.
- `src/atilcalc/web/keyboard.js` — single global `keydown` listener with a finite state machine (input mode vs result mode vs help-popup mode).
- FastAPI serves `src/atilcalc/web/` as static files at `/`; calls `POST /api/evaluate` with `{expr: "2+3"}` → `{result: 5}` for the engine.

## Rationale

**Why Option A wins on the constraints (in order of weight):**

1. **Minimum-dep + AMD-friendly** — Option A has zero deps. Options C, D each add ≥30KB runtime + a toolchain. Option B has 14KB but the SSR mismatch is fatal (see below). On a constrained VM, "no JS runtime to load" is a real cost, not a theoretical one.
2. **SPA not SSR (PM lean)** — Option B's htmx model forces server roundtrips; it cannot satisfy M4's <500ms skin swap or M3's keyboard state machine without ugly workarounds. Option A is the only one that is genuinely client-state.
3. **Owner-comfort (solo dev)** — Option A's mental model is "open the file, edit, refresh browser." No `npm install`, no build watch, no `package-lock.json` merge conflicts. The owner's GitHub profile shows minimal JS work; vanilla + Web Components is the lowest cognitive overhead.
4. **Reversibility** — Option A is reversible: if at MVP-2 the component count or state complexity justifies a framework, we can adopt Svelte (Option C) by introducing a build step and rewriting components. Going the other direction (framework → vanilla) is hard because you have to delete abstractions. **Bezos one-way-door heuristic: take the reversible door.** Option A is the two-way door.
5. **ADR-0017 engine↔UI separation preserved** — engine stays server-side in FastAPI; web shell is a thin client. Options E (WASM) would have broken this; Option A respects it cleanly.

## Consequences

**Positive:**
- Zero supply-chain risk from JS dependencies (no `package.json`, no `npm audit` to run).
- Cold page load = single HTML + 5–6 component JS files + 2 CSS files, all served from local disk by FastAPI. No CDN roundtrips. Works on the LAN VM with no internet.
- The skin system is a one-line CSS variable swap — M4 trivially satisfied.
- The keyboard handler is a single global listener with a 3-state FSM — M3 testable in isolation.
- The owner can debug with browser DevTools without source maps or build artifacts.
- STORY-003 (web shell) becomes the simplest possible thing.

**Negative / tradeoffs:**
- ~10–15% more LOC than a framework equivalent for the keyboard handler state machine (we hand-roll the FSM transitions).
- No JSX-style ergonomics for component markup — we use `document.createElement` + `innerHTML` patterns. Acceptable for ~6 components.
- If MVP-3 introduces heavy interactivity (drag-to-reorder history, graphing), this decision will need revisiting. Sprint 2 STORY-003 is currently scoped to MVP-1 only.
- The owner will need to learn the Web Components API (custom elements + shadow DOM). ~1-hour learning curve; well-documented at MDN.

**Follow-ups:**
- Sprint 1 STORY-003 implementation must use this pattern (acceptance gate in STORY-004 DoD: "STORY-003 PR uses the chosen approach").
- Sprint 2 stretch STORY-007 (persistence ADR) must respect this decision: history UI = `<atilcalc-history>` custom element, no React/Svelte rewrite.
- If Sprint 3+ adds graphing or plotting, reopen this ADR with a "supersede" candidate (Svelte 5 compiled + a thin vanilla shell that hosts the Svelte island). Keep this door open by not letting the surface area expand past ~15 components before reassessing.
- Tooling: do NOT add `package.json` to this repo unless an explicit ADR reopens it.

## Open questions

- [ ] **CSS organization**: per-component scoped via Shadow DOM (encapsulated but harder to skin globally) vs global `theme.css` (easier skin swap but no encapsulation). Pre-vision lean: global `theme.css` + Shadow DOM for component-specific layout only. Owner to confirm in PR review.
- [ ] **Testing harness**: Web Components + ES modules testable via Playwright (already cited as test infra in ADR-0017 §test strategy). No unit test runner needed for the front-end at MVP-1; E2E covers it.
- [ ] **Minification**: ship minified or readable `.js` in production? Pre-vision lean: readable for MVP-1 (the VM is on the LAN, no bandwidth concern; readability helps debuggability). Revisit if the surface grows past ~20 components.
