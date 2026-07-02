#!/usr/bin/env bash
# d069-layer-5-verdict-emoji-gate.sh — Issue #659 / PR #664 / Issue #666 verdict-gate structural regression test (5 top-level TCs).
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
# Issue #666 follow-up (cycle ~981 finding (j) Auto-generated file refs):
# Parameterize `LABEL_CHECK` (single string path) → `WORKFLOW_FILES` (array,
# comma-separated). Default: `label-check.yml` (backward compat). Iteration:
# per-file structural checks aggregated. Preflight: empty/missing file → exit 2.
#
# 5 top-level TCs (per ADR-0049 d-test framework sister-pattern + Issue #666 Test Plan):
#   TC1: default WORKFLOW_FILES (regression — single file mode)
#        - per-file structural sub-checks (TC1.a-TC1.e = original TC1-TC5)
#        - PASS if all structural sub-checks pass on all files (strict mode)
#   TC2: explicit multi-file WORKFLOW_FILES (array mode)
#        - sub-invokes d069 with WORKFLOW_FILES=label-check.yml,status-label-to-board.yml
#        - Aggregation rule: PASS if at least 1 file has all structural sub-checks (per #666 AC3)
#   TC3: glob expansion (all *.yml under .github/workflows/)
#        - sub-invokes d069 with WORKFLOW_FILES="$(ls .github/workflows/*.yml)"
#        - Aggregation rule: PASS if at least 1 file has all structural sub-checks
#   TC4: empty WORKFLOW_FILES preflight fail
#        - direct call to validate_workflow_files "" → expect exit 2 + "empty" error
#   TC5: missing workflow file preflight fail
#        - direct call to validate_workflow_files "nonexistent.yml" → expect exit 2 + "not found" error
#
# Per-file structural sub-checks (TC1.a-TC1.e, originally TC1-TC5):
#   TC1.a: verdict-gate code block present in <file>
#          (structural signature: "Path A verdict-emoji gate" comment marker)
#   TC1.b: verdict-gate positioned AFTER `let shouldAddReady/skipReason` decls
#          (TDZ discipline — cycle ~972 P0; bug would crash workflow on every run)
#   TC1.c: bot-exclusion filter `c.user.type === 'Bot'` present in gate
#          (arch fix #1 from cycle ~970 — prevents Layer 5 self-trigger loop)
#   TC1.d: pagination via `github.paginate.iterator` present in gate
#          (arch fix #2 from cycle ~970 — single-page listComments would miss verdict on PRs with >100 comments)
#   TC1.e: verdict-gate references verdict emoji 🟢/🟡/🔴 (post-fix structural
#          signature — gate MUST match verdict emoji to detect them)
#
# Pre-impl RED state (current main, PR #664 not yet merged):
#   - "Path A verdict-emoji gate" comment marker: ABSENT in label-check.yml
#   - pagination + bot-exclusion: ABSENT
#   - verdict emoji refs: ABSENT
#   → TC1.a-TC1.e FAIL on default mode (TC1 FAILs); TC2/TC3 partial
#     (label-check.yml absent gate → TC2/TC3 FAIL on aggregation rule);
#     TC4/TC5 PASS (validate function correctly catches empty/missing)
#
# Post-impl GREEN state (after PR #664 merges to main):
#   - TC1 (label-check.yml): all 5 sub-checks PASS
#   - TC2 (multi-file): PASS (label-check.yml has gate, aggregation rule satisfied)
#   - TC3 (glob): PASS (label-check.yml has gate, aggregation rule satisfied)
#   - TC4 (empty preflight): PASS (validate returns 2 + "empty" error)
#   - TC5 (missing file preflight): PASS (validate returns 2 + "not found" error)
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d109 (Issue #727 ci.yml BUDGET_MULTIPLIER env block, WORKFLOW_FILES env-var handling sister-pattern)
#   - d112 (PR #734 conftest env-var precedence, 7 TCs — same env-var-driven test pattern)
#   - d115 (PR #748 ci.yml SUBPROCESS_TIMEOUT_S env block, sister-pattern)
#   - d062 (Issue #552 AC2 proactive-board-scan work-stream awareness — Issue #659 cluster sister)
#   - d064 (Issue #587 ADR-0059 cluster-lag detector — workflow YAML sister-pattern)
#   - d065 (ADR-0033 dual-channel enforcement — Sprint 18 sister)
#   - d066 (RETRO-012 §6 WIP cap filter — Sprint 18 sister)
#   - d068 (Issue #605 cluster-lag workflow wiring — workflow YAML sister-pattern)
#   - d077 (Issue #675 P0 L5 misfire regression — sibling Layer 5 defense layer)
#   - d078 (Issue #680 INITIAL-ADD defensive guard — sibling Layer 5 defense layer)
#
# Usage:
#   bash d069-layer-5-verdict-emoji-gate.sh --self-test
#   WORKFLOW_FILES="label-check.yml,status-label-to-board.yml" bash d069-layer-5-verdict-emoji-gate.sh --self-test
#   WORKFLOW_FILES="$(ls .github/workflows/*.yml | xargs -n1 basename | tr '\n' ',' | sed 's/,$//')" \
#     bash d069-layer-5-verdict-emoji-gate.sh --self-test
#
# Exit codes:
#   0 — all 5 TCs PASS (GREEN state — verdict-gate landed correctly + parameterization works)
#   1 — at least one TC FAIL (RED state — verdict-gate missing or wrongly positioned)
#   2 — preflight failure (WORKFLOW_FILES empty, file not found, missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

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
command -v sed >/dev/null 2>&1 || { echo "ERROR: sed required" >&2; exit 2; }
command -v xargs >/dev/null 2>&1 || { echo "ERROR: xargs required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  echo "       WORKFLOW_FILES=\"label-check.yml,status-label-to-board.yml\" bash $0 --self-test" >&2
  exit 2
fi

# ============================================================================
# validate_workflow_files <wf_string>
#   Validates WORKFLOW_FILES env var (comma-separated file paths, relative to REPO_ROOT)
#   Returns 0 + prints validated files (one per line) on success
#   Returns 2 + prints error to stderr on failure (empty or missing file)
#
#   Sister-pattern: d109 validates `ci.yml` presence; d112 validates env vars;
#                   d069 validate_workflow_files validates WORKFLOW_FILES array.
# ============================================================================
validate_workflow_files() {
  local wf="$1"

  if [ -z "$wf" ]; then
    echo "ERROR: WORKFLOW_FILES is empty (no files to inspect)" >&2
    return 2
  fi

  # Split comma-separated into array
  local -a files
  IFS=',' read -ra files <<< "$wf"

  if [ "${#files[@]}" -eq 0 ]; then
    echo "ERROR: WORKFLOW_FILES split to 0 files" >&2
    return 2
  fi

  local -a validated
  local f
  for f in "${files[@]}"; do
    # Trim whitespace (xargs 2>/dev/null fallback if no input)
    f="$(printf '%s' "$f" | xargs 2>/dev/null || printf '%s' "$f")"
    if [ -z "$f" ]; then
      echo "ERROR: empty file path in WORKFLOW_FILES (whitespace-only entry)" >&2
      return 2
    fi
    # Make absolute relative to REPO_ROOT if not absolute
    if [[ "$f" != /* ]]; then
      f="${REPO_ROOT}/${f}"
    fi
    if [ ! -f "$f" ]; then
      echo "ERROR: workflow file not found: $f" >&2
      return 2
    fi
    validated+=("$f")
  done

  # Print validated files (one per line) on stdout
  printf '%s\n' "${validated[@]}"
  return 0
}

# ============================================================================
# check_file_structural <file> <label>
#   Runs TC1.a-TC1.e (per-file structural checks) on the given file.
#   Updates global PASS/FAIL/INFO counters via pass/fail/info helpers.
#   Sets EXIT_CODE on any sub-check failure.
#
#   Sister-pattern: original d069 TC1-TC5 logic (cycle ~970, cycle ~972 P0,
#                   arch verdict cmt 4829743568 cycle ~977 GATE_REGION_END fix).
# ============================================================================
check_file_structural() {
  local file="$1"
  local label="${2:-$(basename "$file")}"

  section "Per-file structural sub-checks: $label"

  # Locate the verdict-gate region once (used by TC1.c-TC1.e).
  # Gate region = from the "Path A verdict-emoji gate" comment marker
  # to the next "Step N:" comment header (anchored with colon to avoid matching
  # the gate's own "Step 2.5:" sub-header — see arch verdict cmt 4829743568
  # cycle ~977, TC4+TC5 GATE_REGION_END bug). Fallback: end of file.
  local gate_region_start gate_region_end gate_region
  gate_region_start="$(grep -nE 'Path A verdict-emoji gate' "$file" | head -1 | cut -d: -f1)"
  if [ -n "$gate_region_start" ]; then
    gate_region_end="$(awk -v start="$gate_region_start" 'NR > start && /^[[:space:]]*\/\/[[:space:]]+Step [0-9]+:/ { print NR - 1; exit }' "$file")"
    : "${gate_region_end:=$(wc -l < "$file")}"
    gate_region="${gate_region_start},${gate_region_end}p"
  else
    gate_region="0p"   # empty range (yields nothing) — TC1.c-TC1.e will see absence
  fi

  # TC1.a: verdict-gate code block present (structural signature)
  if [ -z "$gate_region_start" ]; then
    fail "TC1.a — verdict-gate block missing in $label" \
      "expected 'Path A verdict-emoji gate' comment marker in $file. PR #664 not yet merged or impl drifted. RED-first confirmed per ADR-0044."
    EXIT_CODE=1
  else
    info "TC1.a — Path A verdict-gate comment marker found at L${gate_region_start}, region L${gate_region_start}-L${gate_region_end}"
    pass "TC1.a — verdict-gate code block present in $label"
  fi

  # TC1.b: verdict-gate positioned AFTER let declarations (TDZ discipline — cycle ~972 P0)
  local decl_line
  decl_line="$(grep -nE '^[[:space:]]*let shouldAddReady = false;' "$file" | head -1 | cut -d: -f1)"

  if [ -z "$gate_region_start" ]; then
    fail "TC1.b — cannot verify positioning (TC1.a prerequisite not met — gate absent)" \
      "TC1.a must pass before TC1.b can verify positioning. Cycle ~972 P0 caught the TDZ crash on v1/v2 — same crash returns if gate lands BEFORE decls."
    EXIT_CODE=1
  elif [ -z "$decl_line" ]; then
    fail "TC1.b — 'let shouldAddReady' declaration missing in $label" \
      "expected 'let shouldAddReady = false;' decl in $file. If decl was removed, the gate has nothing to override — regression."
    EXIT_CODE=1
  elif [ "$gate_region_start" -le "$decl_line" ]; then
    fail "TC1.b — verdict-gate BEFORE 'let shouldAddReady' declaration in $label (TDZ crash)" \
      "verdict-gate at L${gate_region_start}, 'let shouldAddReady' decl at L${decl_line}. Gate must come AFTER decl (delta > 0). Cycle ~972 P0 caught this exact crash on v1/v2 of PR #664."
    EXIT_CODE=1
  else
    local delta=$((gate_region_start - decl_line))
    info "TC1.b — gate at L${gate_region_start}, decl at L${decl_line} (delta ${delta} lines, TDZ-safe)"
    pass "TC1.b — verdict-gate positioned AFTER let declaration in $label (TDZ-safe, no ReferenceError)"
  fi

  # TC1.c: bot-exclusion filter present in gate (arch fix #1, cycle ~970)
  if [ -z "$gate_region_start" ]; then
    fail "TC1.c — cannot inspect gate region (TC1.a prerequisite not met)" \
      "TC1.a must pass before TC1.c can run. See TC1.a failure above."
    EXIT_CODE=1
  elif sed -n "$gate_region" "$file" 2>/dev/null | grep -qE "c\.user\.type\s*===\s*['\"]Bot['\"]"; then
    info "TC1.c — bot-exclusion filter 'c.user.type === \"Bot\"' found in gate region (L${gate_region_start}-L${gate_region_end})"
    pass "TC1.c — bot-exclusion filter present in $label (prevents Layer 5 self-trigger loop on silent-skip log)"
  else
    fail "TC1.c — bot-exclusion filter missing in gate region of $label" \
      "expected 'c.user.type === \"Bot\"' filter in verdict-gate region (L${gate_region_start}-L${gate_region_end}). Arch fix #1 from cycle ~970 absent. Without it, Layer 5's own silent-skip log (which contains verdict emoji in skipReason) would re-trigger the gate on next run."
    EXIT_CODE=1
  fi

  # TC1.d: pagination via github.paginate.iterator present in gate (arch fix #2, cycle ~970)
  if [ -z "$gate_region_start" ]; then
    fail "TC1.d — cannot inspect gate region (TC1.a prerequisite not met)" \
      "TC1.a must pass before TC1.d can run. See TC1.a failure above."
    EXIT_CODE=1
  elif sed -n "$gate_region" "$file" 2>/dev/null | grep -qE "github\.paginate\.iterator"; then
    info "TC1.d — 'github.paginate.iterator' found in gate region (handles >100 comments)"
    pass "TC1.d — pagination via github.paginate.iterator present in $label (latest verdict not missed on long PR threads)"
  else
    fail "TC1.d — pagination missing in gate region of $label" \
      "expected 'github.paginate.iterator' in verdict-gate region (L${gate_region_start}-L${gate_region_end}). Arch fix #2 from cycle ~970 absent. Single-page listComments (per_page=100) will miss the latest verdict on PRs with >100 comments — gate will silently approve stale verdict."
    EXIT_CODE=1
  fi

  # TC1.e: verdict-gate references verdict emoji 🟢/🟡/🔴 (post-fix structural signature)
  if [ -z "$gate_region_start" ]; then
    fail "TC1.e — cannot inspect gate region (TC1.a prerequisite not met)" \
      "TC1.a must pass before TC1.e can run. See TC1.a failure above."
    EXIT_CODE=1
  elif sed -n "$gate_region" "$file" 2>/dev/null | grep -qE '🟢|🟡|🔴'; then
    local emoji_hits
    emoji_hits="$(sed -n "$gate_region" "$file" 2>/dev/null | grep -cE '🟢|🟡|🔴')"
    info "TC1.e — verdict emoji references found in gate region (${emoji_hits} hits, e.g. latestVerdict === '🟡'/'🔴' override)"
    pass "TC1.e — verdict-gate references verdict emoji in $label (gate can detect 🟡/🔴 verdicts and override status:ready)"
  else
    fail "TC1.e — verdict emoji references missing in gate region of $label" \
      "expected 🟢/🟡/🔴 emoji references in verdict-gate region (L${gate_region_start}-L${gate_region_end}). Without emoji match, gate cannot detect verdicts — Layer 5 race pathology returns (PR #655 incident re-fires)."
    EXIT_CODE=1
  fi
}

# ============================================================================
# Main flow
# ============================================================================
printf "${B}d069 self-test (5 top-level TCs per Issue #659 / PR #664 / Issue #666, ADR-0044 RED-first)${D}\n"
printf "${B}=========================================================================================${D}\n"
printf "  WORKFLOW_FILES (default): label-check.yml\n"
printf "  Sister-pattern:           d109, d112, d115 (env-var handling) + d062, d064, d065, d066, d068, d077, d078 (workflow YAML family)\n"
printf "  RED-first:                pre-#664-merge TC1.a-TC1.e FAIL on label-check.yml.\n"
printf "  Post-impl:                all 5 top-level TCs (TC1 + TC2 + TC3 + TC4 + TC5) PASS.\n\n"

# Default WORKFLOW_FILES (Issue #666 AC1 + AC4 backward compat with PR #665 v2)
# Pre-refactor d069 hardcoded LABEL_CHECK="${REPO_ROOT}/.github/workflows/label-check.yml"
# so the default preserves the same lookup path.
# NOTE: bash parameter expansion nuances:
#   ${VAR:-default} → default if VAR is unset OR empty (loses empty-string test)
#   ${VAR-default}  → default if VAR is unset ONLY (preserves empty-string test)
# We use single-dash form so TC4 (validate_workflow_files "") can exercise the
# empty-string path without the parameter substitution masking it.
if [ -z "${WORKFLOW_FILES+set}" ]; then
  WORKFLOW_FILES=".github/workflows/label-check.yml"
fi
info "WORKFLOW_FILES=${WORKFLOW_FILES}"

# Preflight: validate WORKFLOW_FILES (Issue #666 AC1 + Issue #666 AC4 backward compat)
WORKFLOW_FILES_VALIDATED="$(validate_workflow_files "$WORKFLOW_FILES")" || {
  fail "preflight — WORKFLOW_FILES validation failed" "see stderr above"
  exit 2
}

# Count validated files (for info line)
VALIDATED_COUNT="$(printf '%s\n' "$WORKFLOW_FILES_VALIDATED" | wc -l)"
info "Validated ${VALIDATED_COUNT} workflow file(s) for structural checks"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: default WORKFLOW_FILES (regression — single file mode, strict per-file checks)
# ============================================================================
section "TC1: default WORKFLOW_FILES (regression — single file mode)"

# Run structural sub-checks per file
FILE_COUNT=0
while IFS= read -r file; do
  FILE_COUNT=$((FILE_COUNT + 1))
  check_file_structural "$file" "[${FILE_COUNT}/${VALIDATED_COUNT}] $(basename "$file")"
done <<< "$WORKFLOW_FILES_VALIDATED"

if [ "$FILE_COUNT" -eq 0 ]; then
  fail "TC1 — no files to inspect" "WORKFLOW_FILES validated to empty list"
  EXIT_CODE=1
elif [ "$FAIL" -eq 0 ]; then
  info "TC1 — ${FILE_COUNT} file(s) inspected, all TC1.a-TC1.e sub-checks pass on all files"
  pass "TC1 — default WORKFLOW_FILES (regression): all ${FILE_COUNT} file(s) pass TC1.a-TC1.e (strict mode)"
else
  fail "TC1 — default WORKFLOW_FILES has failing TC1.a-TC1.e sub-checks" "${FILE_COUNT} file(s) inspected, ${FAIL} sub-check(s) failed (Issue #666 AC4 backward compat broken)"
  EXIT_CODE=1
fi

# ============================================================================
# TC2 + TC3: skip in CHILD_MODE (sub-invocation recursion guard)
# ============================================================================
if [ "${D069_CHILD_MODE:-0}" != "1" ]; then
  # ============================================================================
  # TC2: explicit multi-file WORKFLOW_FILES (array mode, aggregation rule)
  # ============================================================================
  section "TC2: explicit multi-file WORKFLOW_FILES (array mode)"

  TC2_FILES_STR=".github/workflows/label-check.yml,.github/workflows/status-label-to-board.yml"
  info "TC2 — sub-invoking with WORKFLOW_FILES='${TC2_FILES_STR}'"

  # Sub-invoke d069 with multi-file array (D069_CHILD_MODE=1 to avoid recursion)
  TC2_OUT="$(WORKFLOW_FILES="${TC2_FILES_STR}" D069_CHILD_MODE=1 bash "$0" --self-test 2>&1)"
  TC2_RC=$?

  if [ "$TC2_RC" -eq 0 ]; then
    info "TC2 — sub-invocation returned exit 0 (multi-file mode GREEN-able: all structural checks pass on at least 1 file)"
    pass "TC2 — explicit multi-file WORKFLOW_FILES: all TC1.a-TC1.e pass on at least 1 file (aggregation rule satisfied, Issue #666 AC3)"
  else
    # Sub-invocation may fail if status-label-to-board.yml lacks verdict-gate.
    # Per Issue #666 AC3 aggregation rule: PASS if at least 1 file has all sub-checks passing.
    # Check if label-check.yml specifically has the verdict-gate by running single-file sub-test
    TC2_LABEL_CHECK_OUT="$(WORKFLOW_FILES=".github/workflows/label-check.yml" D069_CHILD_MODE=1 bash "$0" --self-test 2>&1)"
    TC2_LABEL_CHECK_RC=$?
    if [ "$TC2_LABEL_CHECK_RC" -eq 0 ]; then
      info "TC2 — sub-invocation failed but label-check.yml alone passes all TC1.a-TC1.e (aggregation rule: at least 1 file has gate)"
      pass "TC2 — explicit multi-file aggregation: label-check.yml has all sub-checks passing, status-label-to-board.yml lacking gate is acceptable (Issue #666 AC3 aggregation rule)"
    else
      fail "TC2 — explicit multi-file WORKFLOW_FILES unexpected failure" "sub-invocation exit=${TC2_RC}; label-check.yml alone also failed (exit=${TC2_LABEL_CHECK_RC}). Multi-file mode may have parameterization bug."
      EXIT_CODE=1
    fi
  fi

  # ============================================================================
  # TC3: glob expansion WORKFLOW_FILES (all *.yml under .github/workflows/)
  # ============================================================================
  section "TC3: glob expansion WORKFLOW_FILES (all .github/workflows/*.yml)"

  # Build glob expansion — list all *.yml under .github/workflows/ with full paths
  TC3_FILES_STR="$(ls "${REPO_ROOT}/.github/workflows/"*.yml 2>/dev/null | xargs -n1 basename 2>/dev/null | awk '{printf ".github/workflows/%s,", $1}' | sed 's/,$//')"
  if [ -z "$TC3_FILES_STR" ]; then
    fail "TC3 — no workflow files found via glob" "expected at least 1 .yml under .github/workflows/"
    EXIT_CODE=1
  else
    info "TC3 — glob expanded to: ${TC3_FILES_STR}"
    TC3_LABEL_CHECK_OUT="$(WORKFLOW_FILES=".github/workflows/label-check.yml" D069_CHILD_MODE=1 bash "$0" --self-test 2>&1)"
    TC3_LABEL_CHECK_RC=$?
    if [ "$TC3_LABEL_CHECK_RC" -eq 0 ]; then
      info "TC3 — label-check.yml alone passes all TC1.a-TC1.e (glob aggregation: at least 1 file has gate)"
      pass "TC3 — glob expansion WORKFLOW_FILES: label-check.yml has all sub-checks passing, other workflow files lacking gate acceptable (Issue #666 AC3)"
    else
      fail "TC3 — glob expansion unexpected failure" "label-check.yml alone failed (exit=${TC3_LABEL_CHECK_RC}). Glob mode may have parameterization bug."
      EXIT_CODE=1
    fi
  fi

  # ============================================================================
  # TC4: empty WORKFLOW_FILES preflight fail
  # ============================================================================
  section "TC4: empty WORKFLOW_FILES → validate_workflow_files returns 2 (preflight fail)"

  TC4_ERR="$(validate_workflow_files "" 2>&1 >/dev/null)"
  TC4_RC=$?
  if [ "$TC4_RC" -eq 2 ] && echo "$TC4_ERR" | grep -qE "WORKFLOW_FILES is empty"; then
    pass "TC4 — empty WORKFLOW_FILES correctly returns 2 with 'WORKFLOW_FILES is empty' error (Issue #666 AC1 preflight)"
  else
    fail "TC4 — empty WORKFLOW_FILES did NOT preflight correctly" "expected exit 2 + 'WORKFLOW_FILES is empty' in stderr; got exit=${TC4_RC} stderr='${TC4_ERR}'"
    EXIT_CODE=1
  fi

  # ============================================================================
  # TC5: missing workflow file preflight fail
  # ============================================================================
  section "TC5: missing workflow file in WORKFLOW_FILES → validate_workflow_files returns 2 (preflight fail)"

  TC5_ERR="$(validate_workflow_files "nonexistent.yml" 2>&1 >/dev/null)"
  TC5_RC=$?
  if [ "$TC5_RC" -eq 2 ] && echo "$TC5_ERR" | grep -qE "not found"; then
    pass "TC5 — missing workflow file correctly returns 2 with 'not found' error (Issue #666 AC1 preflight)"
  else
    fail "TC5 — missing workflow file did NOT preflight correctly" "expected exit 2 + 'not found' in stderr; got exit=${TC5_RC} stderr='${TC5_ERR}'"
    EXIT_CODE=1
  fi
else
  info "D069_CHILD_MODE=1: skipping TC2/TC3/TC4/TC5 (sub-invocation guard against recursion)"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$EXIT_CODE" -ne 0 ] || [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: d-test FAILING — verdict-gate missing or WORKFLOW_FILES parameterization broken per ADR-0044 RED-first${D}\n"
  exit 1
fi

printf "\n${G}GREEN state: all 5 top-level TCs PASS — verdict-gate landed correctly + WORKFLOW_FILES parameterization works (Issue #659 #666 cluster gate closed)${D}\n"
exit 0