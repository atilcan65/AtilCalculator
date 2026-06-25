# Current Sprint — Pointer

> **Active sprint:** **Sprint 7 — Doctrine companion (RE-PLANNED 2026-06-25T19:08+03:00 post-REPRIME)**
>
> 📄 **See:** [../sprint-07/plan.md](../sprint-07/plan.md) (re-planned, lead track marked DONE pre-kickoff)
> 📄 **Source-of-truth backlog:** [../sprint-07/backlog.json](../sprint-07/backlog.json)
> 📄 **Sprint 7 kickoff tracking issue:** [#376](https://github.com/atilcan65/AtilCalculator/issues/376) (REPRIME recovery in progress)
> 📄 **Doctrinal gap filed:** [#378](https://github.com/atilcan65/AtilCalculator/issues/378) (RETRO-005 #18 candidate, iteration 2 of #374)
>
> **Mode:** 🚀 **CONTINUOUS FLOW** (owner directive 2026-06-25T18:25Z chat) — Sprint 6 + Sprint 7 overlap permitted, no sprint boundary waiting.
> **Window:** 2-week default (2026-06-25 → 2026-07-09), owner-decision per CLAUDE.md §Sprint duration doctrine
> **Scope:** ⚠️ **RE-PLANNED**: 2.0 SP remaining (#296 + #319) — Sprint 7 P0 lead-track (4.5 SP) + Sprint 6 P2 carry (2.5 SP) = 7.0 SP DONE pre-kickoff
> **Status:** 🟡 **ACTIVE — Sprint 7 started 2026-06-25T18:25Z**, RE-PLANNED 2026-06-25T19:08Z post-REPRIME. PM verdict pending on final scope (option A/B+316/B+370/C).
>
> **Critical path (Sprint 7 remaining):**
> 1. **#296** (peer-poke discipline, P1, orch + owner, 1.0 SP) — scripts/peer-poke.sh helper + 5-soul amendment (owner territory). Spec: [../../peer-poke-spec.md](../../peer-poke-spec.md)
> 2. **#319** (verdict-by enforcer refinement, P2, orch + dev, 1.0 SP) — script-touch on `scripts/agent-watch.sh` `query_stale_verdict` per ADR-0044 §Scope rule, plus d-test (0.5 SP orch + 0.5 SP dev)
> 3. **PM verdict** (pending) — A/B+316/B+370/C for Sprint 7 final scope + Sprint 8 scope
>
> **Sprint 7 P0 lead-track DONE (verified 2026-06-25T19:08Z post-REPRIME):**
> - PR #314 (STORY-300 multi-op + ** power) ✅ MERGED 2026-06-23T20:20:11Z (3d2406b8)
> - PR #318 (STORY-301 REPL mode) ✅ MERGED 2026-06-23T21:15:25Z (15a0db3d)
> - #299 / #300 / #301 ✅ CLOSED COMPLETED pre-kickoff
>
> **Sprint 6 follow-on (DONE):**
> - PR #61 (dev-studio-template, PR-T8+PR-T10+ADR-0047) ✅ MERGED 2026-06-25T15:42:46Z (ea482da1) by owner
> - #198 (template port) ✅ CLOSED COMPLETED 2026-06-25T16:02:24Z (manual, OBS-1 cross-repo-close gap)
> - #375 (PR-T8+T10 design) ✅ CLOSED COMPLETED 2026-06-25T15:35:40Z
> - **Sprint 6 close-out**: pre-staged at [../sprint-06/close.md.draft](../sprint-06/close.md.draft) + [post-merge-staging.md](../sprint-06/post-merge-staging.md); finalization pending (#198 closed ✅, only commit + broadcast left)
>
> **Sprint 6 day 2 milestone (already shipped)**:
> - PR #373 (notify.sh dual-channel, ADR-0033 enforcement) ✅ MERGED @ 9fed64a
> - PR #58 (ADR-0046 d-test convention) ✅ MERGED @ 15:06:27Z
> - PR #60 (cross-repo-close.yml port) ✅ MERGED @ 15:16:58Z
> - PR #61 (dev-studio-template, PR-T8+PR-T10+ADR-0047) ✅ MERGED @ 15:42:46Z by owner (post-kickoff merge)
> - Issue #372 (cross-repo-close.yml gap) ✅ CLOSED (manual, recursive origin pattern)
> - Issue #375 (PR-T8+T10 abstraction design) ✅ CLOSED @ 15:35:40Z
> - Issue #198 (Sprint 6 P2 carry) ✅ CLOSED COMPLETED 2026-06-25T16:02:24Z
> - Issue #377 (RETRO-005 #4 candidate, cross-repo dispatch gap) ✅ FILED for PM day 7+
> - Issue #378 (RETRO-005 #18 candidate, iteration 2 of #374 orch stale-state) ✅ FILED 2026-06-25T19:08Z
>
> **Sprint 5 reference:**
> - Sprint 5 close: PR #292 (commit 345c25c, 2026-06-23T11:06:13Z)
> - RETRO-004 at [../sprint-04/RETRO-004.md](../sprint-04/RETRO-004.md), PR #282 merged
>
> — Orchestrator, 2026-06-25T19:08+03:00 (REPRIME re-plan, Sprint 7 re-scoped to 2.0 SP remaining)
