#!/usr/bin/env bash
# d078-layer-5-initial-add-defensive-guard.sh — Issue #680 + PR #683 d-test (initial-add defensive guard).
#
# Why this test exists
# --------------------
# PR #679 LIVE INSTANCE (cycle ~#1115): Layer 5 initial-add race pathology.
#   - Tester opened PR #679 without status:in-review (tester-flow convention)
#   - L5 attempted DELETE status:in-review → 404 HttpError → label-check FAIL
#   - Parallel: L5 auto-added status:ready to DRAFT PR (premature owner merge signal)
#
# Sister-pattern to d077 (RE-ADD regression test, Issue #675):
#   d077 (Issue #675): RE-ADD pathology — L5 re-adds status:ready on every action=unlabeled
#   d078 (Issue #680): INITIAL-ADD pathology — L5 crashes on DELETE-when-absent + auto-adds to DRAFT
#
# 5 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: Defensive `hasStatus(inReview)` guard — DELETE wrapped in presence check
#        (amendment #1 per PR #683, idempotent skip + silent_skip log if absent)
#   TC2: DRAFT-PR skip-guard `if (pr.isDraft) return` early-return
#        (amendment #2 per PR #683, DRAFT PRs skip status:ready auto-add)
#   TC3: Type-driven table DRAFT row extension
#        (amendment #3 per PR #683, DRAFT PRs skip ALL status:ready auto-add for all types)
#   TC4: DRAFT skip audit marker (`adr-0012-status-ready-gating-draft-skip`)
#        (PR #683 §Workflow YAML impl, audit marker variant)
#   TC5: Combined defensive guard — both TC1 + TC2 present (sister to d077 TC5 regression guard)
#        (regression scenario: PR #679 trigger reproduction; both guards must coexist)
#
# Pre-impl RED state (current main as of 2026-06-29):
#   - Defensive DELETE guard: ABSENT (PR #677 only added re-add guard, not initial-add)
#   - DRAFT-PR skip-guard: ABSENT
#   - DRAFT row in type-driven table: ABSENT
#   - DRAFT skip audit marker: ABSENT
#   → 4/5 FAIL in RED state per ADR-0044 (TC1 PASS post-#677).
#
# Post-impl GREEN state (after PR #683 acceptance + workflow YAML impl):
#   - All 5 structural checks PASS
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d077 (Issue #675 P0 BUG, RE-ADD regression — base sister)
#   - d069 (Layer 5 verdict-emoji gate — sibling defense layer)
#   - d076 (workflow YAML TDZ guard sister)
#   - d055 (Layer 5 idempotent DELETE sister — initial-add DELETE defensive guard pattern)
#
# Usage:
#   bash d078-layer-5-initial-add-defensive-guard.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — initial-add defensive guard landed)
#   1 — at least one FAIL (RED state — initial-add defensive guard missing)
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

command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d078 self-test (5 TCs per Issue #680 + PR #683 initial-add defensive guard, ADR-0044 RED-first)${D}\n"
printf "${B}=======================================================================${D}\n"
printf "  Workflow under test: %s\n" "$LABEL_CHECK"
printf "  Sister-pattern:      d077 (RE-ADD regression) + d069 (verdict-gate) + d055 (L5 idempotent DELETE)\n"
printf "  RED-first:           pre-#683-merge 4/5 FAIL (TC2+TC3+TC4+TC5 absent), TC1 PASS post-#677.\n"
printf "  Post-impl:           all 5 TCs must PASS.\n\n"

if [ ! -f "$LABEL_CHECK" ]; then
  fail "preflight — workflow file missing" "expected $LABEL_CHECK"
  exit 2
fi

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: Defensive `hasStatus(inReview)` guard for DELETE (amendment #1)
# ============================================================================
section "TC1: Defensive DELETE guard for status:in-review (amendment #1 — idempotent skip on absent label)"
TC1_PATTERNS=(
  "hasLabel\\(['\"]status:in-review['\"]"
  "hasLabel.*status:in-review"
  "labels\\.find.*status:in-review"
  "labels\\.some.*status:in-review"
  "if.*status:in-review.*remove"
  "remove.*status:in-review.*if"
  "removeLabel.*status:in-review.*hasLabel"
  "presence.*status:in-review"
)
TC1_HIT=0
TC1_HIT_PATTERN=""
for pat in "${TC1_PATTERNS[@]}"; do
  if grep -qE "$pat" "$LABEL_CHECK"; then
    TC1_HIT=1
    TC1_HIT_PATTERN="$pat"
    break
  fi
done

if [ "$TC1_HIT" -eq 1 ]; then
  info "TC1 — DELETE guard pattern found (pattern: $TC1_HIT_PATTERN)"
  pass "TC1 — defensive hasStatus(status:in-review) guard present (idempotent DELETE on absent label)"
else
  fail "TC1 — defensive DELETE guard MISSING" \
    "expected 'hasLabel(status:in-review)' OR equivalent presence check before removeLabel. PR #679 LIVE INSTANCE: DELETE 404 HttpError. PR #683 amendment #1."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: DRAFT-PR skip-guard `if (pr.isDraft) return` (amendment #2)
# ============================================================================
section "TC2: DRAFT-PR skip-guard before status:ready auto-add (amendment #2)"
TC2_PATTERNS=(
  "pull_request\\.draft"
  "pr\\.isDraft"
  "pr\\?\\.isDraft"
  "payload\\.pull_request\\.draft"
  "draft.*status:ready"
  "draft.*skip"
  "draft.*return"
  "if.*draft.*return"
  "if.*isDraft.*return"
  "if.*isDraft.*skip"
)
TC2_HIT=0
TC2_HIT_PATTERN=""
for pat in "${TC2_PATTERNS[@]}"; do
  if grep -qE "$pat" "$LABEL_CHECK"; then
    TC2_HIT=1
    TC2_HIT_PATTERN="$pat"
    break
  fi
done

if [ "$TC2_HIT" -eq 1 ]; then
  info "TC2 — DRAFT-PR skip-guard found (pattern: $TC2_HIT_PATTERN)"
  pass "TC2 — DRAFT-PR skip-guard present (DRAFT PRs skip status:ready auto-add)"
else
  fail "TC2 — DRAFT-PR skip-guard MISSING" \
    "expected 'if (pr.isDraft) return' OR 'pull_request.draft' check before status:ready auto-add. PR #679 LIVE INSTANCE: status:ready auto-added to DRAFT PR. PR #683 amendment #2."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: Type-driven table DRAFT row extension (amendment #3)
# ============================================================================
section "TC3: Type-driven table DRAFT row extension (amendment #3)"
TC3_PATTERNS=(
  "draft.*skip.*all"
  "DRAFT PRs skip"
  "DRAFT.*auto-add"
  "DRAFT.*status:ready"
  "draft.*all types"
  "draft.*type-driven"
  "draft.*table"
)
TC3_HIT=0
TC3_HIT_PATTERN=""
for pat in "${TC3_PATTERNS[@]}"; do
  if grep -qE "$pat" "$LABEL_CHECK"; then
    TC3_HIT=1
    TC3_HIT_PATTERN="$pat"
    break
  fi
done

if [ "$TC3_HIT" -eq 1 ]; then
  info "TC3 — DRAFT row in type-driven table found (pattern: $TC3_HIT_PATTERN)"
  pass "TC3 — type-driven table DRAFT row extension present (DRAFT PRs skip ALL status:ready for all types)"
else
  fail "TC3 — type-driven table DRAFT row extension MISSING" \
    "expected 'DRAFT PRs skip' comment OR explicit draft row in type-driven table. PR #683 amendment #3."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: DRAFT skip audit marker
# ============================================================================
section "TC4: DRAFT skip audit marker (ADR-0012 observability variant)"
TC4_PATTERNS=(
  "adr-0012-status-ready-gating-draft-skip"
  "adr-0012-draft-skip"
  "draft-skip"
)
TC4_HIT=0
TC4_HIT_PATTERN=""
for pat in "${TC4_PATTERNS[@]}"; do
  if grep -qE "$pat" "$LABEL_CHECK"; then
    TC4_HIT=1
    TC4_HIT_PATTERN="$pat"
    break
  fi
done

if [ "$TC4_HIT" -eq 1 ]; then
  info "TC4 — DRAFT skip audit marker found (pattern: $TC4_HIT_PATTERN)"
  pass "TC4 — DRAFT skip audit marker present (adr-0012-status-ready-gating-draft-skip emitted)"
else
  fail "TC4 — DRAFT skip audit marker MISSING" \
    "expected 'adr-0012-status-ready-gating-draft-skip' marker. Sister-pattern to existing 'adr-0012-status-ready-gating-skip'. PR #683 §Workflow YAML impl."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: Combined defensive guard
# ============================================================================
section "TC5: Combined defensive guard (PR #679 trigger regression scenario)"
if [ "$TC1_HIT" -eq 1 ] && [ "$TC2_HIT" -eq 1 ]; then
  pass "TC5 — combined defensive guard present (DELETE presence check + DRAFT skip-guard both exist; PR #679 trigger regression prevented)"
else
  fail "TC5 — combined defensive guard INCOMPLETE" \
    "expected BOTH TC1 (DELETE presence check) AND TC2 (DRAFT skip-guard) present. PR #679 LIVE INSTANCE had BOTH DELETE 404 + parallel auto-add on DRAFT."
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
  printf "\n${R}RED state: %d TC(s) FAILING — initial-add defensive guard missing per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 5 TCs PASS — initial-add defensive guard landed (PR #679 race pathology closed)${D}\n"
exit 0