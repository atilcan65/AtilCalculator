#!/usr/bin/env bash
# d100-self-hosted-perf-budgets.sh — Sprint 22 PIVOT Faz 1.2 env-aware perf budgets regression guard.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT (Issue #708) Faz 1.1: workflow files migrated to self-hosted
# runners at atilproject org. Lint & Test run on self-hosted VM (192.168.1.197)
# revealed env-side perf budget violations per arch v4 verdict cmt 4842471072:
#   - test_transcendental_p99_under_100ms   — got 206ms (budget 100ms)
#   - test_arithmetic_p99_under_50ms_still_holds — got 218ms (budget 50ms)
#   - test_search_latency_p95_under_100ms   — got 117ms (budget 100ms)
#   - test_e2e_*_keyboard — subprocess timeout at 1s (cold start > 1s)
#
# Root cause: budgets tuned for GH-hosted CPU + cold start, not env-aware.
# Arch recommendation (Option B per cmt 4842471072): env-aware perf budget × 2×
# multiplier for self-hosted + e2e subprocess timeout bumped to 10s.
#
# This d-test guards against regression by probing test files for env-aware
# patterns:
#   - TC1: env detection fixture (RUNNER_ENV/GITHUB_ACTIONS + runner label probe)
#   - TC2: perf budget multiplier 2× env-aware (transcendental/arithmetic/search)
#   - TC3: subprocess timeout bumped to 10s for self-hosted (cold start)
#   - TC4: GH-hosted budgets UNCHANGED (negative — no multiplier when github-hosted)
#
# Pre-impl RED state (current main as of 2026-06-30, post-#709 merge candidate):
#   - TC1: no env detection in any conftest.py → FAIL
#   - TC2: hardcoded budget in perf test files → FAIL
#   - TC3: hardcoded 8s/3s/0.5s/1s subprocess timeouts → FAIL
#   - TC4: no explicit github-hosted branch (no env detection at all) → FAIL
#   → 4/4 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state:
#   - TC1: env detection fixture present (detect_runner_env() helper) ✅
#   - TC2: BUDGET_MULTIPLIER=2 on self-hosted, applied in perf tests ✅
#   - TC3: timeout=10 on self-hosted subprocess paths ✅
#   - TC4: GH-hosted branch preserves strict budget (no multiplier) ✅
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d094 (Sprint 22 PIVOT Faz 1.1 self-hosted runner migration)
#   - d095 (Sprint 22 PIVOT Faz 2.4 post-org-migration clone URLs)
#   - d096 (S21-006 soul files template)
#   - d076 (label-check workflow regression guard)
#
# Sprint 22 PIVOT refs:
#   - Issue #708 (Sprint 22 PIVOT kickoff)
#   - PR #709 (Sprint 22 PIVOT Faz 1.1 — workflow update + d094)
#   - Arch v4 verdict cmt 4842471072 (Option B recommendation, dev lane fixup)
#   - ADR-0019 amendment 2 (perf budget baseline — env-agnostic, needs amendment 3)
#   - ADR-0019 amendment 3 CANDIDATE (env-aware perf budget, arch can file parallel)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern)
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#
# Usage:
#   bash d100-self-hosted-perf-budgets.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — env-aware perf budgets implemented)
#   1 — at least one FAIL (RED state — env-aware perf budgets NOT implemented)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TESTS_DIR="${REPO_ROOT}/tests"

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
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d100 self-test (4 TCs per Sprint 22 PIVOT Faz 1.2 arch Option B cmt 4842471072, ADR-0044 RED-first)${D}\n"
printf "${B}========================================================================================${D}\n"
printf "  Target dir:           %s\n" "$TESTS_DIR"

# ============================================================================
# TC1: env detection fixture present (RUNNER_ENV / GITHUB_ACTIONS + label probe)
# ============================================================================
section "TC1: env detection fixture (RUNNER_ENV/GITHUB_ACTIONS + runner label probe)"

ENV_DETECT_PRESENT=0

# Probe root conftest.py
ROOT_CONFTEST="${TESTS_DIR}/conftest.py"
if [ -f "$ROOT_CONFTEST" ]; then
  if grep -qE 'RUNNER_ENV|GITHUB_ACTIONS|detect_runner_env|runner_type|RUNNER_NAME' "$ROOT_CONFTEST"; then
    ENV_DETECT_PRESENT=1
    pass "tests/conftest.py references env detection (RUNNER_ENV/GITHUB_ACTIONS/detect_runner_env)"
  else
    info "tests/conftest.py exists but no env detection pattern"
  fi
else
  info "tests/conftest.py does not yet exist (root-level)"
fi

# Probe per-test conftest files
for sub in api web history; do
  SUBCONFTEST="${TESTS_DIR}/${sub}/conftest.py"
  if [ -f "$SUBCONFTEST" ]; then
    if grep -qE 'RUNNER_ENV|GITHUB_ACTIONS|detect_runner_env|runner_type|RUNNER_NAME' "$SUBCONFTEST"; then
      ENV_DETECT_PRESENT=1
      pass "tests/${sub}/conftest.py references env detection"
    fi
  fi
done

# Probe inline detection in test files (fallback)
INLINE_FILES=$(grep -rlE 'GITHUB_ACTIONS|RUNNER_ENV|detect_runner_env' "${TESTS_DIR}" --include="*.py" 2>/dev/null || true)
if [ -n "$INLINE_FILES" ] && [ "$ENV_DETECT_PRESENT" -eq 0 ]; then
  ENV_DETECT_PRESENT=1
  pass "Inline env detection in test files: $(echo "$INLINE_FILES" | wc -l) file(s)"
fi

if [ "$ENV_DETECT_PRESENT" -eq 0 ]; then
  fail "TC1 RED: no env detection in any conftest.py or test file" \
    "Expected: tests/conftest.py (or per-test conftest) has detect_runner_env() or RUNNER_ENV/GITHUB_ACTIONS probe"
fi

# ============================================================================
# TC2: perf budget multiplier 2× env-aware
# ============================================================================
section "TC2: perf budget multiplier (2× for self-hosted, env-aware)"

PERF_MULT_PRESENT=0

# Look for multiplier patterns in perf test files
for perf_file in \
  "${TESTS_DIR}/api/test_evaluate_transcendental.py" \
  "${TESTS_DIR}/history/test_history_search_perf.py"
do
  if [ -f "$perf_file" ]; then
    if grep -qE 'BUDGET_MULTIPLIER|budget_multiplier|self_hosted.*budget|budget.*self_hosted|runner.*multipl' "$perf_file"; then
      PERF_MULT_PRESENT=1
      pass "${perf_file##*/} has env-aware budget multiplier pattern"
    fi
  fi
done

# Look for env-aware budget assertion pattern (e.g., budget = base * multiplier)
if grep -rlE 'budget.*\*.*multipl|budget.*=.*base.*\*|self_hosted.*\*.*2|2\s*\*.*self_hosted' "${TESTS_DIR}" --include="*.py" 2>/dev/null | head -1 > /dev/null 2>&1; then
  PERF_MULT_PRESENT=1
  pass "Env-aware budget multiplication pattern present"
fi

if [ "$PERF_MULT_PRESENT" -eq 0 ]; then
  fail "TC2 RED: no perf budget multiplier in perf test files" \
    "Expected: test_evaluate_transcendental.py + test_history_search_perf.py have env-aware budget (BUDGET_MULTIPLIER=2 for self-hosted)"
fi

# ============================================================================
# TC3: subprocess timeout bumped to 10s for self-hosted (cold start)
# ============================================================================
section "TC3: subprocess timeout (10s for self-hosted cold start, env-aware)"

TIMEOUT_PRESENT=0

# Look for 10s timeout pattern in test_e2e_keyboard.py or web/conftest.py
for timeout_file in \
  "${TESTS_DIR}/web/test_e2e_keyboard.py" \
  "${TESTS_DIR}/web/conftest.py"
do
  if [ -f "$timeout_file" ]; then
    if grep -qE 'timeout.*=.*10\b|timeout_s.*=.*10\.0' "$timeout_file"; then
      TIMEOUT_PRESENT=1
      pass "${timeout_file##*/} has 10s timeout literal"
    fi
  fi
done

# Or env-aware timeout pattern
if grep -rlE 'self_hosted.*timeout|timeout.*self_hosted|SELF_HOSTED_TIMEOUT|SH_SUBPROCESS_TIMEOUT' "${TESTS_DIR}" --include="*.py" 2>/dev/null | head -1 > /dev/null 2>&1; then
  TIMEOUT_PRESENT=1
  pass "Env-aware subprocess timeout pattern present"
fi

if [ "$TIMEOUT_PRESENT" -eq 0 ]; then
  fail "TC3 RED: no 10s or env-aware subprocess timeout in web tests" \
    "Expected: tests/web/test_e2e_keyboard.py uses env-aware timeout (10s for self-hosted cold start per arch Option B)"
fi

# ============================================================================
# TC4: GH-hosted budgets UNCHANGED (negative — no multiplier when github-hosted)
# ============================================================================
section "TC4: GH-hosted budgets unchanged (negative — no multiplier when github-hosted)"

GH_BRANCH_PRESENT=0

# Look for explicit "github-hosted" branch in env detection (runner_type=="github-hosted" or similar)
GH_BRANCH_FILES=$(grep -rlE 'github-hosted|github_hosted|runner_type.*==.*["'\'']github|env.*==.*["'\'']github|runner_env.*github' "${TESTS_DIR}" --include="*.py" 2>/dev/null || true)
if [ -n "$GH_BRANCH_FILES" ]; then
  GH_BRANCH_PRESENT=1
  pass "Explicit 'github-hosted' branch in env detection ($(echo "$GH_BRANCH_FILES" | wc -l) file(s))"
fi

# Hardcoded budget regression guard (assert < 100ms / < 50ms literal) — supplementary
HARD_BUDGET_FILES=$(grep -rlE 'assert.*p99.*< *100\.?0?\b|assert.*p95.*< *100\.?0?\b|assert.*p99.*< *50\.?0?\b' "${TESTS_DIR}/api/test_evaluate_transcendental.py" "${TESTS_DIR}/history/test_history_search_perf.py" 2>/dev/null || true)
if [ -n "$HARD_BUDGET_FILES" ]; then
  info "Hardcoded perf budget assertion also present (supplementary regression guard, $(echo "$HARD_BUDGET_FILES" | wc -l) file(s))"
fi

if [ "$GH_BRANCH_PRESENT" -eq 0 ]; then
  fail "TC4 RED: no explicit GH-hosted branch OR hardcoded budget regression guard" \
    "Expected: env detection has 'github-hosted' branch preserving strict budget (no multiplier, per arch Option B regression guard)"
fi

# ============================================================================
# Summary
# ============================================================================
section "Summary"
TOTAL=$((PASS+FAIL))
if [ "$FAIL" -gt 0 ]; then
  printf "  ${R}%d TCs total: %d PASS, %d FAIL — RED state (env-aware perf budgets NOT yet implemented)${D}\n" "$TOTAL" "$PASS" "$FAIL"
  exit 1
fi
printf "  ${G}%d TCs total: %d PASS, %d FAIL — GREEN state (env-aware perf budgets implemented per arch Option B cmt 4842471072)${D}\n" "$TOTAL" "$PASS" "$FAIL"
exit 0