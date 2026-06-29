#!/usr/bin/env bash
# d075-claude-md-content.sh — STORY-S21-008 CLAUDE.md.tmpl full doctrine content —
# RED-first regression guard for the rendered project's context file.
#
# Why this test exists
# --------------------
# Sprint 21 E1 (Template Repository Structure) S21-008 demands that
# `CLAUDE.md.tmpl` be present at the repo root with:
#   - AC1: ≥200 lines, 12 required sections (Product, Team, Process, Tech stack,
#          Definition of Done, Communication, Auto-Ping Hard-Rule, Autonomy Loop,
#          Required Label Set, Handoff Discipline, Things agents must NEVER do,
#          File ownership matrix)
#   - AC2: references `docs/decisions/` for ADRs (≥3 occurrences)
#   - AC3: 6 placeholders resolved by init script (`{{REPO_ROOT}}`,
#          `{{GITHUB_OWNER}}`, `{{GITHUB_REPO}}`, `{{HUMAN_OWNER_NAME}}`,
#          `{{PROJECT_NAME}}`, `{{HEARTBEAT_DIR}}`)
#
# Per ADR-0001 §1 (single-repo template architecture), `CLAUDE.md.tmpl` is the
# SOURCE OF TRUTH for downstream project agents' context. The init script
# `scripts/dev-studio-init.sh` renders it to `CLAUDE.md` (gitignored output).
# Without the .tmpl, downstream clones have no doctrine and the agent soul files
# can dangle without coordination.
#
# ADR-0049 d-test framework sister-pattern: ≥5 TCs + --self-test contract,
# bash + grep + awk + wc + init script (no Python dependency).
#
# 7 TCs (per ADR-0044 RED-first + ADR-0049 d-test framework sister-pattern):
#   TC1: Line count ≥ 200 (AC1 base case — content breadth)
#   TC2: 12 required section headings present (AC1 doctrinal completeness)
#   TC3: 6 placeholders present in .tmpl source (AC3 base case)
#   TC4: Adversarial — dry-run init renders 0 unresolved placeholders (AC3 final)
#   TC5: docs/decisions/ referenced ≥ 3 times (AC2 cross-ref density)
#   TC6: .gitignore contains `CLAUDE.md` (template-grade contract: .tmpl is source)
#   TC7: Adversarial — no extra/unknown `{{...}}` placeholders (typo regression guard)
#
# Pre-impl RED state (Issue #632 / current main as of 2026-06-29):
#   - `CLAUDE.md.tmpl`: MISSING at repo root
#   - TC1 line-count: 0 lines (file missing)
#   - TC2 12 sections: all FAIL (no file)
#   - TC3 6 placeholders: all FAIL (no file)
#   - TC4 dry-run: skipped (no .tmpl to render)
#   - TC5 docs/decisions/ refs: 0
#   - TC6 .gitignore line: missing
#   - TC7 unknown placeholders: N/A
#   → All 7 TCs FAIL in RED state per ADR-0044.
#
# Post-impl GREEN state (target, after PR #668 squash):
#   - CLAUDE.md.tmpl present, 273 lines, 12 required sections
#   - All 6 known placeholders resolved cleanly
#   - docs/decisions/ referenced multiple times + ADR list at bottom
#   - .gitignore excludes rendered CLAUDE.md
#   - No stray `{{...}}` that init can't resolve
#   → All 7 TCs PASS in GREEN state.
#
# Usage:
#   bash d075-claude-md-content.sh --self-test     # run inline fixture (7 TCs)
#
# Env vars (override defaults):
#   REPO_ROOT                    path to the repo (default: parent of this script's parent)
#   INIT_SCRIPT                  path to dev-studio-init.sh (default: REPO_ROOT/scripts/dev-studio-init.sh)
#
# Exit codes:
#   0 — all PASS (GREEN state — file meets all 3 ACs)
#   1 — at least one FAIL (RED state — file missing or ACs unsatisfied)
#   2 — preflight failure (missing tool, init script, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
TMPL_PATH="${REPO_ROOT}/CLAUDE.md.tmpl"
INIT_SCRIPT="${INIT_SCRIPT:-${REPO_ROOT}/scripts/dev-studio-init.sh}"

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

# Pre-flight: tools + repo root reachable
command -v wc >/dev/null 2>&1 || { echo "ERROR: wc required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required for TC2/TC3/TC5/TC7" >&2; exit 2; }
[ -d "${REPO_ROOT}" ] || { echo "ERROR: REPO_ROOT invalid: ${REPO_ROOT}" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d075 self-test (7 TCs per STORY-S21-008 CLAUDE.md.tmpl content, ADR-0044 RED-first)${D}\n"
printf "${B}====================================================================================${D}\n"
printf "  Repo root:       %s\n" "$REPO_ROOT"
printf "  .tmpl path:      %s\n" "$TMPL_PATH"
printf "  Init script:     %s\n" "$INIT_SCRIPT"
printf "  Sister-pattern:  d073 (S21-001 template flag sister), d069 (AC1 verdict-gate sister)\n"
printf "  RED-first:       pre-impl all 7 TCs must FAIL.\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: Line count ≥ 200 (AC1 base case — doctrinal breadth)
# ============================================================================
section "TC1: wc -l CLAUDE.md.tmpl ≥ 200 (AC1 base case)"
if [ ! -f "${TMPL_PATH}" ]; then
  fail "TC1 — CLAUDE.md.tmpl missing at repo root" \
    "expected CLAUDE.md.tmpl to exist at ${TMPL_PATH}. Per Issue #632 S21-008 AC1: ≥200 lines of full doctrine. File missing → content missing → downstream clones will lack project context. RED-first confirmed."
  EXIT_CODE=1
  LINE_COUNT=0
else
  LINE_COUNT="$(wc -l < "${TMPL_PATH}" 2>/dev/null || echo 0)"
  if [ "${LINE_COUNT}" -ge 200 ]; then
    info "TC1 — line count = ${LINE_COUNT} (AC1 base case satisfied: ≥200)"
    pass "TC1 — line count ≥ 200 (${LINE_COUNT} lines present)"
  else
    fail "TC1 — line count < 200 (got: ${LINE_COUNT})" \
      "expected ≥200 lines per AC1 doctrinal breadth. Got ${LINE_COUNT}. Add more doctrine — the 12 required sections must each have body content. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC2: 12 required section headings present (AC1 doctrinal completeness)
# ============================================================================
section "TC2: 12 required section headings present (AC1 doctrinal completeness, case-insensitive grep)"
if [ ! -f "${TMPL_PATH}" ]; then
  fail "TC2 — cannot check sections (CLAUDE.md.tmpl missing)" \
    "TC1 prerequisite not met. See TC1 failure above."
  EXIT_CODE=1
  REQUIRED_SECTIONS_MISSING=12
else
  # 12 sections per AC1 canonical list. Each must appear as a level-2 heading.
  REQUIRED_SECTIONS=(
    "## Product"
    "## Team"
    "## Process"
    "## Tech stack"
    "## Definition of Done"
    "## Communication"
    "## Auto-Ping Hard-Rule"
    "## Autonomy Loop"
    "## Required Label Set"
    "## Handoff Label Discipline"
    "## Things agents must NEVER do"
    "## File ownership matrix"
  )
  MISSING_LIST=""
  MISSING_COUNT=0
  for sec in "${REQUIRED_SECTIONS[@]}"; do
    # case-insensitive grep on the whole h2 heading; -F fixed-string mode,
    # -w word-boundary not used (h2 headings start at column 0)
    if ! grep -qiF "${sec}" "${TMPL_PATH}"; then
      MISSING_COUNT=$((MISSING_COUNT + 1))
      MISSING_LIST="${MISSING_LIST}${sec} | "
    fi
  done
  if [ "${MISSING_COUNT}" -eq 0 ]; then
    info "TC2 — all 12 required sections present (canonical AC1 list verified)"
    pass "TC2 — 12 required sections present (Product, Team, Process, Tech stack, DoD, Communication, Auto-Ping, Autonomy Loop, Required Label Set, Handoff, Things NEVER, File ownership)"
  else
    fail "TC2 — ${MISSING_COUNT}/12 required section(s) missing" \
      "expected all 12 canonical AC1 sections. Missing: ${MISSING_LIST}RED-first confirmed. Per ADR-0012 §File ownership matrix (in the .tmpl) the 12 sections are the doctrinal backbone for every agent lane."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC3: 6 placeholders present in .tmpl source (AC3 base case)
# ============================================================================
section "TC3: 6 placeholders present in .tmpl source (AC3 base case)"
EXPECTED_PLACEHOLDERS=(
  "{{REPO_ROOT}}"
  "{{GITHUB_OWNER}}"
  "{{GITHUB_REPO}}"
  "{{HUMAN_OWNER_NAME}}"
  "{{PROJECT_NAME}}"
  "{{HEARTBEAT_DIR}}"
)
if [ ! -f "${TMPL_PATH}" ]; then
  fail "TC3 — cannot check placeholders (CLAUDE.md.tmpl missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  MISSING_PH=""
  MISSING_PH_COUNT=0
  for ph in "${EXPECTED_PLACEHOLDERS[@]}"; do
    if ! grep -qF "${ph}" "${TMPL_PATH}"; then
      MISSING_PH_COUNT=$((MISSING_PH_COUNT + 1))
      MISSING_PH="${MISSING_PH}${ph} | "
    fi
  done
  if [ "${MISSING_PH_COUNT}" -eq 0 ]; then
    info "TC3 — all 6 expected placeholders present in .tmpl"
    pass "TC3 — 6 placeholders present (REPO_ROOT, GITHUB_OWNER, GITHUB_REPO, HUMAN_OWNER_NAME, PROJECT_NAME, HEARTBEAT_DIR)"
  else
    fail "TC3 — ${MISSING_PH_COUNT}/6 placeholder(s) missing" \
      "expected all 6 placeholders per AC3. Missing: ${MISSING_PH}. Init script sed-replaces these in dev-studio-init.sh lines 434-439; if .tmpl omits any, downstream rendered CLAUDE.md will have stale or empty values. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC4: Adversarial — init script's exact sed pipeline leaves 0 unresolved placeholders (AC3 final)
# ============================================================================
section 'TC4: init scripts exact sed pipeline (lines 434-439) leaves 0 unresolved placeholders (AC3 final integration check)'
if [ ! -f "${TMPL_PATH}" ]; then
  fail "TC4 — cannot run sed pipeline (CLAUDE.md.tmpl missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
elif [ ! -f "${INIT_SCRIPT}" ]; then
  fail "TC4 — init script missing: ${INIT_SCRIPT}" \
    "expected dev-studio-init.sh to exist (sister-pattern impl per ADR-0050 §C9). RED-first confirmed."
  EXIT_CODE=1
else
  # Replicate init's exact sed pipeline (lines 434-439 of dev-studio-init.sh):
  #   sed -e "s|{{REPO_ROOT}}|${REPO_ROOT}|g" \
  #       -e "s|{{GITHUB_OWNER}}|${GITHUB_OWNER}|g" \
  #       -e "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" \
  #       -e "s|{{HUMAN_OWNER_NAME}}|${HUMAN_OWNER_NAME}|g" \
  #       -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
  #       -e "s|{{HEARTBEAT_DIR}}|${HEARTBEAT_DIR}|g" \
  # Then apply init's verify() regex (line 517): grep -lE "\{\{[A-Z_]+\}\}"
  SANDBOX_TMP="$(mktemp -d)"
  trap 'rm -rf "${SANDBOX_TMP}"' EXIT

  # Render to a temp file with the same sed pipeline init uses
  RENDERED="${SANDBOX_TMP}/CLAUDE.md"
  sed -e "s|{{REPO_ROOT}}|/tmp/fake/repo/root|g" \
      -e "s|{{GITHUB_OWNER}}|fake-owner|g" \
      -e "s|{{GITHUB_REPO}}|fake-repo|g" \
      -e "s|{{HUMAN_OWNER_NAME}}|Fake Owner|g" \
      -e "s|{{PROJECT_NAME}}|fake-project|g" \
      -e "s|{{HEARTBEAT_DIR}}|/var/log/dev-studio/fake-project|g" \
      "${TMPL_PATH}" > "${RENDERED}"

  # Now apply init's verify() regex exactly (line 517)
  STRAGGLERS="$(grep -oE '\{\{[A-Z_][A-Z0-9_]*\}\}' "${RENDERED}" 2>/dev/null || true)"

  if [ -z "${STRAGGLERS}" ]; then
    info "TC4 — init's sed pipeline + verify regex leaves 0 unresolved placeholders (AC3 final integration OK)"
    pass "TC4 — init's exact sed pipeline (lines 434-439) + verify() regex (line 517) → 0 unresolved placeholders remain"
  else
    fail "TC4 — init's sed pipeline left unresolved placeholders: ${STRAGGLERS}" \
      "expected init's sed to consume all {{UPPER_SNAKE}} markers. Stragglers indicate a placeholder name mismatch between the .tmpl and dev-studio-init.sh. AC3 violated. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC5: docs/decisions/ referenced ≥ 3 times (AC2 cross-ref density)
# ============================================================================
section "TC5: docs/decisions/ referenced ≥ 3 times (AC2 ADR cross-ref density)"
if [ ! -f "${TMPL_PATH}" ]; then
  fail "TC5 — cannot check cross-refs (CLAUDE.md.tmpl missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  # Count occurrences of docs/decisions/ literal in the .tmpl
  REF_COUNT="$(grep -c "docs/decisions/" "${TMPL_PATH}" 2>/dev/null || echo 0)"
  if [ "${REF_COUNT}" -ge 3 ]; then
    info "TC5 — docs/decisions/ referenced ${REF_COUNT} time(s) (AC2 base case satisfied: ≥3)"
    pass "TC5 — docs/decisions/ referenced ≥ 3 times (got: ${REF_COUNT}) — doctrinal cross-ref density OK"
  else
    fail "TC5 — docs/decisions/ referenced < 3 times (got: ${REF_COUNT})" \
      "expected ≥3 references per AC2 (dev claims 9+). Add ADR list section + inline references in Architecture/Files sections. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC6: .gitignore contains `CLAUDE.md` (template-grade contract: .tmpl is source)
# ============================================================================
section 'TC6: .gitignore contains bare CLAUDE.md (template-grade contract: rendered output is gitignored)'
GITIGNORE="${REPO_ROOT}/.gitignore"
if [ ! -f "${GITIGNORE}" ]; then
  fail "TC6 — .gitignore missing at repo root" \
    "expected .gitignore present (sister-pattern to .claude/CLAUDE.md gitignore contract). RED-first confirmed."
  EXIT_CODE=1
elif grep -qx "CLAUDE.md" "${GITIGNORE}"; then
  info "TC6 — .gitignore has bare 'CLAUDE.md' entry (rendered output excluded from VCS)"
  pass "TC6 — .gitignore excludes rendered CLAUDE.md (template-grade contract: edit .tmpl, never the rendered file)"
else
  fail "TC6 — .gitignore does not contain bare 'CLAUDE.md'" \
    "expected a bare 'CLAUDE.md' line in .gitignore (sister-pattern to README.md and .claude/CLAUDE.md exclusions — see the 'Faz 4 BÖL rendered outputs' section). Without this, rendered CLAUDE.md will be committed and dev-studio-init will refuse to re-render (would overwrite tracked file). RED-first confirmed."
  EXIT_CODE=1
fi

# ============================================================================
# TC7: Adversarial — no extra/unknown `{{...}}` placeholders (typo regression guard)
# ============================================================================
section "TC7: no extra/unknown {{...}} placeholders (typo regression guard — AC3 strictness)"
if [ ! -f "${TMPL_PATH}" ]; then
  fail "TC7 — cannot check for unknown placeholders (CLAUDE.md.tmpl missing)" \
    "TC1 prerequisite not met."
  EXIT_CODE=1
else
  # Extract all {{UPPER_SNAKE}} style placeholders; compare against the 6 expected.
  # Note: lowercase or mixed-case placeholders not handled by init's sed (init lines 434-439
  # use exact-case sed -e substitution), so we strictly check UPPER_SNAKE.
  FOUND_PLACEHOLDERS="$(grep -oE '\{\{[A-Z_][A-Z0-9_]*\}\}' "${TMPL_PATH}" 2>/dev/null | sort -u)"
  UNKNOWN=""
  for ph in ${FOUND_PLACEHOLDERS}; do
    # shellcheck disable=SC2076
    if ! printf '%s\n' "${EXPECTED_PLACEHOLDERS[@]}" | grep -qxF "${ph}"; then
      UNKNOWN="${UNKNOWN}${ph} "
    fi
  done
  if [ -z "${UNKNOWN}" ]; then
    info "TC7 — placeholders strictly limited to the 6 expected (no typos found)"
    pass "TC7 — no unknown placeholders (typo regression guard: AC3 strictness satisfied)"
  else
    fail "TC7 — unknown placeholder(s) found: ${UNKNOWN}" \
      "init script sed-replaces ONLY the 6 expected placeholders (lines 434-439). Any other {{UPPER_SNAKE}} marker would survive render and the verify() function would emit 'Unresolved placeholders found' warning → exit 2 (lines 519-528). Remove the typo(s) or add sed substitution to dev-studio-init.sh. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "${FAIL}" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — CLAUDE.md.tmpl missing or ACs unsatisfied per ADR-0044 RED-first${D}\n" "${FAIL}"
  exit 1
fi

printf "\n${G}GREEN state: all 7 TCs PASS — CLAUDE.md.tmpl present, doctrinally complete, init renders cleanly, .gitignore contract upheld${D}\n"
exit 0
