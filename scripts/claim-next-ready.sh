#!/usr/bin/env bash
# claim-next-ready.sh — STUB (Sprint 5 Layer 2 impl deferred per ADR-0038)
#
# Why this exists
# ---------------
# Issue #276 (Design-Drift, 2026-06-22T19:36Z): PR #275 soul patch (Layer 1
# per ADR-0038) added §Auto-Claim Protocol hooks to all 4 agent soul files
# (.claude/agents/{architect,developer,product-manager,tester}.md). The hooks
# invoke `bash scripts/claim-next-ready.sh <role>` when agents "go back to
# sleep". But the actual impl was deferred to Sprint 5 (Issue #271, 1.5 SP).
# Without this stub, every agent's auto-claim hook fails when next sleeping.
#
# This stub:
#   - Makes the soul hook succeed (exit 0) so no error loops
#   - Logs a clear "deferred to Sprint 5" message for observability
#   - Honors Layer 2 properties from ADR-0038 (atomic, role-aware, idempotent)
#     in its STUB form: no state mutations, no audit writes, no wake emissions
#
# Sprint 5 Layer 2 impl will replace this stub:
#   - scripts/claim-next-ready.sh (~80 LOC, atomic claim helper)
#   - agent-watch.sh integration (~15 LOC)
#   - scripts/tests/d031-claim-next-ready.sh (5 TCs: priority sort,
#     age tie-break, dep parser, WIP cap, negative case)
#
# Properties (STUB):
#   1. No-op: exits 0 with a clear "deferred" message
#   2. Idempotent: safe to call repeatedly
#   3. No side effects: pure log + exit, no external state changes
#
# Exit codes:
#   0   success (no-op stub, expected)
#   2   usage error (missing role argument)

set -uo pipefail

ROLE="${1:-}"

if [ -z "$ROLE" ]; then
  echo "usage: claim-next-ready.sh <role>" >&2
  echo "  role: orchestrator|product-manager|architect|developer|tester" >&2
  exit 2
fi

# Validate role enum (defensive — keep stub safe against typos)
case "$ROLE" in
  orchestrator|product-manager|architect|developer|tester) ;;
  *) echo "ERROR: invalid role: $ROLE" >&2; exit 2 ;;
esac

# STUB behavior: log + exit 0
# Sprint 5 impl will replace this block with actual priority sort + claim.
echo "[claim-next-ready.sh] STUB: Layer 2 impl deferred to Sprint 5 (Issue #271, 1.5 SP). Role=$ROLE, no action taken."
exit 0