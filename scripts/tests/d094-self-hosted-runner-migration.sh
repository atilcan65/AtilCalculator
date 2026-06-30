#!/usr/bin/env bash
# d094-self-hosted-runner-migration.sh — Sprint 22 PIVOT Faz 1.1 regression guard.
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT (Issue #708) Faz 1.1: workflow files migrate from GitHub-hosted
# ubuntu-latest runners to self-hosted runners registered at the atilproject org.
# Owner pre-validated 8 runners registered + concurrent + failover tests passed.
#
# This d-test guards against:
#   - TC1: Any workflow file using `runs-on: ubuntu-latest` (regression)
#   - TC2: Self-hosted runners missing required labels (Linux, X64, atilproject)
#   - TC3: Orphan `ubuntu-latest` strings (e.g., in comments, doc blocks)
#
# Pre-impl RED state (current main as of 2026-06-30):
#   - TC1: 9/10 workflow files use ubuntu-latest → FAIL (deploy.yml already self-hosted)
#   - TC2: 0 workflow files use self-hosted (other than deploy.yml) → FAIL
#   - TC3: 9+ orphan ubuntu-latest strings in workflow files → FAIL
#   → 3/3 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after Issue #708 Faz 1.1 impl lands + PR squash):
#   - TC1: 0/10 workflow files use ubuntu-latest ✅
#   - TC2: 10/10 workflow files use [self-hosted, Linux, X64, atilproject] ✅
#   - TC3: 0 orphan ubuntu-latest strings remain ✅
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d069 (Issue #666 + PR #679 workflow-file scope parameterization, WORKFLOW_FILES array)
#   - d070 (Issue #637 + PR #704 dev-studio-init.sh template-rendering regression guard)
#   - d070b (Issue #693 + PR #703 init-prompt-ux regression guard)
#   - d091 (work-stream awareness regression guard)
#   - d093 (Issue #633 + PR #694 TEMPLATE-README.md polish regression guard)
#
# Sprint 22 PIVOT refs:
#   - Issue #708 (Sprint 22 PIVOT kickoff — owner GO verdict)
#   - Sprint 22 PIVOT plan v3 (5-phase, 8 self-hosted runner + 3-repo org migration)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern)
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#
# Usage:
#   bash d094-self-hosted-runner-migration.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — workflows migrated to self-hosted)
#   1 — at least one FAIL (RED state — migration incomplete)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOWS_DIR="${REPO_ROOT}/.github/workflows"
EXPECTED_RUNS_ON="self-hosted, Linux, X64, atilproject"

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

printf "${B}d094 self-test (3 TCs per Issue #708 Sprint 22 PIVOT Faz 1.1, ADR-0044 RED-first)${D}\n"
printf "${B}============================================================================${D}\n"
printf "  Target dir:           %s\n" "$WORKFLOWS_DIR"
printf "  Expected runs-on:     [%s]\n" "$EXPECTED_RUNS_ON"
printf "  Sister-pattern:       d069 (WORKFLOW_FILES array) + d070 + d070b + d091 + d093"
printf "  Pre-impl RED:         3/3 TCs FAIL by design per ADR-0044"
printf "  Sprint 22 PIVOT:      Issue #708 (owner GO verdict cycle ~#1512)"
printf "  File ownership:       .github/workflows/ = human-only (agents propose via PR)\n\n"

if [ ! -d "$WORKFLOWS_DIR" ]; then
  fail "preflight — .github/workflows/ missing" "expected $WORKFLOWS_DIR"
  exit 2
fi

EXIT_CODE=0

# ============================================================================
# TC1: All workflow files use self-hosted runner (not ubuntu-latest)
# ============================================================================
section "TC1: AC1 — all workflow files use self-hosted runner (no ubuntu-latest)"
TC1_UBUNTU_FILES=()
TC1_TOTAL=0
for wf in "$WORKFLOWS_DIR"/*.yml; do
  [ -f "$wf" ] || continue
  TC1_TOTAL=$((TC1_TOTAL + 1))
  if grep -qE "^[[:space:]]*runs-on:[[:space:]]+ubuntu-latest" "$wf"; then
    TC1_UBUNTU_FILES+=("$(basename "$wf")")
  fi
done

if [ "${#TC1_UBUNTU_FILES[@]}" -eq 0 ]; then
  pass "TC1 — all ${TC1_TOTAL} workflow files use self-hosted runner (no ubuntu-latest)"
else
  FILE_LIST=$(IFS=', '; echo "${TC1_UBUNTU_FILES[*]}")
  fail "TC1 — ${#TC1_UBUNTU_FILES[@]}/${TC1_TOTAL} workflow files still on ubuntu-latest: ${FILE_LIST}" \
    "expected all workflow files migrated to runs-on: [self-hosted, Linux, X64, atilproject] per Sprint 22 PIVOT Faz 1.1. Issue #708; owner-merge per file ownership matrix."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: Self-hosted runner labels match expected pattern
# ============================================================================
section "TC2: AC2 — self-hosted runner labels include [self-hosted, Linux, X64, atilproject]"
TC2_SELF_HOSTED=0
TC2_MISSING_LABELS=()
for wf in "$WORKFLOWS_DIR"/*.yml; do
  [ -f "$wf" ] || continue
  # Extract runs-on value (single-line or array start)
  RUNS_ON_LINE=$(grep -E "^[[:space:]]*runs-on:" "$wf" | head -1)
  if echo "$RUNS_ON_LINE" | grep -qE "self-hosted"; then
    TC2_SELF_HOSTED=$((TC2_SELF_HOSTED + 1))
    # Check all 4 labels present
    for label in self-hosted Linux X64 atilproject; do
      if ! echo "$RUNS_ON_LINE" | grep -q "$label"; then
        TC2_MISSING_LABELS+=("$(basename "$wf"): missing '$label' label")
      fi
    done
  fi
done

if [ "$TC2_SELF_HOSTED" -eq "$TC1_TOTAL" ] && [ "${#TC2_MISSING_LABELS[@]}" -eq 0 ]; then
  pass "TC2 — ${TC2_SELF_HOSTED}/${TC1_TOTAL} workflow files have correct self-hosted labels [self-hosted, Linux, X64, atilproject]"
else
  if [ "${#TC2_MISSING_LABELS[@]}" -gt 0 ]; then
    MISSING_LIST=$(IFS='; '; echo "${TC2_MISSING_LABELS[*]}")
    fail "TC2 — ${TC2_SELF_HOSTED}/${TC1_TOTAL} self-hosted, but missing labels: ${MISSING_LIST}" \
      "expected all 4 labels (self-hosted, Linux, X64, atilproject) per Sprint 22 PIVOT plan v3 §Faz 1.1."
    EXIT_CODE=1
  else
    fail "TC2 — only ${TC2_SELF_HOSTED}/${TC1_TOTAL} workflow files use self-hosted" \
      "expected all ${TC1_TOTAL} workflow files migrated to self-hosted runner."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC3: No orphan ubuntu-latest strings (any context)
# ============================================================================
section "TC3: AC3 — no orphan ubuntu-latest strings in any workflow file"
TC3_ORPHAN_TOTAL=0
TC3_ORPHAN_FILES=()
for wf in "$WORKFLOWS_DIR"/*.yml; do
  [ -f "$wf" ] || continue
  ORPHAN_COUNT=$(grep -cE "ubuntu-latest" "$wf" || true)
  if [ "$ORPHAN_COUNT" -gt 0 ]; then
    TC3_ORPHAN_TOTAL=$((TC3_ORPHAN_TOTAL + ORPHAN_COUNT))
    TC3_ORPHAN_FILES+=("$(basename "$wf"): ${ORPHAN_COUNT}")
  fi
done

if [ "$TC3_ORPHAN_TOTAL" -eq 0 ]; then
  pass "TC3 — no orphan ubuntu-latest strings in any workflow file"
else
  FILE_LIST=$(IFS='; '; echo "${TC3_ORPHAN_FILES[*]}")
  fail "TC3 — ${TC3_ORPHAN_TOTAL} orphan ubuntu-latest string(s) across workflow files: ${FILE_LIST}" \
    "expected zero ubuntu-latest occurrences anywhere in .github/workflows/ (active runs-on OR comments OR doc blocks). Sprint 22 PIVOT Faz 1.1 = full migration."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Workflow files scanned: %d\n" "$TC1_TOTAL"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — Sprint 22 PIVOT Faz 1.1 workflow migration not yet landed${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 3 TCs PASS — Sprint 22 PIVOT Faz 1.1 workflow migration landed${D}\n"
exit 0