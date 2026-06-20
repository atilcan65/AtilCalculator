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
#
# Why v6: RCA-9 (Issue #160) — first auto-deploy after PR #157 merge FAILED
# at run #27862367000 because the v5 preflight dep install was WARN/SKIP
# when `.venv` was missing (fresh self-hosted runner checkout has no venv).
# The script logged a WARN, then `restart_service()` failed at the
# `.venv/bin/uvicorn not found` check (exit 3). v6 changes this to a
# FAIL/CREATE pattern: missing `.venv` → create via `uv venv`; missing `uv`
# → fail with exit 4; dep install failure → fail with exit 4.
#
# Why v7: RCA-11 (Issue #164) — second auto-deploy after PR #161 merge FAILED
# at run #27864083208 because v6's preflight ran `uv pip install -p .venv -e .`
# which only installs RUNTIME deps from pyproject.toml `dependencies = [...]`
# (mpmath==1.3.0). The FastAPI + uvicorn HTTP layer is declared as `[dev]`
# extras, NOT runtime, so it was never installed into `.venv/bin/uvicorn`.
# The script then correctly FAILED at the defense-in-depth restart_service()
# `.venv/bin/uvicorn not found` check (exit 4 — RCA-9 regression prevented),
# but the root cause is a pyproject.toml design gap: HTTP surface is a RUNTIME
# surface, not a dev tool. v7 adds an explicit
#   uv pip install -p "$REPO_DIR/.venv" fastapi==X uvicorn[standard]==Y
# after the editable install, matching the canonical runtime surface.
#
# Sprint 4 follow-up (NOT Sprint 3 P0): Option B — add a `web` extra to
# pyproject.toml and use `uv pip install -e .[web]` (ADR-0027 amendment).
# This script intentionally keeps Option A single-line fix for now to avoid
# coupling Sprint 3 P0 unblock with a design-amendment ADR. Drift risk is
# documented in Issue #164; pinning in 2 places is the trade-off.
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
# RCA-11 layer + fix (v7):
#   RCA-11: pyproject.toml declares fastapi+uvicorn as [dev] extras, not
#           runtime deps. `uv pip install -e .` only installs the runtime
#           list → .venv/bin/uvicorn never created → defense-in-depth
#           restart_service() check fires (exit 4). v6 fix verified working
#           (correct failure mode, no silent WARN), but RCA-11 reveals the
#           underlying design gap.
#     → fix: explicit `uv pip install -p .venv fastapi==X uvicorn[standard]==Y`
#           after the editable install. Pins duplicate pyproject.toml dev
#           list (Sprint 4 will consolidate via `web` extra per ADR-0027
#           amendment). Fail (exit 4) if install exits non-zero (parity with
#           RCA-7-4 + RCA-9 pattern).
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
#   2. Preflight: uv venv .venv (if missing) + uv pip install -e . (RCA-7-4 + RCA-9)
#      + explicit uv pip install fastapi+uvicorn[standard] (RCA-11)
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
#        `uv pip install` failed; RCA-11: explicit uvicorn+fastapi install
#        failed; owner must intervene manually)

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
  log "DRY-RUN: step 2: preflight uv venv .venv (if missing) + uv pip install -p .venv -e . (RCA-9 FAIL/CREATE) + explicit uv pip install fastapi+uvicorn[standard] (RCA-11)"
  log "DRY-RUN: step 3: preflight detect atilcalc-web.service (WARN-only)"
  log "DRY-RUN: step 4: pkill uvicorn + nohup setsid .venv/bin/uvicorn atilcalc.api.main:app --host $ATC_BIND_HOST --port $ATC_PORT"
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
#   3. ALWAYS run `uv pip install -p .venv -e .`; FAIL with exit 4 if it
#      exits non-zero (silent WARN was the v5 bug — RCA-7-4 root cause)
#   4. ALWAYS run explicit `uv pip install -p .venv fastapi uvicorn[standard]`;
#      FAIL with exit 4 if it exits non-zero (RCA-11: pyproject.toml declares
#      these as [dev] extras, so `uv pip install -e .` does NOT install them;
#      Sprint 4 will consolidate via `web` extra — see ADR-0027 amendment TODO)
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
log "Preflight: installing runtime deps via uv pip install -p .venv -e . (RCA-7-4 + RCA-9 fix)"
if ! uv pip install -p "$REPO_DIR/.venv" -e "$REPO_DIR" 2>&1 | tee /tmp/deploy-uv-install.log; then
  fail "uv pip install failed (RCA-7-4). See /tmp/deploy-uv-install.log. Common cause: pyproject.toml dep list broken or registry unreachable." 4
fi
log "Preflight: runtime deps installed successfully"

# RCA-11 fix (Issue #164): pyproject.toml declares fastapi+uvicorn as [dev]
# extras, so `uv pip install -e .` does NOT install them. Sprint 4 follow-up
# will add a `web` extra to pyproject.toml and switch this to `-e .[web]`;
# for Sprint 3 P0 we pin the runtime surface explicitly here.
# Pinned EXACT per ADR-0017 doctrine — these must match pyproject.toml [dev].
# Drift detection: d015-rca-11-runtime-deps.sh fails if versions diverge.
log "Preflight: installing HTTP runtime surface (fastapi + uvicorn[standard]) explicitly (RCA-11 fix)"
if ! uv pip install -p "$REPO_DIR/.venv" \
      fastapi==0.115.6 \
      'uvicorn[standard]==0.32.1' \
      2>&1 | tee /tmp/deploy-uv-install-web.log; then
  fail "uv pip install fastapi+uvicorn failed (RCA-11). See /tmp/deploy-uv-install-web.log. Common cause: registry unreachable or pin mismatch with pyproject.toml [dev] extra." 4
fi
log "Preflight: HTTP runtime surface installed successfully"

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
  # Kill any existing uvicorn process for atilcalc. pkill returns 1 if no match
  # found — that is the normal steady-state (no service running yet) and must
  # NOT fail the deploy.
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

  log "Post-restart process check (ps aux | grep uvicorn | grep -v grep):"
  if ps aux | grep uvicorn | grep -v grep; then
    log "Post-restart: uvicorn process is running"
  else
    log "WARN: no uvicorn process found after restart — service may have failed to start"
    log "WARN: smoke test will fail and trigger rollback (ADR-0027 §Decision.3)"
  fi
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
