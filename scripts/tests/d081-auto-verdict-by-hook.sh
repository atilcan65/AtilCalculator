#!/usr/bin/env bash
# d081-auto-verdict-by-hook.sh — Issue #681 + ADR-0024 amendment d-test (Auto-Verdict-By Hook).
#
# Why this test exists
# --------------------
# PR #679 LIVE INSTANCE (cycle ~#1135): tester-authored PR opened with 4 `cc:*` labels
# (cc:orchestrator, cc:architect, cc:developer, cc:human) but ZERO `verdict-by:<ts>` labels.
# ADR-0024 §Schema additions REQUIRES every `cc:<peer>` to be paired with `verdict-by:<ts>`;
# the convention is documented but not enforced at the agent-action layer.
#
# Sister-pattern to d077 (P0 BUG #675 — L5 misfire regression) + d078 (Issue #680 + PR #683
# initial-add defensive guard). Both use --self-test + bash + grep regression-guard contract.
#
# 5 TCs (per ADR-0044 RED-first + ADR-0024 amendment §Follow-up tickets):
#   TC1: Layer 5 auto-inject hook present in label-check.yml — `cc:*` label-add event
#        triggers `addLabels(['verdict-by:<ts>'])` in same workflow step
#   TC2: Agent-side peer-poke.sh auto-pair helper present — bash function that adds
#        paired `verdict-by:<ts>` on `cc:<peer>` invocation
#   TC3: Atomic pairing doctrine (ADR-0015) — verdict-by added in SAME `gh issue edit`
#        invocation as `cc:*` (defensive grep: paired add within single bash function)
#   TC4: Default deadline = PR creation + 24h (configurable via VERDICT_BY_DEFAULT_HOURS
#        env var) — present in both Layer 5 hook AND peer-poke.sh helper
#   TC5: Silent-skip idempotency — if `verdict-by:<ts>` already present, hook MUST NOT
#        overwrite (no double-deadline, no race-overwrite pathology)
#
# Issue #714 (d081 TC6+TC7 sister) + Issue #713 (TC8 regression guard):
#   TC6: PR-payload shape branching — `isPR ? context.payload.pull_request : context.payload.issue`
#        ternary must be present (PR events populate pull_request, not issue)
#   TC7: Issue-payload shape branching (defensive cross-check) — same ternary must
#        reference BOTH pull_request AND issue (sister-pattern to TC6)
#   TC8: peerLabel accessor uses `context.payload.label.name` (or `github.event.label.name`),
#        NOT `context.event.label.name` (regression guard for L189 bug per Issue #713)
#
# Pre-impl RED state (current main as of 2026-06-29, c006b2a):
#   - Layer 5 auto-inject hook: ABSENT (label-check.yml references verdict-by in comments only)
#   - peer-poke.sh auto-pair helper: ABSENT (peer-poke.sh is a thin notify.sh wrapper)
#   - Atomic pairing doctrine in single invocation: ABSENT
#   - VERDICT_BY_DEFAULT_HOURS env var: ABSENT
#   - Silent-skip idempotency check: ABSENT
# → All 5 TCs FAIL in RED state per ADR-0044.
#
# Post-impl GREEN state (after ADR-0024 amendment impl lands in label-check.yml + peer-poke.sh):
#   - All 5 structural checks PASS
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d077 (Issue #675 P0 BUG, L5 misfire — base sister)
#   - d078 (Issue #680, L5 initial-add defensive guard — sister cycle #680+681)
#   - d069 (L5 verdict-emoji gate — sibling defense layer)
#   - d055 (Layer 5 idempotent DELETE — initial-add DELETE defensive guard pattern)
#   - d015 (dev-idle prevention Katman 1+2 — no self-standby sister)
#
# Usage:
#   bash d081-auto-verdict-by-hook.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — auto-verdict-by hook landed in both layers)
#   1 — at least one FAIL (RED state — hook missing in one or both layers)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABEL_CHECK="${REPO_ROOT}/.github/workflows/label-check.yml"
PEER_POKE="${REPO_ROOT}/scripts/peer-poke.sh"

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

# Pre-flight
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
command -v grep >/dev/null 2>&1 || { echo "ERROR: grep required" >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo "ERROR: awk required" >&2; exit 2; }

if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: $0 --self-test" >&2
  exit 2
fi

printf "${B}d081 self-test (5 TCs per Issue #681 + ADR-0024 Auto-Verdict-By Hook, ADR-0044 RED-first)${D}\n"
printf "${B}========================================================================${D}\n"
printf "  Layer 5 under test:  %s\n" "$LABEL_CHECK"
printf "  Agent-side under test: %s\n" "$PEER_POKE"
printf "  Sister-pattern:      d077 (L5 misfire) + d078 (initial-add defensive guard)\n"
printf "  RED-first:           pre-#686-impl all 5 TCs FAIL.\n"
printf "  Post-impl:           all 5 TCs must PASS.\n\n"

if [ ! -f "$LABEL_CHECK" ]; then
  fail "preflight — label-check.yml missing" "expected $LABEL_CHECK"
  exit 2
fi

if [ ! -f "$PEER_POKE" ]; then
  fail "preflight — peer-poke.sh missing" "expected $PEER_POKE"
  exit 2
fi

# ============================================================================
# TC1: Layer 5 auto-inject hook present in label-check.yml
# ============================================================================
section "TC1: Layer 5 auto-inject hook in label-check.yml"

# Look for: workflow yaml code that auto-adds a verdict-by:<ts> label when a
# cc:* label event fires. Pattern: 'verdict-by' string within github-script
# code (addLabels, issues.addLabel, or autoInject) — must be in code, not just
# a doc comment.
#
# RED-FIRST signature: PASS only if the hook code exists in the workflow
# primary step. A comment-only reference (e.g., "ADR-0024 watchdog" docstring)
# is INSUFFICIENT — we grep for an actual addLabel call referencing verdict-by.

# Extract github-script code blocks: lines between `script: |` and end of
# indented block. Then search for verdict-by + addLabel/auto-inject pattern.
HOOK_FOUND=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "verdict-by" || true)

# A code-level reference must be present. Exclude pure doc comments.
# Refined check: look for the addLabel call pattern with verdict-by.
HOOK_CALL=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "addLabel.*verdict-by|verdict-by.*addLabel|issues\.addLabel.*verdict" || true)

if [ "$HOOK_CALL" -ge 1 ]; then
  pass "TC1 — Layer 5 auto-inject hook present in label-check.yml (verdict-by addLabel call: $HOOK_CALL occurrence(s))"
else
  fail "TC1 — Layer 5 auto-inject hook ABSENT in label-check.yml" "expected addLabel call referencing verdict-by: in github-script code (see ADR-0024 amendment §Path 1)"
fi

# ============================================================================
# TC2: Agent-side peer-poke.sh auto-pair helper present
# ============================================================================
section "TC2: peer-poke.sh auto-pair helper"

# Look for: bash function or inline code in peer-poke.sh that adds paired
# verdict-by:<ts> label via gh issue edit when invoked. Pattern: 'verdict-by'
# + 'gh issue edit' OR 'gh pr edit' + 'add-label' within peer-poke.sh.

PEER_POKE_VERDICT=$(grep -cE "verdict-by" "$PEER_POKE" || true)
PEER_POKE_PAIR=$(grep -cE "verdict-by.*add-label|add-label.*verdict-by|gh (issue|pr) edit.*verdict-by" "$PEER_POKE" || true)

if [ "$PEER_POKE_VERDICT" -ge 1 ] && [ "$PEER_POKE_PAIR" -ge 1 ]; then
  pass "TC2 — peer-poke.sh auto-pair helper present (verdict-by refs: $PEER_POKE_VERDICT, add-label pair: $PEER_POKE_PAIR)"
else
  fail "TC2 — peer-poke.sh auto-pair helper ABSENT" "expected verdict-by + add-label pair invocation in peer-poke.sh (see ADR-0024 amendment §Path 2)"
fi

# ============================================================================
# TC3: Atomic pairing doctrine — verdict-by in SAME gh invocation as cc:*
# ============================================================================
section "TC3: Atomic pairing doctrine (ADR-0015)"

# Per ADR-0015 §Sıra zorunlu, paired labels must be added in the SAME
# `gh issue edit N --add-label ...` invocation. Defensive grep: a single
# `gh issue edit` (or `gh pr edit`) call with BOTH a `cc:*` reference AND
# a `verdict-by:*` reference in one command.

# Check label-check.yml primary step JS for paired addLabel
ATOMIC_L5=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "addLabel.*cc:.*verdict-by|addLabel.*verdict-by.*cc:|labels:.*\[.*cc:.*verdict-by|labels:.*\[.*verdict-by.*cc:" || true)

# Check peer-poke.sh for paired gh issue edit
ATOMIC_PP=$(grep -cE "gh (issue|pr) edit.*--add-label.*cc:.*verdict-by|gh (issue|pr) edit.*--add-label.*verdict-by.*cc:" "$PEER_POKE" || true)

if [ "$ATOMIC_L5" -ge 1 ] || [ "$ATOMIC_PP" -ge 1 ]; then
  WHICH="L5=$ATOMIC_L5, peer-poke=$ATOMIC_PP"
  pass "TC3 — atomic pairing doctrine observed ($WHICH)"
else
  fail "TC3 — atomic pairing doctrine NOT observed" "expected paired addLabel (cc:* + verdict-by:*) in same invocation per ADR-0015"
fi

# ============================================================================
# TC4: Default deadline = PR creation + 24h (VERDICT_BY_DEFAULT_HOURS)
# ============================================================================
section "TC4: Default deadline (VERDICT_BY_DEFAULT_HOURS = 24h)"

# Look for: VERDICT_BY_DEFAULT_HOURS env var or constant in EITHER layer.
# Pattern: 'VERDICT_BY_DEFAULT_HOURS' (case-sensitive) OR '24' near
# 'verdict-by' string.

# label-check.yml primary step
DEFAULT_L5=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "VERDICT_BY_DEFAULT_HOURS|verdict-by.*\+24|\+24.*verdict-by" || true)

# peer-poke.sh
DEFAULT_PP=$(grep -cE "VERDICT_BY_DEFAULT_HOURS|verdict-by.*\+24|\+24.*verdict-by" "$PEER_POKE" || true)

if [ "$DEFAULT_L5" -ge 1 ] || [ "$DEFAULT_PP" -ge 1 ]; then
  WHICH="L5=$DEFAULT_L5, peer-poke=$DEFAULT_PP"
  pass "TC4 — default deadline constant present ($WHICH)"
else
  fail "TC4 — default deadline constant ABSENT" "expected VERDICT_BY_DEFAULT_HOURS=24 (or +24h) reference in label-check.yml or peer-poke.sh"
fi

# ============================================================================
# TC5: Silent-skip idempotency — no overwrite if verdict-by already present
# ============================================================================
section "TC5: Silent-skip idempotency (no double-deadline overwrite)"

# Look for: explicit check that skips verdict-by injection if label already
# present. Pattern: 'if' + 'verdict-by' + ('return' OR 'continue' OR 'skip')
# OR a 'hasLabel' / 'labels.find' / 'labels.some' style presence check.

# TC5 looks for a verdict-by-SPECIFIC idempotency guard, not a generic
# silent_skip (which already exists in label-check.yml from prior amendments
# like d076/d077). The guard must check whether a verdict-by:<ts> label
# already exists on the issue/PR before auto-injecting a second one.
#
# Acceptable patterns:
#   - `labels.some(l => l.name.startsWith('verdict-by:'))` (JS presence check)
#   - `labels.find(...)` returning verdict-by before addLabel call
#   - `gh issue view ... | grep -q verdict-by` (bash presence check)
#   - `if (existingVerdictBy) return;` (early-return guard)
#   - `silent_skip` log line that references verdict-by specifically

# label-check.yml primary step — verdict-by-specific guard
IDEMPOTENT_L5=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "labels\.some.*verdict-by|labels\.find.*verdict-by|hasLabel.*verdict-by|startsWith.*verdict-by|verdict-by.*already|already.*verdict-by|existingVerdict|verdictByExists" || true)

# peer-poke.sh — verdict-by-specific guard
IDEMPOTENT_PP=$(grep -cE "gh (issue|pr) view.*\\| grep.*verdict-by|grep -q.*verdict-by|\\[.*verdict-by.*\\] && exit 0|verdict-by.*already" "$PEER_POKE" || true)

# Also accept: a silent_skip log line that references verdict-by specifically
SILENT_SKIP_VERDICT=$(grep -E "silent_skip|silent-skip" "$PEER_POKE" "$LABEL_CHECK" 2>/dev/null | grep -cE "verdict-by" || true)

if [ "$IDEMPOTENT_L5" -ge 1 ] || [ "$IDEMPOTENT_PP" -ge 1 ] || [ "$SILENT_SKIP_VERDICT" -ge 1 ]; then
  WHICH="L5-guard=$IDEMPOTENT_L5, peer-poke-guard=$IDEMPOTENT_PP, silent-skip-verdict=$SILENT_SKIP_VERDICT"
  pass "TC5 — silent-skip idempotency present ($WHICH)"
else
  fail "TC5 — silent-skip idempotency ABSENT" "expected verdict-by-specific guard (labels.some/find/hasLabel/startsWith OR gh view+grep OR silent_skip line referencing verdict-by)"
fi

# ============================================================================
# TC6: PR-payload shape branching (Issue #714, PR #712 LIVE INSTANCE)
# ============================================================================
section "TC6: PR-payload shape branching (PR events)"

# Per Issue #714: PR events populate `context.payload.pull_request`, NOT
# `context.payload.issue`. The Auto-Verdict-By hook must branch on isPR
# to read the correct payload field. The broken pattern (no branching)
# causes TypeError: Cannot read properties of undefined (reading 'labels').
#
# Probe: grep for the isPR ternary that selects between pull_request and issue.
# Pattern: `isPR ? context.payload.pull_request : context.payload.issue` OR
# equivalent variant.
#
# Reference: Issue #713 body — the Live Instance observation at PR #712
# (run 28436203805) shows the Auto-Verdict-By hook crashed on PR events
# because the ternary was missing in early PR #688 iterations. Even after
# PR #688 added the ternary, the L189 `context.event.label.name` bug
# persisted (context.event is the event NAME, not the payload).
PR_PAYLOAD_TERNARY=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "isPR\s*\?.*pull_request.*issue|context\.payload\.(pull_request|issue)" || true)

if [ "$PR_PAYLOAD_TERNARY" -ge 1 ]; then
  pass "TC6 — PR-payload ternary branching present (refs: $PR_PAYLOAD_TERNARY occurrence(s))"
else
  fail "TC6 — PR-payload ternary branching ABSENT" "expected 'isPR ? context.payload.pull_request : context.payload.issue' (or equivalent) in github-script code per Issue #714"
fi

# ============================================================================
# TC7: Issue-payload shape branching (Issue #714 sister-pattern)
# ============================================================================
section "TC7: Issue-payload shape branching (Issue events, defensive cross-check)"

# Sister-pattern cross-check: same ternary structure must handle issue events
# cleanly. While the current action filter (L177) restricts the hook to
# `pull_request_target` events only, the ternary code at L186-187 is the
# load-bearing defense if the action filter is ever relaxed or removed.
# This TC ensures the branching is symmetrical and defensive.
#
# Probe: the same ternary structure is present and references BOTH pull_request
# AND issue (not just one).
ISSUE_PAYLOAD_BRANCH=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "context\.payload\.(pull_request|issue)" || true)

if [ "$ISSUE_PAYLOAD_BRANCH" -ge 2 ]; then
  pass "TC7 — Issue-payload branch present (defensive, refs: $ISSUE_PAYLOAD_BRANCH occurrence(s))"
else
  fail "TC7 — Issue-payload branch absent or insufficient" "expected both pull_request AND issue payload references (sister-pattern cross-check per Issue #714)"
fi

# ============================================================================
# TC8: peerLabel accessor uses payload (not context.event.name)
# ============================================================================
section "TC8: peerLabel accessor uses payload.label.name (regression guard for L189 bug)"

# Per Issue #713 + tester REJECTED verdict cmt 4842848410: the original L189
# code was `const peerLabel = context.event.label.name;`. This is BROKEN
# because `context.event` is the event NAME (a string like 'pull_request_target'),
# NOT the payload. The correct accessor is `context.payload.label.name` (or
# equivalently `github.event.label.name` since github.event aliases the payload).
#
# Probe: must use `context.payload.label.name` OR `github.event.label.name`.
# Anti-probe: must NOT use `context.event.label.name` (the broken pattern).
#
# Reference: label-check.yml L177 action filter uses `github.event.label.name`
# (correct). L189 body should match the same accessor.

CORRECT_ACCESSOR=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "peerLabel\s*=\s*(context\.payload\.label\.name|github\.event\.label\.name)" || true)

BROKEN_ACCESSOR=$(awk '
  /^[[:space:]]*script:[[:space:]]*\|/ { in_script=1; next }
  in_script && /^[[:space:]]{6,}[^[:space:]]/ { in_script=0 }
  in_script { print }
' "$LABEL_CHECK" | grep -cE "peerLabel\s*=\s*context\.event\.label\.name" || true)

if [ "$CORRECT_ACCESSOR" -ge 1 ] && [ "$BROKEN_ACCESSOR" -eq 0 ]; then
  pass "TC8 — peerLabel accessor uses payload.label.name (correct=$CORRECT_ACCESSOR, broken=$BROKEN_ACCESSOR)"
else
  fail "TC8 — peerLabel accessor BROKEN or wrong" "expected peerLabel = context.payload.label.name (or github.event.label.name); got correct=$CORRECT_ACCESSOR, broken=$BROKEN_ACCESSOR. Fix: change label-check.yml L189 from context.event.label.name to context.payload.label.name"
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: ${G}%d${D}\n" "$PASS"
printf "  FAIL: ${R}%d${D}\n" "$FAIL"
printf "  INFO: ${Y}%d${D}\n" "$INFO"

if [ "$FAIL" -eq 0 ]; then
  printf "\n${G}✓ GREEN state${D} — auto-verdict-by hook landed in both layers (label-check.yml + peer-poke.sh)\n"
  exit 0
else
  printf "\n${R}✗ RED state${D} — auto-verdict-by hook missing in one or more layers (pre-impl per ADR-0044 RED-first)\n"
  printf "  Fix candidates:\n"
  printf "    1. Add Layer 5 hook in label-check.yml (~15 LoC yaml, sister-pattern to d069 verdict-emoji gate)\n"
  printf "    2. Add peer-poke.sh auto-pair helper (~10 LoC bash, layered defense)\n"
  printf "    3. See ADR-0024 amendment §Path D (BOTH paths, layered defense)\n"
  exit 1
fi
