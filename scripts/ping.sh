#!/usr/bin/env bash
# ping.sh — wrapper that enforces correct notify.sh dual-channel invocation.
#
# Why this exists
# ----------------
# scripts/notify.sh has TWO confusing flags with similar shapes:
#   -l <level>  — info | warn | error | ok (LOG LEVEL, emoji selector)
#   -r <role>   — orchestrator | product-manager | architect | developer |
#                 tester | human (TARGET ROLE when -w is set, ADR-0033)
#
# Issue #320 RCA: the Auto-Ping doctrine in CLAUDE.md showed broken syntax
# (`notify.sh -l <role>`) in 22 places across 6 files. The `-l <role>` form
# silently falls through to the default 🤖 emoji and Telegram-only delivery —
# the target agent's tmux pane NEVER wakes. Sprint 3+ peer pings have been
# silently broken for months because of this.
#
# scripts/ping.sh is the canonical fix: it ALWAYS passes -l info -w -r <role>
# internally. Cannot be misused by agents. Owners update CLAUDE.md / soul
# files to use ping.sh instead of notify.sh for peer-pings.
#
# Usage:
#   scripts/ping.sh <role> <message...>
#   scripts/ping.sh developer "PR #42 ready for review"
#   scripts/ping.sh orchestrator "Sprint 7 P0 chain DONE"
#
# Exit codes:
#   0 — message sent + tmux wake injected
#   1 — Telegram API error (notify.sh exit 1)
#   2 — usage error (missing/invalid role)
#
# Reference: Issue #320, ADR-0033 (dual-channel), CLAUDE.md §Auto-Ping.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROLE="${1:-}"
shift || true

if [ -z "$ROLE" ] || [ $# -eq 0 ]; then
  echo "usage: $0 <role> <message...>" >&2
  echo "  role: orchestrator | product-manager | architect | developer | tester | human" >&2
  echo "  example: $0 developer 'PR #42 ready for review'" >&2
  exit 2
fi

case "$ROLE" in
  orchestrator|product-manager|architect|developer|tester|human) ;;
  *)
    echo "ERROR: invalid role: $ROLE" >&2
    echo "  valid: orchestrator | product-manager | architect | developer | tester | human" >&2
    exit 2
    ;;
esac

# Forward to notify.sh with the CORRECT dual-channel syntax.
# -l info is the log level (NOT a role). -w enables tmux wake.
# -r <role> tells notify.sh which tmux pane to inject into.
exec "$SCRIPT_DIR/notify.sh" -l info -w -r "$ROLE" "$*"
