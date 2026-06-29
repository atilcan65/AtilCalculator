#!/usr/bin/env bash
# d093-template-readme-content.sh — Issue #633 / STORY-S21-019 (TEMPLATE-README.md polish).
#
# Why this test exists
# --------------------
# Sprint 21 Wave 1 dispatch (Issue #689): STORY-S21-019 TEMPLATE-README.md Polish —
# the README is the first impression for new users. Polish = trust signal.
#
# 3 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: AC1 badges (CI status, license, template-version)
#        Each badge = either shields.io markdown image OR GitHub Actions badge URL.
#   TC2: AC2 agents (5) + workflows (5) enumerated
#        5 agents NAMED in body text + ≥5 workflows referenced by filename.
#   TC3: AC3 links (4 doc files)
#        ONBOARDING.md + TELEGRAM-SETUP.md + CONTEXT-HYGIENE.md + ADR-INDEX.md
#        — each as markdown link or anchor reference text.
#
# Pre-impl RED state (current main as of 2026-06-29):
#   - AC1: 0/3 badge patterns matched (no shields.io badges present)
#   - AC2: agents 5/5 NAMED; workflows only ci.yml (1/10) → FAIL
#   - AC3: TELEGRAM-SETUP + CONTEXT-HYGIENE present (2/4); ONBOARDING + ADR-INDEX missing (2/4) → FAIL
#   → 3/3 TCs FAIL (or 1/3 PASS for AC2 agents half) = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after Issue #633 impl lands + PR squash):
#   - TC1: 3/3 badges present
#   - TC2: 5/5 agents + ≥5/10 workflows referenced
#   - TC3: 4/4 doc links present (or 3/4 if ONBOARDING.md stays placeholder per Wave 5 dependency)
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d078 (Issue #680 + PR #683 initial-add defensive guard — RETRO-016 sister)
#   - d081 (Issue #681 + PR #686 auto-verdict-by hook — RETRO-016 sister)
#   - d069 (Layer 5 verdict-emoji gate — sibling defense layer)
#   - d077 (Layer 5 misfire regression — sibling defense layer)
#
# Sprint 21 dispatch refs:
#   - Issue #633 (impl, agent:developer, status:in-progress)
#   - Issue #689 (PM Wave 1 dispatch, d093 owed by tester per "Tester lane: 1 d-test owed")
#   - Issue #652 (Sprint 21 Joint Sizing ceremony, owner-ratified)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0012 4-cat invariant (test suite ships via PR per type:feature)
#   - ADR-0049 d-test framework
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#
# Usage:
#   bash d093-template-readme-content.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — TEMPLATE-README.md polished)
#   1 — at least one FAIL (RED state — TEMPLATE-README.md not yet polished)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TARGET="${REPO_ROOT}/TEMPLATE-README.md"

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

printf "${B}d093 self-test (3 TCs per Issue #633 / STORY-S21-019, ADR-0044 RED-first)${D}\n"
printf "${B}========================================================================${D}\n"
printf "  Target file:        %s\n" "$TARGET"
printf "  Sister-pattern:     d078 (Issue #680) + d081 (Issue #681) + d069 (verdict-gate)"
printf "  Pre-impl RED:       3/3 TCs FAIL by design per ADR-0044"
printf "  Wave 1 dispatch:    Issue #689 (PM, 4sp)"
printf "  Sprint 21 Epic E10: documentation\n\n"

if [ ! -f "$TARGET" ]; then
  fail "preflight — TEMPLATE-README.md missing" "expected $TARGET"
  exit 2
fi

EXIT_CODE=0

# ============================================================================
# TC1: AC1 badges (CI status, license, template-version)
# ============================================================================
section "TC1: AC1 — badges present (CI status, license, template-version)"
TC1_BADGE_NAMES=( "ci" "license" "template-version" )
TC1_FOUND=0
TC1_MISSING=()
for badge in "${TC1_BADGE_NAMES[@]}"; do
  # Badge pattern: markdown image with shields.io / img.shields / badge string OR explicit badge keyword in markdown
  if grep -qiE "(\[!\[.*\]\(.*(shields\.io|img\.shields|badge)|badge.*${badge}|${badge}.*badge)" "$TARGET" 2>/dev/null; then
    info "TC1 — badge '${badge}' pattern found"
    TC1_FOUND=$((TC1_FOUND + 1))
  else
    TC1_MISSING+=("${badge}")
  fi
done

if [ "$TC1_FOUND" -eq 3 ]; then
  pass "TC1 — all 3 badges present (CI status, license, template-version)"
else
  BADGE_NAMES=$(IFS=', '; echo "${TC1_MISSING[*]}")
  fail "TC1 — ${TC1_FOUND}/3 badges present, MISSING: ${BADGE_NAMES}" \
    "expected shields.io markdown image OR badge keyword for: CI status, license, template-version. Issue #633 AC1; PM Wave 1 polish."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: AC2 — 5 agents NAMED + ≥5 workflows listed (by filename)
# ============================================================================
section "TC2: AC2 — 5 agents NAMED + ≥5 workflows referenced by filename"
TC2_AGENT_NAMES=( "Product Manager" "Architect" "Developer" "Tester" "Orchestrator" )
TC2_AGENTS_FOUND=0
TC2_AGENTS_MISSING=()
for agent in "${TC2_AGENT_NAMES[@]}"; do
  if grep -qF "$agent" "$TARGET"; then
    TC2_AGENTS_FOUND=$((TC2_AGENTS_FOUND + 1))
  else
    TC2_AGENTS_MISSING+=("$agent")
  fi
done

TC2_WF_FILES=( "ci.yml" "label-check.yml" "lint-and-test.yml" "status-label-to-board.yml" "post-squash.yml" )
TC2_WFS_FOUND=0
TC2_WFS_MISSING=()
for wf in "${TC2_WF_FILES[@]}"; do
  if grep -qF "$wf" "$TARGET"; then
    TC2_WFS_FOUND=$((TC2_WFS_FOUND + 1))
  else
    TC2_WFS_MISSING+=("$wf")
  fi
done

if [ "$TC2_AGENTS_FOUND" -eq 5 ] && [ "$TC2_WFS_FOUND" -ge 5 ]; then
  pass "TC2 — 5/5 agents NAMED + ${TC2_WFS_FOUND}/5 workflows referenced (AC2 met)"
else
  AGENT_MSG=""
  if [ "$TC2_AGENTS_FOUND" -ne 5 ]; then
    AGENT_NAMES=$(IFS=', '; echo "${TC2_AGENTS_MISSING[*]}")
    AGENT_MSG="agents: ${TC2_AGENTS_FOUND}/5 named (missing: ${AGENT_NAMES})"
  fi
  WF_MSG=""
  if [ "$TC2_WFS_FOUND" -lt 5 ]; then
    WF_NAMES=$(IFS=', '; echo "${TC2_WFS_MISSING[*]}")
    WF_MSG="workflows: ${TC2_WFS_FOUND}/5 referenced (missing: ${WF_NAMES})"
  fi
  fail "TC2 — partial AC2 coverage. ${AGENT_MSG}${AGENT_MSG:+; }${WF_MSG}" \
    "expected all 5 agents NAMED in body text + ≥5 workflows listed by filename. Issue #633 AC2; PM Wave 1 polish."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: AC3 — 4 doc file links (ONBOARDING, TELEGRAM-SETUP, CONTEXT-HYGIENE, ADR-INDEX)
# ============================================================================
section "TC3: AC3 — links to 4 doc files (ONBOARDING.md, TELEGRAM-SETUP.md, CONTEXT-HYGIENE.md, ADR-INDEX.md)"
TC3_DOC_FILES=( "ONBOARDING.md" "TELEGRAM-SETUP.md" "CONTEXT-HYGIENE.md" "ADR-INDEX.md" )
TC3_FOUND=0
TC3_MISSING=()
for doc in "${TC3_DOC_FILES[@]}"; do
  # Accept: markdown link OR anchor reference text containing the doc filename
  if grep -qE "(\[.*\]\([^)]*${doc}|\b${doc}\b)" "$TARGET"; then
    info "TC3 — doc link '${doc}' present"
    TC3_FOUND=$((TC3_FOUND + 1))
  else
    TC3_MISSING+=("$doc")
  fi
done

if [ "$TC3_FOUND" -eq 4 ]; then
  pass "TC3 — all 4 doc links present (ONBOARDING.md, TELEGRAM-SETUP.md, CONTEXT-HYGIENE.md, ADR-INDEX.md)"
else
  DOC_NAMES=$(IFS=', '; echo "${TC3_MISSING[*]}")
  fail "TC3 — ${TC3_FOUND}/4 doc links present, MISSING: ${DOC_NAMES}" \
    "expected markdown link OR anchor reference text for: ONBOARDING.md (Wave 5 placeholder OK), TELEGRAM-SETUP.md, CONTEXT-HYGIENE.md, ADR-INDEX.md. Issue #633 AC3; PM Wave 1 polish."
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
  printf "\n${R}RED state: %d TC(s) FAILING — TEMPLATE-README.md polish not yet landed per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 3 TCs PASS — TEMPLATE-README.md polish landed (Issue #633 AC1+AC2+AC3 met)${D}\n"
exit 0
