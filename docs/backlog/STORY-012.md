# STORY-012: Owner-facing documentation pass (README + in-app help + keyboard shortcuts reference)

## User Story
As a **P1 — Atil (owner-operator) + future contributors / auditors**,
I want **clear, complete, owner-facing documentation: a refreshed README with install/run/test commands, an exhaustive in-app `?`-popup listing all keyboard shortcuts (basic + scientific), and a USER-GUIDE explaining skin modes, history view, and scientific functions**,
So that **I (and any future guest / auditor / me-3-months-from-now) can install, run, and use the calculator without reading the source code or asking me (M2 lower-friction + contributor onboarding)**.

## Why now
Sprint 1 shipped the engine + HTTP surface + 6 Web Components + Sprint 2 will add skins + history + scientific functions. The README still references the dev-studio-template's placeholder content; the in-app `?`-popup content was scaffolded in Sprint 1 STORY-003b but doesn't include Sprint 2's new affordances. Documentation debt compounds; better to refresh now than after Sprint 3+ additions.

## Acceptance Criteria
- **AC1** — GIVEN a fresh clone of the repository WHEN the owner reads `README.md` THEN the document explains (a) what AtilCalculator is (1 paragraph), (b) prerequisites (Python 3.11+, port 8000), (c) install command (`pip install -e .[dev]`), (d) run command (`uvicorn atilcalc.api.app:app --host 192.168.1.199 --port 8000`), (e) test command (`pytest -q`), (f) link to `docs/USER-GUIDE.md` and `docs/product/vision.md`.
- **AC2** — GIVEN the user opens the in-app `?`-popup WHEN the popup renders THEN it lists ALL keyboard shortcuts in 3 sections: **Basic** (0-9, +-*/, Enter=equals, Esc=clear, Backspace=delete, ?=help), **History** (↑↓=navigate, Enter=load, /=search-focus, Esc=close-search), **Scientific** (s=sin, c=cos, t=tan, l=log, n=ln, r=sqrt, !=factorial, d=deg/rad toggle, m=mode toggle basic/scientific).
- **AC3** — GIVEN `docs/USER-GUIDE.md` exists WHEN read THEN it covers: skin modes (Dark/Light/Retro — what each looks like, how to switch, when each is best), history view (scroll, search, click-to-load, infinite scroll), scientific mode (entering trig, rad/deg toggle, precision notes), keyboard reference (cross-link to in-app `?`-popup), troubleshooting (port conflicts, VM hardening prerequisites, backup policy reference).
- **AC4** — GIVEN any merged PR changes user-facing behavior WHEN the PR is merged THEN `CHANGELOG.md` has an `[Unreleased]` → `Added`/`Changed`/`Fixed` entry describing the user-visible change (conventional-changelog-style).
- **AC5** — GIVEN the owner runs the docs locally (no build step) WHEN reading any markdown file THEN it renders cleanly in GitHub's UI (no broken links, no missing images, mermaid diagrams render).

## Out of scope
- Marketing / landing page content (this is an owner-self-hosted tool, not a public product).
- Turkish translation of owner-facing docs (vision §Open Questions Q to owner; default = English-only matching project convention).
- API reference for external integrators (no external API in MVP — HTTP surface is internal).
- Architecture deep-dives (those live in `docs/decisions/ADR-*.md` and are already maintained).
- Contributor / developer docs (those live in `.claude/CLAUDE.md` + soul files + ADR index).

## Open questions
- [ ] **PM-led**: USER-GUIDE structure — single long page vs split per topic? PM proposes single page (easier to grep, easier to link). → PM
- [ ] **Owner**: Turkish mirror section for owner-facing docs? Vision §Open Questions Q5: "Docs language: keep this vision document English-only, or add a Turkish mirror section for owner-facing reference?" → owner @atilcan65
- [ ] **Designer**: In-app `?`-popup layout — single scrollable list vs sectioned/tabbed? PM proposes sectioned (basic | history | scientific) for scannability. → designer (PM-led) + architect review

## Mockups / references
- vision.md §Core Problem + §Out-of-scope (for the "what this isn't" framing in docs)
- `<atilcalc-help-popup>` Web Component spec (Sprint 1 STORY-003b, Issue #31 body)
- ADR-0017 + ADR-0018 + ADR-0019 (architecture context for the README's "how it works" section)
- All Sprint 2 stories (STORY-007/008/009/010/011) — USER-GUIDE references them as features

## Dependencies
- **Upstream**:
  - Sprint 2 STORY-007/008/009/010/011 (docs reference their shipped features; can be drafted in parallel and merged with each feature)
  - `<atilcalc-help-popup>` Web Component (Sprint 1, shipped — content is data-driven from a registry)
- **Downstream**: Sprint 3+ — ongoing CHANGELOG hygiene per AC4.

## Metrics of success
- **Leading**: README + USER-GUIDE + in-app help completeness — all Sprint 1 + Sprint 2 features documented (checklist verification).
- **Leading**: zero broken internal links in markdown files (lint check via `markdown-link-check` or equivalent).
- **Lagging**: M2 lower-friction — owner uses `?`-popup or USER-GUIDE instead of source-code diving (proxy: zero "where is X documented?" asks post-launch).
- **Lagging**: contributor onboarding success — a hypothetical fresh contributor can install + run + test from README alone (testable via "out-of-band" exercise, perhaps Sprint 3 retro input).