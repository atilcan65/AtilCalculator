#!/usr/bin/env bash
# d046-peer-poke-canonical-parity.sh — cross-soul canonical parity guard.
#
# Why this test exists
# --------------------
# Per docs/peer-poke-spec.md §Deliverable 2 + arch verdict Obs-2 (Issue #389):
# All 5 souls must reference the SAME canonical §Peer-Poke Discipline text +
# a DISTINCT per-soul context line. This d-test is the backstop that prevents
# drift across the 5 souls (e.g., one soul getting the wrong context line, or
# canonical text being paraphrased / abbreviated inconsistently).
#
# Sister references:
#   - docs/peer-poke-spec.md §Deliverable 2 (canonical text + context line table)
#   - ADR-0033 (dual-channel doctrine anchor)
#   - ADR-0015 (atomic handoff discipline — peer-poke complements, doesn't replace)
#   - Issue #389 (5-soul amendment tracker, owner-gated merge)
#   - Issue #398 (Stage 1 dispatch, dev-authored diff)
#
# Test cases:
#   T1: All 5 souls contain the §Peer-Poke Discipline subsection header
#   T2: All 5 souls contain the canonical preamble (complements/does NOT replace)
#   T3: All 5 souls contain the ADR-0033 anchor reference
#   T4: All 5 souls contain the canonical helper reference (scripts/peer-poke.sh)
#   T5: All 5 souls contain the forbidden-pattern warning (notify.sh -l <role>)
#   T6: All 5 souls contain the multi-role deferral note (Sprint 8+ P3)
#   T7: Each soul contains its UNIQUE per-soul context line (verbatim from spec)
#   T8: d296-peer-poke-helper.sh (the helper script test) still PASS (regression)
#
# Exit code: 0 = all pass, 1 = at least one fail.
# Run standalone: bash scripts/tests/d046-peer-poke-canonical-parity.sh

set -uo pipefail

# Path resolution: git rev-parse --show-toplevel is portable (per Issue #370 §T2 + d043).
REPO_ROOT="$(git rev-parse --show-toplevel)"
SOULS_DIR="$REPO_ROOT/.claude/agents"

if [ ! -d "$SOULS_DIR" ]; then
  echo "ERROR: .claude/agents/ not found at $SOULS_DIR" >&2
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

# ============================================================================
# T1: All 5 souls contain the §Peer-Poke Discipline subsection header
# ============================================================================
section "T1: All 5 souls contain §Peer-Poke Discipline subsection header"
SOULS=(product-manager architect developer tester orchestrator)
MISSING_HEADER=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    MISSING_HEADER+=("$SOUL_FILE (file missing)")
    continue
  fi
  if ! grep -qE '^### §Peer-Poke Discipline — Dual-Channel Auto-Ping' "$SOUL_FILE"; then
    MISSING_HEADER+=("$SOUL.md")
  fi
done
if [ "${#MISSING_HEADER[@]}" -eq 0 ]; then
  pass "all 5 souls have §Peer-Poke Discipline subsection header"
else
  fail "souls missing §Peer-Poke Discipline header" "${MISSING_HEADER[*]}"
fi

# ============================================================================
# T2: All 5 souls contain the canonical preamble (complements/does NOT replace)
# ============================================================================
section "T2: All 5 souls contain canonical preamble (complements Handoff Label Discipline)"
PREAMBLE_PATTERN='complements (does NOT replace) Handoff Label Discipline'
MISSING_PREAMBLE=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    MISSING_PREAMBLE+=("$SOUL_FILE (file missing)")
    continue
  fi
  if ! grep -qF "$PREAMBLE_PATTERN" "$SOUL_FILE"; then
    MISSING_PREAMBLE+=("$SOUL.md")
  fi
done
if [ "${#MISSING_PREAMBLE[@]}" -eq 0 ]; then
  pass "all 5 souls have canonical preamble"
else
  fail "souls missing canonical preamble" "${MISSING_PREAMBLE[*]}"
fi

# ============================================================================
# T3: All 5 souls contain the ADR-0033 anchor reference
# ============================================================================
section "T3: All 5 souls reference ADR-0033 (dual-channel doctrine anchor)"
MISSING_ADR=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    MISSING_ADR+=("$SOUL_FILE (file missing)")
    continue
  fi
  if ! grep -qF "ADR-0033" "$SOUL_FILE"; then
    MISSING_ADR+=("$SOUL.md")
  fi
done
if [ "${#MISSING_ADR[@]}" -eq 0 ]; then
  pass "all 5 souls reference ADR-0033"
else
  fail "souls missing ADR-0033 reference" "${MISSING_ADR[*]}"
fi

# ============================================================================
# T4: All 5 souls contain the canonical helper reference (scripts/peer-poke.sh)
# ============================================================================
section "T4: All 5 souls reference scripts/peer-poke.sh as canonical helper"
MISSING_HELPER=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    MISSING_HELPER+=("$SOUL_FILE (file missing)")
    continue
  fi
  if ! grep -qF "scripts/peer-poke.sh" "$SOUL_FILE"; then
    MISSING_HELPER+=("$SOUL.md")
  fi
done
if [ "${#MISSING_HELPER[@]}" -eq 0 ]; then
  pass "all 5 souls reference scripts/peer-poke.sh"
else
  fail "souls missing scripts/peer-poke.sh reference" "${MISSING_HELPER[*]}"
fi

# ============================================================================
# T5: All 5 souls contain the forbidden-pattern warning (notify.sh -l <role>)
# ============================================================================
section "T5: All 5 souls warn against legacy notify.sh -l <role> footgun"
FORBIDDEN_PATTERN='scripts/notify.sh -l <role>'
MISSING_WARN=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    MISSING_WARN+=("$SOUL_FILE (file missing)")
    continue
  fi
  if ! grep -qF "$FORBIDDEN_PATTERN" "$SOUL_FILE"; then
    MISSING_WARN+=("$SOUL.md")
  fi
done
if [ "${#MISSING_WARN[@]}" -eq 0 ]; then
  pass "all 5 souls warn against legacy notify.sh -l <role> pattern"
else
  fail "souls missing forbidden-pattern warning" "${MISSING_WARN[*]}"
fi

# ============================================================================
# T6: All 5 souls contain the multi-role deferral note (Sprint 8+ P3)
# ============================================================================
section "T6: All 5 souls note multi-role broadcast deferral (Sprint 8+ P3)"
DEFER_NOTE='Sprint 8+ P3 (multi-role helper)'
MISSING_DEFER=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    MISSING_DEFER+=("$SOUL_FILE (file missing)")
    continue
  fi
  if ! grep -qF "$DEFER_NOTE" "$SOUL_FILE"; then
    MISSING_DEFER+=("$SOUL.md")
  fi
done
if [ "${#MISSING_DEFER[@]}" -eq 0 ]; then
  pass "all 5 souls defer multi-role broadcasts (Sprint 8+ P3 helper)"
else
  fail "souls missing multi-role deferral note" "${MISSING_DEFER[*]}"
fi

# ============================================================================
# T7: Each soul contains its UNIQUE per-soul context line (verbatim from spec)
# ============================================================================
section "T7: Each soul contains its UNIQUE per-soul context line (verbatim from spec)"
declare -A CONTEXT_LINES=(
  [product-manager]="You ping @architect for design alignment and @orchestrator for scope/sprint decisions"
  [architect]="You ping @developer after PR design review"
  [developer]="You ping @tester when opening PR"
  [tester]="You ping @developer on CHANGES REQUESTED"
  [orchestrator]="Default to \`peer-poke.sh\` for all 1:1 peer handoffs"
)
WRONG_CONTEXT=()
for SOUL in "${SOULS[@]}"; do
  SOUL_FILE="$SOULS_DIR/$SOUL.md"
  if [ ! -f "$SOUL_FILE" ]; then
    WRONG_CONTEXT+=("$SOUL_FILE (file missing)")
    continue
  fi
  EXPECTED="${CONTEXT_LINES[$SOUL]}"
  if ! grep -qF "$EXPECTED" "$SOUL_FILE"; then
    WRONG_CONTEXT+=("$SOUL.md (expected: '$EXPECTED')")
  fi
done
if [ "${#WRONG_CONTEXT[@]}" -eq 0 ]; then
  pass "all 5 souls contain their UNIQUE per-soul context line (verbatim)"
else
  fail "souls with wrong/missing context line" "${WRONG_CONTEXT[*]}"
fi

# ============================================================================
# T8: d296-peer-poke-helper.sh (the helper script test) still PASS (regression)
# ============================================================================
section "T8: d296-peer-poke-helper.sh regression — sister test still green"
if [ -x "$REPO_ROOT/scripts/tests/d296-peer-poke-helper.sh" ]; then
  if bash "$REPO_ROOT/scripts/tests/d296-peer-poke-helper.sh" >/dev/null 2>&1; then
    pass "d296-peer-poke-helper.sh still PASS (sister test regression)"
  else
    fail "d296-peer-poke-helper.sh FAIL — sibling-script regression detected"
  fi
elif [ -f "$REPO_ROOT/scripts/tests/d296-peer-poke-helper.sh" ]; then
  if bash "$REPO_ROOT/scripts/tests/d296-peer-poke-helper.sh" >/dev/null 2>&1; then
    pass "d296-peer-poke-helper.sh still PASS (sister test regression)"
  else
    fail "d296-peer-poke-helper.sh FAIL — sibling-script regression detected"
  fi
else
  echo "  ${B}⊘ SKIP${D} — d296-peer-poke-helper.sh not found (sister test absent in this environment)"
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
echo "  Reference: docs/peer-poke-spec.md §Deliverable 2, ADR-0033, ADR-0015,"
echo "             Issue #389 (5-soul amendment tracker), Issue #398 (Stage 1 dispatch)."
echo "  Sister regressions: d296-peer-poke-helper.sh (PR #383 SHIPPED)."
exit 0