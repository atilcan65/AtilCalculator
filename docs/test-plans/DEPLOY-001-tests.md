# Test Plan: DEPLOY-001 — Self-hosted GH Actions runner on prod (refs #130, #138, ADR-0030)

**Status**: REWRITTEN 2026-06-19 (regen per Issue #138 RCA + ADR-0030 pivot). Replaces the PR #133 lost plan (commit 81fa651), which assumed public GH runner + appleboy/ssh-action. **All TCs rewritten** to match the new self-hosted-runner architecture (Option A per owner decision 2026-06-19T20:18Z).

**Status**: AMENDED 2026-06-19T21:43Z (per Issue #148 — first self-hosted deploy FAILED with RCA-5 REPO_DIR hardcode + RCA-6 TELEGRAM env missing). Added **TC-10** (REPO_DIR contract) + **AP-9** (REPO_DIR regression) + **AP-10** (TELEGRAM env regression). Strengthened **TC-4 §6** (TELEGRAM env binding). Relaxed **TC-1 §4** (atilcalc-prod label is optional, self-hosted is mandatory).

**Status**: AMENDED 2026-06-20T04:25Z (per Issue #152 — first self-hosted deploy post-#148-fix FAILED with RCA-7 D-Bus session bus unreachable + RCA-8 TELEGRAM secret values rendered empty). Added **TC-11** (systemd user session pre-flight) + **AP-11** (TELEGRAM secret values non-empty pre-flight) + **AP-12** (systemctl --user D-Bus reachable pre-flight). Closes the **runtime/depth** regression-test gap exposed by RCA-8 (PR #151 + PR #150 surface tests passed, but the secret VALUES were empty at step execution — TD-018 lesson).

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
     GH Actions syntax accepts both forms.
  4. **AMENDED 2026-06-19T21:43Z (per Issue #148 + Issue #143 owner-impl)**: the `atilcalc-prod` label is **optional**, not mandatory. Owner-impl (Issue #143) registered the runner with **default labels only** (`self-hosted`, `Linux`, `X64`). The `self-hosted` label is **mandatory** (matches the runner registration); `atilcalc-prod` is a **future-scaling nicety** for multi-runner dispatch. **Defer `atilcalc-prod` enforcement to Sprint 4 (multi-runner scaling) unless explicitly added in a follow-up PR.**
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
  7. **AMENDED 2026-06-19T21:43Z (per Issue #148 RCA-6)**: strengthen §6 — assert these secrets are **bound to the `env:` block of the notify step OR to the job-level `env:` block**, so they are reachable from the `run:` invocation. Mere syntactic presence in the YAML (e.g., a stray `secrets.TELEGRAM_BOT_TOKEN` reference in a comment) does NOT satisfy this assertion. The RCA-6 bug was: workflow referenced the secrets in spirit but did NOT bind them to the env of the notify step, so `scripts/notify.sh` exited 1 silently when TELEGRAM_BOT_TOKEN was unset.
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

### TC-10: REPO_DIR contract (RCA-5 regression test)

**Setup**: merged `scripts/deploy-runner.sh` + `.github/workflows/deploy.yml`.

- **Steps**:
  1. Read `scripts/deploy-runner.sh` line 32 (REPO_DIR default).
  2. Assert the default is **`${REPO_DIR:-$GITHUB_WORKSPACE}`** (architect's recommended fix per Issue #148).
  3. **OR**: assert the workflow YAML passes `REPO_DIR: ${{ github.workspace }}` explicitly to the deploy step's `env:` (acceptable alternative).
  4. Assert the REPO_DIR default does NOT contain `$HOME/projects/AtilCalculator` (the RCA-5 bug — wrong for self-hosted runner user, which resolves `$HOME` to `/home/gh-actions-runner/`).
  5. (Sanity) Parse `github.workspace` from a synthetic test workflow context: assert the path resolves to `/home/gh-actions-runner/actions-runner/_work/AtilCalculator/AtilCalculator/` (GH Actions standard workspace path for self-hosted runner).
- **Expected**: REPO_DIR resolves to the GH Actions checkout directory at runtime. First self-hosted deploy FAILS today because the default is `$HOME/projects/AtilCalculator`; this TC catches it before merge.

### TC-11: Systemd user session availability pre-flight (RCA-7 regression test, NEW 2026-06-20T04:25Z per Issue #152)

**Setup**: merged `scripts/deploy-runner.sh` + prod host (`gh-actions-runner` user with/without `loginctl enable-linger`).

- **Steps**:
  1. Assert `scripts/deploy-runner.sh` performs a **pre-flight check** BEFORE the `systemctl --user restart atilcalc-web.service` step:
     - **Option A** (assert one of):
       - `[ -S "${XDG_RUNTIME_DIR}/bus" ]` — D-Bus session socket exists
       - `systemctl --user status >/dev/null 2>&1` — systemd reachable
     - **Option B** (assert pre-flight detects miss + fails fast): script MUST exit non-zero with a clear error message mentioning `loginctl enable-linger` if D-Bus is unreachable, BEFORE the systemctl restart step is attempted.
  2. Assert the pre-flight check runs BEFORE step 1 (git fetch) OR after git fetch but BEFORE step 2 (systemctl restart). (Earlier is better — fail before destructive state changes.)
  3. (Sanity) On the prod host, simulate the bug: run as `gh-actions-runner` user WITHOUT `loginctl enable-linger` set, invoke `bash scripts/deploy-runner.sh --dry-run`. Assert: script exits non-zero with a clear error mentioning `linger` or `D-Bus`, NOT the generic "Failed to connect to bus: No medium found".
- **Expected**: A future regression of RCA-7 (where the runner user lacks an active systemd session) fails the deploy script with an actionable error pointing to `loginctl enable-linger`, instead of silently corrupting prod state (workspace updated, service not restarted, smoke test never runs).
- **Why**: RCA-7 left prod in a half-deployed state for ~30 min before Issue #152 was filed. The silent failure of `systemctl --user` is the dangerous class — visible in logs only if you know what to grep for. A pre-flight check converts silent failure to loud failure with an actionable remediation.

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

### AP-9: REPO_DIR hardcoded path regression (RCA-5, NEW 2026-06-19T21:43Z per Issue #148)
- **Setup**: merged `scripts/deploy-runner.sh` + `.github/workflows/deploy.yml`.
- **Probe**: `scripts/deploy-runner.sh` line 32 (REPO_DIR default) is `$HOME/projects/AtilCalculator` or any `$HOME`-relative path that does NOT resolve to the GH Actions checkout directory.
- **Expected**: TEST FAILS — must default to `$GITHUB_WORKSPACE` (architect's fix per Issue #148 cmt) OR workflow YAML must explicitly pass `REPO_DIR: ${{ github.workspace }}` to the deploy step's `env:`.
- **Why**: RCA-5 bug from Issue #148. The first self-hosted deploy failed with `REPO_DIR does not exist: /home/gh-actions-runner/projects/AtilCalculator` because `$HOME` for the `gh-actions-runner` user resolves to `/home/gh-actions-runner/`, not the GH Actions workspace path. The fix is to use `$GITHUB_WORKSPACE` (the documented env var for the runner's checkout directory).

### AP-10: TELEGRAM env binding regression (RCA-6, NEW 2026-06-19T21:43Z per Issue #148)
- **Setup**: merged `.github/workflows/deploy.yml`.
- **Probe**: the workflow YAML's notify step `env:` block does NOT include BOTH `TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}` AND `TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}` (either step-level or job-level `env:`). A mere `secrets.TELEGRAM_BOT_TOKEN` reference in a YAML comment or unrelated step does NOT satisfy this probe.
- **Expected**: TEST FAILS — secrets must be bound to the env of the notify step (or job-level env) so `scripts/notify.sh` can read them at runtime.
- **Why**: RCA-6 bug from Issue #148. The first self-hosted deploy's notify step exited 1 because TELEGRAM_BOT_TOKEN was unset. The repo secrets were set (per Issue #143 AC #7) but the workflow YAML's notify step didn't bind them to its `env:` block. `scripts/notify.sh` reads TELEGRAM_BOT_TOKEN from env (or `~/.dev-studio-env`, which doesn't exist on the runner). Silent failure mode — exactly what RCA-2 + RCA-4 from Issue #138 was supposed to fix.

### AP-11: TELEGRAM secret values non-empty pre-flight (RCA-8, NEW 2026-06-20T04:25Z per Issue #152)
- **Setup**: merged `scripts/deploy-runner.sh` + repo secrets (`gh secret list`).
- **Probe**: `scripts/deploy-runner.sh` does NOT perform a pre-flight check that `${TELEGRAM_BOT_TOKEN}` and `${TELEGRAM_CHAT_ID}` are non-empty strings BEFORE invoking `scripts/notify.sh` (or BEFORE any destructive step that depends on notification, e.g., rollback notify).
- **Expected**: TEST FAILS — script MUST include a check like `[ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]` (or equivalent) early in execution, exiting non-zero with a clear error ("TELEGRAM_BOT_TOKEN is empty — re-set via gh secret set") if either is unset.
- **Why**: RCA-8 from Issue #152. PR #151's RCA-6 fix (workflow YAML env binding) worked syntactically — `gh secret list` shows the secrets exist, the workflow references them correctly, the env block is populated. **But the secret VALUES are empty** (run #27859671427 env block shows `TELEGRAM_BOT_TOKEN: ` / `TELEGRAM_CHAT_ID: ` with no value). This means the secrets were set with empty values at owner bootstrap time (likely `gh secret set -v""` or sourced env file with literal `TELEGRAM_BOT_TOKEN=` empty assignment). The workflow YAML surface test (AP-10) cannot catch this — secrets are encrypted at rest, only the runtime env block reveals emptiness. **A pre-flight check in the deploy script catches this AT DEPLOY TIME, before the service restart, instead of letting the silent notify failure corrupt the deploy gate.**

### AP-12: systemctl --user D-Bus reachable pre-flight (RCA-7, NEW 2026-06-20T04:25Z per Issue #152)
- **Setup**: merged `scripts/deploy-runner.sh` + prod host systemd config.
- **Probe**: `scripts/deploy-runner.sh` does NOT verify D-Bus session bus reachability BEFORE invoking `systemctl --user restart atilcalc-web.service`. Specifically, script lacks either:
  - `[ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]` check, OR
  - `systemctl --user status >/dev/null 2>&1` check, OR
  - explicit `command -v systemctl` + `systemctl --user is-system-running` check.
- **Expected**: TEST FAILS — script MUST include a D-Bus/systemd reachability pre-flight, failing fast with an actionable error message ("systemd user session not available — run `sudo loginctl enable-linger gh-actions-runner` on the prod host") if the check fails.
- **Why**: RCA-7 from Issue #152. PR #151's RCA-5 fix worked — REPO_DIR resolved correctly. But the runner's `gh-actions-runner` user has no active systemd user session (no `loginctl enable-linger`), so `systemctl --user` cannot reach D-Bus, fails with "Failed to connect to bus: No medium found". The deploy script treats this as a generic systemctl failure, exits 1, but the workspace was already `git reset --hard origin/main` — prod is in a half-deployed state. A pre-flight check converts silent half-deploy into loud, actionable failure.

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
1. TC-1..TC-11 PASS (or PASS-with-justified-exception for owner-gated TCs TC-1, TC-4, TC-5).
2. AP-1..AP-12 PASS (no false negatives).
3. `bash scripts/deploy-runner.sh --dry-run` exits 0 with valid SHA.
4. Workflow YAML parses (PyYAML) + structural assertions pass.
5. `gh api /repos/atilcan65/AtilCalculator/actions/runners` returns at least one `online` runner with `self-hosted` label (`atilcalc-prod` label optional, defer to Sprint 4).
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
- **2026-06-19T21:34Z (v3)**: PR #146 (workflow YAML) MERGED at 40242a2d. Self-hosted runner picked up the push → first self-hosted deploy FAILED at 21:34:33Z (run #27849461286).
- **2026-06-19T21:36Z (v3)**: Issue #148 filed — RCA-5 (REPO_DIR hardcoded to `$HOME/projects/AtilCalculator`, wrong for self-hosted runner user) + RCA-6 (TELEGRAM env not bound to notify step's `env:`).
- **2026-06-19T21:43Z (v3 — THIS FILE, AMENDMENT)**: Test plan amended per Issue #148. Added **TC-10** (REPO_DIR contract) + **AP-9** (REPO_DIR regression) + **AP-10** (TELEGRAM env regression). Strengthened **TC-4 §6** (TELEGRAM env binding — bound to env block, not just syntactically referenced). Relaxed **TC-1 §4** (`atilcalc-prod` label optional; `self-hosted` mandatory per Issue #143 owner-impl). Tester own-miss acknowledged (PR #146 review missed both bugs — TD-017 lesson parallels TD-016 architect lesson).
- **2026-06-20T04:25Z (v4 — THIS FILE, AMENDMENT)**: Test plan amended per Issue #152 (PR #151 MERGED but first self-hosted deploy post-fix FAILED at run #27859671427 with RCA-7 D-Bus unreachable + RCA-8 TELEGRAM secrets rendered empty). Added **TC-11** (systemd user session pre-flight) + **AP-11** (TELEGRAM secret values non-empty pre-flight) + **AP-12** (D-Bus reachable pre-flight). Closes the **runtime/depth** regression-test gap exposed by RCA-8: AP-10 validated the workflow YAML surface, but the secret VALUES themselves were empty at step execution. Lesson filed as **TD-018**: regression tests must cover the runtime/depth layer of an RCA, not just the syntactic surface. PR #150 amendment: same branch, new commit.

— @tester, 2026-06-20T04:25Z
