#!/usr/bin/env bash
# d115-ci-subprocess-timeout-env-block.sh — Issue #739 follow-up + TD-046-extension
# regression guard for `.github/workflows/ci.yml` SUBPROCESS_TIMEOUT_S env propagation.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT Faz 1.1 (PR #709, commit `eb64485`) migrated CI from
# `ubuntu-latest` to self-hosted runners but propagated only BUDGET_MULTIPLIER
# (Issue #727, PR #729 commit `f5636d5`, d109 sister-pattern). The
# SUBPROCESS_TIMEOUT_S env var was NOT propagated to the `Test (Python)` step.
#
# Root cause of PR #732 CI failure (cycle ~#1966 hand-off):
#   - tests/conftest.py:144 _resolve_subprocess_timeout_s() returns 10.0 on
#     self-hosted (map baseline) but 5.0 on github-hosted + local.
#   - When the e2e subprocess test (tests/e2e/test_cli_basic.py) computes
#     cleanup_timeout = max(int(SUBPROCESS_TIMEOUT_S/5), 1):
#       local dev (SUBPROCESS_TIMEOUT_S=5.0) → cleanup_timeout = 1s
#       self-hosted (SUBPROCESS_TIMEOUT_S=10.0) → cleanup_timeout = 2s
#   - Without SUBPROCESS_TIMEOUT_S env in ci.yml, conftest defaults to the
#     map fallback path. If detect_runner_env() drifted in self-hosted VM
#     cold-start (CI runner regression cycle ~#1966), the e2e subprocess
#     test had cleanup_timeout=1s insufficient for cold start > 1s.
#   - This is the EXACT same shape as Issue #727 BUDGET_MULTIPLIER gap
#     (PR #709 → PR #729 → d109) — sister-pattern fix.
#
# This d-test guards ci.yml so future PIVOT refactors don't silently
# drop the env var again. Sister-pattern to d109 (BUDGET_MULTIPLIER env
# block, PR #729 commit f5636d5) + d112 (conftest env-var precedence,
# PR #734 commit 727a2c7) + d100 (self-hosted perf budgets) + d107
# (Issue #722 install-git-hooks) + d108 (Issue #725 context watchdog).
#
# AC mapping (Issue #739 follow-up, TD-046-extension):
#   AC1 — ci.yml Test (Python) step env: block contains SUBPROCESS_TIMEOUT_S key
#   AC2 — expression `${{ vars.SUBPROCESS_TIMEOUT_S || 10.0 }}` (default 10.0 fallback)
#   AC3 — pytest invocation preserved (regression guard against removing pytest call)
#   AC4 — d-test ≥5 TCs per ADR-0049
#   AC5 — INDEX.md updated per Cadence Rule 1 atomic (ADR-0055 §1)
#   AC6 — PR is DRAFT with 4-cat labels per ADR-0012
#
# 6 TCs (per ADR-0049 d-test framework sister-pattern to d109):
#   TC1: ci.yml exists at .github/workflows/ci.yml (preflight)
#   TC2: "Test (Python)" step has env: block (AC1 — block presence, sister to d109 TC2)
#   TC3: env: block contains SUBPROCESS_TIMEOUT_S key (AC1 — key presence, sister to d109 TC3)
#   TC4: SUBPROCESS_TIMEOUT_S expression uses ${{ vars.SUBPROCESS_TIMEOUT_S }} (AC2 — repo var hook, sister to d109 TC4)
#   TC5: Expression falls back to 10.0 when vars unset (AC2 — `|| 10.0` default, sister to d109 TC5)
#   TC6: pytest invocation preserved — `pytest -q --cov=...` still runs (AC3 — regression guard, sister to d109 TC6)
#
# Pre-impl RED state (current main as of 2026-07-01, pre-Issue #739-followup impl):
#   - .github/workflows/ci.yml Test (Python) step env: block has BUDGET_MULTIPLIER only
#   - TC1: PASS (file exists)
#   - TC2: PASS (env: block present for BUDGET_MULTIPLIER)
#   - TC3: FAIL (env block does NOT contain SUBPROCESS_TIMEOUT_S)
#   - TC4: FAIL (cascade from TC3)
#   - TC5: FAIL (cascade from TC3)
#   - TC6: PASS (pytest still runs)
#   → 3 PASS + 3 FAIL = proper RED-first per ADR-0044
#   → TC3/TC4/TC5 marked FAIL with informative notes
#
# Post-impl GREEN state (target, after this PR merge):
#   - SUBPROCESS_TIMEOUT_S key added to env: block
#   - All 6 TCs PASS (3 PASS + 3 previously-FAIL now PASS)
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d109 (Issue #727 BUDGET_MULTIPLIER env block, PR #729 commit f5636d5) —
#          DIRECT sister (the same env: block, just different key — same
#          shape, same fix, same cycle era)
#   - d112 (TD-046-extension conftest env-var precedence, PR #734 commit 727a2c7,
#          7 TCs) — sister-pattern to the conftest _resolve_subprocess_timeout_s()
#          function this PR targets from ci.yml side
#   - d100 (Sprint 22 PIVOT self-hosted perf budgets, 5 TCs) — uses
#          BUDGET_MULTIPLIER + SUBPROCESS_TIMEOUT_S via conftest env-var
#          precedence chain
#   - d107 + d108 (URGENT-P0 fix d-tests) — same cycle era cluster
#   - d094 + d094-self-hosted-runner-migration + d094-watcher-self-cc-skip —
#          Sprint 22 PIVOT self-hosted runner migration sister family
#
# Usage:
#   bash d115-ci-subprocess-timeout-env-block.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — env block present, default fallback works, pytest preserved)
#   1 — at least one FAIL (RED state — impl missing or ACs unsatisfied)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CI_YML="${REPO_ROOT}/.github/workflows/ci.yml"

# Colors (TTY-aware) — sister-pattern to d107/d108/d109
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
command -v sed >/dev/null 2>&1 || { echo "ERROR: sed required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d115 self-test (6 TCs per Issue #739-followup + TD-046-extension, ADR-0044 RED-first)${D}\n"
printf "${B}=========================================================================================${D}\n"
printf "  Repo root:           %s\n" "$REPO_ROOT"
printf "  ci.yml:              %s\n" "$CI_YML"
printf "  Sister-pattern:      d109 (BUDGET_MULTIPLIER env block, PR #729) + d112 (conftest env-var precedence)\n"
printf "  Spec ref:            Issue #739 follow-up + TD-046-extension cycle ~#1770+ + ADR-0019 amend 4\n"
printf "  Pre-impl RED:        TC3 + TC4 + TC5 cascade FAIL by design per ADR-0044\n"
printf "  Post-impl:           all 6 TCs must PASS\n\n"

EXIT_CODE=0

# ============================================================================
# TC1: ci.yml exists at .github/workflows/ci.yml (preflight)
# ============================================================================
section "TC1: AC1 preflight — ci.yml exists + readable"

if [ -f "$CI_YML" ]; then
  if [ -r "$CI_YML" ]; then
    pass "TC1 — ci.yml exists at $CI_YML and is readable"
  else
    fail "TC1 — ci.yml exists but is NOT readable" \
      "expected read permissions on $CI_YML"
    EXIT_CODE=1
  fi
else
  fail "TC1 — ci.yml missing" \
    "expected $CI_YML per Issue #739-followup AC1. Without this file, ci.yml env gap cannot be guarded. RED-first confirmed."
  EXIT_CODE=1
  section "TC2-TC6: SKIPPED (TC1 prerequisite not met — ci.yml missing)"
  printf "  ${Y}ℹ INFO${D} — TC2-TC6 cannot run without ci.yml. Post-impl: all 6 TCs must PASS.\n"
  FAIL=$((FAIL + 5))
  EXIT_CODE=1
  printf "\n${B}==== Summary ====${D}\n"
  printf "  PASS: %d\n" "$PASS"
  printf "  FAIL: %d\n" "$FAIL"
  printf "  INFO: %d\n" "$INFO"
  printf "\n${R}RED state: ci.yml not present — TC1 fails + TC2-TC6 cascade${D}\n"
  exit 1
fi

# ============================================================================
# Extract the Test (Python) step block (16-line window after "name: Test (Python)")
# ============================================================================
# This isolates just the step definition so we don't get false positives from
# env blocks on other steps (like conventional-commits job which has GITHUB_TOKEN).
START_LINE="$(grep -n 'name: Test (Python)' "$CI_YML" | head -1 | cut -d: -f1)"
if [ -z "$START_LINE" ]; then
  fail "internal — could not locate 'Test (Python)' step in ci.yml" \
    "grep returned empty for name: Test (Python)"
  EXIT_CODE=1
else
  TEST_BLOCK="$(sed -n "${START_LINE},$((START_LINE + 32))p" "$CI_YML")"
  # Sanity: the block should contain the run: line for pytest (TC6 below uses this)
  if echo "$TEST_BLOCK" | grep -q 'run: |'; then
    info "Test (Python) step block: lines ${START_LINE}-$((START_LINE + 32))"
  else
    info "WARNING: 'run: |' not found in expected line window; window may have shifted"
  fi
fi

# ============================================================================
# TC2: "Test (Python)" step has env: block
# ============================================================================
section "TC2: AC1 — Test (Python) step has env: block (sister to d109 TC2)"

# An env: block at same indentation as if:/run: would be 8 spaces (under
# the `- name:` step keyword) — GH Actions YAML convention. We match
# lines with 8-space indent + "env:" — allow trailing whitespace.
if [ -n "$TEST_BLOCK" ]; then
  if echo "$TEST_BLOCK" | grep -qE '^[[:space:]]{8}env:[[:space:]]*$'; then
    pass "TC2 — Test (Python) step has env: block (8-space indented, sis to if:/run:)"
  else
    fail "TC2 — Test (Python) step has NO env: block" \
      "expected an 8-space-indented 'env:' key between 'if:' and 'run:' (sister-pattern to GH Actions docs §env — same indent as if:/run: in this step). Without env block, SUBPROCESS_TIMEOUT_S cannot be injected. RED-first confirmed."
    EXIT_CODE=1
  fi
else
  fail "TC2 — could not extract Test (Python) step block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: env: block contains SUBPROCESS_TIMEOUT_S key
# ============================================================================
section "TC3: AC1 — env: block contains SUBPROCESS_TIMEOUT_S key (sister to d109 TC3)"

if echo "$TEST_BLOCK" | grep -qE '^[[:space:]]+SUBPROCESS_TIMEOUT_S:'; then
  pass "TC3 — env: block contains SUBPROCESS_TIMEOUT_S key"
else
  fail "TC3 — env: block (if present) does NOT contain SUBPROCESS_TIMEOUT_S key" \
    "expected indented 'SUBPROCESS_TIMEOUT_S:' line under the env: block (sister-pattern to BUDGET_MULTIPLIER on the line above, d109 TC3). Without this key, conftest _resolve_subprocess_timeout_s() falls back to detect_runner_env() map (5.0s on github-hosted vs 10.0s canonical self-hosted) — drift causes e2e subprocess cleanup_timeout=1s insufficient for cold start > 1s."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: SUBPROCESS_TIMEOUT_S expression uses vars.SUBPROCESS_TIMEOUT_S
# ============================================================================
section "TC4: AC2 — expression uses vars.SUBPROCESS_TIMEOUT_S (Settings repo var hook, sister to d109 TC4)"

# We expect: SUBPROCESS_TIMEOUT_S: ${{ vars.SUBPROCESS_TIMEOUT_S || 10.0 }}
# This is split across the right-hand side of the key. Grep for "vars.SUBPROCESS_TIMEOUT_S"
if echo "$TEST_BLOCK" | grep -q 'vars\.SUBPROCESS_TIMEOUT_S'; then
  pass "TC4 — SUBPROCESS_TIMEOUT_S expression references vars.SUBPROCESS_TIMEOUT_S (repo Setting override hook)"
else
  fail "TC4 — SUBPROCESS_TIMEOUT_S expression does NOT reference vars.SUBPROCESS_TIMEOUT_S" \
    "expected the RHS to interpolate from repo Settings > Secrets and variables > Variables (sister-pattern to BUDGET_MULTIPLIER on the line above, d109 TC4). Without this, future subprocess timeout tuning requires code changes instead of variables-only."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: Expression falls back to 10.0 when vars unset
# ============================================================================
section "TC5: AC2 — expression falls back to 10.0 default when vars unset (sister to d109 TC5)"

# We accept "|| 10.0" or "||'10.0'" with optional quoting.
# GH Actions YAML parses `${{ vars.X || 10.0 }}` and `${{ vars.X || '10.0' }}` identically.
# 10.0 matches tests/conftest.py:120 _SUBPROCESS_TIMEOUT_MAP_S['self-hosted']=10.0
if echo "$TEST_BLOCK" | grep -qE 'vars\.SUBPROCESS_TIMEOUT_S[[:space:]]*\|\|[[:space:]]*10\.0'; then
  pass "TC5 — expression falls back to 10.0 default (matches Sprint 22 PIVOT self-hosted canonical per conftest _SUBPROCESS_TIMEOUT_MAP_S['self-hosted']=10.0)"
else
  fail "TC5 — expression does NOT fall back to 10.0" \
    "expected 'vars.SUBPROCESS_TIMEOUT_S || 10.0' on the RHS (string or unquoted both work in GH Actions). Default 10.0 = Sprint 22 PIVOT self-hosted canonical subprocess timeout (matches tests/conftest.py:120 _SUBPROCESS_TIMEOUT_MAP_S['self-hosted']=10.0 + ADR-0019 amend 3); any other default would silently shift the baseline."
  EXIT_CODE=1
fi

# ============================================================================
# TC6: pytest invocation preserved (regression guard)
# ============================================================================
section "TC6: AC3 — pytest invocation preserved (regression guard, sister to d109 TC6)"

# The original step runs `pytest -q --cov=src/atilcalc/engine --cov-fail-under=90`.
# We must NOT have silently broken the test command in the env-block edit.
# This guards against future bot-PRs that edit env and accidentally nuke run:.
if echo "$TEST_BLOCK" | grep -q 'pytest -q --cov=src/atilcalc/engine --cov-fail-under=90'; then
  pass "TC6 — pytest invocation preserved (pytest -q --cov=src/atilcalc/engine --cov-fail-under=90)"
else
  fail "TC6 — pytest invocation diverged or missing" \
    "expected 'pytest -q --cov=src/atilcalc/engine --cov-fail-under=90' on the run: | block. Per §regression-guard, env edits must not accidentally break the test command (dogfood on existing pytest signature)."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}GREEN state: env: SUBPROCESS_TIMEOUT_S block landed — TC1-TC6 all PASS${D}\n"
  exit 0
else
  printf "\n${R}RED state: env: SUBPROCESS_TIMEOUT_S block missing or incomplete — Issue #739-followup impl still pending${D}\n"
  exit 1
fi