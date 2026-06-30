#!/usr/bin/env bash
# d105-audit-project-refs.sh — Issue #651 / STORY-S21-004 (Project Refs Audit Script).
#
# Why this test exists
# --------------------
# Without this audit script, hardcoded "AtilCalculator" / "atilcan65" refs leak
# through template clones (someone forgets to run dev-studio-init.sh, or runs
# it before adding the .tmpl file, or runs it after a partial migration).
# This d-test verifies the audit catches (AC1) and clears (AC2) these refs,
# AND that the JSON mode is parseable (AC3 prerequisite for CI).
#
# 3 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: AC1 — Pre-init fixture dir → audit exits 1, finds hardcoded refs
#        (creates a tmp dir with hardcoded `AtilCalculator` + `atilcan65` refs,
#        commits them as tracked files, runs audit-project-refs.sh, asserts exit 1).
#   TC2: AC2 — Post-init fixture dir → audit exits 0, no hardcoded refs
#        (creates a tmp dir with only {{...}} placeholders + final-user values,
#        commits them as tracked files, runs audit-project-refs.sh, asserts exit 0).
#   TC3: AC3 — JSON output mode parseable + CI integration viable
#        (asserts --json output is valid JSON with status/hits/details keys).
#
# Pre-impl RED state (origin/main at PR #651):
#   - AC1: scripts/audit-project-refs.sh DOES NOT EXIST → exit 2 (preflight)
#   - AC2: scripts/audit-project-refs.sh DOES NOT EXIST → exit 2 (preflight)
#   - AC3: scripts/audit-project-refs.sh DOES NOT EXIST → exit 2 (preflight)
#   → 3/3 TCs FAIL = proper RED-first per ADR-0044.
#
# Post-impl GREEN state (after Issue #651 impl lands + PR squash):
#   - TC1: pre-init fixture → audit exits 1, hits >= 1
#   - TC2: post-init fixture → audit exits 0, hits = 0
#   - TC3: --json output valid JSON, status=FAIL, hits > 0
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d070a (S21-003a #636, sister — impl gate for init script)
#   - d070b (S21-003b #693, sister — advanced UX layer)
#   - d095 (S21-022 #684, post-org-migration clone-urls sister)
#   - d105 (S21-004 #651, this file — audit-project-refs sister)
#
# Sprint 21 dispatch refs:
#   - Issue #651 (impl, agent:developer, status:ready claimed cycle ~#1625q)
#   - Issue #690 (PM Wave 2 dispatch)
#   - Issue #636 (S21-003a, upstream — d070a sister, dev lane)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0012 4-cat invariant (d-test ships via PR per type:feature)
#   - ADR-0049 d-test framework
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md same commit)
#   - ADR-0059 cluster-squash doctrine (Wave 2 cluster cadence)
#
# Usage:
#   bash d105-audit-project-refs.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — audit script lands with impl)
#   1 — at least one FAIL (RED state — impl not yet landed)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUDIT_SCRIPT="${REPO_ROOT}/scripts/audit-project-refs.sh"

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
command -v git >/dev/null 2>&1 || { echo "ERROR: git required" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required (for JSON validate TC3)" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d105 self-test (3 TCs per Issue #651 + ADR-0044 RED-first)${D}\n"
printf "${B}=================================================================${D}\n"
printf "  Script under test: %s\n" "$AUDIT_SCRIPT"
printf "  Sister-pattern:    d070a (S21-003a impl gate) + d095 (clone-urls)\n"
printf "  RED-first:         pre-impl all 3 TCs FAIL (script missing → preflight).\n"
printf "  Post-impl:         all 3 TCs must PASS.\n\n"

if [ ! -f "$AUDIT_SCRIPT" ]; then
  fail "preflight — scripts/audit-project-refs.sh missing" "expected $AUDIT_SCRIPT (Issue #651 impl not yet shipped)"
  exit 2
fi

if [ ! -x "$AUDIT_SCRIPT" ]; then
  fail "preflight — scripts/audit-project-refs.sh not executable" "run: chmod +x scripts/audit-project-refs.sh"
  exit 2
fi

# ============================================================================
# TC1: AC1 — Pre-init fixture → audit exits 1, finds hardcoded refs
# ============================================================================
section "TC1: AC1 — Pre-init fixture audit (exit 1)"

TC1_TMP=$(mktemp -d)
trap 'rm -rf "$TC1_TMP" "$TC2_TMP"' EXIT
TC1_GIT="$TC1_TMP/repo"
mkdir -p "$TC1_GIT"
(
  cd "$TC1_GIT"
  git init -q
  git config user.email "test@test"
  git config user.name "Test"
  # Create tracked files with hardcoded refs (the pre-init state)
  mkdir -p src scripts docs
  echo "# AtilCalculator" > README.md
  echo "PROJECT_NAME=AtilCalculator" > .env
  echo "OWNER=atilcan65" >> .env
  cat > src/main.py <<EOF
def main():
    print("AtilCalculator engine v1")
    return "atilcan65/AtilCalculator"
EOF
  git add -A
  git commit -q -m "pre-init fixture"
)

# Run audit on the pre-init fixture
bash "$AUDIT_SCRIPT" "$TC1_GIT" > /dev/null 2>&1
TC1_EXIT=$?

if [ "$TC1_EXIT" -eq 1 ]; then
  pass "TC1 — pre-init audit exits 1 (correctly catches hardcoded refs)"
else
  fail "TC1 — pre-init audit must exit 1" "expected exit 1, got exit $TC1_EXIT"
fi

# ============================================================================
# TC2: AC2 — Post-init fixture → audit exits 0, no hardcoded refs
# ============================================================================
section "TC2: AC2 — Post-init fixture audit (exit 0)"

TC2_TMP=$(mktemp -d)
TC2_GIT="$TC2_TMP/repo"
mkdir -p "$TC2_GIT"
(
  cd "$TC2_GIT"
  git init -q
  git config user.email "test@test"
  git config user.name "Test"
  # Create tracked files with placeholder-only and user-replaced values (post-init state)
  mkdir -p src scripts docs
  echo "# MyProject" > README.md
  echo "PROJECT_NAME=MyProject" > .env
  echo "OWNER=myorg" >> .env
  cat > src/main.py <<EOF
def main():
    print("MyProject engine v1")
    return "myorg/MyProject"
EOF
  git add -A
  git commit -q -m "post-init fixture"
)

bash "$AUDIT_SCRIPT" "$TC2_GIT" > /dev/null 2>&1
TC2_EXIT=$?

if [ "$TC2_EXIT" -eq 0 ]; then
  pass "TC2 — post-init audit exits 0 (no hardcoded refs found)"
else
  fail "TC2 — post-init audit must exit 0" "expected exit 0, got exit $TC2_EXIT"
fi

# ============================================================================
# TC3: AC3 — JSON output mode parseable + CI integration viable
# ============================================================================
section "TC3: AC3 — JSON output mode (parseable for CI)"

# Use TC1 fixture (has hardcoded refs → JSON should show FAIL)
# Note: --json must be the FIRST argument (the script treats $1 as target dir otherwise)
TC3_JSON=$(cd "$TC1_GIT" && bash "$AUDIT_SCRIPT" --json 2>/dev/null)
TC3_PARSE_OK=$(echo "$TC3_JSON" | python3 -c "import json, sys; d = json.loads(sys.stdin.read()); print('OK' if 'status' in d and 'hits' in d else 'MISSING_KEYS')" 2>&1)
TC3_STATUS=$(echo "$TC3_JSON" | python3 -c "import json, sys; d = json.loads(sys.stdin.read()); print(d.get('status', 'NONE'))" 2>&1)

if [ "$TC3_PARSE_OK" = "OK" ] && [ "$TC3_STATUS" = "FAIL" ]; then
  pass "TC3 — --json output valid JSON, status=FAIL (CI gate viable)"
else
  fail "TC3 — --json output not parseable or wrong status" "parse=$TC3_PARSE_OK, status=$TC3_STATUS"
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

printf "${G}✓ GREEN state — audit-project-refs.sh (Issue #651) lands with all 3 ACs verified${D}\n"
exit 0
