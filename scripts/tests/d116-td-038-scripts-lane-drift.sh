#!/usr/bin/env bash
# d116-td-038-scripts-lane-drift.sh — Issue #750 TD-038 scripts/ + scripts/tests/ lane drift regression guard.
#
# Why this test exists
# --------------------
# TD-038 (architect doc PR #750, Refs #749 + #739) is a post-PR-#749 drift audit
# finding: PR #749 closed the URL hygiene work for `docs/decisions/` only; 314
# stale `atilcan65/AtilCalculator` refs remain across `scripts/`, `.claude/`,
# `docs/`, `tests/`. The scripts/ lane subset (this d116's scope) has 7 affected
# files per @architect's TD-038 audit at cycle ~#2590+ (CMT 2026-07-01T19:40:25Z).
#
# Scope split (per arch drift-audit + dev lane MIGRATE/PRESERVE discipline, sister-pattern
# to Sprint 22 PIVOT Faz 2.4 d095 — same Issue #708 §PREP comment 4841268188 catalog):
#
#   - Category A (MIGRATE, 1 tracked file — ACTIVE stale refs to fix):
#     1. scripts/proactive-board-scan.sh
#        → 1 comment example citing atilcan65/AtilCalculator as REPO value
#
#   Out-of-scope (intentionally NOT in Category A — per ADR-0011 drop-in doctrine):
#     - scripts/install/systemd/dev-studio-watcher@.service
#       → 2 Documentation= URL refs (ADR-0010 + ADR-0011) — gitignored per
#         .gitignore L79; file is TEMPLATE-RENDERED at install time by
#         scripts/install/dev-studio-install-systemd.sh, NOT committed.
#         Verified locally: pre-fix has 2 stale refs; out-of-repo so the d-test
#         cannot enforce. Drift fix is a per-instance drop-in concern (systemd
#         installer responsibility), not a d-test contract.
#
#   - Category B (PRESERVE, 5 files — intentional `atilcan65` mentions, MUST NOT TOUCH):
#     1. scripts/tests/d095-post-org-migration-clone-urls.sh
#        → regression guard TC descriptions (the test itself defines OLD_ORG=atilcan65
#          and explicitly enumerates Category A files that should NOT contain the ref)
#     2. scripts/tests/INDEX.md
#        → historical descriptive rows (d095 + d105 + d114 etc.) cite atilcan65 by name;
#          Cadence Rule 1 (ADR-0055 §1) requires INDEX.md to be a historical record
#     3. scripts/tests/d096-soul-files-template.sh
#        → TC descriptions explaining what the d-test guards against ("must use
#          {{HUMAN_OWNER_NAME}} not hardcoded @atilcan65" — INTENTIONAL regression prose)
#     4. scripts/tests/d105-audit-project-refs.sh
#        → mock fixture return value `return "atilcan65/AtilCalculator"` simulating
#          the pre-init state that the audit script is supposed to CATCH (intentional
#          regression target for scripts/audit-project-refs.sh)
#     5. scripts/tests/proactive-sweep-test.sh
#        → 2 mock fixtures (GITHUB_REPO=atilcan65/AtilCalculator + REPO=atilcan65/AtilCalculator)
#          simulating pre-migration state for the sweep test (intentional regression targets)
#
# 5 TCs (per ADR-0049 d-test framework sister-pattern, ≥5/5 baseline):
#   TC1: REGRESSION — Category A (2) files have NO `atilcan65/AtilCalculator` URL refs
#        post-fix (negative pattern, red→green — pre-fix FAILS by design).
#   TC2: POSITIVE — Category A (2) files reference `atilproject/AtilCalculator`
#        post-fix (positive pattern, red→green — pre-fix FAILS by design).
#   TC3: PRESERVE-INVARIANT — all 5 Category B files retain >=1 `atilcan65` mention
#        each post-fix (TC3 passes pre- and post-fix by design — intentional refs
#        MUST NOT be touched; the drift fix must not over-reach into the regression
#        guard's own descriptive prose).
#   TC4: BARE-MENTION SWEEP — bare `\batilcan65\b` (no URL suffix, broader sweep)
#        in Category A = 0 post-fix. Covers URL refs + env-var mocks + owner-mention
#        refs that TC1's URL-specific regex would miss.
#   TC5: NET-RECONCILIATION — Category A URL refs = 0 post-fix AND Category B
#        total `atilcan65/AtilCalculator` mentions preserved at intentional baseline
#        (= sum of all 5 Category B file counts, never 0).
#
# Pre-impl RED state (current main HEAD 727a2c7, 2026-07-01, pre-fix):
#   - TC1: 1/1 Category A file has `atilcan65/AtilCalculator` URL refs → FAIL
#          (proactive-board-scan.sh=1)
#   - TC2: 1/1 Category A file lacks `atilproject/AtilCalculator` positive ref → FAIL
#   - TC3: 5/5 Category B files have >=1 `atilcan65` mentions each → PASS (always-green)
#   - TC4: bare `atilcan65` mentions in Category A = 1 (URL refs in 1 file) → FAIL
#   - TC5: Category A URL refs = 1 (non-zero, expected 0); Category B baseline intact → FAIL
#   → 4/5 TCs FAIL = proper RED-first per ADR-0044. TC3 PASSES pre- and post-fix
#     by design (PRESERVE-INVARIANT — regression guard's own descriptive prose
#     + test mock fixtures MUST NOT change).
#
# Post-impl GREEN state (after TD-038 scripts/ lane fix PR lands):
#   - TC1: 0/1 Category A file has `atilcan65/AtilCalculator` URL refs ✅
#   - TC2: 1/1 Category A file references `atilproject/AtilCalculator` ✅
#   - TC3: 5/5 Category B files still have >=1 `atilcan65` mentions each (PRESERVE held) ✅
#   - TC4: bare `atilcan65` mentions in Category A = 0 ✅
#   - TC5: Category A URL refs = 0 ✅ + Category B baseline preserved at 21 mentions
#   → 5/5 TCs PASS = GREEN state.
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d095 (Sprint 22 PIVOT Faz 2.4 #684 — post-org-migration clone-URL regression
#           guard. d116 EXTENDS d095 scope from 9-file Sprint-22-PIVOT catalog to
#           TD-038 7-file audit. d116's MIGRATE/PRESERVE Category split is the same
#           discipline Issue #708 §PREP comment 4841268188 codified for d095 —
#           d116's Category B intentionally cites d095 as the canonical regression
#           prose PRESERVE anchor + audit-script mock fixtures as INTENTIONAL
#           regression targets).
#   - d105 (S21-004 #651 — audit-project-refs sister. d105's mock fixture
#           `return "atilcan65/AtilCalculator"` is the canonical example of
#           "intentional regression target" — d116 TC3 verifies d105's fixture
#           is PRESERVED post-fix, not nuked by over-zealous drift script).
#   - d114 (Issue #739 URL hygiene — sister-lane coverage. d114 covers
#           `docs/decisions/`, d116 covers the scripts/ lane sibling. Cluster-squash
#           per ADR-0059).
#   - d069 (workflow-file scope parameterization WORKFLOW_FILES array archetype,
#           d-test pattern shape — same --self-test + bash + grep + awk contract)
#           + d070 + d070b + d091 + d093 (sister-pattern lineage from Sprint 21+).
#
# Sprint 23 + TD-038 refs:
#   - Issue #750 (architect TD-038 doc PR — Refs #749, this d-test is the
#                 sister d-test for the scripts/ lane audit follow-up)
#   - Issue #739 (root URL hygiene issue — PR #749 closed docs/decisions/
#                 only; drift audit surfaced scripts/ + .claude/ + tests/
#                 remaining refs)
#   - Issue #708 (Sprint 22 PIVOT — atilcan65 → atilproject org migration;
#                 d116 mirrors the Issue #708 §PREP comment 4841268188
#                 MIGRATE/PRESERVE discipline into TD-038 scripts/ lane)
#   - ADR-0044 (RED-first TDD doctrinal home)
#   - ADR-0049 (d-test framework sister-pattern, ≥5 TCs baseline)
#   - ADR-0055 §1 Cadence Rule 1 atomic (d-test file + INDEX.md entry same commit)
#   - ADR-0059 (cluster-squash doctrine — TD-038 cluster pairs with Issue #750)
#   - Issue #113 (label-authority — d-test number slot rationale: d113-d115
#                 belong to PR #747/#748/#750's pending chains; d116 = next
#                 free slot post-squash)
#
# Usage:
#   bash d116-td-038-scripts-lane-drift.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — TD-038 scripts/ lane drift fix landed)
#   1 — at least one FAIL (RED state — drift fix incomplete)
#   2 — preflight failure (missing tool, file missing, etc.)

set -uo pipefail
set +u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
TESTS_DIR="${REPO_ROOT}/scripts/tests"

# Category A: TD-038 scripts/ lane MIGRATE scope (1 tracked file, d116 owns refactor)
# Note: scripts/install/systemd/dev-studio-watcher@.service is gitignored (template-
# rendered per ADR-0011), so it cannot be in Category A. Its drift is fixed per-
# instance by scripts/install/dev-studio-install-systemd.sh at install time.
CATEGORY_A_FILES=(
  "${SCRIPTS_DIR}/proactive-board-scan.sh"
)

# Category B: TD-038 scripts/ lane PRESERVE scope (5 files, MUST NOT touch)
CATEGORY_B_FILES=(
  "${TESTS_DIR}/d095-post-org-migration-clone-urls.sh"
  "${TESTS_DIR}/INDEX.md"
  "${TESTS_DIR}/d096-soul-files-template.sh"
  "${TESTS_DIR}/d105-audit-project-refs.sh"
  "${TESTS_DIR}/proactive-sweep-test.sh"
)

OLD_ORG="atilcan65"
NEW_ORG="atilproject"
REPO_NAME="AtilCalculator"
STALE_REF="${OLD_ORG}/${REPO_NAME}"
EXPECTED_REF="${NEW_ORG}/${REPO_NAME}"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1;34m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0; INFO=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
info() { printf "  ${Y}ℹ INFO${D} — %s\n" "$1"; INFO=$((INFO+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Pre-flight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d116 self-test (5 TCs per TD-038 Issue #750 + ADR-0044 RED-first)${D}\n"
printf "${B}=============================================================================${D}\n"
printf "  Repo root:                %s\n" "$REPO_ROOT"
printf "  Category A (MIGRATE):     %d files (stale refs fixable by grep/sed)\n" "${#CATEGORY_A_FILES[@]}"
printf "  Category B (PRESERVE):    %d files (intentional mentions — DO NOT TOUCH)\n" "${#CATEGORY_B_FILES[@]}"
printf "  Old org (regression):     %s\n" "$OLD_ORG"
printf "  New org (expected):       %s\n" "$NEW_ORG"
printf "  Sister-pattern:           d095 (clone-urls) + d105 (audit-project-refs) + d114 (URL hygiene)\n"
printf "  RED-first state:          4/5 FAIL (TC3 PASS by design — preserve invariant)\n"
printf "  Post-impl expected:       5/5 PASS.\n"
printf "  File ownership:           scripts/ = dev+tester lane (agents propose via PR)\n\n"

# Preflight: every Category A and Category B file must exist
PREFLIGHT_FAIL=0
for f in "${CATEGORY_A_FILES[@]}" "${CATEGORY_B_FILES[@]}"; do
  if [ ! -f "$f" ]; then
    fail "preflight — file missing: $f"
    PREFLIGHT_FAIL=1
  fi
done
if [ "$PREFLIGHT_FAIL" -ne 0 ]; then
  exit 2
fi

EXIT_CODE=0

# ============================================================================
# TC1: REGRESSION — Category A files have NO `atilcan65/AtilCalculator` URL refs
# ============================================================================
section "TC1: AC1 — Category A files have no atilcan65/AtilCalculator refs (regression)"
TC1_REGRESSION_FILES=()
TC1_TOTAL_FILES=${#CATEGORY_A_FILES[@]}
for catA in "${CATEGORY_A_FILES[@]}"; do
  if grep -qF "${STALE_REF}" "$catA"; then
    TC1_REGRESSION_FILES+=("$(basename "$catA")")
  fi
done

if [ "${#TC1_REGRESSION_FILES[@]}" -eq 0 ]; then
  pass "TC1 — all ${TC1_TOTAL_FILES} Category A files have no ${STALE_REF} refs (post-fix GREEN)"
else
  FILE_LIST=$(IFS=', '; echo "${TC1_REGRESSION_FILES[*]}")
  fail "TC1 — ${#TC1_REGRESSION_FILES[@]}/${TC1_TOTAL_FILES} Category A files still reference ${STALE_REF}: ${FILE_LIST}" \
    "expected all Category A files migrated to ${EXPECTED_REF} per TD-038 scripts/ lane drift audit (architect Issue #750 at cycle ~#2590+). Fix scope = 1 tracked file (proactive-board-scan.sh). The systemd unit file is gitignored (ADR-0011 drop-in, template-rendered at install time) and is NOT a d-test contract — its drift fix lives in scripts/install/dev-studio-install-systemd.sh. Category B 5 files are PRESERVE-INVARIANT (intentional regression prose + mock fixtures)."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: POSITIVE — Category A files reference `atilproject/AtilCalculator`
# ============================================================================
section "TC2: AC2 — Category A files reference atilproject/AtilCalculator (positive)"
TC2_MISSING_FILES=()
for catA in "${CATEGORY_A_FILES[@]}"; do
  if ! grep -qF "${EXPECTED_REF}" "$catA"; then
    TC2_MISSING_FILES+=("$(basename "$catA")")
  fi
done

if [ "${#TC2_MISSING_FILES[@]}" -eq 0 ]; then
  pass "TC2 — all ${TC1_TOTAL_FILES} Category A files reference ${EXPECTED_REF} (positive verified)"
else
  FILE_LIST=$(IFS=', '; echo "${TC2_MISSING_FILES[*]}")
  fail "TC2 — ${#TC2_MISSING_FILES[@]} Category A files missing ${EXPECTED_REF} ref: ${FILE_LIST}" \
    "expected every Category A file to have at least one ${EXPECTED_REF} reference post-fix. Each stale-ref replaced with ${EXPECTED_REF} (1 tracked file, 1 occurrence: proactive-board-scan.sh=1 comment example). The systemd unit is gitignored (ADR-0011 drop-in) and not part of d-test contract."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: PRESERVE-INVARIANT — Category B files retain >=1 atilcan65 mention each
# ============================================================================
section "TC3: AC3 — Category B (5 files) intentional atilcan65 mentions preserved (always-green)"
TC3_PRESERVE_OK=1
TC3_DETAILS=()
for catB in "${CATEGORY_B_FILES[@]}"; do
  COUNT=$(grep -cE '\batilcan65\b' "$catB" 2>/dev/null || echo 0)
  TC3_DETAILS+=("$(basename "$catB")=${COUNT}")
  # PRESERVE-INVARIANT: each Category B file MUST keep >=1 atilcan65 mention
  # (intentional TC descriptions + INDEX.md historical rows + mock fixtures).
  if [ "$COUNT" -lt 1 ]; then
    TC3_PRESERVE_OK=0
  fi
done

if [ "$TC3_PRESERVE_OK" -eq 1 ]; then
  DETAIL_STR=$(IFS=', '; echo "${TC3_DETAILS[*]}")
  info "TC3 — intentional mentions preserved (${DETAIL_STR})"
  pass "TC3 — all ${#CATEGORY_B_FILES[@]} Category B files retain >=1 atilcan65 mention each (PRESERVE-INVARIANT held pre- and post-fix)"
else
  DETAIL_STR=$(IFS=', '; echo "${TC3_DETAILS[*]}")
  fail "TC3 — Category B at least one intentional mention lost post-fix (${DETAIL_STR})" \
    "expected every PRESERVE file (d095 + INDEX.md + d096 + d105 + proactive-sweep-test) to retain >=1 atilcan65 mention — these are intentional TC descriptions + historical rows + mock fixtures, the drift fix must NOT touch them. If any count dropped, the fix over-reached into MIGRATE-vs-PRESERVE territory."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: BARE-MENTION SWEEP — bare \batilcan65\b in Category A = 0 (broader pattern)
# ============================================================================
section "TC4: AC4 — bare atilcan65 mentions (any context) = 0 in Category A post-fix (broader sweep)"
# Distinction from TC1: TC1 checks URL-specific pattern `atilcan65/AtilCalculator`.
# TC4 checks ALL mentions of `atilcan65` as a word boundary (bare refs in URL
# path, comment prose, env var values).
TC4_BARE_COUNT=0
TC4_BARE_DETAILS=()
for catA in "${CATEGORY_A_FILES[@]}"; do
  C=$(grep -cE '\batilcan65\b' "$catA" 2>/dev/null || echo 0)
  TC4_BARE_COUNT=$((TC4_BARE_COUNT + C))
  if [ "$C" -gt 0 ]; then
    TC4_BARE_DETAILS+=("$(basename "$catA")=${C}")
  fi
done

if [ "$TC4_BARE_COUNT" = "0" ]; then
  pass "TC4 — bare atilcan65 mentions in Category A = 0 (broader sweep — covers URL + comment patterns, post-fix GREEN)"
else
  DETAIL_STR=$(IFS=', '; echo "${TC4_BARE_DETAILS[*]}")
  fail "TC4 — bare atilcan65 mentions in Category A = ${TC4_BARE_COUNT} (${DETAIL_STR})" \
    "expected 0 bare atilcan65 mentions in Category A post-fix. Pre-fix state: atilcan65 mentions persist beyond URL pattern. Re-run drift-fix grep over Category A with regex \\batilcan65\\b — comprehensive sweep including all contexts (URL refs, comment prose)."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: NET-RECONCILIATION — Category A URL refs = 0 AND Category B baseline preserved
# ============================================================================
section "TC5: AC5 — net-reconciliation: Category A = 0, Category B baseline preserved (intentional only)"
TC5_CATEGORY_A_COUNT=0
for catA in "${CATEGORY_A_FILES[@]}"; do
  C=$(grep -cF "${STALE_REF}" "$catA" 2>/dev/null || echo 0)
  TC5_CATEGORY_A_COUNT=$((TC5_CATEGORY_A_COUNT + C))
done
TC5_CATEGORY_B_COUNT=0
for catB in "${CATEGORY_B_FILES[@]}"; do
  C=$(grep -cF "${STALE_REF}" "$catB" 2>/dev/null || echo 0)
  TC5_CATEGORY_B_COUNT=$((TC5_CATEGORY_B_COUNT + C))
done

info "TC5 — Category A (MIGRATE) ${STALE_REF} mentions = ${TC5_CATEGORY_A_COUNT}; Category B (PRESERVE) mentions = ${TC5_CATEGORY_B_COUNT}; total = $((TC5_CATEGORY_A_COUNT + TC5_CATEGORY_B_COUNT))"

if [ "$TC5_CATEGORY_A_COUNT" = "0" ] && [ "$TC5_CATEGORY_B_COUNT" -gt 0 ]; then
  pass "TC5 — net-reconciled: Category A = 0 (drift cleared), Category B baseline = ${TC5_CATEGORY_B_COUNT} (intentional preserved); architect's TD-038 audit reconciled to whitelist-only"
else
  fail "TC5 — net-reconciliation FAILED: Category A = ${TC5_CATEGORY_A_COUNT} (expected 0), Category B = ${TC5_CATEGORY_B_COUNT} (expected > 0 preserved baseline)" \
    "TD-038 drift fix incomplete OR over-reaching. Expected: Category A URL refs reduced to 0 (drift cleared, 1 tracked file), Category B baseline preserved at >0 (intentional mentions — MIGRATE/PRESERVE discipline). Verify fix scope = 1 Category A tracked file; verify Category B 5 files NOT touched; verify the gitignored systemd unit (ADR-0011 drop-in) is NOT included in the d-test contract."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  Category A files (MIGRATE scope):           %d\n" "${#CATEGORY_A_FILES[@]}"
printf "  Category B files (PRESERVE scope):          %d\n" "${#CATEGORY_B_FILES[@]}"
printf "  Old org regression (TC1):                  %s\n" "$([ "$TC5_CATEGORY_A_COUNT" = "0" ] && echo "✓ 0 stale refs" || echo "✗ non-zero stale refs")"
printf "  New org positive (TC2):                    tested in TC1/TC2 section\n"
printf "  Preserve-invariant (TC3):                  %s\n" "$([ "$TC3_PRESERVE_OK" -eq 1 ] && echo "✓ intentional refs held" || echo "✗ intentional refs lost")"
printf "  Bare atilcan65 sweep (TC4):                 %s\n" "$([ "$TC4_BARE_COUNT" = "0" ] && echo "✓ 0 bare mentions" || echo "✗ ${TC4_BARE_COUNT} bare mentions")"
printf "  Net reconciliation (TC5):                   %s\n" "$([ "$TC5_CATEGORY_A_COUNT" = "0" ] && [ "$TC5_CATEGORY_B_COUNT" -gt 0 ] && echo "✓ reconciled (A=0, B>0 preserved)" || echo "✗ unreconciled")"
printf "  PASS: %d   FAIL: %d   INFO: %d\n" "$PASS" "$FAIL" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — TD-038 scripts/ lane drift fix incomplete${D}\n" "$FAIL"
  printf "${R}  PR #750 architect doc (Refs #739) does NOT close until this d-test goes GREEN.${D}\n"
  printf "${R}  Fix scope = Category A 1 tracked file (proactive-board-scan.sh); Category B 5 files MUST NOT be touched.${D}\n"
  exit 1
fi

printf "\n${G}GREEN state: all 5 TCs PASS — TD-038 scripts/ lane drift fix landed (P0 BUG post-#749 drift audit closed)${D}\n"
exit 0
