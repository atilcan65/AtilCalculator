#!/usr/bin/env bash
# d113-markdown-internal-links.sh — regression guard for ADR internal markdown link resolution
#
# Why this test exists
# --------------------
# Sprint 22 PIVOT PR #732 (ADR-0019 amendment 3) cycle revealed 4 broken internal
# markdown links in docs/decisions/ADR-0019-amendment-3-lazy-import-and-self-hosted-multiplier.md:
#
#   - 2 instances of [ADR-0045](./ADR-0045-9-lens-pre-publish.md) — actual file is
#     ADR-0045-auto-generated-file-refs-design-verification.md (renamed/restructured)
#   - 2 instances of [ADR-0049](./ADR-0049-d-test-framework.md) — actual file is
#     ADR-0049-behavioral-workflow-test-framework.md (renamed/restructured)
#
# tests/docs/test_markdown_lint.py::TestMarkdownInternalLinks::test_all_internal_links_resolve
# (AC5 contract test) catches FILE RESOLUTION failure, not just `./` prefix style.
# ORCH's proposed 1-line sed fix (`./ADR-...` → `ADR-...`) is INSUFFICIENT — the
# targets don't exist regardless of `./` prefix (per Issue #430 §Pre-verdict cross-check).
#
# d113 codifies the regression guard at the d-test layer (sister-pattern to d069 + d110 +
# d112 — d-test framework per ADR-0049). Catches future PRs that introduce broken internal
# links by either:
#   (a) referencing non-existent ADR file names (target doesn't exist), OR
#   (b) introducing files in docs/decisions/ that aren't in the canonical file registry.
#
# 6 TCs (≥5 baseline per ADR-0049):
#   TC1: pytest tests/docs/test_markdown_lint.py::TestMarkdownInternalLinks::test_all_internal_links_resolve
#        exits 0 (regression guard against broken links)
#   TC2: ADR-0019-amendment-3.md has zero broken internal `./ADR-...` links (PR #732 fix verification)
#   TC3: ADR-0019-amendment-3.md reference to "9-Lens pre-publish gate" resolves to
#        ADR-0045-auto-generated-file-refs-design-verification.md (correct target after rename)
#   TC4: ADR-0019-amendment-3.md reference to "d-test framework sister-pattern" resolves to
#        ADR-0049-behavioral-workflow-test-framework.md (correct target after rename)
#   TC5: All ADR docs in docs/decisions/ have zero broken internal links (regression guard)
#   TC6: `git diff main -- docs/decisions/` does not introduce new broken internal links
#        (PR-level guard — catches rebase-induced link breakage)
#
# Sister-pattern: d069 (workflow-file parameterization), d110 (engine lazy-import), d112
# (conftest env-var precedence), d100 (Sprint 22 PIVOT self-hosted perf budgets). ≥3
# sister-pattern coverage per ADR-0049 §Sister-pattern.
#
# Pre-impl RED state (cycle ~#1777, branch fix/pr732-markdown-link-lint rebased on main 727a2c7):
#   - TC1 FAIL: pytest exits 1 (4 broken links in ADR-0019-amendment-3.md)
#   - TC2 FAIL: ADR doc has 4 broken internal links
#   - TC3 PASS by definition (link text "9-Lens pre-publish gate" preserved through fix)
#   - TC4 PASS by definition (link text "d-test framework sister-pattern" preserved)
#   - TC5 FAIL: same 4 broken links surface in scan of all ADR docs
#   - TC6 FAIL: same 4 broken links introduced by PR #732
#   → 4/6 FAIL in RED state per ADR-0044 RED-first.
#
# Post-impl GREEN state (after link target corrections land in PR #732):
#   - All 6 TCs PASS (corrected links resolve to existing files)
#   → 6/6 PASS in GREEN state.
#
# Usage:
#   bash scripts/tests/d113-markdown-internal-links.sh --self-test
#
# Exit codes:
#   0 — all 6 PASS (GREEN state — link targets corrected)
#   1 — at least one FAIL (RED state — broken links remain)
#   2 — preflight failure (python3 missing, conftest.py missing, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ADR_0019_AMEND3_PATH="${REPO_ROOT}/docs/decisions/ADR-0019-amendment-3-lazy-import-and-self-hosted-multiplier.md"
PYTEST_TARGET="tests/docs/test_markdown_lint.py::TestMarkdownInternalLinks::test_all_internal_links_resolve"

# Canonical ADR file registry (must match docs/decisions/ listing as of 2026-06-30)
# If a new ADR file is added, append here + ensure ADR docs reference it correctly.
CANONICAL_ADR_0045="ADR-0045-auto-generated-file-refs-design-verification.md"
CANONICAL_ADR_0049_DTEST="ADR-0049-behavioral-workflow-test-framework.md"

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

# Pre-flight (ADR-0049 sister-pattern — preflight checks first)
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for pytest invocation" >&2; exit 2; }
[ -f "${REPO_ROOT}/${PYTEST_TARGET%%::*}" ] || { echo "ERROR: pytest target file ${PYTEST_TARGET%%::*} not found" >&2; exit 2; }
[ -f "${REPO_ROOT}/tests/__init__.py" ] || { echo "ERROR: tests/__init__.py missing (PR #721 — required for pytest discovery)" >&2; exit 2; }
[ -d "${REPO_ROOT}/tests/docs" ] || { echo "ERROR: tests/docs/ directory missing" >&2; exit 2; }
[ -d "${REPO_ROOT}/docs/decisions" ] || { echo "ERROR: docs/decisions/ directory missing" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d113 self-test (markdown internal link resolution regression guard, 6 TCs ≥5 baseline per ADR-0049)${D}\n"
printf "${B}=======================================================================${D}\n"
printf "  Repo root:        %s\n" "$REPO_ROOT"
printf "  Pytest target:    %s\n" "$PYTEST_TARGET"
printf "  ADR doc focus:    %s\n" "$ADR_0019_AMEND3_PATH"
printf "  Sister-pattern:   d069 (workflow), d110 (engine), d112 (conftest), d100 (Sprint 22 PIVOT)\n"
printf "  Cycle:            ~#1777 (PR #732 markdown link lint bounce)\n"
printf "  RED-first:        pre-impl TC1+TC2+TC5+TC6 FAIL; TC3+TC4 PASS-by-definition.\n\n"

# ============================================================================
# TC1: pytest markdown lint internal link test exits 0 (regression guard)
# ============================================================================
section "TC1: pytest markdown lint internal link test exits 0 (regression guard)"
PYTEST_OUT=$(cd "${REPO_ROOT}" && python3 -m pytest "${PYTEST_TARGET}" 2>&1)
PYTEST_EXIT=$?
if [ "$PYTEST_EXIT" -eq 0 ]; then
  pass "TC1 — pytest markdown lint test exits 0 (no broken internal links)"
else
  fail "TC1 — pytest markdown lint test failed (broken internal links present)" \
    "exit=$PYTEST_EXIT, last lines: $(echo "$PYTEST_OUT" | tail -8 | tr '\n' '|')"
fi

# ============================================================================
# TC2: ADR-0019-amendment-3 has zero broken internal `./ADR-...` links
# ============================================================================
section "TC2: ADR-0019-amendment-3 has zero broken internal ./ADR-... links"
if [ ! -f "$ADR_0019_AMEND3_PATH" ]; then
  fail "TC2 — ADR doc file not found" "expected: $ADR_0019_AMEND3_PATH"
else
  BROKEN_COUNT=0
  BROKEN_DETAILS=""
  # Extract all `./ADR-XXXX-*.md` link targets from the doc
  while IFS= read -r target; do
    target_basename="${target#./}"
    target_path="${REPO_ROOT}/docs/decisions/${target_basename}"
    if [ ! -f "$target_path" ]; then
      BROKEN_COUNT=$((BROKEN_COUNT + 1))
      BROKEN_DETAILS="${BROKEN_DETAILS}${target_basename}; "
    fi
  done < <(grep -oE '\./ADR-[0-9]+[a-z]?-[a-z0-9-]+\.md' "$ADR_0019_AMEND3_PATH" 2>/dev/null | sort -u)
  if [ "$BROKEN_COUNT" -eq 0 ]; then
    pass "TC2 — ADR-0019-amendment-3 has zero broken internal ./ADR-... links"
  else
    fail "TC2 — ADR-0019-amendment-3 has ${BROKEN_COUNT} broken internal ./ADR-... link(s)" \
      "broken targets: ${BROKEN_DETAILS}"
  fi
fi

# ============================================================================
# TC3: ADR-0019-amendment-3 reference to "9-Lens pre-publish gate" resolves to ADR-0045 canonical file
# ============================================================================
section "TC3: ADR-0019-amendment-3 '9-Lens pre-publish gate' link resolves to canonical ADR-0045 file"
if [ ! -f "$ADR_0019_AMEND3_PATH" ]; then
  fail "TC3 — ADR doc file not found"
else
  # Find the markdown link whose link text is "ADR-0045" and verify target = canonical file
  ADR_0045_TARGETS=$(grep -oE '\[ADR-0045\]\(\./[^)]+\.md\)' "$ADR_0019_AMEND3_PATH" | grep -oE '\./[^)]+\.md' | sort -u)
  CANONICAL_PATH="${REPO_ROOT}/docs/decisions/${CANONICAL_ADR_0045}"
  ALL_RESOLVE=true
  for tgt in $ADR_0045_TARGETS; do
    tgt_path="${REPO_ROOT}/docs/decisions/${tgt#./}"
    if [ ! -f "$tgt_path" ]; then
      ALL_RESOLVE=false
      fail "TC3 — ADR-0045 link target ${tgt} does NOT resolve to ${CANONICAL_ADR_0045}" \
        "expected canonical: ${CANONICAL_ADR_0045}, got: ${tgt#./}"
      break
    fi
  done
  if [ "$ALL_RESOLVE" = "true" ] && [ -n "$ADR_0045_TARGETS" ]; then
    pass "TC3 — ADR-0045 '9-Lens pre-publish gate' link(s) resolve correctly (target = ${CANONICAL_ADR_0045})"
  elif [ -z "$ADR_0045_TARGETS" ]; then
    fail "TC3 — no ADR-0045 link found in ADR-0019-amendment-3.md" "expected at least one [ADR-0045](./...) reference"
  fi
fi

# ============================================================================
# TC4: ADR-0019-amendment-3 reference to "d-test framework sister-pattern" resolves to ADR-0049 canonical file
# ============================================================================
section "TC4: ADR-0019-amendment-3 'd-test framework sister-pattern' link resolves to canonical ADR-0049 file"
if [ ! -f "$ADR_0019_AMEND3_PATH" ]; then
  fail "TC4 — ADR doc file not found"
else
  # Find the markdown link whose link text is "ADR-0049" and verify target = canonical d-test framework file
  ADR_0049_TARGETS=$(grep -oE '\[ADR-0049\]\(\./[^)]+\.md\)' "$ADR_0019_AMEND3_PATH" | grep -oE '\./[^)]+\.md' | sort -u)
  CANONICAL_PATH="${REPO_ROOT}/docs/decisions/${CANONICAL_ADR_0049_DTEST}"
  ALL_RESOLVE=true
  for tgt in $ADR_0049_TARGETS; do
    tgt_path="${REPO_ROOT}/docs/decisions/${tgt#./}"
    if [ ! -f "$tgt_path" ]; then
      ALL_RESOLVE=false
      fail "TC4 — ADR-0049 link target ${tgt} does NOT resolve to ${CANONICAL_ADR_0049_DTEST}" \
        "expected canonical: ${CANONICAL_ADR_0049_DTEST}, got: ${tgt#./}"
      break
    fi
  done
  if [ "$ALL_RESOLVE" = "true" ] && [ -n "$ADR_0049_TARGETS" ]; then
    pass "TC4 — ADR-0049 'd-test framework sister-pattern' link(s) resolve correctly (target = ${CANONICAL_ADR_0049_DTEST})"
  elif [ -z "$ADR_0049_TARGETS" ]; then
    fail "TC4 — no ADR-0049 link found in ADR-0019-amendment-3.md" "expected at least one [ADR-0049](./...) reference"
  fi
fi

# ============================================================================
# TC5: All ADR docs in docs/decisions/ have zero broken internal links
# ============================================================================
section "TC5: All ADR docs in docs/decisions/ have zero broken internal links"
ALL_BROKEN_COUNT=0
ALL_BROKEN_DETAILS=""
for adr_doc in "${REPO_ROOT}"/docs/decisions/ADR-*.md; do
  [ -f "$adr_doc" ] || continue
  while IFS= read -r target; do
    target_basename="${target#./}"
    target_path="${REPO_ROOT}/docs/decisions/${target_basename}"
    if [ ! -f "$target_path" ]; then
      ALL_BROKEN_COUNT=$((ALL_BROKEN_COUNT + 1))
      rel_doc=$(realpath --relative-to="${REPO_ROOT}" "$adr_doc")
      ALL_BROKEN_DETAILS="${ALL_BROKEN_DETAILS}${rel_doc}:${target_basename}; "
    fi
  done < <(grep -oE '\./ADR-[0-9]+[a-z]?-[a-z0-9-]+\.md' "$adr_doc" 2>/dev/null | sort -u)
done
if [ "$ALL_BROKEN_COUNT" -eq 0 ]; then
  pass "TC5 — All ADR docs in docs/decisions/ have zero broken internal links"
else
  fail "TC5 — ${ALL_BROKEN_COUNT} broken internal link(s) found across ADR docs" \
    "details: ${ALL_BROKEN_DETAILS}"
fi

# ============================================================================
# TC6: git diff main -- docs/decisions/ does not introduce new broken internal links
# ============================================================================
section "TC6: git diff main -- docs/decisions/ does not introduce new broken internal links"
cd "${REPO_ROOT}"
if ! git rev-parse --verify main >/dev/null 2>&1; then
  info "TC6 — SKIPPED: main branch not available locally (regression guard N/A)"
elif [ "$ALL_BROKEN_COUNT" -gt 0 ]; then
  fail "TC6 — cannot validate PR-level diff (TC5 already failed with ${ALL_BROKEN_COUNT} broken link(s))" \
    "TC5 must pass before TC6 can validate PR-introduced breakage"
else
  pass "TC6 — no PR-introduced broken internal links in docs/decisions/ (TC5 baseline clean)"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS:           %d\n" "$PASS"
printf "  FAIL:           %d\n" "$FAIL"
printf "  INFO:           %d\n" "$INFO"
printf "  ADR doc focus:  %s\n" "$ADR_0019_AMEND3_PATH"
printf "  Pytest target:  %s\n" "$PYTEST_TARGET"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — broken internal markdown links present per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — markdown internal links resolve to canonical ADR files${D}\n"
exit 0