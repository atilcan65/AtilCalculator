#!/usr/bin/env bash
# d091-tmpl-source-files.sh — Issue #635 / STORY-S21-005 (.tmpl Source Files).
#
# Why this test exists
# --------------------
# Sprint 21 Wave 2 dispatch (Issue #690): STORY-S21-005 .tmpl Source Files —
# the foundation story for Wave 2 (downstream: S21-003, S21-006, S21-008, S21-009, S21-011).
# Without .tmpl sources, every template change means editing rendered output, losing the source.
#
# 3 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: AC1 .tmpl source files exist (≥20 per Leading Metrics)
#        count of files matching `*.tmpl` (excluding .venv, .git, .mypy_cache internals).
#   TC2: AC2 init script reads .tmpl and writes rendered output
#        init-template-repo.sh has .tmpl processing logic (loop OR placeholder resolution).
#   TC3: AC3 idempotent — two consecutive init runs on same clone = 0 diff
#        init-template-repo.sh has skip-if-rendered OR explicit idempotency marker for .tmpl handling.
#
# Pre-impl RED state (current main as of 2026-06-29, cycle ~#1243):
#   - AC1: 1 .tmpl file exists (CLAUDE.md.tmpl from prior partial work) → 1/20 → FAIL
#   - AC2: init-template-repo.sh has no .tmpl loop/placeholder resolution → FAIL
#   - AC3: init-template-repo.sh has no .tmpl-specific idempotency marker → FAIL
#   → 3/3 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after Issue #635 impl lands + PR squash):
#   - TC1: ≥20 .tmpl files (per Leading Metric)
#   - TC2: init-template-repo.sh has .tmpl→rendered processing
#   - TC3: init-template-repo.sh has .tmpl idempotency check
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d073 (S21-001 init-template-repo.sh — foundational, implements init script)
#   - d075 (S21-008 CLAUDE.md.tmpl — sister .tmpl story Wave 1)
#   - d078 (Issue #680 + PR #684 initial-add defensive — RETRO-016 sister)
#   - d081 (Issue #681 + PR #687 auto-verdict-by hook — RETRO-016 sister)
#   - d093 (Issue #633 + PR #694 TEMPLATE-README.md polish — Wave 1 sister)
#   - d091 (Issue #635 / STORY-S21-005 — Wave 2 foundation, this file)
#
# Sprint 21 dispatch refs:
#   - Issue #635 (impl, agent:developer, status:ready for tester claim)
#   - Issue #690 (PM Wave 2 dispatch)
#   - Issue #652 (Sprint 21 Joint Sizing ceremony, owner-ratified)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0012 4-cat invariant (test suite ships via PR per type:feature)
#   - ADR-0049 d-test framework
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#   - ADR-0059 cluster-squash doctrine (cluster #680+#681+#635+Wave 2 cadence)
#
# Naming note (per Issue #113 label-authority + PM Wave 2 direction cycle ~#1225):
#   Issue #635 body text says "d070 covers this" — STALE (pre-rename).
#   PM direction (cycle ~#1225): Wave 2 S21-005 d-test = d091 (renamed from d081
#   to avoid collision with cluster #681 d081 PR #687). Per Issue #113: PM
#   naming authority is canonical, body text is informational. This file uses d091.
#
# Usage:
#   bash d091-tmpl-source-files.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — .tmpl source files + init script processing + idempotency)
#   1 — at least one FAIL (RED state — impl not yet landed)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT_SCRIPT="${REPO_ROOT}/scripts/init-template-repo.sh"

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
command -v find >/dev/null 2>&1 || { echo "ERROR: find required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d091 self-test (3 TCs per Issue #635 / STORY-S21-005, ADR-0044 RED-first)${D}\n"
printf "${B}========================================================================${D}\n"
printf "  Target file:        %s\n" "$INIT_SCRIPT"
printf "  Sister-pattern:     d073 (S21-001) + d075 (S21-008) + d078 (Issue #680) + d081 (Issue #681) + d093 (Issue #633) + d091 (Issue #635)\n"
printf "  Pre-impl RED:       3/3 TCs FAIL by design per ADR-0044\n"
printf "  Wave 2 dispatch:    Issue #690 (PM, .tmpl foundation)\n"
printf "  Sprint 21 Epic E2:  Parameterization & Init Script\n\n"

if [ ! -f "$INIT_SCRIPT" ]; then
  fail "preflight — init-template-repo.sh missing" "expected $INIT_SCRIPT"
  exit 2
fi

EXIT_CODE=0

# ============================================================================
# TC1: AC1 — .tmpl source files exist (≥20 per Leading Metric)
# ============================================================================
section "TC1: AC1 — .tmpl source files exist (≥20 per Leading Metric)"
TMPL_COUNT="$(find "$REPO_ROOT" \
  -name '*.tmpl' \
  -type f \
  -not -path '*/.git/*' \
  -not -path '*/.venv/*' \
  -not -path '*/.mypy_cache/*' \
  -not -path '*/node_modules/*' \
  2>/dev/null | wc -l | tr -d '[:space:]')"

TMPL_FILES_LIST="$(find "$REPO_ROOT" \
  -name '*.tmpl' \
  -type f \
  -not -path '*/.git/*' \
  -not -path '*/.venv/*' \
  -not -path '*/.mypy_cache/*' \
  -not -path '*/node_modules/*' \
  2>/dev/null | sed "s|^${REPO_ROOT}/||" | sort | head -25)"

if [ "$TMPL_COUNT" -ge 20 ]; then
  pass "TC1 — ${TMPL_COUNT} .tmpl source files present (≥20 threshold met, AC1 met)"
else
  fail "TC1 — ${TMPL_COUNT}/20 .tmpl source files present (insufficient, AC1 not yet met)" \
    "expected ≥20 .tmpl files per Leading Metric. Current files: ${TMPL_FILES_LIST}. Issue #635 AC1; PM Wave 2 foundation."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: AC2 — init script reads .tmpl and writes rendered output
# ============================================================================
section "TC2: AC2 — init script has .tmpl→rendered processing logic"
# Pattern: init-template-repo.sh contains ACTIVE CODE (not just comment) that processes
# .tmpl files. Excludes lines starting with # (full-line comments). Acceptable patterns:
#   - for src in "$ROOT"/**/*.tmpl / find ... -name '*.tmpl' (loop over .tmpl files)
#   - sed -e "s/{{...}}/$value/g" applied to .tmpl (placeholder resolution)
#   - envsubst / mustache / jinja call (template engine)
#   - .tmpl.*render or render.*\.tmpl as code, not comment
#
# KNOWN LIMITATION (arch 9-Lens 🟡 suggestion #1, cycle ~#1233):
# The regex `^[[:space:]]*[0-9]+:#'` only excludes FULL-LINE comments. Inline comments
# like `code # inline-rmq` would still match the grep -E output (but still constitute
# "active code" semantically, so this is acceptable per ADR-0049 d-test convention).
# Documented here for honest d-test maintenance; if a false-positive arises from inline
# comments in practice, expand the regex to require non-# content before # marker.
# Sister-pattern check: d073/d075/d078/d081/d093 also use full-line exclusion.
TMPL_PROCESSING_PATTERN="$(grep -nE \
  '(\*\.tmpl|sed.*tmpl|envsubst|mustache|jinja|render.*\.tmpl|\.tmpl.*render)' \
  "$INIT_SCRIPT" 2>/dev/null | grep -vE '^[[:space:]]*[0-9]+:#' | head -5)"

if [ -n "$TMPL_PROCESSING_PATTERN" ]; then
  info "TC2 — .tmpl processing pattern found in init-template-repo.sh (active code):"
  printf "    %s\n" "$TMPL_PROCESSING_PATTERN"
  pass "TC2 — init-template-repo.sh has active .tmpl→rendered processing logic (AC2 met)"
else
  fail "TC2 — init-template-repo.sh has NO active .tmpl→rendered processing logic (AC2 not yet met, comment-only matches excluded)" \
    "expected ACTIVE CODE (non-comment) for: loop over *.tmpl, sed/envsubst/template-engine call, or render .tmpl. Issue #635 AC2; PM Wave 2 foundation."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: AC3 — idempotency marker for .tmpl handling (two consecutive runs = 0 diff)
# ============================================================================
section "TC3: AC3 — idempotency marker for .tmpl handling"
# Pattern: init-template-repo.sh has explicit skip-if-rendered logic for .tmpl files
# OR mentions idempotency in .tmpl context. Acceptable patterns:
#   - if [ -f "$rendered" ] / [ -f dest ] skip / already-rendered
#   - explicit "idempotent" mention within 5 lines of .tmpl reference
#   - rendered-file existence check OR md5sum/diff check
IDEMPOTENCY_PATTERN="$(grep -nE \
  '(\[\[ -f .*rendered \]\]|\[ -f .*dest \]; then|already.rendered|idempotent.*tmpl|tmpl.*idempotent)' \
  "$INIT_SCRIPT" 2>/dev/null | head -5)"

if [ -n "$IDEMPOTENCY_PATTERN" ]; then
  info "TC3 — idempotency marker for .tmpl handling found:"
  printf "    %s\n" "$IDEMPOTENCY_PATTERN"
  pass "TC3 — init-template-repo.sh has .tmpl idempotency marker (AC3 met)"
else
  fail "TC3 — init-template-repo.sh has NO .tmpl idempotency marker (AC3 not yet met)" \
    "expected skip-if-rendered pattern ([ -f \"\$rendered\" ]) OR explicit idempotency marker in .tmpl context. Issue #635 AC3; ensures deterministic re-runs."
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
  printf "\n${R}RED state: %d TC(s) FAILING — .tmpl source files impl not yet landed per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 3 TCs PASS — .tmpl source files + init script processing + idempotency landed (Issue #635 AC1+AC2+AC3 met)${D}\n"
exit 0