#!/usr/bin/env bash
# d031-recovery-scan.sh — Post-merge drift scan for Sprint 4 P0 AUTO-REVERT-FIX (#125).
#
# Per ADR-0031 §"Owner-override recovery procedure" (Accepted per [PR #206]):
#   "24h post-merge drift scan by @architect. The scan targets: (a) ADR violations
#    in merged code, (b) acceptance criterion breaks, (c) irreversible technical
#    debt introduced."
#
# This script implements the **tooling** half of the recovery procedure (the
# other half being the human owner override rationale + RCA pattern). It runs
# daily (systemd timer or GitHub Action cron) and emits a report of:
#   - All owner-override merges in the last 24h (Tier 1 architect reviews)
#   - Drift signals detected on those merges (Mechanism A: owner manual re-flip)
#   - Mechanism B exclusions (label-cleanup.yml is expected behavior)
#
# Drift definition (per architect RCA on #125 at 2026-06-21T08:30Z):
#   Mechanism A (REAL BUG) — actor_type=User, label_change within 90s of owner
#     override merge, opposite-direction flip (e.g., cc:tester → cc:developer).
#   Mechanism B (EXPECTED)  — actor_type=Bot, label_change within 15s of close
#     event (label-cleanup.yml doing its job).
#
# Inputs (env vars):
#   REPO               (required) — e.g. atilcan65/AtilCalculator
#   ROLE               (default: orchestrator)
#   LOOKBACK_HOURS     (default: 24) — drift scan window
#   DRIFT_WINDOW_SEC   (default: 90) — Mechanism A threshold
#   REPORT_PATH        (default: stdout; if set, append JSON to file)
#   SINCE_FILE         (optional) — path to ISO-timestamp file; resume-from-here
#
# Output: JSON object with shape:
#   {
#     "scan_at": "<iso>",
#     "lookback_hours": 24,
#     "repo": "...",
#     "overrides_observed": [ {pr, merged_at, rationale} ],
#     "drift_findings":    [ {pr, kind, evidence, first_drift_at} ],
#     "summary":           {overrides_count, drift_count, by_kind}
#   }
#
# Exit codes:
#   0 = scan completed, no drift detected
#   1 = scan completed, drift findings present (action needed)
#   2 = REPO missing or gh API error
#
# Sprint 4 P0 — owner-merge gated per CLAUDE.md §File ownership matrix
# (.github/workflows/ changes require owner approval; this script is
# scripts/ not workflows/ so dev can iterate freely).
#
# — @developer, 2026-06-21 (initial scaffold, refs Issue #125)

set -euo pipefail

REPO="${REPO:-${1:-}}"
if [ -z "$REPO" ]; then
  echo "ERROR: REPO env var (or arg) is required" >&2
  exit 2
fi

ROLE="${ROLE:-orchestrator}"
LOOKBACK_HOURS="${LOOKBACK_HOURS:-24}"
DRIFT_WINDOW_SEC="${DRIFT_WINDOW_SEC:-90}"
REPORT_PATH="${REPORT_PATH:-}"
SINCE_FILE="${SINCE_FILE:-}"

# --- Kill switch ---
if [ "${D031_ENABLED:-true}" = "false" ]; then
  echo '{"scan_at":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'","kill_switch":true,"note":"d031 disabled via D031_ENABLED=false"}'
  exit 0
fi

# --- Role gate ---
if [ "$ROLE" != "orchestrator" ] && [ "$ROLE" != "developer" ] && [ "$ROLE" != "architect" ]; then
  echo '{"scan_at":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'","role_gate":true,"note":"d031 role-gated to architect/developer/orchestrator"}'
  exit 0
fi

scan_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# --- TODO (full impl gated on PR #206 merge → ADR-0031 Accepted) ---
# Stub: emit empty scan with TODOs visible. Full implementation will:
#   1. Query GH for merged PRs in last LOOKBACK_HOURS (gh pr list --state merged
#      --json number,mergedAt,labels,body --limit 100).
#   2. For each PR, parse squash-merge commit message for override rationale
#      marker (per ADR-0031 §"Owner override procedure" step 2).
#   3. For each override PR, fetch label events via gh api
#      /repos/:owner/:repo/issues/:n/events?per_page=100.
#   4. Classify each label_change event:
#        - actor_type=Bot + delta_to_merge < 15s → Mechanism B (exclude)
#        - actor_type=User + delta_to_override < DRIFT_WINDOW_SEC + opposite-direction
#          flip → Mechanism A (record as drift)
#   5. Emit JSON per the schema above.

cat <<EOF
{
  "scan_at": "$scan_at",
  "lookback_hours": $LOOKBACK_HOURS,
  "drift_window_sec": $DRIFT_WINDOW_SEC,
  "repo": "$REPO",
  "role": "$ROLE",
  "overrides_observed": [],
  "drift_findings": [],
  "summary": {
    "overrides_count": 0,
    "drift_count": 0,
    "by_kind": {}
  },
  "todo": [
    "Query merged PRs in last LOOKBACK_HOURS (step 1)",
    "Parse override rationale marker in squash-merge commit msg (step 2)",
    "Fetch label events for each override PR (step 3)",
    "Classify events: actor_type + delta + direction (step 4)",
    "Emit JSON drift report (step 5)"
  ],
  "note": "Scaffold — full impl gated on PR #206 (ADR-0031 Accepted). Refs Issue #125."
}
EOF

# Persist to REPORT_PATH if requested (append-only, one line per scan)
if [ -n "$REPORT_PATH" ]; then
  mkdir -p "$(dirname "$REPORT_PATH")"
  echo "Scan at $scan_at — scaffold mode (drift_count=0)" >> "$REPORT_PATH"
fi

exit 0
