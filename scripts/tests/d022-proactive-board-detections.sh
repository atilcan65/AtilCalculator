#!/usr/bin/env bash
# d022-proactive-board-detections.sh — focused regression test for the 4
# detections in scripts/proactive-board-scan.sh (refs Issue #200, #48 PR-T1
# follow-up, PR #199 review convergent findings: arch S1 + tester C2).
#
# Why this test exists
# --------------------
# PR #199 (proactive-board-scan refactor) shipped the 4 detections:
#   D1: ready_unblocked — status:ready issues with closed blockers
#   D2: orphan_backlog  — status:backlog with no cc:* label
#   D3: stalled         — status:in-progress older than STALLED_THRESHOLD_SEC
#   D4: wip_overflow    — 3+ in-progress (configurable)
#
# Convergent finding from architect (S1) + tester (C2) on PR #199:
#   "The 4 detections have NO direct regression test. d015 only covers
#    dev-idle paths, not these 4 detections. Especially important because
#    the script will be ported to dev-studio-template (PR-T1-port) —
#    without a regression test, the template port can silently break."
#
# This fixture locks in the 4 detection patterns so future refactors + the
# template port cannot silently break them.
#
# Test cases:
#   T1: D1 ready_unblocked — gh issue list with status:ready + body parser
#   T2: D2 orphan_backlog  — status:backlog filter + cc:* absence check
#   T3: D3 stalled         — cutoff_iso date math + updatedAt filter
#   T4: D4 wip_overflow    — status:in-progress count > 2
#   T5: Kill switch (PROACTIVE_SWEEP_ENABLED=false → '[]')
#   T6: Role gate (ROLE != orchestrator → '[]')
#   T7: REPO env var required (error to stderr, exit 1)
#   T8: Aggregated event emit (jq -n with detections array)
#   T9: REPO check ordering — kill switch + role gate run BEFORE REPO check
#       (locks in #202 fix; RED if reorder regresses)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d022-proactive-board-detections.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SH="$SCRIPT_DIR/../proactive-board-scan.sh"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2; exit 127
fi
if [ ! -r "$SCAN_SH" ]; then
  echo "ERROR: proactive-board-scan.sh not found at $SCAN_SH" >&2; exit 127
fi

# ============================================================================
# T1: D1 ready_unblocked detection present
# ============================================================================
section "T1: D1 ready_unblocked — gh issue list + body blocker parser"
# Pattern: gh issue list --state open --label "status:ready" + jq capture
# of "blocked by" pattern in body, then gh issue view per blocker for state.
if grep -Eq 'label "status:ready"' "$SCAN_SH" && \
   grep -Eq 'capture.*block' "$SCAN_SH" && \
   grep -Eq 'gh issue view' "$SCAN_SH"; then
  pass "D1 detection present (ready list + body parser + per-blocker state view)"
else
  fail "D1 detection missing" "expected gh issue list with status:ready + jq capture('blocked by') + gh issue view per blocker"
fi

# ============================================================================
# T2: D2 orphan_backlog detection present
# ============================================================================
section "T2: D2 orphan_backlog — status:backlog + cc:* absence check"
# Pattern: gh issue list --label "status:backlog" + jq filter that selects
# issues WITHOUT any cc:* label.
if grep -Eq 'label "status:backlog"' "$SCAN_SH" && \
   grep -Eq 'orphan_backlog' "$SCAN_SH" && \
   grep -Eq 'any\(startswith\("cc:"\)\)' "$SCAN_SH"; then
  pass "D2 detection present (backlog list + cc:* absence jq filter)"
else
  fail "D2 detection missing" "expected status:backlog label + 'orphan_backlog' detection name + jq filter 'any(startswith(\"cc:\"))'"
fi

# ============================================================================
# T3: D3 stalled detection present
# ============================================================================
section "T3: D3 stalled — cutoff_iso date math + updatedAt filter"
# Pattern: cutoff_iso computed from now_epoch - STALLED_THRESHOLD_SEC, then
# gh issue list with --label status:in-progress + updatedAt < cutoff_iso filter.
if grep -Eq 'STALLED_THRESHOLD_SEC' "$SCAN_SH" && \
   grep -Eq 'cutoff_iso' "$SCAN_SH" && \
   grep -Eq 'label "status:in-progress"' "$SCAN_SH" && \
   grep -Eq 'updatedAt <' "$SCAN_SH"; then
  pass "D3 detection present (STALLED_THRESHOLD_SEC + cutoff_iso + updatedAt filter)"
else
  fail "D3 detection missing" "expected STALLED_THRESHOLD_SEC reference + cutoff_iso var + status:in-progress filter + updatedAt < filter"
fi

# ============================================================================
# T4: D4 wip_overflow detection present
# ============================================================================
section "T4: D4 wip_overflow — status:in-progress count > 2"
# Pattern: gh issue list with --label status:in-progress + jq length, then
# compare to threshold (> 2 → 3+).
if grep -Eq 'label "status:in-progress"' "$SCAN_SH" && \
   grep -Eq 'wip_overflow' "$SCAN_SH" && \
   grep -Eq 'gt 2|-gt 2' "$SCAN_SH"; then
  pass "D4 detection present (in-progress count + > 2 threshold)"
else
  fail "D4 detection missing" "expected status:in-progress label + 'wip_overflow' detection name + count > 2 comparison"
fi

# ============================================================================
# T5: Kill switch (PROACTIVE_SWEEP_ENABLED=false → '[]')
# ============================================================================
section "T5: Kill switch — PROACTIVE_SWEEP_ENABLED=false returns '[]'"
# Pattern: explicit check for PROACTIVE_SWEEP_ENABLED=false that emits '[]'
# and exits 0 without making gh API calls.
if grep -Eq 'PROACTIVE_SWEEP_ENABLED.*false' "$SCAN_SH" && \
   grep -Fq "echo '[]'" "$SCAN_SH"; then
  pass "Kill switch present (PROACTIVE_SWEEP_ENABLED=false → '[]')"
else
  fail "Kill switch missing" "expected 'PROACTIVE_SWEEP_ENABLED=false' check + 'echo []' early-exit"
fi

# ============================================================================
# T6: Role gate (ROLE != orchestrator → '[]')
# ============================================================================
section "T6: Role gate — ROLE != orchestrator returns '[]'"
# Pattern: explicit check that ROLE equals 'orchestrator', else emit '[]'.
if grep -Eq 'ROLE.*orchestrator' "$SCAN_SH" && \
   grep -Fq "echo '[]'" "$SCAN_SH"; then
  pass "Role gate present (ROLE != orchestrator → '[]')"
else
  fail "Role gate missing" "expected 'ROLE != orchestrator' check + 'echo []' early-exit"
fi

# ============================================================================
# T7: REPO env var required (error + exit 1)
# ============================================================================
section "T7: REPO env var required — error to stderr, exit 1"
# Pattern: explicit REPO check with stderr message + non-zero exit.
if grep -Eq 'REPO.*required' "$SCAN_SH" && \
   grep -Eq 'exit 1' "$SCAN_SH"; then
  pass "REPO env var check present (error to stderr + exit 1)"
else
  fail "REPO check missing" "expected 'ERROR: REPO env var... is required' stderr message + exit 1"
fi

# ============================================================================
# T8: Aggregated event emit (jq -n with detections array)
# ============================================================================
section "T8: Aggregated event emit — jq -n with detections array"
# Pattern: when detections is non-empty, jq -n emits aggregated event with
# kind='proactive_scan' and detections array in context.
if grep -Eq 'jq -n' "$SCAN_SH" && \
   grep -Eq 'kind: "proactive_scan"' "$SCAN_SH" && \
   grep -Eq 'detections: \$detections' "$SCAN_SH"; then
  pass "Aggregated event emit present (jq -n + proactive_scan kind + detections array)"
else
  fail "Aggregated emit missing" "expected 'jq -n' + 'kind: \"proactive_scan\"' + 'detections: \$detections' in jq output"
fi

# ============================================================================
# T9: REPO check ordering — kill switch + role gate BEFORE REPO check
#       (locks in #202 fix; RED if reorder regresses)
# ============================================================================
section "T9: REPO check ordering — killswitch+rolegate BEFORE REPO check"
# Pattern: the line number of `if [ "$PROACTIVE_SWEEP_ENABLED" = "false" ]`
# check must be LESS than the line number of the REPO presence check.
# Locks in #202 fix; if reorder regresses, this TC goes RED.
#
# Use grep -n with `if` prefix to skip comment lines (header block at L37-43).
repo_line="$(grep -n 'ERROR: REPO env var' "$SCAN_SH" | head -1 | cut -d: -f1 || echo "")"
killswitch_line="$(grep -n 'if.*PROACTIVE_SWEEP_ENABLED.*false' "$SCAN_SH" | head -1 | cut -d: -f1 || echo "")"
rolegate_line="$(grep -n 'if.*ROLE.*orchestrator' "$SCAN_SH" | head -1 | cut -d: -f1 || echo "")"

if [ -z "$repo_line" ] || [ -z "$killswitch_line" ] || [ -z "$rolegate_line" ]; then
  fail "Cannot determine line numbers" "expected to find REPO check + kill switch + role gate lines in $SCAN_SH (got repo=$repo_line, killswitch=$killswitch_line, rolegate=$rolegate_line)"
elif [ "$killswitch_line" -lt "$repo_line" ] && [ "$rolegate_line" -lt "$repo_line" ]; then
  pass "REPO check ordering correct (killswitch L$killswitch_line + rolegate L$rolegate_line before REPO check L$repo_line)"
else
  printf "  ${R}✗ FAIL${D} — REPO check ordering wrong\n"
  printf "    ${R}expected: killswitch (L$killswitch_line) + rolegate (L$rolegate_line) BEFORE REPO check (L$repo_line). REGRESSION: #202 fix (tester C4) lost. Restore reorder in scripts/proactive-board-scan.sh.\n"
  FAIL=$((FAIL+1))
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0