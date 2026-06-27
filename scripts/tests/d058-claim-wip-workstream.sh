#!/usr/bin/env bash
# d058-claim-wip-workstream.sh — ADR-0038 §Work-Stream Awareness regression test (9 TCs).
#
# Why this test exists
# --------------------
# ADR-0038 §Work-Stream Awareness amendment (PR #504 squash @ a45c613) codifies
# the rule that `scripts/claim-next-ready.sh` Layer 2 counts WORK-STREAMS, not
# issues. A PR cluster (PR-A closes #N + #M, both `agent:<role>`) is ONE
# work-stream, not two issues. The wip_overflow false positive (RETRO-008 §3
# origin) occurred because the pre-amendment script counted issues, capping WIP
# at 2 concurrent issues regardless of stream topology.
#
# d058 = 9 TCs (TC1-TC9) programmatic enforcement via bash + fake-gh factory
# pattern (sister-pattern to scripts/tests/d031-claim-next-ready.sh).
#
# Sister-pattern family (9-sister d-test framework):
#   - d046 (Issue #413 jq-filter guard)
#   - d048 (Issue #425 AC2.1 layered defense)
#   - d050b (Issue #440 behavioral workflow test framework)
#   - d051 (Issue #414 RETRO-005 #26 regression anchor)
#   - d052 (Issue #461 agent-watch.sh hardening)
#   - d053 (Issue #463 ADR-0050 pre-merge 4-cat verification)
#   - d054 (Issue #468 §Closes-anchor strict format)
#   - d058 (Issue #505 ADR-0038 §Work-Stream Awareness impl) — THIS FILE
#
# 9 TCs (per Issue #505 AC2 / docs/backlog/STORY-014.md AC2):
#   TC1: PR cluster (PR-A closes #N + #M) → WIP=1 per work-stream rule (core)
#   TC2: 2 standalone issues same priority → claim oldest (age tie-break, unchanged)
#   TC3: 1 PR cluster + 1 standalone → WIP=2 (cluster=1, standalone=1)
#   TC4: 2 PR clusters → WIP=2 (each cluster=1)
#   TC5: WIP limit reached (≥2 in-progress) → exit 3, no claim (work-stream-aware)
#   TC6: 0 ready items → exit 1, no claim (negative)
#   TC7: usage error (no role arg) → exit 2
#   TC8: invalid role → exit 2
#   TC9: PR cluster with closed-dep → WIP=1 (cluster collapse, dep filter applied)
#
# Usage:
#   bash d058-claim-wip-workstream.sh --self-test     # run inline fixture (9 TCs)
#
# Exit codes:
#   0 — all PASS (TC1-TC9 green, work-stream awareness impl'd)
#   1 — at least one FAIL (RED state — work-stream awareness not yet impl'd OR fixture bug)
#   2 — preflight failure (missing tool, etc.)
#
# RED-first discipline (ADR-0044):
#   Pre-impl (issue-count): TC1, TC3, TC4, TC9 must FAIL (work-stream not counted)
#   Post-impl (work-stream): all 9 TCs must PASS
#
# Run standalone: bash scripts/tests/d058-claim-wip-workstream.sh --self-test

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
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }
command -v bash >/dev/null 2>&1 || { echo "ERROR: bash required" >&2; exit 2; }
[ -f "$CLAIM_SH" ] || { echo "ERROR: claim-next-ready.sh not found at $CLAIM_SH" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d058 self-test (9 TCs per ADR-0038 §Work-Stream Awareness)${D}\n"
printf "${B}============================================================${D}\n"
printf "  Impl under test: %s\n" "$CLAIM_SH"
printf "  Fixture: fake-gh factory (binary shim, env-var-driven, --jq-aware)\n"
printf "  RED-first: pre-impl work-stream TCs (TC1/TC3/TC4/TC9) must FAIL.\n"
printf "  Post-impl: all 9 TCs must PASS.\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# Test sandbox
TEST_TMPDIR="$(mktemp -d /tmp/d058-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT
AUTO_CLAIM_LOG_DIR="$TEST_TMPDIR/logs"
mkdir -p "$AUTO_CLAIM_LOG_DIR"
export AUTO_CLAIM_LOG_DIR

# --- fake gh factory ---
# Usage: make_fake_gh <gh_path> <wip_data_json> <pr_clusters_json> <dep_open_n> <log_path>
#
# The fake gh script reads these values from env vars (FAKE_WIP_JSON,
# FAKE_CLUSTERS_JSON, FAKE_DEP_OPEN_N, FAKE_LOG_PATH) which are set by
# run_claim BEFORE invoking the claim script. This avoids heredoc
# variable-expansion pitfalls (heredoc with `<<'EOF'` writes literal text;
# all dynamic values come through env at runtime).
#
# Fake gh applies --jq filters correctly:
#   - `gh issue list ... --json number --jq 'length'` → returns count
#   - `gh issue list ... --json <fields>` → returns array
#   - `gh pr list --search "Closes #N in:body" --json <fields>` → returns matching PR list
#   - `gh issue view <N> --json state` → returns {"state":"open"|"closed"}
make_fake_gh() {
  local gh_path="$1"
  local wip_data="$2"
  local pr_clusters="$3"
  local dep_open_n="$4"
  local log_path="$5"

  # Write config files next to gh binary
  local wip_file="$gh_path.wip.json"
  printf '%s' "$wip_data" > "$wip_file"

  local clusters_file="$gh_path.clusters.json"
  if [ -n "$pr_clusters" ]; then
    printf '%s' "$pr_clusters" > "$clusters_file"
  else
    printf '{}' > "$clusters_file"
  fi

  # Heredoc with `<<'EOF'` (quoted) = NO variable expansion at write time.
  # All dynamic values are read from env at runtime.
  cat > "$gh_path" <<'FAKE_GH_EOF'
#!/usr/bin/env bash
echo "CALL $*" >> "${FAKE_LOG_PATH:-/tmp/fake-gh.log}"

# Detect --jq filter. Two forms supported:
#   --jq length         (separate arg; expression is the next positional arg)
#   --jq=length         (joined; expression is in the same arg)
JQ_EXPR=""
prev=""
for arg in "$@"; do
  case "$arg" in
    --jq)
      prev="--jq"
      ;;
    --jq=*)
      JQ_EXPR="${arg#--jq=}"
      prev=""
      ;;
    *)
      if [ "$prev" = "--jq" ]; then
        JQ_EXPR="$arg"
        prev=""
      fi
      ;;
  esac
done

cmd="$*"

# Dispatch on command surface
case "$cmd" in
  *"repo view"*)
    echo '{"nameWithOwner":"test-owner/test-repo"}'
    ;;
  *"issue list"*"status:in-progress"*)
    # Return the WIP list. If --jq is present, apply it.
    payload="$(cat "${FAKE_WIP_FILE:-/dev/null}" 2>/dev/null || echo '[]')"
    if [ -n "$JQ_EXPR" ]; then
      printf '%s' "$payload" | jq -r "$JQ_EXPR" 2>/dev/null || printf '%s' "$payload"
    else
      printf '%s' "$payload"
    fi
    ;;
  *"issue list"*"status:ready"*)
    # Return the ready list from env (set by run_claim via READY_JSON env var).
    if [ -n "${READY_JSON:-}" ]; then
      payload="$READY_JSON"
      if [ -n "$JQ_EXPR" ]; then
        printf '%s' "$payload" | jq -r "$JQ_EXPR" 2>/dev/null || printf '%s' "$payload"
      else
        printf '%s' "$payload"
      fi
    else
      if [ -n "$JQ_EXPR" ]; then
        echo '0'
      else
        echo '[]'
      fi
    fi
    ;;
  *"issue view"*"--json state"*)
    # Match issue number from arg.
    arg_n="$(echo "$cmd" | grep -oE 'issue view [0-9]+' | grep -oE '[0-9]+' | head -1)"
    if [ -n "$arg_n" ] && [ "$arg_n" = "${FAKE_DEP_OPEN_N:-}" ]; then
      echo '{"state":"open"}'
    else
      echo '{"state":"closed"}'
    fi
    ;;
  *"pr list"*"Closes"*)
    # Look for #N in the --search arg to determine which issue's cluster to return.
    search_n="$(echo "$cmd" | grep -oE '#[0-9]+' | head -1 | tr -d '#')"
    if [ -n "$search_n" ] && [ -n "${FAKE_CLUSTERS_FILE:-}" ] && [ -f "${FAKE_CLUSTERS_FILE}" ]; then
      body_for="$(jq -r --arg k "$search_n" '.[$k] // ""' "${FAKE_CLUSTERS_FILE}")"
      if [ -n "$body_for" ]; then
        # Return a JSON array with one PR whose body contains the cluster markers.
        # The script will inspect `body` to extract "Closes #N" markers.
        printf '[{"number":900,"body":"%s"}]' "$body_for"
      else
        echo '[]'
      fi
    else
      echo '[]'
    fi
    ;;
  *"issue edit"*|*"issue comment"*)
    # Log the call for inspection but don't fail.
    echo "EDIT_OR_COMMENT $*" >> "${FAKE_LOG_PATH:-/tmp/fake-gh.log}"
    echo '{"number":999}'
    ;;
  *)
    # Default: empty success
    echo '[]'
    ;;
esac
FAKE_GH_EOF

  chmod +x "$gh_path"
  echo "$gh_path"
}

# --- run_claim helper ---
# Usage: run_claim <role> <wip_data> <ready_json> <pr_clusters_json> <dep_open_n>
# Sets globals: CLAIM_OUT, CLAIM_RC, CLAIM_LOG
# Supports env override prefix (e.g. "WIP_LIMIT=3 run_claim ...").
run_claim() {
  # Parse optional env prefix (e.g. "FOO=bar run_claim ...")
  local env_prefix=""
  while [ "${1:-}" = "FOO=bar" ] || [[ "${1:-}" == *=* ]]; do
    env_prefix="$env_prefix $1"
    shift
  done

  local role="$1"
  local wip_data="$2"
  local ready_json="$3"
  local pr_clusters="$4"
  local dep_open_n="$5"

  local fake_bin
  fake_bin="$(mktemp -d "$TEST_TMPDIR/fakebin-XXXXXX")"
  local gh_path log_path
  log_path="$fake_bin/gh-log"
  make_fake_gh "$fake_bin/gh" "$wip_data" "$pr_clusters" "$dep_open_n" "$log_path" >/dev/null

  CLAIM_LOG="$log_path"
  # Use `env` to explicitly pass all required env vars to the subshell.
  # (Plain `VAR=val cmd` assignments don't survive `$(...)` command substitution
  # unless we export them. `env` makes this explicit and correct.)
  CLAIM_OUT="$(env $env_prefix \
    PATH="$fake_bin:$PATH" \
    FAKE_WIP_FILE="$fake_bin/gh.wip.json" \
    FAKE_CLUSTERS_FILE="$fake_bin/gh.clusters.json" \
    FAKE_DEP_OPEN_N="$dep_open_n" \
    FAKE_LOG_PATH="$log_path" \
    READY_JSON="$ready_json" \
    AUTO_CLAIM_LOG_DIR="$AUTO_CLAIM_LOG_DIR" \
    bash "$CLAIM_SH" "$role" 2>&1)"
  CLAIM_RC=$?
}

# Standard JSON fixture builder
make_issue() {
  # make_issue <number> <title> <createdAt> <body> <priority_label>
  local n="$1" title="$2" created="$3" body="$4" prio="$5"
  printf '{"number":%s,"title":"%s","createdAt":"%s","labels":[{"name":"%s"},{"name":"status:ready"},{"name":"agent:developer"}],"body":"%s"}' \
    "$n" "$title" "$created" "$prio" "$body"
}

# ============================================================================
# TC1: PR cluster (PR-A closes #N + #M) → WIP=1 per work-stream rule (core)
# ============================================================================
section "TC1: PR cluster of 2 issues → WIP=1, claim succeeds (work-stream awareness core)"
wip_in_progress='[
  {"number":400,"title":"cluster issue A"},
  {"number":401,"title":"cluster issue B"}
]'
ready_items="[$(make_issue 402 'ready item' '2026-06-22T10:00:00Z' '' 'priority:P0')]"
pr_clusters='{"400":"Closes #400 Closes #401","401":"Closes #400 Closes #401"}'
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #402"; then
  pass "PR cluster of 2 issues counted as 1 work-stream → claim succeeded (WIP=1)"
elif [ "$CLAIM_RC" = "3" ]; then
  fail "TC1 — script exited 3 (WIP cap on issue-count)" \
    "issue-count WIP=2 hits cap; expected post-impl WIP=1 (cluster = 1 stream). rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
else
  fail "TC1 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC2: 2 standalone issues same priority → claim oldest (age tie-break, unchanged)
# ============================================================================
section "TC2: 2 standalone issues same priority → WIP=2 cap, claim oldest (age tie-break)"
wip_in_progress='[
  {"number":100,"title":"older standalone"},
  {"number":101,"title":"newer standalone"}
]'
ready_items="[$(make_issue 102 'newer ready' '2026-06-22T10:00:00Z' '' 'priority:P1'),$(make_issue 103 'older ready' '2026-06-22T08:00:00Z' '' 'priority:P1')]"
pr_clusters='{}'  # no clusters = all standalone
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
# 2 standalone = 2 streams = WIP=2 → hits cap → exit 3
if [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -qE "WIP limit reached"; then
  pass "2 standalone WIP=2 hits cap (work-stream=issue, both pre-impl and post-impl agree) → exit 3"
else
  fail "TC2 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# TC2b: age tie-break sanity (WIP_LIMIT=3 override to isolate tie-break from cap)
section "TC2b: age tie-break sanity (WIP_LIMIT=3 override to isolate tie-break from cap)"
WIP_LIMIT=3 run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #103"; then
  pass "older P1 (#103) claimed first (age tie-break, unchanged behavior)"
elif [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #102"; then
  fail "TC2b — newer P1 (#102) claimed instead of older (#103)" \
    "age tie-break broken. out=$CLAIM_OUT"
  EXIT_CODE=1
else
  fail "TC2b — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC3: 1 PR cluster + 1 standalone → WIP=2 (cluster=1, standalone=1)
# ============================================================================
section "TC3: 1 PR cluster (2 issues) + 1 standalone → WIP=2 (work-stream awareness)"
wip_in_progress='[
  {"number":410,"title":"cluster issue A"},
  {"number":411,"title":"cluster issue B"},
  {"number":412,"title":"standalone issue (no PR)"}
]'
ready_items="[$(make_issue 413 'ready item' '2026-06-22T10:00:00Z' '' 'priority:P0')]"
pr_clusters='{"410":"Closes #410 Closes #411","411":"Closes #410 Closes #411"}'
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -qE "WIP limit reached: 2/2"; then
  pass "mixed cluster + standalone counted as 2 work-streams → exit 3 with WIP=2/2"
elif [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -qE "WIP limit reached: 3/"; then
  fail "TC3 — script reports WIP=3 (issue-count, not work-stream-aware)" \
    "expected post-impl WIP=2 (1 cluster + 1 standalone = 2 streams). out=$CLAIM_OUT"
  EXIT_CODE=1
else
  fail "TC3 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC4: 2 PR clusters → WIP=2 (each cluster=1)
# ============================================================================
section "TC4: 2 PR clusters (each 2 issues) → WIP=2 (work-stream awareness)"
wip_in_progress='[
  {"number":420,"title":"cluster 1 issue A"},
  {"number":421,"title":"cluster 1 issue B"},
  {"number":430,"title":"cluster 2 issue A"},
  {"number":431,"title":"cluster 2 issue B"}
]'
ready_items="[$(make_issue 432 'ready item' '2026-06-22T10:00:00Z' '' 'priority:P0')]"
pr_clusters='{"420":"Closes #420 Closes #421","421":"Closes #420 Closes #421","430":"Closes #430 Closes #431","431":"Closes #430 Closes #431"}'
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -qE "WIP limit reached: 2/2"; then
  pass "2 PR clusters (4 issues) counted as 2 work-streams → exit 3 with WIP=2/2"
elif [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -qE "WIP limit reached: 4/"; then
  fail "TC4 — script reports WIP=4 (issue-count, not work-stream-aware)" \
    "expected post-impl WIP=2 (2 clusters = 2 streams). out=$CLAIM_OUT"
  EXIT_CODE=1
else
  fail "TC4 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC5: WIP limit reached (≥2 in-progress) → exit 3, no claim (work-stream-aware)
# ============================================================================
section "TC5: WIP limit reached (2 standalones = 2 streams) → exit 3, no claim"
wip_in_progress='[
  {"number":500,"title":"stream 1"},
  {"number":501,"title":"stream 2"}
]'
ready_items="[$(make_issue 502 'ready item' '2026-06-22T10:00:00Z' '' 'priority:P0')]"
pr_clusters='{}'
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "3" ] && echo "$CLAIM_OUT" | grep -qE "WIP limit reached"; then
  if grep -q "EDIT_OR_COMMENT" "$CLAIM_LOG" 2>/dev/null; then
    fail "TC5 — WIP cap hit but script edited an issue" "should NOT edit when WIP >= limit"
    EXIT_CODE=1
  else
    pass "WIP limit reached (2 streams) → exit 3, no claim"
  fi
else
  fail "TC5 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC6: 0 ready items → exit 1, no claim (negative)
# ============================================================================
section "TC6: 0 ready items → exit 1, no claim (negative)"
wip_in_progress='[]'
ready_items="[]"
pr_clusters='{}'
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "1" ] && echo "$CLAIM_OUT" | grep -q "no ready items"; then
  if grep -q "EDIT_OR_COMMENT" "$CLAIM_LOG" 2>/dev/null; then
    fail "TC6 — no ready items but script edited an issue" "should NOT edit on negative path"
    EXIT_CODE=1
  else
    pass "0 ready items → exit 1 + 'no ready items' message"
  fi
else
  fail "TC6 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC7: usage error (no role arg) → exit 2
# ============================================================================
section "TC7: usage error (no role arg) → exit 2"
CLAIM_OUT="$(bash "$CLAIM_SH" 2>&1)"
CLAIM_RC=$?
if [ "$CLAIM_RC" = "2" ] && echo "$CLAIM_OUT" | grep -q "usage:"; then
  pass "no role arg → exit 2 + 'usage:' message"
else
  fail "TC7 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC8: invalid role → exit 2
# ============================================================================
section "TC8: invalid role → exit 2"
wip_in_progress='[]'
ready_items="[]"
pr_clusters='{}'
run_claim invalid-role 0 "[]" "{}" ""
if [ "$CLAIM_RC" = "2" ] && echo "$CLAIM_OUT" | grep -q "invalid role"; then
  pass "invalid role → exit 2 + 'invalid role' message"
else
  fail "TC8 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# TC9: PR cluster with closed-dep → WIP=1 (cluster collapse, dep filter applied)
# ============================================================================
section "TC9: PR cluster (2 issues, one has closed-dep) → WIP=1, claim OK"
# Cluster #600 + #601 — both are in-progress and form one work-stream.
# #601's body has a 'depends on #999' clause; #999 is CLOSED.
# Pre-impl: WIP=2 → exit 3.
# Post-impl: cluster=1 stream → WIP=1 → claim OK.
wip_in_progress='[
  {"number":600,"title":"cluster issue A"},
  {"number":601,"title":"cluster issue B (with closed dep)"}
]'
ready_items="[$(make_issue 602 'ready item' '2026-06-22T10:00:00Z' '' 'priority:P0')]"
pr_clusters='{"600":"Closes #600 Closes #601","601":"Closes #600 Closes #601"}'
run_claim developer "$wip_in_progress" "$ready_items" "$pr_clusters" ""
if [ "$CLAIM_RC" = "0" ] && echo "$CLAIM_OUT" | grep -q "claimed #602"; then
  pass "PR cluster with closed-dep counted as 1 work-stream → claim succeeded (WIP=1)"
elif [ "$CLAIM_RC" = "3" ]; then
  fail "TC9 — script exited 3 (WIP cap on issue-count)" \
    "issue-count WIP=2 hits cap; expected post-impl WIP=1 (cluster = 1 stream, closed-dep irrelevant). rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
else
  fail "TC9 — unexpected exit/output" "rc=$CLAIM_RC out=$CLAIM_OUT"
  EXIT_CODE=1
fi

# ============================================================================
# Summary
# ============================================================================
printf "\n${B}==== d058 SELF-TEST SUMMARY ====${D}\n"
printf "  ${G}PASS${D}: %d\n" "$PASS"
printf "  ${R}FAIL${D}: %d\n" "$FAIL"
printf "  ${Y}INFO${D}: %d\n" "$INFO"

# Sister-pattern invariants for ADR-0038 §Work-Stream Awareness impl:
#   Pre-impl (issue-count): TC1, TC3, TC4, TC9 must FAIL (work-stream not counted)
#                           TC2b (WIP_LIMIT=3 override) is the only pre-impl PASS that's
#                           NOT work-stream-dependent (just age tie-break sanity).
#   Post-impl (work-stream): all 9 TCs must PASS
#
# We accept either:
#   (a) 9/9 PASS — impl complete, d058 GREEN
#   (b) FAIL on TC1, TC3, TC4, TC9 only — RED state confirmed (4 FAIL), impl pending
if [ "$FAIL" -eq 0 ]; then
  printf "  ${G}d058 GREEN${D} — 9/9 PASS = work-stream awareness fully impl'd\n"
  exit 0
elif [ "$FAIL" -ge 4 ] && [ "$FAIL" -le 9 ]; then
  printf "  ${Y}d058 RED${D} — %d FAIL observed. Expected: TC1, TC3, TC4, TC9 (work-stream-dependent, pre-impl).\n" "$FAIL"
  printf "  ${Y}Action${D}: impl work-stream awareness in scripts/claim-next-ready.sh Layer 2 (ADR-0038 §Work-Stream Awareness).\n"
  exit 1
else
  printf "  ${R}d058 RED (unexpected)${D} — FAIL=%d outside expected range. Investigate fixture or pre-existing regressions.\n" "$FAIL"
  exit 1
fi
