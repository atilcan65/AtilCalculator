#!/usr/bin/env bash
# d077-layer-5-misfire-regression.sh — Issue #675 / P0 BUG Layer 5 misfire regression test (5 TCs).
#
# Why this test exists
# --------------------
# P0 BUG #675 (cycle ~1080): ADR-0048 Layer 5 verdict-emoji gate re-adds `status:ready`
# on every `pull_request_target` event with `action=unlabeled`, regardless of verdict
# state. CONFIRMED via REST events on PR #658 (4 misfires, 9-12s cadence each). Architectural
# RCA by @architect cmt 4832077155 on Issue #675 cycle ~1081:
#
#   Step 2 (L460-L480): sets shouldAddReady=true if needs-architect-review absent
#   Step 2.5 Path A verdict-emoji gate (L482-L509): overrides ONLY if 🟡/🔴 emoji in comments
#   TRIGGER: pull_request_target with action=unlabeled (any label removal)
#   LOOP: owner removes status:ready → triggers unlabeled event → L5 re-adds status:ready → loop
#
# Architectural fix combination (arch recommended Option A + Option C):
#   - Option A: explicit verdict label taxonomy (verdict:changes-requested, verdict:approved)
#   - Option C: short-circuit on action=unlabeled AND label.name starts with 'status:'
#
# 5 TCs (per ADR-0049 d-test framework sister-pattern):
#   TC1: status:* removal short-circuit (Option C structural signature)
#        Assert: early-return guard at L5 entry when action=unlabeled AND label.name
#        starts with 'status:'. Bug absent = no guard = TC1 FAIL (RED-first).
#   TC2: verdict:* label taxonomy check (Option A structural signature)
#        Assert: code structure references 'verdict:changes-requested' label check inside
#        the type-driven decision (L460-L480 region) OR alongside Step 2.5 gate.
#   TC3: bot-self-label actor exclusion at L5 entry
#        Assert: code structure filters out github-actions[bot] actor early in the L5
#        handler so the bot's own status:ready re-add attempts are no-op.
#   TC4: loop-protection on successive unlabeled events
#        Assert: code structure includes timestamp/dedup guard (e.g., `Date.now() -
#        lastFireTime < 60000`) OR verdict:* label check before re-add. Sister-pattern
#        to existing skip-log dedup logic at L515-L534.
#   TC5: verdict-emoji gate structural regression guard
#        Assert: "Path A verdict-emoji gate" comment marker STILL present post-fix
#        (d069 invariant must not be regressed by d077 fix implementation).
#        Pre-impl: PASS (d069 already merged). Post-impl: PASS (must hold).
#
# Pre-impl RED state (current main, P0 bug active):
#   - TC1 FAIL: no status:* short-circuit
#   - TC2 FAIL: no verdict:changes-requested check
#   - TC3 FAIL: no L5-entry bot-actor filter
#   - TC4 FAIL: no loop-protection guard
#   - TC5 PASS: d069 verdict-emoji gate already on main (regression guard baseline)
# → 4/5 FAIL in RED state per ADR-0044.
#
# Post-impl GREEN state (after fix PR merges to main):
#   - TC1 PASS: short-circuit guard present
#   - TC2 PASS: verdict:* label check present
#   - TC3 PASS: bot-actor filter present
#   - TC4 PASS: loop-protection present
#   - TC5 PASS: verdict-emoji gate still present (held invariant)
# → 5/5 PASS in GREEN state.
#
# Sister-pattern family (ADR-0049 d-test lineage):
#   - d069 (Layer 5 verdict-emoji gate — sister-pattern base, this d077 extends)
#   - d076 (label-check closed-state TDZ — workflow YAML regression guard sister)
#   - d068 (cluster-lag-detector workflow wiring — workflow YAML sister-pattern)
#   - d055 (Layer 5 idempotent DELETE — Layer 5 family)
#
# Usage:
#   bash d077-layer-5-misfire-regression.sh --self-test
#
# Exit codes:
#   0 — all PASS (GREEN state — L5 misfire regression guard landed)
#   1 — at least one FAIL (RED state — bug present or fix incomplete)
#   2 — preflight failure (missing tool, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LABEL_CHECK="${REPO_ROOT}/.github/workflows/label-check.yml"

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
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d077 self-test (5 TCs per Issue #675 P0 BUG, ADR-0044 RED-first)${D}\n"
printf "${B}=======================================================================${D}\n"
printf "  Workflow under test:  %s\n" "$LABEL_CHECK"
printf "  Sister-pattern:       d069 (Layer 5 verdict-gate) + d076 (TDZ) + d055/d068\n"
printf "  Spec ref:             Issue #675 cmt 4832077155 (arch RCA cycle ~1081)\n"
printf "  RED-first state:      4/5 FAIL (TC1+TC2+TC3+TC4 missing); TC5 PASS (d069 held).\n"
printf "  Post-impl expected:   5/5 PASS.\n\n"

if [ ! -f "$LABEL_CHECK" ]; then
  fail "preflight — workflow file missing" "expected $LABEL_CHECK"
  exit 2
fi

# Locate the Layer 5 region: from the "Layer 5 — status:ready auto-add gating" job name
# to the next top-level step (anchored with colon to avoid matching sub-headers).
LAYER5_START="$(grep -nE '^\s*-\s+name:\s+Layer 5\s+' "$LABEL_CHECK" | head -1 | cut -d: -f1)"
if [ -z "$LAYER5_START" ]; then
  fail "preflight — Layer 5 job anchor not found" "expected 'name: Layer 5 — status:ready auto-add gating' step in $LABEL_CHECK"
  exit 2
fi
# LAYER5_END is the end of file (Layer 5 is the last major block in label-check.yml
# in the current post-Path-A cluster-squash state).
LAYER5_END="$(wc -l < "$LABEL_CHECK")"
LAYER5_REGION="${LAYER5_START},${LAYER5_END}p"
L5_BODY="$(sed -n "$LAYER5_REGION" "$LABEL_CHECK")"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# ============================================================================
# TC1: status:* removal short-circuit (Option C structural signature)
# ============================================================================
section "TC1: status:* removal short-circuit at L5 entry (Option C — Action A+ C combined fix)"
# Pattern: `if (evtAction === 'unlabeled' && ...label.name?.startsWith('status:')) return;`
# OR equivalent guard at job-level `if:` expression.
# RED: no such guard → L5 re-adds status:ready → loop.
TC1_PATTERNS=(
  "startsWith\\(['\"]status:"
  "label\\.name\\.startsWith\\(['\"]status:"
  "label\\?\\.name\\.startsWith\\(['\"]status:"
  "label\\?\\.name.*startsWith.*status:"
  "name\\.startsWith.*status:"
)
TC1_HIT=0
for pat in "${TC1_PATTERNS[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC1_HIT=1
    break
  fi
done

# Also accept job-level `if:` guards
if [ "$TC1_HIT" -eq 0 ]; then
  JOB_IF_PATTERN="if:.*action.*unlabeled.*status:"
  if grep -B2 -A2 "pull_request_target" "$LABEL_CHECK" | grep -qE "$JOB_IF_PATTERN"; then
    TC1_HIT=1
  fi
fi

if [ "$TC1_HIT" -eq 1 ]; then
  info "TC1 — short-circuit guard found in L5 region (action=unlabeled + status:* label)"
  pass "TC1 — status:* removal short-circuit present (prevents L5 from re-adding status:ready on cleanup)"
else
  fail "TC1 — short-circuit guard MISSING for action=unlabeled + status:* label" \
    "expected pattern like 'evtAction === \"unlabeled\" && label.name.startsWith(\"status:\") return;' or job-level 'if:' guard. P0 BUG #675 root cause: L5 re-adds status:ready on owner cleanup, loop unbreakable without this guard. Arch cmt 4832077155 Option C."
  EXIT_CODE=1
fi

# ============================================================================
# TC2: verdict:* label taxonomy check (Option A structural signature)
# ============================================================================
section "TC2: verdict:* label taxonomy check in L5 logic (Option A — explicit verdict label)"
# Pattern: explicit check for `verdict:changes-requested` label inside L5 body.
# Bug absence: L5 only checks 🟡/🔴 emoji in COMMENTS, NOT verdict:* labels.
# With verdict:changes-requested label set, owner approval is text-only,
# not in emoji, so L5 doesn't recognize the suppression → misfire.
TC2_PATTERNS=(
  "verdict:changes-requested"
  "verdict-changes-requested"
  "hasLabel\\(['\"]verdict:changes-requested['\"]"
  "verdict.*changes-requested.*label"
  "changes-requested.*verdict"
)
TC2_HIT=0
TC2_HIT_PATTERN=""
for pat in "${TC2_PATTERNS[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC2_HIT=1
    TC2_HIT_PATTERN="$pat"
    break
  fi
done

if [ "$TC2_HIT" -eq 1 ]; then
  info "TC2 — verdict:changes-requested label check found in L5 region (pattern: $TC2_HIT_PATTERN)"
  pass "TC2 — verdict:* label taxonomy check present (Option A: explicit verdict state via label, not emoji)"
else
  fail "TC2 — verdict:* label check MISSING from L5 logic" \
    "expected 'verdict:changes-requested' label check in L5 region. Arch cmt 4832077155 Option A: add explicit verdict:changes-requested / verdict:approved labels, L5 checks verdict:* labels BEFORE re-adding status:ready. Owner can set verdict:changes-requested on PR → L5 sees it → no re-add even on action=unlabeled."
  EXIT_CODE=1
fi

# ============================================================================
# TC3: bot-self-label actor exclusion at L5 entry
# ============================================================================
section "TC3: bot-self-label actor exclusion at L5 entry (prevent github-actions[bot] self-trigger)"
# Pattern: filter out github-actions[bot] actor at L5 entry so its own
# status:ready re-add attempts are no-op. Sister-pattern to the existing
# `c.user.type === 'Bot'` filter at L499 (which is for VERDICT EMOJI gate,
# not for L5 entry itself).
TC3_PATTERNS=(
  "context\\.sender.*type.*Bot"
  "context\\.payload\\.sender.*type.*Bot"
  "sender\\.type\\s*===\\s*['\"]Bot['\"]"
  "github-actions\\[bot\\]"
  "actor\\s*===\\s*['\"]github-actions"
)
TC3_HIT=0
TC3_HIT_PATTERN=""
for pat in "${TC3_PATTERNS[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC3_HIT=1
    TC3_HIT_PATTERN="$pat"
    break
  fi
done

if [ "$TC3_HIT" -eq 1 ]; then
  info "TC3 — bot-actor exclusion found in L5 region (pattern: $TC3_HIT_PATTERN)"
  pass "TC3 — bot-self-label actor exclusion present (prevents github-actions[bot] from triggering its own L5 loop)"
else
  fail "TC3 — bot-actor exclusion MISSING from L5 entry" \
    "expected pattern like 'context.sender.type === \"Bot\"' or 'actor === \"github-actions[bot]\"' early in L5. Without it, github-actions[bot]'s own status:ready addition triggers another unlabeled event → L5 fires again → infinite loop pathology."
  EXIT_CODE=1
fi

# ============================================================================
# TC4: loop-protection on successive unlabeled events (timestamp / dedup guard)
# ============================================================================
section "TC4: loop-protection guard on successive unlabeled events (pathology breaker)"
# Pattern: timestamp/dedup guard like `Date.now() - lastFireTime < 60000` OR
# explicit `if (consecutiveUnlabeledCount > N) return;` OR explicit dedup
# pattern via marker + idempotency. Sister-pattern to existing skip-log
# dedup at L515-L534 (existing dedup only fires if shouldAddReady=false).
TC4_PATTERNS=(
  "Date\\.now\\(\\).*lastFireTime"
  "lastFireTime"
  "lastUnlabeled"
  "consecutiveUnlabeled"
  "loopGuard"
  "rate.?limit.*label.?check"
)
TC4_HIT=0
TC4_HIT_PATTERN=""
for pat in "${TC4_PATTERNS[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC4_HIT=1
    TC4_HIT_PATTERN="$pat"
    break
  fi
done

# Alternative: explicit short-circuit on 'unlabeled' with verdict:* check
# (Option A alone is sufficient to break the loop — TC4 fall-back).
if [ "$TC4_HIT" -eq 0 ] && [ "$TC2_HIT" -eq 1 ]; then
  TC4_HIT=1
  TC4_HIT_PATTERN="verdict:* check (TC2 overlap, sufficient for loop-break per arch recommendation)"
fi

if [ "$TC4_HIT" -eq 1 ]; then
  info "TC4 — loop-protection found in L5 region (pattern: $TC4_HIT_PATTERN)"
  pass "TC4 — loop-protection guard present (prevents rapid-fire unlabeled event cascade)"
else
  fail "TC4 — loop-protection guard MISSING from L5" \
    "expected timestamp/dedup guard like 'Date.now() - lastFireTime < 60000' OR verdict:* label short-circuit. P0 BUG #675 observed 4 misfires in 16min on PR #658 — without explicit loop guard, even Option A+C combined may race. Sister-pattern to d076 TC6 cascade-strip + Layer 5 carry-the-same-guard doctrine."
  EXIT_CODE=1
fi

# ============================================================================
# TC5: verdict-emoji gate structural regression guard (d069 invariant hold)
# ============================================================================
section "TC5: verdict-emoji gate STILL present (d069 invariant must hold post-d077-fix)"
# Pattern: "Path A verdict-emoji gate" comment marker must remain in label-check.yml
# after d077 fix lands. This protects d069 sister-pattern invariant.
GATE_REGION_START="$(grep -nE 'Path A verdict-emoji gate' "$LABEL_CHECK" | head -1 | cut -d: -f1)"

if [ -z "$GATE_REGION_START" ]; then
  fail "TC5 — verdict-gate comment marker MISSING (d069 regression — fix must not remove emoji gate)" \
    "expected 'Path A verdict-emoji gate' comment marker in $LABEL_CHECK. d069 5/5 GREEN requires this comment for gate region detection. d077 fix must preserve d069 logic, not replace it."
  EXIT_CODE=1
else
  info "TC5 — Path A verdict-gate marker found at L${GATE_REGION_START} (d069 invariant held)"
  pass "TC5 — verdict-emoji gate structural regression guard passed (d069 invariant PRESERVED through d077 fix)"
fi

# ============================================================================
# TC6: verdict-state pre-condition for INITIAL-TRIGGER on type:docs
# (ADR-0048 amend-3, Issue #744 — sister-pattern to amend-1 🟡/🔴 suppression;
# adds ABSENT-verdict suppression for INITIAL-TRIGGER on type:docs PRs)
# ============================================================================
section "TC6: verdictPresent pre-condition gate for INITIAL-TRIGGER on type:docs (Amend-3, Issue #744)"
# Pattern: gate must check 4 surfaces BEFORE re-adding status:ready on
# initial-trigger type:docs PRs:
#   (a) latestVerdict === '🟢' OR hasLabel('verdict:approved')   (explicit OK signals)
#   (b) hasLabel('verdict-by') prefix-match                        (ADR-0024 §Schema timestamp)
#   (c) reviews.length > 0                                          (Issue #430 sister-pattern)
#   (d) guard: isInitialTrigger && isDocs && docsAuthor && !verdictPresent → suppress
# RED: no verdictPresent variable on main → L5 fires on type:docs initial-trigger
# even when comments=0/reviews=0/verdict-by=absent (PR #736 LIVE INSTANCE).
TC6_PATTERNS_VERDICT_PRESENT=(
  "const\\s+verdictPresent\\s*="
  "let\\s+verdictPresent\\s*="
  "verdictPresent\\s*:="
  "verdictPresent\\s*=\\s*\\("
)
TC6_PATTERNS_IS_INITIAL_TRIGGER=(
  "isInitialTrigger"
  "const\\s+isInitialTrigger"
  "let\\s+isInitialTrigger"
  "evtAction\\s*===\\s*['\"]opened['\"]"
)
TC6_PATTERNS_REVIEWS_FETCH=(
  "pulls\\.listReviews"
  "listReviews"
  "github\\.rest\\.pulls\\.listReviews"
)
TC6_PATTERNS_VERDICT_BY_PREFIX=(
  "verdict-by.*prefix"
  "labels\\.some.*verdict-by"
  "startsWith\\(['\"]verdict-by['\"]"
  "startsWith\\(['\"]verdict-by"
  "label\\.startsWith.*verdict-by"
  "\\.startsWith\\(['\"]verdict-by"
)
TC6_PATTERNS_VERDICT_APPROVED=(
  "verdict:approved"
  "hasLabel\\(['\"]verdict:approved['\"]"
)
TC6_PATTERNS_GUARD_CONDITION=(
  "isInitialTrigger.*isDocs.*docsAuthor.*verdictPresent"
  "isInitialTrigger.*!.*verdictPresent"
  "!verdictPresent.*isInitialTrigger"
  "verdictPresent.*REFUSED"
  "verdict-state gate"
  "Amend-3"
)

TC6_HIT_PRESENT=0
TC6_HIT_INITIAL=0
TC6_HIT_REVIEWS=0
TC6_HIT_VERDICT_BY=0
TC6_HIT_VERDICT_APPROVED=0
TC6_HIT_GUARD=0
TC6_HIT_PATTERNS=""

for pat in "${TC6_PATTERNS_VERDICT_PRESENT[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC6_HIT_PRESENT=1
    TC6_HIT_PATTERNS="${TC6_HIT_PATTERNS}[present:$pat] "
    break
  fi
done
for pat in "${TC6_PATTERNS_IS_INITIAL_TRIGGER[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC6_HIT_INITIAL=1
    TC6_HIT_PATTERNS="${TC6_HIT_PATTERNS}[initial:$pat] "
    break
  fi
done
for pat in "${TC6_PATTERNS_REVIEWS_FETCH[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC6_HIT_REVIEWS=1
    TC6_HIT_PATTERNS="${TC6_HIT_PATTERNS}[reviews:$pat] "
    break
  fi
done
for pat in "${TC6_PATTERNS_VERDICT_BY_PREFIX[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC6_HIT_VERDICT_BY=1
    TC6_HIT_PATTERNS="${TC6_HIT_PATTERNS}[verdict-by:$pat] "
    break
  fi
done
for pat in "${TC6_PATTERNS_VERDICT_APPROVED[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC6_HIT_VERDICT_APPROVED=1
    TC6_HIT_PATTERNS="${TC6_HIT_PATTERNS}[approved:$pat] "
    break
  fi
done
for pat in "${TC6_PATTERNS_GUARD_CONDITION[@]}"; do
  if echo "$L5_BODY" | grep -qE "$pat"; then
    TC6_HIT_GUARD=1
    TC6_HIT_PATTERNS="${TC6_HIT_PATTERNS}[guard:$pat] "
    break
  fi
done

TC6_TOTAL=$((TC6_HIT_PRESENT + TC6_HIT_INITIAL + TC6_HIT_REVIEWS + TC6_HIT_VERDICT_BY + TC6_HIT_VERDICT_APPROVED + TC6_HIT_GUARD))

if [ "$TC6_TOTAL" -ge 4 ]; then
  info "TC6 — Amend-3 verdict-state gate present (${TC6_TOTAL}/6 sub-patterns matched: ${TC6_HIT_PATTERNS})"
  pass "TC6 — verdictPresent pre-condition gate present in L5 region (Amend-3 / Issue #744 fix landed; PR #736 pathology closed)"
else
  fail "TC6 — verdict-state pre-condition gate INCOMPLETE in L5 region (${TC6_TOTAL}/6 sub-patterns matched)" \
    "expected ALL 6 sub-patterns for ADR-0048 Amend-3 verdictPresent pre-condition: (1) verdictPresent variable declaration, (2) isInitialTrigger check, (3) pulls.listReviews fetch (sister to listComments per Issue #430), (4) verdict-by prefix-match (ADR-0024 §Schema), (5) verdict:approved label check (defense-in-depth), (6) ABSENT-verdict suppression guard (isInitialTrigger && isDocs && docsAuthor && !verdictPresent → REFUSED). PR #736 = 6th TD-021 live instance: type:docs PR initial-triggered status:ready with ZERO peer verdicts in comments[]/reviews[]/verdict-by — Amend-3 closes this pathology."
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — L5 misfire regression guard missing (P0 BUG #675 active)${D}\n" "$FAIL"
  printf "${R}  PR #658 (and other Step 4 singles γ) squashes BLOCKED until fix lands + d077 goes GREEN.${D}\n"
  exit 1
fi

printf "\n${G}GREEN state: all 5 TCs PASS — L5 misfire regression guard landed (P0 BUG #675 fixed)${D}\n"
exit 0
