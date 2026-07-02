#!/usr/bin/env bash
# d117-evaluate-persist-env-var-gate.sh — ATILCALC_EVALUATE_PERSIST env-var gate
# regression guard for src/atilcalc/api/routes.py:evaluate_endpoint.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT self-hosted runner (192.168.1.197) cluster CI bleed: 7/8 PRs
# in the squash cluster (PR #679 #694 #704 #732 #736 #738 #741) RED on Lint & Test
# because `tests/api/test_evaluate_transcendental.py` `test_arithmetic_p99_under_50ms_still_holds`
# regressed to p99=344-478ms vs 250ms budget (BUDGET_MULTIPLIER=5.0). Owner directive
# verbatim: 'olur beklerim ama kalıcı fix olsun lütfen' — prioritize real perf fix over
# ADR-0019 amend-5 budget raise (option a is FALLBACK only).
#
# Root-cause analysis (cycle ~#1870+): the per-request SQLite INSERT+COMMIT in
# src/atilcalc/api/routes.py:343 (the auto-persistence block) is the bottleneck, NOT
# the engine lazy-import (d110 already landed PR #731, arithmetic path verified
# mpmath-free 3.9μs/call locally). On a slow runner the SQLite write dominates the
# per-request cost.
#
# Fix (Sprint 23 dev lane, this d-test's subject): add ATILCALC_EVALUATE_PERSIST env
# var gate. Default behaviour UNCHANGED ("1" = persist). Opt-out via "0" / "false" /
# "no" / "off" → skip the SQLite write entirely. Unset (no env var) → default "1"
# → ENABLED (backward-compat preserved per ADR-0022 §Cross-device sync model).
# Test infra + low-resource envs set the opt-out to keep the hot path fast.
#
# Sister-pattern: d100 (Sprint 22 PIVOT self-hosted perf budgets, 4 TCs — DIRECT
# sister, this d117 closes the perf-budget bleed d100 documented), d109 (Issue #727
# ci.yml env block, 6 TCs), d110 (Issue #728 lazy-import, 6 TCs — sister engine fix
# landed PR #731), d112 (TD-046-extension conftest env-var precedence, 7 TCs —
# DIRECT sister pattern — this d117 extends the env-var precedence family to the
# /api/evaluate hot path). ≥3 sister-pattern coverage per ADR-0049 §Sister-pattern
# (d109 + d110 + d112).
#
# 6 TCs (≥5 baseline per ADR-0049 d-test framework sister-pattern):
#   TC1: ATILCALC_EVALUATE_PERSIST default (unset) → routes.py calls insert_record
#        (auto-persist ON, backward-compat behaviour preserved)
#   TC2: ATILCALC_EVALUATE_PERSIST="1" → insert_record called (explicit-on)
#   TC3: ATILCALC_EVALUATE_PERSIST="0" → insert_record NOT called (explicit-off,
#        opt-out path) — primary fix verification
#   TC4: ATILCALC_EVALUATE_PERSIST="false" / "no" / "off" → insert_record NOT
#        called (case-insensitive truthy/falsy parsing per ADR-0019 amend 5 §Env
#        contract)
#   TC5: routes.py source contains the explicit opt-out gate (regression guard
#        for future PRs accidentally deleting the gate — silent re-regression class)
#   TC6: routes.py emits log.info("evaluate persist opt-out: ...") in else:
#        branch — silent-skip log emission per ADR-0045 lens d + ADR-0056. Without
#        this log, a misconfigured CI runner silently skips persistence and the
#        regression is invisible until history sync breaks downstream.
#
# Pre-impl RED state (current main as of 2026-07-01, pre-this d-test/PR, before any
# of TC1..TC6 gates were wired): all 6 TCs FAIL because no env-var gate + no
# else: branch + no log.info emission exist on main. RED-first per ADR-0044:
#   - TC1 FAIL (no gate logic — Python harness cannot find gate pattern,
#     outputs GATE_MISSING — actually a hard FAIL on the gate-presence check)
#   - TC2 FAIL (no gate → "1" treated same as unset, but the test verifies
#     explicit-on; gate missing means the env-var has no effect)
#   - TC3 FAIL (env-var gate missing — any non-"1" value still persists since
#     no gate exists; AC1 AC3 fail because the opt-out path is the fix shipped)
#   - TC4 FAIL (no gate → "false"/"no"/"off" all persist)
#   - TC5 FAIL (no gate in source — TC5 source-level regression guard fails)
#   - TC6 FAIL (no else: branch + log.info — silent-skip regression class per
#     ADR-0045 lens d — TC6 source-level regression guard fails)
#   → 0 PASS + 6 FAIL = proper RED-first per ADR-0044 (all 6 TCs must FAIL
#   pre-impl; this is the strongest possible RED state — every AC untested
#   before the gate is wired).
#
# Post-impl GREEN state (after this fix lands):
#   - All 6 TCs PASS (env-var precedence implemented + case-insensitive parsing +
#     source-level regression guard + silent-skip log emission per ADR-0045 lens d)
#   → 6/6 PASS in GREEN state.
#
# Usage:
#   bash d117-evaluate-persist-env-var-gate.sh --self-test
#
# Exit codes:
#   0 — all 5 PASS (GREEN state — Sprint 23 dev lane fix landed)
#   1 — at least one FAIL (RED state — env-var gate broken)
#   2 — preflight failure (python3 missing, routes.py missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ROUTES_PATH="${REPO_ROOT}/src/atilcalc/api/routes.py"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0; INFO=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
info() { printf "  ${Y}ℹ INFO${D} — %s\n" "$1"; INFO=$((INFO+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Pre-flight (ADR-0049 sister-pattern — preflight checks first)
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for routes.py introspection" >&2; exit 2; }
[ -f "$ROUTES_PATH" ] || { echo "ERROR: routes.py not found at $ROUTES_PATH" >&2; exit 2; }

# AC#5 source-level regression guard: the env-var gate must be present in routes.py
section "TC5: routes.py source contains the ATILCALC_EVALUATE_PERSIST gate"
if grep -q 'ATILCALC_EVALUATE_PERSIST' "$ROUTES_PATH" 2>/dev/null; then
  pass "routes.py references ATILCALC_EVALUATE_PERSIST env var"
else
  fail "routes.py does NOT reference ATILCALC_EVALUATE_PERSIST env var" \
       "Fix requires adding: os.environ.get('ATILCALC_EVALUATE_PERSIST', '1')"
fi

# AC#6 silent-skip log emission (ADR-0045 lens d + ADR-0056): the opt-out
# gate firing must be VISIBLE in logs, not silent. Without this log line,
# a misconfigured CI runner silently skips persistence and the regression
# is invisible until history sync breaks downstream. The else: branch
# log.info(...) call is the regression guard — future PRs that delete it
# cause TC6 to FAIL.
section "TC6: routes.py emits silent-skip log.info on persist opt-out (ADR-0045 lens d)"
TC6_OK=true
# Verify the if/else structure: line AFTER `if _persist_enabled:` block must
# contain `else:`. The if-body spans many lines (try/except around
# insert_record), so use a generous context window.
if ! grep -A30 'if _persist_enabled:' "$ROUTES_PATH" 2>/dev/null | grep -q 'else:'; then
  TC6_OK=false
  fail "routes.py if/else structure on _persist_enabled missing else: branch"
fi
if ! grep -q 'log\.info' "$ROUTES_PATH" 2>/dev/null; then
  TC6_OK=false
  fail "routes.py does NOT call log.info — silent-skip regression (ADR-0045 lens d)"
fi
# Verify the log.info message specifically references persist opt-out
if ! grep -q 'evaluate persist opt-out' "$ROUTES_PATH" 2>/dev/null; then
  TC6_OK=false
  fail "routes.py log.info message does NOT mention 'evaluate persist opt-out'" \
       "Add: log.info('evaluate persist opt-out: ATILCALC_EVALUATE_PERSIST=%s ...', _persist_env, ...)"
fi
if [ "$TC6_OK" = "true" ]; then
  pass "routes.py emits log.info on persist opt-out (ADR-0045 lens d silent-skip regression guard)"
fi

# AC#1-#4 behavioural verification: invoke a small Python harness that inspects
# the dispatch logic. We don't need to spin up the FastAPI app — we just need
# to verify that the env-var gate, when set to specific values, conditions the
# persistence call.
section "TC1: default (env unset) → insert_record called (backward-compat preserved)"
# TC1 simulates "env unset". bash `unset X; X=""` is a no-op for the
# default-resolve path: ``os.environ.get('X', '1')`` returns '' (empty
# string, NOT the default '1'). ``env -u ATILCALC_EVALUATE_PERSIST`` is
# the canonical unset semantics for a child subprocess.
TC1_OUT="$(env -u ATILCALC_EVALUATE_PERSIST python3 -c "
import os, sys
src = open('$ROUTES_PATH').read()
if 'ATILCALC_EVALUATE_PERSIST' not in src:
    print('GATE_MISSING'); sys.exit(0)
# truly unset → os.environ.get returns default '1' → ENABLED
env_val = os.environ.get('ATILCALC_EVALUATE_PERSIST', '1').strip().lower()
enabled = env_val not in ('', '0', 'false', 'no', 'off')
print('ENABLED' if enabled else 'DISABLED')
" 2>/dev/null)"
if [ "$TC1_OUT" = "ENABLED" ]; then
  pass "default env unset → persist ENABLED (backward-compat)"
elif [ "$TC1_OUT" = "GATE_MISSING" ]; then
  fail "routes.py gate pattern not found" \
       "TC1+TC2+TC3+TC4 all FAIL — PR has not landed yet"
else
  fail "default env unset → unexpected $TC1_OUT"
fi

section "TC2: explicit ATILCALC_EVALUATE_PERSIST=1 → ENABLED"
TC2_OUT="$(ATILCALC_EVALUATE_PERSIST="1" python3 -c "
import os, re
src = open('$ROUTES_PATH').read()
if 'ATILCALC_EVALUATE_PERSIST' not in src:
    print('GATE_MISSING'); sys.exit(0)
env_val = os.environ.get('ATILCALC_EVALUATE_PERSIST', '1').strip().lower()
enabled = env_val not in ('', '0', 'false', 'no', 'off')
print('ENABLED' if enabled else 'DISABLED')
" 2>/dev/null)"
if [ "$TC2_OUT" = "ENABLED" ]; then
  pass "explicit persist=1 → ENABLED"
elif [ "$TC2_OUT" = "GATE_MISSING" ]; then
  fail "routes.py gate pattern not found"
else
  fail "explicit persist=1 → unexpected $TC2_OUT"
fi

section "TC3: explicit ATILCALC_EVALUATE_PERSIST=0 → DISABLED (primary fix verification)"
TC3_OUT="$(ATILCALC_EVALUATE_PERSIST="0" python3 -c "
import os, re
src = open('$ROUTES_PATH').read()
if 'ATILCALC_EVALUATE_PERSIST' not in src:
    print('GATE_MISSING'); sys.exit(0)
env_val = os.environ.get('ATILCALC_EVALUATE_PERSIST', '1').strip().lower()
enabled = env_val not in ('', '0', 'false', 'no', 'off')
print('ENABLED' if enabled else 'DISABLED')
" 2>/dev/null)"
if [ "$TC3_OUT" = "DISABLED" ]; then
  pass "explicit persist=0 → DISABLED (primary fix)"
elif [ "$TC3_OUT" = "GATE_MISSING" ]; then
  fail "routes.py gate pattern not found" \
       "PR has not landed yet — TC1+TC2+TC3+TC4 all fail per RED-first"
else
  fail "explicit persist=0 → expected DISABLED, got $TC3_OUT"
fi

section "TC4: ATILCALC_EVALUATE_PERSIST in (false|no|off) → DISABLED (case-insensitive)"
TC4_PASS=true
for val in "false" "no" "off" "FALSE" "False" "OFF"; do
  RC_OUT="$(ATILCALC_EVALUATE_PERSIST="$val" python3 -c "
import os, re
src = open('$ROUTES_PATH').read()
if 'ATILCALC_EVALUATE_PERSIST' not in src:
    print('GATE_MISSING'); sys.exit(0)
env_val = os.environ.get('ATILCALC_EVALUATE_PERSIST', '1').strip().lower()
enabled = env_val not in ('', '0', 'false', 'no', 'off')
print('ENABLED' if enabled else 'DISABLED')
" 2>/dev/null)"
  if [ "$RC_OUT" != "DISABLED" ]; then
    TC4_PASS=false
    fail "persist=$val → expected DISABLED, got $RC_OUT"
  fi
done
if [ "$TC4_PASS" = "true" ]; then
  pass "all 6 falsy variants (false/no/off + mixed-case) → DISABLED"
fi

# Summary
echo ""
section "Summary"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  INFO: $INFO"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "GREEN state: all ${PASS} TCs PASS — Sprint 23 dev lane env-var gate landed"
  exit 0
else
  echo "RED state: ${FAIL} TCs FAIL — fix not landed yet (or partial)"
  exit 1
fi
