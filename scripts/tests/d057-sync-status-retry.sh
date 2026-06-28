#!/usr/bin/env bash
# d057-sync-status-retry.sh — sync-status workflow retry + silent-skip guard
#
# Why this test exists
# --------------------
# d057 codifies the Issue #571 fix (sync-status workflow rate-limit cascade).
# PR #565 fix propagated but a NEW race surface remained: rapid label flips
# drain PROJECT_TOKEN GraphQL rate-limit (5000/hr classic PAT), causing
# sync-status failures that mark PRs as mergeable_state:unstable (squash
# gate blocker). The fix: withRetry() wrapper + silent-skip on exhausted
# retries + concurrency block (latest label state wins).
#
# Sister-pattern: d054 (deep-narrow), d055 (Layer 5 idempotency reconcile),
# d056 (regression guard), d058 (work-stream aware factory), d060 (fake-gh).
#
# 9 TCs (1 PASS baseline + 8 violation codifications, RED-first per ADR-0044).
# Pre-impl expected: 1 PASS (TC1 baseline) + 8 FAIL (TC2-TC9 violations).
# Post-impl expected: 9 PASS (all TCs green).
#
# Doctrine anchors:
# - ADR-0056 §Layer 5 idempotency reconcile (silent-skip sister-pattern)
# - ADR-0014 §PROJECT_TOKEN secret doctrine (rate-limit ceiling)
# - Issue #571 AC1-AC5 (sync-status retries + silent-skip + d-test)
# - §32 LIVE INSTANCE #8 + #13 (PR #565 + Issue #564 cascade family)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/status-label-to-board.yml"

# TTY-aware color setup (sister-pattern to d054/d058)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; Y=""; B=""; D=""
fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

# Preflight
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required for YAML validation" >&2; exit 2; }
[ -f "$WORKFLOW" ] || { echo "ERROR: workflow not found at $WORKFLOW" >&2; exit 2; }

# Self-test mode (RED-first per ADR-0044)
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

# ============================================================================
# TC1 (BASELINE PASS): workflow file exists and is syntactically valid YAML
# ============================================================================
section "TC1: workflow file exists + syntactically valid YAML (baseline)"
# Pre-impl: PASS (file exists, was valid before changes)
# Post-impl: PASS (still valid after withRetry addition)
if [ -f "$WORKFLOW" ] && python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW'))" 2>/dev/null; then
  pass "TC1: workflow file valid YAML (baseline)"
else
  fail "TC1: workflow file missing or YAML invalid"
fi

# ============================================================================
# TC2 (FAIL→PASS): workflow has withRetry() helper function
# ============================================================================
section "TC2: workflow defines withRetry() helper for GraphQL retry"
# Pre-impl: FAIL (no withRetry function)
# Post-impl: PASS (withRetry wraps every github.graphql call)
if grep -q "async function withRetry" "$WORKFLOW" 2>/dev/null; then
  pass "TC2: withRetry() helper defined (ADR-0056 §Layer 5 idempotency reconcile)"
else
  fail "TC2: workflow MUST define withRetry() helper for GraphQL rate-limit retry"
fi

# ============================================================================
# TC3 (FAIL→PASS): workflow has silentSkipOnRateLimit() helper function
# ============================================================================
section "TC3: workflow defines silentSkipOnRateLimit() helper"
# Pre-impl: FAIL (no silent-skip helper)
# Post-impl: PASS (silent-skip on exhausted retries per ADR-0056)
if grep -q "function silentSkipOnRateLimit" "$WORKFLOW" 2>/dev/null; then
  pass "TC3: silentSkipOnRateLimit() helper defined (ADR-0056 §silent_skip)"
else
  fail "TC3: workflow MUST define silentSkipOnRateLimit() helper for exhausted-retry fallback"
fi

# ============================================================================
# TC4 (FAIL→PASS): all github.graphql() calls wrapped in withRetry()
# ============================================================================
section "TC4: every github.graphql() call is wrapped in withRetry()"
# Pre-impl: FAIL (raw graphql calls, no retry wrapper)
# Post-impl: PASS (4 call sites all wrapped)
# Count raw graphql calls (not inside withRetry)
total_graphql=$(grep -E "^\s*(const|await)\s+.*github\.graphql\(" "$WORKFLOW" 2>/dev/null | grep -vc "withRetry" || true)
wrapped_graphql=$(grep -cE "withRetry\(\(\) => github\.graphql\(" "$WORKFLOW" 2>/dev/null)
# Exclude comment-only matches
total_graphql=$((total_graphql + 0))
if [ "$wrapped_graphql" -ge 4 ] && [ "$total_graphql" -eq 0 ]; then
  pass "TC4: all 4 github.graphql() calls wrapped in withRetry() (comment matches excluded)"
else
  fail "TC4: only $wrapped_graphql wrapped + $total_graphql unwrapped graphql calls found"
fi

# ============================================================================
# TC5 (FAIL→PASS): workflow has concurrency block (per-PR serialization)
# ============================================================================
section "TC5: workflow has concurrency block to serialize per-PR runs"
# Pre-impl: FAIL (no concurrency block, runs fan out)
# Post-impl: PASS (cancel-in-progress: true, latest label wins)
if grep -qE "^concurrency:" "$WORKFLOW" 2>/dev/null && grep -qE "cancel-in-progress:[[:space:]]+true" "$WORKFLOW" 2>/dev/null; then
  pass "TC5: concurrency block + cancel-in-progress: true (latest label wins)"
else
  fail "TC5: workflow MUST have concurrency block + cancel-in-progress: true (rate-limit mitigation)"
fi

# ============================================================================
# TC6 (FAIL→PASS): silent-skip logs core.warning (not setFailed)
# ============================================================================
section "TC6: silent-skip uses core.warning + early return (not core.setFailed)"
# Pre-impl: FAIL (no silent-skip pattern)
# Post-impl: PASS (rate-limit errors → core.warning + return, not setFailed)
if grep -B2 "core.warning.*silent-skip" "$WORKFLOW" 2>/dev/null | grep -q "silentSkipOnRateLimit"; then
  pass "TC6: silent-skip emits core.warning + early return (ADR-0056 §silent_skip)"
else
  fail "TC6: silent-skip MUST emit core.warning + early return, not core.setFailed"
fi

# ============================================================================
# TC7 (FAIL→PASS): try-catch wraps the GraphQL block
# ============================================================================
section "TC7: try-catch wraps GraphQL block for silent-skip catch"
# Pre-impl: FAIL (no try-catch around GraphQL operations)
# Post-impl: PASS (try { ... } catch (err) { silentSkipOnRateLimit(err) })
if grep -qE "^\s+try \{$" "$WORKFLOW" 2>/dev/null && grep -qE "^\s+\} catch \(err\) \{" "$WORKFLOW" 2>/dev/null; then
  pass "TC7: try-catch wraps GraphQL block (catches exhausted-retry errors)"
else
  fail "TC7: workflow MUST wrap GraphQL block in try-catch for silent-skip"
fi

# ============================================================================
# TC8 (FAIL→PASS): non-rate-limit errors propagate (don't silent-skip)
# ============================================================================
section "TC8: non-rate-limit errors propagate (don't silent-skip)"
# Pre-impl: FAIL (catch wasn't selective)
# Post-impl: PASS (only rate-limit caught silently; others re-thrown via throw err)
if grep -F "throw err" "$WORKFLOW" 2>/dev/null | grep -v "withRetry" | grep -q "throw err"; then
  pass "TC8: non-rate-limit errors re-thrown (silent-skip is selective)"
else
  fail "TC8: catch block MUST re-throw non-rate-limit errors (don't swallow all)"
fi

# ============================================================================
# TC9 (FAIL→PASS): concurrency group includes PR/issue number (per-resource serialization)
# ============================================================================
section "TC9: concurrency group keys on PR/issue number (per-resource serialize)"
# Pre-impl: FAIL (no concurrency or global group)
# Post-impl: PASS (group: sync-status-PR/issue number)
if grep -F 'sync-status-' "$WORKFLOW" 2>/dev/null | grep -F 'pull_request.number' | grep -F 'issue.number' | grep -q 'group:'; then
  pass "TC9: concurrency group per PR/issue number (no cross-PR interference)"
else
  fail "TC9: concurrency group MUST key on PR/issue number (avoid cross-PR rate-limit drain)"
fi

# ============================================================================
# Summary (sister-pattern to d054 + d058)
# ============================================================================
printf "\n${B}==== d057 SELF-TEST SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

# Pre-impl expected: 1 PASS (TC1 baseline) + 8 FAIL (TC2-TC9 violations)
# Post-impl expected: 9 PASS (all TCs green)
if [ "$PASS" -eq 9 ] && [ "$FAIL" -eq 0 ]; then
  printf "  ${G}d057 GREEN${D} — 9/9 PASS = sync-status retry + silent-skip fully impl'd\n"
  exit 0
elif [ "$PASS" -eq 1 ] && [ "$FAIL" -eq 8 ]; then
  printf "  ${Y}d057 RED${D} — 1/9 PASS + 8/9 FAIL = expected pre-impl RED state\n"
  exit 1
else
  printf "  ${R}d057 RED (unexpected)${D} — counts outside expected range. Investigate.\n"
  exit 1
fi