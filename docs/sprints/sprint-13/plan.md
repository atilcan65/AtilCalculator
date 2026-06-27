# Sprint 13 — Plan (ratified)

> **Status**: ACTIVE (2026-06-27T01:35+00:00 = 04:35+03:00)
> **Mode**: 🚀 **CONTINUOUS FLOW** (ADR-0031 owner override carry from Sprint 4-12)
> **Owner ratification**: @atilcan65 at 2026-06-27T04:34+03:00 ("scope ok")
> **Trigger**: Issue #463 disposition ✅ + Sprint 13 proposed-scope ratification ✅
> **PM lane definition (LOCKED this sprint)**: PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors (per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)

## Goal

Close the Sprint 12 doctrinal carry-forward cluster + codify RETRO-007 watchlist entries #3, #5, #6, #8 + apply PM lane definition. **7 stories total** (1 P0 + 3 P1 + 3 P2), no feature work.

## Capacity

- **architect**: 1/2 WIP (Issue #463 ADR-0050 PR open, peer-poke sent)
- **developer**: 0/2 WIP (gated on Issue #463 ADR Accepted)
- **tester**: 0/2 WIP (gated on dev d-test impl)
- **product-manager**: 1/2 WIP (grooming Sprint 13 P1 #3, #4)
- **orchestrator**: 0/2 WIP (kickoff facilitation)

## Committed stories

### P0 (owner territory)

1. **d050b TC1 owner carry** (Sprint 12 carry-forward, owner-implementable workflow file change per ADR-0049 §Implementation guide)
   - Owner: @atilcan65
   - Lane: `.github/workflows/` (human-only territory, agents propose via PR)
   - **No PM action needed**

### P1 (architect + PM-facilitated)

2. **§Pre-merge 4-cat verification d-test** — Issue #463 (5/5 agent steps DONE, awaiting owner squash)
   - Owner: @architect (ADR PR #464 🟢) + @developer (d-test impl PR #465 🟢, Closes #463) + @tester (sign-off 🟢 APPROVED)
   - PR #464: arch ADR-0050, MERGEABLE, status:ready + cc:human
   - PR #465: dev d-test impl, MERGEABLE, status:ready + cc:human, 9/9 TCs green, Closes #463
   - **CI integration (AC4) deferred to owner territory** (`.github/workflows/lint-and-test.yml` paths trigger)
   - 2.0 SP total (arch 0.5 + dev 0.5 + tester 0.5 + integration 0.5)
   - Sister-pattern to d046/d048/d050b/d051/d052 family
   - Cross-refs: RETRO-007 watchlist #3, ADR-0050, Issue #463
   - **Suggested squash sequence**: PR #464 → PR #465 (ADR gates impl)

3. **§Pre-verdict cross-check timing window codification** — Issue #470 (OPEN, status:backlog)
   - Owner: @product-manager (Issue #470)
   - 0.5 SP (PM doc amendment, arch review)
   - Origin: PR #460 PM-AC-VERIFY missed arch verdict due to GitHub GraphQL comment-propagation delay (30-60s window)
   - Discipline refinement: re-query within 30s of posting verdict, not 1+ min before
   - Lane: `docs/CLAUDE.md` §Dispatch Discipline (not human-only territory)
   - Sister-pattern: Issue #430 §Pre-verdict cross-check doctrine + Issue #414 §Dispatch Discipline 6-step
   - 5 observed instances (PR #460, #462, #465, etc.) — RETRO-007 watchlist entry #6 codification

4. **Sprint 13 PM lane definition amendment** — Issue #471 (OPEN, status:backlog)
   - Owner: @product-manager (Issue #471, PR opens) + @atilcan65 (squash merge)
   - 0.5 SP (PM proposes, owner merges per file ownership matrix)
   - Lane: `.claude/CLAUDE.md` (human-only territory)
   - Sister-pattern to RETRO-007 watchlist entry #9 (§PM-cc gap orchestrator signaling)
   - Closes RETRO-007 #9 on PR merge via Closes-anchor (strict format per ADR-0050 C9)

### P2 (architect carry, RETRO-007 watchlist codifications)

5. **§Dispatch Discipline in-flight body amend** — Issue #467 (OPEN, status:backlog)
   - Owner: @architect (Issue #467)
   - 0.5 SP (arch-only, docs/CLAUDE.md text apply via orchestrator PR)
   - Origin: PR #462 body amend Closes #461 → L1 was the trigger
   - Sister-pattern to #3 (PM-AC-VERIFY timing window)
   - Lane: docs/CLAUDE.md (orchestrator territory, not human-only)

6. **§Closes-anchor strict format d-test** — Issue #468 (OPEN, status:backlog)
   - Owner: @architect (doc) + @developer (d-test impl, d054) + @tester (sign-off)
   - 2.0 SP (arch 0.5 + dev 1.0 + tester 0.5)
   - d054 dedicated Closes-anchor d-test, deeper than d053 C9 sister
   - Sister-pattern to d046 (jq-filter guard) + d048 (Layer 5 reviewer chain) + d053 C9 (sister d-test)

7. **ADR-0049 (k) text apply** — Issue #469 (OPEN, status:backlog)
   - Owner: @architect
   - 0.5 SP (arch-only, ADR-0049 amendment)
   - Status: parked since Sprint 12, parked-to-P2 in Sprint 13
   - Lens (k) = JS syntactic correctness, sister to d046

### Backlog deferral candidates (Sprint 14+)

- STORY-013 (P1, #179) — implicit first operand from history, defer pending customer feedback
- DEPLOY-001-004 (P0-P2) — deferred per ADR-0017 (no HTTP surface decided)
- RETRO-003 (P1) — stale Sprint 2 retro, recommend close-as-superseded
- TEMPLATE-PORT (P1, #48) — stale template work, recommend close-as-superseded

## Sizing (joint, per ADR-0024) — 100% COMPLETE @ 2026-06-27T04:47+03:00

| # | Story | arch | dev | tester | total | PR |
|---|---|---|---|---|---|---|
| 1 | d050b TC1 (owner territory) | — | — | — | owner | TODO owner-implement |
| 2 | §Pre-merge 4-cat verification (Issue #463, d053) ✅ DONE | 0.5 ✅ | 0.5 ✅ | 0.5 ✅ (+ integration 0.5) | 2.0 SP ✅ | #464 + #465 |
| 3 | §Pre-verdict cross-check timing window (Issue #470) ✅ PR OPEN | TBD | — | — | 0.75 SP ✅ | #472 |
| 4 | PM lane def amendment (Issue #471) ✅ PR OPEN | — | — | — | 0.5 SP ✅ | #473 |
| 5 | §Dispatch Discipline in-flight body amend (Issue #467) | 0.5 | — | — | 0.5 SP | — |
| 6 | §Closes-anchor strict format d-test (Issue #468, d054) | 0.5 | 1.0 | 0.5 | 2.0 SP | — |
| 7 | ADR-0049 (k) text apply (Issue #469) | 0.5 | — | — | 0.5 SP | — |
| **TOTAL** | | | | | **6.25 SP** | 4 PRs ready |

**Joint sizing verdict (PM-finalized per ADR-0024)**:
- P1 #2: 2.0 SP (agent DONE, PR #464+#465 owner squash pending)
- P1 #3: 0.75 SP (PM PR #472 ready, owner squash pending)
- P1 #4: 0.5 SP (PM PR #473 ready, owner-merge territory)
- P2 #5: 0.5 SP (arch lane, Issue #467)
- P2 #6: 2.0 SP (arch+dev+tester joint, Issue #468)
- P2 #7: 0.5 SP (arch lane, Issue #469)
- **6.25 SP total**, 100% sized

## Risks

1. **d050b TC1 owner-implementation slip**: owner territory, owner-implementable but no agent can self-execute. Owner blocked = Sprint 13 P0 carry stays unresolved.
2. **arch stall recurrence**: arch was 10h37m stalled on Issue #463. Mitigation: peer-poke sent, owner-approved, but watch 1h ack window.
3. ✅ **RESOLVED — ENGINE PERF CI FLAKE** (was misattributed as deterministic regression): PR #472 Lint & Test FAIL at p99=143ms was transient flake per Issue #329 hypothesis (environmental sensitivity, 50ms threshold tight for CI variance). All 4 P1 PRs CI re-ran GREEN @ 2026-06-27T05:01Z. **No fix needed.** Ground truth re-verified via `gh pr view <N> --json statusCheckRollup`. PM misattribution now documented as RETRO-008 §Flake vs regression candidate (concrete example).
4. 🆕 **CI re-run race condition** (RETRO-008 candidate): PR #472 status:ready auto-promote raced PM status:in-review flip. Tester misattribution (flake vs regression) caught by PM §Timing window doctrine.
3. **PM lane def amendment territory friction**: `.claude/CLAUDE.md` is human-only. PM proposes, owner merges. Latency = owner merge speed.
4. **Sizing ceremony SLA breach**: ADR-0024 verdict SLA framework requires arch+dev+tester to size jointly. Risk: agents solo-size instead.

## Critical path

1. arch ADR-0050 PR open (PR #464) ✅ MERGED @ 2026-06-27T05:25:26Z (sha 0ddbe80, status:done auto-promoted)
2. dev d-test impl (PR #465) ✅ MERGED @ 2026-06-27T05:24:27Z (sha 59f8d62, status:done auto-promoted, Closes #463)
3. tester sign-off ✅ DONE (🟢 APPROVED, Layer 5 auto-promoted, post-merge verify on main @ 0ddbe80 SUCCESS)
4. PM timing window PR (PR #472) ✅ **🟢 APPROVED** (post-tester re-verify @ 04:57Z). PM fix @ 764a45e VERIFIED CORRECT. Labels cleaned. CI FAIL was **TRANSIENT FLAKE per Issue #329 hypothesis** (NOT deterministic regression) — fresh re-query at 2026-06-27T05:01Z showed Lint & Test SUCCESS. RETRO-008 §Flake vs regression candidate now has concrete example.
5. PM lane def PR (PR #473) ✅ DONE (status:ready + cc:human, C9 strict ✅, HUMAN-ONLY territory + gitignore force-add note)
6. ✅ **ENGINE PERF SINGLE-FLAKE RESOLVED ON MAIN** (NOT deterministic regression, NOT fixed by PR #464): PR #465 alone on main @ 59f8d62 had CI FAIL (run 28279816671: p99=209.64ms vs 50ms budget + p99=102.78ms vs 100ms budget). Same engine code on main @ 0ddbe80 (after PR #464 doc-only merge) had CI SUCCESS (run 28279839346). Dev correction ACK confirmed: PR #464 didn't fix anything — second run was a flake pass. Single-flake instance per Issue #329 hypothesis (environmental sensitivity). RETRO-008 §Flake vs regression candidate has concrete example.
7. ✅ **owner squash PR #464** MERGED @ 2026-06-27T05:25:26Z (sha 0ddbe80, status:done auto-promoted by Layer 5)
8. ✅ **owner squash PR #465** MERGED @ 2026-06-27T05:24:27Z (sha 59f8d62, status:done auto-promoted by Layer 5, **Closes #463** auto-fired)
9. **owner squash PR #472** 🟡 AWAITING — **READY** (PM §Timing window, MERGEABLE, CI all green). **Closes #470**
10. **owner squash PR #473** 🟡 AWAITING — **READY** (PM lane def, MERGEABLE, CI all green, HUMAN-ONLY territory). **Closes #471**
11. ✅ Issue #463 AUTO-CLOSED via closes-anchor @ 2026-06-27T05:24:28Z (ADR-0050 carrier)
12. CI integration (`.github/workflows/lint-and-test.yml` paths update) 🟡 d050b TC1 owner territory — **deferred** (no longer Sprint 13 critical path; Sprint 14 P0 carry candidate)

## Definition of Done — Sprint 13

- [ ] All committed stories shipped (TBD SP after joint sizing) or carried with rationale
- [ ] All PRs merged to main via human owner squash
- [ ] CI green on main post-merge
- [ ] Docs updated: PM lane definition amendment, RETRO-007 watchlist additions (#6 timing, #8 in-flight, #9 PM-cc gap), close.md
- [ ] Sprint 13 kickoff issue closed (status:done, atomic close)
- [ ] No new P0/P1 bugs filed against Sprint 13 stories in 24h post-merge window

## Cross-refs

- Sprint 13 proposed-scope: `docs/sprints/sprint-13/proposed-scope.md` (PM draft)
- Issue #463 (ADR-0050 carrier): https://github.com/atilcan65/AtilCalculator/issues/463
- ADR-0050: `docs/decisions/ADR-0050-pre-merge-4-cat-verification.md`
- RETRO-007 watchlist (9 entries)
- Sprint 12 close: `docs/sprints/sprint-12/close.md`

— @orchestrator, 2026-06-27T04:35+03:00, Sprint 13 ratified plan
