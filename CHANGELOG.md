# Changelog

All notable changes to this project are recorded here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **TD-019 — Orchestrator guidance cross-check doctrine (P2; refs #152 RCA-7, Issue #156).** Sister entry to TD-016 + TD-018 in the "blind-spot family". On Issue #152 P0 (RCA-7 deploy failure), @orchestrator's 04:47Z guidance included a hallucinated module path `atilcalc.web.app:app`; canonical is `atilcalc.api.main:app` (12 references: `scripts/run-server.sh` + 11 test files). Doctrine: before issuing prod-host commands, workflow YAML snippets, or design doc recommendations, agents MUST grep the canonical entry script and confirm (a) module path, (b) restart mechanism, (c) preflight steps, (d) post-deploy verification. Captured in `docs/tech-debt.md` row TD-019 + new "Blind-spot family" section consolidating TD-016 + TD-018 + TD-019 as instances of the same class (agent must trace MORE than local shape before verdicts). ADR-0027 supplement section added with actual prod instance details (hostname `atiltestweb`, deploy path `/home/atilcan/atilcalc`, canonical restart = nohup+setsid, canonical module = `atilcalc.api.main:app`). RETRO-003 consolidation planned. See [Issue #156](https://github.com/atilcan65/AtilCalculator/issues/156), [Issue #152 cmt 4756498070](https://github.com/atilcan65/AtilCalculator/issues/152#issuecomment-4756498070) (orchestrator's 04:47Z guidance), [Issue #152 cmt 4756543400](https://github.com/atilcan65/AtilCalculator/issues/152#issuecomment-4756543400) (orchestrator's 05:03:51Z RCA), and PR #158 (this docs PR). **Note on AC mismatch**: Issue #156 AC references `ADR-0010-per-project-watchers.md` for the supplement, but the actual deploy ADR is `ADR-0027-deploy-automation.md` (which contains the `192.168.1.199` reference and `systemctl --user` pattern); architect amended ADR-0027 instead and flagged the mismatch in the PR description for @orchestrator confirmation. See [Issue #156](https://github.com/atilcan65/AtilCalculator/issues/156) "Escalate to @orchestrator if" clause.

- **#113 — Watchdog: `issue_assigned_any_status` event kind (Issue #113
  Part B, refs #113, closes #113 Layer B).** New watchdog query
  `query_assigned_issues_any_status()` in `scripts/agent-watch.sh` emits
  `issue_assigned_any_status` events for every open issue with
  `agent:<role>`, regardless of `status:*` label (backlog, ready,
  in-progress, blocked). Closes the silent-drop gap where agents with
  backlog-only work saw no wake events (2026-06-19 incident with
  #71/#72/#74 — issues were `status:backlog` + `agent:developer` but
  the agent's `issue_assigned` query only fired on `status:ready` or
  later). Throttled per (issue, role) at 5-min buckets; kill switch
  `QUERY_ASSIGNED_ANY_STATUS_ENABLED=false`. Context payload carries
  status + actionability hint (`ACTIONABLE` for ready/in-progress,
  `informational` for backlog/blocked) so agents reading the event know
  not to start work without PM grooming. Event ID format:
  `issue-assigned-any-<n>-b<bucket>` (sister to `stale-verdict-<n>` and
  `mention-<role>-<n>` per ADR-0024 + ADR-0026). Doctrinally aligned
  with Issue #113 Layer A (soul clause: "labels = ownership, body may
  be stale"). 9-case regression test
  `scripts/tests/d013-issue-assigneeship-authority.sh` (T1 function
  exists, T2 kill switch, T3 kind emitted, T4 ID format, T5 status
  field, T6 ACTIONABLE, T7 informational, T8 poll_once integration, T9
  kinds enum). See [`docs/backlog/#113`](docs/backlog/) + PR #114
  (merged 2026-06-19T13:40:35Z, commit `236c759`). Companion to PR
  #115 (Issue #113 Layer A — issue-assigneeship-authority clause in 4
  soul files, merged 2026-06-19T08:00:45Z).

- **STORY-012 — Owner-facing documentation pass (P2; refs #74).**
  Refreshed `README.md` from the dev-studio-template placeholder to
  AtilCalculator-specific content (intro + prereqs + install + run + test
  + links to `docs/USER-GUIDE.md` and `docs/product/vision.md`). Created
  `docs/USER-GUIDE.md` covering the 5 owner-facing topics: Skin modes
  (Dark/Light/Retro with WCAG-AAA contrast + auto-discovery), History
  view (scroll / search / click-to-load / infinite scroll), Scientific
  mode (trig, rad/deg toggle, precision notes, DomainError mapping),
  Keyboard reference (cross-linked to in-app `?` popup), Troubleshooting
  (port conflicts, VM hardening, SQLite locking, backup policy).
  Extracted the keyboard shortcut registry to
  `src/atilcalc/web/shortcuts.js` (single source of truth per ADR-0023
  §Help popup content) and rewired `<atilcalc-help-popup>` to render
  the 19 shortcuts in 3 sections (Basic | History | Scientific). Added
  scientific single-letter handlers to the keyboard FSM (`s`→`sin(`,
  `c`→`cos(`, `t`→`tan(`, `l`→`log(`, `n`→`ln(`, `r`→`sqrt(`, `!`→`!`),
  plus `d` (deg/rad toggle), `m` (mode toggle), `↑`/`↓` (history
  navigation), and `/` (history search-focus) as CustomEvent
  dispatches. The FSM and popup are now wired through the same
  registry — they cannot drift (test_help_popup.py AP-2 invariant).

- **STORY-011 — Scientific functions (P1; refs #73).**
  Engine + API surface for sin / cos / tan / log / ln / sqrt / factorial
  (trig accepts `45 deg` unit suffix; rad/deg toggle via `deg=True`
  flag or `d` keyboard shortcut). New `DomainError` exception class
  maps to HTTP 400 with envelope
  `{"error": {"code": "DomainError", "message": "..."}}`. Precision
  via `mpmath==1.3.0` (50-digit internal, 28-digit Decimal response)
  per ADR-0019 amend 2. 71/71 engine tests green; 10/10 API
  transcendental tests green; 0 wider regressions.

- **STORY-010 — Skin preference persistence (P1; refs #72).**
  SQLite-backed skin state in `src/atilcalc/persistence/skin.py` with
  `skin` table (single-row `current` key) and `skin_audit` log
  (idempotency_key UNIQUE + ts). PRAGMAs `journal_mode=WAL` +
  `busy_timeout=5000` per ADR-0022. Cross-device sync via shared
  SQLite file (NFS-equivalent) — no application-level sync layer.
  Idempotency-Key read from HEADER (not body) per ADR-0019 §Idempotency;
  race-safe UNIQUE handling on `idempotency_key` (same key + same
  body → 200 cached, same key + different body → 409 Conflict).
  Replaces the in-memory `_skin_state` and `_idempotency_cache` from
  PR #37 (STORY-009 MVP-1). 13 new test files covering cross-device,
  durability, concurrency, idempotency contract.

- **STORY-009 — Skin system (P1; refs #71).**
  ≥3 built-in skins (Dark, Light, Retro) as auto-discovered CSS files
  in `src/atilcalc/web/skins/`. WCAG-AAA contrast per skin (18.9:1 /
  18.0:1 / 13.7:1). Skin attribute on `<html>` drives CSS custom
  properties (no JS palette swap). `Idempotency-Key` header (UUID v4)
  on `PUT /api/skin` per ADR-0019; unknown skin → 400
  `UnknownSkinError`. 13/13 contract tests green.

### Fixed

- **#6 — Watcher re-fires on every label/comment bump (P1, sibling of #61).**
  `agent-watch.sh` constructed `issue_assigned`, `board_change`, and
  `pr_labeled` event IDs from `.updatedAt`. Because `updatedAt` bumps on
  every comment / label-edit / assign — even when the watched label set is
  unchanged — every metadata flick produced a fresh event ID and re-woke
  the assigned agent. Repro: orchestrator's `processed_event_ids` showed
  five distinct entries for `board-1` (`13:19:49Z`, `13:21:58Z`,
  `13:23:37Z`, `13:24:34Z`, `13:24:48Z`) for the same Issue #1 with no
  real state change between them; same pattern was firing `pr-labeled-5`
  repeatedly on PR #5 every time the architect touched a label during
  their retraction cleanup. The fix switches the three event-ID
  constructions from `+ "-" + .updatedAt` to
  `+ "-" + (.labels | map(.name) | sort | join("|"))` (and equivalent
  for `pr_labeled`, whose `labels` is already a flat string array). The
  dedup chain (`processed_event_ids` ring) was working correctly all
  along — the bug was upstream, in ID *construction*, not in mark/trim.
  Net effect: a comment on an unchanged-assignment issue is now silently
  absorbed; a real label-set change still fires; an idempotent flip
  (add X then remove X) collapses to the original ID and is suppressed.
  Regression pin: `scripts/tests/d006-stable-event-ids.sh` (5/5 PASS,
  including end-to-end watcher invocation against a mocked `gh`).

- **#61 — Watcher phantom re-delivery of `board-*` events (P1).** Orchestrator's
  `agent-watch.sh` loop was receiving the same two `label_change` events
  (`board-50-*`, `board-52-*`) repeatedly across polls, even though both source
  issues are CLOSED with `status:done` and the resolving PRs (#51, #54) are
  merged. Two interacting bugs caused the dedup chain to fail: **(A)** the
  three HWM vars (`LAST_SEEN`, `PR_MERGED_LAST_SEEN`, `PR_LABELED_LAST_SEEN`)
  were read ONCE at script start and never refreshed inside `poll_once`, so a
  long-running `--loop` watcher's local vars drifted behind the state file's
  HWM and the gh query kept returning historical events; **(B)** the
  `processed_event_ids` FIFO trim (default 50) was evicting the still-active
  phantom event IDs as newer events flooded in. The fix moves all three HWM
  reads into `poll_once` (via `init_pr_merged_hwm` and `init_pr_labeled_hwm`
  helpers) and bumps `DEFAULT_TRIM_MAX` from 50 to 200 as a backstop. The
  orchestrator's INBOX is now clean across 10+ consecutive polls. Regression
  pin: `scripts/tests/d213-phantom-board-dedup.sh` (10/10 PASS).

- **#95 — Sprint 2 plan.md stale dep list (P3 chore).** Dropped
  `sqlmodel==0.0.22` + `alembic==1.13.x` lines from `docs/sprints/sprint-02/plan.md`
  (line 66, STORY-007 AC; lines 197-198, deps table) — ADR-0022 §Decision chose
  stdlib `sqlite3` only (no ORM, no migration framework) per ADR-0017 boring-tech
  principle. Plan was drafted at 14:50Z but PR #82 (ADR-0022) committed at 15:59Z;
  plan was never updated to match. No code impact (pyproject.toml is the actual
  source of truth for runtime deps); pure docs hygiene. See Issue #92 architect
  note (PR #92 cmt #4745155530) and ADR-0022.

- **STORY-002 — `app/main.py` now registers a SIGTERM handler (TC-8 unblock).**
  `kill <pid>` (SIGTERM) on the uvicorn process used to exit with code
  `143` (= 128 + SIGTERM), which breaks container/k8s/systemd graceful
  shutdown. The handler is installed at module-import time and calls
  `os._exit(0)` (C-level `_exit(2)`), mirroring uvicorn's own SIGINT
  behaviour without raising `SystemExit` — this avoids a `CancelledError`
  traceback from the asyncio loop's pending Starlette `lifespan` task,
  satisfying STORY-001 AC4 ("no traceback on shutdown"). No-op for
  Ctrl-C development; load-bearing the moment the service ships to a
  process supervisor. See PR #24 (`test_sigterm_exits_zero`) for the
  subprocess-level regression pin and PR #25 / `tests/test_sigterm_handler.py`
  for the in-process pin.

### Added

- **STORY-007 — Persistent cross-device history (SQLite backend)** (Sprint 2,
  P0; refs #69, closes #69). New persistence layer in
  `src/atilcalc/persistence/history.py` (stdlib-only `sqlite3` + `threading` +
  `uuid`; preserves ADR-0017 engine↔UI separation — persistence is a sibling
  module, not nested in the engine). PRAGMAs `journal_mode=WAL` +
  `synchronous=NORMAL` per the persistence-layer design (ADR-0022, in-review
  via PR #82 — impl proceeded against the open ADR per the human owner's
  Option A go-ahead; architect-acknowledged in PR #88 review). Schema:
  `history(id INTEGER PK, expr TEXT, result TEXT, ts TEXT,
  idempotency_key TEXT UNIQUE)` with `idx_history_ts DESC` + `idx_history_expr`
  for newest-first ordering + substring-search perf. `POST /api/history`
  requires `Idempotency-Key` header (UUID v4); missing → 400
  `MissingIdempotencyKeyError`, malformed → 400 `InvalidIdempotencyKeyError`,
  same-key + same-payload → 201 (idempotent replay), same-key +
  different-payload → 409 `IdempotencyConflictError`. `GET /api/history`
  returns envelope `{"history": [...], "cursor": null}` (cursor MVP-1 is
  null, no pagination yet). `POST /api/evaluate` persists best-effort
  (try/except + WARNING log; eval response preserved on persistence failure
  per AC1 "does not block eval"). Decimal-as-string serialization preserved
  end-to-end (AC7 `0.1+0.2 = "0.3"` lossless; no NUMERIC/REAL coercion —
  trailing zeros from `str(Decimal)` round-trip cleanly). 26 new tests across
  5 files: history endpoint (9), idempotency (4 + 1 skip for freezegun
  deferred), durability (3), search perf (3), decimal precision (4). Test
  infrastructure fixes also landed (PR #88): `_temp_db` conftest fixture
  missing `yield` (tests using `sqlite3.connect(db_path)` directly were
  deleting the temp file before the test body ran), case-sensitive schema
  assertion in `test_history_decimal_precision.py` (`"result TEXT"` →
  `"RESULT TEXT"` to match the uppercased `schema_sql`).
  See [`docs/backlog/STORY-007.md`](docs/backlog/STORY-007.md) (full AC +
  Gherkin), [`docs/decisions/ADR-0022-persistence-layer.md`](docs/decisions/ADR-0022-persistence-layer.md)
  (schema + PRAGMA spec, in-review via PR #82), PR #79 (TDD red, merged
  2026-06-18T16:12:06Z), PR #88 (impl, merged 2026-06-18T18:32:56Z, commit
  `a56be89`), and PR #90 (PM bookkeeping, in-review).

- **STORY-008 — History UI wiring (render + substring search + click-to-load)**
  (Sprint 2, P0; refs #70, closes #70). Rewires `<atilcalc-history>` from
  in-memory deque to backend `GET /api/history` (ADR-0019 amend 2 envelope per
  PR #84 MERGED). Sprint 1 surface preserved (`pushEntry` does optimistic
  append + background re-sync via `loadPage`). All 6 ACs wired across 6
  commits + 1 post-merge CI fix:
  - AC1+AC4 (`169671a`): `loadPage({limit?,before?,q?})` async fetch +
    Sprint 1 surface + `data-ts`/`data-expr` attributes + clickable entries.
  - AC2 (`c56d8cc`): `<input type="search">` in shadow DOM + 100ms debounce
    per AC2 perf budget (PR #103 backoff alignment spec).
  - AC3 (`12fd4fe`): click + keydown(Enter) → `history:entry-selected` event;
    global FSM listener wires it to `setInput` + `setResult`.
  - AC5 (`9fd8337`): scroll-to-bottom detection (8px threshold) →
    `_appendPage({before: oldest_ts})` for infinite scroll; dedup by ts.
  - AC6 (`bafff04`): `_fetchWithBackoff` with 250/500/1000ms × max 3 retries
    (PR #103 alignment); `history:error` events with phase discriminator
    (`retry-1`/`retry-2`/`retry-3`/`retry-exhausted`).
  - Infra (`cb76d26`): `tests/web/conftest.py` Playwright + FastAPI server
    fixture — session-scoped `atc_server` (127.0.0.1:`<free_port>` via
    `subprocess.Popen`, `/healthz` 30s readiness probe), session-scoped
    `browser` (Playwright Chromium headless), function-scoped `browser_page`
    (fresh `browser_context` per test, waits for 3 custom elements attached).
  - CI fix (`170e5fa`, post-merge): `_playwright_available()` now probes the
    chromium binary on disk (default `~/.cache/ms-playwright`, override via
    `PLAYWRIGHT_BROWSERS_PATH`); `browser` fixture wraps `chromium.launch`
    in try/except → skips with actionable message on launch failure;
    `atc_server` derives `cwd` from `__file__` (was hardcoded
    `/home/atilcan/projects/atilcalc-developer`, CI-broken). Result: CI Lint
    & Test went from 31 errors (browser launch) → 31 skipped with the same
    actionable message.
  See [`docs/backlog/STORY-008.md`](docs/backlog/STORY-008.md) (full AC +
  Gherkin), [`docs/designs/STORY-008-impl-design.md`](docs/designs/STORY-008-impl-design.md)
  (design PR #100, MERGED), and PR #111 (merged 2026-06-19T11:21:14Z,
  commit `c5e0ac4`). Closes #70.

- **STORY-001 — FastAPI service skeleton with `GET /healthz`** (Sprint 1, P0).
  Standalone FastAPI service runnable from a clean clone with one command
  (`make run`); liveness probe at `/healthz` returns `200 OK` with
  `{"status": "ok"}` and `Content-Type: application/json`. Unknown paths
  return `404` (not `500`). `Ctrl-C` exits cleanly with code `0`.
  See `docs/backlog/sprint-1/STORY-001-fastapi-skeleton-healthz.md` (Sprint 1 archive; path preserved as historical reference — file lives in the project history),
  `docs/designs/STORY-001-design.md` (Sprint 1 design — same archive),
  and `docs/decisions/ADR-0001-fastapi-skeleton.md` (Sprint 1 ADR — same archive).

- **STORY-003a — Web shell core: HTTP surface + 3 Web Components + keyboard FSM**
  (Sprint 1, P0; refs #30, closes #35). 4 API endpoints per ADR-0019
  (`POST /api/evaluate`, `GET /api/history`, `GET /api/skin`, `PUT /api/skin`)
  with engine-error envelope (ExpressionSyntaxError / DivisionByZeroError /
  UndefinedOperatorError → 400; EngineError catch-all → 500; pydantic
  ValidationError → 422) and Decimal-as-string serialisation (AC7
  `0.1+0.2 = "0.3"` exact regression pin). `PUT /api/skin` is the only
  state-mutating endpoint and requires `idempotency_key` (replay cache,
  FIFO-bounded 1024). Static SPA shell (vanilla JS, no build step per
  ADR-0018) mounted at `/` with 3 custom elements (`<atilcalc-display>`,
  `<atilcalc-keypad>`, `<atilcalc-history>`) and a 3-state global keyboard
  FSM (idle / entering / evaluated) on an allowlist of 0-9, + - * /, ( ),
  `.`, Enter, Escape, Backspace. Observability harness (ADR-0019
  §Observability) emits structured logs (path, request_id, latency_ms,
  status_code) on every request; error responses carry the same
  `request_id` in the envelope and the log line for correlation. See
  [`docs/backlog/.../STORY-003a-...`](docs/backlog/) (design in PR #37,
  test plan in `docs/test-plans/STORY-003a-tests.md`). Closes d007
  observability regression pin (Issue #35): `bash scripts/tests/
  d007-api-observability.sh` → `TOTAL=8 PASS=8 FAIL=0` (T1 middleware
  + main reference; T2 every route logs; T3 3 engine subclasses + 4
  mapping rows with drift-detect; T4 PUT/POST idempotency_key; T5
  requires-python ≥3.11).

- **STORY-003b — Web shell deferred: 3 components + skin system + E2E + LAN-bind**
  (Sprint 1, P0; refs #31). Completes the 3 deferred custom elements from
  STORY-003a split-out: `<atilcalc-mode-toggle>` (3-button dark/light/retro
  switcher that dispatches `skin:change`), `<atilcalc-help-popup>` (modal
  `<dialog>` listing 8 keyboard shortcuts, opened by `?` and dispatched
  `help:open`), `<atilcalc-error-toast>` (transient banner that listens
  for `engine:error` from the FSM, 5s auto-dismiss, Esc dismiss). Skin
  system infrastructure in `src/atilcalc/web/theme.js` swaps 14 CSS custom
  properties on `:root` from a `PALETTES` object; AC6 transition is
  `body { transition: background 200ms, color 200ms; }` (GPU-compositable
  properties only). Keyboard FSM extensions: `?` → `help:open`, evaluate
  4xx/5xx → `engine:error` (with `type` + `message` + `status`),
  network failure → `engine:error` with `type=NetworkError`. LAN-bind
  per ADR-0019 R-3: new `scripts/run-server.sh` reads `ATC_HOST` (default
  `192.168.1.199` — NOT `0.0.0.0`) and `ATC_PORT` (default `8000`); port
  is validated up front. Playwright E2E contract test in
  `tests/web/test_e2e_keyboard.py` boots uvicorn via `run-server.sh`,
  opens Chromium headless, dispatches real keyboard events, and asserts
  the `<atilcalc-display>` shadow-DOM result for 3 scenarios
  (`1+2=3`, `1+2+3=6`, `7*8=56`). New dev deps: `playwright==1.49.0`,
  `pytest-playwright==0.7.0`. Design-plan deviations from the issue
  dev-plan comment: LAN-bind default follows ADR-0019 (`192.168.1.199`),
  not the `127.0.0.1` originally proposed; surfaced in PR body for
  architect review.

- **STORY-004 — `GET /hello/{name}` greeting endpoint** (Sprint 1, P1).
  Demo-facing route that returns `200 OK` with
  `{"message": "hello, {name}"}` and `Content-Type: application/json`.
  Case is preserved verbatim (no lowercasing); URL-encoded values pass
  through unchanged (e.g. `/hello/%20` → `"hello,  "`). The path segment
  is required, capped at 64 characters to bound log-spam risk; missing
  name returns `404` (FastAPI default), not `500`.
  See `docs/backlog/sprint-1/STORY-004-hello-name-greeting-endpoint.md` (Sprint 1 archive; historical reference).

- **#15 — VM hardening (P0 ops deliverable, STORY-001 infra).** Idempotent
  apply script (`scripts/ops/apply-vm-hardening.sh`, 497 lines) + operator
  runbook (`docs/ops/vm-hardening.md`, 362 lines, AC6) + contract test
  suite (`scripts/tests/test-vm-hardening.sh`, 13/13 PASS). Cardinal
  safety rule hard-coded: never disable password SSH before verifying
  key-based auth works (FATAL if `/root/.ssh/authorized_keys` is
  missing/empty OR loopback key SSH fails). Knobs overridable via env
  (`SSH_PORT`, `HTTP_PORT`, `FAIL2BAN_BAN_TIME`, `FAIL2BAN_MAX_RETRY`,
  `FAIL2BAN_FIND_TIME`, `BACKUP_CRON_EXPR`, `BACKUP_RETENTION_DAYS`);
  `--dry-run` previews without applying. Drop-in
  `/etc/ssh/sshd_config.d/00-vm-hardening.conf` (cleaner than mutating
  `sshd_config` directly); `sshd -t` validates config before reload.
  Owner runs on target VM (`192.168.1.199`) with `sudo`. Open follow-up
  items (P2/P3 from review): T6 test-header comment, T2 default-check
  grep looseness, `TEST_USER` fallback message, trailing newlines, AC1
  `permitrootlogin` doc gap. See Issue #15 and PR #40.

- **STORY-045 — Orchestrator STATUS-block action driver** (Sprint 1,
  P0; refs #45, closes #45). New CLI tool
  `scripts/status-action-driver.sh` (~260 LOC, bash + python3 for JSON
  output) parses the orchestrator's end-of-turn STATUS block (reads from
  `--status-file <path>` or `--from-stdin`; missing or malformed header
  → exit codes 3 / 4) and derives actionable notifications: **Phase 1**
  (P0/P1 blocker escalation → target=human) is always on; **Phase 2**
  (idle-team ping) is flag-gated behind `--enable-phase2` so the
  1-sprint dry-run can validate the false-positive rate before it ships.
  Each derivation is appended to
  `/var/log/dev-studio/AtilCalculator/orchestrator.heartbeat` with a
  `kind=status_derived` audit marker; `--dry-run` logs the derived
  actions but does NOT call `scripts/notify.sh`. Auto-ping format
  follows the existing `[ORCH→HUMAN]` / `[ORCH→ALL]` convention so the
  downstream wake path is identical to manual STATUS processing.
  Regression pin: `scripts/tests/d011-status-action-driver.sh`
  (14/14 PASS — T1 invocation + version, T2 no-blockers path,
  T3–T5 P0/P1/Phase-2 trigger semantics, T6 malformed STATUS exit-3,
  T7 empty stdin exit-4, T8–T11 dry-run vs live notify isolation,
  T12 parsed-field surfacing, T13 audit trail, T14 malformed-blocker
  count). See Issue #45 and PR #64.

### Infrastructure

- `pyproject.toml` — PEP 621, Python `>=3.12,<3.13`, pinned runtime deps
  (`fastapi==0.115.6`, `uvicorn[standard]==0.32.1`) and dev extras
  (`pytest`, `httpx`, `ruff`). Ruff config and pytest config colocated.
- `Makefile` — canonical `install` / `run` / `test` / `lint` / `format`
  targets, all thin wrappers around `uv run` (ADR-0001).
- `.python-version` — `3.12` for `uv python pin` and `pyenv` consumers.
- `app/__init__.py` — package marker with `__version__ = "0.1.0"`.
- `app/main.py` — FastAPI instance + sync `GET /healthz` handler.
- `tests/test_healthz.py` — single skeleton smoke test (AC2 happy path).
  Full contract test suite (404, determinism, subprocess lifecycle,
  README on-ramp timing) lands in STORY-002.
- `tests/test_hello.py` — 4 contract tests for `/hello/{name}` (AC1–AC4
  of STORY-004). Happy-path + case-preservation pair satisfies AC5.
- `README.md` — Sprint 1 repo layout + 4-step "Getting started" (Install
  uv → `make install` → `make run` → `curl /healthz`).
