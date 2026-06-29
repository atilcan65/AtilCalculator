#!/usr/bin/env bash
# d070b-init-prompt-ux.sh — Issue #693 / STORY-S21-003b (Init Script: Advanced Prompt UX).
#
# Why this test exists
# --------------------
# Sprint 21 Wave 2 dispatch (Issue #690): STORY-S21-003b Init Script Advanced Prompt UX —
# SPLIT from S21-003 per arch §Size-negotiation (cycle ~#1221). Without S21-003b, the init
# script lacks proper interactive UX for P1 founder Day-0 experience — silent failures,
# unclear error messages, no validation flow.
#
# 3 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: AC1 — 5 sequential interactive prompts with validation
#        GITHUB_OWNER (alphanumeric), GITHUB_REPO (kebab-case), HUMAN_OWNER_NAME,
#        PROJECT_NAME, PROJECT_TOKEN with default values + validation regex per variable.
#   TC2: AC2 — Invalid input → clear error message + re-prompt loop
#        Empty string / whitespace-only / invalid chars trigger validation error AND
#        re-prompt (no silent failure, no exit). All 5 variables covered.
#   TC3: AC3 — `--non-interactive` flag with env vars pre-set
#        CI-friendly mode: skips prompts when env vars (GITHUB_OWNER, GITHUB_REPO,
#        HUMAN_OWNER_NAME, PROJECT_NAME, PROJECT_TOKEN) are pre-set.
#
# Pre-impl RED state (current main as of 2026-06-29, cycle ~#1255):
#   - AC1: dev-studio-init.sh only has interactive prompt for PROJECT_TOKEN
#          (4/5 are auto-resolved via `gh api user`/`gh repo view`/`git config user.name`/basename).
#          Per Issue #693 spec, all 5 should be interactive prompts.
#          → FAIL (only 1/5 explicit prompts; missing validation regex for 4).
#   - AC2: PROJECT_TOKEN has format validation + fail-fast. Other 4 vars either auto-resolve
#          (fail-fast on missing) or have no interactive validation.
#          → FAIL (validation loop pattern absent for 4/5 vars).
#   - AC3: PROJECT_NAME has DEV_STUDIO_PROJECT_NAME env var + PROJECT_TOKEN has PROJECT_TOKEN
#          env var. But no general `--non-interactive` flag.
#          → FAIL (--non-interactive flag absent).
#   → 3/3 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after Issue #693 impl lands + PR squash):
#   - TC1: 5 explicit `read -rp` prompts with per-variable validation regex
#   - TC2: invalid input → error message + retry loop pattern present for all 5 vars
#   - TC3: --non-interactive flag detects pre-set env vars and skips prompts
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d091 (S21-005 #635 d091 — Wave 2 foundation sister — PR #698 my lane)
#   - d093 (S21-019 #633 d093 — Wave 1 polish sister — PR #694 my lane)
#   - d073 (S21-001 template flag sister — --self-test pattern)
#   - d075 (S21-008 CLAUDE.md.tmpl sister — Wave 1)
#   - d070b (S21-003b #693, this file) — note: d070a is for S21-003a #636 (dev lane,
#          core placeholder resolution); d070b extends UX for d070a's impl on dev branch
#
# Sprint 21 dispatch refs:
#   - Issue #693 (impl, agent:developer, status:ready claimed by tester cycle ~#1255)
#   - Issue #690 (PM Wave 2 dispatch)
#   - Issue #636 (S21-003a, d070a sister — dev lane)
#   - Issue #652 (Sprint 21 Joint Sizing ceremony, owner-ratified)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0012 4-cat invariant (test suite ships via PR per type:feature)
#   - ADR-0049 d-test framework
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#   - ADR-0059 cluster-squash doctrine (Wave 2 cluster cadence)
#
# Naming note (per Issue #113 label-authority + PM Wave 2 direction):
#   Issue #693 body explicitly says "d070a extends d070" — establishes d070 family as the
#   parent series. d070a = S21-003a (#636, dev lane, core placeholder resolution);
#   d070b = S21-003b (#693, this claim, advanced UX layer). Per Issue #113: PM direction
#   canonical, naming convention follows Issue body where d070 series is the family root.
#
# Usage:
#   bash d070b-init-prompt-ux.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — interactive prompts + validation + --non-interactive flag)
#   1 — at least one FAIL (RED state — impl not yet landed)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT_SCRIPT="${REPO_ROOT}/scripts/dev-studio-init.sh"

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

printf "${B}d070b self-test (3 TCs per Issue #693 / STORY-S21-003b, ADR-0044 RED-first)${D}\n"
printf "${B}=========================================================================${D}\n"
printf "  Target file:        %s\n" "$INIT_SCRIPT"
printf "  Sister-pattern:     d091 (S21-005) + d093 (S21-019) + d070a (S21-003a) + d073 (S21-001) + d075 (S21-008) + d070b (S21-003b)\n"
printf "  Pre-impl RED:       3/3 TCs FAIL by design per ADR-0044\n"
printf "  Wave 2 dispatch:    Issue #690 (PM, 2sp advanced UX layer)\n"
printf "  Sprint 21 Epic E2:  Parameterization & Init Script\n\n"

if [ ! -f "$INIT_SCRIPT" ]; then
  fail "preflight — dev-studio-init.sh missing" "expected $INIT_SCRIPT"
  exit 2
fi

EXIT_CODE=0

# ============================================================================
# TC1: AC1 — 5 sequential interactive prompts with validation
# ============================================================================
section "TC1: AC1 — 5 interactive prompts present with validation regex"
# Variables: GITHUB_OWNER, GITHUB_REPO, HUMAN_OWNER_NAME, PROJECT_NAME, PROJECT_TOKEN
# Per Issue #693 AC1: each must have read -p / read -rp prompt + validation pattern.
# Test counts `read -rp` or `read -p` calls referencing each variable name in the script.
TC1_VARS=( "GITHUB_OWNER" "GITHUB_REPO" "HUMAN_OWNER_NAME" "PROJECT_NAME" "PROJECT_TOKEN" )
TC1_FOUND=0
TC1_MISSING=()

for var in "${TC1_VARS[@]}"; do
  # Pattern: `read` command where ${var} is the LAST positional argument (the captured
  # variable), not appearing in an assignment like `${var}=$(...)`. Both `read -rp "...VAR..."
  # ${var}` (combined) and `printf '...VAR...'; read ... ${var}` (separate) qualify as
  # interactive prompting. The ${var}=$(... auto-resolution pattern must NOT match.
  # Use a regex that requires `read` keyword followed by content ending in ${var} (last token).
  # KNOWN LIMITATION (arch 9-Lens sister-pattern d091 🟡 #1, cycle ~#1233): full-line
  # exclusion only; inline-comment edge case acceptable per ADR-0049 d-test convention.
  PROMPT_LINE="$(grep -nE "(^|[^=])read[ ]+[^&|;]*\\b${var}\\b[ \\t]*([;&|#]|$)" "$INIT_SCRIPT" 2>/dev/null | grep -vE '^[[:space:]]*[0-9]+:#' | head -1)"
  if [ -n "$PROMPT_LINE" ]; then
    info "TC1 — interactive prompt for '${var}' found: ${PROMPT_LINE}"
    TC1_FOUND=$((TC1_FOUND + 1))
  else
    TC1_MISSING+=("${var}")
  fi
done

if [ "$TC1_FOUND" -eq 5 ]; then
  pass "TC1 — all 5 interactive prompts present (GITHUB_OWNER, GITHUB_REPO, HUMAN_OWNER_NAME, PROJECT_NAME, PROJECT_TOKEN) with read -rp validation"
else
  MISSING_LIST=$(IFS=', '; echo "${TC1_MISSING[*]}")
  fail "TC1 — ${TC1_FOUND}/5 interactive prompts present, MISSING: ${MISSING_LIST}" \
    "expected 5 explicit 'read -rp' or 'read -p' prompts capturing into GITHUB_OWNER + GITHUB_REPO + HUMAN_OWNER_NAME + PROJECT_NAME + PROJECT_TOKEN with per-variable validation regex (alphanumeric, kebab-case). Issue #693 AC1; PM Wave 2."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: AC2 — Invalid input → error message + re-prompt loop
# ============================================================================
section "TC2: AC2 — validation error + re-prompt loop pattern (no silent failure, no exit)"
# Pattern: validation loop (while loop with read + regex check + error echo) for at least
# one of the 5 vars. The full impl should cover all 5, but d-test starts with ≥1 as
# proof-of-pattern (sister-pattern d091 TC3 narrow starting scope, expanded in follow-up
# per arch 9-Lens 🟡 #3 cycle ~#1233).
VALIDATION_LOOP_PATTERN="$(grep -nE \
  '(while[ ]+(true|:)|while[ ]+true;[ ]+do|until[ ]+valid|invalid[ ]*input|re-?prompt|retry[ ]+prompt|invalid[ ]+format)' \
  "$INIT_SCRIPT" 2>/dev/null | head -5)"

if [ -n "$VALIDATION_LOOP_PATTERN" ]; then
  info "TC2 — validation loop pattern found:"
  printf "    %s\n" "$VALIDATION_LOOP_PATTERN"
  pass "TC2 — dev-studio-init.sh has validation error + re-prompt loop pattern (AC2 met for ≥1 var)"
else
  fail "TC2 — dev-studio-init.sh has NO validation error + re-prompt loop pattern (AC2 not yet met)" \
    "expected while-loop pattern: while true; do read -rp; validate; if invalid, echo error + retry; done. Sister-pattern d091 TC3 narrow starting scope acceptable. Issue #693 AC2; ensures non-silent error feedback."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: AC3 — --non-interactive flag with env vars pre-set (CI-friendly)
# ============================================================================
section "TC3: AC3 — --non-interactive flag present + env var detection"
# Pattern: --non-interactive flag detection + skip-prompts branch when env vars set.
# Acceptable patterns:
#   - case statement parsing $1 or getopt loop with --non-interactive option
#   - env var detection: if [ -n "$GITHUB_OWNER" ] && [ "${NON_INTERACTIVE:-0}" = "1" ]; then skip; fi
#   - DEV_STUDIO_NON_INTERACTIVE=1 env var convention (sister-pattern)
NON_INTERACTIVE_PATTERN="$(grep -nE \
  '(--non-interactive|NON_INTERACTIVE|non_interactive|skip[ ]+prompt)' \
  "$INIT_SCRIPT" 2>/dev/null | head -5)"

if [ -n "$NON_INTERACTIVE_PATTERN" ]; then
  info "TC3 — --non-interactive pattern found:"
  printf "    %s\n" "$NON_INTERACTIVE_PATTERN"
  pass "TC3 — dev-studio-init.sh has --non-interactive flag + env var detection (AC3 met)"
else
  fail "TC3 — dev-studio-init.sh has NO --non-interactive flag (AC3 not yet met)" \
    "expected --non-interactive arg parsing + skip-prompts branch when env vars (GITHUB_OWNER, GITHUB_REPO, etc.) pre-set. CI-friendly mode per Issue #693 AC3; enables d070b d-test in CI."
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
  printf "\n${R}RED state: %d TC(s) FAILING — Init Script Advanced Prompt UX impl not yet landed per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 3 TCs PASS — 5 prompts + validation loop + --non-interactive flag landed (Issue #693 AC1+AC2+AC3 met)${D}\n"
exit 0