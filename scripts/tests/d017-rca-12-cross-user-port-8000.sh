#!/usr/bin/env bash
# d017-rca-12-cross-user-port-8000.sh — regression test for Issue #168
# (RCA-12 — 8th auto-deploy after PR #165 merge FAILED at run #27865086173
# because deploy-runner.sh restart_service() called `pkill -f 'uvicorn.*atilcalc'`
# with `|| true` (silent on cross-user no-op), and the post-restart check
# was `ps aux | grep uvicorn | grep -v grep` (matches ANY uvicorn, not port-aware).
# The pre-existing atilcan-owned uvicorn (PID 33353, started 05:02 manual unblock,
# bind to port 8000) stayed up because runner (user gh-actions-runner) cannot
# kill a process owned by a different user without sudo. Runner's nohup-spawned
# uvicorn tried to bind port 8000, failed. Smoke test curled 127.0.0.1:8000 →
# hit atilcan's uvicorn → git_sha mismatch (got=e13407d9, want=540deffe=PR #165
# merge) → rollback → exit 1.)
#
# Bug class defended against (RCA-12 root cause):
#   - Cross-user process kill silently no-ops (pkill -f ... || true)
#   - Lenient post-restart check (ps aux | grep — not port-aware, returns
#     success when ANY uvicorn is running, even if it's the wrong one)
#   - No detection of which uvicorn is actually bound to ATC_PORT
#
# v8 fix (proposed):
#   - Pre-restart: ss -tlnp "sport = :$ATC_PORT" → check owner uid; if different
#     from current uid, fail with exit 5 (cross-user port conflict)
#   - Post-restart: capture new uvicorn PID via $!; ss -tlnp sport = :$ATC_PORT
#     → verify new PID owns the port; else fail with exit 6 (PID mismatch)
#   - New exit codes: 5 = cross-user port conflict, 6 = post-restart PID mismatch
#   - Header comment documents RCA-12 + new exit codes 5 + 6
#
# Test cases (T1..T8) — verify v8 fix is in place:
#   T1: pre-restart port-owner check uses `ss -tlnp`
#   T2: pre-restart cross-user check fails with exit 5
#   T3: post-restart check uses `ss -tlnp` (port-aware, not just ps)
#   T4: post-restart PID-mismatch check fails with exit 6
#   T5: header documents RCA-12 + exit codes 5 + 6
#   T6: --dry-run step 4 line mentions RCA-12
#   T7: pre-check is BEFORE pkill in source order (line order matters for fix)
#   T8: pkill `|| true` is supplemented by strict port-owner check (no silent
#       cross-user no-op — fails with exit 5 first)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d017-rca-12-cross-user-port-8000.sh

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
# result matches a second pattern. Used to verify "pre-check is BEFORE pkill".
before_match() {
  local p1="$1"; local n="$2"; local p2="$3"
  grep -B "$n" -m 1 -E "$p1" "$RUNNER_SH" | grep -Eq "$p2"
}

# ============================================================================
# Test cases T1..T8
# ============================================================================

section "T1: pre-restart port-owner check uses 'ss -tlnp' (or lsof -i) — RCA-12 detection"
# The pre-check must use a port-aware tool to find the owner of port $ATC_PORT.
# `ps aux | grep uvicorn` is NOT port-aware (RCA-12 root cause).
# Pattern: must reference `ss -tlnp` OR `lsof -i` somewhere in the
# restart_service() function (or just before it).
if grep -Eq 'ss -tlnp|lsof -i' "$RUNNER_SH"; then
  pass "port-aware tool (ss -tlnp or lsof -i) is present (RCA-12 detection)"
else
  fail "port-aware tool missing" "expected 'ss -tlnp' or 'lsof -i' in deploy-runner.sh (RCA-12 detection — ps aux | grep uvicorn is not port-aware)"
fi

section "T2: pre-restart cross-user check fails with exit code 5 (new RCA-12 exit code)"
# Pattern: the pre-check must use a `fail ... 5` exit code when the port
# is occupied by a different user. This is the new exit code 5 (RCA-12).
# Per header (line 119-121), existing exit codes are 0,1,2,3,4 — exit 5 is
# reserved for the new cross-user conflict case.
if grep -Eq 'fail .* 5\)' "$RUNNER_SH" || grep -Eq 'fail ".*" 5' "$RUNNER_SH" \
   || grep -Eq 'fail .*cross-user.* 5' "$RUNNER_SH"; then
  pass "cross-user conflict fails with exit 5 (RCA-12 new exit code)"
else
  fail "no 'fail ... 5' for cross-user conflict" "expected 'fail ... 5' pattern in deploy-runner.sh (RCA-12: new exit code 5 = cross-user port conflict)"
fi

section "T3: post-restart check uses 'ss -tlnp' (port-aware, not just ps aux | grep uvicorn)"
# The lenient `ps aux | grep uvicorn | grep -v grep` check returns success
# for ANY uvicorn process — even one owned by a different user on port 8000.
# The fix replaces this with a port-aware check that verifies the new PID
# owns port $ATC_PORT.
# Pattern: somewhere in the post-restart region (after the new uvicorn is
# spawned), there must be an `ss -tlnp` check, AND the lenient `ps aux |
# grep uvicorn | grep -v grep` must be either removed or no longer the
# primary post-check.
# Extract the restart_service() function body:
restart_body=$(awk '/^restart_service\(\)/,/^}/' "$RUNNER_SH")
if printf '%s' "$restart_body" | grep -Eq 'ss -tlnp'; then
  pass "post-restart check uses 'ss -tlnp' (port-aware, strict)"
else
  fail "post-restart check missing 'ss -tlnp'" "expected 'ss -tlnp' in restart_service() post-restart region (RCA-12: replace lenient 'ps aux | grep uvicorn' with port-aware check)"
fi

section "T4: post-restart PID-mismatch check fails with exit code 6 (new RCA-12 exit code)"
# Pattern: when the post-restart port-owner check reveals a different PID
# (not the just-spawned uvicorn), the script must fail with exit 6.
# This is the new exit code 6 (RCA-12).
if grep -Eq 'fail .* 6\)' "$RUNNER_SH" || grep -Eq 'fail ".*" 6' "$RUNNER_SH" \
   || grep -Eq 'fail .*PID mismatch.* 6' "$RUNNER_SH" \
   || grep -Eq 'fail .*post-restart.* 6' "$RUNNER_SH"; then
  pass "post-restart PID-mismatch fails with exit 6 (RCA-12 new exit code)"
else
  fail "no 'fail ... 6' for post-restart PID mismatch" "expected 'fail ... 6' pattern in deploy-runner.sh (RCA-12: new exit code 6 = post-restart PID mismatch)"
fi

section "T5: header comment documents RCA-12 + exit codes 5 + 6"
# Pattern: the header comment block must mention RCA-12 and document the
# new exit codes 5 (cross-user) and 6 (PID mismatch).
if grep -Eq 'RCA-12' "$RUNNER_SH" \
   && grep -Eq 'exit code 5' "$RUNNER_SH" \
   && grep -Eq 'exit code 6' "$RUNNER_SH"; then
  pass "header documents RCA-12 + exit codes 5 + 6"
else
  fail "header missing RCA-12 + exit code documentation" "expected 'RCA-12' AND 'exit code 5' AND 'exit code 6' in deploy-runner.sh header comment"
fi

section "T6: --dry-run step 4 line mentions RCA-12 + cross-user check"
# Pattern: the --dry-run section's step 4 (restart) line should reference
# RCA-12 and the cross-user port-owner check.
if grep -Eq 'step 4:.*RCA-12' "$RUNNER_SH"; then
  pass "dry-run step 4 line references RCA-12"
else
  fail "dry-run step 4 line does not reference RCA-12" "expected 'step 4: ... RCA-12 ...' in --dry-run output of deploy-runner.sh"
fi

section "T7: pre-check is BEFORE systemctl --user stop in source order (line order matters for RCA-12 fix)"
# Pattern: the port-owner pre-check must be executed BEFORE the actual
# `systemctl --user stop atilcalc-web.service` command (the v9 spawn gate).
# v9 has TWO occurrences of the systemctl stop string: (1) the canonical
# pattern in the header comment (line ~142), and (2) the actual function
# body call (line ~416). We anchor on the function-body call by requiring
# the `if !` prefix (only the actual code has this). The window is 30
# lines to span from the pre-check (~line 404) up to the spawn gate.
if before_match "if ! systemctl --user stop atilcalc-web\\.service" 30 'fail .* 5'; then
  pass "port-owner pre-check (fail ... 5) appears before systemctl --user stop (correct line order, v9 function-body anchor)"
else
  fail "port-owner pre-check NOT before systemctl --user stop (function-body)" "expected a 'fail ... 5' line to appear within 30 lines BEFORE 'if ! systemctl --user stop atilcalc-web.service' (the function-body call, not the comment anchor) in deploy-runner.sh (RCA-12: pre-check must fail-fast before v9 spawn gate)"
fi

section "T8: systemctl --user stop supplemented by strict port-owner check (no silent cross-user no-op)"
# Pattern: the silent cross-user no-op is the RCA-12 anti-pattern. v9
# replaces pkill with `systemctl --user stop atilcalc-web.service`, but
# the strict pre-check (fail ... 5) must still appear BEFORE the spawn
# gate. Test verifies all of:
#   (a) ss -tlnp pattern (T1) is still present
#   (b) fail ... 5 pattern (T2) is still present
#   (c) the pre-check (ss -tlnp) is before the function-body spawn gate
# This is the consolidated RCA-12 fix check, updated for the v9 spawn shape.
if grep -Eq 'ss -tlnp' "$RUNNER_SH" \
   && (grep -Eq 'fail .* 5' "$RUNNER_SH") \
   && before_match "if ! systemctl --user stop atilcalc-web\\.service" 35 'ss -tlnp'; then
  pass "RCA-12 fix is consolidated: ss -tlnp + fail ... 5 pre-check before systemctl --user stop (v9 function-body anchor)"
else
  fail "RCA-12 fix not consolidated for v9" "expected all of: (a) 'ss -tlnp' pattern, (b) 'fail ... 5' pattern, (c) pre-check (ss -tlnp) before 'if ! systemctl --user stop atilcalc-web.service' (function-body) in source order (defense-in-depth, v9 spawn gate anchor)"
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
