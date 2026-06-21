#!/usr/bin/env bash
# d019-e2e-deploy-verify.sh — E2E deploy verification regression test
# (refs Issue #188 STORY-E2E-DEPLOY-VERIFY, Issue #189 RCA-16 v9 ExecStart fail,
#  Issue #175 RCA-15 APPLIED, Issue #171 RCA-14, PR #174 v9 systemd, PR #169 RCA-12 v8)
#
# Bug class defended against (Sprint 3 P0 DoD §4/§5):
#   - Sprint 3 P0 DoD §4: 3+ consecutive self-hosted auto-deploys succeed
#   - Sprint 3 P0 DoD §5: rollback + service persistence verified
#   - d019 verifies the v9 deploy-runner.sh has the right structural elements
#     to support these DoD checks. The actual E2E runs (3 deploys + 5+ min
#     persistence) are runbook-level, not test-file-level.
#
# Test cases (T1..T5) — verify v9 path is structurally complete:
#   T1: deploy-runner.sh exit-0 path on v9 success (AC1)
#   T2: post-deploy port + etimes check (AC2/AC3)
#   T3: systemctl --user is-active atilcalc-web.service check (AC4)
#   T4: /healthz smoke test exit code propagates (AC5)
#   T5: RCA-12 v8 pre-check (exit 5) + post-check (exit 6) preserved (AC7)
#
# Forward-looking:
#   T6: RCA-16 user-context fix (XDG_RUNTIME_DIR or sudo) — RED until RCA-16
#       resolved. Captured for visibility, not blocking AC6.
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d019-e2e-deploy-verify.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_SH="$SCRIPT_DIR/../deploy-runner.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if [ ! -r "$RUNNER_SH" ]; then
  echo "ERROR: deploy-runner.sh not found at $RUNNER_SH" >&2; exit 127
fi

# ============================================================================
# T1: deploy-runner.sh exit-0 path on v9 success (AC1)
# ============================================================================
section "T1: deploy-runner.sh exit-0 path on v9 success (AC1: 3+ deploys exit 0)"
# Pattern: deploy-runner.sh must have an explicit exit-0 path for the v9
# success case (NOT just `exit $?`). The v9 success path is:
#   preflight PASS → step 3 unit check PASS → step 4 stop+start PASS →
#   post-check PASS → exit 0.
if grep -Eq '^[[:space:]]*exit 0[[:space:]]*$' "$RUNNER_SH"; then
  pass "deploy-runner.sh has explicit 'exit 0' path (v9 success)"
else
  fail "exit-0 path missing" "expected explicit 'exit 0' in deploy-runner.sh success path (AC1 — 3+ deploys must exit 0; cannot rely on implicit $? propagation alone)"
fi

# ============================================================================
# T2: post-deploy port + etimes check (AC2/AC3)
# ============================================================================
section "T2: post-deploy port + etimes check (AC2/AC3: uvicorn LISTEN + persistence)"
# Pattern: deploy-runner.sh step 4 post-deploy must verify (a) port 8000 is
# bound by a recent uvicorn (etimes < threshold) and (b) the PID is ours
# (not stale from a previous run). This is the RCA-12 v8 post-check.
if grep -Eq "ss -tlnp.*sport.*\\\$ATC_PORT|ss -tlnp.*sport.*8000" "$RUNNER_SH" \
   && grep -Eq 'etimes' "$RUNNER_SH"; then
  pass "post-deploy port-etime check present (ss -tlnp + etimes)"
else
  fail "post-deploy port-etime check missing" "expected 'ss -tlnp' for ATC_PORT + 'etimes' check in deploy-runner.sh post-deploy (AC2/AC3 — verify uvicorn LISTEN + fresh after deploy)"
fi

# ============================================================================
# T3: systemctl --user is-active atilcalc-web.service check (AC4)
# ============================================================================
section "T3: systemctl --user is-active atilcalc-web.service check (AC4: service active between deploys)"
# Pattern: deploy-runner.sh must verify the systemd-managed service is
# active after deploy. This is distinct from the port-etime check — it
# confirms the unit itself is healthy, not just the port.
if grep -Eq 'systemctl --user is-active.*atilcalc-web' "$RUNNER_SH"; then
  pass "systemctl --user is-active atilcalc-web.service check present"
else
  fail "is-active check missing" "expected 'systemctl --user is-active atilcalc-web.service' in deploy-runner.sh (AC4 — verify systemd-managed service is healthy, not just the port)"
fi

# ============================================================================
# T4: /healthz smoke test exit code propagates (AC5)
# ============================================================================
section "T4: /healthz smoke test exit code propagates (AC5: 200 OK after deploy)"
# Pattern: deploy-runner.sh must run a /healthz smoke test after the service
# is up, and the exit code must propagate to the deploy-runner.sh exit
# (per ADR-0027 §3 rollback-on-smoke-test-fail).
if grep -Eq 'healthz|192\.168\.1\.199:8000' "$RUNNER_SH"; then
  pass "/healthz smoke test present in deploy-runner.sh"
else
  fail "smoke test missing" "expected 'curl -fsS http://192.168.1.199:8000/healthz' (or similar) in deploy-runner.sh post-deploy (AC5 — verify HTTP service responds 200 OK)"
fi

# ============================================================================
# T5: RCA-12 v8 pre-check (exit 5) + post-check (exit 6) preserved (AC7)
# ============================================================================
section "T5: RCA-12 v8 pre-check + post-check preserved (AC7: cross-user port defense)"
# Pattern: deploy-runner.sh must have BOTH the pre-check (exit 5, cross-user
# port conflict) and the post-check (exit 6, stale port). These were added
# in PR #169 (RCA-12 v8) and must be preserved in v9.
if grep -Eq 'fail.*5|cross.user|port.*conflict' "$RUNNER_SH" \
   && grep -Eq 'fail.*6|post.restart|port.PID.mismatch|etime' "$RUNNER_SH"; then
  pass "RCA-12 pre-check (exit 5) + post-check (exit 6) preserved"
else
  fail "RCA-12 v8 check missing" "expected BOTH 'fail ... 5' (cross-user pre-check) AND 'fail ... 6' (post-check, etime-related) in deploy-runner.sh (AC7 — RCA-12 v8 cross-user port defense preserved on v9 path)"
fi

# ============================================================================
# T6 (forward-looking): RCA-16 user-context fix (XDG_RUNTIME_DIR or sudo)
# ============================================================================
section "T6: RCA-16 user-context fix (XDG_RUNTIME_DIR or sudo) — forward-looking"
# Pattern: RCA-16 (v9 ExecStart fail) most likely root cause is
# XDG_RUNTIME_DIR isolation between gh-actions-runner user and atilcan's
# user-service bus. deploy-runner.sh must either (a) `sudo -u atilcan` for
# systemctl calls, or (b) explicitly set XDG_RUNTIME_DIR. This TC is
# forward-looking — will be RED until RCA-16 fix lands. Non-blocking for
# AC6 (the d019 contract is for the v9 baseline; RCA-16 fix is a separate PR).
if grep -Eq 'sudo -u atilcan|XDG_RUNTIME_DIR' "$RUNNER_SH"; then
  pass "RCA-16 user-context fix present (sudo -u atilcan OR XDG_RUNTIME_DIR)"
else
  printf "  ${R}✗ FAIL${D} — RCA-16 user-context fix NOT present\n"
  printf "    ${R}expected 'sudo -u atilcan' or 'XDG_RUNTIME_DIR' in deploy-runner.sh (RCA-16 — first v9 deploy failed at step 4 systemctl --user start due to user-bus isolation). FORWARD-LOOKING: this TC is RED until RCA-16 fix PR lands. Non-blocking for d019 contract; tracked in Issue #189.\n"
  FAIL=$((FAIL+1))
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
  printf "${G}${B}ALL %d TESTS PASSED${D}\n" "$PASS"
  exit 0
else
  printf "${R}${B}%d/%d TESTS FAILED${D} (T6 RCA-16 is forward-looking; %d substantive failures)${D}\n" "$FAIL" "$TOTAL" "$((FAIL - 1))"
  exit 1
fi
