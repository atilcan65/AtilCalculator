#!/usr/bin/env bash
# d114-url-hygiene-atilcan65-to-atilproject.sh — regression guard for ADR URL hygiene (atilcan65/AtilCalculator → atilproject/AtilCalculator)
#
# Why this test exists
# --------------------
# Sprint 22 audit cycle ~#1822 surfaced 75 stale `atilcan65/AtilCalculator` URLs
# across 20 ADR files in `docs/decisions/`. URLs are NOT broken — GitHub HTTP
# redirect (HTTP 200, click-time resolves to atilproject) — so the drift was
# textual, not functional. Per file ownership matrix: `docs/decisions/**` = arch
# lane (Issue #739 scope). PR #739 (this d-test's sister) applies the sed fix.
#
# Costs of the textual drift (now closed):
# 1. Tooling drift — any tool that does string-matching on repo URL (CI workflows,
#    owner-policy scripts, d-tests) may not handle the redirect cleanly.
# 2. Discoverability cost — new agents/humans reading ADRs may believe the repo
#    is at atilcan65 when it's actually at atilproject (CLAUDE.md also stale).
# 3. Search rank pollution — `grep atilcan65/AtilCalculator docs/decisions/`
#    returns 75 hits; canonical `atilproject/AtilCalculator` returned 0 in
#    many files (now 75+).
#
# 6 TCs (≥5 baseline per ADR-0049):
#   TC1: `grep -r atilcan65/AtilCalculator docs/decisions/` returns 0 matches
#        (regression guard against URL drift)
#   TC2: `grep -r atilproject/AtilCalculator docs/decisions/ | wc -l` shows
#        ≥75 matches (canonical ref present at scale)
#   TC3: Specific ADR files (ADR-0019-api-contract.md, ADR-0017-tech-stack.md)
#        contain atilproject/AtilCalculator refs (canonical redirect target)
#   TC4: INDEX.md has ZERO atilcan65/AtilCalculator occurrences (sanity check
#        that Cadence Rule 1 atomic update per ADR-0055 §1 was applied)
#   TC5: Sister-pattern to d113 (markdown link resolution) — verify d114 is
#        registered in scripts/tests/INDEX.md (Cadence Rule 1 atomic)
#   TC6: Live-state verification — `git diff main -- docs/decisions/` does NOT
#        introduce new atilcan65/AtilCalculator refs (PR-level guard — catches
#        rebase-induced drift regression)
#
# Sister-pattern: d113 (markdown internal link resolution, post-#732 squash),
# d100 (env-aware perf budgets), d094 (self-hosted runner migration). ≥3
# sister-pattern coverage per ADR-0049 §Sister-pattern.
#
# Pre-impl RED state (Issue #739 epoch, branch main pre-PR #739 squash):
#   - TC1 FAIL: grep returns 75+ matches
#   - TC2 FAIL: grep returns 0 matches (canonical refs absent at scale)
#   - TC3 FAIL: ADR-0019-api-contract.md has 2 stale refs (no atilproject)
#   - TC4 FAIL: INDEX.md has 0 stale refs (already clean — pre-existing state)
#   - TC5 FAIL: d114 NOT registered in INDEX.md
#   - TC6 FAIL: same drift in PR diff (post-fix, this TC must pass)
#   → 4/6 FAIL in RED state per ADR-0044 RED-first.
#
# Post-impl GREEN state (after PR #739 lands):
#   - All 6 TCs PASS (sed fix applied + INDEX.md atomic update + d114 registered)
#   → 6/6 PASS in GREEN state.
#
# Usage:
#   bash scripts/tests/d114-url-hygiene-atilcan65-to-atilproject.sh --self-test
#
# Exit codes:
#   0 — all 6 PASS (GREEN state — URL hygiene restored)
#   1 — at least one FAIL (RED state — drift remains)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DECISIONS_DIR="${REPO_ROOT}/docs/decisions"
INDEX_PATH="${DECISIONS_DIR}/INDEX.md"

# Canonical ADR file registry (sister-pattern to d113, scope: docs/decisions/ only)
CANONICAL_REPO_URL="atilproject/AtilCalculator"
DEPRECATED_REPO_URL="atilcan65/AtilCalculator"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

pass() { printf "${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "${R}✗ FAIL${D} — %s\n" "$1"; FAIL=$((FAIL+1)); [ -n "${2:-}" ] && printf "        %s\n" "$2"; }
info() { printf "${Y}ℹ INFO${D} — %s\n" "$1"; INFO=$((INFO+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Preflight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v wc >/dev/null 2>&1 || { echo "ERROR: wc required" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git required (TC6)" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

if [ ! -d "$DECISIONS_DIR" ]; then
  echo "ERROR: docs/decisions/ not found at $DECISIONS_DIR" >&2
  exit 2
fi

PASS=0; FAIL=0; INFO=0

printf "${B}d114 self-test (6 TCs per Issue #739 + ADR-0049, ADR-0044 RED-first)${D}\n"
printf "${B}====================================================================${D}\n"
printf "  Scope:                 %s\n" "$DECISIONS_DIR"
printf "  Deprecated URL:        %s\n" "$DEPRECATED_REPO_URL"
printf "  Canonical URL:         %s\n" "$CANONICAL_REPO_URL"
printf "  Sister-pattern:        d113 (markdown internal links), d100, d094\n"
printf "  Cadence Rule 1 atomic: d-test file + INDEX.md entry in same PR per ADR-0055 §1\n"
printf "  RED-first:             pre-#739-impl 4/6 FAIL. Post-impl: 6/6 GREEN.\n\n"

# ============================================================================
# TC1: deprecated URL absent from docs/decisions/ (regression guard)
# ============================================================================
section "TC1: deprecated URL absent from docs/decisions/ (Issue #739 AC1)"
DEPRECATED_HITS=$(grep -rl "${DEPRECATED_REPO_URL}" "${DECISIONS_DIR}" 2>/dev/null | wc -l)
DEPRECATED_LINES=$(grep -rh "${DEPRECATED_REPO_URL}" "${DECISIONS_DIR}" 2>/dev/null | wc -l)
if [ "$DEPRECATED_HITS" -eq 0 ]; then
  pass "TC1 — ${DEPRECATED_REPO_URL} absent from docs/decisions/ (0 files, 0 lines)"
else
  fail "TC1 — ${DEPRECATED_REPO_URL} STILL PRESENT in ${DEPRECATED_HITS} file(s), ${DEPRECATED_LINES} line(s)" \
    "expected 0. Files: $(grep -rl "${DEPRECATED_REPO_URL}" "${DECISIONS_DIR}" 2>/dev/null | head -5 | tr '\n' ' ')"
fi

# ============================================================================
# TC2: canonical URL present at scale (≥75 matches after PR #739 fix)
# ============================================================================
section "TC2: canonical URL present at scale (Issue #739 AC2)"
CANONICAL_HITS=$(grep -rl "${CANONICAL_REPO_URL}" "${DECISIONS_DIR}" 2>/dev/null | wc -l)
CANONICAL_LINES=$(grep -rh "${CANONICAL_REPO_URL}" "${DECISIONS_DIR}" 2>/dev/null | wc -l)
if [ "$CANONICAL_LINES" -ge 75 ]; then
  pass "TC2 — ${CANONICAL_REPO_URL} present in ${CANONICAL_HITS} file(s), ${CANONICAL_LINES} line(s) (≥75 baseline)"
else
  fail "TC2 — ${CANONICAL_REPO_URL} count (${CANONICAL_LINES}) below 75 baseline" \
    "expected ≥75 after PR #739 fix. Currently ${CANONICAL_LINES}."
fi

# ============================================================================
# TC3: specific ADR files contain canonical URL (spot-check)
# ============================================================================
section "TC3: specific ADR files contain canonical URL (canonical redirect target spot-check)"
SPOT_CHECK_PASS=0
SPOT_CHECK_TOTAL=0
for f in ADR-0019-api-contract.md ADR-0017-tech-stack.md ADR-0002-autonomy-loop.md ADR-0053-layer-5-race-pattern.md; do
  SPOT_CHECK_TOTAL=$((SPOT_CHECK_TOTAL+1))
  FILE_PATH="${DECISIONS_DIR}/${f}"
  if [ ! -f "$FILE_PATH" ]; then
    info "TC3.${f} — file not found (skip)"
    continue
  fi
  FILE_CANONICAL_COUNT=$(grep -c "${CANONICAL_REPO_URL}" "$FILE_PATH" 2>/dev/null | tr -d '[:space:]'; true)
  FILE_CANONICAL_COUNT=${FILE_CANONICAL_COUNT:-0}
  FILE_DEPRECATED_COUNT=$(grep -c "${DEPRECATED_REPO_URL}" "$FILE_PATH" 2>/dev/null | tr -d '[:space:]'; true)
  FILE_DEPRECATED_COUNT=${FILE_DEPRECATED_COUNT:-0}
  if [ "$FILE_CANONICAL_COUNT" -ge 1 ] && [ "$FILE_DEPRECATED_COUNT" -eq 0 ]; then
    SPOT_CHECK_PASS=$((SPOT_CHECK_PASS+1))
    info "TC3.${f} — canonical=${FILE_CANONICAL_COUNT}, deprecated=${FILE_DEPRECATED_COUNT} ✓"
  else
    fail "TC3.${f} — canonical=${FILE_CANONICAL_COUNT} (≥1 required), deprecated=${FILE_DEPRECATED_COUNT} (0 required)" \
      "expected canonical refs ≥1 + zero deprecated refs."
  fi
done
if [ "$SPOT_CHECK_PASS" -eq "$SPOT_CHECK_TOTAL" ] && [ "$SPOT_CHECK_TOTAL" -gt 0 ]; then
  pass "TC3 — ${SPOT_CHECK_PASS}/${SPOT_CHECK_TOTAL} spot-check ADR files have canonical URL + zero deprecated URL"
fi

# ============================================================================
# TC4: INDEX.md has zero deprecated URL occurrences (Cadence Rule 1 atomic)
# ============================================================================
section "TC4: INDEX.md zero deprecated URL (ADR-0055 §1 Cadence Rule 1 atomic)"
if [ ! -f "$INDEX_PATH" ]; then
  fail "TC4 — INDEX.md not found at $INDEX_PATH" ""
elif INDEX_DEPRECATED=$(grep -c "${DEPRECATED_REPO_URL}" "$INDEX_PATH" 2>/dev/null | tr -d '[:space:]'; true); then
  INDEX_DEPRECATED=${INDEX_DEPRECATED:-0}
  if [ "$INDEX_DEPRECATED" -eq 0 ]; then
    pass "TC4 — INDEX.md has 0 deprecated URL occurrences (Cadence Rule 1 atomic preserved)"
  else
    fail "TC4 — INDEX.md has ${INDEX_DEPRECATED} deprecated URL occurrence(s)" \
      "expected 0. Issue #739 AC3 violated (atomic update missing)."
  fi
fi

# ============================================================================
# TC5: d114 registered in scripts/tests/INDEX.md (Cadence Rule 1 atomic)
# ============================================================================
section "TC5: d114 registered in scripts/tests/INDEX.md (Cadence Rule 1 atomic)"
TESTS_INDEX="${SCRIPT_DIR}/INDEX.md"
if [ ! -f "$TESTS_INDEX" ]; then
  fail "TC5 — scripts/tests/INDEX.md not found at $TESTS_INDEX" ""
elif grep -qE 'd114.*url-hygiene-atilcan65|URL hygiene.*d114|d114.*URL hygiene' "$TESTS_INDEX" 2>/dev/null; then
  pass "TC5 — d114 registered in scripts/tests/INDEX.md (Cadence Rule 1 atomic preserved)"
else
  fail "TC5 — d114 NOT registered in scripts/tests/INDEX.md" \
    "expected INDEX.md entry per ADR-0055 §1 Cadence Rule 1 atomic. Sister-pattern to d113 + d100 + d094."
fi

# ============================================================================
# TC6: PR-level live-state guard — git diff main does NOT introduce new deprecated URL
# ============================================================================
section "TC6: git diff main does NOT introduce new deprecated URL (PR-level guard)"
if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  fail "TC6 — not a git repository ($REPO_ROOT)" ""
else
  # Capture the diff against main (or origin/main if main branch unavailable)
  MAIN_REF="main"
  if ! git -C "$REPO_ROOT" rev-parse --verify "${MAIN_REF}" >/dev/null 2>&1; then
    MAIN_REF="origin/main"
  fi
  if ! git -C "$REPO_ROOT" rev-parse --verify "${MAIN_REF}" >/dev/null 2>&1; then
    info "TC6 — neither main nor origin/main available; skipping PR-level guard (not blocking)"
  else
    PR_DEPRECATED=$(git -C "$REPO_ROOT" diff "${MAIN_REF}" -- "docs/decisions/" 2>/dev/null | grep -c "^+.*${DEPRECATED_REPO_URL}" | tr -d '[:space:]'; true)
    PR_DEPRECATED=${PR_DEPRECATED:-0}
    if [ "$PR_DEPRECATED" -eq 0 ]; then
      pass "TC6 — git diff ${MAIN_REF} introduces 0 new deprecated URLs in docs/decisions/ (PR-level guard clean)"
    else
      fail "TC6 — git diff ${MAIN_REF} introduces ${PR_DEPRECATED} new deprecated URL line(s)" \
        "expected 0. PR-level drift regression. Sister-pattern to d113 TC6 (rebase-induced link breakage)."
    fi
  fi
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS:           %d\n" "$PASS"
printf "  FAIL:           %d\n" "$FAIL"
printf "  INFO:           %d\n" "$INFO"
printf "  Deprecated URL: %s (target: 0 occurrences)\n" "$DEPRECATED_REPO_URL"
printf "  Canonical URL:  %s (baseline: ≥75 occurrences post-#739-fix)\n" "$CANONICAL_REPO_URL"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}GREEN state: all TCs PASS — URL hygiene restored per Issue #739 + ADR-0049${D}\n"
  exit 0
else
  printf "\n${R}RED state: %d TC(s) FAIL — URL drift remains or INDEX.md atomic update missing${D}\n" "$FAIL"
  exit 1
fi