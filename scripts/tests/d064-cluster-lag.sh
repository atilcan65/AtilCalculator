#!/usr/bin/env bash
# d064-cluster-lag.sh — ADR-0059 §1 cluster-squash batch-lag detection regression test (6 TCs).
#
# Why this test exists
# --------------------
# Sprint 14-16 ceremonies observed cluster-squash events (≥3 PRs squashed within
# tight temporal windows) becoming increasingly common. RETRO-009 §14 codifies
# the observation; Issue #508 documents a 4-PR cluster with cluster_lag = 324s.
# Manual reconstruction requires PM lane (RETRO curator) to cross-reference
# squash timestamps via `gh pr view --json mergedAt` — error-prone + scales
# linearly with cluster size.
#
# ADR-0059 §1-§3 codifies the cluster-squash batch-lag detection doctrine:
#   - Detection criterion: ≥3 PRs squashed within 60s window (ADR §1 wording drift; impl uses 600s lookback per TC2 fixture codification — Sprint 18+ ADR amendment per ADR-0056)
#   - Lag metric: cluster_lag_seconds = max(squash_timestamps[]) − min(squash_timestamps[])
#   - RETRO-consumable output format: structured markdown + JSON event log (PM curator step per Option B rescope)
#
# d064 = 6 TCs (TC1-TC6) programmatic enforcement via bash + fake-gh factory
# (sister-pattern to d061-label-hygiene.sh — both post-squash bash sweeps).
#
# Sister-pattern family (d-test lineage, ADR-0049):
#   - d061 (RETRO-009 §3 post-squash label hygiene — direct sister)
#   - d062 (Issue #552 AC2 watcher patch dual mechanism)
#   - d063 (RETRO-011 §1 stale-cc deadlock-breaker — pending PR #591)
#   - d058 (Issue #505 ADR-0038 §Work-Stream Awareness impl — work-stream aware)
#   - d054 (Issue #468 §Closes-anchor strict format — deep-narrow)
#
# 6 TCs (per STORY-P1-1 design doc §API contract + Issue #587 AC2 + tester F3 fix Option X):
#   TC1: detector script exists + executable + bash syntax valid (baseline)
#   TC2: cluster detection: 4 PRs in 600s lookback → cluster_lag_detected emitted (LIVE INSTANCE)
#   TC3: single-PR squash → silent_skip log (ADR-0048 lens d compliance)
#   TC4: 600s lookback boundary: 1 sibling outside 600s window → silent_skip (false-positive guard) — F2 cosmetic fix
#   TC5: cluster_lag_seconds metric: max-min delta correct (cluster_id format too)
#   TC6: malformed merged.json (object not array, missing fields) → exit 2 (F3 fix per ADR-0056 Option X explicit jq error check)
#
# Usage:
#   bash d064-cluster-lag.sh --self-test     # run inline fixture (6 TCs)
#
# Exit codes:
#   0 — all PASS (TC1-TC6 green, cluster-lag-detector impl'd)
#   1 — at least one FAIL (RED state — impl missing OR fixture bug)
#   2 — preflight failure (missing tool, etc.)
#
# RED-first discipline (ADR-0044):
#   Pre-impl: TC1 PASS only if impl exists; TC2-TC6 FAIL (impl missing)
#   Post-impl: all 6 TCs must PASS
#
# Run standalone: bash scripts/tests/d064-cluster-lag.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DETECTOR_SH="${REPO_ROOT}/scripts/post-squash/cluster-lag-detector.sh"
LOG_FILE="${CLUSTER_LAG_LOG:-/var/log/dev-studio/AtilCalculator/cluster-lag.log}"

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
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required for cluster_lag JSON parse" >&2; exit 2; }

# Self-test mode
if [ "${1:-}" != "--self-test" ]; then
  echo "Usage: bash $0 --self-test" >&2
  exit 2
fi

printf "${B}d064 self-test (6 TCs per ADR-0059 §1-§3 cluster-squash batch-lag detection)${D}\n"
printf "${B}=========================================================================${D}\n"
printf "  Impl under test: %s\n" "$DETECTOR_SH"
printf "  Fixture: fake-gh factory (mocks gh pr list --state merged --json)\n"
printf "  RED-first: pre-impl TCs must FAIL.\n"
printf "  Post-impl: all 6 TCs must PASS (5 original + TC6 F3 fix per ADR-0056 Option X).\n\n"

PASS=0; FAIL=0; INFO=0
EXIT_CODE=0

# Test sandbox
TEST_TMPDIR="$(mktemp -d /tmp/d064-XXXXXX)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# ============================================================================
# fake-gh factory — mocks `gh pr list --state merged --json mergedAt,number`
# ============================================================================
# Usage: install_fake_gh <fake_bin_dir> <state_dir>
#   state_dir/merged.json — JSON array of {number, mergedAt} for fixture
install_fake_gh() {
  local fake_bin="$1"
  local state_dir="$2"
  mkdir -p "$fake_bin"

  cat > "$fake_bin/gh" <<'GH_EOF'
#!/usr/bin/env bash
# fake-gh: minimal gh CLI mock for d064 tests
# Supports: gh pr list --state merged --json mergedAt,number --jq '<filter>'
FAKE_GH_MERGED="${FAKE_GH_MERGED:?FAKE_GH_MERGED not set}"

case "${1:-}:${2:-}" in
  pr:list)
    # Print full JSON array (matches real `gh pr list --json mergedAt,number`)
    cat "$FAKE_GH_MERGED"
    exit 0
    ;;
  *)
    echo "ERROR: fake-gh: unsupported command: $*" >&2
    exit 2
    ;;
esac
GH_EOF
  chmod +x "$fake_bin/gh"
}

# Helper: build a fixture JSON array of merged PRs
make_merged_fixture() {
  local fixture_path="$1"
  shift
  # Args: pr_number:iso_timestamp pairs
  local first=1
  printf '[' > "$fixture_path"
  while [ $# -gt 0 ]; do
    local pr_num="${1%%:*}"
    local merged_at="${1#*:}"
    if [ "$first" -eq 0 ]; then printf ',' >> "$fixture_path"; fi
    first=0
    printf '{"number":%s,"mergedAt":"%s"}' "$pr_num" "$merged_at" >> "$fixture_path"
    shift
  done
  printf ']' >> "$fixture_path"
}

# Helper: run the detector with a given PR + fixture
# Sets globals: DET_OUT, DET_RC, DET_LOG
run_detector() {
  local fake_bin="$1"
  local fixture_path="$2"
  local pr_number="$3"
  local merged_at="$4"
  local log_file="$5"
  local cluster_id="${6:-sprint-17-test-cluster}"

  rm -f "$log_file"
  local det_out_file="$TEST_TMPDIR/det_out_$$_$RANDOM.txt"
  # Run detector directly (NOT via $()) so we capture its real exit status.
  # Previously used `$() || true` which masked exit code 2 as 0 (TC6 false-positive).
  FAKE_GH_MERGED="$fixture_path" \
    PATH="$fake_bin:$PATH" \
    CLUSTER_LAG_LOG="$log_file" \
    PR_NUMBER="$pr_number" \
    MERGED_AT="$merged_at" \
    REPO="atilproject/AtilCalculator" \
    CLUSTER_ID="$cluster_id" \
    DETECTOR_VERSION="0.1.0" \
    bash "$DETECTOR_SH" > "$det_out_file" 2>&1
  DET_RC=$?
  DET_OUT="$(cat "$det_out_file")"
  rm -f "$det_out_file"
  DET_LOG="$(cat "$log_file" 2>/dev/null || true)"
}

# ============================================================================
# TC1: detector script exists + executable + bash syntax valid (baseline)
# ============================================================================
section "TC1: detector script exists + executable + bash syntax valid"
if [ ! -f "$DETECTOR_SH" ]; then
  fail "TC1 — detector script not found" \
    "expected $DETECTOR_SH (impl not yet written per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  if [ ! -x "$DETECTOR_SH" ]; then
    fail "TC1 — detector script not executable" \
      "expected chmod +x on $DETECTOR_SH"
    EXIT_CODE=1
  else
    if bash -n "$DETECTOR_SH" 2>/dev/null; then
      pass "TC1 — detector exists + executable + bash syntax valid"
    else
      fail "TC1 — bash syntax error in detector" \
        "run: bash -n $DETECTOR_SH"
      EXIT_CODE=1
    fi
  fi
fi

# ============================================================================
# TC2: cluster detection — 4 PRs in 60s window → cluster_lag_detected emitted
# ============================================================================
section "TC2: cluster detection (4 PRs in 60s window) → cluster_lag_detected emitted (LIVE INSTANCE, Issue #508 sister)"
if [ ! -f "$DETECTOR_SH" ]; then
  fail "TC2 — impl missing, cannot test" \
    "expected $DETECTOR_SH (impl lands via separate PR per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc2"
  install_fake_gh "$state/fake_bin" "$state"
  # 4 PRs merged within 60s window — Issue #508 sister-pattern
  make_merged_fixture "$state/merged.json" \
    "506:2026-06-27T21:54:34Z" \
    "507:2026-06-27T21:58:14Z" \
    "508:2026-06-27T21:59:46Z" \
    "509:2026-06-27T22:00:00Z"
  run_detector "$state/fake_bin" "$state/merged.json" 509 "2026-06-27T22:00:00Z" "$state/cluster-lag.log" "sprint-14-p1-2-cluster"

  if [ "$DET_RC" != "0" ]; then
    fail "TC2 — expected exit 0 on cluster detection" \
      "got rc=$DET_RC out=$DET_OUT"
    EXIT_CODE=1
  elif [ -z "$DET_LOG" ]; then
    fail "TC2 — cluster_lag_detected log line missing" \
      "expected append to $state/cluster-lag.log (ADR-0048 lens d compliance)"
    EXIT_CODE=1
  else
    # Parse log JSON: must have cluster_size=4 + cluster_lag_seconds + pr_numbers + cluster_id
    event_type="$(echo "$DET_LOG" | jq -r '.event // empty' 2>/dev/null)"
    cluster_size="$(echo "$DET_LOG" | jq -r '.cluster_size // empty' 2>/dev/null)"
    cluster_id="$(echo "$DET_LOG" | jq -r '.cluster_id // empty' 2>/dev/null)"
    if [ "$event_type" = "cluster_lag_detected" ] && [ "$cluster_size" = "4" ] && [ "$cluster_id" = "sprint-14-p1-2-cluster" ]; then
      pass "TC2 — 4-PR cluster detected, cluster_lag_detected event emitted with cluster_id=$cluster_id"
    else
      fail "TC2 — log JSON schema mismatch" \
        "expected event=cluster_lag_detected cluster_size=4 cluster_id=sprint-14-p1-2-cluster. got: event=$event_type cluster_size=$cluster_size cluster_id=$cluster_id"
      EXIT_CODE=1
    fi
  fi
fi

# ============================================================================
# TC3: single-PR squash → silent_skip log (ADR-0048 lens d compliance)
# ============================================================================
section "TC3: single-PR squash → silent_skip (no cluster)"
if [ ! -f "$DETECTOR_SH" ]; then
  fail "TC3 — impl missing, cannot test" \
    "expected $DETECTOR_SH (impl lands via separate PR per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc3"
  install_fake_gh "$state/fake_bin" "$state"
  # Only 1 PR in window — below ≥3 threshold
  make_merged_fixture "$state/merged.json" \
    "500:2026-06-27T21:54:34Z"
  run_detector "$state/fake_bin" "$state/merged.json" 500 "2026-06-27T21:54:34Z" "$state/cluster-lag.log"

  if [ "$DET_RC" != "0" ]; then
    fail "TC3 — expected exit 0 silent_skip" \
      "got rc=$DET_RC out=$DET_OUT"
    EXIT_CODE=1
  elif [ -z "$DET_LOG" ]; then
    fail "TC3 — silent_skip log line missing" \
      "expected append to $state/cluster-lag.log (ADR-0048 lens d compliance — silent_skip event)"
    EXIT_CODE=1
  else
    event_type="$(echo "$DET_LOG" | jq -r '.event // empty' 2>/dev/null)"
    reason="$(echo "$DET_LOG" | jq -r '.reason // empty' 2>/dev/null)"
    if [ "$event_type" = "silent_skip" ]; then
      pass "TC3 — single-PR squash → silent_skip event (cluster_size < 3)"
    else
      fail "TC3 — expected silent_skip event" \
        "got: event=$event_type reason=$reason. silent_skip is mandatory per ADR-0048 lens d"
      EXIT_CODE=1
    fi
  fi
fi

# ============================================================================
# TC4: 60s threshold boundary — 2 PRs at 61s gap → silent_skip (false-positive guard)
# ============================================================================
section "TC4: 600s lookback boundary (1 sibling outside 600s window) → silent_skip"
if [ ! -f "$DETECTOR_SH" ]; then
  fail "TC4 — impl missing, cannot test" \
    "expected $DETECTOR_SH (impl lands via separate PR per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc4"
  install_fake_gh "$state/fake_bin" "$state"
  # 3 PRs spanning 61s; current PR = 511 @ 22:00:30 (middle sibling)
  # 600s lookback window from current = [21:50:30, 22:00:30]
  # PR 512 @ 22:01:01 is OUTSIDE lookback window (31s after current) → excluded
  # PR 510 @ 22:00:00 is INSIDE lookback window → counted
  # Result: cluster_size = 2 (current 511 + sibling 510) < threshold 3 → silent_skip
  make_merged_fixture "$state/merged.json" \
    "510:2026-06-27T22:00:00Z" \
    "511:2026-06-27T22:00:30Z" \
    "512:2026-06-27T22:01:01Z"
  run_detector "$state/fake_bin" "$state/merged.json" 511 "2026-06-27T22:00:30Z" "$state/cluster-lag.log"

  if [ "$DET_RC" != "0" ]; then
    fail "TC4 — expected exit 0 silent_skip" \
      "got rc=$DET_RC out=$DET_OUT"
    EXIT_CODE=1
  elif [ -z "$DET_LOG" ]; then
    fail "TC4 — silent_skip log line missing" \
      "expected append to $state/cluster-lag.log"
    EXIT_CODE=1
  else
    event_type="$(echo "$DET_LOG" | jq -r '.event // empty' 2>/dev/null)"
    if [ "$event_type" = "silent_skip" ]; then
      pass "TC4 — sibling outside 600s lookback → silent_skip (boundary respected)"
    else
      fail "TC4 — false-positive cluster detected" \
        "got event=$event_type. 600s lookback must exclude siblings outside [current-600s, current] window"
      EXIT_CODE=1
    fi
  fi
fi

# ============================================================================
# TC5: cluster_lag_seconds metric — max-min delta correct
# ============================================================================
section "TC5: cluster_lag_seconds metric (max-min delta correct)"
if [ ! -f "$DETECTOR_SH" ]; then
  fail "TC5 — impl missing, cannot test" \
    "expected $DETECTOR_SH (impl lands via separate PR per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  state="$TEST_TMPDIR/tc5"
  install_fake_gh "$state/fake_bin" "$state"
  # 4 PRs — known lag = 324s (5m24s) per Issue #508
  make_merged_fixture "$state/merged.json" \
    "506:2026-06-27T21:54:34Z" \
    "507:2026-06-27T21:58:14Z" \
    "508:2026-06-27T21:59:46Z" \
    "509:2026-06-27T22:00:00Z"
  run_detector "$state/fake_bin" "$state/merged.json" 509 "2026-06-27T22:00:00Z" "$state/cluster-lag.log"

  if [ -z "$DET_LOG" ]; then
    fail "TC5 — log line missing, cannot verify metric" \
      "expected cluster_lag_detected event for 4-PR cluster"
    EXIT_CODE=1
  else
    cluster_lag="$(echo "$DET_LOG" | jq -r '.cluster_lag_seconds // empty' 2>/dev/null)"
    pr_numbers="$(echo "$DET_LOG" | jq -r '.pr_numbers | sort | join(",")' 2>/dev/null)"
    if [ "$cluster_lag" = "326" ] && [ "$pr_numbers" = "506,507,508,509" ]; then
      pass "TC5 — cluster_lag_seconds=326s correct (max-min delta 22:00:00Z − 21:54:34Z)"
    else
      fail "TC5 — cluster_lag metric mismatch" \
        "expected cluster_lag_seconds=326 pr_numbers=506,507,508,509. got: cluster_lag=$cluster_lag prs=$pr_numbers"
      EXIT_CODE=1
    fi
  fi
fi

# ============================================================================
# TC6: malformed merged.json → exit 2 (F3 fix per ADR-0056 Option X)
# ============================================================================
section "TC6: malformed merged.json (object not array, missing fields) → exit 2"
if [ ! -f "$DETECTOR_SH" ]; then
  fail "TC6 — impl missing, cannot test" \
    "expected $DETECTOR_SH (impl lands via separate PR per ADR-0044 RED-first)"
  EXIT_CODE=1
else
  # Sub-case A: object (not array) → jq validation rejects
  state_a="$TEST_TMPDIR/tc6a"
  install_fake_gh "$state_a/fake_bin" "$state_a"
  echo '{"number":500,"mergedAt":"2026-06-27T21:54:34Z"}' > "$state_a/merged.json"  # object, not array
  run_detector "$state_a/fake_bin" "$state_a/merged.json" 500 "2026-06-27T21:54:34Z" "$state_a/cluster-lag.log"

  if [ "$DET_RC" != "2" ]; then
    fail "TC6 — expected exit 2 on object (not array)" \
      "got rc=$DET_RC. F3 fix per ADR-0056 Option X requires explicit jq error → exit 2"
    EXIT_CODE=1
  else
    # Sub-case B: array missing required field → jq validation rejects
    state_b="$TEST_TMPDIR/tc6b"
    install_fake_gh "$state_b/fake_bin" "$state_b"
    echo '[{"number":500}]' > "$state_b/merged.json"  # missing mergedAt
    run_detector "$state_b/fake_bin" "$state_b/merged.json" 500 "2026-06-27T21:54:34Z" "$state_b/cluster-lag.log"

    if [ "$DET_RC" != "2" ]; then
      fail "TC6 — expected exit 2 on array missing mergedAt field" \
        "got rc=$DET_RC. F3 fix per ADR-0056 Option X requires explicit jq error → exit 2"
      EXIT_CODE=1
    else
      pass "TC6 — malformed merged.json (object + missing field) → exit 2 (F3 fix per ADR-0056 Option X)"
    fi
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
  printf "\n${R}RED state: %d TC(s) FAILING — impl missing or buggy per ADR-0044 RED-first${D}\n" "$FAIL"
  exit 1
fi

printf "\n${G}GREEN state: all 6 TCs PASS — cluster-lag-detector impl correct (5 original + TC6 F3 fix)${D}\n"
exit 0
