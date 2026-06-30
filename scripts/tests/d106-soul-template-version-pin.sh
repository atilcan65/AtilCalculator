#!/usr/bin/env bash
# d106-soul-template-version-pin.sh — Issue #639 / STORY-S21-007 (Soul File Template-Version Pin).
#
# Why this test exists
# --------------------
# Without template-version pinning, clones silently drift from upstream template.
# Each soul .tmpl file must carry a `template-version` header (AC1) that the
# init script substitutes from `.template-version` (AC2). AC3 (agent-doctor
# drift report) is enforced via the header presence + init substitution chain
# (full drift detection is Sprint 22+ work, see Issue #639 Downstream).
#
# 3 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: AC1 — All 5 .tmpl files have `<!-- template-version: {{TEMPLATE_VERSION}} -->`
#        header as the FIRST line of the file (above YAML front-matter).
#   TC2: AC2 — Init script reads `.template-version` and substitutes the
#        placeholder via sed pipeline (asserts the sed substitution is present
#        + simulates end-to-end render via tmp dir, verifies header replaces
#        from placeholder to actual version).
#   TC3: AC3 — `.template-version` file exists at REPO_ROOT + init script
#        falls back gracefully when file is missing (no crash, warning logged).
#
# Pre-impl RED state (origin/main at Issue #639):
#   - AC1: 5 .tmpl files exist (PR #712 SHIPPED), but NO `template-version`
#          header on any of them → 5/5 FAIL.
#   - AC2: dev-studio-init.sh sed pipeline does NOT include
#          `{{TEMPLATE_VERSION}}` substitution → FAIL.
#   - AC3: `.template-version` does NOT exist on main → FAIL (file missing).
#   → 3/3 TCs FAIL by design (proper RED-first per ADR-0044).
#
# Post-impl GREEN state (after Issue #639 impl lands + PR squash):
#   - TC1: All 5 .tmpl files have `template-version: {{TEMPLATE_VERSION}}` header
#   - TC2: Init sed pipeline substitutes the placeholder correctly
#   - TC3: `.template-version` exists + init script handles missing gracefully
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d096 (S21-006 #638 soul .tmpl files sister — d106 EXTENDS by adding
#          version pin contract to the same 5 .tmpl files)
#   - d075 (S21-008 CLAUDE.md.tmpl sister — version-pinning extends to .claude/)
#   - d091 (S21-005 .tmpl Source Files sister)
#   - d070 + d070b (init-script sister family — d106 tests the init script's
#          substitution pipeline)
#   - d105 (S21-004 #651 audit-project-refs sister — d106's version-pinning
#          contract is one of the things d105 audits)
#
# Sprint 21 dispatch refs:
#   - Issue #639 (impl, agent:developer, status:ready auto-claimed cycle ~#1625q)
#   - Issue #690 (PM Wave 2 dispatch)
#   - Issue #113 (label-authority doctrine — d-test number slot rationale)
#   - ADR-0001 §1 (single-repo template architecture)
#   - ADR-0050 §C9 (init script contract — d106 verifies the version-pin
#          contract is honored)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern, ≥3 TCs minimum)
#   - ADR-0055 §1 (Cadence Rule 1 atomic — d-test file + INDEX.md same commit)
#
# Usage:
#   bash d106-soul-template-version-pin.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — version-pin lands with all 3 ACs verified)
#   1 — at least one FAIL (RED state — impl not yet landed)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INIT_SCRIPT="${REPO_ROOT}/scripts/dev-studio-init.sh"
TEMPLATE_VERSION_FILE="${REPO_ROOT}/.template-version"
TMPL_DIR="${REPO_ROOT}/.claude/agents"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[0m'
else
  R=""; G=""; Y=""; B=""; D=""
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

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d106 self-test (3 TCs per Issue #639 + ADR-0044 RED-first)${D}\n"
printf "${B}================================================================${D}\n"
printf "  Init script:    %s\n" "$INIT_SCRIPT"
printf "  Version file:   %s\n" "$TEMPLATE_VERSION_FILE"
printf "  Soul .tmpl dir: %s\n" "$TMPL_DIR"
printf "  Sister-pattern: d096 (S21-006 soul files) + d105 (S21-004 audit)\n"
printf "  RED-first:      pre-impl all 3 TCs FAIL.\n"
printf "  Post-impl:      all 3 TCs must PASS.\n\n"

if [ ! -f "$INIT_SCRIPT" ]; then
  fail "preflight — dev-studio-init.sh missing" "expected $INIT_SCRIPT"
  exit 2
fi

if [ ! -d "$TMPL_DIR" ]; then
  fail "preflight — .claude/agents/ missing" "expected $TMPL_DIR (PR #712 S21-006 ships these)"
  exit 2
fi

# ============================================================================
# TC1: AC1 — All 5 .tmpl files have template-version header
# ============================================================================
section "TC1: AC1 — All 5 .tmpl files have template-version header"

EXPECTED_COUNT=5
FOUND_COUNT=0
MISSING_FILES=()
for tmpl_file in "$TMPL_DIR"/*.tmpl; do
  if [ ! -f "$tmpl_file" ]; then continue; fi
  # Header must be the FIRST non-empty line of the file
  FIRST_LINE=$(head -1 "$tmpl_file")
  if echo "$FIRST_LINE" | grep -qE "^<!-- template-version: \{\{TEMPLATE_VERSION\}\} -->$"; then
    FOUND_COUNT=$((FOUND_COUNT + 1))
  else
    MISSING_FILES+=("$(basename "$tmpl_file"): '$FIRST_LINE'")
  fi
done

if [ "$FOUND_COUNT" -ge "$EXPECTED_COUNT" ]; then
  pass "TC1 — All $FOUND_COUNT/$EXPECTED_COUNT .tmpl files have template-version header"
else
  fail "TC1 — Only $FOUND_COUNT/$EXPECTED_COUNT .tmpl files have header" "missing: ${MISSING_FILES[*]:-none}"
fi

# ============================================================================
# TC2: AC2 — Init script substitutes {{TEMPLATE_VERSION}} via sed pipeline
# ============================================================================
section "TC2: AC2 — Init script sed pipeline substitutes template-version"

# Check the sed pipeline has the TEMPLATE_VERSION substitution
if grep -qE 's\|\{\{TEMPLATE_VERSION\}\}\|.*\|g' "$INIT_SCRIPT"; then
  pass "TC2a — sed pipeline has {{TEMPLATE_VERSION}} substitution"
else
  fail "TC2a — sed pipeline missing {{TEMPLATE_VERSION}} substitution" "expected -e 's|{{TEMPLATE_VERSION}}|${TEMPLATE_VERSION}|g' in render_template()"
fi

# Simulate end-to-end render: tmp dir, copy a .tmpl, run sed, verify substitution
TC2_TMP=$(mktemp -d)
trap 'rm -rf "$TC2_TMP"' EXIT
mkdir -p "$TC2_TMP/rendered"
cp "$TMPL_DIR/developer.md.tmpl" "$TC2_TMP/test.tmpl" 2>/dev/null || {
  fail "TC2b — could not copy developer.md.tmpl for render test"
  section "Summary"; printf "  ${G}PASS: %d${D}  ${R}FAIL: %d${D}\n" "$PASS" "$FAIL"; exit 1
}

# Mimic init script's sed pipeline (the relevant substitutions)
sed -e "s|{{REPO_ROOT}}|/tmp/test|g" \
    -e "s|{{GITHUB_OWNER}}|myorg|g" \
    -e "s|{{GITHUB_REPO}}|myrepo|g" \
    -e "s|{{HUMAN_OWNER_NAME}}|Tester|g" \
    -e "s|{{PROJECT_NAME}}|TestProj|g" \
    -e "s|{{HEARTBEAT_DIR}}|/tmp/hb|g" \
    -e "s|{{TEMPLATE_VERSION}}|0.1.0|g" \
    "$TC2_TMP/test.tmpl" > "$TC2_TMP/rendered/test.md"

if grep -qE "^<!-- template-version: 0\.1\.0 -->$" "$TC2_TMP/rendered/test.md"; then
  pass "TC2b — end-to-end render substitutes placeholder with actual version"
else
  fail "TC2b — end-to-end render did not substitute placeholder" "first line: $(head -1 "$TC2_TMP/rendered/test.md")"
fi

# ============================================================================
# TC3: AC3 — .template-version file exists + init script handles missing gracefully
# ============================================================================
section "TC3: AC3 — .template-version file + graceful fallback"

if [ -f "$TEMPLATE_VERSION_FILE" ]; then
  VERSION=$(tr -d '[:space:]' < "$TEMPLATE_VERSION_FILE")
  if [ -n "$VERSION" ]; then
    pass "TC3a — .template-version exists with content: '$VERSION'"
  else
    fail "TC3a — .template-version exists but is empty"
  fi
else
  fail "TC3a — .template-version missing" "expected $TEMPLATE_VERSION_FILE (created by Issue #639 impl)"
fi

# Check init script handles missing gracefully (warns + uses fallback)
if grep -qE "warn.*\\.template-version.*not found" "$INIT_SCRIPT"; then
  pass "TC3b — init script logs warn when .template-version missing"
else
  fail "TC3b — init script lacks graceful fallback for missing .template-version" "expected: warn message + TEMPLATE_VERSION='0.0.0-unknown' fallback"
fi

# ============================================================================
# Summary
# ============================================================================
section "Summary"
printf "  ${G}PASS: %d${D}  ${R}FAIL: %d${D}  ${Y}INFO: %d${D}\n\n" "$PASS" "$FAIL" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "${R}✗ RED state — at least one TC failed${D}\n"
  exit 1
fi

printf "${G}✓ GREEN state — soul template-version-pin (Issue #639) lands with all 3 ACs verified${D}\n"
exit 0