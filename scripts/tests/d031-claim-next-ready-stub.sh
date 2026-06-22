#!/usr/bin/env bash
# d031-claim-next-ready-stub.sh — regression test for #276
# (Stub script that exits gracefully until Sprint 5 Layer 2 impl lands)
#
# Why this test exists
# --------------------
# Issue #276 (Design-Drift, 2026-06-22T19:36Z): PR #275 soul patch added
# §Auto-Claim Protocol hooks to all 4 agent soul files. The hooks invoke
# `bash scripts/claim-next-ready.sh <role>` but the actual impl is Sprint 5
# deferred (Issue #271, 1.5 SP). Without this stub, every agent's hook fails.
#
# The stub makes the hook succeed (exit 0) while clearly logging the deferral.
# This test verifies the stub contract:
#   T1:  scripts/claim-next-ready.sh exists + executable
#   T2:  Stub exits 0 with no args? No — exits 2 (usage error). WITH valid role, exits 0.
#   T3:  Stub exits 2 on missing role argument
#   T4:  Stub exits 2 on invalid role
#   T5:  Stub output contains "STUB" + "Sprint 5" markers
#   T6:  Stub is idempotent (calling twice produces same result, no state)
#   T7:  Stub has no side effects (no gh CLI, no notify.sh, no label edits)
#   T8:  Stub validates role enum
#   T9:  Stub honors all 5 expected roles (orchestrator/product-manager/architect/developer/tester)
#   T10: Stub does NOT create auto-claim.log (audit log path is reserved for full impl)
#
# Exit code: 0 = all pass, 1 = at least one fail.
#
# Run standalone: bash scripts/tests/d031-claim-next-ready-stub.sh
#
# When Sprint 5 Layer 2 lands (Issue #271), this test should be REPLACED with
# d031-claim-next-ready.sh per ADR-0038 §d031 spec (5 TCs covering priority
# sort, age tie-break, dep parser, WIP cap, negative case).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAIM_SH="$REPO_ROOT/scripts/claim-next-ready.sh"
AUDIT_LOG="/var/log/dev-studio/AtilCalculator/auto-claim.log"

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

# ============================================================================
section "T1: scripts/claim-next-ready.sh exists + executable"
if [ -f "$CLAIM_SH" ] && [ -x "$CLAIM_SH" ]; then
  pass "stub exists and is executable"
else
  fail "stub missing or not executable" "expected: scripts/claim-next-ready.sh (-x bit set) — Issue #276 Path B"
fi

# ============================================================================
section "T2: Stub exits 0 with valid role argument"
if [ -x "$CLAIM_SH" ]; then
  output="$("$CLAIM_SH" developer 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "stub exits 0 with valid role"
  else
    fail "stub exit code != 0 with valid role" "got exit $rc, expected 0 — Issue #276 Path B contract"
  fi
else
  fail "stub not executable — T2 cannot run" "expected: chmod +x scripts/claim-next-ready.sh"
fi

# ============================================================================
section "T3: Stub exits 2 on missing role argument"
if [ -x "$CLAIM_SH" ]; then
  output="$("$CLAIM_SH" 2>&1)"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    pass "stub exits 2 on missing role (usage error)"
  else
    fail "stub exit code != 2 on missing role" "got exit $rc, expected 2 (usage error)"
  fi
fi

# ============================================================================
section "T4: Stub exits 2 on invalid role"
if [ -x "$CLAIM_SH" ]; then
  output="$("$CLAIM_SH" invalid-role 2>&1)"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    pass "stub exits 2 on invalid role"
  else
    fail "stub exit code != 2 on invalid role" "got exit $rc, expected 2 (validation error)"
  fi
fi

# ============================================================================
section "T5: Stub output contains STUB + Sprint 5 markers"
if [ -x "$CLAIM_SH" ]; then
  output="$("$CLAIM_SH" developer 2>&1)"
  if echo "$output" | grep -q "STUB" && echo "$output" | grep -q "Sprint 5"; then
    pass "stub output contains STUB + Sprint 5 markers"
  else
    fail "stub output missing markers" "expected: output contains both 'STUB' and 'Sprint 5' — observability for ops"
  fi
fi

# ============================================================================
section "T6: Stub is idempotent (no state between calls)"
if [ -x "$CLAIM_SH" ]; then
  out1="$("$CLAIM_SH" developer 2>&1)"
  out2="$("$CLAIM_SH" developer 2>&1)"
  if [ "$out1" = "$out2" ]; then
    pass "stub produces identical output across calls (idempotent)"
  else
    fail "stub output varies between calls" "expected: same output every call (no random/state elements)"
  fi
fi

# ============================================================================
section "T7: Stub has no side effects (no gh, no notify, no label edits)"
if [ -f "$CLAIM_SH" ]; then
  has_gh=false
  has_notify=false
  has_label_edit=false
  grep -Eq '\bgh\b' "$CLAIM_SH" && has_gh=true
  grep -Eq '\bnotify\.sh\b' "$CLAIM_SH" && has_notify=true
  grep -Eq 'gh issue edit|--add-label|--remove-label' "$CLAIM_SH" && has_label_edit=true

  if ! $has_gh && ! $has_notify && ! $has_label_edit; then
    pass "stub has no gh/notify/label-edit side effects (pure log + exit)"
  else
    fail_lines=""
    $has_gh && fail_lines+="contains 'gh' CLI call"$'\n'
    $has_notify && fail_lines+="contains 'notify.sh' call"$'\n'
    $has_label_edit && fail_lines+="contains label edit"$'\n'
    fail "stub has side effects" "expected: pure log + exit 0 (no side effects) — $fail_lines"
  fi
fi

# ============================================================================
section "T8: Stub validates role enum (5 expected roles)"
if [ -x "$CLAIM_SH" ]; then
  valid_roles=("orchestrator" "product-manager" "architect" "developer" "tester")
  all_pass=true
  for role in "${valid_roles[@]}"; do
    "$CLAIM_SH" "$role" >/dev/null 2>&1 || all_pass=false
  done
  if $all_pass; then
    pass "stub accepts all 5 expected roles"
  else
    fail "stub rejects valid role" "expected: all 5 roles accepted (orchestrator|product-manager|architect|developer|tester)"
  fi
fi

# ============================================================================
section "T9: Stub output includes the role name (observability)"
if [ -x "$CLAIM_SH" ]; then
  output="$("$CLAIM_SH" tester 2>&1)"
  if echo "$output" | grep -q "Role=tester"; then
    pass "stub output includes the role name"
  else
    fail "stub output missing role name" "expected: output includes 'Role=<arg>' for log grep-ability"
  fi
fi

# ============================================================================
section "T10: Stub does NOT create auto-claim.log (reserved for Sprint 5)"
# Per ADR-0038 §Layer 2: audit log path is /var/log/dev-studio/<project>/auto-claim.log
# The STUB must not write to this path — that's reserved for the full impl.
if [ -x "$CLAIM_SH" ]; then
  rm -f "$AUDIT_LOG" 2>/dev/null || true
  "$CLAIM_SH" developer >/dev/null 2>&1
  if [ ! -f "$AUDIT_LOG" ]; then
    pass "stub does NOT create auto-claim.log (correct — reserved for Sprint 5 full impl)"
  else
    fail "stub created auto-claim.log" "expected: STUB does NOT write audit log (that's Sprint 5 Layer 2 impl's job)"
    rm -f "$AUDIT_LOG" 2>/dev/null || true
  fi
fi

# ============================================================================
printf "\n${B}==== SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "Issue #276 REGRESSION FAILED — claim-next-ready.sh STUB contract violated."
  echo "Fix: ensure stub exits 0 with valid role, exits 2 on bad args, has no side effects."
  exit 1
fi
echo
echo "Issue #276 REGRESSION PASS — claim-next-ready.sh STUB contract honored."
echo "Note: When Sprint 5 Layer 2 lands (Issue #271), replace this test with d031-claim-next-ready.sh"
echo "      covering priority sort + age tie-break + dep parser + WIP cap + negative case."
exit 0