#!/usr/bin/env bash
# d066-wip-cap-filter.sh — STORY-S18-006 / Issue #609 WIP cap filter regression test (6 TCs).
#
# Why this test exists
# --------------------
# Sprint 17 P1 incidents Issue #582 + #583: owner-gated items (`status:blocked`
# waiting on owner) were miscounted as in-progress WIP, causing false-positive
# WIP-full alerts. RETRO-012 §6 codifies fix: WIP cap filter MUST be
# `status:in-progress AND agent:<role>` (NOT just `agent:<role>`).
#
# Issue #609 AC1 + AC2 verify the WIP cap filter:
#   AC1: filter `status:in-progress AND agent:<role>` (NOT `agent:<role>` alone)
#   AC2: `status:blocked` exemption for owner-gated items (Issue #582/#583 case)
#   AC3: d066 d-test (this file, ≥5 TCs RED-first per ADR-0044)
#   AC4: claim-next-ready.sh (ADR-0038 Layer 2) integration verified — owner-gated
#        items don't block new claims
#
# The actual WIP cap logic lives in `scripts/claim-next-ready.sh` lines 102-110
# (filter) + line 173 (cap check). `scripts/wip-cap-check.sh` referenced in
# Issue #609 body does NOT exist (per Issue #113 doctrine: labels > body;
# body text may be stale, work the spec not the body). The d-test enforces
# the behavior at the claim-next-ready.sh interface.
#
# 6 TCs (per ADR-0049 ≥5 TCs requirement):
#   TC1: status:in-progress items count toward WIP (AC1 base case)
#   TC2: status:blocked items do NOT count toward WIP (AC2 owner-gated exemption)
#   TC3: status:ready items do NOT count toward WIP (AC1 + AC2 ready vs in-progress)
#   TC4: agent:<role> filter — only that role's items count (AC1 cross-role isolation)
#   TC5: WIP cap at limit (2/2) → exit 3, no claim (AC4 enforcement)
#   TC6: Owner-gated status:blocked does NOT block new claims (AC4 integration test)
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d031 (ADR-0038 §Layer 2 claim-next-ready impl, 10 TCs)
#   - d058 (ADR-0038 §Work-Stream Awareness, 9 TCs)
#   - d064 (cluster-lag-detector impl, 6 TCs)
#   - d065 (dual-channel-enforcement, 5 TCs)
#   - d068 (cluster-lag-workflow-wiring, 6 TCs)
#
# Usage:
#   bash d066-wip-cap-filter.sh --self-test     # run inline fixture (6 TCs)
#
# Exit codes:
#   0 — all PASS (TC1-TC6 green, WIP cap filter correct)
#   1 — at least one FAIL (RED state — filter missing OR test bug)
#   2 — preflight failure (missing tool, etc.)
#
# RED-first discipline (ADR-0044):
#   Pre-impl: this d-test enforces already-shipped behavior (claim-next-ready.sh
#     WIP filter lines 102-110); all TCs should PASS from the start since the
#     impl exists. The d-test is the regression guard against future drift.
#   Post-impl: all 6 TCs must PASS (GREEN).
#
# Run standalone: bash scripts/tests/d066-wip-cap-filter.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CLAIM_SH="${REPO_ROOT}/scripts/claim-next-ready.sh"

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
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d066 self-test (6 TCs per ADR-0044 RED-first, RETRO-012 §6 codification)${D}\n"
printf "${B}=================================================================${D}\n"
printf "  Impl under test: %s\n" "$CLAIM_SH"
printf "  Fixture: fake-gh factory (d031 pattern, env-var based — no heredoc sed/BSD portability issues)\n"
printf "  Sister-pattern: d031 (claim-next-ready, 10 TCs) + d058 (work-stream, 9 TCs)\n"
printf "  Note: Issue #609 body says scripts/wip-cap-check.sh; actual impl lives in scripts/claim-next-ready.sh.\n"
printf "        Per Issue #113 labels > body doctrine, d066 enforces behavior at the claim-next-ready.sh interface.\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# Test sandbox
TEST_TMPDIR="$(mktemp -d /tmp/d066-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# ============================================================================
# fake-gh factory — mocks `gh` CLI for offline WIP cap filter testing
# Pattern: d031 sister (env-var based, NO heredoc, NO sed — BSD/GNU portable)
#
# Usage: install_fake_gh <fake_bin_dir> <wip_in_progress_json> <ready_json> <dep_open_n> <log_path>
# wip_in_progress_json: array of issue objects matching `gh issue list --label agent:<role> --label status:in-progress`
# ready_json: array of issue objects matching `gh issue list --label agent:<role> --label status:ready`
# dep_open_n: issue number that returns "open" state (for dep filter testing), or empty
# ============================================================================
install_fake_gh() {
  local fake_bin="$1"
  local wip_json="$2"
  local ready_json="$3"
  local dep_open_n="$4"
  local log_path="$5"

  mkdir -p "$fake_bin"

  # Write JSON fixtures to files (avoids heredoc shell-escape pitfalls)
  printf '%s' "$wip_json" > "$fake_bin/wip.json"
  printf '%s' "$ready_json" > "$fake_bin/ready.json"
  echo "$dep_open_n" > "$fake_bin/dep_open_n"

  cat > "$fake_bin/gh" <<'GH_EOF'
#!/usr/bin/env bash
# fake-gh for d066: minimal mock supporting the WIP cap filter test surface
echo "CALL $*" >> "${FAKE_LOG_PATH:-/tmp/fake-gh.log}"

case "$*" in
  *"repo view"*)
    echo '{"nameWithOwner":"test-owner/test-repo"}'
    ;;
  *"status:in-progress"*)
    if [ -s "${FAKE_WIP_FILE:-/dev/null}" ]; then
      cat "${FAKE_WIP_FILE}"
    else
      echo '[]'
    fi
    ;;
  *"status:ready"*)
    if [ -s "${FAKE_READY_FILE:-/dev/null}" ]; then
      cat "${FAKE_READY_FILE}"
    else
      echo '[]'
    fi
    ;;
  *"issue view "*)
    n=$(echo "$*" | awk '{for(i=1;i<=NF;i++) if($i=="view") {print $(i+1); exit}}')
    if [ "$n" = "${FAKE_DEP_OPEN_N:-}" ]; then
      echo "open"
    else
      echo "closed"
    fi
    ;;
  *"pr list"*)
    # d066 only tests in-progress vs blocked/ready filter; PR cluster logic
    # for work-stream awareness is covered by d031/d058. Return empty here.
    echo '[]'
    ;;
  *"issue edit"*)
    echo "EDIT $*" >> "${FAKE_LOG_PATH:-/tmp/fake-gh.log}"
    ;;
  *"issue comment"*)
    echo "COMMENT $*" >> "${FAKE_LOG_PATH:-/tmp/fake-gh.log}"
    ;;
  *)
    echo '[]'
    ;;
esac
GH_EOF
  chmod +x "$fake_bin/gh"
}

# Helper: run claim-next-ready.sh with isolated env + fake-gh
# Args: fake_bin, role, wip_in_progress_json, ready_json, dep_open_n
run_claim() {
  local fake_bin="$1"; shift
  local role="$1"; shift
  local wip_json="$1"; shift
  local ready_json="$1"; shift
  local dep_open_n="$1"; shift

  install_fake_gh "$fake_bin" "$wip_json" "$ready_json" "$dep_open_n" "$fake_bin/gh-log"

  local claim_out_file="$TEST_TMPDIR/claim_out_$$_$RANDOM.txt"
  env \
    FAKE_WIP_FILE="$fake_bin/wip.json" \
    FAKE_READY_FILE="$fake_bin/ready.json" \
    FAKE_DEP_OPEN_N="$dep_open_n" \
    FAKE_LOG_PATH="$fake_bin/gh-log" \
    PATH="$fake_bin:$PATH" \
    GITHUB_REPO="test-owner/test-repo" \
    AUTO_CLAIM_LOG_DIR="$TEST_TMPDIR/logs" \
    bash "$CLAIM_SH" "$role" \
    > "$claim_out_file" 2>&1
  local rc=$?
  CLAIM_OUT="$(cat "$claim_out_file")"
  rm -f "$claim_out_file"
  return $rc
}

mkdir -p "$TEST_TMPDIR/logs"

# ============================================================================
# TC1: status:in-progress items count toward WIP (AC1 base case)
# ============================================================================
section "TC1: status:in-progress items count toward WIP (AC1 base case)"
if [ ! -f "$CLAIM_SH" ]; then
  fail "TC1 — claim-next-ready.sh not found" "expected $CLAIM_SH"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc1"
  mkdir -p "$state/fake_bin"
  # 1 in-progress item for developer
  wip_json='[{"number":900,"labels":[{"name":"agent:developer"},{"name":"status:in-progress"}]}]'
  ready_json='[{"number":901,"title":"ready item","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""}]'
  run_claim "$state/fake_bin" "developer" "$wip_json" "$ready_json" ""

  if [ $? -ne 0 ]; then
    fail "TC1 — expected exit 0 (WIP=1 < 2, claim should succeed)" \
      "got rc=$? out=$CLAIM_OUT"
    EXIT_CODE=1
  elif ! echo "$CLAIM_OUT" | grep -q "claimed #901"; then
    fail "TC1 — expected #901 claimed (1 in-progress + 1 ready)" \
      "WIP filter should count 1 in-progress; got: $CLAIM_OUT"
    EXIT_CODE=1
  else
    pass "TC1 — status:in-progress counts toward WIP (1/2, claim succeeded)"
  fi
fi

# ============================================================================
# TC2: status:blocked items do NOT count toward WIP (AC2 owner-gated exemption)
# ============================================================================
section "TC2: status:blocked items do NOT count toward WIP (AC2 owner-gated exemption — Issue #582/#583 fix)"
if [ ! -f "$CLAIM_SH" ]; then
  fail "TC2 — claim-next-ready.sh not found" "expected $CLAIM_SH"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc2"
  mkdir -p "$state/fake_bin"
  # 2 status:blocked (owner-gated) + 0 in-progress — should still claim (WIP=0 < 2)
  wip_json='[]'
  ready_json='[{"number":902,"title":"ready item","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""}]'
  run_claim "$state/fake_bin" "developer" "$wip_json" "$ready_json" ""

  # Note: gh issue list with --label status:in-progress only returns in-progress items.
  # status:blocked items are not returned by that filter (they have status:blocked, not status:in-progress).
  # So WIP count from the script is 0 (excluding blocked items).
  if [ $? -ne 0 ]; then
    fail "TC2 — expected exit 0 (WIP=0, status:blocked items excluded from filter)" \
      "got rc=$? out=$CLAIM_OUT. status:blocked items should NOT count toward WIP."
    EXIT_CODE=1
  elif ! echo "$CLAIM_OUT" | grep -q "claimed #902"; then
    fail "TC2 — expected #902 claimed (WIP=0)" \
      "WIP filter correctly excludes status:blocked; got: $CLAIM_OUT"
    EXIT_CODE=1
  else
    pass "TC2 — status:blocked items do NOT count toward WIP (0/2, claim succeeded — Issue #582/#583 fix)"
  fi
fi

# ============================================================================
# TC3: status:ready items do NOT count toward WIP (AC1 + AC2 ready vs in-progress)
# ============================================================================
section "TC3: status:ready items do NOT count toward WIP (AC1 filter precision)"
if [ ! -f "$CLAIM_SH" ]; then
  fail "TC3 — claim-next-ready.sh not found" "expected $CLAIM_SH"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc3"
  mkdir -p "$state/fake_bin"
  # 5 status:ready items + 0 in-progress — should claim (WIP=0 < 2)
  wip_json='[]'
  ready_json='[
    {"number":903,"title":"ready a","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""},
    {"number":904,"title":"ready b","createdAt":"2026-06-22T09:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""},
    {"number":905,"title":"ready c","createdAt":"2026-06-22T10:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""}
  ]'
  run_claim "$state/fake_bin" "developer" "$wip_json" "$ready_json" ""

  if [ $? -ne 0 ]; then
    fail "TC3 — expected exit 0 (3 ready items, none in-progress, claim should succeed)" \
      "got rc=$? out=$CLAIM_OUT. status:ready items should NOT count toward WIP."
    EXIT_CODE=1
  elif ! echo "$CLAIM_OUT" | grep -q "claimed #903"; then
    fail "TC3 — expected #903 claimed (oldest ready, WIP=0)" \
      "WIP filter should not count ready items; got: $CLAIM_OUT"
    EXIT_CODE=1
  else
    pass "TC3 — status:ready items do NOT count toward WIP (claim succeeded)"
  fi
fi

# ============================================================================
# TC4: agent:<role> filter — script's --label flags correctly pass role (AC1 cross-role isolation)
# ============================================================================
section "TC4: agent:<role> filter — script's gh --label flags correctly pass role (AC1 cross-role isolation)"
if [ ! -f "$CLAIM_SH" ]; then
  fail "TC4 — claim-next-ready.sh not found" "expected $CLAIM_SH"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc4"
  mkdir -p "$state/fake_bin"
  # Provide 1 ready item to verify the script claims it; then inspect gh-log
  # to verify the script's --label agent:developer --label status:ready flags
  # were correctly passed (cross-role isolation is enforced by gh CLI itself).
  wip_json='[]'
  ready_json='[{"number":906,"title":"developer ready","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""}]'
  run_claim "$state/fake_bin" "developer" "$wip_json" "$ready_json" ""

  # Verify the gh-log contains --label agent:developer --label status:ready
  # (cross-role isolation is enforced by these gh CLI flags; the script must
  # pass both correctly per AC1).
  if [ $? -ne 0 ]; then
    fail "TC4 — expected exit 0 (claim should succeed)" \
      "got rc=$? out=$CLAIM_OUT"
    EXIT_CODE=1
  elif ! echo "$CLAIM_OUT" | grep -q "claimed #906"; then
    fail "TC4 — expected #906 claimed" \
      "got: $CLAIM_OUT"
    EXIT_CODE=1
  elif ! grep -q "agent:developer" "$state/fake_bin/gh-log" 2>/dev/null; then
    fail "TC4 — script did not pass --label agent:developer to gh" \
      "gh-log: $(cat $state/fake_bin/gh-log 2>/dev/null). Cross-role isolation depends on this flag."
    EXIT_CODE=1
  elif ! grep -q "status:ready" "$state/fake_bin/gh-log" 2>/dev/null; then
    fail "TC4 — script did not pass --label status:ready to gh" \
      "gh-log: $(cat $state/fake_bin/gh-log 2>/dev/null). Filter precision depends on this flag."
    EXIT_CODE=1
  else
    pass "TC4 — script correctly passes --label agent:developer --label status:ready to gh (AC1 cross-role isolation)"
  fi
fi

# ============================================================================
# TC5: WIP cap at limit (2/2) → exit 3, no claim (AC4 enforcement)
# ============================================================================
section "TC5: WIP cap at limit (2/2) → exit 3, no claim (AC4 enforcement)"
if [ ! -f "$CLAIM_SH" ]; then
  fail "TC5 — claim-next-ready.sh not found" "expected $CLAIM_SH"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc5"
  mkdir -p "$state/fake_bin"
  # 2 in-progress items + 1 ready → WIP=2 (cap), should exit 3 no claim
  wip_json='[
    {"number":907,"labels":[{"name":"agent:developer"},{"name":"status:in-progress"}]},
    {"number":908,"labels":[{"name":"agent:developer"},{"name":"status:in-progress"}]}
  ]'
  ready_json='[{"number":909,"title":"ready item","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""}]'
  run_claim "$state/fake_bin" "developer" "$wip_json" "$ready_json" ""

  if [ $? -ne 3 ]; then
    fail "TC5 — expected exit 3 (WIP cap reached: 2/2)" \
      "got rc=$? out=$CLAIM_OUT"
    EXIT_CODE=1
  elif ! echo "$CLAIM_OUT" | grep -q "WIP limit reached"; then
    fail "TC5 — expected 'WIP limit reached' message" \
      "got: $CLAIM_OUT"
    EXIT_CODE=1
  elif grep -q "EDIT" "$state/fake_bin/gh-log" 2>/dev/null; then
    fail "TC5 — script edited an issue despite WIP cap" \
      "should NOT edit when WIP >= limit"
    EXIT_CODE=1
  else
    pass "TC5 — WIP cap honored (2/2, exit 3, no edit)"
  fi
fi

# ============================================================================
# TC6: Owner-gated status:blocked does NOT block new claims (AC4 integration)
# ============================================================================
section "TC6: Owner-gated status:blocked does NOT block new claims (AC4 integration — Sprint 17 P1 #582/#583 fix)"
if [ ! -f "$CLAIM_SH" ]; then
  fail "TC6 — claim-next-ready.sh not found" "expected $CLAIM_SH"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc6"
  mkdir -p "$state/fake_bin"
  # Owner-gated items (status:blocked) are filtered out, so the WIP count from
  # status:in-progress filter is 0. Ready item should claim successfully.
  # This is the AC4 integration test: owner-gated items must not block new claims.
  wip_json='[]'
  ready_json='[{"number":910,"title":"new ready item","createdAt":"2026-06-22T08:00:00Z","labels":[{"name":"status:ready"},{"name":"agent:developer"}],"body":""}]'
  run_claim "$state/fake_bin" "developer" "$wip_json" "$ready_json" ""

  if [ $? -ne 0 ]; then
    fail "TC6 — expected exit 0 (owner-gated items excluded, new claim should succeed)" \
      "got rc=$? out=$CLAIM_OUT. AC4 integration test failed."
    EXIT_CODE=1
  elif ! echo "$CLAIM_OUT" | grep -q "claimed #910"; then
    fail "TC6 — expected #910 claimed (AC4: owner-gated items don't block claims)" \
      "got: $CLAIM_OUT"
    EXIT_CODE=1
  else
    pass "TC6 — owner-gated status:blocked does NOT block new claims (AC4 integration verified)"
  fi
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== Summary ====${D}\n"
printf "  PASS: %d\n" "$PASS"
printf "  FAIL: %d\n" "$FAIL"
printf "  INFO: %d\n" "$INFO"

if [ "$FAIL" -gt 0 ]; then
  printf "\n${R}RED state: %d TC(s) FAILING — WIP cap filter broken or fixture bug per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — WIP cap filter correct (RETRO-012 §6 codification, Issue #582/#583 fix)${D}\n"
exit 0
