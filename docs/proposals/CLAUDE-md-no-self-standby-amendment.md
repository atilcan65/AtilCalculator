# Proposal: §Things agents must NEVER do — explicit forbidden standby modes (Issue #238)

**Status**: Proposed (architect PR — pending human owner application per `.claude/` human-only convention)
**Date**: 2026-06-22
**Source issue**: #238 (P0 — `[Doctrin] Agents self-standby on dependency — violates no-pause doctrine`)
**Author**: @architect
**Deciders**: @atilcan65 (human owner applies the change), @orchestrator (operational review), @developer (impl impact: heartbeat + wake_nudge changes), @tester (regression test impact: d028)

## Why this proposal exists

At 2026-06-22T06:46Z, owner reported "no agent is working". RCA found 4 agents in self-invented "standby" states:

| Agent | Self-justified pause | Doctrine violation |
|---|---|---|
| architect | "GitHub rate limit hit" | "no new events" pattern (rate limit is not a valid pause reason) |
| developer | "#232/#233 dependency blocks" | "blocked on dependency" pattern (queue has other items to work) |
| tester | "STATE-CORRUPTION processed_event_ids 200→2" | "state corruption" pattern (flag + take OTHER queue items, don't pause) |
| product-manager | (correct) | no work assigned — valid empty-queue state |

CLAUDE.md L355 already says: "Agents do NOT invent 'standby'... If you find yourself in a 'standby'... you are in a halucination loop."

**The problem isn't missing doctrine — it's that the doctrine is abstract, and agents are not applying it.** The fix is to add an **explicit enumeration** of the 4 most common forbidden standby modes with the correct action for each. This turns an abstract "don't pause" rule into a 4-item checklist agents can self-check.

## Proposed amendment to `.claude/CLAUDE.md`

**Location**: `## Things agents must NEVER do` section, after the existing "Invent self-imposed work pauses" clause (L355).

**Proposed addition** (new sub-section after the "Invent self-imposed work pauses" clause — owner decides final structure):

```markdown
### Forbidden standby modes (explicit enumeration)

The "no self-standby" doctrine (above) is abstract. Below is the **explicit enumeration** of forbidden standby modes observed in incidents. If you find yourself reasoning toward any of these, **stop, re-read this file, and take the prescribed action**:

| Self-justified pause | Why it's forbidden | What to do INSTEAD |
|---|---|---|
| "blocked on dependency" | Queue has OTHER items; pausing on one is a queue-bypass | **Take OTHER queue items** — file, sort, write the design doc, draft the ADR, work the related issue |
| "GitHub rate limit hit" | Rate limit is API throttling, not a work pause. Local work (read files, design, draft) is rate-limit-immune | **Work locally** — read scripts, draft ADRs/designs, plan the work, prepare diffs. Wait is not required. |
| "state corruption" (e.g. `processed_event_ids` corrupted) | Watcher is degraded but other agents' queues are not | **Flag to orchestrator** (`@orchestrator` comment on the issue + `notify.sh -l orchestrator`) **AND take OTHER queue items** |
| "no new events" / "queue is empty" | Queue is computed; agents don't get events for "stale" or "expired" items | **Scan queue for expired, unblock** — re-read your queue, look for items in `status:ready` past 24h, items with `cc:<role>` from the owner, items with a referenced ADR that has a follow-up issue |

### Operational enforcement

- **`agent-watch.sh` heartbeat**: every 5 min, even if no events (closes the "no events → standby" loop).
- **`wake_nudge` trigger**: heartbeat-missed, not just queue-non-empty (closes the "queue is stale but I'm not checking" loop).
- **d028 regression test**: 4 TCs, one per forbidden standby mode — agent should NOT pause polling.

### Self-check before pausing

Before ANY pause, ask:
1. Is there an explicit human instruction in chat (verbatim, current thread)? — If no, **continue working**.
2. Is there an explicit dependency block documented in an issue/PR (with link)? — If no, **continue working**.
3. Is this a heartbeat/reprime SOP step? — If no, **continue working**.

If all three are no, you are in a self-justified pause. Re-read this file and resume.
```

## What this amendment does

1. **Closes the abstract-doctrine gap**: agents had to *interpret* "no self-standby" against their specific scenario. Now the 4 specific patterns are named and have prescribed actions.
2. **Prevents regression of #238's exact pattern**: the 4 forbidden modes are the 4 modes observed in this incident. Future agents see the same patterns and know what to do.
3. **Operational enforcement is co-located**: heartbeat, wake_nudge trigger, d028 test are all in the same section, so agent-watcher impl and doctrine stay in sync.
4. **Self-check is unambiguous**: the 3-question checklist (a/b/c) is the operational form of the existing 3-valid-pause-reasons rule.

## What this amendment does NOT do

- Does NOT change the existing "Invent self-imposed work pauses" clause (L355) — that remains the abstract rule. The new section is the explicit enumeration that operationalizes it.
- Does NOT change `.claude/agents/*.md` files directly. Per "Edit other agents' soul files" doctrine (CLAUDE.md L354), the human owner applies changes to soul files. If the human wants to mirror this section into the 5 soul files, that's a separate post-merge task.
- Does NOT introduce a 3rd poll layer (per #238 §5 — "Update Issue #235 to also detect standby-on-dependency pattern"). That's a D6 sub-detection, dev work in ADR-0037.

## Peer review request

Per ADR-0012 4-cat invariant (docs PR default `agent:<author>` only, peer `cc:*` requires cross-cutting rationale per ADR-0021):
- `agent:architect` (me, author)
- `cc:human` (primary — `.claude/` is human-only, owner applies)
- `cc:orchestrator` (operational review — heartbeat + wake_nudge changes affect orchestrator's loop)
- `cc:developer` (impl impact — agent-watch.sh patch is dev work, ~10 lines + d028 test)
- `cc:tester` (regression test impact — d028 spec)

## Sprint 4 commitment

| Role | SP | Scope |
|---|---|---|
| **Architect** (me) | 0.25 | This proposal + ADR-0037 cross-link — DONE on PR open |
| **Human owner** | 0.25 | Apply the amendment to `.claude/CLAUDE.md` (1-line change to add the section) |
| **Developer** | 1.0 | agent-watch.sh patch (heartbeat every 5 min, ~5 lines) + wake_nudge trigger change (heartbeat-missed vs queue-non-empty, ~10 lines) + d028 regression test (4 TCs) |
| **Tester** | 0.5 | d028 sign-off (4 TCs) |
| **Total** | **2.0** | Fits Sprint 4 EOD 2026-06-22T24:00Z |

## Cross-references

- Issue #238 (P0 — this proposal's source)
- Issue #235 (related — orchestrator gap-scan, ADR-0037 D6 dev_idle is the operational detector for the "GitHub rate limit" and "state corruption" modes)
- ADR-0002 (autonomy loop — foundation, agent-watch.sh + notify.sh are the impl substrate)
- ADR-0037 (proactive gap-scan, includes D6 dev_idle which is the operational detection for 2 of the 4 modes here)
- `scripts/agent-watch.sh` L1060-1086 (`query_board_changes`), L1088-1135 (`wake_pane_for_role`) — impl target for heartbeat change
- `scripts/agent-state.sh` (HWM for last_heartbeat_utc, already exists per `cmd_heartbeat`)
- PR #226 (precedent — `docs(proposal): ADR-0033 — CLAUDE.md §Auto-Ping Hard-Rule amendment proposal`, MERGED 2026-06-21T21:35:45Z)

## Rollback

Revert this proposal PR. The 4 forbidden standby modes section is additive; removing it leaves the existing "Invent self-imposed work pauses" clause intact. Zero impact on existing doctrine.

## Open questions for owner

1. **Structure**: should the new section be a sub-bullet of "Invent self-imposed work pauses" (compact) or a new `### Forbidden standby modes (explicit enumeration)` sub-section (more visible)? Recommended: sub-section (more visible, harder to skim past).
2. **Operational enforcement co-location**: should `agent-watch.sh` heartbeat + `wake_nudge` trigger + d028 spec be in the same CLAUDE.md section, or in a separate file (e.g. `docs/doctrine/no-self-standby.md`)? Recommended: co-located (one source of truth for the doctrine + its enforcement).
3. **5 soul files**: should this section be mirrored into `.claude/agents/{architect,developer,tester,orchestrator,product-manager}.md`? Recommended: no — the doctrine is universal; mirroring creates 6 copies that can drift. CLAUDE.md is the single source of truth; soul files should reference it.
