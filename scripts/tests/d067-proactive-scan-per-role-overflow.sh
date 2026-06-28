#!/usr/bin/env bash
# d067-proactive-scan-per-role-overflow.sh — Issue #610 regression guard
# (proactive-board-scan.sh D4 wip_overflow per-role semantics fix)
#
# Why this test exists
# --------------------
# Sprint 17 P1 LIVE INSTANCE: PM + arch lanes both at WIP=2/2 (legitimate
# AT-CAP, per ADR-0038 §Work-Stream Awareness per-role cap=2) fired
# `wip_overflow` alerts (false positive). Root cause: proactive-board-scan.sh
# D4 used `claim-next-ready.sh --wip-count-only '*'` (GLOBAL count, sum
# across all roles) and compared against hardcoded threshold 2.
#   - PM=2 + arch=2 → global=4 > 2 → FIRES (false positive — neither lane overflowed)
#
# Fix: per-role iteration. Fire wip_overflow only when a SPECIFIC role
# exceeds its per-role cap (count > 2). AT-CAP (count == 2) → silent.
#
# 6 TCs (1 PASS baseline + 5 violation codifications, RED-first per ADR-0044).
# Pre-impl expected: 1 PASS (TC1 baseline) + 5 FAIL (TC2-TC6 violations).
# Post-impl expected: 6 PASS (all TCs green).
#
# Test pattern: sister-pattern to d062 (source-grep regression guard). No mock
# complexity — pure source inspection verifies the per-role semantics are
# baked into the script. Behavioral verification happens in production via
# the orchestrator watcher (proactive sweep integration test).
#
# Doctrine anchors:
# - ADR-0038 §Work-Stream Awareness (per-role WIP cap, NOT global)
# - ADR-0044 TDD RED contract
# - ADR-0049 d-test framework
# - ADR-0055 §1 Cadence Rule 1 atomic (d-test + INDEX.md entry in same PR)
# - Issue #610 (STORY-S18-007 doctrinal home, Sprint 18 P1)
# - RETRO-012 §5 (Sprint 17 ProcessGap codification, false-positive origin)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCAN_SCRIPT="${REPO_ROOT}/scripts/proactive-board-scan.sh"

# TTY-aware color setup (sister-pattern to d058/d062/d066)
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
[ -f "$SCAN_SCRIPT" ] || { echo "ERROR: proactive-board-scan.sh not found" >&2; exit 2; }

# Self-test mode (RED-first per ADR-0044)
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

# ============================================================================
# TC1 (BASELINE PASS): proactive-board-scan.sh exists
# ============================================================================
section "TC1: scripts exist + baseline (pre-impl PASS)"
if [ -f "$SCAN_SCRIPT" ]; then
  pass "TC1: proactive-board-scan.sh exists"
else
  fail "TC1: proactive-board-scan.sh missing"
  # Hard fail: rest of test requires script existence
  printf "\n${R}==== early abort: cannot test missing script ====${D}\n"
  exit 1
fi

# ============================================================================
# TC2: D4 wip_overflow threshold uses STRICT GREATER-THAN (>2 not >=2)
# AC2 critical: AT-CAP (count==2) MUST NOT fire wip_overflow
# ============================================================================
section "TC2: D4 threshold is count > 2 (strict — count==2 MUST NOT fire)"
# Pre-impl: FAIL (no D4 section, or uses raw issue count)
# Post-impl: PASS (grep shows `-gt 2` or `> 2` in D4 section)
d4_section="$(grep -A 25 'D4: wip_overflow' "$SCAN_SCRIPT" 2>/dev/null || true)"
if echo "$d4_section" | grep -qE '\-gt[[:space:]]+2'; then
  pass "TC2: D4 threshold is count > 2 (strict — AT-CAP=2 silent)"
else
  fail "TC2: D4 threshold MUST be count > 2 (strict — count==2 is AT-CAP, not overflow)" \
    "D4 section lacks '-gt 2' threshold"
fi

# ============================================================================
# TC3: D4 iterates per-role (NOT single global --wip-count-only '*' query)
# Sprint 17 P1 LIVE INSTANCE root cause: global count summed PM=2+arch=2 → 4
# ============================================================================
section "TC3: D4 iterates per-role (not single global query — Sprint 17 P1 fix)"
# Pre-impl: FAIL (single '--wip-count-only' call with '*' or 'global')
# Post-impl: PASS (for loop over roles, each with --wip-count-only <role>)
if echo "$d4_section" | grep -qE 'for[[:space:]]+role[[:space:]]+in'; then
  pass "TC3: D4 uses per-role iteration (for loop over roles)"
elif echo "$d4_section" | grep -qE "wip-count-only.*['\"][*]"; then
  fail "TC3: D4 still uses global '--wip-count-only *' query (Sprint 17 P1 false positive NOT fixed)" \
    "Pre-fix behavior: PM=2+arch=2 → global=4 > 2 → false positive"
else
  fail "TC3: D4 MUST use per-role iteration (for loop over roles calling --wip-count-only <role>)"
fi

# ============================================================================
# TC4: per-role detection output includes role tag (role: $role in jq)
# ============================================================================
section "TC4: detection payload includes role tag (role: \$role in jq --arg)"
# Pre-impl: FAIL (no role tag — just count)
# Post-impl: PASS (jq --arg role <name> + .role: $role in detection object)
if echo "$d4_section" | grep -qE 'role:[[:space:]]+\$role' \
   || echo "$d4_section" | grep -qE '\.role:[[:space:]]+\$'; then
  pass "TC4: detection payload includes role tag (.role: \$role)"
else
  fail "TC4: detection payload MUST include role tag (.role: \$role) for per-role diagnostics" \
    "Without role tag, dashboard can't tell WHICH role overflowed"
fi

# ============================================================================
# TC5 (AC1+AC2 LIVE INSTANCE): Sprint 17 P1 cross-role AT-CAP silent
# Verifies comment + code explicitly reference AT-CAP (count==cap) ≠ overflow
# ============================================================================
section "TC5: explicit comment documents AT-CAP ≠ OVERFLOW semantics"
# Pre-impl: FAIL (no comment, or generic comment)
# Post-impl: PASS (comment mentions AT-CAP, false positive, or Sprint 17 P1)
if echo "$d4_section" | grep -qiE 'AT-CAP|fals.{0,5}posit|Sprint 17 P1'; then
  pass "TC5: D4 comment documents AT-CAP semantics (explicit non-overflow)"
else
  fail "TC5: D4 MUST have explicit comment distinguishing AT-CAP from OVERFLOW" \
    "Sprint 17 P1 false positives were silent bugs because semantic was implicit"
fi

# ============================================================================
# TC6: list of roles iterated matches all 5 lanes per file ownership matrix
# developer + product-manager + architect + tester + orchestrator = 5
# ============================================================================
section "TC6: per-role iteration covers all 5 lanes (ADR-0012 lane matrix)"
# Pre-impl: FAIL (no iteration, single '*' call)
# Post-impl: PASS (for loop includes all 5 lanes)
roles_found=0
for lane in developer product-manager architect tester orchestrator; do
  if echo "$d4_section" | grep -q "$lane"; then
    roles_found=$((roles_found + 1))
  fi
done
if [ "$roles_found" -eq 5 ]; then
  pass "TC6: D4 per-role iteration covers all 5 lanes (5/5 found in D4 section)"
else
  fail "TC6: D4 MUST iterate all 5 lanes (developer + product-manager + architect + tester + orchestrator)" \
    "found=$roles_found/5 (missing lanes = false-negative risk)"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
printf "${B}==== d067 summary ====${D}\n"
TOTAL=$((PASS+FAIL))
printf "  TOTAL=%d  PASS=%d  FAIL=%d\n" "$TOTAL" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "${R}RED state: %d TC(s) FAILING — fix needed before impl merge${D}\n" "$FAIL"
  exit 1
fi
printf "${G}GREEN state: all TCs PASS — per-role semantics verified${D}\n"
exit 0