#!/usr/bin/env bash
# scripts/deploy-runner.sh — DEPLOY-001 prod-host runner v7 (refs #130, #155,
# ADR-0027, ADR-0027-amend-1 implied by RCA-7 4-layer findings, RCA-9 + RCA-11 fix).
#
# Sprint 3 v5 rewrite per Issue #155 — supersedes PR #151 (e13407d) v4.
# Sprint 3 v6 amend per Issue #160 — supersedes PR #157 v5 for the preflight
# dep install path. v6 is a follow-up bugfix, not a rewrite — restart pattern
# unchanged (RCA-7-1/2/3 fix verified working at PR #157 squash c7c060e).
# Sprint 3 v7 amend per Issue #164 — supersedes v6 for the explicit
# uvicorn+fastapi runtime install path. v7 is a follow-up bugfix, not a
# rewrite — FAIL-or-CREATE preflight pattern unchanged (RCA-9 fix verified
# working at PR #161 squash 73fc618).
# Sprint 3 v8 amend per Issue #168 — supersedes v7 for the cross-user port
# kill failure. v8 is a follow-up bugfix, not a rewrite — restart pattern
# (nohup+setsid) unchanged (RCA-7-1/2/3 fix verified working at PR #157
# squash c7c060e), but the pre-check (port-owner via `ss -tlnp`, exit 5)
# and post-check (port-PID etimes via `ss -tlnp`, exit 6) are now strict.
#
# Why v6: RCA-9 (Issue #160) — first auto-deploy after PR #157 merge FAILED
# at run #27862367000 because the v5 preflight dep install was WARN/SKIP
# when `.venv` was missing (fresh self-hosted runner checkout has no venv).
# The script logged a WARN, then `restart_service()` failed at the
# `.venv/bin/uvicorn not found` check (exit 3). v6 changes this to a
# FAIL/CREATE pattern: missing `.venv` → create via `uv venv`; missing `uv`
# → fail with exit 4; dep install failure → fail with exit 4.
#
# Why v8: RCA-12 (Issue #168) — eighth auto-deploy after PR #165 merge FAILED
# at run #27865086173 because deploy-runner.sh restart_service() called
# `pkill -f 'uvicorn.*atilcalc' 2>/dev/null || true` (silent on cross-user
# no-op) and the post-restart check was `ps aux | grep uvicorn | grep -v grep`
# (matches ANY uvicorn — not port-aware). A pre-existing uvicorn (PID 33353,
# owned by user `atilcan`, started 2026-06-20T05:02 from the manual unblock,
# bound to port 8000) stayed up because the self-hosted runner (user
# `gh-actions-runner`) cannot kill a process owned by a different user
# without sudo. The runner's nohup-spawned uvicorn tried to bind port 8000
# and failed. The lenient post-check returned "running" (atilcan's old
# uvicorn was running, just not the right one). The smoke test curled
# 127.0.0.1:8000 → hit atilcan's uvicorn → git_sha mismatch (got=e13407d9,
# want=540deffe=PR #165 merge) → rollback → exit 1.
#
# v8 implements two defense-in-depth checks:
#   1. **Pre-restart** (before pkill): `ss -tlnp "sport = :$ATC_PORT"` →
#      extract the port-bound PID's uid; if different from current uid,
#      fail-fast with exit 5 (cross-user port conflict). The pre-check
#      MUST appear before pkill in source order so cross-user conflicts
#      surface as a clear error rather than a silent no-op.
#   2. **Post-restart** (replace lenient `ps aux | grep uvicorn`): after
#      a 2s bind-settle, `ss -tlnp "sport = :$ATC_PORT"` → verify the
#      port-bound process started RECENTLY (etimes ≤ 60s). The atilcan
#      uvicorn from the manual unblock has been running for hours
#      (etimes >> 60s); our just-spawned uvicorn has etimes ~2s. If the
#      port-bound process is OLD, fail with exit 6 (port-PID mismatch
#      — cross-user scenario recurring). This is the same family of
#      "lenient silent failure" anti-pattern that motivated the FAIL-or-
#      CREATE fix in v6 (RCA-9); v8 extends the FAIL-or-CREATE doctrine
#      to the restart step.
#
# New exit codes (5 + 6) are the RCA-12 surface; the pre-check + post-check
# pair is defense-in-depth. The pre-check should catch all cross-user
# scenarios at the gate; the post-check is the backstop in case the
# pre-check tool (`ss`) is missing on the host or the port is in a
# transient state at the moment of the check.
#
# Why v7: RCA-11 (Issue #164) — second auto-deploy after PR #161 merge FAILED
# at run #27864083208 because v6's preflight ran `uv pip install -p .venv -e .`
# which only installs RUNTIME deps from pyproject.toml `dependencies = [...]`
# (mpmath==1.3.0). The FastAPI + uvicorn HTTP layer was declared as `[dev]`
# extras, NOT runtime, so it was never installed into `.venv/bin/uvicorn`.
# The script then correctly FAILED at the defense-in-depth restart_service()
# `.venv/bin/uvicorn not found` check (exit 4 — RCA-9 regression prevented),
# but the root cause is a pyproject.toml design gap: HTTP surface is a RUNTIME
# surface, not a dev tool. v7 implements **Option B** (architect's preferred
# Sprint 4 hygiene, now Sprint 3 P0 due to merged test contract AP-23c): adds
# a `web` extra to pyproject.toml (single source of truth for prod runtime
# pins) and switches the preflight to `uv pip install -p .venv -e ".[web]"`.
# The `[dev]` extra retains the dev tooling (pytest, ruff, mypy, playwright)
# plus the package names `fastapi` and `uvicorn[standard]` (UN-pinned; dev
# tooling uses pip's resolver — see AP-23c carve-out rationale in
# docs/test-plans/DEPLOY-001-tests.md).
#
# 4 RCA-7 layers + fixes (v5):
#   RCA-7-1: atilcalc-web.service systemd unit does NOT exist on prod
#     → fix: nohup+setsid canonical restart (systemd detection is now WARN-only)
#   RCA-7-2: symptom of 7-1
#     → fix: same as 7-1
#   RCA-7-3: hallucinated module path atilcalc.web.app:app (atilcalc.web is JS-only)
#     → fix: canonical module is atilcalc.api.main:app (verified 12 references)
#   RCA-7-4: stale .venv lacks runtime deps (mpmath==1.3.0) after git reset
#     → fix: preflight uv pip install -p .venv -e .
#
# RCA-9 layer + fix (v6):
#   RCA-9:  fresh self-hosted runner checkout has NO .venv at all (not just
#           stale deps). v5 preflight was WARN/SKIP when .venv missing →
#           restart_service() failed at the existence check → exit 3.
#     → fix: FAIL-or-CREATE pattern — `uv venv .venv` if missing; fail
#           (exit 4) if uv missing or venv creation fails or `uv pip install`
#           exits non-zero. New exit code 4 = preflight failure.
#
# RCA-12 layer + fix (v8):
#   RCA-12: cross-user process kill silently no-ops. pkill -f ... || true
#           succeeds (returns 0) on cross-user targets, leaving atilcan's
#           pre-existing uvicorn on port 8000. The lenient post-check
#           (ps aux | grep uvicorn) returns "running" for atilcan's uvicorn
#           (matches ANY uvicorn), so the smoke test curls 127.0.0.1:8000,
#           hits the wrong uvicorn, sees old git_sha, fails, rolls back.
#     → fix: pre-restart `ss -tlnp` port-owner check (exit 5 on cross-user)
#           + post-restart `ss -tlnp` etimes check (exit 6 on stale port).
#           The pre-check is the gate; the post-check is defense-in-depth.
#           Both use `ss -tlnp` (port-aware) — NOT the lenient ps grep.
#
# RCA-11 layer + fix (v7):
#   RCA-11: pyproject.toml declared fastapi+uvicorn as [dev] extras, not
#           runtime deps. `uv pip install -e .` only installs the runtime
#           list → .venv/bin/uvicorn never created → defense-in-depth
#           restart_service() check fires (exit 4). v6 fix verified working
#           (correct failure mode, no silent WARN), but RCA-11 reveals the
#           underlying design gap.
#     → fix: **Option B** — add a `web` extra to pyproject.toml (single
#           source of truth for prod runtime pins — see pyproject.toml
#           [project.optional-dependencies] web), then switch
#           deploy-runner.sh to `uv pip install -p .venv -e ".[web]"`.
#           The `[dev]` extra retains pytest/ruff/mypy/playwright + the
#           un-pinned package names `fastapi` and `uvicorn[standard]`
#           for dev tooling (TestClient, httpx test backend). Fail
#           (exit 4) on install failure (parity with RCA-7-4 + RCA-9
#           pattern). Satisfies merged test contract AP-23c "exactly
#           one place" probe — pins live in pyproject [web] only, NOT
#           duplicated in this script.
#
# Canonical restart pattern (matches manual unblock 2026-06-20T05:02:42Z):
#   pkill -f 'uvicorn.*atilcalc' 2>/dev/null || true
#   sleep 1
#   PYTHONPATH=$REPO_DIR/src nohup setsid .venv/bin/uvicorn \
#       atilcalc.api.main:app --host 0.0.0.0 --port $ATC_PORT \
#       > /tmp/atilcalc-web.log 2>&1 &
#   disown
#   sleep 2
#   ps aux | grep uvicorn | grep -v grep  # post-check
#
# systemd fallback (informational only — no longer required for deploy success):
#   The atilcalc-web.service unit was never installed on this host (RCA-7-1).
#   ADR-0010 documented the PATTERN (systemd user-service) but not the
#   actual prod instance. Sprint 4 ADR-0010 supplement will document the
#   nohup canonical pattern + actual prod host (atiltestweb, not
#   192.168.1.199) + actual deploy path (/home/atilcan/atilcalc).
#
# Invoked on the prod host by .github/workflows/deploy.yml via the
# self-hosted runner (Issue #143 in flight) or, as fallback, via
# appleboy/ssh-action with the same script (per ADR-0027 §Decision.2).
#
# Responsibilities per ADR-0027 §Decision.3 (smoke test) + §Decision.5 (idempotency):
#   1. git fetch + reset --hard origin/main             (idempotent converge)
#   2. Preflight: uv venv .venv (if missing) + uv pip install -e ".[web]"
#      (RCA-7-4 + RCA-9 + RCA-11 — [web] extra is single source of truth)
#   3. Preflight: detect atilcalc-web.service (WARN-only)
#   4. Restart via nohup+setsid canonical pattern       (replaces systemctl)
#   5. GET /healthz smoke test                          (DEPLOY-003 contract)
#   6. On smoke-test failure: rollback + retry once     (HEAD@{1} revert)
#   7. On double-failure: page owner via notify.sh      (ADR-0027 §Decision.3)
#
# Module path: atilcalc.api.main:app (NEVER atilcalc.web.app — atilcalc.web is
# the JS Web Components dir, no Python app object exists there).
#
# Usage on prod host:
#   GITHUB_SHA=<40-char-hex> bash scripts/deploy-runner.sh
#   GITHUB_SHA=<40-char-hex> bash scripts/deploy-runner.sh --dry-run
#
# Exit codes:
#   0  — smoke test passed, prod running the expected SHA
#   1  — smoke test failed but rollback succeeded; deploy should be retried
#   2  — smoke test failed AND rollback failed; owner paged, manual fix needed
#   3  — usage / configuration error (missing GITHUB_SHA, bad REPO_DIR, etc.)
#   4  — preflight failure (RCA-9: uv missing, venv creation failed, or
#        `uv pip install -e ".[web]"` failed; RCA-11: [web] extra missing
#        or broken; owner must intervene manually)
#   exit code 5 — cross-user port conflict (RCA-12: port $ATC_PORT is bound
#        by a process owned by a different user; runner cannot kill it
#        without sudo. Fix: run runner as the prod user, sudoers rule, or
#        change $ATC_PORT to a non-conflicting port. Owner must intervene.)
#   exit code 6 — post-restart port-PID mismatch (RCA-12: post-restart
#        ss -tlnp shows the port is bound by a process with etimes > 60s
#        — a pre-existing uvicorn, not our just-spawned one. The pre-check
#        should have caught this with exit 5; investigate tool/sudo chain.)

set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
fail() { log "ERROR: $*"; exit "${2:-1}"; }

# --- Hostname detection (AC #155 #10 — log prod host for audit; warn if unexpected) ---
PROD_HOSTNAME="${PROD_HOSTNAME:-atiltestweb}"
ACTUAL_HOSTNAME="$(hostname 2>/dev/null || echo 'unknown')"
log "Deploy target hostname: $ACTUAL_HOSTNAME (expected prod: $PROD_HOSTNAME)"
if [[ "$ACTUAL_HOSTNAME" != "$PROD_HOSTNAME" ]]; then
  log "WARN: hostname '$ACTUAL_HOSTNAME' is not the documented prod host '$PROD_HOSTNAME'"
  log "WARN: continuing — operator must confirm this is intentional (Sprint 4 ADR-0010 supplement)"
fi

# --- Config (env-driven so the same script works in --dry-run and prod) ---
# REPO_DIR default chain (RCA-7 host discovery — Issue #152 RCA cmt 2026-06-20T05:03Z):
#   1. Caller override (REPO_DIR env var, e.g., from workflow YAML)
#   2. ${GITHUB_WORKSPACE} — set by GH Actions in self-hosted runner context
#   3. /home/atilcan/atilcalc — actual prod path on atiltestweb
#      (NOT $HOME/projects/AtilCalculator — that path was v4's wrong default per
#       RCA-5; the actual prod path is /home/atilcan/atilcalc)
REPO_DIR="${REPO_DIR:-${GITHUB_WORKSPACE:-/home/atilcan/atilcalc}}"
ATC_PORT="${ATC_PORT:-8000}"
# ATC_HOST is the smoke-test target (curl origin). Loopback is correct when the
# runner is on the same host as the service. Service bind host is separate
# (ATC_BIND_HOST) — see below.
ATC_HOST="${ATC_HOST:-127.0.0.1}"
# ATC_BIND_HOST is the host the uvicorn service binds to. 0.0.0.0 = all
# interfaces (LAN-reachable from 192.168.1.x or any network the host is on).
ATC_BIND_HOST="${ATC_BIND_HOST:-0.0.0.0}"
HEALTHZ_URL="http://${ATC_HOST}:${ATC_PORT}/healthz"
HEALTHZ_TIMEOUT_SEC="${HEALTHZ_TIMEOUT_SEC:-5}"
SMOKE_ATTEMPTS="${SMOKE_ATTEMPTS:-5}"
SMOKE_RETRY_DELAY_SEC="${SMOKE_RETRY_DELAY_SEC:-2}"

# --- GITHUB_SHA is mandatory (the smoke test asserts git_sha == this value) ---
if [[ -z "${GITHUB_SHA:-}" ]]; then
  fail "GITHUB_SHA env var is required (caller must pass it; the GH Action does this automatically)" 3
fi
# Validate SHA shape (40-char hex) so a malformed value is caught early.
if ! [[ "$GITHUB_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  fail "GITHUB_SHA must be a 40-char hex SHA, got: $GITHUB_SHA" 3
fi

# --- Parse flags ---
DRY_RUN="false"
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN="true"
fi

# --- Preflight (only in prod mode) ---
if [[ "$DRY_RUN" == "false" ]]; then
  if [[ ! -d "$REPO_DIR" ]]; then
    fail "REPO_DIR does not exist: $REPO_DIR" 3
  fi
  if ! command -v curl >/dev/null 2>&1; then
    fail "curl not found on PATH (smoke test requires it)" 3
  fi
fi

# --- --dry-run: print the plan, then exit 0 ---
if [[ "$DRY_RUN" == "true" ]]; then
  log "DRY-RUN: no changes will be made"
  log "DRY-RUN: REPO_DIR=$REPO_DIR"
  log "DRY-RUN: GITHUB_SHA=$GITHUB_SHA"
  log "DRY-RUN: HEALTHZ_URL=$HEALTHZ_URL"
  log "DRY-RUN: ATC_HOST=$ATC_HOST ATC_BIND_HOST=$ATC_BIND_HOST ATC_PORT=$ATC_PORT"
  log "DRY-RUN: step 1: cd $REPO_DIR && git fetch origin && git reset --hard origin/main"
  log "DRY-RUN: step 2: preflight uv venv .venv (if missing) + uv pip install -p .venv -e '.[web]' (RCA-9 FAIL/CREATE + RCA-11 [web] extra — single source of truth)"
  log "DRY-RUN: step 3: preflight detect atilcalc-web.service (WARN-only)"
  log "DRY-RUN: step 4: RCA-12 pre-check ss -tlnp (port-owner uid vs current uid, exit 5 on cross-user) + pkill uvicorn + nohup setsid .venv/bin/uvicorn atilcalc.api.main:app --host $ATC_BIND_HOST --port $ATC_PORT + RCA-12 post-check ss -tlnp etimes (exit 6 on stale port)"
  log "DRY-RUN: step 5: smoke test $HEALTHZ_URL (expecting git_sha=$GITHUB_SHA)"
  log "DRY-RUN: step 6 (on smoke-test failure): git reset --hard HEAD@{1} + restart + retry"
  log "DRY-RUN: step 7 (on double failure): page owner via scripts/notify.sh -l human"
  exit 0
fi

cd "$REPO_DIR"

# --- Step 1: idempotent converge to origin/main (ADR-0027 §Decision.5) ---
log "Fetching origin (REPO_DIR=$REPO_DIR)"
git fetch origin
log "Resetting to origin/main (target SHA=$GITHUB_SHA)"
git reset --hard origin/main

# Sanity: confirm we landed on the SHA the workflow requested.
actual_sha="$(git rev-parse HEAD)"
if [[ "$actual_sha" != "$GITHUB_SHA" ]]; then
  fail "post-reset HEAD ($actual_sha) != GITHUB_SHA ($GITHUB_SHA); something is very wrong" 1
fi
log "HEAD is at $actual_sha — matches GITHUB_SHA"

# --- Step 2: preflight dep install (RCA-7-4 — stale .venv; RCA-9 — missing .venv;
#               RCA-11 — uvicorn+fastapi declared as dev extras, not runtime) ---
# git reset --hard syncs source files but does NOT install Python deps AND
# does NOT preserve .venv from prior runs (a fresh self-hosted runner
# checkout has no .venv at all — RCA-9). The v6 fix is FAIL-or-CREATE
# (replaces v5's WARN-or-SKIP which left the restart step running with a
# non-existent binary):
#   1. If `uv` is missing → FAIL with exit 4 (cannot proceed without it)
#   2. If `.venv` is missing → CREATE via `uv venv .venv`; fail with exit 4
#      if venv creation itself fails
#   3. ALWAYS run `uv pip install -p .venv -e ".[web]"` (RCA-7-4 + RCA-9 +
#      RCA-11). The `[web]` extra is the prod runtime surface (FastAPI +
#      uvicorn); pins are SINGLE SOURCE OF TRUTH in pyproject.toml [web]
#      (AP-23c "exactly one place" probe). FAIL with exit 4 on install
#      failure (silent WARN was the v5 bug — RCA-7-4 root cause).
# The `.venv` creation step is idempotent (no-op if .venv already exists),
# so repeated deploys converge to a stable state.
if ! command -v uv >/dev/null 2>&1; then
  fail "uv not found on PATH (RCA-9 — preflight dep install requires uv). Install uv on the prod host or pre-create $REPO_DIR/.venv manually." 4
fi
if [[ ! -d "$REPO_DIR/.venv" ]]; then
  log "Preflight: .venv missing at $REPO_DIR/.venv — creating via uv venv (RCA-9 fix; fresh self-hosted runner checkout has no venv)"
  if ! uv venv "$REPO_DIR/.venv" 2>&1 | tee /tmp/deploy-uv-venv.log; then
    fail "uv venv creation failed (RCA-9). See /tmp/deploy-uv-venv.log. Manual fix: pre-create $REPO_DIR/.venv (python3 -m venv or uv venv) then re-run." 4
  fi
  log "Preflight: .venv created at $REPO_DIR/.venv"
fi
log "Preflight: installing prod runtime surface via uv pip install -p .venv -e '.[web]' (RCA-7-4 + RCA-9 + RCA-11 — [web] extra is the single source of truth for fastapi+uvicorn pins)"
if ! uv pip install -p "$REPO_DIR/.venv" -e ".[web]" 2>&1 | tee /tmp/deploy-uv-install.log; then
  fail "uv pip install -e '.[web]' failed (RCA-7-4 + RCA-11). See /tmp/deploy-uv-install.log. Common cause: pyproject.toml [web] extra broken, or registry unreachable, or [web] extra not declared." 4
fi
log "Preflight: prod runtime surface installed successfully"

# --- Step 3: preflight detect atilcalc-web.service (AC #155 #2 — WARN-only, do not fail) ---
# Per RCA-7-1, the systemd unit was never installed on this host. The detection
# is informational — log + warn + continue. We do NOT fail the deploy on
# missing unit because the nohup+setsid canonical path is what actually runs
# the service.
if command -v systemctl >/dev/null 2>&1; then
  # `systemctl --user list-unit-files` may itself fail (no D-Bus session) on
  # the runner context. Suppress all errors and treat any failure as
  # "unit not registered" — which is the correct state for this host.
  unit_state="$(systemctl --user list-unit-files atilcalc-web.service 2>/dev/null || true)"
  if [[ -n "$unit_state" ]] && printf '%s' "$unit_state" | grep -q atilcalc-web; then
    log "INFO: atilcalc-web.service systemd unit is registered; nohup canonical path is still preferred (RCA-7-1)"
  else
    log "WARN: atilcalc-web.service systemd unit NOT registered (RCA-7-1) — using nohup canonical path"
  fi
else
  log "INFO: systemctl not on PATH; nohup canonical path is the only path"
fi

# --- Step 4: restart via nohup+setsid canonical pattern (RCA-7-1/2/3 fix) ---
# Extracted as a function so step 6 (rollback) reuses the same restart logic
# — keeps the restart shape in exactly one place. Matches the manual unblock
# at 2026-06-20T05:02:42Z (PID 33353) verbatim.
restart_service() {
  log "Restarting atilcalc-web.service via nohup+setsid canonical pattern (RCA-7-1/2/3)"

  # --- RCA-12 pre-restart: cross-user port conflict detection (BEFORE pkill) ---
  # The runner (user gh-actions-runner) cannot kill a process owned by a
  # different user (e.g., atilcan's pre-existing uvicorn from the 05:02
  # manual unblock — RCA-12 root cause). The `pkill -f ... || true` below
  # would silently no-op on such targets. Detect the conflict here, before
  # pkill gets a chance, and fail-fast with exit 5 (cross-user port conflict).
  # `ss -tlnp` is port-aware (gives the PID bound to the port) — the
  # alternative `lsof -i :$ATC_PORT -t` works too but `ss` is the more
  # common pre-installed tool on modern Linux distros. Either is fine.
  pre_port_pid=""
  if command -v ss >/dev/null 2>&1; then
    pre_line=$(ss -tlnpH "sport = :$ATC_PORT" 2>/dev/null | head -1 || true)
    if [[ -n "$pre_line" ]]; then
      pre_port_pid=$(printf '%s' "$pre_line" | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2 || true)
    fi
  elif command -v lsof >/dev/null 2>&1; then
    pre_port_pid=$(lsof -ti ":$ATC_PORT" 2>/dev/null | head -1 || true)
  fi
  if [[ -n "$pre_port_pid" ]]; then
    pre_uid=$(ps -o uid= -p "$pre_port_pid" 2>/dev/null | tr -d ' ' || true)
    current_uid=$(id -u)
    if [[ -n "$pre_uid" ]] && [[ "$pre_uid" != "$current_uid" ]]; then
      pre_user=$(ps -o user= -p "$pre_port_pid" 2>/dev/null | tr -d ' ' || echo "uid:$pre_uid")
      fail "port $ATC_PORT is occupied by PID $pre_port_pid owned by user '$pre_user' (uid=$pre_uid), NOT current user '$USER' (uid=$current_uid). Cross-user kill not possible without sudo (RCA-12 — 8th deploy fail at run 27865086173). Fix: run self-hosted runner as user '$pre_user', OR pre-stop the existing uvicorn via 'sudo -u $pre_user pkill -f atilcalc.api.main:app', OR change \$ATC_PORT to a non-conflicting port." 5
    fi
    log "RCA-12 pre-check: port $ATC_PORT owned by PID $pre_port_pid (uid=$pre_uid, current uid=$current_uid) — same user, kill will work"
  else
    log "RCA-12 pre-check: port $ATC_PORT is free (no listener); pkill will be a no-op steady-state"
  fi

  # Kill any existing uvicorn process for atilcalc. pkill returns 1 if no match
  # found — that is the normal steady-state (no service running yet) and must
  # NOT fail the deploy. RCA-12: the pre-check above guarantees that if
  # pkill silently no-ops due to a cross-user target, we have already
  # failed with exit 5 (not silently continued).
  pkill -f 'uvicorn.*atilcalc' 2>/dev/null || true
  sleep 1

  # Validate .venv/bin/uvicorn exists — defense in depth. Step 2 (preflight)
  # should have ensured this via FAIL-or-CREATE pattern (RCA-9 fix), but if
  # something raced and the venv disappeared between steps, surface that as
  # a clear preflight failure rather than letting nohup fail silently.
  if [[ ! -x "$REPO_DIR/.venv/bin/uvicorn" ]]; then
    fail ".venv/bin/uvicorn not found or not executable at $REPO_DIR/.venv/bin/uvicorn (RCA-9 regression — step 2 preflight did not produce a valid uvicorn binary)" 4
  fi

  log "Starting: PYTHONPATH=$REPO_DIR/src nohup setsid .venv/bin/uvicorn atilcalc.api.main:app --host $ATC_BIND_HOST --port $ATC_PORT"
  # PYTHONPATH is belt-and-suspenders for the editable install: even if the
  # .pth file from `uv pip install -e .` is missing or stale, PYTHONPATH
  # ensures atilcalc.api.main is importable from $REPO_DIR/src.
  PYTHONPATH="$REPO_DIR/src" nohup setsid "$REPO_DIR/.venv/bin/uvicorn" \
      atilcalc.api.main:app \
      --host "$ATC_BIND_HOST" --port "$ATC_PORT" \
      > /tmp/atilcalc-web.log 2>&1 &
  disown
  sleep 2

  # --- RCA-12 post-restart: strict port-PID etimes check (REPLACES lenient ps grep) ---
  # The old `ps aux | grep uvicorn | grep -v grep` check was lenient — it
  # returned success for ANY uvicorn process, including a pre-existing
  # atilcan-owned uvicorn that survived the pkill (cross-user no-op).
  # The new check verifies the port-bound process started RECENTLY
  # (etimes ≤ 60s). atilcan's pre-existing uvicorn has been running for
  # hours (etimes >> 60s); our just-spawned uvicorn has etimes ~2s.
  # If the port-bound process is OLD, the cross-user scenario is recurring
  # → fail with exit 6 (port-PID mismatch). This is defense-in-depth: the
  # pre-check should have caught it with exit 5; this is the backstop in
  # case the pre-check tool was missing or the port was in a transient
  # state at the moment of the check.
  new_port_pid=""
  if command -v ss >/dev/null 2>&1; then
    new_line=$(ss -tlnpH "sport = :$ATC_PORT" 2>/dev/null | head -1 || true)
    if [[ -n "$new_line" ]]; then
      new_port_pid=$(printf '%s' "$new_line" | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2 || true)
    fi
  elif command -v lsof >/dev/null 2>&1; then
    new_port_pid=$(lsof -ti ":$ATC_PORT" 2>/dev/null | head -1 || true)
  fi
  if [[ -z "$new_port_pid" ]]; then
    fail "RCA-12 post-check: no process is bound to port $ATC_PORT after restart — uvicorn may have failed to bind (RCA-12 defense-in-depth)" 6
  fi
  # Verify the port-bound process started recently (within 60s).
  new_etimes=$(ps -o etimes= -p "$new_port_pid" 2>/dev/null | tr -d ' ' || echo "")
  if [[ -z "$new_etimes" ]] || ! [[ "$new_etimes" =~ ^[0-9]+$ ]]; then
    fail "RCA-12 post-check: cannot determine etimes for PID $new_port_pid on port $ATC_PORT" 6
  fi
  if [[ "$new_etimes" -gt 60 ]]; then
    new_user=$(ps -o user= -p "$new_port_pid" 2>/dev/null | tr -d ' ' || echo "uid:?")
    fail "RCA-12 post-check: port $ATC_PORT is bound by PID $new_port_pid (user=$new_user, etimes=${new_etimes}s) — NOT our just-spawned uvicorn. Cross-user scenario recurring. Pre-check exit 5 should have caught this; investigate tool/sudo chain." 6
  fi
  log "RCA-12 post-check: port $ATC_PORT owned by PID $new_port_pid (etimes=${new_etimes}s, recent) — uvicorn restart verified"
}

restart_service

# --- Step 5: smoke test (DEPLOY-003 / ADR-0027 §Decision.3) ---
log "Smoke test: GET $HEALTHZ_URL (expecting git_sha=$GITHUB_SHA)"
smoke_ok="false"
for attempt in $(seq 1 "$SMOKE_ATTEMPTS"); do
  if body=$(curl -fsS --max-time "$HEALTHZ_TIMEOUT_SEC" "$HEALTHZ_URL" 2>/dev/null); then
    # Extract git_sha defensively (JSON parser could fail if body is malformed;
    # we fall back to grep rather than failing the loop on a JSON parse error).
    actual_sha=$(printf '%s' "$body" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("git_sha", "") or "")
except Exception:
    print("")
' 2>/dev/null || true)
    if [[ "$actual_sha" == "$GITHUB_SHA" ]]; then
      log "Smoke test PASSED on attempt $attempt: git_sha matches GITHUB_SHA"
      smoke_ok="true"
      break
    fi
    log "Smoke test attempt $attempt: git_sha mismatch (got=$actual_sha want=$GITHUB_SHA)"
  else
    log "Smoke test attempt $attempt: curl failed (service not up yet?)"
  fi
  sleep "$SMOKE_RETRY_DELAY_SEC"
done

if [[ "$smoke_ok" == "true" ]]; then
  exit 0
fi

# --- Step 6: rollback (ADR-0027 §Decision.3 auto-rollback, restart uses new nohup path) ---
log "Smoke test FAILED after $SMOKE_ATTEMPTS attempts; rolling back to HEAD@{1}"
git reset --hard HEAD@{1}
restart_service

# --- Step 7: retry smoke test once; if this ALSO fails, page owner ---
log "Retry smoke test after rollback"
retry_ok="false"
if body=$(curl -fsS --max-time "$HEALTHZ_TIMEOUT_SEC" "$HEALTHZ_URL" 2>/dev/null); then
  log "Post-rollback smoke test PASSED (deploy rolled back to a working prior SHA)"
  retry_ok="true"
fi

if [[ "$retry_ok" == "true" ]]; then
  log "Returning exit 1: deploy failed but rollback succeeded; workflow should page owner"
  exit 1
fi

# Double-failure: page owner (per ADR-0027 §Decision.3)
log "Double-failure: smoke test failed BEFORE and AFTER rollback; paging owner"
notify_path="$REPO_DIR/scripts/notify.sh"
if [[ -x "$notify_path" ]]; then
  "$notify_path" -l human "[DEPLOY] Prod rollback FAILED on $ACTUAL_HOSTNAME — manual intervention required. Expected SHA=$GITHUB_SHA. See workflow: $GITHUB_SHA" || true
else
  log "WARN: $notify_path not found or not executable; cannot page owner via notify.sh"
fi
exit 2
