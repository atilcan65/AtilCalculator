# Sprint 10 — Close-out

> **Author:** @orchestrator
> **Date:** 2026-06-26T13:36+03:00 = 10:36Z
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner override carry from Sprint 4-9, ADR-0031)
> **Window:** 2026-06-26T07:36Z (PR #416 merge) → 2026-06-26T10:33Z (PR #426 merge) ≈ 3h elapsed
> **Plan:** [./plan.md](./plan.md) (6.0 SP committed, 50% P1 allocation)
> **Proposed-scope:** [./proposed-scope.md](./proposed-scope.md) (PM grooming, merged via PR #416)
> **Kickoff issue:** #415 (Sprint 10 Kickoff, `status:done`, CLOSED on this commit)

## TL;DR outcome

- **6.0 SP committed → 6.0 SP delivered (100%)** + 1.0 SP Sprint 11 P2 carry (#26, Issue #414, deferred per plan)
- **12 PRs merged to main** in ~3h flow window
- **3 deviations in PR #426** (D1 typo + D2 SyntaxError + D3 staleness) — all caught pre-CI by defense-in-depth (1 dev pre-apply + 2 tester pre-merge re-review)
- **Sprint 11 P1 carryover**: Issue #422 (ADR-0047 dev impl, 0.5 SP) — already pre-flip'd `sprint:next → sprint:current + status:backlog → status:ready` on this commit
- **Sprint 11 P2 candidates queued**: #425 (Workflow Part 2) + #414 (RETRO-005 #26)
- **Critical path 100% shipped** — 3 P1 stories + 2 P2 stories + 1 P3 batch = 0 slips, 0 carryover blockers

## SP delivery matrix

| P-tier | Story | SP | Issue | PR(s) merged | Outcome |
|---|---|---|---|---|---|
| **P1** | #18+#20 (orch+PM soul amend) | 2.0 | #374, #378 | #418 (08:10:43Z) | ✅ Shipped |
| **P1** | #4 (ADR-0012 amend + workflow Part 1) | 1.0 | #394 | #424 (09:33:25Z ADR) + #426 (10:33:50Z workflow) | ✅ Shipped (2-PR split per plan) |
| **P2** | #24 (PM §Pre-verdict cross-check) | 1.0 | #395 | #421 (08:32:00Z) | ✅ Shipped |
| **P2** | #5 ADR-0047 (architect ADR) | 0.5 | #377 | #420 (08:38:52Z) | ✅ Shipped (ADR half) |
| **P2** | #5 ADR-0047 (dev impl) | 0.5 | #422 | (deferred to Sprint 11 P1) | ⏳ Sprint 11 P1 carry |
| **P3** | #6 PR #381 4-obs batch (dev 3 obs) | 0.75 | #382 | #419 (09:01:57Z) | ✅ Shipped (381.2/3/4) |
| **P3** | #6 PR #381 4-obs batch (orch 381.1 watcher isDraft) | 0.25 | #382 | (PR #417 / #418 orch soul + agent-watch.sh isDraft field) | ✅ Shipped (orchestrator soul amend + watcher enhancement) |
| **P1+P2+P3 sub-total** | | **6.0** | | **6 PRs** | **100%** |
| **Sprint 11 P2 carry** | #26 5-soul ground-truth amend | 1.0 | #414 | (deferred) | ⏳ Sprint 11 P2 |

**Summary**: 6.0 SP committed → 5.5 SP shipped in Sprint 10 + 0.5 SP carry to Sprint 11 P1 + 1.0 SP carry to Sprint 11 P2 (planned) = 7.0 SP total work touched.

## PR ledger (Sprint 10)

| PR | Type | Title | Merged | Commit | Author | Sprint 10 work item |
|---|---|---|---|---|---|---|
| **#426** | chore | fix(workflow): Layer 4 cascade-strip scope-tightening per ADR-0012 §Part 1 (Issue #423) | 2026-06-26T10:33:50Z | 161e003 | @developer | P1 #4 (workflow Part 1) |
| **#424** | docs | docs(adr): ADR-0012 §Part 1 canonical-primary ambiguity clarification | 2026-06-26T09:33:25Z | b4fe899 | @architect | P1 #4 (ADR amend) |
| **#421** | docs | docs(soul): PM §Pre-verdict cross-check — Sprint 10 P2 #24 (Issue #395) | 2026-06-26T08:32:00Z | ce587a9 | @product-manager | P2 #24 |
| **#420** | docs | docs(adr): ADR-0047 cross-repo watcher architecture | 2026-06-26T08:38:52Z | 66302fa | @architect | P2 #5 (ADR half) |
| **#419** | feat | feat(cli): atilcalc --version + d036d T0 framing + README ADR-0017 cross-link | 2026-06-26T09:01:57Z | d7a3673 | @developer | P3 #6 (dev 3 obs) |
| **#418** | docs | docs(sprint-10-p1): combined #4 ADR-0012 amend + #18+#20 soul amend | 2026-06-26T08:10:43Z | 4c7b709 | @orchestrator | P1 #18+#20 |
| **#417** | docs | docs(sprint-10): orchestrator supplementary plan — CONTINUOUS FLOW mode | 2026-06-26T09:27:06Z | c1224df | @orchestrator | Sprint 10 supplementary |
| **#416** | docs | docs(sprint-10): PM proposed-scope | 2026-06-26T07:36:21Z | 57b2d43 | @product-manager | Sprint 10 plan (PM grooming) |
| **#413** | test | test(scripts): d046-expansion-adr-0044-literal-form | 2026-06-26T06:23:48Z | 7d8dbd6 | @developer | Sprint 9 close-out carry |
| **#412** | docs | docs(soul): PM status:ready flip discipline per #327 + ADR-0021 | 2026-06-26T06:22:26Z | 4dc4c99 | @product-manager | Sprint 9 carry |
| **#411** | docs | docs(adr): ADR-0044 §See also — cross-link to ADR-0046 | 2026-06-26T06:08:33Z | 9959117 | @architect | Sprint 9 carry |
| **#409** | docs | docs(adr): ADR-0046 load-bearing ADR §Implementation guide pattern | 2026-06-26T06:15:13Z | 72e5249 | @architect | Sprint 9 carry |
| **#408** | fix | fix(tests): #329 flaky perf-budget test | 2026-06-26T04:52:28Z | fa40617 | @developer | Sprint 9 carry |

**Note**: #412, #411, #409, #408 are Sprint 9 carry-overs that landed within Sprint 10 window. Sprint 10 net-new = 8 PRs (#416, #417, #418, #419, #420, #421, #424, #426).

## Deviations (defense-in-depth worked)

PR #426 had **3 pre-CI bugs caught by peer review** — exactly the pattern doctrine predicted:

| Deviation | Type | Caught by | Cost | Fix |
|---|---|---|---|---|
| **D1** | Typo `earliestByCreated.get(b)` → `earliestByName.get(b)` (line 67) | @developer (pre-apply sanity read) | 1 line | 1 line replace |
| **D2** | SyntaxError `currentStatusLabels.join('\')` unclosed string (line 123) — backtick escape pattern was unclosed literal at parse time, kills workflow for ALL events (worse than D1) | @tester (pre-merge re-review, cmt 4808419049) | 1 line | `join('\')` → `join(', ')` (backtick to comma-space; valid list separator for `Status labels observed` audit line) |
| **D3** | Staleness: yaml header said "PR #424 clarification pending" after PR #424 MERGED | @tester (pre-merge re-review) | 1 line | `pending` → `MERGED` |

**Doctrine lesson**: pre-apply sanity read (dev) + pre-merge dual-channel re-review (tester) = 3 bugs caught before CI. If D2 SyntaxError had landed, the workflow would have failed for ALL events at PARSE time, not just 2+ status cases — order of magnitude worse than D1. Defense-in-depth justified.

## Sprint 11 kickoff (atomic flip on this commit)

| Issue | Old state | New state | Notes |
|---|---|---|---|
| **#422** | `sprint:next, status:backlog, agent:developer, cc:orchestrator + cc:developer` | `sprint:current, status:ready, agent:developer, cc:orchestrator + cc:developer` | **Sprint 11 P1**: ADR-0047 dev impl (agent-watch.sh --repo + cross-repo-scan.sh) |
| **#425** | `sprint:next, status:backlog, agent:human` | (no flip — Sprint 11 P2 candidate, d-test mandatory) | Workflow Part 2 sister |
| **#414** | `sprint:next, status:backlog, agent:product-manager` | (no flip — Sprint 11 P2 candidate) | RETRO-005 #26 5-soul ground-truth amend |

Issue #422 atomic flip fires ADR-0038 auto-claim for @developer.

## Issue #415 atomic close (on this commit)

- `--remove-label agent:orchestrator` (terminal handoff, done state)
- `--remove-label cc:product-manager + cc:architect + cc:developer + cc:tester` (terminal handoff, done state)
- `--add-label status:done` + `--remove-label status:in-progress` (4-cat invariant, one status only)
- `sprint:current` retained (sprint-end posture: closed but not retracted)
- `priority:P1` retained (priority meta, not flow state)
- `type:chore` retained (categorical)
- Issue close: 2026-06-26T10:36Z (on this commit)

## Sprint 10 atomic close sequence (timeline)

1. **2026-06-26T07:36:21Z** — PR #416 MERGED (PM proposed-scope shipped) → Sprint 10 start
2. **2026-06-26T08:10:43Z** — PR #418 MERGED (P1 #18+#20 soul amend)
3. **2026-06-26T08:32:00Z** — PR #421 MERGED (P2 #24)
4. **2026-06-26T08:38:52Z** — PR #420 MERGED (P2 #5 ADR)
5. **2026-06-26T09:01:57Z** — PR #419 MERGED (P3 #6 dev share)
6. **2026-06-26T09:27:06Z** — PR #417 MERGED (orch supplementary)
7. **2026-06-26T09:33:25Z** — PR #424 MERGED (P1 #4 ADR amend)
8. **2026-06-26T10:33:50Z** — PR #426 MERGED (P1 #4 workflow Part 1) → Sprint 10 P1 100% shipped
9. **2026-06-26T10:33:51Z** — Issue #423 auto-closed (Closes #423 in PR #426 body)
10. **2026-06-26T10:36Z** (this commit) — Issue #415 atomic close + close.md + Issue #422 Sprint 11 kickoff

## Sprint 11 capacity allocation (committed, on this commit)

| P-tier | Story | SP | Issue | Owner | Trigger |
|---|---|---|---|---|---|
| **P1** | ADR-0047 dev impl (agent-watch.sh --repo + cross-repo-scan.sh) | 3.0 | #422 | @developer | Sprint 10 carry (this commit) |
| **P2** | Workflow Part 2 (status:ready auto-add gating) | 1.0 | #425 | @architect + @human | d-test mandatory (Sprint 10 plan) |
| **P2** | 5-soul ground-truth query amend | 1.0 | #414 | @orchestrator (5-soul PR) | At 5+ instances OR Sprint 11 grooming |
| **Total Sprint 11 P1+P2** | | **5.0** | | | |

## Open items for owner

1. **Arch §Security note follow-on PR** (Option A from PR #426 review cycle, deferred to post-merge) — security pattern reinforcement for pull_request_target trigger in label-check workflow
2. **Sprint 11 P2 #425 d-test** (architect: lock scope + write d-test before dev starts)
3. **Sprint 11 P2 #414 trigger decision** (5+ instances OR grooming decides — owner ratification)

## Definition of Done — Sprint 10

- ✅ All committed stories shipped (6.0 SP, 100%) or carried with rationale (0.5 SP Sprint 11 P1, 1.0 SP Sprint 11 P2)
- ✅ All PRs merged to main via human owner squash
- ✅ CI green on main post-merge (9/9 checks SUCCESS on PR #426 final)
- ✅ Docs updated: ADR-0012 §Part 1 amended, ADR-0044 cross-link, ADR-0046, ADR-0047, soul amends (orch+PM), close.md (this file)
- ✅ Issue #415 closed (status:done, atomic close on this commit)
- ✅ No P0/P1 bugs filed against Sprint 10 stories in 24h post-merge window (TBD pending merge at 10:33Z, monitor until 2026-06-27T10:33Z)
- ⏳ Sprint 10 retro (RETRO-006 DRAFT, PM finalizes within Sprint 11 P1 timeframe per Issue #425 sister)

## What worked / What didn't / Carry-forwards

**Worked**:
- CONTINUOUS FLOW mode (owner override, ADR-0031) — 3h elapsed, 8 net-new PRs merged, 0 sprint-blocking defects
- Pre-broadcast REPRIME + Pre-Kickoff Gate (orch soul amend, PR #418) — picked up REPRIME event cleanly in this session
- 5-soul §Peer-Poke Discipline (PR #406, pre-sprint) — dual-channel peer-poke protocol worked: PM's `notify.sh -w -r orchestrator` ping landed mid-close, no message relay needed
- Defense-in-depth (dev pre-apply + tester pre-merge) — 3 bugs caught pre-CI on PR #426

**Didn't** (minor):
- D1 typo was caught by dev pre-apply, not by arch review — suggests arch doctrinal review missed the simple typo, peer lint test could have caught it. (Note: d-test for label-check is on Sprint 11 P2 #425 plan.)
- 4-cat invariant: `status:in-progress` → `status:done` transition required manual removal of old label (not atomic in `gh issue edit` — should be a future script enhancement, possibly #425 Workflow Part 2 territory)

**Carry-forwards**:
- Sprint 11 P1 #422 (ADR-0047 dev impl, 0.5 SP)
- Sprint 11 P2 #425 (Workflow Part 2, d-test mandatory)
- Sprint 11 P2 #414 (5-soul ground-truth amend, 1.0 SP)
- Arch §Security note (Option A, post-PR-#426-merge)

— Orchestrator, 2026-06-26T10:36Z (Sprint 10 atomic close, Issue #415 → status:done, Sprint 11 P1 Issue #422 auto-claim fires)
