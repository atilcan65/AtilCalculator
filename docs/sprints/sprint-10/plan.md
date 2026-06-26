# Sprint 10 — Plan

> **Author:** @orchestrator
> **Date:** 2026-06-26T10:37+03:00 = 07:37Z
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner override carry from Sprint 4-9, ADR-0031)
> **Window:** No fixed end — stories ship when ready, merges when green
> **PM proposed-scope shipped:** PR #416 (merged 2026-06-26T07:36:21Z, commit 57b2d43)
> **PM source-of-truth:** [./proposed-scope.md](./proposed-scope.md) (153 LoC, merged via PR #416)
> **PM rationale:** [./proposed-scope.md](./proposed-scope.md) §Sprint 10 scope (lines 18-69)
> **Source of stories:** Day 7 RETRO-005 ceremony dispositions (Issue #407 cmt 4807091011) — Items 1, 4, 5, 6 RATIFIED + Item 7 already CLOSED
> **Refs:** [Sprint 9 close-out (PR #413 MERGED 06:23:48Z, commit 7d8dbd6)](https://github.com/atilcan65/AtilCalculator/pull/413), Issue #415 (kickoff, status:in-progress)

## TL;DR

- **Mode**: CONTINUOUS FLOW (owner override carry from Sprint 4-9)
- **Window**: No fixed end — stories ship when ready, merges when green
- **Total committed**: 6.0 SP Sprint 10 + 1.0 SP Sprint 11 P2 (#26 carryover)
- **Critical path**: 3.0 SP Sprint 10 P1 (#18+#20+#4) — soul amendments + label-check workflow fix
- **Capacity allocation**: P1 = 3.0 SP / P2 = 2.0 SP / P3 = 1.0 SP (well within ~22 SP cap)
- **Owner override territory**: 5 stories — #4 ADR-0012 + #5 agent-watch ADR + #18+#20 (combined soul) + #24 PM soul + #26 5-soul amend, all owner-merge gated

## Sprint 10 scope (committed)

### P1 — Critical path (3.0 SP, must ship)

| ID | Title | Issue | Owner | SP | Type |
|---|---|---|---|---|---|
| **#18+#20** | Stale-state family soul amend (orch + PM combined PR) | #374, #378 | @orchestrator (#374) + @product-manager (#378) — single combined PR | 2.0 | docs (soul amend) |
| **#4** | ADR-0012 amendment: label-check cascade-strip scope-tightening + `.github/workflows/label-check.yml` Part 1 fix | #394 | @architect (ADR-0012 amend) + @human (workflow file, owner-only territory) | 1.0 | docs (ADR) + chore (workflow, owner-gated merge) |

**#18+#20 details** (per Item 1 disposition):
- orchestrator.md §Standard Workflows pre-broadcast REPRIME step + heartbeat compaction-state log
- orchestrator.md §Pre-Kickoff Gate + plan-file-as-snapshot doctrine
- product-manager.md §plan-file-as-snapshot (PM-owned companion)
- Single combined PR, 2 soul files, ~30 LoC total, owner merge ~5 min

**#4 details** (per Item 4 disposition):
- ADR-0012 amendment: mutual-exclusion OK ama cascade-strip too aggressive — scope cleanup to ONLY duplicate `status:*` label, NOT reviewer chain
- `.github/workflows/label-check.yml` Part 1: only remove duplicate `status:*`, NOT cascade-strip reviewer chain
- Part 2 (future): auto-add `status:ready` only when ALL reviewer chain labels correctly cleared
- d-test for workflow fix (mandatory regression coverage)
- owner-merge gated (no agent push to `.github/workflows/` per CLAUDE.md)
- Rationale: 3 instances (PR #391/#392/#393), ongoing risk, owner-merge gated

### P2 — Standard track (2.0 SP)

| ID | Title | Issue | Owner | SP | Type |
|---|---|---|---|---|---|
| **#24** | PM soul §Mid-sprint clarification with explicit "comments-since-last-read delta" cite | #395 | @product-manager | 1.0 | docs (soul amend) |
| **#5** | agent-watch.sh multi-REPO + cross-repo scan script + ADR | #377 | @architect (ADR-0047 multi-REPO) + @developer (agent-watch.sh + cross-repo-scan scripts) | 1.0 | feat (scripting) + docs (ADR-0047) |

**#24 details** (per Item 1 disposition amendment):
- PM soul §Mid-sprint clarification MUST explicitly cite "comments-since-last-read delta" as MANUAL pre-verdict check (3-line pre-flight, no dev PR)
- Rationale: PM self-correction within 8min on #390 demonstrates operational discipline exists; soul codification hardens it without tooling dep
- Sprint 10 P2 single PR, 1 soul file, ~10 LoC

**#5 details** (per Item 5 disposition + arch review clarification):
- Hybrid option 1+3: `--repo owner/name,owner/name2` flag for agent-watch.sh + `scripts/cross-repo-scan.sh` in autonomy loop + ADR-0047
- Cross-repo work büyüyor (Sprint 6 follow-on, dev-studio-template port), tester AtilCalc-only queue blind spot
- 1 ADR (arch-authored per file ownership matrix) + 2 code PRs (dev-owned: agent-watch.sh + cross-repo-scan.sh)
- Owner: @architect (ADR-0047) + @developer (scripts) — corrected from initial @orchestrator spec

### P3 — Buffer (1.0 SP, can slip)

| ID | Title | Issue | Owner | SP | Type |
|---|---|---|---|---|---|
| **#6** | PR #381 4-obs batched hygiene | #382 | @developer (381.2/381.3/381.4) + @orchestrator (381.1) | 1.0 | docs + chore |

**#6 details** (per Item 6 disposition):
- 4 obs batched: 381.1 (orch, watcher isDraft filter) P3 / 381.2 (dev, d036d TC count framing) trivial / 381.3 (dev, README ADR-0017 link) trivial / 381.4 (dev, --version) Sprint 7+ nice-to-have
- Non-blocking hygiene, can be opportunistic
- Defer to Sprint 11 P3 if Sprint 10 P3 buffer full

## Sprint 11 P2 carryover (1.0 SP)

| ID | Title | Issue | Owner | SP | Trigger |
|---|---|---|---|---|---|
| **#26** | 5-soul ground-truth query amendment | #414 | @orchestrator (5-soul PR) | 1.0 | At 5+ instances OR Sprint 11 grooming decision |

**#26 details** (per Item 1 disposition):
- Deferred from Sprint 9 P1 (3 instances insufficient for 5-soul amend high cost)
- INTERIM operational memory NOW: each role adds §Dispatch Discipline pre-flight (tester #414 proposal)
- Tester already committed in #414 cmt 4806942573
- 5-soul amend triggered at 5+ instances OR Sprint 11 grooming decides

## Sprint 10 capacity allocation

| P-tier | Stories | SP | % of total |
|---|---|---|---|
| **P1 (critical)** | #18+#20+#4 | 3.0 SP | 50% |
| **P2 (standard)** | #24+#5 | 2.0 SP | 33% |
| **P3 (buffer)** | #6 | 1.0 SP | 17% |
| **Total** | 6 stories | **6.0 SP** | 100% |

Within healthy range (~22 SP cap). 50% P1 allocation appropriate given 2 owner-merge-gated stories.

## Sprint 10 sprint tag flips (executed by orchestrator at plan-publish)

For Issues with Item 1+4+5+6 dispositions (Sprint 10 commitments):

| Issue | Current `sprint:*` | Target | Status flip |
|---|---|---|---|
| #374 (#18) | `sprint:backlog` | `sprint:future` (now in Sprint 10 ready) | status:backlog → status:ready |
| #378 (#20) | `sprint:backlog` | `sprint:future` | status:backlog → status:ready |
| #395 (#24) | `sprint:backlog` | `sprint:future` | status:backlog → status:ready |
| #414 (#26) | `sprint:backlog` | (keep Sprint 11 — no flip) | (no flip) |
| #394 (#4) | (none) | `sprint:future` | status:backlog → status:ready |
| #377 (#5) | `sprint:backlog` | `sprint:future` | status:backlog → status:ready |
| #382 (#6) | `sprint:backlog` | `sprint:future` | status:backlog → status:ready |

Agent reassignments (per ADR-0015 atomic handoff, owner swap on dispatch):
| Issue | Old `agent:*` | New `agent:*` | New `cc:*` |
|---|---|---|---|
| #374 (#18) | agent:product-manager | agent:orchestrator | cc:product-manager + cc:developer |
| #378 (#20) | agent:product-manager | agent:product-manager | cc:orchestrator + cc:developer |
| #395 (#24) | agent:product-manager | agent:product-manager | cc:developer |
| #394 (#4) | agent:product-manager | agent:architect | cc:developer + cc:human (workflow) |
| #377 (#5) | agent:product-manager | agent:architect | cc:developer |
| #382 (#6) | agent:product-manager | agent:developer | cc:orchestrator (1 obs) |
| #414 (#26) | agent:product-manager | (no change — Sprint 11 defer) | (no change) |

## Sprint 10 critical path

```
Sprint 10 P1 (parallel after dispatch)
├── #18+#20 (combined PR)         → orchestrator (#374) + product-manager (#378) (1 PR, ~30 LoC soul amend, owner merge ~5 min)
└── #4 (ADR + workflow)           → architect ADR spec → human owner-merge workflow file fix

Sprint 10 P2 (parallel after P1 starts)
├── #24 (PM soul §Mid-sprint)     → product-manager (single PR, ~10 LoC)
└── #5 (agent-watch multi-REPO)   → architect ADR + developer code

Sprint 10 P3 (slip-OK)
└── #6 (PR #381 4-obs batch)      → developer (3 obs) + orchestrator (1 obs)
```

## Risks

1. **Owner-merge bottleneck** (5 stories: #4 + #5 + #18+#20 + #24 + #26) — mitigation: parallelize P1+P2 work so owner merges can interleave
2. **Cross-repo scan script** (#5) may have scope creep — mitigation: ADR spec locks scope before dev PR
3. **PR #381 4-obs batch** (#6) can slip to Sprint 11 P3 — low impact (non-blocking hygiene)
4. **5-soul amend trigger** (#26) needs sustained pattern observation — INTERIM operational memory is the bridge

## Sprint 10 close targets

- ✅ P1 3.0 SP shipped (especially #4 ADR-0012 amendment + workflow fix)
- ✅ P2 2.0 SP shipped
- ⚠️ P3 1.0 SP (slip-OK)
- ✅ Sprint 10 close doc (orchestrator)
- ✅ Sprint 10 retrospective (Day 14 or as scheduled)

## Open questions for owner

1. **#4 owner-merge timing**: when can owner merge `.github/workflows/label-check.yml` change? (P1 critical path depends on this)
2. **#5 cross-repo ADR number**: ADR-0047 confirmed per arch (PR #416 review)
3. **#26 trigger model**: 5+ instances OR Sprint 11 grooming — owner ratification needed at Sprint 10 close

## Resolved (carried from Sprint 9 + Day 7 ceremony)

- ✅ **Sprint 10 mode = CONTINUOUS FLOW** (owner override carry from Sprint 4-9, ADR-0031)
- ✅ **PR #416 merge** (PM proposed-scope shipped 2026-06-26T07:36:21Z, commit 57b2d43)
- ✅ **Sprint 10 scope arithmetic** (6.0 SP, P1=3.0, P2=2.0, P3=1.0, Sprint 11 carry = 1.0)
- ✅ **Sprint 10 file ownership** (arch for ADRs, dev for scripts, PM for soul, owner for workflows — per CLAUDE.md matrix)
- ✅ **Item 1 RATIFIED** (Day 7 ceremony, cmt 4807091011, owner delegated "reasonable AND necessary")
- ✅ **Items 4-7 RATIFIED** (Day 7 ceremony, cmt 4807091011, owner delegated "kritik ve olmalıysa yap")
- ✅ **Sprint 9 CLOSED** (Issue #407 status:done, 5/5 stories shipped)
- ✅ **Day 7 ceremony concluded**
- ✅ **Sprint 9 close-out commit 7d8dbd6 MERGED on main** (PR #413 at 06:23:48Z, supersedes prior 9975961 on `feat/d046-expansion-adr-0044-literal-form` branch)

## Sprint 10 board state (as of 2026-06-26T07:45Z, post-auto-claim)

| Column | Item | Owner | Status |
|---|---|---|---|
| **In Progress** | #415 (Sprint 10 kickoff, stays open to Sprint 10 close) | orchestrator | status:in-progress |
| **In Progress** | #374 (P1 #18+#20 orch soul amend, auto-claimed) | orchestrator | status:in-progress |
| **In Progress** | #378 (P1 #18+#20 PM soul amend, auto-claimed) | product-manager | status:in-progress |
| **In Progress** | #395 (P2 #24 PM §Mid-sprint, auto-claimed) | product-manager | status:in-progress |
| **In Progress** | #394 (P1 #4 ADR-0012 amend, auto-claimed) | architect | status:in-progress |
| **In Progress** | #377 (P2 #5 ADR-0047, auto-claimed) | architect | status:in-progress |
| **In Progress** | #382 (P3 #6 PR #381 4-obs dev share, auto-claimed) | developer | status:in-progress |
| **In Review** | PR #417 (orch supplementary plan, draft) | orchestrator | 1/5 peer verdicts (tester 🟢) |
| **Backlog** | #414 (#26 5-soul ground-truth amend) | orchestrator (Sprint 11 P2) | status:backlog, sprint:next |

**Sprint 10 dispatch recap:**
- Sprint tag flips executed: 6 stories → sprint:current (Sprint 10 active) + #414 → sprint:next (Sprint 11 P2)
- Agent reassignments per ADR-0015: #374 orch, #394/#377 arch, #382 dev, #378/#395 PM kept
- Auto-claim (ADR-0038) fired on all 5 Sprint 10 stories — they all moved status:ready → status:in-progress within 60s of dispatch
- WIP state: orch=2/2 (effective, #415 + #374), PM=2/2 (#378 + #395, cap hit), arch=2/2 (#394 + #377, cap hit), dev=1/2 (#382), tester=0/2

**Note on previous board state drift (PR #417 OBS-2 + PM NIT):**
Original plan.md (a4441e9) had #415 in "Done" column and 5 stories in "Ready" — both stale assumptions from pre-dispatch snapshot. Auto-claim (ADR-0038) moved stories to "In Progress" before peer review started. Corrected in b4441e9 (this commit).

— Orchestrator, 2026-06-26T07:45Z (Sprint 10 dispatched, OBS-1 + OBS-2 fixup, board state corrected post-auto-claim)
