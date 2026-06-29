#!/usr/bin/env bash
# d069-layer-5-verdict-emoji-gate.sh — Issue #659 / PR #664 verdict-gate structural regression test (5 TCs).
#
# Why this test exists
# --------------------
# Sprint 21 P1 cluster (PR #662 ADR-0048 amendment + PR #664 Layer 5
# verdict-emoji gate impl) fixes RETRO-015 §16 Layer 5 race pathology:
# Layer 5 was auto-adding `status:ready` despite a 🔴 CHANGES REQUESTED
# verdict in the PR thread (PR #655 incident, Issue #113 sister-precedent).
# PR #664 ships the workflow fix in `.github/workflows/label-check.yml`;
# d069 verifies the fix landed correctly per ADR-0044 RED-first +
# ADR-0049 d-test framework sister-pattern (≥5 TCs, --self-test contract,
# bash + grep + awk fallback, no Python dependency).
#
# 5 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: verdict-gate code block present in label-check.yml
#        (structural signature: "Path A verdict-emoji gate" comment marker)
#   TC2: verdict-gate positioned AFTER `let shouldAddReady/skipReason` decls
#        (TDZ discipline — cycle ~972 P0; this is the bug that would crash
#        the workflow on every run if not fixed)
#   TC3: bot-exclusion filter `c.user.type === 'Bot'` present in gate
#        (arch fix #1 from cycle ~970 — prevents Layer 5's own
#         silent-skip log from re-triggering the gate on next run)
#   TC4: pagination via `github.paginate.iterator` present in gate
#        (arch fix #2 from cycle ~970 — single-page listComments would
#         miss the latest verdict on PRs with >100 comments)
#   TC5: verdict-gate references verdict emoji 🟢/🟡/🔴 (post-fix structural
#        signature — the gate MUST match verdict emoji to detect them)
#
# Pre-impl RED state (current main as of 2026-06-29, PR #664 not yet merged):
#   - "Path A verdict-emoji gate" comment marker: ABSENT
#   - pagination + bot-exclusion: ABSENT
#   - verdict emoji refs: ABSENT
#   → All 5 TCs FAIL in RED state per ADR-0044.
#
# Post-impl GREEN state (after PR #664 merges to main):
#   - All 5 structural checks PASS
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d062 (Issue #552 AC2 proactive-board-scan work-stream awareness — Issue #659 cluster sister)
#   - d064 (Issue #587 ADR-0059 cluster-lag detector — workflow YAML sister-pattern)
#   - d065 (ADR-0033 dual-channel enforcement — Sprint 18 sister)
#   - d066 (RETRO-012 §6 WIP cap filter — Sprint 18 sister)
#   - d068 (Issue #605 cluster-lag workflow wiring — workflow YAML sister-pattern)
#
# Usage:
#   bash d069-layer-5-verdict-emoji-gate.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — verdict-gate landed correctly)
#   1 — at least one FAIL (RED state — verdict-gate missing or wrongly positioned)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABEL_CHECK="${REPO_ROOT}/.github/workflows/label-check.yml"

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

# Pre-flight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d069 self-test (5 TCs per Issue #659 / PR #664 cluster, ADR-0044 RED-first)${D}\n"
printf "${B}=======================================================================${D}\n"
printf "  Workflow under test: %s\n" "$LABEL_CHECK"
printf "  Sister-pattern:      d062, d064, d065, d066, d068 (ADR-0049 d-test family)\n"
printf "  RED-first:           pre-#664-merge all 5 TCs FAIL.\n"
printf "  Post-impl:           all 5 TCs must PASS.\n\n"

if [ ! -f "$LABEL_CHECK" ]; then
  fail "preflight — workflow file missing" "expected $LABEL_CHECK"
  exit 2
fi

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# Locate the verdict-gate region once (used by TC3-TC5).
# Gate region = from the "Path A verdict-emoji gate" comment marker
# to the next "Step N" header or end of file.
GATE_REGION_START="$(grep -nE 'Path A verdict-emoji gate' "$LABEL_CHECK" | head -1 | cut -d: -f1)"
if [ -n "$GATE_REGION_START" ]; then
  GATE_REGION_END="$(awk -v start="$GATE_REGION_START" 'NR > start && /Step [0-9]/ { print NR - 1; exit }' "$LABEL_CHECK")"
  : "${GATE_REGION_END:=$(wc -l < "$LABEL_CHECK")}"
  GATE_REGION="${GATE_REGION_START},${GATE_REGION_END}p"
else
  GATE_REGION="0p"   # empty range (yields nothing) — TC3-TC5 will see absence
fi

# ============================================================================
# TC1: verdict-gate code block present (structural signature)
# ============================================================================
section "TC1: verdict-gate code block present in label-check.yml (Path A fix landed)"
if [ -z "$GATE_REGION_START" ]; then
  fail "TC1 — verdict-gate block missing" \
    "expected 'Path A verdict-emoji gate' comment marker in $LABEL_CHECK. PR #664 not yet merged or impl drifted. RED-first confirmed per ADR-0044."
  EXIT_CODE=1
else
  info "TC1 — Path A verdict-gate comment marker found at L${GATE_REGION_START}, region L${GATE_REGION_START}-L${GATE_REGION_END}"
  pass "TC1 — verdict-gate code block present"
fi

# ============================================================================
# TC2: verdict-gate positioned AFTER let declarations (TDZ discipline — cycle ~972 P0)
# ============================================================================
section "TC2: verdict-gate positioned AFTER let declarations (TDZ discipline — cycle ~972 P0)"
DECL_LINE="$(grep -nE '^[[:space:]]*let shouldAddReady = false;' "$LABEL_CHECK" | head -1 | cut -d: -f1)"

if [ -z "$GATE_REGION_START" ]; then
  fail "TC2 — cannot verify positioning (TC1 prerequisite not met — gate absent)" \
    "TC1 must pass before TC2 can verify positioning. See TC1 failure above. Cycle ~972 P0 caught the TDZ crash on v1/v2 — same crash returns if gate lands BEFORE decls."
  EXIT_CODE=1
elif [ -z "$DECL_LINE" ]; then
  fail "TC2 — 'let shouldAddReady' declaration missing" \
    "expected 'let shouldAddReady = false;' decl in $LABEL_CHECK. If decl was removed, the gate has nothing to override — regression."
  EXIT_CODE=1
elif [ "$GATE_REGION_START" -le "$DECL_LINE" ]; then
  fail "TC2 — verdict-gate BEFORE 'let shouldAddReady' declaration (TDZ crash)" \
    "verdict-gate at L${GATE_REGION_START}, 'let shouldAddReady' decl at L${DECL_LINE}. Gate must come AFTER decl (delta > 0). Cycle ~972 P0 caught this exact crash on v1/v2 of PR #664."
  EXIT_CODE=1
else
  DELTA=$((GATE_REGION_START - DECL_LINE))
  info "TC2 — gate at L${GATE_REGION_START}, decl at L${DECL_LINE} (delta ${DELTA} lines, TDZ-safe)"
  pass "TC2 — verdict-gate positioned AFTER let declaration (TDZ-safe, no ReferenceError)"
fi

# ============================================================================
# TC3: bot-exclusion filter present in gate (arch fix #1, cycle ~970)
# ============================================================================
section "TC3: bot-exclusion filter present in gate region (arch fix #1, cycle ~970)"
if [ -z "$GATE_REGION_START" ]; then
  fail "TC3 — cannot inspect gate region (TC1 prerequisite not met)" \
    "TC1 must pass before TC3 can run. See TC1 failure above."
  EXIT_CODE=1
elif sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -qE "c\.user\.type\s*===\s*['\"]Bot['\"]"; then
  info "TC3 — bot-exclusion filter 'c.user.type === \"Bot\"' found in gate region (L${GATE_REGION_START}-L${GATE_REGION_END})"
  pass "TC3 — bot-exclusion filter present (prevents Layer 5 self-trigger loop on silent-skip log)"
else
  fail "TC3 — bot-exclusion filter missing in gate region" \
    "expected 'c.user.type === \"Bot\"' filter in verdict-gate region (L${GATE_REGION_START}-L${GATE_REGION_END}). Arch fix #1 from cycle ~970 absent. Without it, Layer 5's own silent-skip log (which contains verdict emoji in skipReason) would re-trigger the gate on next run."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: pagination via github.paginate.iterator present in gate (arch fix #2, cycle ~970)
# ============================================================================
section "TC4: pagination via github.paginate.iterator present in gate region (arch fix #2, cycle ~970)"
if [ -z "$GATE_REGION_START" ]; then
  fail "TC4 — cannot inspect gate region (TC1 prerequisite not met)" \
    "TC1 must pass before TC4 can run. See TC1 failure above."
  EXIT_CODE=1
elif sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -qE "github\.paginate\.iterator"; then
  info "TC4 — 'github.paginate.iterator' found in gate region (handles >100 comments)"
  pass "TC4 — pagination via github.paginate.iterator present (latest verdict not missed on long PR threads)"
else
  fail "TC4 — pagination missing in gate region" \
    "expected 'github.paginate.iterator' in verdict-gate region (L${GATE_REGION_START}-L${GATE_REGION_END}). Arch fix #2 from cycle ~970 absent. Single-page listComments (per_page=100) will miss the latest verdict on PRs with >100 comments — gate will silently approve stale verdict."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: verdict-gate references verdict emoji 🟢/🟡/🔴 (post-fix structural signature)
# ============================================================================
section "TC5: verdict-gate references verdict emoji 🟢/🟡/🔴 (post-fix structural signature)"
if [ -z "$GATE_REGION_START" ]; then
  fail "TC5 — cannot inspect gate region (TC1 prerequisite not met)" \
    "TC1 must pass before TC5 can run. See TC1 failure above."
  EXIT_CODE=1
elif sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -qE '🟢|🟡|🔴'; then
  EMOJI_HITS="$(sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -cE '🟢|🟡|🔴')"
  info "TC5 — verdict emoji references found in gate region (${EMOJI_HITS} hits, e.g. latestVerdict === '🟡'/'🔴' override)"
  pass "TC5 — verdict-gate references verdict emoji (gate can detect 🟡/🔴 verdicts and override status:ready)"
else
  fail "TC5 — verdict emoji references missing in gate region" \
    "expected 🟢/🟡/🔴 emoji references in verdict-gate region (L${GATE_REGION_START}-L${GATE_REGION_END}). Without emoji match, gate cannot detect verdicts — Layer 5 race pathology returns (PR #655 incident re-fires)."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — verdict-gate missing or wrongly positioned per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 5 TCs PASS — verdict-gate landed correctly (Path A structural invariants)${D}\n"
exit 0
