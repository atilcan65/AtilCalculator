#!/usr/bin/env bash
# d054-closes-anchor-strict-format.sh — dedicated §Closes-anchor strict format d-test (ADR-0050 §C9)
#
# Why this test exists
# --------------------
# ADR-0050 §C9 specifies the Closes-anchor strict format rule:
#   > L1 of PR body MUST match `^Closes #[0-9]+$` — uppercase C + line 1 + NO trailing text.
#
# d053 (Issue #463, MERGED via PR #464+#465 at 2026-06-27T05:24:27Z + 05:25:26Z)
# implements C9 as one of 9 doctrinal checks (broad-shallow coverage). This d-test,
# d054 (Issue #468, Sprint 13 P2 #6, design doc PR #474), is the **deep-narrow**
# sister-pattern: dedicated single-purpose d-test, 8 explicit TCs covering all
# observed + anticipated Closes-anchor format variants.
#
# Sister-pattern to d046 (jq-filter guard), d048 (Layer 5 reviewer chain),
# d050b (behavioral workflow test), d051 (5-soul dispatch), d052 (agent-watch
# hardening), d053 (broad 9-check sweep). Together: 7-sister d-test family
# (Sprint 11-13 d-test framework consolidation).
#
# 8 Test Cases TC1-TC8 (per design doc §8 Test Cases):
#   TC1: Closes #N             (canonical, no trailing)            → PASS (no violation)
#   TC2: closes #N             (lowercase c)                       → FAIL (violation)
#   TC3: closes #N             (no anchor / lowercase variant)     → FAIL (violation)
#   TC4: ## Why\nCloses #N     (mid-paragraph, L1 is header)       → FAIL (violation, PR #462 v1 catch)
#   TC5: Closes #N             (trailing space)                    → FAIL (violation)
#   TC6: Closes #N. See #M     (trailing sentence on L1)           → FAIL (violation, PR #472+#473 cycle)
#   TC7: (empty body)                                                → FAIL (violation)
#   TC8: ## Why               (no Closes anchor anywhere on L1)    → FAIL (violation)
#
# Self-test expected outcome: 1 PASS + 7 FAIL (green).
#
# Usage:
#   bash d054-closes-anchor-strict-format.sh <PR_NUMBER>     # live run on PR
#   bash d054-closes-anchor-strict-format.sh --self-test    # run inline fixture (8 TCs)
#
# Exit codes:
#   0 — L1 matches strict format (PASS) OR self-test green
#   1 — violation detected (with TC id + remediation) OR self-test RED
#   2 — preflight failure (missing tool, missing PR number, etc.)
#
# Run standalone: bash scripts/tests/d054-closes-anchor-strict-format.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-atilcan65/AtilCalculator}"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Pre-flight
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

# Self-test mode — run against inline fixture (8 TCs TC1-TC8)
if [ "${1:-}" = "--self-test" ]; then
  printf "${B}d054 self-test (8 TCs TC1-TC8 per design doc §8 Test Cases)${D}\n"
  printf "${B}================================================================${D}\n"

  PASS=0; FAIL=0
  EXIT_CODE=0

  # ---------------------------------------------------------------------------
  # Helper: check_strict_format LABEL BODY_L1 EXPECTED_OUTCOME
  #   EXPECTED_OUTCOME = "pass" | "fail"
  # Asserts the d-test correctly reports PASS/FAIL for the given L1.
  # ---------------------------------------------------------------------------
  check_strict_format() {
    local tc_label="$1" body_l1="$2" expected="$3"
    if [ -z "$body_l1" ]; then
      if [ "$expected" = "fail" ]; then
        fail "$tc_label" "empty body — Closes-anchor missing (expected: FAIL)"
        EXIT_CODE=1
      else
        fail "$tc_label" "empty body — should not happen for PASS fixtures"
        EXIT_CODE=1
      fi
    elif echo "$body_l1" | grep -qE "^Closes #[0-9]+\$"; then
      if [ "$expected" = "pass" ]; then
        pass "$tc_label — Closes-anchor strict format: L1 = '${body_l1}'"
      else
        fail "$tc_label" "strict regex matched but expected FAIL. L1='${body_l1}'"
        EXIT_CODE=1
      fi
    else
      if [ "$expected" = "fail" ]; then
        fail "$tc_label" "Closes-anchor NOT strict format. L1='${body_l1}' (expected: FAIL)"
        EXIT_CODE=1
      else
        fail "$tc_label" "Closes-anchor NOT strict format. L1='${body_l1}' (expected: PASS)"
        EXIT_CODE=1
      fi
    fi
  }

  # TC1 canonical case — strict format, expect PASS
  section "TC1 self-test: Closes #N (canonical)"
  check_strict_format "TC1" "Closes #468" "pass"

  # TC2 lowercase c — expect FAIL (violation)
  section "TC2 self-test: closes #N (lowercase c)"
  check_strict_format "TC2" "closes #468" "fail"

  # TC3 no anchor / lowercase variant — expect FAIL (violation)
  section "TC3 self-test: closes #N (no anchor, lowercase)"
  check_strict_format "TC3" "closes #468" "fail"

  # TC4 mid-paragraph — expect FAIL (PR #462 v1 catch)
  section "TC4 self-test: ## Why (L1 is header, anchor mid-paragraph)"
  check_strict_format "TC4" "## Why" "fail"

  # TC5 trailing space — expect FAIL (violation)
  section "TC5 self-test: Closes #N (trailing space)"
  check_strict_format "TC5" "Closes #468 " "fail"

  # TC6 trailing sentence — expect FAIL (PR #472+#473 cycle)
  section "TC6 self-test: Closes #N. See #M (trailing sentence)"
  check_strict_format "TC6" "Closes #468. See #469" "fail"

  # TC7 empty body — expect FAIL (violation)
  section "TC7 self-test: (empty body)"
  check_strict_format "TC7" "" "fail"

  # TC8 no anchor — expect FAIL (violation)
  section "TC8 self-test: ## Why (no Closes anchor)"
  check_strict_format "TC8" "## Why" "fail"

  printf "\n${B}==== SELF-TEST SUMMARY ====${D}\n"
  printf "  ${G}PASS${D}: %d\n" "$PASS"
  printf "  ${R}FAIL${D}: %d (expected: 1 PASS + 7 FAIL per design doc)\n" "$FAIL"

  if [ "$PASS" -eq 1 ] && [ "$FAIL" -eq 7 ]; then
    printf "  ${G}self-test green${D} — 1 PASS (TC1 canonical) + 7 FAIL (TC2-TC8 violation cases)\n"
    exit 0
  else
    printf "  ${R}self-test RED${D} — expected 1 PASS + 7 FAIL, got PASS=%d FAIL=%d\n" "$PASS" "$FAIL"
    exit 1
  fi
fi

# Live mode — requires PR_NUMBER
PR_NUMBER="${1:-${PR_NUMBER:-}}"
if [ -z "$PR_NUMBER" ]; then
  echo "Usage: bash $0 <PR_NUMBER>  |  PR_NUMBER=N bash $0  |  bash $0 --self-test" >&2
  exit 2
fi

section "PR #${PR_NUMBER} §Closes-anchor strict format d054 (ADR-0050 §C9 deep-narrow)"
section "Repo: ${REPO}"

# Fetch PR body
PR_JSON="$(gh api "repos/${REPO}/pulls/${PR_NUMBER}" 2>/dev/null)" || {
  echo "ERROR: gh api failed for PR #${PR_NUMBER}" >&2
  exit 2
}

BODY_L1="$(echo "$PR_JSON" | jq -r '.body // ""' 2>/dev/null | head -1)"

printf "  L1: %s\n" "${BODY_L1:0:80}"
echo

# ---------------------------------------------------------------------------
# C9 deep-narrow check (sister to d053 C9 broad-shallow, same regex)
# ---------------------------------------------------------------------------
if [ -z "$BODY_L1" ]; then
  fail "C9" "PR body empty — Closes-anchor missing (TC7: empty body)"
  exit 1
elif echo "$BODY_L1" | grep -qE "^Closes #[0-9]+\$"; then
  pass "C9 — Closes-anchor strict format: L1 = '${BODY_L1}' (ADR-0050 §C9 compliant)"
else
  # Classify violation by 8 TC categories for actionable remediation
  TC_ID=""
  REMEDIATION=""
  if echo "$BODY_L1" | grep -qE "^closes " ; then
    TC_ID="TC2/TC3"
    REMEDIATION="uppercase C required (per ADR-0050 §C9 case-sensitive C)"
  elif echo "$BODY_L1" | grep -qE "^## "; then
    TC_ID="TC4/TC8"
    REMEDIATION="Closes-anchor must be on L1, not after a markdown header (PR #462 v1 catch precedent)"
  elif echo "$BODY_L1" | grep -qE "Closes #[0-9]+ \$" ; then
    TC_ID="TC5"
    REMEDIATION="trailing space on L1 violates strict format (regex anchored to EOL)"
  elif echo "$BODY_L1" | grep -qE "Closes #[0-9]+\." ; then
    TC_ID="TC6"
    REMEDIATION="no trailing text on L1 (PR #472+#473 cycle precedent); move prose to L2+"
  else
    TC_ID="TC?"
    REMEDIATION="L1 must match ^Closes #[0-9]+\$ exactly (uppercase C, no trailing text)"
  fi
  fail "C9 (${TC_ID})" "Closes-anchor NOT strict format. L1='${BODY_L1}'. Remediation: ${REMEDIATION}"
  exit 1
fi

printf "\n${B}==== SUMMARY (PR #${PR_NUMBER}) ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"
printf "  ${Y}INFO${D}: d054 deep-narrow sister to d053 C9 broad-shallow — same regex, deeper violation classification\n"

exit 0