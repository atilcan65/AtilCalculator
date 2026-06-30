#!/usr/bin/env bash
# d095-post-org-migration-clone-urls.sh — Sprint 22 PIVOT Faz 2.4 regression guard.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT (Issue #708) Faz 2.1 completed: `atilcan65/AtilCalculator`,
# `atilcan65/dev-studio-template`, `atilcan65/dev-studio-launcher` transferred
# to the `atilproject` org. Faz 2.4 (dev lane) requires updating functional
# scripts + d-test MOCK fixtures that hardcoded `atilcan65/{repo}` references.
#
# This d-test guards against:
#   - TC1: Any Category A functional script still referencing `atilcan65/AtilCalculator` (regression)
#   - TC2: Any Category A test script still referencing `atilcan65/AtilCalculator` (regression)
#   - TC3: Category A functional scripts missing the `atilproject/AtilCalculator` reference (negative pattern)
#   - TC4: Category A test scripts missing the `atilproject/AtilCalculator` reference (negative pattern)
#
# Pre-impl RED state (current main as of 2026-06-30, pre-Faz-2.4 migration):
#   - TC1: 4+ functional scripts have `atilcan65/AtilCalculator` → FAIL
#   - TC2: 9+ d-test fixtures have `atilcan65/AtilCalculator` → FAIL
#   - TC3: 4 functional scripts are missing `atilproject/AtilCalculator` → FAIL
#   - TC4: 9 d-test fixtures are missing `atilproject/AtilCalculator` → FAIL
#   → 4/4 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after Faz 2.4 lands + PR squash):
#   - TC1: 0 functional scripts reference `atilcan65/AtilCalculator` ✅
#   - TC2: 0 d-test fixtures reference `atilcan65/AtilCalculator` ✅
#   - TC3: 4 functional scripts reference `atilproject/AtilCalculator` ✅
#   - TC4: 9 d-test fixtures reference `atilproject/AtilCalculator` ✅
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d069 (Issue #666 + PR #679 workflow-file scope parameterization, WORKFLOW_FILES array)
#   - d070 (Issue #637 + PR #704 dev-studio-init.sh template-rendering regression guard)
#   - d070b (Issue #693 + PR #703 init-prompt-ux regression guard)
#   - d091 (work-stream awareness regression guard)
#   - d093 (Issue #633 + PR #694 TEMPLATE-README.md polish regression guard)
#   - d094 (Issue #708 + PR #709 self-hosted runner migration regression guard)
#   - **d095 (this file) — Sprint 22 PIVOT Faz 2.4 post-org-migration clone URL regression guard**
#
# Sprint 22 PIVOT refs:
#   - Issue #708 §Faz 2.4 (dev lane, owner-blocked until Faz 2.1 transfer complete)
#   - Issue #708 §PREP comment 4841268188 (110 files catalog, MIGRATE/PRESERVE categorization)
#   - Sprint 22 PIVOT plan v3 §Faz 2.4 (peer actions `@developer`)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern, ≥3 TCs minimum)
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#
# Usage:
#   bash d095-post-org-migration-clone-urls.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — Faz 2.4 migration complete)
#   1 — at least one FAIL (RED state — migration incomplete)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
TESTS_DIR="${REPO_ROOT}/scripts/tests"

# Category A: functional scripts (MIGRATE scope — sprint 22 PIVOT Faz 2.4)
CATEGORY_A_SCRIPTS=(
  "${SCRIPTS_DIR}/cross-repo-close.sh"
  "${SCRIPTS_DIR}/cross-repo-scan.sh"
  "${SCRIPTS_DIR}/agent-watch.sh"
  "${SCRIPTS_DIR}/status-action-driver.sh"
)

# Category A: d-test files (MIGRATE scope — sprint 22 PIVOT Faz 2.4)
# These contain MOCK URL fixtures that need updating for post-Faz-2.4 CI runs
CATEGORY_A_TESTS=(
  "${TESTS_DIR}/d006-stable-event-ids.sh"
  "${TESTS_DIR}/d035-cross-repo-close.sh"
  "${TESTS_DIR}/d047-cross-repo-watcher.sh"
  "${TESTS_DIR}/d049-cross-repo-scan.sh"
  "${TESTS_DIR}/d053-pre-merge-4-cat-verification.sh"
  "${TESTS_DIR}/d054-closes-anchor-strict-format.sh"
  "${TESTS_DIR}/d064-cluster-lag.sh"
  "${TESTS_DIR}/d074-license-check.sh"
  "${TESTS_DIR}/d319-verdict-by-tdd-red-exclusion.sh"
)

# Post-Faz-2.1 expected org: atilproject (3 repos migrated to org per Issue #708 §Faz 2.1)
NEW_ORG="atilproject"
OLD_ORG="atilcan65"

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

command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d095 self-test (4 TCs per Issue #708 Sprint 22 PIVOT Faz 2.4, ADR-0044 RED-first)${D}\n"
printf "${B}============================================================================${D}\n"
printf "  Target dir:           %s\n" "$SCRIPTS_DIR"
printf "  Old org (regression): %s\n" "$OLD_ORG"
printf "  New org (expected):   %s\n" "$NEW_ORG"
printf "  Sister-pattern:       d069+d070+d070b+d091+d093+d094 (31-sister family post-sprint-22 PIVOT)\n"
printf "  Pre-impl RED:         4/4 TCs FAIL by design per ADR-0044\n"
printf "  Sprint 22 PIVOT:      Issue #708 Faz 2.4 (dev lane, post-Faz-2.1 owner transfer)\n"
printf "  File ownership:       scripts/ = dev+tester lane (agents propose via PR)\n\n"

# Preflight: verify each file exists
PREFLIGHT_FAIL=0
for f in "${CATEGORY_A_SCRIPTS[@]}" "${CATEGORY_A_TESTS[@]}"; do
  if [ ! -f "$f" ]; then
    fail "preflight — file missing: $f"
    PREFLIGHT_FAIL=1
  fi
done
if [ "$PREFLIGHT_FAIL" -ne 0 ]; then
  exit 2
fi

EXIT_CODE=0

# ============================================================================
# TC1: REGRESSION — Category A functional scripts MUST NOT reference atilcan65/AtilCalculator
# ============================================================================
section "TC1: AC1 — Category A functional scripts have no atilcan65/AtilCalculator refs (regression)"
TC1_REGRESSION_FILES=()
TC1_TOTAL_FILES=${#CATEGORY_A_SCRIPTS[@]}
for script in "${CATEGORY_A_SCRIPTS[@]}"; do
  if grep -qE "${OLD_ORG}/AtilCalculator" "$script"; then
    TC1_REGRESSION_FILES+=("$(basename "$script")")
  fi
done

if [ "${#TC1_REGRESSION_FILES[@]}" -eq 0 ]; then
  pass "TC1 — all ${TC1_TOTAL_FILES} Category A functional scripts have no ${OLD_ORG}/AtilCalculator refs"
else
  FILE_LIST=$(IFS=', '; echo "${TC1_REGRESSION_FILES[*]}")
  fail "TC1 — ${#TC1_REGRESSION_FILES[@]}/${TC1_TOTAL_FILES} Category A scripts still reference ${OLD_ORG}/AtilCalculator: ${FILE_LIST}" \
    "expected all Category A scripts migrated to ${NEW_ORG}/AtilCalculator per Sprint 22 PIVOT Faz 2.4."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: REGRESSION — Category A d-test fixtures MUST NOT reference atilcan65/AtilCalculator
# ============================================================================
section "TC2: AC2 — Category A d-test fixtures have no atilcan65/AtilCalculator refs (regression)"
TC2_REGRESSION_FILES=()
TC2_TOTAL_FILES=${#CATEGORY_A_TESTS[@]}
for testf in "${CATEGORY_A_TESTS[@]}"; do
  if grep -qE "${OLD_ORG}/AtilCalculator" "$testf"; then
    TC2_REGRESSION_FILES+=("$(basename "$testf")")
  fi
done

if [ "${#TC2_REGRESSION_FILES[@]}" -eq 0 ]; then
  pass "TC2 — all ${TC2_TOTAL_FILES} Category A d-test fixtures have no ${OLD_ORG}/AtilCalculator refs"
else
  FILE_LIST=$(IFS=', '; echo "${TC2_REGRESSION_FILES[*]}")
  fail "TC2 — ${#TC2_REGRESSION_FILES[@]}/${TC2_TOTAL_FILES} Category A d-tests still reference ${OLD_ORG}/AtilCalculator: ${FILE_LIST}" \
    "expected all MOCK URL fixtures migrated to ${NEW_ORG}/AtilCalculator per Sprint 22 PIVOT Faz 2.4."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: POSITIVE — Category A functional scripts MUST reference atilproject/AtilCalculator
# ============================================================================
section "TC3: AC3 — Category A functional scripts reference atilproject/AtilCalculator (positive)"
TC3_MISSING_FILES=()
for script in "${CATEGORY_A_SCRIPTS[@]}"; do
  if ! grep -qE "${NEW_ORG}/AtilCalculator" "$script"; then
    TC3_MISSING_FILES+=("$(basename "$script")")
  fi
done

if [ "${#TC3_MISSING_FILES[@]}" -eq 0 ]; then
  pass "TC3 — all ${#CATEGORY_A_SCRIPTS[@]} Category A functional scripts reference ${NEW_ORG}/AtilCalculator"
else
  FILE_LIST=$(IFS=', '; echo "${TC3_MISSING_FILES[*]}")
  fail "TC3 — ${#TC3_MISSING_FILES[@]} Category A scripts missing ${NEW_ORG}/AtilCalculator ref: ${FILE_LIST}" \
    "expected all Category A scripts to have at least one ${NEW_ORG}/AtilCalculator reference post-Faz-2.4."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: POSITIVE — Category A d-test fixtures MUST reference atilproject/AtilCalculator
# ============================================================================
section "TC4: AC4 — Category A d-test fixtures reference atilproject/AtilCalculator (positive)"
TC4_MISSING_FILES=()
for testf in "${CATEGORY_A_TESTS[@]}"; do
  if ! grep -qE "${NEW_ORG}/AtilCalculator" "$testf"; then
    TC4_MISSING_FILES+=("$(basename "$testf")")
  fi
done

if [ "${#TC4_MISSING_FILES[@]}" -eq 0 ]; then
  pass "TC4 — all ${#CATEGORY_A_TESTS[@]} Category A d-test fixtures reference ${NEW_ORG}/AtilCalculator"
else
  FILE_LIST=$(IFS=', '; echo "${TC4_MISSING_FILES[*]}")
  fail "TC4 — ${#TC4_MISSING_FILES[@]} Category A d-tests missing ${NEW_ORG}/AtilCalculator ref: ${FILE_LIST}" \
    "expected all MOCK URL fixtures to have at least one ${NEW_ORG}/AtilCalculator reference post-Faz-2.4."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Category A functional scripts:     %d\n" "$TC1_TOTAL_FILES"
printf "  Category A d-test fixtures:        %d\n" "$TC2_TOTAL_FILES"
printf "  Old org regression (TC1+TC2):      ✓ regression guard active\n"
printf "  New org positive (TC3+TC4):        ✓ positive verification active\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — Sprint 22 PIVOT Faz 2.4 migration not yet landed${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 4 TCs PASS — Sprint 22 PIVOT Faz 2.4 migration landed${D}\n"
exit 0
