#!/usr/bin/env bash
# d026-layer3-open-only-fire.sh — regression for ADR-0035 Layer 3 open-only fire.
#
# Why this test exists
# --------------------
# PR #220 (Issue #213 TEST-WAKE-ENFORCE Layer 3) added the type:bug PR
# requirement for `cc:tester` + `needs-tester-signoff` at open. PM BLOCK verdict
# (cmt 4763243123) flagged that the step fires on every label change, not just
# `opened`. Owner merged anyway with override (per ADR-0031). ADR-0035 is the
# audit-trail follow-up closing the re-fire gap.
#
# Fix (per ADR-0035): add `if: github.event.action == 'opened'` (combined with
# existing `event_name == 'pull_request_target'`) to the Layer 3 step in
# `.github/workflows/label-check.yml`, so the type-driven invariant check
# fires only at PR open, not on subsequent label changes (tester sign-off,
# status:ready flip, etc).
#
# Test cases (5, per ADR-0035 §d026 regression test contract):
#   T1: Layer 3 step has `if:` condition
#   T2: Layer 3 if condition references github.event.action
#   T3: Layer 3 if condition allows ONLY `opened` (not labeled/unlabeled/reopened)
#   T4: Layer 3 if condition still preserves `event_name == 'pull_request_target'`
#        (Layer 3 must not fire on issues; only on PRs)
#   T5: workflow `on: pull_request_target:` still includes `opened` (otherwise
#        the action never reaches Layer 3 step)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d026-layer3-open-only-fire.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WF="$SCRIPT_DIR/../../.github/workflows/label-check.yml"

# Colors (TTY-aware)
if [[ -t 1 ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; B=$'\033[1m'; D=$'\033[0m'
else
  G=""; R=""; B=""; D=""; fi

PASS=0; FAIL=0
pass() { printf "  ${G}✓ PASS${D} — %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  ${R}✗ FAIL${D} — %s\n" "$1"; [ -n "${2:-}" ] && printf "    ${R}%s\n" "$2"; FAIL=$((FAIL+1)); }
section() { printf "\n${B}==== %s ====${D}\n" "$1"; }

if [ ! -r "$WF" ]; then
  echo "ERROR: label-check.yml not found at $WF" >&2; exit 127
fi

# Extract the Layer 3 step block (between "Layer 3 —" header and the next "- name:" at the same indent)
LAYER3_BLOCK="$(awk '/Layer 3 — type:bug/{flag=1} flag && !/^      - name: Layer 3/{print} /^      - name: Layer 3/ && NR>1 && !/type:bug/{flag=0}' "$WF" 2>/dev/null | head -50)"

if [ -z "$LAYER3_BLOCK" ]; then
  echo "ERROR: could not extract Layer 3 step block from $WF" >&2
  exit 127
fi

# ============================================================================
# T1: Layer 3 step has `if:` condition (open-only fire is gated)
# ============================================================================
section "T1: Layer 3 step has 'if:' condition"
if echo "$LAYER3_BLOCK" | grep -Eq '^\s*if:\s*github'; then
  pass "Layer 3 has 'if:' condition (gate present)"
else
  fail "Layer 3 missing 'if:' condition" "expected 'if: github.event.action =='\\''opened'\\'' ' in Layer 3 step"
fi

# ============================================================================
# T2: Layer 3 if condition references github.event.action
# ============================================================================
section "T2: Layer 3 if condition references github.event.action"
if echo "$LAYER3_BLOCK" | grep -Eq 'if:.*github\.event\.action'; then
  pass "Layer 3 if references github.event.action (open-only fire)"
else
  fail "Layer 3 if missing github.event.action" "expected 'if:' clause to include 'github.event.action' per ADR-0035"
fi

# ============================================================================
# T3: Layer 3 if condition allows ONLY `opened` (excludes labeled/unlabeled/reopened)
# ============================================================================
section "T3: Layer 3 if condition scopes to 'opened' only"
if echo "$LAYER3_BLOCK" | grep -Eq "if:.*github\.event\.action.*'opened'"; then
  pass "Layer 3 if scopes to 'opened' (excludes labeled/unlabeled/reopened)"
else
  fail "Layer 3 if not scoped to 'opened'" "expected 'opened' literal in 'if:' clause per ADR-0035 §Decision"
fi

# ============================================================================
# T4: Layer 3 if condition preserves event_name == 'pull_request_target'
# ============================================================================
section "T4: Layer 3 if condition preserves event_name == 'pull_request_target'"
if echo "$LAYER3_BLOCK" | grep -Eq "if:.*github\.event_name.*'pull_request_target'"; then
  pass "Layer 3 if still scopes to pull_request_target (Layer 3 doesn't fire on issues)"
else
  fail "Layer 3 if missing event_name check" "expected 'github.event_name =='\\''pull_request_target'\\'' ' in 'if:' clause — without it, Layer 3 would fire on issues too"
fi

# ============================================================================
# T5: workflow `on: pull_request_target:` includes `opened` action
# ============================================================================
section "T5: workflow 'on: pull_request_target:' triggers include 'opened'"
if grep -Eq "^on:" "$WF"; then
  # Extract lines from `on:` until the next top-level key
  ON_BLOCK="$(sed -n '/^on:/,/^[a-z]/p' "$WF" | head -20)"
  if echo "$ON_BLOCK" | grep -Eq "pull_request_target"; then
    if echo "$ON_BLOCK" | grep -A 4 "pull_request_target" | grep -Eq "opened"; then
      pass "pull_request_target: types includes 'opened' (Layer 3 can fire at PR open)"
    else
      fail "pull_request_target missing 'opened' trigger" "expected 'opened' in pull_request_target.types — without it, Layer 3 step would never run"
    fi
  else
    fail "pull_request_target trigger missing" "expected 'pull_request_target:' under on: in label-check.yml"
  fi
else
  fail "'on:' block missing" "expected 'on:' block at top of label-check.yml"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
