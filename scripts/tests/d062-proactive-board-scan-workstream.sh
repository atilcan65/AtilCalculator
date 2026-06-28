#!/usr/bin/env bash
# d062-proactive-board-scan-workstream.sh — Issue #552 AC2 watcher patch regression guard
#
# Why this test exists
# --------------------
# Issue #552 AC2 (arch verdict cycle 481) requires the orchestrator watcher
# to report WIP as WORK-STREAM-COUNT (not issue-count). The fix:
#   1. scripts/claim-next-ready.sh — add --wip-count-only mode + stream:
#      label preference (PRIMARY) on top of existing commit-base fallback
#      (SECONDARY). Standalone → TERTIARY fallback.
#   2. scripts/proactive-board-scan.sh D4 — delegate wip_count to
#      claim-next-ready.sh --wip-count-only --role=* (single source of truth).
#
# d062 is the regression guard for this dual mechanism. Sister-pattern to
# d058 (work-stream awareness base, 11 TCs).
#
# 6 TCs (1 PASS baseline + 5 violation codifications, RED-first per ADR-0044).
# Pre-impl expected: 1 PASS (TC1 baseline) + 5 FAIL (TC2-TC6 violations).
# Post-impl expected: 6 PASS (all TCs green).
#
# Doctrine anchors:
# - ADR-0038 §Work-Stream Awareness (work-stream-count semantics)
# - ADR-0055 §1 Cadence Rule 1 atomic (d-test + INDEX.md entry in same PR)
# - ADR-0044 TDD RED contract
# - Issue #552 AC2 (orch watcher wip_count aggregation, ~10-15 LOC)
# - Arch verdict cycle 481 (dual mechanism: stream: label PRIMARY + commit-base SECONDARY)
# - RETRO-010 §17 NEW (orch issue-count vs work-stream-count drift)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLAIM_SCRIPT="${REPO_ROOT}/scripts/claim-next-ready.sh"
SCAN_SCRIPT="${REPO_ROOT}/scripts/proactive-board-scan.sh"

# TTY-aware color setup (sister-pattern to d058)
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
[ -f "$CLAIM_SCRIPT" ] || { echo "ERROR: claim-next-ready.sh not found" >&2; exit 2; }
[ -f "$SCAN_SCRIPT" ] || { echo "ERROR: proactive-board-scan.sh not found" >&2; exit 2; }

# Self-test mode (RED-first per ADR-0044)
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

# ============================================================================
# TC1 (BASELINE PASS): both scripts exist + --wip-count-only flag accepted
# ============================================================================
section "TC1: scripts exist + --wip-count-only mode flag accepted (baseline)"
# Pre-impl: PASS (both files exist)
# Post-impl: PASS (mode flag accepted)
# Note: pipefail-friendly — capture output to var first, then grep (avoid
# `set -uo pipefail` breaking the pipe when claim-next-ready.sh exits 2).
if [ -f "$CLAIM_SCRIPT" ] && [ -f "$SCAN_SCRIPT" ]; then
  usage_out="$(bash "$CLAIM_SCRIPT" --wip-count-only 2>&1 || true)"
  if echo "$usage_out" | grep -q "usage:"; then
    pass "TC1: scripts exist + --wip-count-only mode flag accepted"
  else
    fail "TC1: --wip-count-only mode flag not accepted (usage message missing)" \
      "out=$usage_out"
  fi
else
  fail "TC1: scripts missing (claim-next-ready.sh or proactive-board-scan.sh)"
fi

# ============================================================================
# TC2 (FAIL→PASS): --wip-count-only '*' outputs wip_count=N issue_count=M format
# ============================================================================
section "TC2: --wip-count-only '*' outputs machine-parseable wip_count=N issue_count=M"
# Pre-impl: FAIL (no --wip-count-only mode)
# Post-impl: PASS (single-line output with wip_count=N issue_count=M)
out="$(bash "$CLAIM_SCRIPT" --wip-count-only '*' 2>&1 || true)"
if echo "$out" | grep -qE "^wip_count=[0-9]+ issue_count=[0-9]+$"; then
  pass "TC2: --wip-count-only '*' outputs machine-parseable wip_count + issue_count format"
else
  fail "TC2: --wip-count-only '*' MUST output 'wip_count=N issue_count=M' single-line format" \
    "out=$out"
fi

# ============================================================================
# TC3 (FAIL→PASS): claim-next-ready.sh stream_count logic uses stream: label
# preference (PRIMARY mechanism per arch verdict cycle 481)
# ============================================================================
section "TC3: claim-next-ready.sh uses stream: label preference (PRIMARY dual mechanism)"
# Pre-impl: FAIL (no stream: label check)
# Post-impl: PASS (stream: label = PRIMARY, before commit-base fallback)
if grep -qE "stream:" "$CLAIM_SCRIPT" 2>/dev/null \
   && grep -qE "PRIMARY" "$CLAIM_SCRIPT" 2>/dev/null \
   && awk '/PRIMARY/{exit 0} /SECONDARY/{exit 1}' "$CLAIM_SCRIPT" 2>/dev/null; then
  pass "TC3: stream: label preference (PRIMARY) checked BEFORE commit-base fallback (SECONDARY)"
else
  fail "TC3: claim-next-ready.sh MUST check stream: label (PRIMARY) before commit-base fallback (SECONDARY)"
fi

# ============================================================================
# TC4 (FAIL→PASS): --wip-count-only mode early-exits before ready query (skip claim logic)
# ============================================================================
section "TC4: --wip-count-only mode early-exits before ready query (skip claim logic)"
# Pre-impl: FAIL (no early exit; falls through to ready query)
# Post-impl: PASS (early exit after wip_count compute, skips fetch + claim)
if grep -qE "WIP_COUNT_ONLY.*true" "$CLAIM_SCRIPT" 2>/dev/null \
   && grep -B2 -A5 "WIP_COUNT_ONLY.*true" "$CLAIM_SCRIPT" 2>/dev/null | grep -q "exit 0"; then
  pass "TC4: --wip-count-only mode early-exits (skips ready query + claim logic)"
else
  fail "TC4: --wip-count-only mode MUST early-exit after wip_count compute (no ready query, no claim)"
fi

# ============================================================================
# TC5 (FAIL→PASS): --wip-count-only --role=* accepts global mode (no agent filter)
# ============================================================================
section "TC5: --wip-count-only --role=* accepts global mode (no agent: filter)"
# Pre-impl: FAIL (no ROLE='*' / 'global' handling)
# Post-impl: PASS (ROLE='*' or 'global' allowed only in --wip-count-only mode)
if grep -qE "ROLE.*\*.*global" "$CLAIM_SCRIPT" 2>/dev/null \
   && grep -qE "label \"status:in-progress\"" "$CLAIM_SCRIPT" 2>/dev/null; then
  pass "TC5: --wip-count-only --role=* uses global query (no agent: filter)"
else
  fail "TC5: --wip-count-only --role=* MUST support global mode (no agent: filter, queries all status:in-progress)"
fi

# ============================================================================
# TC6 (FAIL→PASS): proactive-board-scan.sh D4 delegates wip_count to claim-next-ready.sh
# --wip-count-only --role=* (single source of truth, regression guard for AC2)
# ============================================================================
section "TC6: proactive-board-scan.sh D4 delegates wip_count to claim-next-ready.sh --wip-count-only"
# Pre-impl: FAIL (D4 uses raw `gh issue list | jq 'length'` issue count)
# Post-impl: PASS (D4 calls claim-next-ready.sh --wip-count-only --role='*')
if grep -A3 "D4: wip_overflow" "$SCAN_SCRIPT" 2>/dev/null \
   | grep -q "claim-next-ready.sh.*--wip-count-only"; then
  pass "TC6: proactive-board-scan.sh D4 delegates to claim-next-ready.sh --wip-count-only (single source of truth)"
else
  fail "TC6: proactive-board-scan.sh D4 MUST delegate to claim-next-ready.sh --wip-count-only --role='*'" \
    "D4 currently uses raw issue-count, AC2 dual mechanism not applied"
fi

# ============================================================================
# Summary (sister-pattern to d054 + d058)
# ============================================================================
printf "\n${B}==== d062 SELF-TEST SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

# Pre-impl expected: 1 PASS (TC1 baseline) + 5 FAIL (TC2-TC6 violations)
# Post-impl expected: 6 PASS (all TCs green)
if [ "$PASS" -eq 6 ] && [ "$FAIL" -eq 0 ]; then
  printf "  ${G}d062 GREEN${D} — 6/6 PASS = watcher patch dual mechanism fully impl'd\n"
  exit 0
elif [ "$PASS" -eq 1 ] && [ "$FAIL" -eq 5 ]; then
  printf "  ${Y}d062 RED${D} — 1/6 PASS + 5/6 FAIL = expected pre-impl RED state\n"
  exit 1
else
  printf "  ${R}d062 RED (unexpected)${D} — counts outside expected range. Investigate.\n"
  exit 1
fi