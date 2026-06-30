#!/usr/bin/env bash
# d096-soul-files-template.sh — STORY-S21-006 (Issue #638) "All 5 Soul Files in Template"
# RED-first regression guard for soul-file template coverage.
#
# Why this test exists
# --------------------
# Sprint 21 E3 (Agent Soul Files) S21-006 demands that all 5 soul files exist
# as `.tmpl` template sources under `.claude/agents/` so that `dev-studio-init.sh`
# can render them into `.md` for any fresh clone. Without `.tmpl` sources, the
# soul files contain hardcoded references (e.g., `@atilcan65`, `AtilCalculator`)
# that are wrong on every downstream clone — agents wake with stale doctrine.
#
# AC mapping (Issue #638):
#   AC1 — 5 `.tmpl` files exist under `.claude/agents/`
#         (orchestrator, product-manager, architect, developer, tester)
#   AC2 — All 5 reference `.claude/CLAUDE.md` as the project doctrine source
#   AC3 — All 5 use `{{HUMAN_OWNER_NAME}}`, `{{GITHUB_OWNER}}`, `{{GITHUB_REPO}}`
#         placeholders (no hardcoded owner/repo strings)
#
# 5 TCs (per ADR-0044 RED-first + ADR-0049 d-test framework sister-pattern):
#   TC1: 5 .tmpl files exist in .claude/agents/ (AC1 base case)
#   TC2: All 5 reference `.claude/CLAUDE.md` (AC2 doctrinal)
#   TC3: All 5 contain `{{HUMAN_OWNER_NAME}}` placeholder (AC3 base case)
#   TC4: All 5 contain `{{GITHUB_OWNER}}` AND `{{GITHUB_REPO}}` placeholders (AC3 base case)
#   TC5: Adversarial — init script's exact sed pipeline (lines 434-439) renders
#        all 5 cleanly (0 unresolved placeholders remain) + `.gitignore` excludes
#        rendered `.md` outputs (template-grade contract: edit .tmpl, never .md)
#
# Pre-impl RED state (current main as of 2026-06-30, pre-S21-006 impl):
#   - 0 `.tmpl` soul files exist in `.claude/agents/`
#   - TC1: 0/5 → FAIL
#   - TC2: N/A (no .tmpl files to check)
#   - TC3: 0/5 contain `{{HUMAN_OWNER_NAME}}` → FAIL
#   - TC4: 0/5 contain `{{GITHUB_OWNER}}/{{GITHUB_REPO}}` → FAIL
#   - TC5: init sed pipeline has nothing to render; .gitignore does not exclude `.claude/agents/*.md` → FAIL
#   → 5/5 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (target, after S21-006 PR merge):
#   - 5 `.tmpl` files exist (orchestrator, product-manager, architect, developer, tester)
#   - All reference `.claude/CLAUDE.md`
#   - All contain `{{HUMAN_OWNER_NAME}}`, `{{GITHUB_OWNER}}`, `{{GITHUB_REPO}}`
#   - Init script's exact sed pipeline renders all 5 cleanly
#   - `.gitignore` excludes rendered `.claude/agents/*.md` (Faz 3 contract)
#   → 5/5 TCs PASS in GREEN state.
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d075 (Issue #632 CLAUDE.md.tmpl content, 7 TCs) — direct sister-pattern
#   - d069 (workflow-file scope parameterization) — earlier sister
#   - d070 (dev-studio-init.sh template-rendering) — upstream impl tested
#   - d070b (init-prompt-ux) — Wave 2 sister
#   - d091 (work-stream awareness) — Wave 2 sister
#   - d093 (TEMPLATE-README polish) — Wave 1 sister
#   - d094 (self-hosted runner migration) — Sprint 22 PIVOT
#   - d095 (post-org-migration clone URLs) — Sprint 22 PIVOT
#   - **d096 (this file) — Sprint 21 E3 soul files template coverage**
#
# Refs:
#   - Issue #638 (STORY-S21-006) — AC1+AC2+AC3
#   - ADR-0012 §File ownership matrix (.claude/ = human-only territory, dev proposes via PR)
#   - ADR-0044 (RED-first TDD)
#   - ADR-0049 (d-test framework sister-pattern, ≥3 TCs minimum)
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#   - d075 sister-pattern (CLAUDE.md.tmpl content)
#
# Usage:
#   bash d096-soul-files-template.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — 5 .tmpl soul files present, doctrinally complete, init renders cleanly)
#   1 — at least one FAIL (RED state — impl missing or ACs unsatisfied)
#   2 — preflight failure (missing tool, init script, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
AGENTS_DIR="${REPO_ROOT}/.claude/agents"
INIT_SCRIPT="${INIT_SCRIPT:-${REPO_ROOT}/scripts/dev-studio-init.sh}"
GITIGNORE="${REPO_ROOT}/.gitignore"

# 5 soul files per AC1
SOUL_FILES=(
  "orchestrator.md.tmpl"
  "product-manager.md.tmpl"
  "architect.md.tmpl"
  "developer.md.tmpl"
  "tester.md.tmpl"
)

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
command -v sed >/dev/null 2>&1 || { echo "ERROR: sed required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d096 self-test (5 TCs per Issue #638 STORY-S21-006, ADR-0044 RED-first)${D}\n"
printf "${B}====================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Agents dir:       %s\n" "$AGENTS_DIR"
printf "  Init script:      %s\n" "$INIT_SCRIPT"
printf "  Soul files (5):   %s\n" "$(IFS=', '; echo "${SOUL_FILES[*]}")"
printf "  Sister-pattern:   d075 (CLAUDE.md.tmpl content, 7 TCs) + d070+d070b (init render)\n"
printf "  Pre-impl RED:     5/5 TCs FAIL by design per ADR-0044\n"
printf "  Sprint:           21 (Wave 2 E3 soul files)\n"
printf "  File ownership:   .claude/ = human-only territory (dev proposes via PR per ADR-0012)\n\n"

# Preflight
[ -d "${AGENTS_DIR}" ] || { echo "ERROR: ${AGENTS_DIR} missing" >&2; exit 2; }
[ -d "${REPO_ROOT}" ] || { echo "ERROR: REPO_ROOT invalid: ${REPO_ROOT}" >&2; exit 2; }

EXIT_CODE=0

# ============================================================================
# TC1: 5 .tmpl files exist in .claude/agents/ (AC1 base case)
# ============================================================================
section "TC1: AC1 — 5 soul files exist as .tmpl in .claude/agents/"
TC1_MISSING=()
for sf in "${SOUL_FILES[@]}"; do
  if [ ! -f "${AGENTS_DIR}/${sf}" ]; then
    TC1_MISSING+=("${sf}")
  fi
done

if [ "${#TC1_MISSING[@]}" -eq 0 ]; then
  pass "TC1 — all 5 soul .tmpl files exist in .claude/agents/ (orch/pm/arch/dev/tester)"
else
  MISSING_LIST=$(IFS=', '; echo "${TC1_MISSING[*]}")
  fail "TC1 — ${#TC1_MISSING[@]}/5 soul .tmpl files missing: ${MISSING_LIST}" \
    "expected all 5 .tmpl files per AC1. Without .tmpl sources, fresh clones cannot render soul files with project-specific values. RED-first confirmed."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: All 5 reference .claude/CLAUDE.md (AC2 doctrinal)
# ============================================================================
section "TC2: AC2 — all 5 soul .tmpl files reference .claude/CLAUDE.md"
TC2_MISSING=()
if [ "${#TC1_MISSING[@]}" -eq "${#SOUL_FILES[@]}" ]; then
  fail "TC2 — cannot check (no .tmpl files exist per TC1)" \
    "TC1 prerequisite not met. All 5 .tmpl files must exist before AC2 reference check is meaningful."
  EXIT_CODE=1
else
  for sf in "${SOUL_FILES[@]}"; do
    f="${AGENTS_DIR}/${sf}"
    [ -f "$f" ] || continue
    # Soul files should reference CLAUDE.md either explicitly (.claude/CLAUDE.md)
    # or implicitly via the rendered output location
    if ! grep -qF ".claude/CLAUDE.md" "$f"; then
      TC2_MISSING+=("${sf}")
    fi
  done

  if [ "${#TC2_MISSING[@]}" -eq 0 ]; then
    pass "TC2 — all ${#SOUL_FILES[@]} soul .tmpl files reference .claude/CLAUDE.md (AC2 doctrinal cross-link)"
  else
    MISSING_LIST=$(IFS=', '; echo "${TC2_MISSING[*]}")
    fail "TC2 — ${#TC2_MISSING[@]}/5 soul .tmpl files missing .claude/CLAUDE.md reference: ${MISSING_LIST}" \
      "expected all 5 soul files to cite .claude/CLAUDE.md as project doctrine source per AC2. Missing references indicate agents won't know to read the doctrine file. RED-first confirmed."
    EXIT_CODE=1
  fi
fi

# ============================================================================
# TC3: All 5 contain {{HUMAN_OWNER_NAME}} placeholder (AC3 base case)
# ============================================================================
section "TC3: AC3a — all 5 soul .tmpl files contain {{HUMAN_OWNER_NAME}}"
TC3_MISSING=()
for sf in "${SOUL_FILES[@]}"; do
  f="${AGENTS_DIR}/${sf}"
  [ -f "$f" ] || continue
  if ! grep -qF "{{HUMAN_OWNER_NAME}}" "$f"; then
    TC3_MISSING+=("${sf}")
  fi
done

if [ "${#TC3_MISSING[@]}" -eq 0 ] && [ "${#TC1_MISSING[@]}" -eq 0 ]; then
  pass "TC3 — all ${#SOUL_FILES[@]} soul .tmpl files contain {{HUMAN_OWNER_NAME}} placeholder (AC3 base case)"
elif [ "${#TC1_MISSING[@]}" -gt 0 ]; then
  fail "TC3 — cannot fully check (${#TC1_MISSING[@]} .tmpl files missing per TC1)" \
    "TC1 prerequisite not met. Cannot verify placeholder presence without .tmpl files."
  EXIT_CODE=1
else
  MISSING_LIST=$(IFS=', '; echo "${TC3_MISSING[*]}")
  fail "TC3 — ${#TC3_MISSING[@]}/5 soul .tmpl files missing {{HUMAN_OWNER_NAME}}: ${MISSING_LIST}" \
    "expected all 5 .tmpl files to use {{HUMAN_OWNER_NAME}} per AC3 for owner mention (no hardcoded @atilcan65). RED-first confirmed."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: All 5 contain {{GITHUB_OWNER}} AND {{GITHUB_REPO}} placeholders (AC3 base case)
# ============================================================================
section "TC4: AC3b — all 5 soul .tmpl files contain {{GITHUB_OWNER}} AND {{GITHUB_REPO}}"
TC4_MISSING_OWNER=()
TC4_MISSING_REPO=()
for sf in "${SOUL_FILES[@]}"; do
  f="${AGENTS_DIR}/${sf}"
  [ -f "$f" ] || continue
  if ! grep -qF "{{GITHUB_OWNER}}" "$f"; then
    TC4_MISSING_OWNER+=("${sf}")
  fi
  if ! grep -qF "{{GITHUB_REPO}}" "$f"; then
    TC4_MISSING_REPO+=("${sf}")
  fi
done

TC4_TOTAL_MISSING=$(( ${#TC4_MISSING_OWNER[@]} + ${#TC4_MISSING_REPO[@]} ))
if [ "${TC4_TOTAL_MISSING}" -eq 0 ] && [ "${#TC1_MISSING[@]}" -eq 0 ]; then
  pass "TC4 — all ${#SOUL_FILES[@]} soul .tmpl files contain {{GITHUB_OWNER}} AND {{GITHUB_REPO}} placeholders (AC3 base case)"
elif [ "${#TC1_MISSING[@]}" -gt 0 ]; then
  fail "TC4 — cannot fully check (${#TC1_MISSING[@]} .tmpl files missing per TC1)" \
    "TC1 prerequisite not met. Cannot verify placeholder presence without .tmpl files."
  EXIT_CODE=1
else
  OWNER_LIST=$(IFS=', '; echo "${TC4_MISSING_OWNER[*]:-}")
  REPO_LIST=$(IFS=', '; echo "${TC4_MISSING_REPO[*]:-}")
  fail "TC4 — ${TC4_TOTAL_MISSING} placeholder(s) missing across .tmpl files" \
    "missing {{GITHUB_OWNER}}: [${OWNER_LIST}]; missing {{GITHUB_REPO}}: [${REPO_LIST}]. Per AC3, all 5 soul files must use these placeholders for repo refs (no hardcoded atilcan65/AtilCalculator). RED-first confirmed."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: Adversarial — init script's exact sed pipeline renders all 5 cleanly +
#      .gitignore excludes rendered .md outputs (template-grade contract)
# ============================================================================
section 'TC5: AC3 final + contract — init sed pipeline renders 5 .tmpl cleanly + .gitignore excludes rendered .md'
SANDBOX_TMP="$(mktemp -d)"
trap 'rm -rf "${SANDBOX_TMP}"' EXIT

# Init script's exact sed pipeline (per d075 TC4 sister-pattern, lines 434-439)
RENDER_FAIL=0
RENDERED_COUNT=0
for sf in "${SOUL_FILES[@]}"; do
  f="${AGENTS_DIR}/${sf}"
  [ -f "$f" ] || continue
  RENDERED_COUNT=$((RENDERED_COUNT + 1))
  OUT="${SANDBOX_TMP}/${sf%.tmpl}"
  sed -e "s|{{REPO_ROOT}}|/tmp/fake/repo/root|g" \
      -e "s|{{GITHUB_OWNER}}|fake-owner|g" \
      -e "s|{{GITHUB_REPO}}|fake-repo|g" \
      -e "s|{{HUMAN_OWNER_NAME}}|Fake Owner|g" \
      -e "s|{{PROJECT_NAME}}|fake-project|g" \
      -e "s|{{HEARTBEAT_DIR}}|/var/log/dev-studio/fake-project|g" \
      "$f" > "$OUT"

  # Init's verify() regex (sister-pattern d075 TC4 line 245)
  STRAGGLERS="$(grep -oE '\{\{[A-Z_][A-Z0-9_]*\}\}' "$OUT" 2>/dev/null || true)"
  if [ -n "${STRAGGLERS}" ]; then
    RENDER_FAIL=1
    fail "TC5 — ${sf} left unresolved placeholders after init sed: ${STRAGGLERS}" \
      "expected init's sed to consume all {{UPPER_SNAKE}} markers. Stragglers indicate placeholder name mismatch between the .tmpl and dev-studio-init.sh. AC3 final integration violated."
  fi
done

if [ "${RENDERED_COUNT}" -eq 0 ]; then
  fail "TC5 — no .tmpl files to render (TC1 prerequisite not met)" \
    "expected 5 .tmpl files. Without them, init has nothing to render. RED-first confirmed."
  EXIT_CODE=1
elif [ "${RENDER_FAIL}" -eq 0 ]; then
  # .gitignore contract: rendered .md outputs should be excluded (sister-pattern d075 TC6)
  if [ -f "${GITIGNORE}" ] && grep -qE "^\.claude/agents/\*\.md$|^\.claude/agents/[^/]+\.md$" "${GITIGNORE}"; then
    info "TC5 — init's exact sed pipeline renders all ${RENDERED_COUNT} .tmpl cleanly (0 unresolved) + .gitignore excludes rendered .md"
    pass "TC5 — init's sed pipeline (lines 434-439) renders 5 .tmpl cleanly + .gitignore Faz 3 contract upheld"
  else
    fail "TC5 — .gitignore does not exclude rendered .claude/agents/*.md" \
      "expected a '.claude/agents/*.md' (or equivalent pattern) entry in .gitignore per template-grade Faz 3 contract. Without this, rendered .md files will be tracked instead of regenerated. Sister-pattern to d075 TC6 (.gitignore excludes rendered CLAUDE.md). RED-first confirmed."
    EXIT_CODE=1
  fi
else
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Soul .tmpl files expected:  5 (orch/pm/arch/dev/tester)\n"
printf "  Soul .tmpl files present:   %d\n" "$RENDERED_COUNT"
printf "  Sister-pattern:             d075 (CLAUDE.md.tmpl content, 7 TCs)\n"
printf "  AC1 base case (TC1):        5 .tmpl files exist\n"
printf "  AC2 doctrinal (TC2):        .claude/CLAUDE.md referenced\n"
printf "  AC3 base case (TC3+TC4):    3 placeholders per file\n"
printf "  AC3 final + contract (TC5): init render + .gitignore\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — S21-006 soul-files-template impl not yet landed${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 5 TCs PASS — S21-006 soul-files-template impl complete${D}\n"
exit 0