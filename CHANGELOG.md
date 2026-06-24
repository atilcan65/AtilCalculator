# Changelog

All notable changes to this project are recorded here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Issue #237 — Atomic-write state recovery (Sprint 4 P1).** Tester state file `processed_event_ids` corrupted 200→2 (unrecoverable). Root cause: `agent-state.sh` `jq_inplace` (read file → modify → write tmp in `/tmp` → mv across filesystems) could leave target empty/partially-written if process killed mid-write. Fix: new `scripts/atomic-write.sh` with `atomic_write_json()` helper (write-to-temp in SAME directory + fsync + atomic mv — observers always see old OR new content, never half-written). `agent-state.sh` `jq_inplace` now delegates to `atomic_write_json` (signature unchanged, so all 13 call sites in cmd_init/cmd_set/cmd_mark/cmd_heartbeat/cmd_trim/cmd_kick automatically inherit the atomic guarantee). New `cmd_validate <role>` detects 4 corruption modes (missing file / jq parse error / length-0 processed_event_ids / schema mismatch) with distinct exit codes 1-4. New `cmd_rebuild <role>` restores `processed_event_ids` from event log when state is corrupt. New `scripts/event-log.sh` provides append-only JSONL event log at `$AGENT_EVENT_LOG_DIR/<role>.jsonl` (atomic append via write-to-temp + sync + mv), enabling cmd_rebuild to restore dedup buffer from history. Regression test `scripts/tests/d027-state-recovery.sh` (7 TCs T1-T7 per #237 ACs) — 7/7 PASS. Follow-up (separate PR): integrate `event_log_append` into agent-watch.sh's mark flow so cmd_rebuild has real event history to restore from.

- **DEPLOY-001 v9 (Issue #171, refs #169) — RCA-14 follow-up fix:
  systemd user-service integration (uvicorn lifecycle owned by
  systemd, nohup+setsid canonical pattern REMOVED).**
  Sprint 3 P0 unblock (PR #165 + #169) verified that deploys succeed
  via the nohup+setsid canonical restart pattern (RCA-7-1/2/3 fix at
  PR #157, RCA-12 v8 defense at PR #169), but the self-hosted runner's
  "Cleanup orphan processes" step at job end terminates the
  nohup-spawned uvicorn: `Complete job Terminate orphan process:
  pid (47805) (uvicorn)`. Result: deploys succeed (smoke test pass)
  but the service does NOT persist between deploys — `http://192.168.1.199:8000/`
  goes dead as soon as the runner job ends. v9 REPLACES the v8
  nohup+setsid spawn shape with `systemctl --user stop atilcalc-web.service`
  + `systemctl --user start atilcalc-web.service`. The unit's
  ExecStart spawns uvicorn; systemd owns the process lifecycle. The
  service survives the runner cleanup phase because it's owned by
  the atilcan user session (not the runner job process tree).
  Logout-survival requires `loginctl enable-linger atilcan` (owner
  pre-req, one-time setup). v9 keeps the RCA-12 v8 cross-user
  defense (pre-check exit 5 + post-check exit 6) intact — only the
  spawn mechanism changed. New exit code **7** = systemd integration
  failure (unit not registered, or `systemctl --user` call returns
  non-zero). Step 3 (preflight) is now FAIL-loud on missing unit
  (replaces v8's WARN-only — the WARN-only behavior masked the
  RCA-14 bug). New regression test
  `scripts/tests/d018-rca-14-uvicorn-orphan-kill.sh` (9 cases T1-T9):
  pre-deploy `systemctl --user stop`, post-deploy `systemctl --user
  start`, nohup+setsid uvicorn pattern REPLACED, header documents
  RCA-14 + exit code 7, --dry-run step 4 references systemctl +
  atilcalc-web.service, pre-check BEFORE systemctl stop + post-check
  AFTER systemctl start in source order, header references owner
  pre-req (`loginctl enable-linger atilcan`) + ADR-0010. **d017
  (RCA-12) updated** to anchor on `systemctl --user stop` instead
  of `pkill` (the v8 spawn gate anchor is no longer valid in v9;
  the cross-user check itself is preserved). **Sprint 3 P0 DoD §4
  = 3/3 deploy success** was achieved with v8, but Sprint 3 P0
  DoD §5 (intentional bad-merge → rollback + persistence) requires
  v9. Filed RCA-14 as Issue #171; owner pre-req must be applied
  BEFORE first v9 deploy (install unit file, `loginctl enable-linger
  atilcan`, `systemctl --user daemon-reload`, `systemctl --user
  enable atilcalc-web.service`).

- **DEPLOY-001 v8 (Issue #168, refs #165, #164, #161, #160, #155) —
  RCA-12 follow-up fix: cross-user port kill failure defense.**
  `scripts/deploy-runner.sh` v8 adds two strict port-aware checks to
  `restart_service()` — extending the FAIL-or-CREATE doctrine (v6
  RCA-9) from the preflight step to the restart step. **Pre-restart
  check (BEFORE pkill)**: `ss -tlnp "sport = :$ATC_PORT"` extracts
  the port-bound PID's uid; if it differs from the current user's
  uid, fail-fast with **exit code 5** (cross-user port conflict) —
  `pkill -f ... || true` would silently no-op on cross-user targets
  (root cause of 8th deploy fail at run #27865086173, atilcan-owned
  PID 33353 stayed up on port 8000 because the runner is
  `gh-actions-runner`, not `atilcan`). **Post-restart check
  (REPLACES lenient `ps aux | grep uvicorn`)**: after a 2s
  bind-settle, `ss -tlnp` extracts the new port-bound PID and
  `ps -o etimes=` verifies it started RECENTLY (≤ 60s). atilcan's
  pre-existing uvicorn has etimes > 10000s; our just-spawned
  uvicorn has etimes ~2s. If the port-bound process is OLD, fail
  with **exit code 6** (port-PID mismatch) — same cross-user
  scenario, defense-in-depth backstop in case the pre-check tool
  was missing. New regression test
  `scripts/tests/d017-rca-12-cross-user-port-8000.sh` (8 cases
  T1-T8): pre-check tool presence, fail ... 5 / fail ... 6 patterns,
  post-check uses `ss -tlnp` (not lenient ps grep), header
  documents RCA-12 + exit codes 5/6, --dry-run step 4 mentions
  RCA-12, pre-check BEFORE pkill in source order (function-body
  anchor, not comment). **Sprint 3 P0 is STILL not done** — the
  v8 defensive code fix is necessary but not sufficient: the
  underlying infra mismatch (runner as `gh-actions-runner`, prod
  uvicorn as `atilcan`) requires an **owner decision**: Option A
  (run runner as `atilcan`) / Option B (sudoers rule for cross-user
  `pkill`) / Option C (change `$ATC_PORT` to a non-conflicting
  port). Filed RCA-12 as Issue #168; @orchestrator notified via
  `notify.sh -l orchestrator`; @atilcan65 (infra decision) notified
  via `notify.sh -l human` (soul-level escalation per doctrine:
  production deploy/release kararı).

- **DEPLOY-001 v7 (Issue #164, refs #161, #160, #155) — RCA-11
  follow-up fix: `web` extra consolidation (Option B, merged test
  contract PR #166, single source of truth).**
  `scripts/deploy-runner.sh` v7 switches the preflight dep install from
  `uv pip install -p "$REPO_DIR/.venv" -e .` to
  `uv pip install -p "$REPO_DIR/.venv" -e ".[web]"`, pulling in the
  HTTP runtime surface (FastAPI + uvicorn) from a new
  `pyproject.toml [project.optional-dependencies] web` extra. The
  `web` extra carries the **single source of truth** for prod runtime
  pins (`fastapi==0.115.6`, `uvicorn[standard]==0.32.1`). The `[dev]`
  extra retains the dev tooling (pytest, ruff, mypy, playwright,
  httpx) plus the **un-pinned** package names `fastapi` and
  `uvicorn[standard]` (dev tooling uses pip's resolver; drift vs
  `[web]` is acceptable for dev tooling, NOT a prod concern). v6 was
  architecturally correct (it caught the missing uvicorn at the
  defense-in-depth `restart_service()` check, exit 4 — RCA-9
  regression prevented) but uncovered a deeper design gap: pyproject
  declared fastapi+uvicorn as `[dev]` extras, NOT runtime. RCA chain
  RCA-7 → RCA-9 → RCA-10 → RCA-11, each layer revealed by the
  previous fix. Sprint 3 P0 originally scoped Option A (single-line
  script change) per orchestrator Issue #164 fast-path
  recommendation, but merged test contract PR #166 (AP-23c "exactly
  one place" probe) **forced Option B** — pins in EXACTLY ONE place,
  no duplicate pinning in script + pyproject. v7 implements Option B
  per the merged test contract. Sprint 4 ADR-0027 amendment now
  satisfied (the `[web]` extra consolidation IS the amendment).
  **TD-023** (tester self-miss: v6 amendment did not cover the
  `[dev]` extras layer — same class as TD-022) **closed by PR #166**.
  New regression test `scripts/tests/d016-rca-11-runtime-deps-explicit.sh`
  (8 cases T1-T8): Option B path enforcement + AP-23c compliance
  check (zero pin strings in script). Test plan amendment
  **merged via PR #166**: TC-16 (runtime-deps layer) + AP-23 (drift
  detection + single source of truth probe).

- **DEPLOY-001 v6 (Issue #160, refs #159, #157, #155, #152) — RCA-9
  follow-up fix: preflight dep install FAIL-or-CREATE pattern.**
  `scripts/deploy-runner.sh` v6 changes the preflight dep install block
  from WARN-or-SKIP to **FAIL-or-CREATE**: if `uv` is missing → exit
  4 (preflight failure); if `.venv` is missing → create via
  `uv venv .venv` (exit 4 if creation fails); `uv pip install -p
  .venv -e .` failure → exit 4 (was WARN-only continuation in v5,
  which was the silent-WARN bug class — RCA-7 / RCA-8 / RCA-9 family).
  New exit code **4 = preflight failure** (distinct from exit 3 =
  usage error and exit 2 = double-failure). `restart_service()`'s
  defense-in-depth `.venv/bin/uvicorn` existence check upgraded from
  exit 3 → exit 4 (parity with the preflight category). RCA-9 root
  cause: v5 preflight was `if [[ -d "$REPO_DIR/.venv" ]] && command
  -v uv >/dev/null 2>&1; then ...; else log "WARN..."; fi` — script
  proceeded to restart with no venv; restart failed at
  `.venv/bin/uvicorn not found` (exit 3). First auto-deploy after
  PR #157 merge FAILED at run #27862367000 (2026-06-20T06:04:46Z,
  2s after squash-merge c7c060e). v6 closes the WARN/SKIP
  regression-test gap with **TC-15** (FAIL-or-CREATE behavior) +
  **AP-21** (uv-missing + venv-creation-fail fail-fast) +
  **AP-22** (`uv pip install` non-zero exit, not log-only)
  in `docs/test-plans/DEPLOY-001-tests.md`. Sister to **TD-022**
  (tester self-miss: AP-14 covered presence of preflight, not the
  FAIL-or-CREATE semantic — file in RETRO-003).

- **DEPLOY-001 v5 (Issue #155, refs #152) — RCA-7 4-layer root cause
  fix.** `scripts/deploy-runner.sh` rewritten to use the nohup+setsid
  canonical restart pattern that worked at 2026-06-20T05:02:42Z (PID
  33353, manual unblock). The v4 `systemctl --user restart
  atilcalc-web.service` was wrong on FOUR independent layers:
  **RCA-7-1** `atilcalc-web.service` systemd unit does NOT exist on
  prod (never installed, ADR-0010 documented the PATTERN not the
  actual instance); **RCA-7-2** symptom of 7-1; **RCA-7-3** the
  `atilcalc.web.app:app` module path is hallucinated (`atilcalc.web`
  is the JS Web Components dir, no Python app object) — canonical
  module is `atilcalc.api.main:app` (verified 12 references:
  `scripts/run-server.sh` + 11 test files); **RCA-7-4** fresh `.venv`
  lacks runtime deps (mpmath==1.3.0) after `git reset --hard` — fixed
  by preflight `uv pip install -p .venv -e .`. Other v5 changes:
  REPO_DIR default chain `$REPO_DIR > $GITHUB_WORKSPACE >
  /home/atilcan/atilcalc` (was `$HOME/projects/AtilCalculator` —
  actual prod path discovered at 2026-06-20T04:47Z), hostname detection
  log with WARN if not atiltestweb, `ATC_BIND_HOST` env (default
  0.0.0.0) for service bind host. `.github/workflows/deploy.yml` v5
  passes `ATC_BIND_HOST` to deploy step. Smoke test
  (`GET /healthz`, git_sha match) and auto-rollback shape unchanged
  from ADR-0027 §Decision.3.

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

### 2026-06-24 — Sprint 4 day 4: dual-channel + Issue #326 ship (Issue #320 closure)

#### Added

- **PR #330 — `verdict_posted` v8 native kind in `scripts/agent-watch.sh` (Issue #326, P0; closes #326 — Phase 2 of Issue #312 RCA).** New `query_verdict_posted()` function emits `verdict_posted` events when a PR comment on a PR where `agent:<role>` OR `cc:<role>` contains verdict keywords (🟢 APPROVED / 🟡 SUGGESTIONS / 🔴 CHANGES_REQUESTED). Self-cc skip per Issue #94 (`is_author_self_cc_pr` filter — author does not wake on own PR's incoming verdict). Event ID format `verdict-posted-<n>-<sha7>-b<bucket>` with 5-min bucket for dedup against comment edits. Event schema matches ADR-0041 §Decision verbatim: `{kind, number, verdict, author, comment_id, comment_url, pr_url, context: {verdict_class, source, keyword_matched, ...}}`. Sister to PR #322 (Phase 0 standalone, now deprecated) and PR #313 (d036 regression). Phase 3 follow-up: remove `scripts/agent-watch-verdicts.sh` per ADR-0041 §Phasing.

- **PR #337 — ADR-0033 §Verification log (docs-only).** End-to-end verification of the dual-channel mechanism per Issue #320 expanded scope. 5/5 ACK across PM (2/2), DEV (1/1, 3s latency), ARCH (1/1), TEST (1/1). Latency budgets documented (idle-pane: 3-5s send-keys, 1-2s paste-buffer; busy-pane: worst-case ~100s context-saturated). PR chain #325/#332/#333/#337 + Issue #320 closure recorded.

#### Changed

- **PR #325 — `scripts/ping.sh` wrapper (Issue #320).** New canonical entry point for peer-pings: `scripts/ping.sh <role> '<message>'`. Wraps `notify.sh` with the correct dual-channel syntax (`-l info -w -r <role>`) so it cannot be misused. `notify.sh -l <role>` is deprecated (emits stderr WARNING + CLAUDE.md hint). Regression tests `d037` (deprecation warning) + `d038` (wrapper contract) — both 7/7 GREEN.

- **PR #332 — Soul-sed: 4 tracked soul files migrated to `scripts/ping.sh <role>` (Issue #320 PR-A, sed-only).** `.claude/agents/{product-manager,architect,developer,tester}.md` updated to reference `scripts/ping.sh <role>` instead of the deprecated `notify.sh -l <role>` form. Sister to PR #333 (orchestrator role tracked + ADR-0041).

- **PR #333 — `.claude/agents/orchestrator.md` tracked + ADR-0041 orchestrator role contract (Issue #320 PR-B).** Orchestrator soul file was gitignored at line 76 of `.gitignore`; now tracked alongside the 4 sibling souls. ADR-0041 codifies the orchestrator role: handoff discipline (atomic 4-flag flip per ADR-0015), WIP enforcement, stale queue detection, verdict-by SLA monitoring, REPRIME protocol, auto-ping hard-rule. Sister to PR #332 (sed-only).

#### Closed

- **Issue #320 — Peer-ping syntax broken in 22 places across 6 files.** Closed via PR chain #325 (wrapper) + #332 (sed-only) + #333 (orchestrator tracked) + #337 (verification log). Doctrinal artifact: `scripts/ping.sh` is now the canonical mechanism; `notify.sh -l <role>` is deprecated but backward-compat (Issue #320 AC2).

- **Issue #326 — v8 native extension in `scripts/agent-watch.sh` — `verdict_posted` kind (P0, closes Phase 2 of Issue #312 RCA).** Closed via PR #330. PR #336 was a duplicate closed in favor of #330 after tester 🔴 verdict (3 architectural regressions vs ADR-0041 §Decision — see /tmp/tester-verdict-336.md).

## 2026-06-20T09:31:07Z — uv PATH fix verified
## 2026-06-20T09:43:21Z — uv PATH fix verified (Sprint 3 P0 RCA-13)
