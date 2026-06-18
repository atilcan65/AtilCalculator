# Changelog

All notable changes to this project are recorded here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

- **STORY-001 — FastAPI service skeleton with `GET /healthz`** (Sprint 1, P0).
  Standalone FastAPI service runnable from a clean clone with one command
  (`make run`); liveness probe at `/healthz` returns `200 OK` with
  `{"status": "ok"}` and `Content-Type: application/json`. Unknown paths
  return `404` (not `500`). `Ctrl-C` exits cleanly with code `0`.
  See [`docs/backlog/sprint-1/STORY-001-fastapi-skeleton-healthz.md`](docs/backlog/sprint-1/STORY-001-fastapi-skeleton-healthz.md),
  [`docs/designs/STORY-001-design.md`](docs/designs/STORY-001-design.md),
  and [`docs/decisions/ADR-0001-fastapi-skeleton.md`](docs/decisions/ADR-0001-fastapi-skeleton.md).

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

- **STORY-004 — `GET /hello/{name}` greeting endpoint** (Sprint 1, P1).
  Demo-facing route that returns `200 OK` with
  `{"message": "hello, {name}"}` and `Content-Type: application/json`.
  Case is preserved verbatim (no lowercasing); URL-encoded values pass
  through unchanged (e.g. `/hello/%20` → `"hello,  "`). The path segment
  is required, capped at 64 characters to bound log-spam risk; missing
  name returns `404` (FastAPI default), not `500`.
  See [`docs/backlog/sprint-1/STORY-004-hello-name-greeting-endpoint.md`](docs/backlog/sprint-1/STORY-004-hello-name-greeting-endpoint.md).

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
