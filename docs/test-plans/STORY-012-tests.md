# Test Plan: STORY-012 — Owner-facing documentation pass (README + in-app help + USER-GUIDE + CHANGELOG)

## Scope

- **In scope**: AC1 (README has install/run/test commands + links), AC2 (in-app `?`-popup lists ALL keyboard shortcuts in 3 sections), AC3 (docs/USER-GUIDE.md covers skin modes + history + scientific + keyboard + troubleshooting), AC4 (CHANGELOG.md has `[Unreleased]` entries per user-visible PR), AC5 (markdown renders cleanly — no broken links, mermaid diagrams render).
- **Out of scope**: Marketing / landing pages, Turkish translation, API reference for external integrators (no external API in MVP), architecture deep-dives (those live in `docs/decisions/ADR-*.md`), contributor / developer docs (those live in `.claude/CLAUDE.md` + soul files + ADR index).

## Source contracts (ADR pinning)

- **ADR-0017** (Accepted) — Tech stack: Python 3.11+, `pip install -e .[dev]`, `pytest -q`, FastAPI + uvicorn.
- **ADR-0018** (Accepted) — Frontend framework: vanilla JS + Web Components. The `<atilcalc-help-popup>` is data-driven from a registry (per ADR-0023 §Help popup content).
- **ADR-0019** (Accepted + amendments) — HTTP API contract: `GET /api/skin`, `PUT /api/skin`, `POST /api/evaluate`, `GET /api/history`, etc.
- **ADR-0023** (Accepted) — Frontend architecture: keyboard FSM in `src/atilcalc/web/app.js`. Keyboard shortcut registry is the source of truth for `<atilcalc-help-popup>` content.
- **vision.md §M2, M3, M4** — Daily-use stickiness (lower friction via docs), keyboard-only (M3 acceptance test), cross-device (M4 skin persistence).

## Acceptance criteria recap

| AC | Description | Test surface |
|---|---|---|
| AC1 | README has 6 required sections (intro, prereqs, install, run, test, links) | `tests/docs/test_readme.py` |
| AC2 | In-app `?`-popup lists ALL keyboard shortcuts in 3 sections (Basic / History / Scientific) | `tests/web/test_help_popup.py` |
| AC3 | docs/USER-GUIDE.md covers 5 topics (skin modes + history + scientific + keyboard + troubleshooting) | `tests/docs/test_user_guide.py` |
| AC4 | CHANGELOG.md `[Unreleased]` has entries per user-visible PR | `tests/docs/test_changelog.py` |
| AC5 | All markdown files have no broken links + render cleanly | `tests/docs/test_markdown_lint.py` |

## Test Cases

### TC-1: AC1 — README has install command (`pip install -e .[dev]`)
- **Setup**: read `README.md` as UTF-8 text.
- **Steps**:
  1. Assert file exists at repo root.
  2. Assert content contains the string `pip install -e .[dev]` (or `pip install -e ".[dev]"` for shell-safe quoting).
  3. Assert content contains a `## Install` (or similar) section header.
- **Expected**: install command present in README; future owner can copy-paste.

### TC-2: AC1 — README has run command (uvicorn + correct host/port)
- **Setup**: read `README.md`.
- **Steps**:
  1. Assert content matches regex `uvicorn atilcalc\.api\.\w+:\w+ --host \d+\.\d+\.\d+\.\d+ --port \d+` (or similar pattern for the project's actual server module).
  2. Assert host is the LAN VM (per spec AC1.b: 192.168.1.199) OR a configurable default with explicit note.
- **Expected**: run command present and runnable. If host is configurable, README must show the default.

### TC-3: AC1 — README has test command (`pytest -q`)
- **Setup**: read `README.md`.
- **Steps**:
  1. Assert content contains `pytest -q` or equivalent (`pytest`, `make test`, etc.).
  2. Assert content does NOT claim tests can run without dependencies (e.g., must mention `pip install -e .[dev]` prerequisite).
- **Expected**: test command present; reviewer can verify green CI by running locally.

### TC-4: AC1 — README links to USER-GUIDE + vision.md
- **Setup**: read `README.md`.
- **Steps**:
  1. Assert content contains a markdown link to `docs/USER-GUIDE.md`.
  2. Assert content contains a markdown link to `docs/product/vision.md` (or relative `product/vision.md`).
- **Expected**: discoverability — owner can navigate from README to USER-GUIDE and vision.

### TC-5: AC2 — in-app `?`-popup lists Basic section (digits + ops + Enter + Esc + Backspace + ?)
- **Setup**: spawn FastAPI server with all Web Components mounted. Load `/?show_help=1` OR dispatch `help:open` CustomEvent.
- **Steps**:
  1. Locate `<atilcalc-help-popup>` element; assert it has a `Basic` section.
  2. Assert Basic section contains: `0-9` (digits), `+-*/` (operators), `Enter=equals`, `Esc=clear`, `Backspace=delete`, `?=help`.
  3. Assert each shortcut text in the popup corresponds to a registered keyboard handler in `src/atilcalc/web/app.js` keyboard FSM.
- **Expected**: Basic shortcuts all present and functional. Cross-link to `tests/web/test_keyboard_fsm.py` (STORY-003a TC-2..TC-7).

### TC-6: AC2 — in-app `?`-popup lists History section (↑↓ + Enter + / + Esc)
- **Setup**: same as TC-5.
- **Steps**:
  1. Assert `<atilcalc-help-popup>` has a `History` section.
  2. Assert History section contains: `↑↓=navigate`, `Enter=load`, `/=search-focus`, `Esc=close-search`.
  3. Assert each shortcut is wired to the history FSM (per ADR-0023 §History events).
- **Expected**: History shortcuts all present.

### TC-7: AC2 — in-app `?`-popup lists Scientific section (s,c,t,l,n,r,!,d,m)
- **Setup**: same as TC-5.
- **Steps**:
  1. Assert `<atilcalc-help-popup>` has a `Scientific` section.
  2. Assert Scientific section contains: `s=sin`, `c=cos`, `t=tan`, `l=log`, `n=ln`, `r=sqrt`, `!=factorial`, `d=deg/rad toggle`, `m=mode toggle basic/scientific`.
- **Expected**: Scientific shortcuts all present (per STORY-011 ADR-0019 amendment 2 §mpmath + factorial cap + DomainError).

### TC-8: AC3 — USER-GUIDE.md exists and covers 5 required topics
- **Setup**: read `docs/USER-GUIDE.md` (will be created by this story).
- **Steps**:
  1. Assert file exists at `docs/USER-GUIDE.md`.
  2. Assert content contains a `## Skin Modes` (or similar) section covering Dark/Light/Retro + how to switch + when each is best.
  3. Assert content contains a `## History` (or similar) section covering scroll + search + click-to-load + infinite scroll.
  4. Assert content contains a `## Scientific Mode` (or similar) section covering entering trig + rad/deg toggle + precision notes.
  5. Assert content contains a `## Keyboard Reference` (or similar) section cross-linking to the in-app `?`-popup (per AC2).
  6. Assert content contains a `## Troubleshooting` (or similar) section covering port conflicts + VM hardening prereqs + backup policy reference.
- **Expected**: USER-GUIDE.md is comprehensive; future contributor can find any Sprint 1+2 feature documentation.

### TC-9: AC4 — CHANGELOG.md has `[Unreleased]` section with categorized entries
- **Setup**: read `CHANGELOG.md` (file already exists per repo inventory).
- **Steps**:
  1. Assert content contains `## [Unreleased]` section.
  2. Assert content contains at least one `### Added`, `### Changed`, or `### Fixed` subsection under `[Unreleased]`.
  3. Assert content follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format (per existing CHANGELOG header).
- **Expected**: CHANGELOG is up-to-date with user-visible changes since last release.

### TC-10: AC4 — CHANGELOG entry per merged PR with user-visible change
- **Setup**: query GitHub for merged PRs since last release tag (or last `[X.Y.Z]` version in CHANGELOG).
- **Steps**:
  1. For each merged PR with `type:feature` or `fix(*):` in conventional-commit format, assert CHANGELOG `[Unreleased]` has a corresponding entry.
  2. Exempt: chore-only PRs (refactors, dep updates, CI changes) — they don't have user-visible changes.
- **Expected**: zero missing CHANGELOG entries. (CI gate: `tests/docs/test_changelog.py::test_changelog_covers_merged_prs`.)
- **Note**: this test requires GitHub API access; CI must have `GITHUB_TOKEN` with `repo:read` scope.

### TC-11: AC5 — all internal markdown links resolve
- **Setup**: scan all `.md` files in `docs/` and root.
- **Steps**:
  1. For each markdown file, parse all `[text](path)` links.
  2. For each link with a relative path (no scheme), assert the target file exists.
  3. For each link with an absolute path (`/foo/bar.md`), assert it resolves relative to repo root.
- **Expected**: zero broken internal links. (CI gate: `tests/docs/test_markdown_lint.py::test_internal_links_resolve`.)
- **Tools**: `markdown-link-check` (npm) OR custom pytest + regex parser. Recommend custom to avoid npm dependency.

### TC-12: AC5 — mermaid diagrams render without syntax errors
- **Setup**: scan all `.md` files for ` ```mermaid ` code blocks.
- **Steps**:
  1. For each mermaid block, run `mmdc -i <block> -o /dev/null` (mermaid CLI; npm) OR a Python mermaid parser (e.g., `pymmdc`).
  2. Assert zero syntax errors.
- **Expected**: all mermaid blocks render. If npm toolchain is not available in CI, skip with a clear message.

## Adversarial Probes

### AP-1: README claims a command that doesn't actually work
- **Setup**: extract install/run/test commands from README via regex.
- **Steps**:
  1. Run `pip install -e .[dev]` in a clean venv; assert exit 0.
  2. Run `pytest -q`; assert exit 0 (or known-skip count).
  3. Run `uvicorn atilcalc.api.X:Y --host ... --port ...`; assert FastAPI app loads.
- **Expected**: all 3 commands exit successfully. (This is a strong contract — README lies are caught.)
- **Note**: this test runs in CI as part of STORY-012 contract suite.

### AP-2: in-app `?`-popup missing a shortcut
- **Setup**: enumerate ALL keyboard shortcuts from `src/atilcalc/web/app.js` (the FSM source of truth).
- **Steps**:
  1. Load `?`-popup; extract its content.
  2. For each registered shortcut, assert it appears in the popup.
  3. Assert no shortcuts in the popup that are NOT in the FSM (orphan shortcuts → either remove or wire up).
- **Expected**: bidirectional invariant. (Catches drift between code and docs.)

### AP-3: USER-GUIDE.md references a feature that doesn't exist
- **Setup**: parse USER-GUIDE.md sections + cross-reference with shipped stories.
- **Steps**:
  1. For each USER-GUIDE section, identify the story(s) it documents.
  2. Assert those stories are merged (not just spec'd).
- **Expected**: no aspirational docs (docs only describe shipped features).

### AP-4: CHANGELOG entry is wrong (mentions wrong version, wrong category)
- **Setup**: extract all `[Unreleased]` entries.
- **Steps**:
  1. For each entry, parse the PR number (if any).
  2. Cross-check with GitHub PR title + conventional commit type.
  3. Assert category matches: `feat:` → `### Added`, `fix:` → `### Fixed`, `feat!:` or `fix!:` → `### Changed` (BREAKING CHANGE).
- **Expected**: CHANGELOG entries are accurate, not just present.

### AP-5: Mermaid diagram uses deprecated syntax
- **Setup**: scan mermaid blocks.
- **Steps**:
  1. Assert no deprecated syntax (`graph TD` — use `flowchart TD`; `subgraph foo` — verify spelling).
- **Expected**: all mermaid blocks use current syntax.

### AP-6: README link to vision.md is broken after directory restructure
- **Setup**: scan all internal markdown links.
- **Steps**:
  1. For each link to `docs/product/vision.md`, assert file exists at that exact path.
- **Expected**: zero broken links after any directory restructure (caught by CI gate).

## Performance Concerns

### Perf-1: README length is scannable (<300 lines)
- **Setup**: read `README.md`, count lines.
- **Steps**:
  1. Assert line count ≤ 300.
- **Expected**: scannable README. If longer, expect a `## Table of Contents` at top.

### Perf-2: USER-GUIDE.md length is comprehensive but not bloated (<2000 lines)
- **Setup**: read `docs/USER-GUIDE.md`, count lines.
- **Steps**:
  1. Assert line count ≤ 2000.
- **Expected**: comprehensive but not bloated. If longer, split into sub-pages.

## Regression Risk

- **STORY-003a (Issue #30, Sprint 1)**: shipped `<atilcalc-help-popup>` Web Component. AC2 verifies the popup content is complete + wired. **Action**: cross-check existing `tests/web/test_help_popup.py` (if exists) or `tests/web/test_keyboard_fsm.py` for the FSM shortcut registry.
- **STORY-003b (Issue #31, Sprint 1)**: shipped mode-toggle + visual skins. AC3 USER-GUIDE.md must reference these. **Action**: USER-GUIDE.md sprint-2-features section must mention all shipped Sprint 1+2 features.
- **STORY-007/008/009/010/011 (Sprint 2)**: all ship features documented in USER-GUIDE.md. **Action**: USER-GUIDE.md can be drafted in parallel and merged with each feature.
- **CHANGELOG.md**: already exists per repo inventory. **Action**: AC4 is an ongoing hygiene contract, not a one-time fix; CI gate per TC-10.
- **`.claude/CLAUDE.md`**: project-wide context for AGENTS, not owner-facing docs. **Action**: keep separate; AC1 explicitly does NOT cover agent context.

## Test Files to Land

| File | Purpose | ACs |
|---|---|---|
| `tests/docs/__init__.py` | Package marker for tests/docs/ | — |
| `tests/docs/test_readme.py` | README has 6 required sections + install/run/test commands work | AC1, AP-1 |
| `tests/docs/test_help_popup.py` | `<atilcalc-help-popup>` lists ALL shortcuts in 3 sections, bidirectional invariant with FSM | AC2, AP-2 |
| `tests/docs/test_user_guide.py` | docs/USER-GUIDE.md exists + 5 required topics | AC3, AP-3 |
| `tests/docs/test_changelog.py` | CHANGELOG.md `[Unreleased]` has entries per merged user-visible PR | AC4, AP-4 |
| `tests/docs/test_markdown_lint.py` | All markdown links resolve + mermaid blocks valid | AC5, AP-5, AP-6 |

All tests are TDD RED with module-level skip guards. They probe:
- `README.md` exists at repo root
- `docs/USER-GUIDE.md` exists (created by this story)
- `CHANGELOG.md` exists at repo root
- All markdown files are syntactically valid

When implementation lands (README refresh + USER-GUIDE.md creation + CHANGELOG hygiene + help popup registry refresh), all tests will run.

## Pre-Lock Blockers

1. **Keyboard shortcut registry source-of-truth location**: The FSM is in `src/atilcalc/web/app.js`. The help popup is in `<atilcalc-help-popup>`. Where does the shared shortcut registry live? **Action**: confirm with @architect — recommend extracting to `src/atilcalc/web/shortcuts.js` (single source of truth, imported by both FSM and popup).
2. **USER-GUIDE.md structure**: single long page vs split per topic. PM proposes single page. **Action**: confirm with PM before locking test plan.
3. **CHANGELOG entry granularity**: per-PR vs per-feature vs per-sprint. **Action**: confirm with PM — recommend per-PR with conventional-commit type mapping.
4. **Mermaid CLI in CI**: TC-12 requires `mmdc` (npm). CI may not have npm toolchain. **Action**: confirm CI support OR use Python-only mermaid parser (`pymmdc` or custom).

## Out-of-Scope Tests (NOT in this plan)

- Marketing / landing page content (out of scope per AC).
- Turkish translation (open question to owner).
- API reference for external integrators (no external API in MVP).
- Architecture deep-dives (covered by ADR index).
- Contributor / developer docs (covered by `.claude/CLAUDE.md`).
