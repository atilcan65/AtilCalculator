#!/usr/bin/env bash
# peer-poke.sh — Dual-channel peer-poke wrapper (ADR-0033, Issue #296)
#
# Usage:
#   scripts/peer-poke.sh architect "[ORCH→ARCH] #289 v2 review needed"
#   scripts/peer-poke.sh developer "[TEST→DEV] bug #320 ready for triage"
#
# Wraps: notify.sh -l info -w -r <role> <message>
# Refuses to call without -w (the whole point of this script).
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# Per ADR-0033 (dual-channel doctrine), waking a peer agent from tmux context
# requires BOTH (a) a Telegram message AND (b) a tmux pane wake. Telegram-only
# (the `notify.sh -l <role>` legacy form) is broken — peer tmux panes never
# wake. Five agent soul files used to show the legacy form in their
# §Peer-Poke Discipline examples, so new agents learned the wrong pattern.
# Issue #296 closes that gap.
#
# This wrapper bakes the correct invocation shape (`-l info -w -r <role>`)
# into a single helper, so the wrong form is unreachable through this entry
# point. Sister: scripts/ping.sh — identical wrapper semantics, slightly
# different argument-handling edges (see d038 vs d296 d-tests).
#
# Refs:
#   - Issue #296
#   - docs/peer-poke-spec.md §Deliverable 1
#   - ADR-0033 (dual-channel doctrine)
#   - Issue #320 RCA (notify.sh -l <role> footgun)
#   - CLAUDE.md §Auto-Ping Hard-Rule
#
# Doctrinal contract (d-test d296-peer-poke-helper.sh, 3 TCs):
#   T1: argv capture: peer-poke.sh <role> "<msg>" → notify.sh -l info -w -r <role> "<msg>"
#   T2: missing args → exit 2 + usage to stderr
#   T3: bash -n syntactically valid

set -euo pipefail

ROLE="${1:-}"
shift || true
MSG="${*:-}"

if [ -z "$ROLE" ] || [ -z "$MSG" ]; then
    echo "Usage: $0 <role> <message>" >&2
    echo "  role: orchestrator | product-manager | architect | developer | tester" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/notify.sh" -l info -w -r "$ROLE" "$MSG"
