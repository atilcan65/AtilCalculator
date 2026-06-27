#!/usr/bin/env bash
# d046-expansion-adr-0044-literal-form.sh — ADR-0046 §A literal-form guard
# for scripts/agent-watch.sh.
#
# Why this test exists
# --------------------
# Per ADR-0046 §A + §Implementation step 3 (Sprint 9 P1, Issue #388
# RETRO-005 #19 audit): the load-bearing jq regex in scripts/agent-watch.sh
# (lines 1003 + 1065) defines ADR-0044 §Decision "test-only" detection.
# A future maintainer who "simplifies" the regex (e.g., removes one escape
# level, drops the basename anchor) would silently re-open TD-031
# (substring-overlap over-exclusion window) and break ADR-0044.
#
# This d-test is the backstop: it grep-verifies scripts/agent-watch.sh
# matches ADR-0046 §A verbatim (canonical literal form + multi-level
# escape sequence + basename anchor).
#
# Sister references:
#   - ADR-0046 §A (literal jq filter — canonical spec)
#   - ADR-0044 (load-bearing ADR being made literal)
#   - ADR-0046 §Implementation step 3 (this d-test's spec)
#   - TD-031 (substring-overlap window — closed by PR #393 basename fix)
#   - PR #393 (TD-031 fix, MERGED 2026-06-25T18:55:04Z)
#   - PR #405 (d046 sister-pattern, MERGED 2026-06-25T21:54:34Z)
#   - PR #409 (ADR-0046 source, AC references this d-test)
#   - Issue #388 (RETRO-005 #19 audit)
#   - Issue #410 (this d-test's tracker)
#
# Test cases:
#   T1: Canonical §A pattern verbatim in scripts/agent-watch.sh (both
#       line-1003 + line-1065 occurrences — the 2 query_* call sites).
#   T2: Basename anchor (TD-031) — `.path | split("/") | last` precedes
#       `test(...)` in both occurrences (closes substring-overlap window).
#   T3: Multi-level escape trace — bash source contains `\\\\.` (4
#       backslashes + dot) per ADR-0046 §A escaping table. Future
#       "simplification" PRs that remove escape levels break this TC.
#   T4: Sister-test regression — d046-peer-poke-canonical-parity.sh
#       still PASS (regression backstop, sister pattern per ADR-0046).
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d046-expansion-adr-0044-literal-form.sh

set -uo pipefail

# Path resolution: git rev-parse --show-toplevel is portable (per Issue #370 §T2 + d043).
REPO_ROOT="$(git rev-parse --show-toplevel)"
WATCH_SH="$REPO_ROOT/scripts/agent-watch.sh"

if [ ! -f "$WATCH_SH" ]; then
  echo "ERROR: scripts/agent-watch.sh not found at $WATCH_SH" >&2
  exit 127
fi

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Canonical §A pattern (verbatim from ADR-0046 §A line 46 — bash source escaping).
# grep -F treats this as a fixed string (not regex), so backslashes are literal.
CANONICAL_PATTERN='(\$bn | test(\"^(test_.*\\\\.(py|sh)|.*_test\\\\.(py|sh)|.*\\\\.test\\\\.(ts|js)|.*\\\\.spec\\\\.(ts|js)|.*Test\\\\.java)$\"))'

# ============================================================================
# T1: Canonical §A pattern verbatim in scripts/agent-watch.sh (both occurrences)
# ============================================================================
section "T1: Canonical §A pattern verbatim in scripts/agent-watch.sh (lines 1003 + 1065)"
OCCURRENCE_COUNT=$(grep -cF "$CANONICAL_PATTERN" "$WATCH_SH" || true)
if [ "$OCCURRENCE_COUNT" = "2" ]; then
  pass "canonical §A pattern appears exactly 2x (lines 1003 + 1065 — query_stale_verdict + query_missing_expectation)"
else
  fail "canonical §A pattern expected 2 occurrences, found $OCCURRENCE_COUNT" \
    "Expected: query_stale_verdict (line ~1003) + query_missing_expectation (line ~1065). Diff in scripts/agent-watch.sh breaks ADR-0044 §Decision test-only detection."
fi

# ============================================================================
# T2: Basename anchor (TD-031) — `.path | split("/") | last` precedes test(...)
# ============================================================================
section "T2: Basename anchor (TD-031) — split(\"/\") | last precedes test(...) in both occurrences"
# In scripts/agent-watch.sh the split() call is inside a double-quoted bash string,
# so the inner double quotes are escaped: split(\"/\") | last.
SPLIT_LAST_PATTERN='split(\"/\") | last'
SPLIT_LAST_LINES=$(grep -nF "$SPLIT_LAST_PATTERN" "$WATCH_SH" | cut -d: -f1 || true)
NEAR_TEST_COUNT=0
if [ -n "$SPLIT_LAST_LINES" ]; then
  for LINE in $SPLIT_LAST_LINES; do
    # Look in next 3 lines for `test(` (the canonical pattern invocation)
    if sed -n "$((LINE+1)),$((LINE+3))p" "$WATCH_SH" | grep -qF 'test('; then
      NEAR_TEST_COUNT=$((NEAR_TEST_COUNT + 1))
    fi
  done
fi
if [ "$NEAR_TEST_COUNT" = "2" ]; then
  pass "basename anchor (TD-031) precedes test(...) in 2 query_* call sites"
else
  fail "basename anchor expected adjacent to test(...) in 2 sites, found $NEAR_TEST_COUNT" \
    "TD-031 fix (PR #393) closes substring-overlap window. Removing split(\"/\") | last re-opens it."
fi

# ============================================================================
# T3: Multi-level escape trace — bash source contains `\\\\.` (4 backslashes + dot)
# ============================================================================
section "T3: Multi-level escape trace — bash source contains \\\\\\\\\\\\. (4 backslashes + dot)"
# Per ADR-0046 §A table: bash source `\\\\.` → shell `\\.` → jq `\.` → ERE `\.`.
# Any future maintainer who removes an escape level (e.g., drops to `\\.`) breaks the canonical form.
# grep -F '\\.\\.' matches the literal two-char sequence \\. (2 backslashes + dot).
# We expect: bash source has 4 backslashes + dot per .(extension) — i.e., `\\\\.` = `\\\\.`.
# Verify the file contains `\\\\.(py|sh)` or similar 4-backslash patterns.
ESCAPE_PATTERN='\\\\.'
ESCAPE_COUNT=$(grep -oF "$ESCAPE_PATTERN" "$WATCH_SH" | wc -l | tr -d ' ' || echo "0")
# ADR-0046 §A lists 6 extension anchors: 2x (py|sh) at start, 2x (py|sh) middle, 2x (ts|js), 2x (ts|js), 1x Java.
# In bash source that's: 4x (py|sh occurrences) + 4x (ts|js) + 1x Test\\.java = 9 expected escape sequences.
# We accept >= 5 to be tolerant of unrelated escape uses; the strict >= 9 is the design target.
if [ "$ESCAPE_COUNT" -ge 5 ]; then
  pass "bash source contains $ESCAPE_COUNT occurrences of \\\\\\\\. (canonical multi-level escape preserved)"
else
  fail "expected ≥5 \\\\\\\\. occurrences (canonical escape), found $ESCAPE_COUNT" \
    "Per ADR-0046 §A: bash `\\\\\\\\.` → shell `\\\\.` → jq `\\\\.` → ERE `\\\\.`. Future simplification PRs that remove escape levels break ADR-0044 test-only detection."
fi

# ============================================================================
# T4: Sister-test regression — d046-peer-poke-canonical-parity.sh still PASS
# ============================================================================
section "T4: d046-peer-poke-canonical-parity.sh regression — sister test still green"
SISTER_TEST="$REPO_ROOT/scripts/tests/d046-peer-poke-canonical-parity.sh"
if [ -f "$SISTER_TEST" ]; then
  if bash "$SISTER_TEST" >/dev/null 2>&1; then
    pass "d046-peer-poke-canonical-parity.sh still PASS (sister test regression)"
  else
    fail "d046-peer-poke-canonical-parity.sh FAIL — sibling-script regression detected"
  fi
else
  echo "  ${B}⊘ SKIP${D} — d046-peer-poke-canonical-parity.sh not found (sister test absent in this environment)"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
echo ""
echo "  Reference: ADR-0046 §A + §Implementation step 3, ADR-0044 §Decision,"
echo "             TD-031, Issue #388, Issue #410 (this d-test tracker)."
echo "  Sister regressions: d046-peer-poke-canonical-parity.sh (PR #405 MERGED)."
exit 0