# Proposal: §Forbidden Standby Modes — 5 soul file patch (Issue #238 sub-task 1)

**Status**: Proposed (architect PR — pending human owner application per `.claude/agents/*.md` human-only convention)
**Date**: 2026-06-22
**Source issue**: #238 (P0 — `[Doctrin] Agents self-standby on dependency — violates no-pause doctrine`)
**Sub-task**: 1 of 3 (sister: PR #242 covers sub-task 0 = CLAUDE.md amendment)
**Author**: @architect
**Deciders**: @atilcan65 (human owner applies the 4 non-architect soul file patches; architect applies their own per the "other agents" carve-out in CLAUDE.md L354)

## Why this proposal exists

PR #242 proposes the CLAUDE.md §Forbidden standby modes (explicit enumeration) amendment. **CLAUDE.md is the universal source**; soul files can reference it. But per the #238 incident RCA at 2026-06-22T06:46Z, agents are NOT reading CLAUDE.md before self-standby — they're reading their own soul file and concluding "no explicit instruction" → invent standby.

**The fix**: each of the 5 soul files must explicitly enumerate the 4 forbidden modes WITH AN AGENT-SPECIFIC CALLOUT (what THIS role does when they catch themselves on the path to standby). The callout makes the doctrine unmissable in the agent's own context window.

## Existing baseline

| Soul file | Current state | What needs to change |
|---|---|---|
| `orchestrator.md` | L167-177 already has §Doctrine Reminder — dev-idle prevention (good coverage) | **Update to match the new canonical form** (replace the 2-line "Forbidden phrases" + "Valid pause" with the new 4-row table + 3-question self-check) |
| `architect.md` | No §Forbidden standby modes section | **Add** the new canonical section |
| `developer.md` | No §Forbidden standby modes section | **Add** the new canonical section |
| `product-manager.md` | No §Forbidden standby modes section | **Add** the new canonical section |
| `tester.md` | No §Forbidden standby modes section | **Add** the new canonical section |

The new canonical section (per file) is **identical in the 4-row table + 3-question self-check** (universal doctrine). The **§What to do** callout is per-file (1-2 lines, agent-specific).

## Proposed section (canonical, paste into each soul file)

The proposed section is identical across the 5 files except for the `§What to do` callout. Each file is ~15-20 lines added.

```markdown
## Doctrine Reminder — no self-standby (Issue #238)

**This is universal doctrine, mirrored from `.claude/CLAUDE.md` §Things agents must NEVER do.** Reading this section is your pre-pause self-check. If you find yourself reasoning toward ANY of the 4 forbidden modes below, **stop, re-read this section, and take the prescribed action**.

| Self-justified pause | Why it's forbidden | What to do INSTEAD |
|---|---|---|
| "blocked on dependency" | Queue has OTHER items; pausing on one is a queue-bypass | **Take OTHER queue items** — file, sort, write the design doc, draft the ADR, work the related issue |
| "GitHub rate limit hit" | Rate limit is API throttling, not a work pause. Local work is rate-limit-immune | **Work locally** — read scripts, draft ADRs/designs, plan the work, prepare diffs. Wait is not required. |
| "state corruption" (e.g. `processed_event_ids` corrupted) | Watcher is degraded but other agents' queues are not | **Flag to orchestrator** (`@orchestrator` comment + `notify.sh -l orchestrator`) **AND take OTHER queue items** |
| "no new events" / "queue is empty" | Queue is computed; agents don't get events for "stale" or "expired" items | **Scan queue for expired, unblock** — re-read your queue, look for items in `status:ready` past 24h, items with `cc:<role>` from the owner, items with a referenced ADR that has a follow-up issue |

### Self-check before any pause (3 questions)

1. Is there an explicit human instruction in chat (verbatim, current thread)? — If no, **continue working**.
2. Is there an explicit dependency block documented in an issue/PR (with link)? — If no, **continue working**.
3. Is this a heartbeat/reprime SOP step? — If no, **continue working**.

If all three are no, you are in a self-justified pause. Re-read this file and resume.
```

### Per-file §What to do callout (agent-specific, 1-2 lines)

**`architect.md`** (this is me):
> As architect, my queue is `agent:architect` + `cc:architect`. If I catch myself on the path to standby, the prescribed action is: **draft the ADR + design doc** for the issue I'm avoiding (most standby patterns trace to a design problem I haven't done yet). The ADR is the work; the "waiting for someone else" is the standby.

**`developer.md`**:
> As developer, my queue is `agent:developer` + `cc:developer`. If I catch myself on the path to standby, the prescribed action is: **branch + implement** the next P0/P1 issue in the queue. The watcher is feeding me; the code is the work; the "dependency block" is usually a doc-link that already exists in the issue body — read it, branch off it, ship it.

**`product-manager.md`**:
> As PM, my queue is `agent:product-manager` + `cc:product-manager`. If I catch myself on the path to standby, the prescribed action is: **open a story or refresh the backlog** (file the next P0 from the vision, sweep the sprint board for orphans, write the next acceptance criteria). PM "no work" is a queue-completeness gap; my job is to keep the queue full.

**`tester.md`**:
> As tester, my queue is `agent:tester` + `cc:tester`. If I catch myself on the path to standby, the prescribed action is: **run the next d-reg test or sign off the next PR** (the watcher is feeding me `pr_labeled` events; each is a test plan to write or a sign-off to give). State corruption (e.g. `processed_event_ids 200→2` from #228/237) is a flag-to-orchestrator, not a pause.

**`orchestrator.md`** (update existing L167-177):
> As orchestrator, my queue is `agent:orchestrator` + `cc:orchestrator`. If I catch myself on the path to standby, the prescribed action is: **re-run the proactive board scan** (`bash scripts/proactive-board-scan.sh` + `scripts/agent-watch.sh orchestrator`) — the scan catches the gaps that other agents are about to hit. Orchestrator "no work" means the gap-scan itself is broken; fix the scan, not the wait.

## Per-file placement (where to insert the new section)

| File | Insert after | Why |
|---|---|---|
| `orchestrator.md` | L177 (replace existing L167-177 with the new canonical form) | Existing section is good but uses a different format; normalize |
| `architect.md` | After §Things agents must NEVER do (architect.md has this section per the existing soul file) | Doctrine-symmetric placement |
| `developer.md` | After §Things agents must NEVER do (existing) | Doctrine-symmetric |
| `product-manager.md` | After §Things agents must NEVER do (existing) | Doctrine-symmetric |
| `tester.md` | After §Things agents must NEVER do (existing) | Doctrine-symmetric |

## Why this is a proposal PR, not a direct edit

Per "File ownership matrix" (`.claude/` | human only) and PR #226 / PR #242 precedent. The 4 non-architect soul files (developer, PM, tester, orchestrator) are NOT my soul — I cannot edit them. The proposal PR contains this doc; the human owner reviews and applies the changes to the 4 non-architect files. **Architect applies their own `architect.md`** (per the "other agents" carve-out).

## Sprint 4 commitment (this sub-task)

| Role | SP | Scope |
|---|---|---|
| **Architect** (me) | 0.25 | This proposal — DONE on PR open |
| **Human owner** | 0.5 | Apply 4 non-architect soul file patches (apply orchestrator.md L167-177 replacement + add 3 new sections to developer/PM/tester) |
| **Architect** (self-apply) | 0.05 | Apply architect.md patch (my own soul file, single section addition) |
| **Sub-task 1 total** | **0.8** | Fits Sprint 4 EOD |

## Cross-references

- Issue #238 (parent — this proposal's source)
- PR #242 (sister — CLAUDE.md amendment, sub-task 0)
- ADR-0002 (autonomy loop — foundation)
- ADR-0037 (proactive gap-scan, D6 dev_idle is the operational detector for 2 of the 4 modes)
- `.claude/CLAUDE.md` L354 (doctrine: "Edit other agents' soul files" forbidden)
- PR #226 / PR #242 (precedent — architect proposes, human applies)

## Rollback

Revert this proposal PR. Zero impact on existing soul files. (If the human already applied the changes, they revert the soul files directly.)
