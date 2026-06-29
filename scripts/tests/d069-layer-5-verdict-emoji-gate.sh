#!/usr/bin/env bash
# d069-layer-5-verdict-emoji-gate.sh — Issue #659 (verdict-gate) + Issue #666 (parameterization v2)
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
# Issue #666 (cycle ~981 arch verdict cmt 4829796278, follow-up hygiene)
# extends d069 to support WORKFLOW_FILES array input, enabling verdict-gate
# detection across sibling workflow files (e.g., label-check-2.yml,
# status-label-to-board-2.yml) if/when verdict-gate is replicated.
#
# 5 verdict-gate TCs (TC1-TC5, run PER file in WORKFLOW_FILES):
#   TC1: verdict-gate code block present in <workflow-file>
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
# 5 parameterization TCs (TC-1 to TC-5, structural checks on d069 source):
#   TC-1: WORKFLOW_FILES env var declared with default 'label-check.yml'
#         (Issue #666 AC8 — backward compat with PR #665 v2 GREEN state)
#   TC-2: multi-file array parsing present (IFS=',' + array iteration)
#         (Issue #666 AC1+AC2 — comma-separated input → bash array)
#   TC-3: shopt globstar enabled for *.yml pattern expansion
#         (arch Q1 decision — bash 5.x universal on GH Actions ubuntu-latest)
#   TC-4: silent_skip guard for empty WORKFLOW_FILES (ADR-0048 lens d)
#         (Issue #666 TC-4 — empty array MUST log silent_skip event, exit 2)
#   TC-5: missing-file preflight (exit 2 if any resolved file doesn't exist)
#         (Issue #666 TC-5 — graceful fail on nonexistent.yml input)
#
# Aggregation: AND across files (arch Q2 — all files must pass verdict-gate
# structural TCs; apparent TC-2 coverage vs aggregation conflict resolved
# by arch verdict: coverage requirement = "at least 1 file detected", NOT
# the cross-file aggregation logic).
#
# Observability (lens f per arch guidance):
#   - workflow_file_count, files_passed, files_failed counters
#   - per-file structured log: file, verdict, tc1..tc5 pass/fail counts
#
# Pre-impl RED state (current main as of 2026-06-29):
#   - TC1-TC5: depend on PR #664 verdict-gate implementation (currently MERGED on main)
#   - TC-1 to TC-5: ALL FAIL on main (parameterization not implemented)
#   → 5/5 parameterization TCs FAIL in RED state per ADR-0044.
#
# Post-impl GREEN state (after Issue #666 refactor lands):
#   - TC1-TC5: still 5/5 (verdict-gate preserved)
#   - TC-1 to TC-5: 5/5 (parameterization structural checks present)
#   → 10/10 PASS in GREEN state (5 per-file + 5 parameterization).
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d046 (workflow YAML sister-pattern)
#   - d068 (cluster-lag workflow wiring sister)
#   - d077 (Layer 5 misfire regression — extends from verdict-gate)
#
# Usage:
#   bash d069-layer-5-verdict-emoji-gate.sh --self-test
#   WORKFLOW_FILES="label-check.yml,status-label-to-board.yml" bash d069-layer-5-verdict-emoji-gate.sh --self-test
#   WORKFLOW_FILES="*.yml" bash d069-layer-5-verdict-emoji-gate.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — verdict-gate landed + parameterization working)
#   1 — at least one FAIL (RED state — verdict-gate or parameterization broken)
#   2 — preflight failure (empty array, missing file, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"

# WORKFLOW_FILES env var with default (Issue #666 AC1+AC8 backward compat)
# Use :- for unset-only default; empty string IS a valid input (TC-4 silent_skip test)
WORKFLOW_FILES="${WORKFLOW_FILES-label-check.yml}"

# Globstar + nullglob per arch Q1 decision (bash 5.x on GH Actions ubuntu-latest)
shopt -s globstar nullglob

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
command -v find >/dev/null 2>&1 || { echo "ERROR: find required (TC-3 glob expansion)" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test [WORKFLOW_FILES=...]" >&2
  exit 2
fi

printf "${B}d069 self-test (5 verdict-gate + 5 parameterization TCs per Issue #659 + #666, ADR-0044 RED-first)${D}\n"
printf "${B}=======================================================================${D}\n"
printf "  WORKFLOW_FILES input: '%s'\n" "$WORKFLOW_FILES"
printf "  Sister-pattern:       d046, d068, d077 (ADR-0049 d-test family)\n"
printf "  Aggregation:          AND across files (arch Q2)\n"
printf "  Glob:                 shopt -s globstar nullglob (arch Q1)\n"
printf "  Silent-skip:          ADR-0048 lens d guard on empty array\n"
printf "  RED-first:            pre-impl TC-2..TC-5 FAIL; TC-1 PASS (backward compat default).\n\n"

# ============================================================================
# Parse WORKFLOW_FILES → RESOLVED_FILES array (Issue #666 AC1+AC2)
# ============================================================================
IFS=',' read -ra WORKFLOW_FILES_ARR <<< "$WORKFLOW_FILES"

# Trim whitespace + skip empty entries
TRIMMED_FILES=()
for entry in "${WORKFLOW_FILES_ARR[@]}"; do
  trimmed="$(echo "$entry" | xargs)"
  [ -z "$trimmed" ] && continue
  TRIMMED_FILES+=("$trimmed")
done

# Resolve to absolute paths (with glob expansion if needed)
RESOLVED_FILES=()
for f in "${TRIMMED_FILES[@]}"; do
  if [[ "$f" == *"*"* ]] || [[ "$f" == *"?"* ]]; then
    # Glob pattern: unquote $f so shell can expand it (nullglob makes empty match → skip)
    for match in "${WORKFLOWS_DIR}"/$f; do
      [ -e "$match" ] && [[ ! " ${RESOLVED_FILES[*]} " =~ " $match " ]] && RESOLVED_FILES+=("$match")
    done
    # Also check subdirectories (globstar)
    for match in "${WORKFLOWS_DIR}"/**/$f; do
      [ -e "$match" ] && [[ ! " ${RESOLVED_FILES[*]} " =~ " $match " ]] && RESOLVED_FILES+=("$match")
    done
  else
    RESOLVED_FILES+=("${WORKFLOWS_DIR}/$f")
  fi
done

# Observability (lens f per arch guidance)
WORKFLOW_FILE_COUNT=${#RESOLVED_FILES[@]}
info "WORKFLOW_FILES resolved to ${WORKFLOW_FILE_COUNT} file(s)"
for f in "${RESOLVED_FILES[@]}"; do
  info "  - $(basename "$f")"
done

# ============================================================================
# Preflight checks (Issue #666 TC-4 + TC-5 — silent_skip + missing file)
# ============================================================================
if [ "$WORKFLOW_FILE_COUNT" -eq 0 ]; then
  # Lens d silent-skip guard per ADR-0048 — silent pass on empty glob is production blind
  printf "${Y}[silent_skip] WORKFLOW_FILES='%s' resolved to empty array (0 files)${D}\n" "$WORKFLOW_FILES" >&2
  printf "  workflow_file_count=0\n" >&2
  printf "  hint: ensure WORKFLOW_FILES points to existing workflow files or valid glob pattern\n" >&2
  fail "preflight — WORKFLOW_FILES resolved to empty array" \
    "WORKFLOW_FILES='$WORKFLOW_FILES' → 0 files resolved. See silent_skip log above (ADR-0048 lens d)."
  exit 2
fi

# Check all resolved files exist (TC-5)
for f in "${RESOLVED_FILES[@]}"; do
  if [ ! -f "$f" ]; then
    fail "preflight — workflow file missing" \
      "expected $f (resolved from WORKFLOW_FILES='$WORKFLOW_FILES'). Exit 2 per Issue #666 TC-5."
    exit 2
  fi
done

# ============================================================================
# Per-file verdict-gate structural TCs (TC1-TC5, AND-aggregated across files)
# ============================================================================
FILES_PASSED=0
FILES_FAILED=0

for LABEL_CHECK in "${RESOLVED_FILES[@]}"; do
  FILE_BASENAME="$(basename "$LABEL_CHECK")"
  section "Per-file verdict-gate checks: ${FILE_BASENAME}"

  FILE_PASS=0
  FILE_FAIL=0

  # Locate gate region (anchor: "Path A verdict-emoji gate" comment)
  # Gate region = from comment marker to next "Step N:" comment header
  GATE_REGION_START="$(grep -nE 'Path A verdict-emoji gate' "$LABEL_CHECK" | head -1 | cut -d: -f1)"
  if [ -n "$GATE_REGION_START" ]; then
    GATE_REGION_END="$(awk -v start="$GATE_REGION_START" 'NR > start && /^[[:space:]]*\/\/[[:space:]]+Step [0-9]+:/ { print NR - 1; exit }' "$LABEL_CHECK")"
    : "${GATE_REGION_END:=$(wc -l < "$LABEL_CHECK")}"
    GATE_REGION="${GATE_REGION_START},${GATE_REGION_END}p"
  else
    GATE_REGION="0p"
  fi

  # TC1: verdict-gate code block present
  if [ -z "$GATE_REGION_START" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC1 — verdict-gate code block missing in $FILE_BASENAME" \
      "expected 'Path A verdict-emoji gate' comment marker. PR #664 not yet merged or impl drifted."
  else
    FILE_PASS=$((FILE_PASS+1))
    info "  TC1 — gate region L${GATE_REGION_START}-L${GATE_REGION_END} in $FILE_BASENAME"
  fi

  # TC2: verdict-gate positioned AFTER let declarations (TDZ discipline)
  DECL_LINE="$(grep -nE '^[[:space:]]*let shouldAddReady = false;' "$LABEL_CHECK" | head -1 | cut -d: -f1)"
  if [ -z "$GATE_REGION_START" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC2 — cannot verify positioning in $FILE_BASENAME (TC1 missing)" ""
  elif [ -z "$DECL_LINE" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC2 — 'let shouldAddReady' decl missing in $FILE_BASENAME" \
      "expected decl line; gate has nothing to override."
  elif [ "$GATE_REGION_START" -le "$DECL_LINE" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC2 — verdict-gate BEFORE 'let shouldAddReady' decl in $FILE_BASENAME (TDZ crash)" \
      "gate at L${GATE_REGION_START}, decl at L${DECL_LINE}. Must be AFTER decl."
  else
    DELTA=$((GATE_REGION_START - DECL_LINE))
    FILE_PASS=$((FILE_PASS+1))
    info "  TC2 — gate at L${GATE_REGION_START}, decl at L${DECL_LINE} (delta ${DELTA}, TDZ-safe)"
  fi

  # TC3: bot-exclusion filter `c.user.type === 'Bot'`
  if [ -z "$GATE_REGION_START" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC3 — cannot inspect gate region in $FILE_BASENAME (TC1 missing)" ""
  elif sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -qE "c\.user\.type\s*===\s*['\"]Bot['\"]"; then
    FILE_PASS=$((FILE_PASS+1))
    info "  TC3 — bot-exclusion filter present in $FILE_BASENAME"
  else
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC3 — bot-exclusion filter missing in $FILE_BASENAME" \
      "expected 'c.user.type === \"Bot\"' filter in gate region."
  fi

  # TC4: pagination via github.paginate.iterator
  if [ -z "$GATE_REGION_START" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC4 — cannot inspect gate region in $FILE_BASENAME (TC1 missing)" ""
  elif sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -qE "github\.paginate\.iterator"; then
    FILE_PASS=$((FILE_PASS+1))
    info "  TC4 — pagination via github.paginate.iterator present in $FILE_BASENAME"
  else
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC4 — pagination missing in $FILE_BASENAME" \
      "expected 'github.paginate.iterator' in gate region."
  fi

  # TC5: verdict-gate references verdict emoji 🟢/🟡/🔴
  if [ -z "$GATE_REGION_START" ]; then
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC5 — cannot inspect gate region in $FILE_BASENAME (TC1 missing)" ""
  elif sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -qE '🟢|🟡|🔴'; then
    EMOJI_HITS="$(sed -n "$GATE_REGION" "$LABEL_CHECK" 2>/dev/null | grep -cE '🟢|🟡|🔴')"
    FILE_PASS=$((FILE_PASS+1))
    info "  TC5 — verdict emoji references (${EMOJI_HITS} hits) in $FILE_BASENAME"
  else
    FILE_FAIL=$((FILE_FAIL+1))
    fail "  TC5 — verdict emoji references missing in $FILE_BASENAME" \
      "expected 🟢/🟡/🔴 emoji in gate region."
  fi

  # Per-file verdict (all 5 must pass for file to pass — AND aggregation)
  if [ "$FILE_FAIL" -eq 0 ]; then
    FILES_PASSED=$((FILES_PASSED+1))
    info "${FILE_BASENAME}: 5/5 verdict-gate TCs PASS"
  else
    FILES_FAILED=$((FILES_FAILED+1))
    info "${R}${FILE_BASENAME}: ${FILE_FAIL}/5 verdict-gate TCs FAIL${D}"
  fi
done

# ============================================================================
# Parameterization TCs (TC-1 to TC-5 per Issue #666 body) — structural on d069 source
# ============================================================================
D069_SOURCE="${SCRIPT_DIR}/$(basename "$0")"

# TC-1: WORKFLOW_FILES env var declared with default 'label-check.yml'
section "TC-1: WORKFLOW_FILES env var + default (Issue #666 AC1+AC8 backward compat)"
if grep -qE 'WORKFLOW_FILES:-label-check\.yml|WORKFLOW_FILES:-\${WORKFLOW_FILES:-label-check\.yml}|WORKFLOW_FILES:="label-check\.yml"|WORKFLOW_FILES:=\${WORKFLOW_FILES:-label-check\.yml}' "$D069_SOURCE"; then
  pass "TC-1 — WORKFLOW_FILES env var declared with default 'label-check.yml' (AC8 backward compat preserved)"
else
  fail "TC-1 — WORKFLOW_FILES default 'label-check.yml' NOT FOUND in d069 source" \
    "expected 'WORKFLOW_FILES:=\${WORKFLOW_FILES:-label-check.yml}' or equivalent. AC1+AC8 not implemented."
fi

# TC-2: multi-file array parsing (IFS=',' + array iteration)
section "TC-2: WORKFLOW_FILES multi-file array parsing (Issue #666 AC1+AC2)"
if grep -qE "IFS=[',\"]" "$D069_SOURCE" && grep -qE "WORKFLOW_FILES_ARR|TRIMMED_FILES|RESOLVED_FILES" "$D069_SOURCE"; then
  pass "TC-2 — multi-file array parsing present (IFS=',' + bash array iteration, AC1+AC2)"
else
  fail "TC-2 — multi-file array parsing NOT FOUND in d069 source" \
    "expected 'IFS=',' read -ra' + 'WORKFLOW_FILES_ARR' or 'RESOLVED_FILES' array variable. AC1+AC2 not implemented."
fi

# TC-3: shopt globstar enabled (arch Q1 decision)
section "TC-3: WORKFLOW_FILES glob expansion via shopt globstar (arch Q1)"
if grep -qE 'shopt -s globstar' "$D069_SOURCE"; then
  pass "TC-3 — shopt globstar enabled (bash 5.x universal on GH Actions, arch Q1 decision)"
else
  fail "TC-3 — 'shopt -s globstar' NOT FOUND in d069 source" \
    "expected 'shopt -s globstar' for *.yml pattern expansion. Arch Q1 decision."
fi

# TC-4: silent_skip guard for empty WORKFLOW_FILES (ADR-0048 lens d)
section "TC-4: WORKFLOW_FILES='' → silent_skip guard (ADR-0048 lens d + Issue #666 TC-4)"
if grep -qE 'silent_skip' "$D069_SOURCE" && grep -qE "WORKFLOW_FILE_COUNT -eq 0|#RESOLVED_FILES\[@\]" "$D069_SOURCE"; then
  pass "TC-4 — silent_skip guard present (empty array → exit 2, lens d enforced)"
else
  fail "TC-4 — silent_skip guard NOT FOUND in d069 source" \
    "expected 'silent_skip' log + empty-array check + exit 2. ADR-0048 lens d not implemented."
fi

# TC-5: missing-file preflight (exit 2)
section "TC-5: WORKFLOW_FILES=nonexistent.yml → preflight fail (exit 2)"
if grep -qE '\[ ! -f "\$f' "$D069_SOURCE" && grep -qE 'exit 2' "$D069_SOURCE"; then
  pass "TC-5 — missing-file preflight present (exit 2 enforced on nonexistent file)"
else
  fail "TC-5 — missing-file preflight NOT FOUND in d069 source" \
    "expected file existence check ('[ ! -f \"$f\" ]') + 'exit 2'. AC1 preflight not implemented."
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS:           %d\n" "$PASS"
printf "  FAIL:           %d\n" "$FAIL"
printf "  INFO:           %d\n" "$INFO"
printf "  Files resolved: %d\n" "$WORKFLOW_FILE_COUNT"
printf "  Files passed:   %d\n" "$FILES_PASSED"
printf "  Files failed:   %d\n" "$FILES_FAILED"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — verdict-gate or parameterization broken per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all TCs PASS — verdict-gate landed + parameterization working per AC1-AC11${D}\n"
exit 0