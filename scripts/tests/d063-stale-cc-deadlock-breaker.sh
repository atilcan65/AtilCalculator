#!/usr/bin/env bash
# d063-stale-cc-deadlock-breaker.sh — RETRO-011 §1 stale_cc regression guard
#
# Why this test exists
# --------------------
# RETRO-011 §1 (codification target) requires the agent-watch loop + claim-next-ready.sh
# to handle **stale cc:* labels** (label added >24h ago, no recent activity, OR label on
# a closed/merged PR) WITHOUT deadlocking the watcher. The stale_cc deadlock pattern
# was identified in cycle 478-481 Option D verdicts:
#
#   When an Issue/PR has stale `cc:*` labels pointing to an agent that has been
#   removed from the queue (no `agent:*` claim), the watcher can deadlock — both
#   the assignee and cc'd agent see stale queue entries, neither can claim, and
#   the workstream stalls until manual label flip.
#
# d063 is the regression guard for this doctrine. Sister-pattern to d062
# (proactive-board-scan-workstream, 6/6 TCs).
#
# 5 TCs (1 PASS baseline + 4 violation codifications, RED-first per ADR-0044).
# Pre-impl expected: 1 PASS (TC1 baseline) + 4 FAIL (TC2-TC5 violations).
# Post-impl expected: 5 PASS (all TCs green, stale_cc impl lands via RETRO-011 §1).
#
# Doctrine anchors:
# - RETRO-011 §1 NEW (stale_cc deadlock-breaker doctrinal home)
# - RETRO-011 §6 NEW (stale_cc wake classification sister-pattern, cycle 510)
# - RETRO-011 §8 NEW (Layer 5 reversal handler UNSTABLE state flake sister-pattern)
# - ADR-0038 §Work-Stream Awareness (work-stream-count semantics, sister-pattern d062)
# - ADR-0055 §1 Cadence Rule 1 atomic (d-test + INDEX.md entry in same PR)
# - ADR-0044 TDD RED contract
# - Issue #113 (label-authority doctrine, labels = ownership not body text)
# - Cycle 478-481 Option D (stale_cc verdict family)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WATCH_SCRIPT="${REPO_ROOT}/scripts/agent-watch.sh"
CLAIM_SCRIPT="${REPO_ROOT}/scripts/claim-next-ready.sh"

# TTY-aware color setup (sister-pattern to d062 + d058)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Preflight
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }
[ -f "$WATCH_SCRIPT" ] || { echo "ERROR: agent-watch.sh not found" >&2; exit 2; }
[ -f "$CLAIM_SCRIPT" ] || { echo "ERROR: claim-next-ready.sh not found" >&2; exit 2; }

# --- TC1: scripts exist + baseline invocation (PASS expected pre/post impl) ---
section "TC1: scripts exist + baseline invocation (PASS pre/post impl)"
if [ -x "$WATCH_SCRIPT" ] && [ -x "$CLAIM_SCRIPT" ]; then
  pass "TC1: agent-watch.sh + claim-next-ready.sh exist + executable"
else
  fail "TC1: scripts missing or not executable" "watch=$WATCH_SCRIPT claim=$CLAIM_SCRIPT"
fi

# --- TC2: stale_cc classification (FAIL pre-impl, PASS post-impl per RETRO-011 §1) ---
# Verifies that agent-watch.sh classifies stale cc:* (label added >24h ago OR on closed PR)
# as INFORMATIONAL not ACTIONABLE. Pre-impl: no classification logic, all wakes treated as
# ACTIONABLE → stale wakes pollute the queue. Post-impl: classification logic exists.
# Specific identifier patterns: stale_cc (snake_case) or is_stale_cc or freshness_check
section "TC2: stale_cc classification (RETRO-011 §1 doctrinal target)"
STALE_CC_CLASSIFIER="false"
if grep -qE "stale_cc|is_stale_cc|freshness_check|label_age|cc_freshness" "$CLAIM_SCRIPT" "$WATCH_SCRIPT" 2>/dev/null; then
  STALE_CC_CLASSIFIER="true"
fi
if [ "$STALE_CC_CLASSIFIER" = "true" ]; then
  pass "TC2: stale_cc classifier detected (freshness gate exists in watch/claim scripts)"
else
  fail "TC2: stale_cc classifier NOT implemented yet" "RETRO-011 §1 requires freshness gate (cycle 478-481 Option D); impl pending"
fi

# --- TC3: claim-next-ready.sh skips items with stale cc:* on closed upstream PR (FAIL pre-impl) ---
# Per RETRO-011 §1: when an issue/PR has stale cc:* pointing to a closed/merged PR,
# the watcher should NOT trigger an actionable wake. Pre-impl: no skip logic, all
# cc:* items processed regardless of upstream PR state.
# Specific identifier patterns: skip_stale_cc OR skip_closed_pr OR upstream_pr_state
section "TC3: claim-next-ready.sh skips items with stale cc:* on closed upstream PR"
STALE_CC_SKIP="false"
if grep -qE "skip_stale_cc|skip_closed_pr|upstream_pr_state|stale_cc_skip" "$CLAIM_SCRIPT" 2>/dev/null; then
  STALE_CC_SKIP="true"
fi
if [ "$STALE_CC_SKIP" = "true" ]; then
  pass "TC3: claim-next-ready.sh has stale_cc skip logic for closed upstream PR"
else
  fail "TC3: claim-next-ready.sh lacks stale_cc skip logic" "RETRO-011 §1 deadlock-breaker requires PR state check before claiming"
fi

# --- TC4: no deadlock on stale cc:* + closed PR + status:done combination (FAIL pre-impl) ---
# Per RETRO-011 §1: the worst-case deadlock scenario is when stale cc:* + closed PR +
# status:done label all coexist. Pre-impl: watcher may infinite-loop or exit non-zero.
# Post-impl: clean exit, queue moves on.
# Specific identifier patterns: stale_cc_deadlock OR deadlock_breaker OR status_done_gate
section "TC4: no deadlock on stale_cc + closed PR + status:done combination (RETRO-011 §1 deadlock-breaker)"
NO_DEADLOCK_GUARD="false"
if grep -qE "stale_cc_deadlock|deadlock_breaker|status_done_gate" "$WATCH_SCRIPT" 2>/dev/null; then
  NO_DEADLOCK_GUARD="true"
fi
if [ "$NO_DEADLOCK_GUARD" = "true" ]; then
  pass "TC4: deadlock guard detected in agent-watch.sh (stale_cc_deadlock OR deadlock_breaker OR status_done_gate)"
else
  fail "TC4: no deadlock guard detected" "RETRO-011 §1 requires cycle 478-481 Option D deadlock-breaker (status:done gate OR deadlock_breaker)"
fi

# --- TC5: 24h boundary freshness threshold per cycle 510 (FAIL pre-impl) ---
# Per RETRO-011 §6 (sister-pattern, cycle 510): stale_cc threshold = 24h since label added.
# Pre-impl: no threshold logic. Post-impl: labels >24h old classified stale, <24h fresh.
# Specific identifier patterns: STALE_CC_THRESHOLD_SEC OR CC_FRESHNESS_WINDOW_SEC OR stale_cc_window
section "TC5: 24h boundary freshness threshold (cycle 510, RETRO-011 §6 sister-pattern)"
FRESHNESS_THRESHOLD="false"
if grep -qE "STALE_CC_THRESHOLD_SEC|CC_FRESHNESS_WINDOW_SEC|stale_cc_window|86400" "$WATCH_SCRIPT" 2>/dev/null; then
  FRESHNESS_THRESHOLD="true"
fi
if [ "$FRESHNESS_THRESHOLD" = "true" ]; then
  pass "TC5: 24h freshness threshold detected (STALE_CC_THRESHOLD_SEC OR 86400s pattern)"
else
  fail "TC5: 24h freshness threshold not implemented" "RETRO-011 §6 + cycle 510 require 24h threshold for stale_cc classification"
fi

# --- Summary ---
section "d063 SELF-TEST SUMMARY"
TOTAL=$((PASS + FAIL))
printf "  ${B}Total:${D} %d  ${G}PASS:${D} %d  ${R}FAIL:${D} %d\n" "$TOTAL" "$PASS" "$FAIL"
echo ""
if [ "$FAIL" -gt 0 ]; then
  printf "  ${Y}⚠ Pre-impl state (expected RED on TC2-TC5):${D}\n"
  printf "  ${Y}  - TC2-TC5 will turn GREEN once RETRO-011 §1 stale_cc impl lands${D}\n"
  printf "  ${Y}  - Sister-pattern: d062 was RED on TC2-TC6 pre-impl, GREEN post-Issue #552 AC4 close${D}\n"
  printf "  ${Y}  - Cadence Rule 1 (ADR-0055 §1): d-test + INDEX.md entry ship atomic${D}\n"
fi

# Exit code: 0 if all pass, 1 if any fail (sister-pattern to d062)
if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
