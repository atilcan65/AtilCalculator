# Test Plan: DEPLOY-001 — Self-hosted GH Actions runner on prod (refs #130, #138, ADR-0030)

**Status**: REWRITTEN 2026-06-19 (regen per Issue #138 RCA + ADR-0030 pivot). Replaces the PR #133 lost plan (commit 81fa651), which assumed public GH runner + appleboy/ssh-action. **All TCs rewritten** to match the new self-hosted-runner architecture (Option A per owner decision 2026-06-19T20:18Z).

**Refs**:
- Issue #130 (DEPLOY-001 — closed via PR #136 merge e51857b, but DEPLOY-001 deployment still blocked)
- Issue #138 (P0 incident — public runner → private LAN unreachable, RCA-1+2+3)
- ADR-0027 (superseded by ADR-0030 §Decision.1 — trigger topology changed)
- ADR-0030 (new ADR, draft in flight on `docs/adr-0030-self-hosted-runner` branch)
- PR #136 (DEPLOY-001 v1 impl, MERGED, deploy mechanism now invalid)
- DEPLOY-002 (#131 — secrets DONE, but DEPLOY_SSH_KEY/HOST/USER no longer needed for self-hosted runner)

## Scope

- **In scope**:
  - Self-hosted GH Actions runner contract: registered with label `atilcalc-prod`; `gh-actions-runner` user (no sudo, no shell login); runner IS the prod host (192.168.1.199).
  - Workflow YAML structure: `runs-on: self-hosted, labels: [atilcalc-prod]`, no `appleboy/ssh-action`, no SSH key secrets.
  - `scripts/deploy-runner.sh` runs locally on the runner (no SSH); same contract as v1 (idempotent converge, restart, smoke test, rollback).
  - **RCA-3 regression**: workflow MUST use `script:` (not `script_path:`) — the v1 yaml used `script_path` which appleboy/ssh-action v1.1.0 silently ignored.
  - **RCA-2 regression**: `notify.sh` step MUST run on `if: always()` (not `if: failure()`) so notifications fire on infrastructure-level failures (e.g., runner offline).
  - Runner registration: label `atilcalc-prod`, ephemeral token rotation per GH API.
  - Secrets: only `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` (RCA-2 fix) — SSH key/host/user secrets retired.

- **Out of scope**:
  - Multi-host deploy (Sprint 4+).
  - Self-hosted runner security hardening (assumed handled by `gh-actions-runner` user setup).
  - Runner version upgrade cadence (manual).
  - DEPLOY-002 (`DEPLOY_SSH_KEY` etc. secrets) — retired with appleboy/ssh-action.

## Constraints (CRITICAL)

- **`.github/workflows/` is human-only** per CLAUDE.md §File ownership matrix. Workflow file changes require **explicit human approval at merge time** — agents propose via PR.
- **`gh-actions-runner` user is owner-installed** on prod (Issue #138, owner gate). Workflow assumes user exists + runner registered + systemd-enabled.
- **Self-hosted runner IS prod** — no separate test runner. The "test the deploy" loop is: push to `main` → runner picks it up → runner runs `deploy-runner.sh` locally → if smoke test fails, runner rolls back its own previous state. There is no staging runner.
- **TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID** must be set as repo secrets before the first real deploy (RCA-2). Owner action.

## Test Cases

### TC-1: Workflow uses self-hosted runner with `atilcalc-prod` label

- **Setup**: merged `.github/workflows/deploy.yml` on `main` (human-approved).
- **Steps**:
  1. `git show origin/main:.github/workflows/deploy.yml` (read merged state).
  2. Parse YAML (PyYAML safe_load).
  3. Assert `jobs.<job_id>.runs-on` is EITHER:
     - a string `"self-hosted"`, OR
     - a list of strings (e.g., `["self-hosted", "atilcalc-prod"]`)
     GH Actions syntax accepts both forms; the `atilcalc-prod` label MUST be present (in either string list form or as a literal token) so the runner registration matches. (Per developer review on PR #141 — GH Actions does NOT accept a dict form; the dict assumption was incorrect. Updated.)
  4. Assert `atilcalc-prod` is in the resolved labels (string or list).
  5. Assert NO `runs-on: ubuntu-latest` (would deploy to public runner, the original bug).
  6. Assert `concurrency.group: production-deploy` and `cancel-in-progress: false` (per ADR-0027 §Decision.5 carry-over).
- **Expected**: workflow dispatches only to the prod host's self-hosted runner, with the `atilcalc-prod` label matching the runner registration.

### TC-2: No `appleboy/ssh-action` (RCA-1 architectural fix)

- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Grep workflow YAML for `uses: appleboy/ssh-action` — must return 0 matches.
  2. Grep for `uses: appleboy/` (any appleboy action) — must return 0 matches.
  3. Grep for `${{ secrets.DEPLOY_SSH_KEY }}` — must return 0 matches (SSH key retired).
  4. Grep for `${{ secrets.DEPLOY_HOST }}` — must return 0 matches.
  5. Grep for `${{ secrets.DEPLOY_USER }}` — must return 0 matches.
- **Expected**: zero SSH-related references in workflow. Runner talks to itself directly.

### TC-3: Workflow uses `script`/`run` (RCA-3 regression)

- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Grep workflow YAML for `script_path:` — must return 0 matches (was silently ignored by appleboy/ssh-action v1.1.0 in v1 yaml).
  2. Assert at least one step uses `run:` with `bash scripts/deploy-runner.sh` (or equivalent local invocation).
  3. (Optional) Assert `shellcheck` lint clean on the inline `run:` block if it contains shell.
- **Expected**: workflow invokes `deploy-runner.sh` as a local script (no SSH transport). The v1 bug — `script_path` silently ignored + empty inline fallback — must not recur.

### TC-4: Notification runs on `if: always()` (RCA-2 silent-failure fix)

- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Find the step that calls `scripts/notify.sh` for failure notification.
  2. Assert the step has `if: always()` (NOT `if: failure()` only).
  3. Assert `if: always()` is the **outermost** conditional on the step (NOT nested inside an `if: failure()` parent or matrix context that could shadow it). GH Actions matrix can interact oddly with `if:` predicates.
  4. Reason: `if: failure()` only triggers when a prior step fails. If the **runner itself** fails to come online (no `atilcalc-prod`-labeled runner registered), the job fails before any step runs — `if: failure()` won't fire because no prior step failed. `if: always()` covers both code-level and infrastructure-level failures.
  5. Assert a second `if: always()` step exists for success notification (or merge into a single step that branches on outcome).
  6. Assert workflow references `secrets.TELEGRAM_BOT_TOKEN` + `secrets.TELEGRAM_CHAT_ID` (the env vars RCA-2 found missing).
- **Expected**: notification fires on every workflow outcome — success, failure, runner-offline, infrastructure error.

### TC-5: Self-hosted runner registration contract

- **Setup**: prod host (192.168.1.199).
- **Steps**:
  1. SSH to prod (owner action, manual).
  2. `sudo -u gh-actions-runner ./svc.sh status` — assert runner is registered + active.
  3. `gh api /repos/atilcan65/AtilCalculator/actions/runners` — assert at least one runner with `labels` including `atilcalc-prod` and `self-hosted`, with `status: "online"`.
  4. Assert `gh-actions-runner` user has `NO sudo` (sudo -l returns "may not run sudo") and `NO shell login` (`grep gh-actions-runner /etc/passwd` shows `/usr/sbin/nologin` or `/bin/false`).
  5. Assert runner working directory is owned by `gh-actions-runner`, not root. **Also assert working directory is `$HOME/projects/AtilCalculator`** (i.e., `REPO_DIR` from `deploy-runner.sh`), NOT `/` or `/tmp` (prevents the runner from accidentally resetting the wrong repo on `git reset --hard origin/main`).
  6. **Cross-cutting gap (raised by @developer on PR #141 review)**: assert the runner can restart the user-service `atilcalc-web.service`. The `gh-actions-runner` user does NOT have its own systemd user-instance (nologin shell, no active session bus), so the v1 pattern of `systemctl --user restart atilcalc-web.service` from inside the runner WILL FAIL SILENTLY. Acceptable resolution paths (architect + owner decision required):
     - **(a) System service migration**: `atilcalc-web.service` becomes a system service (run by `atilcalc-prod` user, no session bus needed). Tests assert `systemctl restart atilcalc-web.service` (no `--user`) works as `gh-actions-runner`. **Cleanest, recommended.**
     - **(b) Sudoers to machinectl**: `gh-actions-runner` gets a narrow sudoers entry to `machinectl shell atilcan@.host /bin/sh -c "systemctl --user restart atilcalc-web.service"`. Tests assert the sudoers line is present and the call succeeds.
     - **(c) loginctl attach**: runner script does `loginctl attach atilcan` before `systemctl --user` (assumes atilcan has an active session). Tests assert the session is active.
     - **(d) SSH-to-self as atilcan**: runner SSHes to `localhost` as `atilcan` and runs `systemctl --user restart atilcalc-web.service` (back to SSH + secrets pattern, but local). Tests assert the SSH key + atilcan user are accessible.
     Until a path is chosen, this TC fails by default. **Architect's call** (probably as ADR-0030-amend-1 or new ADR). Test plan updated to encode the gap; impl PR must resolve before TC-5 passes.
- **Expected**: runner is online, labeled correctly, runs as a hardened user, and CAN restart the prod service (via one of the 4 paths above).

### TC-6: `scripts/deploy-runner.sh` local-runner contract

- **Setup**: merged `scripts/deploy-runner.sh` (developer-owned, not workflow-file).
- **Steps**:
  1. Assert file exists at `scripts/deploy-runner.sh`.
  2. Assert `os.access(path, os.X_OK)` returns True.
  3. Assert shebang is `#!/usr/bin/env bash` or `#!/bin/bash`.
  4. Run `bash -n scripts/deploy-runner.sh` (syntax check) — exit 0.
  5. Run `shellcheck scripts/deploy-runner.sh` (if available) — 0 errors.
  6. Run `bash scripts/deploy-runner.sh --dry-run` with `GITHUB_SHA=<test-sha>` — prints 5-step plan, exits 0.
  7. Assert script does NOT call `ssh` or `scp` (was using appleboy/ssh-action transitively in v1; now unnecessary).
  8. Assert script's `REPO_DIR` resolves to the runner's checkout directory (typically `$GITHUB_WORKSPACE` or `$HOME/projects/AtilCalculator`).
  9. **Cross-cutting gap (also affects TC-5 step §6)**: the v1 assumption "runner runs as a user with systemd user-instance" is **incorrect** for `gh-actions-runner` (nologin, no session bus). The script's `systemctl --user restart atilcalc-web.service` call WILL FAIL SILENTLY when run as the runner user. Test must be rewritten to match the architect-decided mechanism (see TC-5 step §6 — option (a) is "system service" which makes this step "systemctl restart atilcalc-web.service" without `--user`; option (d) is "SSH-to-self as atilcan" which wraps the `systemctl --user` in an `ssh atilcan@localhost` call).
  10. Assert the script's `systemctl` invocation matches the architect-decided mechanism (regex pattern: `(systemctl --user|sudo systemctl|machinectl shell|systemctl restart atilcalc-web.service)` — at least one match required).
- **Expected**: script runs locally on the runner, exercises the same idempotent converge + restart + smoke test + rollback flow as v1, with a `systemctl` invocation that works for the `gh-actions-runner` user.

### TC-7: Idempotency contract — `git reset --hard origin/main`

- **Setup**: workflow YAML + `deploy-runner.sh` source.
- **Steps**:
  1. Assert workflow step or `deploy-runner.sh` contains `git fetch origin` AND `git reset --hard origin/main` (per ADR-0027 §Decision.5).
  2. Assert NO `git pull` (pull can fail on non-fast-forward; reset is idempotent).
  3. Assert `deploy-runner.sh` has post-reset `HEAD == GITHUB_SHA` sanity check (catches remote drift).
- **Expected**: re-running the deploy (e.g., on transient smoke-test failure + retry) converges to `origin/main` HEAD.

### TC-8: Smoke test integration with `/healthz` (DEPLOY-003)

- **Setup**: workflow + `deploy-runner.sh` + DEPLOY-003 endpoint.
- **Steps**:
  1. Assert `deploy-runner.sh` calls `curl -fsS http://$ATC_HOST:$ATC_PORT/healthz` and asserts `git_sha` matches `GITHUB_SHA`.
  2. Assert workflow (or runner) has network access to `127.0.0.1:8000` (the ATC_PORT default).
  3. Assert `/healthz` returns 200 with `{"status": "ok", "git_sha": <sha>, "ts": <iso>}` (DEPLOY-003 contract from PR #134).
- **Expected**: smoke test validates the just-deployed SHA is actually serving.

### TC-9: Auto-rollback + double-failure page

- **Setup**: `deploy-runner.sh` source.
- **Steps**:
  1. Assert script performs `git reset --hard HEAD@{1}` on smoke-test failure (rollback to previous known-good commit).
  2. Assert script restarts `atilcalc-web.service` after rollback.
  3. Assert script retries the smoke test once; on second failure, calls `scripts/notify.sh -l human` (owner page).
  4. Assert exit codes documented: 0 (pass), 1 (rollback succeeded), 2 (double-fail), 3 (usage error).
- **Expected**: production is never left in a known-broken state — worst case is "known-good prior commit" + owner page.

## Adversarial Probes

### AP-1: Public-runner regression (RCA-1)
- **Setup**: merged workflow YAML.
- **Probe**: workflow uses `runs-on: ubuntu-latest` (the original ADR-0027 §Decision.1 choice that was fundamentally broken for private LAN).
- **Expected**: TEST FAILS — must use `self-hosted, labels: [atilcalc-prod]`.
- **Why**: guards against a future "let me just use the public runner for staging" regression that would re-introduce the RCA-1 failure.

### AP-2: `script_path` regression (RCA-3)
- **Setup**: merged workflow YAML.
- **Probe**: workflow uses `script_path: scripts/deploy-runner.sh` (the v1 bug — appleboy/ssh-action v1.1.0 silently ignored this).
- **Expected**: TEST FAILS — must use `run: bash scripts/deploy-runner.sh` (or `script:` with inline body, if the action supports it).
- **Why**: this is the actual RCA-3 bug. The deploy never happened in the v1 incident because the runner script was never called. The fix is small, but if a future PR copies the v1 yaml pattern, this test catches it.

### AP-3: Notification-silent-failure (RCA-2 + RCA-4)
- **Setup**: merged workflow YAML.
- **Probe**: notification step uses `if: failure()` (or no `if:` at all).
- **Expected**: TEST FAILS — must use `if: always()` to cover runner-offline + infrastructure failure modes.
- **Why**: the v1 incident was detected only by orchestrator periodic polling, ~1 min after the failure. Telegram notification would have alerted owner instantly. The `if: failure()` condition misses infrastructure-level failures (no runner, secrets missing, etc.).

### AP-4: Runner label mismatch
- **Setup**: workflow + GH API.
- **Probe**: workflow uses `labels: [wrong-label]` or omits the label, so no runner picks up the job.
- **Expected**: TEST WARNS (not fails — owner may rename labels) — orchestrator alerts on `runs-on: self-hosted` + no runner pickup within 60s.
- **Why**: silent queueing. Workflow "succeeds" by waiting forever (or hits GH Actions 6h timeout). Need monitoring, not a test assertion.

### AP-5: Runner user privilege escalation
- **Setup**: prod host `gh-actions-runner` user.
- **Probe**: `gh-actions-runner` user can `sudo` (would invalidate the ADR-0027 §Threat model: "no sudo, single-user SSH key" — adapted for self-hosted as "no sudo, dedicated non-login user").
- **Expected**: TEST FAILS — user must be in `nologin` shell + no sudoers entry.
- **Why**: a compromised workflow step (e.g., via a malicious commit) would have full root if the runner user has sudo. The whole point of the self-hosted-runner pivot is to bound the blast radius.

### AP-6: Secret leakage in workflow YAML
- **Setup**: merged workflow YAML.
- **Probe**: grep for `192.168.1.199` literal — FAIL if found.
- **Probe**: grep for `-----BEGIN OPENSSH PRIVATE KEY-----` or similar key markers — FAIL if found.
- **Probe**: grep for `ghp_` (GitHub PAT prefix) — FAIL if found.
- **Expected**: TEST FAILS on any match.
- **Why**: secrets must live in repo secrets (`${{ secrets.* }}`), never in YAML literals. (Retired SSH-key/host/user secrets per self-hosted pivot, but TELEGRAM tokens still secret.)

### AP-7: `/healthz` 5xx swallowed
- **Setup**: `deploy-runner.sh` source.
- **Probe**: smoke test loop does NOT distinguish 503 (engine import failure — per DEPLOY-003 contract) from 200. Both treated as "smoke ok".
- **Expected**: TEST FAILS — script must assert `git_sha` from response body (200 path) AND treat 503 as failure with rollback.
- **Why**: DEPLOY-003 says 503 means engine import failed. A 503 is "service is up but broken" — still warrants rollback.

### AP-8: Workflow fires on every push (PR noise)
- **Setup**: workflow YAML.
- **Probe**: workflow's `on.push` is unconditional (deploys on every branch push, not just `main`).
- **Expected**: TEST FAILS — `on.push.branches: ["main"]` required.
- **Why**: PRs should not deploy (per ADR-0027 §Decision.1).

**Status**: AMENDED 2026-06-20T06:13Z (per Issue #160 — RCA-9 first auto-deploy post-#157-merge FAILED at run #27862367000 with `.venv/bin/uvicorn not found` — fresh self-hosted runner checkout had no `.venv` at all, v5 preflight was WARN/SKIP, restart_service() then failed at the existence check). v6 fix: FAIL-or-CREATE pattern. Added **TC-15** (preflight dep install FAIL-or-CREATE — `.venv` is created via `uv venv` if missing, never WARN/SKIP) + **AP-21** (script fails fast with exit 4 if `uv` missing or `uv venv` creation fails — NO WARN-only skip path) + **AP-22** (`uv pip install` failure is non-zero exit 4, NOT log-only continuation). Closes the **silent-skip** regression-test gap exposed by RCA-9: v5 had AP-14 (presence of preflight dep install) but did NOT cover the FAIL-or-CREATE behavior — a test that passes when the preflight is present but silently skipped is structurally meaningless. File **TD-022** in RETRO-003 (tester-side, parallel to TD-021 — same class of regression test surface-vs-depth gap as RCA-7/RCA-8/RCA-9 family).

### TC-15: Preflight dep install FAIL-or-CREATE — `.venv` created via `uv venv` if missing (NEW 2026-06-20T06:13Z per Issue #160 RCA-9)
- **Setup**: `scripts/deploy-runner.sh` source (v6+).
- **Steps**:
  1. Locate the preflight dep install block in `scripts/deploy-runner.sh` (the section between `# --- Step 1: ---` and `# --- Step 3: ---`).
  2. Assert the block contains a check for `command -v uv` BEFORE the `.venv` check (uv must be checked first — without uv, we cannot create the venv).
  3. Assert the block contains a check for `[[ ! -d "$REPO_DIR/.venv" ]]` (NOT just `[[ -d ... ]]` — must be the FAIL-or-CREATE branch).
  4. Assert the `.venv` missing branch calls `uv venv "$REPO_DIR/.venv"` (NOT a log-only WARN).
  5. Assert the `.venv` missing branch has explicit error handling: `if ! uv venv ... ; then fail ... fi` (NOT bare `uv venv ... || log "WARN..."`).
  6. Assert the `uv pip install -p "$REPO_DIR/.venv" -e "$REPO_DIR"` call has explicit error handling: `if ! uv pip install ... ; then fail ... fi` (NOT bare `uv pip install ... || log "WARN..."`).
  7. Assert the `fail` calls use exit code `4` (the new preflight failure exit code, distinct from exit `3` usage errors).
  8. (Sanity) Run `bash scripts/deploy-runner.sh --dry-run` with `GITHUB_SHA=<valid-sha>`. Assert exit 0 and that step 2 log line includes "FAIL/CREATE" or "RCA-9 fix" marker (so operator can grep deploy logs for the new behavior).
- **Why**: RCA-9 (Issue #160) — v5 preflight dep install was `if [[ -d "$REPO_DIR/.venv" ]] && command -v uv >/dev/null 2>&1; then ...; else log "WARN..."; fi`. The `else` branch was WARN/SKIP — script proceeded to restart step with no venv, restart failed at `.venv/bin/uvicorn not found` (exit 3). v6 replaces with FAIL-or-CREATE: uv-missing → exit 4; .venv-missing → create via `uv venv` (fail with exit 4 if creation fails); dep-install-fail → exit 4. This TC enforces the architectural decision: deploy-runner.sh MUST NOT regress to a WARN/SKIP preflight. Defense-in-depth: even if owner believes "the venv is always pre-created", a fresh checkout (e.g., a new self-hosted runner) must still produce a working deploy.

### AP-21: Probe — script fails fast if `uv` missing or `uv venv` creation fails (RCA-9 NEW 2026-06-20T06:13Z)
- **Setup**: `scripts/deploy-runner.sh` source (v6+).
- **Probe 21a**: preflight block uses `fail "...uv not found..."` with exit `4` (NOT `log "WARN: uv not found..."`) when `command -v uv` fails.
- **Probe 21b**: preflight block uses `fail "...uv venv creation failed..."` with exit `4` (NOT `log "WARN: venv creation failed..."`) when `uv venv` exits non-zero.
- **Probe 21c**: preflight block does NOT contain the literal string `WARN: .venv or uv not found` (v5's silent-skip phrase).
- **Probe 21d**: preflight block does NOT contain the literal string `skipping preflight dep install` (v5's silent-skip phrase).
- **Expected**: TEST FAILS on any probe match (the WARN/SKIP pattern is structurally a regression — silent failure mode that RCA-7/RCA-8/RCA-9 all share).
- **Why**: RCA-9 root cause was the WARN/SKIP pattern in the preflight dep install. AP-14 (v6 amendment) covered the PRESENCE of the preflight step but not the FAIL-or-CREATE semantic. AP-21 closes the surface-vs-depth gap: the preflight must FAIL (not WARN) when its preconditions are not met.

### AP-22: Probe — `uv pip install` failure is non-zero exit, NOT log-only continuation (RCA-9 NEW 2026-06-20T06:13Z)
- **Setup**: `scripts/deploy-runner.sh` source (v6+).
- **Probe 22a**: `uv pip install -p "$REPO_DIR/.venv" -e "$REPO_DIR"` line is wrapped in `if ! ... ; then fail ... fi` (NOT `if ! ... | tee log; then log "WARN..."`).
- **Probe 22b**: the `fail` call uses exit code `4` (the new preflight failure exit code).
- **Probe 22c**: the failure message references `/tmp/deploy-uv-install.log` so operator can inspect the install log.
- **Probe 22d**: preflight block does NOT contain the literal string `WARN: uv pip install exited non-zero; engine may fail to import` (v5's silent-WARN phrase).
- **Expected**: TEST FAILS on any probe match.
- **Why**: v5's `if ! uv pip install ... ; then log "WARN..."` pattern was the silent-WARN class bug. The smoke test would catch the import failure downstream, BUT then the rollback would re-run the same failing `uv pip install` — wasting a full deploy cycle. AP-22 enforces fail-fast on `uv pip install` failure.

## Performance Concerns

- **Self-hosted runner pickup latency**: GH Actions polls for self-hosted runners every ~30s. First-step latency = ~30-60s.
- **Total deploy time budget**: 5 min `timeout-minutes` (carried over from v1). With local runner, expect <2 min (checkout 10s, deploy 30s, smoke 5s).
- **Smoke test loop budget**: 5 attempts × 2s delay = 10s. With local runner, expect 1 attempt on healthy state.

## Regression Risk

- **DEPLOY-002 (#131) closure**: secrets `DEPLOY_SSH_KEY/HOST/USER` are no longer needed. The owner may want to **delete** these from GH repo secrets to clean up. (Not required, but hygiene.) Sprint 3 plan mentions this implicitly; should be explicit close-out action.
- **`scripts/notify.sh` invocation pattern**: same as v1 (workflow calls it via `run: bash scripts/notify.sh ...`). No change.
- **README.md deploy section** (added in PR #136): needs to be **rewritten** to reflect the self-hosted-runner architecture (no more SSH, no more `appleboy`). The owner or developer should amend in a follow-up PR.

## Acceptance Criteria (testable)

A test pass requires ALL of:
1. TC-1..TC-9 + TC-15 PASS (or PASS-with-justified-exception for owner-gated TCs TC-1, TC-4, TC-5). (TC-11..TC-14 are added by the v6 amendment PR #150 — separate PR, owner-gated merge order.)
2. AP-1..AP-8 + AP-21 + AP-22 PASS (no false negatives). (AP-11..AP-20 are added by the v6 amendment PR #150 — separate PR, owner-gated merge order.)
3. `bash scripts/deploy-runner.sh --dry-run` exits 0 with valid SHA.
4. Workflow YAML parses (PyYAML) + structural assertions pass.
5. `gh api /repos/atilcan65/AtilCalculator/actions/runners` returns at least one `online` runner with `atilcalc-prod` label.
6. End-to-end dry deploy: push a `chore: trigger deploy` commit to `main` (owner-gated) → workflow runs → `deploy-runner.sh` → `/healthz` returns 200 with matching `git_sha` → exit 0.

## Open Questions (for architect on ADR-0030)

1. Should the runner use a fixed label (e.g., `atilcalc-prod`) or a group label (e.g., `linux, x64, atilcalc-prod`)? Fixed is simpler; group allows future multi-runner scaling.
2. Should the runner auto-update (`runner.runUpdateInterval` = default 24h) or be owner-managed? Auto-update is the GH default; recommend keeping.
3. If the runner is offline for >1h during a deploy window, does the workflow timeout + alert, or queue indefinitely? Recommend timeout (matches v1 `timeout-minutes: 5`).
4. Runner registration token rotation cadence: GH suggests regenerating the registration token on each install. For long-lived runners, the token is only used once at registration. No rotation needed for the runner itself (but the **API access token** used by `gh api` for owner actions should be rotated per GH PAT policy).

## History

- **2026-06-19T20:00Z (v1)**: test plan authored on `feat/deploy-tests` branch (commit 81fa651), covered public-runner + appleboy/ssh-action architecture. PR #133 opened + closed without merge (TDD-RED ships; merged impl is in PR #134, #136).
- **2026-06-19T20:15Z (v1)**: First auto-deploy FAILED (Issue #138, RCA-1 architectural + RCA-2 silent notification + RCA-3 `script_path` ignored).
- **2026-06-19T20:18Z (v1)**: Owner decision: self-hosted runner (Option A).
- **2026-06-19T20:25Z (v2 — this file)**: Test plan rewritten for self-hosted-runner architecture. RCA-3 + RCA-2 added as AP-2 + AP-3 regression probes. Sprint 3 P0 partial close: impl + secrets + healthz all done; only the trigger mechanism needs swap.
- **2026-06-20T06:13Z (v6 amendment in this file, RCA-9 follow-up to PR #150)**: Added TC-15 + AP-21 + AP-22 per Issue #160. Closes the WARN/SKIP regression-test gap in the preflight dep install. Defense in depth against the silent-WARN bug class (RCA-7 / RCA-8 / RCA-9 family). TD-022 (tester self-miss: AP-14 covered presence of preflight, not the FAIL-or-CREATE semantic).

— @tester, 2026-06-19T20:30Z (initial); amended @tester, 2026-06-20T06:13Z (RCA-9 TC-15 + AP-21 + AP-22)
