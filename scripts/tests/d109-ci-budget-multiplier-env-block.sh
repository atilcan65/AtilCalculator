#!/usr/bin/env bash
# d109-ci-budget-multiplier-env-block.sh — Issue #727 (Sprint 22 PIVOT CI gap)
# regression guard for `.github/workflows/ci.yml` BUDGET_MULTIPLIER env propagation.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT Faz 1.1 (PR #709, commit `eb64485`) migrated CI from
# `ubuntu-latest` to self-hosted runners but did NOT propagate the
# `BUDGET_MULTIPLIER` env var to the `Test (Python)` step. The
# performance-budget tests in `tests/api/test_evaluate_transcendental.py`
# (d100 sister-test, 1× budget reference) silently fail in CI because
# `BUDGET_MULTIPLIER=2.0` default on local dev venvs is treated as
# 1× — but the documented ADR-0019 amendment 2 baseline expects the
# env var to be present so `vars.BUDGET_MULTIPLIER` (repo Settings >
# Secrets and variables > Variables) can override it without code changes.
#
# This d-test guards ci.yml so future PIVOT refactors don't silently
# drop the env var again. Sister-pattern to d107 (Issue #722 pre-push
# hook install) + d108 (Issue #725 context watchdog defaults) — both
# URGENT-P0 fix d-tests in the same cycle ~#1638-#1640 cluster.
#
# AC mapping (Issue #727 / orchestrator-critical 2026-06-30):
#   AC1 — ci.yml Test (Python) step has env: block with BUDGET_MULTIPLIER key
#   AC2 — expression `${{ vars.BUDGET_MULTIPLIER || 2.0 }}` (default 2.0 fallback)
#   AC3 — pytest invocation preserved (regression guard against removing pytest call)
#   AC4 — d-test ≥5 TCs per ADR-0049
#   AC5 — INDEX.md updated per Cadence Rule 1 atomic (ADR-0055 §1)
#   AC6 — PR is DRAFT with 4-cat labels per ADR-0012
#
# 8 TCs (per ADR-0049 d-test framework sister-pattern, Issue #752 window-shift fix):
#   TC1: ci.yml exists at .github/workflows/ci.yml (preflight)
#   TC2: "Test (Python)" step has env: block (AC1 — block presence)
#   TC3: env: block contains BUDGET_MULTIPLIER key (AC1 — key presence)
#   TC4: BUDGET_MULTIPLIER expression uses ${{ vars.BUDGET_MULTIPLIER }} (AC2 — repo var hook)
#   TC5: Expression falls back to 2.0 when vars unset (AC2 — `|| 2.0` default)
#   TC6: pytest invocation preserved — `pytest -q --cov=...` still runs (AC3 — regression guard)
#   TC7: env: block contains SUBPROCESS_TIMEOUT_S key (AC4 — PR #748 regression guard, sister d115)
#   TC8: window covers env: + pytest (AC5 — Issue #752 window-shift guard, WINDOW_SIZE=32)
#
# Pre-impl RED state (current main as of 2026-06-30, pre-Issue #727 impl):
#   - .github/workflows/ci.yml Test (Python) step has NO env: block
#   - TC1: PASS (file exists)
#   - TC2: FAIL (no env: block)
#   - TC3-TC5: cascade-fail (no env: block → no BUDGET_MULTIPLIER)
#   - TC6: PASS (pytest still runs without env)
#   → 4 PASS + 2 FAIL (TC2 + cascade) = proper RED-first per ADR-0044
#   → TC3/TC4/TC5 marked FAIL with informative notes (cascade from TC2)
#
# Post-impl GREEN state (target, after Issue #727 PR merge):
#   - env: block added with BUDGET_MULTIPLIER key
#   - All 6 TCs PASS (4 PASS + 2 previously-FAIL now PASS)
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d100 (Sprint 22 PIVOT self-hosted perf budgets, 5 TCs) —
#          DIRECT sister (the test that USES BUDGET_MULTIPLIER but was
#          silently uncapped in CI because ci.yml never propagated the env)
#   - d107 (Issue #722 install-git-hooks, 6 TCs) — same URGENT-P0 fix shape
#   - d108 (Issue #725 context watchdog defaults, 6 TCs) — same cycle ~#1638 cluster
#   - d094 + d094-self-hosted-runner-migration + d094-watcher-self-cc-skip — Sprint 22
#          PIVOT self-hosted runner migration sister family (this d109 closes the
#          env-var gap left by d094/d100 cascade)
#
# Usage:
#   bash d109-ci-budget-multiplier-env-block.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — env block present, default fallback works, pytest preserved)
#   1 — at least one FAIL (RED state — impl missing or ACs unsatisfied)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CI_YML="${REPO_ROOT}/.github/workflows/ci.yml"

# Colors (TTY-aware) — sister-pattern to d107/d108
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

# Preflight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v sed >/dev/null 2>&1 || { echo "ERROR: sed required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d109 self-test (6 TCs per Issue #727 + ADR-0044 RED-first)${D}\n"
printf "${B}================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  ci.yml:           %s\n" "$CI_YML"
printf "  Sister-pattern:   d100 (self-hosted perf budgets) + d107/d108 (URGENT-P0 fix d-tests)\n"
printf "  Pre-impl RED:     TC2 + TC3/4/5 cascade FAIL by design per ADR-0044\n"
printf "  Post-impl:        all 6 TCs must PASS\n\n"

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
    "expected $CI_YML per Issue #727 AC1. Without this file, ci.yml env gap cannot be guarded. RED-first confirmed."
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
# Extract the Test (Python) step block (32-line window after "name: Test (Python)")
# ============================================================================
# This isolates just the step definition so we don't get false positives from
# env blocks on other steps (like conventional-commits job which has GITHUB_TOKEN).
# Window = 32 lines (was 16, Issue #752 window-shift fix to accommodate PR #748's
# +12 SUBPROCESS_TIMEOUT_S comment block); covers full env: block + run: +
# pytest invocation line. Sister-pattern: d115 uses identical window.
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
section "TC2: AC1 — Test (Python) step has env: block"

# An env: block at same indentation as if:/run: would be 8 spaces (under
# the `- name:` step keyword) — GH Actions YAML convention. We match
# lines with 8-space indent + "env:" — allow trailing whitespace.
if [ -n "$TEST_BLOCK" ]; then
  if echo "$TEST_BLOCK" | grep -qE '^[[:space:]]{8}env:[[:space:]]*$'; then
    pass "TC2 — Test (Python) step has env: block (8-space indented, sis to if:/run:)"
  else
    fail "TC2 — Test (Python) step has NO env: block" \
      "expected an 8-space-indented 'env:' key between 'if:' and 'run:' (sister-pattern to GH Actions docs §env — same indent as if:/run: in this step). Without env block, BUDGET_MULTIPLIER cannot be injected. RED-first confirmed."
    EXIT_CODE=1
  fi
else
  fail "TC2 — could not extract Test (Python) step block (TC1 prerequisite cascade)"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: env: block contains BUDGET_MULTIPLIER key
# ============================================================================
section "TC3: AC1 — env: block contains BUDGET_MULTIPLIER key"

if echo "$TEST_BLOCK" | grep -qE '^[[:space:]]+BUDGET_MULTIPLIER:'; then
  pass "TC3 — env: block contains BUDGET_MULTIPLIER key"
else
  fail "TC3 — env: block (if present) does NOT contain BUDGET_MULTIPLIER key" \
    "expected indented 'BUDGET_MULTIPLIER:' line under the env: block (sister-pattern to conventional-commits job which injects GITHUB_TOKEN). Without this key, d100 perf budgets cannot be calibrated in CI."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: BUDGET_MULTIPLIER expression uses vars.BUDGET_MULTIPLIER
# ============================================================================
section "TC4: AC2 — expression uses vars.BUDGET_MULTIPLIER (Settings repo var hook)"

# We expect: BUDGET_MULTIPLIER: ${{ vars.BUDGET_MULTIPLIER || 2.0 }}
# This is split across the right-hand side of the key. Grep for "vars.BUDGET_MULTIPLIER"
if echo "$TEST_BLOCK" | grep -q 'vars\.BUDGET_MULTIPLIER'; then
  pass "TC4 — BUDGET_MULTIPLIER expression references vars.BUDGET_MULTIPLIER (repo Setting override hook)"
else
  fail "TC4 — BUDGET_MULTIPLIER expression does NOT reference vars.BUDGET_MULTIPLIER" \
    "expected the RHS to interpolate from repo Settings > Secrets and variables > Variables (sister-pattern to GITHUB_TOKEN secret interpolation in conventional-commits job, line 124). Without this, future perf-budget tuning requires code changes instead of variables-only."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: Expression falls back to 2.0 when vars unset
# ============================================================================
section "TC5: AC2 — expression falls back to 2.0 default when vars unset"

# We accept "|| 2.0" or "||'2.0'" with optional quoting.
# GH Actions YAML parses `${{ vars.X || 2.0 }}` and `${{ vars.X || '2.0' }}` identically.
if echo "$TEST_BLOCK" | grep -qE 'vars\.BUDGET_MULTIPLIER[[:space:]]*\|\|[[:space:]]*2\.0'; then
  pass "TC5 — expression falls back to 2.0 default (matches Sprint 22 PIVOT self-hosted canonical (ADR-0019 amend 3))"
else
  fail "TC5 — expression does NOT fall back to 2.0" \
    "expected 'vars.BUDGET_MULTIPLIER || 2.0' on the RHS (string or unquoted both work in GH Actions). Default 2.0 = Sprint 22 PIVOT self-hosted canonical multiplier (ADR-0019 amend 3); any other default would silently shift the baseline."
  EXIT_CODE=1
fi

# ============================================================================
# TC6: pytest invocation preserved (regression guard)
# ============================================================================
section "TC6: AC3 — pytest invocation preserved (regression guard)"

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
# TC7: env: block contains SUBPROCESS_TIMEOUT_S key (PR #748 regression guard)
# ============================================================================
section "TC7: AC4 — env: block contains SUBPROCESS_TIMEOUT_S key (PR #748 / d115 sister)"

# Sister-pattern to d115 TC3: same env-block key shape, but for the second env
# variable propagated in PR #748 (cycle ~#3085). Without this key, e2e
# subprocess tests (tests/e2e/test_cli_basic.py) silently fall back to
# conftest _SUBPROCESS_TIMEOUT_MAP_S[detect_runner_env()] = 5.0s on GH-hosted
# drift, computing cleanup_timeout=max(int(5.0/5),1)=1s insufficient for
# self-hosted VM cold-start > 1s.
if echo "$TEST_BLOCK" | grep -qE '^[[:space:]]+SUBPROCESS_TIMEOUT_S:'; then
  pass "TC7 — env: block contains SUBPROCESS_TIMEOUT_S key (PR #748 regression guard, sister d115)"
else
  fail "TC7 — env: block does NOT contain SUBPROCESS_TIMEOUT_S key" \
    "expected indented 'SUBPROCESS_TIMEOUT_S:' line under the env: block (sister-pattern to d115 which guards this same key from a dedicated file). PR #748 introduced this key for self-hosted cold-start; d112 conftest honors it via _resolve_subprocess_timeout_s(). Without d109 covering TC7, an inadvertent SUBPROCESS_TIMEOUT_S removal slips past d109's TC1-TC6 (those don't check SUBPROCESS_TIMEOUT_S)."
  EXIT_CODE=1
fi

# ============================================================================
# TC8: window-shift regression guard (Issue #752 / Sister-pattern sister d115)
# ============================================================================
section "TC8: AC5 — window covers env: block + pytest (Issue #752 window-shift guard)"

# The 32-line window (START_LINE + 32) must be wide enough to capture both the
# env: block AND the pytest invocation. This guards against future PRs adding
# more comment lines (e.g. PR #748 added +12 comment lines + 1 env var)
# that push the env: block out of the captured window. Sister-pattern to d115.
WINDOW_SIZE=32
WINDOW_END=$((START_LINE + WINDOW_SIZE))
ENV_LINE="$(grep -n '^[[:space:]]\{8\}env:' "$CI_YML" | head -1 | cut -d: -f1)"
PYTEST_LINE="$(grep -n 'pytest -q --cov=src/atilcalc/engine --cov-fail-under=90' "$CI_YML" | head -1 | cut -d: -f1)"

if [ -z "$ENV_LINE" ] || [ -z "$PYTEST_LINE" ]; then
  fail "TC8 — could not locate env: block or pytest invocation line" \
    "ENV_LINE='$ENV_LINE', PYTEST_LINE='$PYTEST_LINE'. Cadence Rule 1 ci.yml sanity."
  EXIT_CODE=1
elif [ "$ENV_LINE" -le "$WINDOW_END" ] && [ "$PYTEST_LINE" -le "$WINDOW_END" ]; then
  pass "TC8 — window covers env: (L${ENV_LINE}) and pytest (L${PYTEST_LINE}); window-end L${WINDOW_END}"
else
  fail "TC8 — window too narrow: env: at L${ENV_LINE} or pytest at L${PYTEST_LINE} beyond L${WINDOW_END}" \
    "WINDOW_SIZE=${WINDOW_SIZE} (Issue #752 fix; was 16 pre-fix). If a future PR adds more comments/env vars and pushes env: block past this window, d109 will silently regress. Increase WINDOW_SIZE OR adopt d113-style smart parser (find next 'run: |' boundary)."
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
  printf "\n${G}GREEN state: env: BUDGET_MULTIPLIER + SUBPROCESS_TIMEOUT_S blocks landed — TC1-TC8 all PASS${D}\n"
  exit 0
else
  printf "\n${R}RED state: env: BUDGET_MULTIPLIER/SUBPROCESS_TIMEOUT_S blocks missing or window too narrow${D}\n"
  exit 1
fi
