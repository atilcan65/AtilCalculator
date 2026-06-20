#!/usr/bin/env bash
# scripts/deploy-runner.sh — DEPLOY-001 prod-host runner (refs #130, ADR-0027).
#
# Invoked on the prod host (REPO_DIR/ATC_HOST are env-driven so the same
# script works across prod / staging / CI rehearsal) by
# .github/workflows/deploy.yml
# via appleboy/ssh-action's `script_path` parameter. Responsibilities per
# ADR-0027 §Decision.3 (smoke test) + §Decision.5 (idempotency):
#
#   1. git fetch + reset --hard origin/main        (idempotent converge)
#   2. systemctl --user restart atilcalc-web.service (ADR-0010 §user-service)
#   3. GET /healthz smoke test                      (DEPLOY-003 contract)
#   4. On smoke-test failure: rollback + retry once (HEAD@{1} revert)
#   5. On double-failure: page owner via notify.sh  (ADR-0027 §Decision.3)
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

set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
fail() { log "ERROR: $*"; exit "${2:-1}"; }

# --- Config (env-driven so the same script works in --dry-run and prod) ---
# REPO_DIR default chain (RCA-5 fix, Issue #148):
#   1. Caller override (REPO_DIR env var, e.g., from workflow YAML)
#   2. ${GITHUB_WORKSPACE} — set by GH Actions in self-hosted runner context
#   3. $HOME/projects/AtilCalculator — manual invocation fallback (CI rehearsal)
REPO_DIR="${REPO_DIR:-${GITHUB_WORKSPACE:-$HOME/projects/AtilCalculator}}"
ATC_PORT="${ATC_PORT:-8000}"
ATC_HOST="${ATC_HOST:-127.0.0.1}"
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
  if ! command -v systemctl >/dev/null 2>&1; then
    fail "systemctl not found on PATH (expected systemd-managed host)" 3
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
  log "DRY-RUN: ATC_HOST=$ATC_HOST ATC_PORT=$ATC_PORT"
  log "DRY-RUN: step 1: cd $REPO_DIR && git fetch origin && git reset --hard origin/main"
  log "DRY-RUN: step 2: systemctl --user restart atilcalc-web.service"
  log "DRY-RUN: step 3: smoke test $HEALTHZ_URL (expecting git_sha=$GITHUB_SHA)"
  log "DRY-RUN: step 4 (on smoke-test failure): git reset --hard HEAD@{1} + restart + retry"
  log "DRY-RUN: step 5 (on double failure): page owner via scripts/notify.sh -l human"
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

# --- Step 2: restart systemd user-service (ADR-0010 §systemd user-service) ---
log "Restarting atilcalc-web.service"
systemctl --user restart atilcalc-web.service

# --- Step 3: smoke test (DEPLOY-003 / ADR-0027 §Decision.3) ---
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

# --- Step 4: rollback (ADR-0027 §Decision.3 auto-rollback) ---
log "Smoke test FAILED after $SMOKE_ATTEMPTS attempts; rolling back to HEAD@{1}"
git reset --hard HEAD@{1}
log "Restarting atilcalc-web.service after rollback"
systemctl --user restart atilcalc-web.service

# --- Step 5: retry smoke test once; if this ALSO fails, page owner ---
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
  "$notify_path" -l human "[DEPLOY] Prod rollback FAILED on $HOSTNAME — manual intervention required. Expected SHA=$GITHUB_SHA. See workflow: $GITHUB_SHA" || true
else
  log "WARN: $notify_path not found or not executable; cannot page owner via notify.sh"
fi
exit 2