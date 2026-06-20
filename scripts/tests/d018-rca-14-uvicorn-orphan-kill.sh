#!/usr/bin/env bash
# d018-rca-14-uvicorn-orphan-kill.sh — regression test for Issue #171
# (RCA-14 — uvicorn killed by GH Actions runner cleanup phase; prod page
# inaccessible between deploys after Sprint 3 P0 DoD §4 = 3/3 PASS).
#
# Bug class defended against (RCA-14 root cause):
#   - deploy-runner.sh v8 spawns uvicorn via `nohup setsid` — but the
#     self-hosted runner's "Cleanup orphan processes" step at job end
#     terminates it: "Complete job  Terminate orphan process: pid (47805) (uvicorn)"
#   - Result: deploy succeeds (smoke test pass), but service does NOT
#     persist between deploys. http://192.168.1.199:8000/ goes dead as
#     soon as the runner job ends.
#   - Sprint 3 P0 trade-off: for P0 unblock we disabled atilcalc-web.service
#     (Option A: deploy-runner.sh sole manager) to keep the RCA-12 v8 fix
#     surface minimal. This trade-off is now biting.
#
# v9 fix (proposed):
#   - Pre-deploy: `systemctl --user stop atilcalc-web.service` (clean shutdown)
#   - Update code + run preflight
#   - Post-deploy: `systemctl --user start atilcalc-web.service`
#   - uvicorn lifecycle now owned by systemd user-service (ADR-0010)
#   - Logout-survivable via `loginctl enable-linger atilcan` (owner pre-req)
#   - Restart-on-fail via unit's `Restart=always` directive
#   - New exit code 7 = systemd integration failure (unit not registered,
#     not enabled, etc.) — fail-loud, not silent
#
# Test cases (T1..T9) — verify v9 fix is in place:
#   T1: pre-deploy `systemctl --user stop atilcalc-web.service` call exists
#   T2: post-deploy `systemctl --user start atilcalc-web.service` call exists
#   T3: nohup+setsid canonical pattern is REPLACED (not just supplemented)
#   T4: header documents RCA-14 + orphan-kill scenario + new exit code 7
#   T5: --dry-run step 4 line references systemctl + atilcalc-web.service
#   T6: pre-check happens BEFORE systemctl stop in source order
#   T7: post-check happens AFTER systemctl start in source order
#   T8: new exit code 7 for systemd integration failure
#   T9: header references owner pre-req (`loginctl enable-linger atilcan`)
#       and ADR-0010 (systemd user-service contract)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d018-rca-14-uvicorn-orphan-kill.sh

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

# Helper: extract N lines after the FIRST match of a pattern, and check that
# result matches a second pattern. Avoids awk's quoting hell with `2>&1`.
after_match() {
  local p1="$1"; local n="$2"; local p2="$3"
  grep -A "$n" -m 1 -E "$p1" "$RUNNER_SH" | grep -Eq "$p2"
}

# Helper: extract N lines BEFORE the FIRST match of a pattern, and check that
# result matches a second pattern. Used to verify source order.
before_match() {
  local p1="$1"; local n="$2"; local p2="$3"
  grep -B "$n" -m 1 -E "$p1" "$RUNNER_SH" | grep -Eq "$p2"
}

# ============================================================================
# Test cases T1..T9
# ============================================================================

section "T1: pre-deploy 'systemctl --user stop atilcalc-web.service' call exists (RCA-14 detection)"
# The pre-deploy must call `systemctl --user stop atilcalc-web.service` to
# cleanly shut down the service before code update. This is the entry point
# of the systemd integration; without it, the old nohup-spawned uvicorn
# could still be bound to the port and the new uvicorn would fail to bind.
if grep -Eq 'systemctl --user stop atilcalc-web\.service' "$RUNNER_SH"; then
  pass "pre-deploy systemctl --user stop atilcalc-web.service call is present (RCA-14 detection)"
else
  fail "pre-deploy systemctl --user stop missing" "expected 'systemctl --user stop atilcalc-web.service' in deploy-runner.sh (RCA-14: pre-deploy must stop service before code update)"
fi

section "T2: post-deploy 'systemctl --user start atilcalc-web.service' call exists"
# The post-deploy must call `systemctl --user start atilcalc-web.service` to
# start the service under systemd management. The unit's ExecStart spawns
# uvicorn; the service now persists beyond the runner's "Cleanup orphan
# processes" phase because it's owned by the atilcan user session (not the
# runner job process tree).
if grep -Eq 'systemctl --user start atilcalc-web\.service' "$RUNNER_SH"; then
  pass "post-deploy systemctl --user start atilcalc-web.service call is present"
else
  fail "post-deploy systemctl --user start missing" "expected 'systemctl --user start atilcalc-web.service' in deploy-runner.sh (RCA-14: post-deploy must start service under systemd, not nohup)"
fi

section "T3: nohup+setsid canonical pattern is REPLACED (not just supplemented)"
# The v8 nohup+setsid pattern was the source of the RCA-14 bug (runner kills
# orphan processes at job end). v9 must REPLACE this pattern, not just
# supplement it with systemctl calls. Otherwise the nohup-spawned uvicorn
# still gets killed by the runner cleanup, and the systemd-managed one
# might race with it for the port.
# Pattern: `nohup setsid` followed by `uvicorn` within ~3 lines (the
# canonical multi-line spawn shape in v8). Detection works across the
# whole file, not just restart_service() (in v9 the function might be
# inlined into the main flow, or replaced with a different function name).
if grep -A 3 -E 'nohup setsid' "$RUNNER_SH" 2>/dev/null | grep -Eq 'uvicorn'; then
  fail "nohup setsid uvicorn pattern still present (within 3 lines of 'nohup setsid')" "expected 'nohup setsid' NOT to be followed by 'uvicorn' within 3 lines (RCA-14: pattern is the source of the orphan-kill bug; v9 replaces with systemctl --user)"
else
  pass "nohup+setsid uvicorn pattern is REPLACED in deploy-runner.sh (RCA-14 source removed)"
fi

section "T4: header documents RCA-14 + orphan-kill scenario + new exit code 7"
# Pattern: the header comment block must mention RCA-14 (or #171) AND
# document the new exit code 7 (systemd integration failure).
if grep -Eq 'RCA-14|Issue #171' "$RUNNER_SH" \
   && grep -Eq 'exit code 7' "$RUNNER_SH"; then
  pass "header documents RCA-14 + exit code 7"
else
  fail "header missing RCA-14 + exit code 7 documentation" "expected 'RCA-14' (or 'Issue #171') AND 'exit code 7' in deploy-runner.sh header comment (RCA-14: new exit code 7 = systemd integration failure)"
fi

section "T5: --dry-run step 4 line references systemctl + atilcalc-web.service"
# Pattern: the --dry-run section's step 4 (restart) line should reference
# `systemctl` and `atilcalc-web.service`.
if grep -Eq 'step 4:.*systemctl.*atilcalc-web\.service' "$RUNNER_SH" \
   || grep -Eq 'step 4:.*atilcalc-web\.service.*systemctl' "$RUNNER_SH" \
   || grep -Eq 'step 4:.*RCA-14.*systemctl' "$RUNNER_SH"; then
  pass "dry-run step 4 line references systemctl + atilcalc-web.service"
else
  fail "dry-run step 4 line does not reference systemctl" "expected 'step 4: ... systemctl ... atilcalc-web.service ...' (or RCA-14) in --dry-run output of deploy-runner.sh"
fi

section "T6: RCA-12 pre-check happens BEFORE systemctl stop in source order"
# Pattern: the RCA-12 port-owner pre-check (lines 336-364 in v8) should
# still happen BEFORE the systemctl stop call in v9. The pre-check is
# defense-in-depth: if the port is held by a different user (cross-user
# scenario), the systemctl stop would fail anyway, but the pre-check
# gives a clearer error.
if before_match 'systemctl --user stop atilcalc-web\.service' 30 'ss -tlnp'; then
  pass "RCA-12 pre-check (ss -tlnp) appears before systemctl stop (correct line order)"
else
  fail "RCA-12 pre-check NOT before systemctl stop" "expected 'ss -tlnp' (or RCA-12 pre-check pattern) to appear within 30 lines BEFORE 'systemctl --user stop atilcalc-web.service' in deploy-runner.sh"
fi

section "T7: post-check happens AFTER systemctl start in source order"
# Pattern: the post-restart port-PID etimes check should happen AFTER the
# systemctl start call (the service starts → we verify the port-bound
# process is OUR uvicorn, not stale).
if after_match 'systemctl --user start atilcalc-web\.service' 50 'ss -tlnp'; then
  pass "post-check (ss -tlnp) appears after systemctl start (correct line order)"
else
  fail "post-check NOT after systemctl start" "expected 'ss -tlnp' to appear within 50 lines AFTER 'systemctl --user start atilcalc-web.service' in deploy-runner.sh"
fi

section "T8: new exit code 7 for systemd integration failure"
# Pattern: the script must fail with exit 7 when systemd integration fails
# (e.g., atilcalc-web.service not registered, not enabled, systemctl
# call returns non-zero). This is the new exit code (v9).
if grep -Eq 'fail .* 7\)' "$RUNNER_SH" \
   || grep -Eq 'fail ".*" 7' "$RUNNER_SH" \
   || grep -Eq 'fail .*systemd.* 7' "$RUNNER_SH" \
   || grep -Eq 'fail .*atilcalc-web.* 7' "$RUNNER_SH"; then
  pass "systemd integration failure fails with exit 7 (RCA-14 new exit code)"
else
  fail "no 'fail ... 7' for systemd integration failure" "expected 'fail ... 7' pattern in deploy-runner.sh (RCA-14: new exit code 7 = systemd integration failure)"
fi

section "T9: header references owner pre-req + ADR-0010 (systemd user-service contract)"
# Pattern: the header must mention the owner pre-req (loginctl enable-linger
# atilcan) and ADR-0010 (systemd user-service contract). The service cannot
# survive logout without linger, and the contract is documented in ADR-0010.
if grep -Eq 'enable-linger|loginctl' "$RUNNER_SH" \
   && grep -Eq 'ADR-0010' "$RUNNER_SH"; then
  pass "header references enable-linger/loginctl + ADR-0010 (systemd user-service contract)"
else
  fail "header missing enable-linger or ADR-0010 reference" "expected 'enable-linger' (or 'loginctl') AND 'ADR-0010' in deploy-runner.sh header comment (RCA-14: systemd user-service requires linger for logout-survival)"
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
  printf "${R}${B}%d/%d TESTS FAILED${D}\n" "$FAIL" "$TOTAL"
  exit 1
fi
