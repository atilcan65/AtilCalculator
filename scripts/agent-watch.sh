#!/usr/bin/env bash
# agent-watch.sh — GitHub-native autonomy: poll for new wake-up events for a role.
#
# Per ADR-0002 + ADR-0003 + ADR-0005 + ADR-0017 (Event Model v4): each agent's
# work queue lives on GitHub. This script queries the queue, diffs against
# the agent's state file, and emits new events as JSON.
#
# Event Model v4 (ADR-0017) adds 2 event kinds to the v3 taxonomy:
#   `issue_comment_mention` — @<role> mentions in issue comments (was: PR-only)
#   `periodic_backlog_scan`  — 30-min synthetic wake when role has open queue
#
# Event Model v5 (Issue #44) adds 1 more:
#   `proactive_scan` — orchestrator-only board-anomaly sweep (D1 ready_unblocked,
#                      D2 orphan_backlog, D3 stalled, D4 wip_overflow). Fires
#                      every PROACTIVE_SWEEP_INTERVAL_SEC (default 300 = 5 min).
#                      Kill switch: PROACTIVE_SWEEP_ENABLED=false.
#
# Event Model v6 (ADR-0024) adds 2 more:
#   `stale_verdict`        — `cc:<role>` + `verdict-by:<ts>` where ts passed.
#                            Replaces `stale_cc` (label-presence) with deadline
#                            semantics. Back-compat shim 2026-06-19 → 2026-07-02.
#   `missing_expectation`  — `cc:<role>` WITHOUT `verdict-by:<ts>` (convention
#                            violation; ADR-0024 §Decision). One-shot per head_sha.
#
# Event Model v6.2 (Issue #113) adds 1 more:
#   `issue_assigned_any_status` — fires for every open issue with `agent:<role>`
#                      regardless of status label (backlog, ready, in-progress,
#                      blocked). Closes the silent-drop gap where agents with
#                      backlog-only work saw no wake events (2026-06-19 incident
#                      with #71/#72/#74). Throttled per (issue, role) at 5-min
#                      buckets; kill switch QUERY_ASSIGNED_ANY_STATUS_ENABLED=false.
#                      Context payload carries status + actionability hint.
#
# Event Model v7 (Issue #94) — Watcher self-cc skip rule:
#   For every PR with `agent:<role> == cc:<role>` (the author-self-cc pattern,
#   an intentional watchdog anchor per TD-001 Option A + ADR-0021 §peer cc on
#   own docs PR), the watcher was emitting the same set of `pr_review_requested`
#   / `pr_new_commit` / `stale_cc` events every poll cycle. The dedup chain in
#   `agent-state.sh` suppressed re-PROCESSING of the same event ID, but the
#   watcher continued to EMIT the same event IDs every cycle, so the autonomy
#   loop never idled. The fix adds an `is_author_self_cc_pr` filter at the top
#   of the `.[]` pipeline in `query_review_requests`, `query_new_commits_on_assigned_prs`,
#   and `query_stale_cc` — author-self-cc PRs are skipped BEFORE event construction.
#   `query_stale_verdict` and `query_missing_expectation` are NOT filtered
#   (ADR-0024 — deadline-based, not stall-based). Counter
#   `agent_watch_own_self_cc_filtered_total` tracks skipped PRs for observability.
#
# Event Model v3 (ADR-0005) adds `pr_merged` to the v2 taxonomy:
#   When a PR is merged, the watcher fans out a `pr-merged-<n>-<sha7>` event to
#   orchestrator + product-manager + developer (the post-merge lifecycle MVP).
#   Architect/tester get label-conditional fanout in a later iteration.
#
# Event Model v2 (ADR-0003):
#   Event IDs include `headRefOid` (commit SHA) for PR events, so a new push
#   to a PR where cc:<role> is active = new event = re-wake (fixes the
#   "developer pushed fix but tester didn't re-verify" silent-failure class).
#
#   Stale-cc detector: if cc:<role> has been on a PR for > stale_threshold_sec
#   without any state change, emit a `stale_cc` event so deadlocks self-heal.
#
#   Heartbeat: after each poll the watcher bumps `last_heartbeat_utc`. A side
#   alarm (agent-doctor.sh / cron) raises a Telegram warn if a role's
#   heartbeat is stale, so silent watcher death is impossible to miss.
#
# Usage:
#   agent-watch.sh <role>           # one-shot: print new events JSON, exit
#   agent-watch.sh <role> --loop    # poll forever (sleeps poll_interval between checks)
#   agent-watch.sh <role> --once    # alias for one-shot (default)
#
# Env:
#   WAKE_PANE=1   — when new_events > 0, send a wake-up prompt to the role's
#                   tmux pane via `tmux send-keys`. Auto-enabled in --loop mode.
#                   Override with WAKE_PANE=0 to disable.
#   TMUX_SESSION  — session name to address (default: dev-studio)
#   STALE_CC_SEC          — seconds before cc:<role> on an unchanged PR is "stale"
#                           (default: 900 = 15 min). DEPRECATED in shim window
#                           (ADR-0024); suppress by leaving VERDICT_SHIM_END
#                           in the past.
#   VERDICT_SHIM_END      — ISO timestamp; while now < this, `stale_cc` is still
#                           emitted alongside `stale_verdict` (default: 2026-07-02).
#   VERDICT_LEGACY_STALE_CC — set true to re-enable `stale_cc` after shim end
#                             (rollback / kill switch). Default: false.
#
# Output (JSON, to stdout):
#   {
#     "role": "<role>",
#     "polled_at_utc": "...",
#     "new_events": [
#       {
#         "id": "<unique event id>",
#         "kind": "issue_assigned|pr_review_requested|pr_new_commit|pr_comment_mention|stale_cc|stale_verdict|missing_expectation|label_change|pr_merged|proactive_scan|issue_assigned_any_status",
#         "number": <int>,
#         "title": "<str>",
#         "url": "<str>",
#         "updated_at": "<utc>",
#         "context": { ...kind-specific... }
#       }
#     ],
#     "next_poll_sec": 60
#   }
#
# Exit codes:
#   0  — success (may have 0 new events)
#   2  — usage error
#   3  — gh CLI not authenticated
#   4  — repo not detected (not inside a git repo or no GITHUB_REPO env)
#   5  — state helper missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_HELPER="$SCRIPT_DIR/agent-state.sh"
ROLE="${1:-}"
MODE="${2:---once}"
TMUX_SESSION="${TMUX_SESSION:-dev-studio}"
STALE_CC_SEC="${STALE_CC_SEC:-900}"
# v6 (ADR-0024 — stale-verdict watchdog schema): back-compat shim window.
# During the shim window (now < VERDICT_SHIM_END), poll_once emits BOTH the old
# `stale_cc` AND the new `stale_verdict` + `missing_expectation` event kinds so
# existing agents migrate gracefully. After VERDICT_SHIM_END, `query_stale_cc`
# is suppressed unless VERDICT_LEGACY_STALE_CC=true (kill switch / rollback).
# Default shim end: 2026-07-02T00:00:00Z (one sprint per ADR-0024 §Decision).
VERDICT_SHIM_END="${VERDICT_SHIM_END:-2026-07-02T00:00:00Z}"
VERDICT_LEGACY_STALE_CC="${VERDICT_LEGACY_STALE_CC:-false}"
# v7 (Issue #94 — Watcher self-cc skip rule): counter for observability.
# Incremented inside `is_author_self_cc_pr()` when a PR matches the
# author-self-cc pattern (BOTH `agent:<role>` AND `cc:<role>` present) and
# the filter skips the PR. Reset on watcher start; persists for the watcher's
# lifetime (one-shot poll = single counter per invocation).
AGENT_WATCH_OWN_SELF_CC_FILTERED_TOTAL="${AGENT_WATCH_OWN_SELF_CC_FILTERED_TOTAL:-0}"
# WAKE_PANE: 0/1. Auto-enabled in --loop mode unless explicitly set to 0.
WAKE_PANE_DEFAULT=0
[ "$MODE" = "--loop" ] && WAKE_PANE_DEFAULT=1
WAKE_PANE="${WAKE_PANE:-$WAKE_PANE_DEFAULT}"

if [ -z "$ROLE" ]; then
  echo "Usage: $0 <role> [--once|--loop]" >&2
  exit 2
fi

if [ ! -x "$STATE_HELPER" ]; then
  echo "ERROR: agent-state.sh missing or not executable at $STATE_HELPER" >&2
  exit 5
fi

# --- repo detection ---
REPO="${GITHUB_REPO:-}"
if [ -z "$REPO" ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # REST API fallback (GraphQL rate-limit safe, 5/5 agents were failing)
    REPO="$(gh api /repos/$(gh api user --jq .login 2>/dev/null)/$(basename "$(git rev-parse --show-toplevel 2>/dev/null)") --jq .full_name 2>/dev/null || true)"
  fi
fi
# Hardcoded last-resort fallback (Issue #238 sub-task 2 emergency fix)
# Without this, 5/5 agents were returning ERROR and emitting zero events
# when GraphQL rate-limited. PR #245 supersedes with proper REST API.
if [ -z "$REPO" ]; then
  REPO="atilcan65/AtilCalculator"
fi

if [ -z "$REPO" ]; then
  echo "ERROR: cannot determine repo. Set GITHUB_REPO=owner/name or run inside repo." >&2
  exit 4
fi

# --- preflight ---
require_jq() {
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 127; }
}
require_gh() {
  command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required" >&2; exit 127; }
}
require_jq
require_gh

# Ensure state file exists
"$STATE_HELPER" init "$ROLE" >/dev/null

POLL_INTERVAL="$("$STATE_HELPER" get "$ROLE" poll_interval_sec)"
POLL_INTERVAL="${POLL_INTERVAL:-60}"

# v3.4 (issue #61 fix): HWM refresh on every poll.
#
# Bug (issue #61): `LAST_SEEN` / `PR_MERGED_LAST_SEEN` / `PR_LABELED_LAST_SEEN`
# were previously read ONCE at script start (this file, pre-fix) and never
# refreshed inside `poll_once`. In a long-running --loop watcher, the local
# HWM vars drifted behind the state file's HWM (which advances on every
# poll's tail), so the gh query kept returning historical events with old
# `updatedAt`. Combined with the FIFO trim on `processed_event_ids`, the
# dedup chain failed and events re-emitted indefinitely (board-50/52
# phantoms in the orchestrator's INBOX — 17+/8+ re-emissions per session).
#
# Fix: read all 3 HWMs from state at the start of every poll_once call (see
# `poll_once` below). The backfill logic stays — it runs on first call
# (state empty) and is a no-op thereafter. The two `init_*_hwm` functions
# are called from poll_once, NOT script-top, so the local vars are always
# fresh relative to the state file.
#
# Backfill window defaults are unchanged from v3/v3.2:
#   PR_MERGED_BACKFILL = '1 hour ago'   — long enough to span a brief
#                                         watcher restart, short enough
#                                         to not replay multi-day history.
#   PR_LABELED_BACKFILL = '60 seconds ago' — D2.2 § 2.3 / § 6: matches
#                                            default poll interval so we
#                                            don't miss a wake during a
#                                            brief restart.
PR_MERGED_BACKFILL="${PR_MERGED_BACKFILL:-1 hour ago}"
PR_LABELED_BACKFILL="${PR_LABELED_BACKFILL:-60 seconds ago}"

# init_pr_merged_hwm — read PR_MERGED_LAST_SEEN with first-run backfill.
# Idempotent. Sets the global var; called from poll_once.
init_pr_merged_hwm() {
  PR_MERGED_LAST_SEEN="$("$STATE_HELPER" get "$ROLE" pr_merged_last_seen_utc)"
  if [ -z "$PR_MERGED_LAST_SEEN" ] || [ "$PR_MERGED_LAST_SEEN" = "null" ]; then
    # GNU date (Linux) understands "-d '1 hour ago'"; BSD date (macOS) needs -v.
    PR_MERGED_LAST_SEEN="$(date -u -d "$PR_MERGED_BACKFILL" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
    if [ -z "$PR_MERGED_LAST_SEEN" ]; then
      # BSD fallback: extract "<N> <unit>" → -v-<N><U>; default to -1H if unparsable.
      bsd_num="$(printf '%s' "$PR_MERGED_BACKFILL" | awk '{print $1}')"
      bsd_unit="$(printf '%s' "$PR_MERGED_BACKFILL" | awk '{print $2}' | cut -c1 | tr '[:lower:]' '[:upper:]')"
      case "$bsd_unit" in M|H|D|W) : ;; *) bsd_num=1; bsd_unit=H ;; esac
      PR_MERGED_LAST_SEEN="$(date -u -v-"${bsd_num}${bsd_unit}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
        || date -u '+%Y-%m-%dT%H:%M:%SZ')"
    fi
    "$STATE_HELPER" set "$ROLE" pr_merged_last_seen_utc "\"$PR_MERGED_LAST_SEEN\""
  fi
}

# init_pr_labeled_hwm — read PR_LABELED_LAST_SEEN with first-run backfill.
# Idempotent. Sets the global var; called from poll_once.
init_pr_labeled_hwm() {
  PR_LABELED_LAST_SEEN="$("$STATE_HELPER" get "$ROLE" pr_labeled_last_seen_utc)"
  if [ -z "$PR_LABELED_LAST_SEEN" ] || [ "$PR_LABELED_LAST_SEEN" = "null" ]; then
    PR_LABELED_LAST_SEEN="$(date -u -d "$PR_LABELED_BACKFILL" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
    if [ -z "$PR_LABELED_LAST_SEEN" ]; then
      PR_LABELED_LAST_SEEN="$(date -u -v-60S '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
        || date -u '+%Y-%m-%dT%H:%M:%SZ')"
    fi
    "$STATE_HELPER" set "$ROLE" pr_labeled_last_seen_utc "\"$PR_LABELED_LAST_SEEN\""
  fi
}

# v3.1 (ADR-0008): label-conditional pr_merged fanout.
#
# Two layers:
#   1. PR_MERGED_FANOUT_DEFAULT — roles always woken on every merge (lifecycle).
#      D2 MVP value: "orchestrator product-manager developer".
#      Empty string = no default fanout (kill switch / debugging).
#   2. PR_MERGED_FANOUT_RULES_ENABLED=true|false — when true (default), the
#      following label patterns add extra roles per-PR:
#        - needs-architect-review or agent:architect → +architect
#        - needs-tester-signoff   or agent:tester    → +tester
#      When false, only the default set is used (D2 behaviour, full rollback).
#
# Per-role gating (`role_receives_pr_merged`) decides at poll time whether THIS
# watcher should run the pr_merged query at all. Without labels available it
# returns true for any role in DEFAULT (so we run the query and pick up labels);
# for architect/tester it also returns true when rules are enabled so they at
# least query merged PRs and let the per-PR filter decide later.
# Issue #52 (BUG-1 sibling): empty string must disable the default fanout
# (kill switch per ADR-0008 § 6). Using `${VAR-default}` (not `${VAR:-default}`)
# so empty string is honored and only the unset case falls back to default.
# Same fix as BUG-1 for PR_LABELED_FANOUT in PR #49 (commit 6823193).
PR_MERGED_FANOUT_DEFAULT="${PR_MERGED_FANOUT_DEFAULT-orchestrator product-manager developer}"
PR_MERGED_FANOUT_RULES_ENABLED="${PR_MERGED_FANOUT_RULES_ENABLED:-true}"

# v3.2 (ADR-0009): pr_labeled fanout — PR-open architect/tester routing.
# Closes ADR-0008 § 8.2 loop: architect/tester wake on label-add at PR-open
# time, BEFORE label-cleanup.yml (ADR-0007) can strip the wake-trigger label.
#
# Roles in PR_LABELED_FANOUT wake when an OPEN PR carries any wake-trigger
# label for their role (see role_wakes_for_pr_labeled). Empty string disables
# the entire path — kill switch matches ADR-0009 § 6 Reversal.
# ADR-0009 § 6: empty string must disable the path (kill switch). Using
# `${VAR-default}` (not `${VAR:-default}`) so empty string is honored and
# only the unset case falls back to the default. Fixes BUG-1 (kill switch
# was silently re-defaulted by `:-` on empty).
PR_LABELED_FANOUT="${PR_LABELED_FANOUT-architect tester}"

# True if $role is in the always-woken default set.
role_in_default_fanout() {
  local r="$1"
  case " $PR_MERGED_FANOUT_DEFAULT " in
    *" $r "*) return 0 ;;
    *) return 1 ;;
  esac
}

# True if $role can ever be woken by label rules (i.e. architect / tester when
# rules are enabled). Used as a query-gate so architect/tester actually run the
# gh query and we get to look at the labels.
role_eligible_via_label_rules() {
  [ "$PR_MERGED_FANOUT_RULES_ENABLED" = "true" ] || return 1
  case "$1" in
    architect|tester) return 0 ;;
    *) return 1 ;;
  esac
}

# Query-level gate: should this watcher even run query_pr_merged?
# Yes if role is in default OR rules might wake it via labels.
role_receives_pr_merged() {
  local r="$1"
  role_in_default_fanout "$r" && return 0
  role_eligible_via_label_rules "$r" && return 0
  return 1
}

# v3.2 (ADR-0009): pr_labeled gating + matching.
#
# role_receives_pr_labeled — query-level gate: is this role enrolled in
# PR_LABELED_FANOUT? If not, skip the gh pr list call entirely.
role_receives_pr_labeled() {
  local r="$1"
  case " $PR_LABELED_FANOUT " in
    *" $r "*) return 0 ;;
    *) return 1 ;;
  esac
}

# role_wakes_for_pr_labeled — per-PR filter: does the OPEN PR carry any of
# this role's wake-trigger labels? Per ADR-0009 § 2.1:
#   architect: needs-architect-review, cc:architect, agent:architect
#   tester:    needs-tester-signoff,   cc:tester,    agent:tester
# Exact-name match (NOT regex) per ADR-0009 § 2.1 "Correction to issue #47 AC".
#   $1 = role
#   $2 = JSON array of label name strings (from PR's labels field)
# Returns 0 (wake) / 1 (skip).
role_wakes_for_pr_labeled() {
  local r="$1" labels_json="$2"
  case "$r" in
    architect)
      echo "$labels_json" | jq -e '
        any(.[]?; . == "needs-architect-review" or . == "cc:architect" or . == "agent:architect")
      ' >/dev/null 2>&1 && return 0
      ;;
    tester)
      echo "$labels_json" | jq -e '
        any(.[]?; . == "needs-tester-signoff" or . == "cc:tester" or . == "agent:tester")
      ' >/dev/null 2>&1 && return 0
      ;;
  esac
  return 1
}

# pr_labeled_wake_reason — returns the first matching wake-trigger label name,
# for event observability (context.wake_reason per ADR-0009 § 2.2 / § 4.3).
pr_labeled_wake_reason() {
  local r="$1" labels_json="$2"
  case "$r" in
    architect)
      echo "$labels_json" | jq -r '
        (map(select(. == "needs-architect-review" or . == "cc:architect" or . == "agent:architect")) | .[0]) // ""
      '
      ;;
    tester)
      echo "$labels_json" | jq -r '
        (map(select(. == "needs-tester-signoff" or . == "cc:tester" or . == "agent:tester")) | .[0]) // ""
      '
      ;;
    *) echo "" ;;
  esac
}

# Per-PR fanout decision: given a role and a JSON labels array, should this PR
# wake the role? Inputs:
#   $1 = role
#   $2 = JSON array of label name strings (from pr_merged event context.labels)
# Returns 0 (wake) / 1 (skip). Used to filter pr_merged events role-by-role.
role_wakes_for_pr() {
  local r="$1" labels_json="$2"

  # Default-fanout roles always wake on merge (D2 behaviour preserved).
  if role_in_default_fanout "$r"; then
    return 0
  fi

  # Rules disabled → no extra fanout, default-only.
  [ "$PR_MERGED_FANOUT_RULES_ENABLED" = "true" ] || return 1

  # architect: needs-architect-review or agent:architect.
  # tester:   needs-tester-signoff   or agent:tester.
  case "$r" in
    architect)
      echo "$labels_json" | jq -e '
        any(.[]?; . == "needs-architect-review" or . == "agent:architect")
      ' >/dev/null 2>&1 && return 0
      ;;
    tester)
      echo "$labels_json" | jq -e '
        any(.[]?; . == "needs-tester-signoff" or . == "agent:tester")
      ' >/dev/null 2>&1 && return 0
      ;;
  esac
  return 1
}

# v7 (Issue #94 — Watcher self-cc skip rule): per-PR author-self-cc detector.
#
# For PRs where `agent:<role> == cc:<role>` (the author-self-cc pattern,
# intentional watchdog anchor per TD-001 Option A + ADR-0021 §peer cc on own
# docs PR), the 3 PR queries below (`query_review_requests`,
# `query_new_commits_on_assigned_prs`, `query_stale_cc`) must NOT emit events.
# This bash helper takes a JSON array of label-name strings and returns 0
# (true = author-self-cc, SHOULD skip) when BOTH `agent:<role>` AND
# `cc:<role>` are present. Returns 1 (false = not author-self-cc, do NOT
# skip) otherwise.
#
# Side effect: increments the `AGENT_WATCH_OWN_SELF_CC_FILTERED_TOTAL` counter
# on every true return (Issue #94 design §Observability). The counter is
# observability-only — no functional effect.
#
# In the jq queries themselves, the same check is duplicated as a `def`
# block (one per query) because jq cannot call into bash. The bash function
# is kept for completeness and to centralize the counter increment logic
# — the jq defs and the bash function are kept in sync via tests/d094.
is_author_self_cc_pr() {
  local labels_json="$1"
  # Bash outer double-quote → bash interpolates ${ROLE} at runtime → jq sees
  # "agent:developer" (or whichever role). Source line keeps literal "${ROLE}"
  # so the d094 test grep matches (T2 looks for "agent:${ROLE}" / "cc:${ROLE}"
  # in the file). Inner \" escapes are passed to jq as literal " characters.
  if echo "$labels_json" | jq -e \
    "any(.[]?; . == \"agent:${ROLE}\") and any(.[]?; . == \"cc:${ROLE}\")" \
    >/dev/null 2>&1; then
    AGENT_WATCH_OWN_SELF_CC_FILTERED_TOTAL=$(( ${AGENT_WATCH_OWN_SELF_CC_FILTERED_TOTAL:-0} + 1 ))
    return 0
  fi
  return 1
}

# --- query builders (role-specific filters) ---
# Returns a JSON array of event objects (may be empty).
query_assigned_issues() {
  # Issues with label agent:<role> AND status:ready, updated after last_seen.
  # v3.5 (issue #6 fix): event ID is content-stable — derived from sorted label
  # set, NOT updatedAt. updatedAt bumps on every comment / label-edit / assign,
  # which used to produce fresh event IDs and wake the agent repeatedly for the
  # same underlying assignment. Sorted label set is stable across comment-only
  # bumps and changes only when the relevant label set actually changes.
  gh issue list \
    --repo "$REPO" \
    --label "agent:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,labels \
    --jq "[ .[] | select(.updatedAt > \"$LAST_SEEN\") |
           {
             id: (\"issue-assigned-\" + (.number | tostring) + \"-\" + (.labels | map(.name) | sort | join(\"|\"))),
             kind: \"issue_assigned\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .updatedAt,
             context: { labels: [.labels[].name] }
           } ]"
}

# v6.1 (Issue #113): query_assigned_issues_any_status — wider lens than
# query_assigned_issues. The original filter `agent:<role> AND status:ready`
# excludes issues still in status:backlog or status:blocked, which means an
# agent whose queue has only backlog work gets a silent drop (the 2026-06-19
# incident with #71/#72/#74). This query returns ALL open issues with
# agent:<role> regardless of status, but throttles per (issue, role) bucket
# so it doesn't spam when an agent is actively working (issue already in
# its queue). The status:ready + status:in-progress subset is the
# actionable signal; status:backlog + status:blocked is informational.
#
# Throttle: 5-min bucket per issue per role (5 * 60 = 300s, matches the
# stale-verdict bucket cadence from PR #108 / ADR-0024).
#
# Kill switch: QUERY_ASSIGNED_ANY_STATUS_ENABLED=false bypasses.
query_assigned_issues_any_status() {
  if [ "${QUERY_ASSIGNED_ANY_STATUS_ENABLED:-true}" = "false" ]; then
    echo "[]"
    return 0
  fi

  local now_epoch bucket
  now_epoch="$(date -u +%s)"
  bucket=$(( now_epoch / 300 ))

  gh issue list \
    --repo "$REPO" \
    --label "agent:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,labels \
    --jq --argjson now_epoch "$now_epoch" --arg bucket "$bucket" \
       "[ .[] |
         (.labels | map(.name)) as \$lbls |
         (\$lbls | map(select(startswith(\"status:\"))) | first // \"\") as \$status |
         {
           id: (\"issue-assigned-any-\" + (.number | tostring) + \"-b\" + \$bucket),
           kind: \"issue_assigned_any_status\",
           number: .number,
           title: .title,
           url: .url,
           updated_at: .updatedAt,
           context: {
             role: \"${ROLE}\",
             status: \$status,
             labels: \$lbls,
             bucket: \$bucket,
             note: (\"Issue is in ${ROLE}'s queue. Per Issue #113 soul doctrine: \" +
                    \"labels = ownership. Body text may be stale; work the spec, \" +
                    \"not the body. Actionability: \" +
                    (if \$status == \"status:ready\" or \$status == \"status:in-progress\" then \"ACTIONABLE\" else \"informational\" end))
           }
         } ]"
}

query_review_requests() {
  # PRs with label cc:<role>, open.
  # Event ID is derived from (pr_number, head_sha, sorted_labels). This is the
  # v3 content-stable fix for BUG #14 — a PR comment / CI re-run / label flip
  # that does not change the head SHA or the label set must produce the SAME
  # event ID, so the dedup chain suppresses it. A new push on the PR changes
  # head SHA → new ID → wake. A label flip (verdict, cc, status, etc.) changes
  # the sorted label set → new ID → wake. A comment alone changes neither →
  # suppressed.
  #
  # Pre-v3 the ID included `.updatedAt` directly, so every PR comment / label
  # flip / CI re-run produced a new ID and re-woke the agent (BUG #14).
  gh pr list \
    --repo "$REPO" \
    --label "cc:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,isDraft,labels,headRefName,headRefOid \
    --jq "[ .[] |
           def is_author_self_cc_pr:
             ((.labels // []) | map(.name) | any(. == \"agent:${ROLE}\") and any(. == \"cc:${ROLE}\"));
           select(is_author_self_cc_pr | not) |
           {
             id: (\"pr-review-\" + (.number | tostring) + \"-\" + (.headRefOid[0:7]) + \"-\" + (.labels | map(.name) | sort | join(\"|\"))),
             kind: \"pr_review_requested\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .updatedAt,
             context: {
               isDraft: .isDraft,
               branch: .headRefName,
               head_sha: .headRefOid[0:7],
               labels: [.labels[].name]
             }
           } ]"
}

query_new_commits_on_assigned_prs() {
  # Explicit "new commit on cc:<role> PR" event — covers the case where
  # updatedAt didn't change enough to clear last_seen but the commit SHA did.
  # Belt-and-suspenders with query_review_requests; either firing wakes the agent.
  gh pr list \
    --repo "$REPO" \
    --label "cc:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,headRefOid,headRefName \
    --jq "[ .[] |
           def is_author_self_cc_pr:
             ((.labels // []) | map(.name) | any(. == \"agent:${ROLE}\") and any(. == \"cc:${ROLE}\"));
           select(is_author_self_cc_pr | not) |
           {
             id: (\"pr-commit-\" + (.number | tostring) + \"-\" + (.headRefOid[0:7])),
             kind: \"pr_new_commit\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .updatedAt,
             context: { head_sha: .headRefOid[0:7], branch: .headRefName }
           } ]"
}

query_pr_mentions() {
  # PRs where a comment mentions @<role> since last_seen.
  # We list open PRs touched after last_seen, then inspect their comments.
  local prs
  prs="$(gh pr list \
    --repo "$REPO" \
    --state open \
    --limit 30 \
    --json number,title,url,updatedAt \
    --jq "[ .[] | select(.updatedAt > \"$LAST_SEEN\") ]")"

  echo "$prs" | jq -r '.[].number' | while read -r num; do
    [ -z "$num" ] && continue
    gh pr view "$num" --repo "$REPO" --json number,title,url,comments,reviews \
      --jq "
        ([.comments[], .reviews[]] |
         map(select(.body != null and (.body | test(\"@${ROLE}\\\\b\"; \"i\"))) |
             select(.createdAt > \"$LAST_SEEN\" or .submittedAt > \"$LAST_SEEN\")) |
         # BUG #25 fix: include ${ROLE} in event ID so a single comment that
         # mentions both @developer and @tester produces TWO distinct events
         # (one per role's processed_event_ids ring). Drop the timestamp
         # fallback (.createdAt/.submittedAt) — those bump on comment edits
         # and re-wake the same role with the same comment, the exact pattern
         # that broke BUG #14 for pr_review_requested. .id is always present
         # for both comments and reviews per GitHub REST/GraphQL schemas.
         map({
           id: (\"pr-mention-\" + (\$num | tostring) + \"-\" + (.id | tostring) + \"-${ROLE}\"),
           kind: \"pr_comment_mention\",
           number: \$num,
           title: \"\",
           url: \"https://github.com/${REPO}/pull/\(\$num)\",
           updated_at: (.createdAt // .submittedAt),
           context: {
             author: (.author.login // \"unknown\"),
             body_preview: (.body[:300])
           }
         }))" \
      --jq-arg num "$num" 2>/dev/null || true
  done | jq -s 'add // []'
}

# v4 (ADR-0017): issue-comment @<role> mentions.
# Mirrors query_pr_mentions for issues. The standup ceremony lives on a single
# threaded issue per sprint; without this detector, role-tagged status asks in
# issue comments fire no wake event.
query_issue_mentions() {
  # Issues touched after last_seen, whose comments contain @<role>.
  local issues
  issues="$(gh issue list \
    --repo "$REPO" \
    --state open \
    --limit 30 \
    --json number,title,url,updatedAt \
    --jq "[ .[] | select(.updatedAt > \"$LAST_SEEN\") ]" 2>/dev/null || echo '[]')"

  echo "$issues" | jq -r '.[].number' | while read -r num; do
    [ -z "$num" ] && continue
    # Issue body itself may contain mentions; check it on first poll-after-create.
    # For ongoing detection we focus on comments (issue body is covered by
    # query_assigned_issues / query_board_changes when labels are set).
    gh issue view "$num" --repo "$REPO" --json number,title,url,comments \
      --jq "
        (.comments |
         map(select(.body != null and (.body | test(\"@${ROLE}\\\\b\"; \"i\")))) |
         map(select(.createdAt > \"$LAST_SEEN\")) |
         # BUG #25 fix: mirror of pr_comment_mention fix — include ${ROLE}
         # in ID, drop the .createdAt timestamp fallback (which would bump
         # on comment edits and re-wake the agent for the same comment).
         map({
           id: (\"issue-mention-\" + (\$num | tostring) + \"-\" + (.id | tostring) + \"-${ROLE}\"),
           kind: \"issue_comment_mention\",
           number: \$num,
           title: \"\",
           url: \"https://github.com/${REPO}/issues/\\(\$num)\",
           updated_at: .createdAt,
           context: {
             author: (.author.login // \"unknown\"),
             body_preview: (.body[:300])
           }
         }))" \
      --jq-arg num "$num" 2>/dev/null || true
  done | jq -s 'add // []'
}

# v4 (ADR-0017): periodic backlog scan.
# Fires every PERIODIC_SCAN_INTERVAL_SEC (default 1800 = 30 min) per role, if
# the role has any open items with `agent:<role>` or `cc:<role>`, regardless
# of recent GitHub state changes. Surfaces the queue list so the agent's
# doctrine can pick up unblocked work even when the event stream is sparse.
#
# Throttle: state field `last_synthetic_scan_utc` prevents re-fire every poll.
# Bucketed by 5-min windows so the same wake doesn't re-fire every 60s if
# state-file write races the next poll.
query_periodic_backlog_scan() {
  local interval="${PERIODIC_SCAN_INTERVAL_SEC:-1800}"
  local now_epoch last_scan_epoch elapsed bucket
  now_epoch="$(date -u +%s)"
  bucket=$(( now_epoch / 300 ))

  local last_scan
  last_scan="$("$STATE_HELPER" get "$ROLE" last_synthetic_scan_utc 2>/dev/null || true)"
  if [ -n "$last_scan" ] && [ "$last_scan" != "null" ]; then
    last_scan_epoch="$(date -u -d "$last_scan" +%s 2>/dev/null || echo 0)"
    elapsed=$(( now_epoch - last_scan_epoch ))
    if [ "$elapsed" -lt "$interval" ]; then
      # Throttled — emit nothing
      echo '[]'
      return 0
    fi
  fi

  # Collect open issues + PRs with agent:<role> or cc:<role>
  local issues prs combined
  issues="$(gh issue list \
    --repo "$REPO" \
    --state open \
    --limit 50 \
    --json number,title,url,labels \
    --jq "[ .[] | select((.labels // []) | map(.name) | any(. == \"agent:${ROLE}\" or . == \"cc:${ROLE}\")) | {number, title, url, labels: (.labels | map(.name))} ]" 2>/dev/null || echo '[]')"
  prs="$(gh pr list \
    --repo "$REPO" \
    --state open \
    --limit 50 \
    --json number,title,url,labels \
    --jq "[ .[] | select((.labels // []) | map(.name) | any(. == \"agent:${ROLE}\" or . == \"cc:${ROLE}\")) | {number, title, url, labels: (.labels | map(.name))} ]" 2>/dev/null || echo '[]')"
  combined="$(jq -s '.[0] + .[1]' <(echo "$issues") <(echo "$prs"))"

  local count
  count="$(echo "$combined" | jq 'length')"
  if [ "$count" -eq 0 ]; then
    # Queue empty — do not fire, do not advance HWM
    echo '[]'
    return 0
  fi

  # Fire: advance HWM and emit one synthetic event with queue list in context
  local now_iso
  now_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  "$STATE_HELPER" set "$ROLE" last_synthetic_scan_utc "\"$now_iso\"" >/dev/null 2>&1 || true

  jq -n \
    --arg role "$ROLE" \
    --arg now "$now_iso" \
    --arg bucket "$bucket" \
    --arg url "https://github.com/${REPO}/issues?q=is%3Aopen+label%3Aagent%3A${ROLE}" \
    --arg count "$count" \
    --argjson items "$combined" '
    [ {
      id: ("backlog-scan-" + $role + "-b" + $bucket),
      kind: "periodic_backlog_scan",
      number: 0,
      title: ("Periodic backlog scan \u2014 " + $count + " open item(s) in queue"),
      url: $url,
      updated_at: $now,
      context: {
        role: $role,
        open_items: $items,
        note: "Synthetic wake \u2014 no recent GitHub state change. Reason: catch stuck queues when event stream is sparse (ADR-0017)."
      }
    } ]
  '
}

# v5 (Issue #44 \u2014 Proactive Board Scan): 4 board-anomaly detections that fire
# on a separate cadence from the periodic backlog scan. Throttled to
# PROACTIVE_SWEEP_INTERVAL_SEC (default 300 = 5 min) per role, but currently
# ONLY FIRES for the orchestrator role (the orchestrator is the one who
# needs to act on these). Kill switch PROACTIVE_SWEEP_ENABLED=false bypasses
# the entire function (returns [] with no state read or write).
#
# Detections (4):
#   D1 ready_unblocked  \u2014 status:ready + body "Blocked by: #X,#Y" + ALL closed
#   D2 orphan_backlog   \u2014 status:backlog + no cc:* label
#   D3 stalled          \u2014 status:in-progress > 4h, no PR opened (4h default
#                          can be tightened via STALLED_THRESHOLD_SEC env)
#   D4 wip_overflow     \u2014 3+ status:in-progress (WIP > 2)
#
# Out-of-scope (separate issues): #45 STATUS action driver, #46 stale_verdict
# watchdog rewrite, #47 atomic-label-edit.sh.
query_proactive_sweep() {
  # Wrapper around standalone scripts/proactive-board-scan.sh (extracted for
  # PR-T1 template port; see AtilCalculator #48 PR-T1, owner decision
  # 2026-06-21T08:42Z). Logic moved 2026-06-21; behavior identical to
  # previous inline impl.
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local scan_script="$script_dir/proactive-board-scan.sh"
  if [ ! -f "$scan_script" ]; then
    echo "ERROR: $scan_script not found (refactor incomplete)" >&2
    echo '[]'
    return 0
  fi
  REPO="$REPO" ROLE="$ROLE" \
    PROACTIVE_SWEEP_ENABLED="${PROACTIVE_SWEEP_ENABLED:-true}" \
    PROACTIVE_SWEEP_INTERVAL_SEC="${PROACTIVE_SWEEP_INTERVAL_SEC:-300}" \
    STALLED_THRESHOLD_SEC="${STALLED_THRESHOLD_SEC:-14400}" \
    STATE_HELPER="$STATE_HELPER" \
    bash "$scan_script"
}

query_stale_cc() {
  # Deadlock breaker: if cc:<role> has sat on a PR for > STALE_CC_SEC without
  # any state change (no new commit, no new review, no label flip), emit a
  # stale_cc event. The agent picks it up and either acts or explicitly punts
  # the label back. Prevents permanent stall when an event was lost (watcher
  # restart, tmux send-keys race, processed_event_ids corruption).
  #
  # The event ID is bucketed by 5-minute windows so the same stall doesn't
  # spam wake-ups every poll — it re-fires at most every ~5 min until cleared.
  local now_epoch bucket
  now_epoch="$(date -u +%s)"
  bucket=$(( now_epoch / 300 ))

  gh pr list \
    --repo "$REPO" \
    --label "cc:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,headRefOid,labels \
    --jq "[ .[] |
           def is_author_self_cc_pr:
             ((.labels // []) | map(.name) | any(. == \"agent:${ROLE}\") and any(. == \"cc:${ROLE}\"));
           select(is_author_self_cc_pr | not) |
           ((now - (.updatedAt | fromdateiso8601)) | floor) as \$age |
           select(\$age > ${STALE_CC_SEC}) |
           {
             id: (\"stale-cc-\" + (.number | tostring) + \"-\" + (.headRefOid[0:7]) + \"-b${bucket}\"),
             kind: \"stale_cc\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .updatedAt,
             context: {
               age_sec: \$age,
               head_sha: .headRefOid[0:7],
               note: \"cc:${ROLE} unchanged for >${STALE_CC_SEC}s; deadlock-breaker wake.\"
             }
           } ]"
}

# v6 (ADR-0024): query_stale_verdict — deadline-based watchdog.
#
# Replaces stale_cc's stall target from "label presence" to "review verdict
# expectation". A PR with `cc:<role>` but NO `verdict-by:<ts>` label is NOT
# stale — there is no expectation to miss. A PR with `verdict-by:<ts>` whose
# deadline has passed IS stale — emit `stale_verdict` so the agent wakes and
# either delivers the verdict or extends the deadline (with rationale).
#
# Event ID = `stale-verdict-<n>-<sha7>-b<bucket>` (5-min window, same throttle
# scheme as stale_cc). The verdict-by ISO timestamp is captured in `context`
# for the agent to display. Re-fire suppression: same head_sha + same bucket
# → same ID → dedup catches it. Extending the deadline bumps head_sha (new
# commit) or rolls into a new bucket → new event → re-wake.
#
# Quiet under docs PRs (ADR-0021): docs PRs SHOULD NOT carry verdict-by; if
# they do, this fires the moment the deadline passes (correct — the agent
# should either remove the cc:* or add a verdict-by to reflect an actual
# expectation).
query_stale_verdict() {
  local now_epoch bucket
  now_epoch="$(date -u +%s)"
  bucket=$(( now_epoch / 300 ))

  gh pr list \
    --repo "$REPO" \
    --label "cc:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,headRefOid,labels \
    --jq --argjson now_epoch "$now_epoch" "[
      .[] |
      (.labels | map(.name)) as \$lbls |
      (\$lbls | map(select(startswith(\"verdict-by:\"))) | first // empty) as \$vb |
      select(\$vb != \"\" and \$vb != null) |
      (\$vb | sub(\"verdict-by:\"; \"\") | fromdateiso8601? // empty) as \$deadline |
      select(\$deadline != null and \$deadline != \"\" and \$now_epoch > \$deadline) |
      {
        id: (\"stale-verdict-\" + (.number | tostring) + \"-\" + (.headRefOid[0:7]) + \"-b${bucket}\"),
        kind: \"stale_verdict\",
        number: .number,
        title: .title,
        url: .url,
        updated_at: .updatedAt,
        context: {
          deadline: \$vb,
          age_sec: ((\$now_epoch - \$deadline) | floor),
          head_sha: .headRefOid[0:7],
          note: \"verdict-by deadline passed for cc:${ROLE}; verdict expected, none received.\"
        }
      }
    ]"
}

# v6 (ADR-0024): query_missing_expectation — convention violation catch.
#
# A PR with `cc:<role>` but NO `verdict-by:<ts>` label violates the new
# convention (ADR-0024 §Decision). Emit `missing_expectation` once per
# (PR, head_sha) so the agent can either add a verdict-by label (with
# explicit time bound) or remove the cc label. Idempotent: same head_sha
# → same event ID → dedup catches re-fires until a new commit lands (which
# bumps head_sha → re-wake to confirm convention is still followed).
#
# Event ID = `missing-expectation-<n>-<sha7>` (no bucket — dedup is by
# head_sha only, since this is a state-of-the-PR check, not a time check).
query_missing_expectation() {
  gh pr list \
    --repo "$REPO" \
    --label "cc:${ROLE}" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,headRefOid,labels \
    --jq "[
      .[] |
      (.labels | map(.name)) as \$lbls |
      select((\$lbls | map(select(startswith(\"verdict-by:\"))) | length) == 0) |
      {
        id: (\"missing-expectation-\" + (.number | tostring) + \"-\" + (.headRefOid[0:7])),
        kind: \"missing_expectation\",
        number: .number,
        title: .title,
        url: .url,
        updated_at: .updatedAt,
        context: {
          head_sha: .headRefOid[0:7],
          cc_label: \"cc:${ROLE}\",
          note: \"cc:${ROLE} set without verdict-by:<ts> expectation (ADR-0024 convention violation).\"
        }
      }
    ]"
}

# v3 (ADR-0005): post-merge lifecycle. Fan out pr-merged events to the roles
# listed in PR_MERGED_FANOUT_ROLES so developer/PM/orchestrator can run their
# cleanup workflows (branch prune, board update, sprint refresh) without manual
# pokes. Event ID = `pr-merged-<n>-<sha7>` where sha7 is the merge commit short
# SHA — unique per merge so re-merges (force-push to main, rare) re-fire cleanly.
#
# Dedup defense:
#   1. `pr_merged_last_seen_utc` high-water mark filters the gh query.
#   2. `processed_event_ids` ring buffer (poll_once) drops anything already seen.
#   3. Event ID embeds merge SHA — same PR re-merged with new SHA = new event.
# Side-channel: query_pr_merged exposes the newest merged_at it SAW (across all
# merged PRs in the window, regardless of label filter) via the global
# PR_MERGED_NEWEST_SEEN. This lets the HWM update advance even when label rules
# filter every PR out for this role — otherwise architect/tester would re-query
# the same backfill window forever and rely on dedup to suppress duplicates.
PR_MERGED_NEWEST_SEEN=""

query_pr_merged() {
  PR_MERGED_NEWEST_SEEN=""
  role_receives_pr_merged "$ROLE" || { echo '[]'; return; }

  # Fetch all merged PRs in the backfill window with their labels.
  local raw
  raw="$(gh pr list \
    --repo "$REPO" \
    --state merged \
    --search "merged:>${PR_MERGED_LAST_SEEN}" \
    --limit 50 \
    --json number,title,url,mergedAt,mergeCommit,author,labels \
    --jq "[ .[] |
           select(.mergeCommit != null and .mergeCommit.oid != null) |
           {
             id: (\"pr-merged-\" + (.number | tostring) + \"-\" + (.mergeCommit.oid[0:7])),
             kind: \"pr_merged\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .mergedAt,
             context: {
               merge_sha: .mergeCommit.oid[0:7],
               merged_at: .mergedAt,
               author: (.author.login // \"unknown\"),
               labels: [.labels[].name]
             }
           } ]")"

  # v3.1.1: bump HWM here (not in poll_once) so we don't depend on a global
  # surviving the $(query_pr_merged) subshell. Subshells lose parent vars.
  local newest
  newest="$(echo "$raw" | jq -r '[.[].context.merged_at] | max // empty')"
  PR_MERGED_NEWEST_SEEN="$newest"  # kept for backward compat / unit tests
  if [ -n "$newest" ] && [ "$newest" != "null" ]; then
    "$STATE_HELPER" set "$ROLE" pr_merged_last_seen_utc "\"$newest\""
  fi

  # v3.1 (ADR-0008): per-PR label-conditional filter.
  # Default-fanout roles keep every PR (D2 behaviour, fast path).
  # Architect/tester only keep PRs whose labels match the configured rules.
  if role_in_default_fanout "$ROLE"; then
    echo "$raw"
    return
  fi

  # Walk the events one by one so each label set is checked by jq separately.
  local filtered='[]' n i evt labels
  n="$(echo "$raw" | jq 'length')"
  i=0
  while [ "$i" -lt "$n" ]; do
    evt="$(echo "$raw" | jq -c ".[$i]")"
    labels="$(echo "$evt" | jq -c '.context.labels')"
    if role_wakes_for_pr "$ROLE" "$labels"; then
      filtered="$(jq -c -n --argjson acc "$filtered" --argjson e "$evt" '$acc + [$e]')"
    fi
    i=$((i+1))
  done
  echo "$filtered"
}

# v3.2 (ADR-0009 D2.2): PR-open architect/tester routing via pr_labeled.
#
# Why not Events API? Per ADR-0009 § 3 "Alternatives", we use the cheaper
# `gh pr list --state open` query with PR.updatedAt as HWM proxy. Cost:
# 1 API call per role per poll (only architect/tester are enrolled by default,
# so 2 calls/min total). Trade-off vs label-event precision is logged as
# TD-002 (docs/tech-debt.md) with a 5%-suppression-rate payoff trigger.
#
# Event ID = `pr-labeled-<n>-<updatedAt>` — stable per (PR, wake-tick). Re-poll
# of the same PR within one updatedAt window produces the same ID, which the
# processed_event_ids ring suppresses. A force-push or comment bumps updatedAt
# → new ID → re-wake (acceptable; agent sees fresh signal).
#
# Suppression observability: when role_receives_pr_labeled is true but no PR
# matches role_wakes_for_pr_labeled, we still advance the HWM (D2.1.2 pattern).
# Future TD-002 instrumentation will log pr_labeled_suppressed_quick_removal
# when the dedup ring detects > 5% same-PR re-evaluation churn (deferred to D2.2.1).
PR_LABELED_NEWEST_SEEN=""

query_pr_labeled() {
  PR_LABELED_NEWEST_SEEN=""
  role_receives_pr_labeled "$ROLE" || { echo '[]'; return; }

  # Fetch all OPEN PRs with their labels + updatedAt.
  local raw
  raw="$(gh pr list \
    --repo "$REPO" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,labels,isDraft \
    --jq "[ .[] | select(.updatedAt > \"$PR_LABELED_LAST_SEEN\") |
           {
             number,
             title,
             url,
             updatedAt,
             isDraft,
             labels: [.labels[].name]
           } ]" 2>/dev/null || echo '[]')"

  # D2.1.2-style inline HWM bump: advance even when label filter drops all PRs.
  local newest
  newest="$(echo "$raw" | jq -r '[.[].updatedAt] | max // empty')"
  PR_LABELED_NEWEST_SEEN="$newest"
  if [ -n "$newest" ] && [ "$newest" != "null" ]; then
    "$STATE_HELPER" set "$ROLE" pr_labeled_last_seen_utc "\"$newest\""
  fi

  # Per-PR filter: only keep PRs whose labels match this role's wake-trigger set.
  local filtered='[]' n i pr labels_json wake_reason
  n="$(echo "$raw" | jq 'length')"
  i=0
  while [ "$i" -lt "$n" ]; do
    pr="$(echo "$raw" | jq -c ".[$i]")"
    labels_json="$(echo "$pr" | jq -c '.labels')"
    if role_wakes_for_pr_labeled "$ROLE" "$labels_json"; then
      wake_reason="$(pr_labeled_wake_reason "$ROLE" "$labels_json")"
      filtered="$(jq -c -n \
        --argjson acc "$filtered" \
        --argjson p "$pr" \
        --arg reason "label:${wake_reason}" \
        '$acc + [{
          id: ("pr-labeled-" + ($p.number | tostring) + "-" + ($p.labels | sort | join("|"))),
          kind: "pr_labeled",
          number: $p.number,
          title: $p.title,
          url: $p.url,
          updated_at: $p.updatedAt,
          context: {
            labels: $p.labels,
            wake_reason: $reason,
            pr_state: "open",
            isDraft: $p.isDraft
          }
        }]')"
    fi
    i=$((i+1))
  done
  echo "$filtered"
}

# Orchestrator has a wider lens: all label changes on any issue/PR.
query_board_changes() {
  if [ "$ROLE" != "orchestrator" ]; then
    echo "[]"
    return
  fi
  # Recent issue events for label/assignee changes since last_seen.
  # v3.5 (issue #6 fix): event ID is content-stable — derived from sorted label
  # set, NOT updatedAt. See query_assigned_issues for the full rationale.
  # Idempotent label flips (add X then remove X) collapse to the same ID, which
  # the processed_event_ids dedup catches; only net changes to the label set
  # produce a new event.
  gh issue list \
    --repo "$REPO" \
    --state all \
    --limit 50 \
    --json number,title,url,updatedAt,labels,state \
    --jq "[ .[] | select(.updatedAt > \"$LAST_SEEN\") |
           {
             id: (\"board-\" + (.number | tostring) + \"-\" + (.labels | map(.name) | sort | join(\"|\"))),
             kind: \"label_change\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .updatedAt,
             context: { state: .state, labels: [.labels[].name] }
           } ]"
}

# --- tmux pane wake-up (title-based) ---
# Find pane by title (role uppercase) and inject a wake-up prompt via send-keys.
# Safe to call when not inside tmux — silently no-ops.
wake_pane_for_role() {
  local role="$1"
  local events_json="$2"
  local count
  count="$(echo "$events_json" | jq 'length')"
  [ "$count" -gt 0 ] || return 0

  # tmux available?
  command -v tmux >/dev/null 2>&1 || return 0
  tmux has-session -t "$TMUX_SESSION" 2>/dev/null || return 0

  # Find pane id by title (uppercase role). Fallback: deterministic index map.
  local role_upper
  role_upper="$(echo "$role" | tr '[:lower:]' '[:upper:]')"

  local pane_id
  pane_id="$(tmux list-panes -t "$TMUX_SESSION" -F '#{pane_id} #{pane_title}' 2>/dev/null \
    | awk -v t="$role_upper" '$2 == t { print $1; exit }')"

  # Fallback index map (matches dev-studio-start.sh layout)
  if [ -z "$pane_id" ]; then
    case "$role" in
      orchestrator)    pane_id="${TMUX_SESSION}:main.0" ;;
      product-manager) pane_id="${TMUX_SESSION}:main.1" ;;
      architect)       pane_id="${TMUX_SESSION}:main.2" ;;
      developer)       pane_id="${TMUX_SESSION}:main.3" ;;
      tester)          pane_id="${TMUX_SESSION}:main.4" ;;
      *) return 0 ;;
    esac
  fi

  # Compose pretty-printed wake-up prompt (heredoc-safe).
  local pretty
  pretty="$(echo "$events_json" | jq '.')"

  local prompt
  prompt="🔔 INBOX (auto-wake from agent-watch loop):
${pretty}

Lütfen pickup et: review yap, label flip et, peer'i bilgilendir, sonra heartbeat yaz ve queue'ya dön."

  # Send prompt then Enter. Use literal mode (-l) so backticks/quotes survive.
  tmux send-keys -t "$pane_id" -l "$prompt" 2>/dev/null || return 0
  tmux send-keys -t "$pane_id" Enter 2>/dev/null || true
}

# --- the actual poll ---
poll_once() {
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  # Heartbeat FIRST — even if the rest fails, doctor can see we're alive.
  "$STATE_HELPER" heartbeat "$ROLE" >/dev/null 2>&1 || true

  # Issue #238 sub-task 2 (PR #245): synthetic is_alive heartbeat emitted every
  # IS_ALIVE_INTERVAL_SEC (default 300s = 5min), independent of queue state.
  # Catches the "watcher stuck in rate-limited gh api loop" silent-drop class
  # (architect silenced 2026-06-22T06:46Z RCA, tester silenced 2026-06-22T06:46Z
  # RCA). The 5-min synthetic signal lets the doctor + orchestrator detect a
  # silently-stuck watcher via `last_is_alive_utc` field in state.
  local is_alive_interval last_is_alive_utc last_is_alive_epoch now_epoch emit_is_alive
  is_alive_interval="${IS_ALIVE_INTERVAL_SEC:-300}"
  last_is_alive_utc="$("$STATE_HELPER" get "$ROLE" last_is_alive_utc 2>/dev/null || echo "")"
  emit_is_alive=false
  if [ -z "$last_is_alive_utc" ] || [ "$last_is_alive_utc" = "null" ]; then
    emit_is_alive=true
  else
    last_is_alive_epoch="$(date -u -d "$last_is_alive_utc" +%s 2>/dev/null || echo 0)"
    now_epoch="$(date -u +%s)"
    if [ "$(( now_epoch - last_is_alive_epoch ))" -gt "$is_alive_interval" ]; then
      emit_is_alive=true
    fi
  fi
  local is_alive_event='[]'
  if [ "$emit_is_alive" = "true" ]; then
    is_alive_event="$(jq -n \
      --arg role "$ROLE" \
      --arg now "$now" \
      --argjson interval "$is_alive_interval" \
      '[
         {
           kind: "is_alive",
           id: ("is-alive-" + $role + "-" + $now),
           number: 0,
           title: ("is_alive heartbeat: " + $role),
           url: "",
           updated_at: $now,
           context: { role: $role, interval_sec: $interval }
         }
       ]')"
    "$STATE_HELPER" set "$ROLE" last_is_alive_utc "\"$now\"" >/dev/null 2>&1 || true
  fi

  # ADR-0032 RCA-18 fix (RCA-32): prune processed_event_ids entries older than
  # 24h (288 × 5min buckets) from the dedup buffer BEFORE downstream queries
  # and the dedup filter see it. Without this, historical stale-cc events from
  # past conditions accumulate up to the 200-cap and bias the buffer tail
  # toward 3-day-old events (refs Issue #216 RCA-18, PR #217 ADR). The
  # if/test() pattern RETAINs non-bucket IDs (wake_nudge, pr-merged,
  # pr-review) — they're bounded by their own throttle, not by bucket age.
  #
  # RCA-32 v2 (fix for P0 type-bug found by tester on PR #224): do the jq edit
  # DIRECTLY on the state file, NOT via "$STATE_HELPER set ... processed_event_ids
  # <json-array-string>". `cmd_set` uses `--arg` which treats its 3rd arg as a
  # STRING literal — so a JSON-array string got stored as a string, not an
  # array. After the first post-deploy poll, `processed_event_ids` would be
  # a string in the file, breaking `cmd_seen` substring dedup, `cmd_trim`'s
  # .[-max:] slice, and `length` reporting. Bypassing `cmd_set` here means
  # the file is read as JSON, the filter runs, and the array type is
  # preserved. The same jq filter is used in `cmd_trim`'s TTL branch which
  # already uses `jq_inplace` directly and works correctly.
  local current_bucket prune_cutoff_bucket state_file_ttl
  current_bucket=$(( $(date -u +%s) / 300 ))
  prune_cutoff_bucket=$(( current_bucket - 288 ))
  state_file_ttl="$("$STATE_HELPER" path "$ROLE")"
  if [ -f "$state_file_ttl" ]; then
    local tmp_ttl
    tmp_ttl="$(mktemp)"
    if jq --argjson cutoff "$prune_cutoff_bucket" '
      .processed_event_ids = (
        [ .processed_event_ids[] |
          if test("b[0-9]+$") then
            (capture("b(?<bucket>[0-9]+)$").bucket | tonumber) as $b |
            select($b >= $cutoff)
          else
            .  # wake_nudge / pr-merged / pr-review — retain
          end
        ]
      )
    ' "$state_file_ttl" > "$tmp_ttl" 2>/dev/null; then
      mv "$tmp_ttl" "$state_file_ttl"
    else
      rm -f "$tmp_ttl" 2>/dev/null || true
    fi
  fi

  # BUG-#61 fix: refresh HWMs from state at the start of every poll, so a
  # long-running --loop watcher's local HWM vars don't drift behind the state
  # file's HWM (which advances on every poll's tail below at `$STATE_HELPER set
  # ... last_seen_utc "$now"`). The 3 reads below were previously at script
  # start (pre-fix) and frozen there for the lifetime of the --loop process,
  # so the gh queries (query_assigned_issues, query_pr_mentions,
  # query_pr_merged, query_pr_labeled, query_board_changes) kept returning
  # historical events with old `updatedAt`.
  LAST_SEEN="$("$STATE_HELPER" get "$ROLE" last_seen_utc)"
  init_pr_merged_hwm
  init_pr_labeled_hwm

  local assigned reviews commits mentions stale stale_verdict missing_expectation board pr_merged pr_labeled issue_mentions periodic_scan
  assigned="$(query_assigned_issues || echo '[]')"
  reviews="$(query_review_requests || echo '[]')"
  commits="$(query_new_commits_on_assigned_prs || echo '[]')"
  mentions="$(query_pr_mentions 2>/dev/null || echo '[]')"
  # v6 (ADR-0024) shim dispatch: emit `stale_cc` only during the shim window
  # (now < VERDICT_SHIM_END) or when VERDICT_LEGACY_STALE_CC=true (rollback).
  # After 2026-07-02 by default, `query_stale_cc` is a no-op — the new
  # `stale_verdict` + `missing_expectation` queries carry the watchdog load.
  local now_epoch_shim shim_end_epoch
  now_epoch_shim="$(date -u +%s)"
  shim_end_epoch="$(date -u -d "$VERDICT_SHIM_END" +%s 2>/dev/null || echo 9999999999)"
  if [ "$now_epoch_shim" -lt "$shim_end_epoch" ] || [ "$VERDICT_LEGACY_STALE_CC" = "true" ]; then
    stale="$(query_stale_cc 2>/dev/null || echo '[]')"
  else
    stale='[]'
  fi
  stale_verdict="$(query_stale_verdict 2>/dev/null || echo '[]')"
  missing_expectation="$(query_missing_expectation 2>/dev/null || echo '[]')"
  board="$(query_board_changes || echo '[]')"
  pr_merged="$(query_pr_merged 2>/dev/null || echo '[]')"
  pr_labeled="$(query_pr_labeled 2>/dev/null || echo '[]')"
  # v4 (ADR-0017):
  issue_mentions="$(query_issue_mentions 2>/dev/null || echo '[]')"
  periodic_scan="$(query_periodic_backlog_scan 2>/dev/null || echo '[]')"
  # v5 (Issue #44 — Proactive Board Scan):
  # Issue #201: capture stderr to a log file instead of swallowing it.
  # Failure path (REPO missing, jq parse error, gh API error mid-detection)
  # must remain visible to post-mortem, while the success path stays silent.
  # XDG-cache-honoring: $PROACTIVE_SWEEP_LOG overrides; default lives under
  # $XDG_CACHE_HOME/dev-studio/agent-watch/ with $HOME/.cache fallback.
  # Shell-scope var (not `local`) because `$(...)` subshell needs read access
  # for the redirect; local vars don't leak into command substitutions.
  PROACTIVE_SWEEP_LOG="${PROACTIVE_SWEEP_LOG:-${XDG_CACHE_HOME:-$HOME/.cache}/dev-studio/agent-watch/proactive-sweep-errors.log}"
  mkdir -p "$(dirname "$PROACTIVE_SWEEP_LOG")" 2>/dev/null || true
  # Truncate on each call (AC: "no unbounded growth")
  : > "$PROACTIVE_SWEEP_LOG" 2>/dev/null || true
  proactive_sweep="$(query_proactive_sweep 2>"$PROACTIVE_SWEEP_LOG" || echo '[]')"
  # v6.1 (Issue #113 — Issue assigneeship authority + actionability signal):
  assigned_any="$(query_assigned_issues_any_status 2>/dev/null || echo '[]')"

  # v6.2 (Issue #119 — Dev-Idle Prevention, Katman 1): emit `wake_nudge` when
  # the agent has open work (`agent:<role>` or `cc:<role>` label on open issues)
  # but `new_events` is otherwise empty. Without this, an idle session sees
  # zero events and concludes "no work" — but the queue may have unresolved
  # issues. The nudge makes the queue visible to one-shot polls.
  local wake_nudge='[]'
  if [ -n "${REPO:-}" ]; then
    local queue_open cc_open
    # REST API (GraphQL rate-limit safe, Issue #238 emergency fix 2026-06-22)
    queue_open="$(gh api "repos/${REPO}/issues?state=open&labels=agent:${ROLE}&per_page=100" --jq 'length' 2>/dev/null || echo 0)"
    cc_open="$(gh api "repos/${REPO}/issues?state=open&labels=cc:${ROLE}&per_page=100" --jq 'length' 2>/dev/null || echo 0)"
    # Heartbeat-missed check (Issue #238 sub-task 2, PR #245): fire wake_nudge
    # if the synthetic is_alive heartbeat is older than 2x IS_ALIVE_INTERVAL_SEC.
    # Watchdog for the "watcher itself stuck" class — even when the queue is
    # empty, the synthetic heartbeat must remain fresh. Catches architect +
    # tester silenced at 2026-06-22T06:46Z RCA (per-poll heartbeat up to date
    # but gh api rate-limited → no events → self-pause).
    local heartbeat_missed=false
    if [ -n "$last_is_alive_utc" ] && [ "$last_is_alive_utc" != "null" ] && [ "$last_is_alive_epoch" -gt 0 ]; then
      if [ "$(( now_epoch - last_is_alive_epoch ))" -gt "$(( is_alive_interval * 2 ))" ]; then
        heartbeat_missed=true
      fi
    fi
    if [ "$((queue_open + cc_open))" -gt 0 ] || [ "$heartbeat_missed" = "true" ]; then
      local wake_note
      if [ "$heartbeat_missed" = "true" ]; then
        wake_note="watcher heartbeat missed (>2x IS_ALIVE_INTERVAL_SEC); queue may be empty or stuck"
      else
        wake_note="no-new-events but queue non-empty (Katman 1)"
      fi
      wake_nudge="$(jq -n \
        --arg role "$ROLE" \
        --arg now "$now" \
        --arg repo "$REPO" \
        --argjson queue "$queue_open" \
        --argjson cc "$cc_open" \
        --argjson hb_missed "$([ "$heartbeat_missed" = "true" ] && echo true || echo false)" \
        --arg note "$wake_note" \
        '[
           {
             kind: "wake_nudge",
             id: ("wake-nudge-" + $role + "-" + $now),
             number: 0,
             title: ("queue: agent:" + $role + "=" + ($queue|tostring) + ", cc:" + $role + "=" + ($cc|tostring) + " open issues"),
             url: ("https://github.com/" + $repo + "/issues?q=is%3Aopen+label%3Aagent%3A" + $role),
             updated_at: $now,
             context: {agent_count: $queue, cc_count: $cc, heartbeat_missed: $hb_missed, note: $note}
           }
         ]')"
    fi
  fi

  # Merge and dedupe
  local merged
  merged="$(jq -s 'add | unique_by(.id)' \
    <(echo "$assigned") <(echo "$reviews") <(echo "$commits") \
    <(echo "$mentions") <(echo "$stale") <(echo "$stale_verdict") \
    <(echo "$missing_expectation") <(echo "$board") \
    <(echo "$pr_merged") <(echo "$pr_labeled") \
    <(echo "$issue_mentions") <(echo "$periodic_scan") \
    <(echo "$proactive_sweep") <(echo "$assigned_any") \
    <(echo "$is_alive_event") \
    2>/dev/null || echo '[]')"

  # Filter out events already in processed_event_ids
  local state_file new_events
  state_file="$("$STATE_HELPER" path "$ROLE")"
  new_events="$(jq -n \
    --slurpfile state "$state_file" \
    --argjson events "$merged" '
    [ $events[] | select((.id as $id | $state[0].processed_event_ids | index($id)) == null) ]
  ')"

  # Emit
  jq -n \
    --arg role "$ROLE" \
    --arg now "$now" \
    --argjson events "$new_events" \
    --argjson next "$POLL_INTERVAL" \
    --argjson nudge "$wake_nudge" \
    '{
       role: $role,
       polled_at_utc: $now,
       new_events: $events,
       wake_nudge: $nudge,
       next_poll_sec: $next
     }'

  # Bump last_seen
  "$STATE_HELPER" set "$ROLE" last_seen_utc "\"$now\""

  # v3.1.1 (ADR-0008): HWM bump now lives inside query_pr_merged because the
  # subshell `$(query_pr_merged)` capture above drops any globals set by the
  # callee. The role still advances pr_merged_last_seen_utc on every poll even
  # when label rules filtered every PR out for this role.

  # Auto-mark events as processed (the agent can also call mark explicitly)
  echo "$new_events" | jq -r '.[].id' | while read -r eid; do
    [ -n "$eid" ] && "$STATE_HELPER" mark "$ROLE" "$eid"
  done

  # Trim processed_event_ids to keep state file bounded (default: keep last 50).
  # ADR-0032 RCA-32: pass 288 (24h × 12 buckets/h) as 3rd arg so cmd_trim also
  # applies the TTL filter (defense in depth on top of the prune block above).
  "$STATE_HELPER" trim "$ROLE" "${AGENT_PROCESSED_MAX:-50}" 288 >/dev/null 2>&1 || true

  # Wake the tmux pane if events arrived OR wake_nudge present and wake mode is on.
  # v6.2 (Issue #119 — Dev-Idle Prevention, Katman 2): wake on nudge too, not
  # only on new_events. Combined payload (events + nudges) gives full context.
  if [ "$WAKE_PANE" = "1" ]; then
    local wake_payload
    wake_payload="$(jq -n --argjson e "$new_events" --argjson n "$wake_nudge" '$e + $n')"
    wake_pane_for_role "$ROLE" "$wake_payload" || true
  fi
}

case "$MODE" in
  --once)
    poll_once
    ;;
  --loop)
    while true; do
      poll_once
      sleep "$POLL_INTERVAL"
    done
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    exit 2
    ;;
esac
