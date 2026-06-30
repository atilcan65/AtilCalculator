# Current Sprint — Pointer

> **Active sprint:** **Sprint 22 — PIVOT: Self-Hosted Runner + 3-Repo Org Migration + Template Visibility**
>
> 📄 **Orchestrator-published plan (DRAFTED cycle ~1519):** [../sprint-22/plan.md](../sprint-22/plan.md) (5-Phase Plan, 8 risks, 8 DoD criteria, 10 open Q's — owner verdict pending on Q1/Q2/Q4-Q12)
> 📄 **PM-drafted scope (owner GO):** [Issue #708](https://github.com/atilproject/AtilCalculator/issues/708) (Plan v3 final, owner GO verdict cycle ~#1512 follow-up, 5-Phase Plan + 10 Open Questions + 8 Risk register)
> 📄 **Predecessor (Sprint 21 STALLED → carry-over):** [../sprint-21/close.md](../sprint-21/close.md) (Wave 1 pre-dispatch, PRs ready, sizing never executed — Q6 owner-decision: abandonment vs carry-over, **default carry-over per Issue #708 §In-flight migration continuity**, skeleton drafted cycle ~#1552)
> 📄 **Predecessor (Sprint 18 PROJECT CLOSED):** [../sprint-18/close.md](../sprint-18/close.md) (AtilCalculator FINAL 8/8 SHIPPED, PR #625 squash @ e4bfa3e)
> 📄 **Predecessor (Sprint 20 folded):** [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md) §6
>
> **Mode:** 🚀 **SPRINT 22 PIVOT EXECUTION** — owner GO verdict (Issue #708, status:in-progress, agent:orchestrator + agent:developer — co-piloted). Strategy v3 final: 8 self-hosted runners (atilproject org, owner VM 192.168.1.197) + 3-repo org migration (atilcalculator + dev-studio-template + dev-studio-launcher → atilproject) + template visibility default-private. GH-hosted runner dependency ZERO. R3 SPOF (single VM) → 2. VM redundancy Sprint 23+.
>
> ⚠️ **CRITICAL CORRECTION cycle ~#1566** (arch v3 CORRECTION cmt 4841705205): Sprint 22 PIVOT critical-path STILL BLOCKED. PR #710 (clone-URL scripts) did NOT validate self-hosted runner infra — it modified 0 workflow files and its CI ran on GH-hosted `ubuntu-latest`. **NEW IMPLICIT Faz 2.5b (owner-action ~5-10min)** filed as Issue #711 — enable atilproject org-runner access for atilproject/AtilCalculator repo (Settings → Actions → Runners). Sprint scope-change (19 phases, was 18). See plan.md §Faz 1.1 correction note + §Faz 2.5b.
>
> **Status:**
> - 🟢 **Sprint 18 PROJECT CLOSED** (PR #625 squash @ e4bfa3e, all 8 stories SHIPPED)
> - 🟢 **Sprint 20 PROJECT CLOSED** (PM RECOMMENDATION (b) ACHIEVED — folded into Sprint 18 squash)
> - 🟡 **Sprint 21 SCOPE RATIFIED** (PR #626 squash @ a5e0942) but **STALLED at Wave 1 pre-dispatch** — 10 PRs all MERGEABLE + ready, sizing never executed, Wave 1 dispatch never landed. **Q6 owner-decision (default carry-over per Issue #708), close-out skeleton drafted cycle ~#1552**
> - 🚀 **Sprint 22 PIVOT EXECUTION** (owner GO, Issue #708 status:in-progress, 5-Phase Plan underway)
>
> **Origin directive (Sprint 22 PIVOT trigger, Issue #708 author @atilcan65)**:
> Owner pivot: GH-hosted runner dependency eliminated via 8 self-hosted runners on owner's VM. 3 repos (atilcalculator + dev-studio-template + dev-studio-launcher) migrated to atilproject org. Template visibility default-private. Self-hosted runner auto-discovery replaces GH-hosted at PR open time. "Hiçbir detayı kaçırma" — full infra sovereignty.
>
> **In-flight migration continuity (must survive 3-repo org migration):**
> - **PR #694** (tester d-test, agent:tester, status:ready, cc:human) — Closes #633
> - **PR #695** (feat/docs S21-019, agent:developer, status:ready, verdict-by:2026-06-30T16:52:15Z) — Closes #633
> - **Issue #652** (STORY-S21-020 ONBOARDING.md, agent:product-manager, status:backlog, parked Wave 5 per Issue #685) — Sprint 22 candidate
>
> **Lane discipline**: PM lane = docs/sprints/souls PRs, NOT scripts/ refactors (Sprint 13+ LOCKED, per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)
>
> **Cross-refs**:
> - Sprint 22 plan: [../sprint-22/plan.md](../sprint-22/plan.md) (orchestrator-published, 5-Phase Plan, IN PROGRESS)
> - Issue #708: https://github.com/atilproject/AtilCalculator/issues/708 (Sprint 22 PIVOT coordination, owner GO, status:in-progress)
> - Sprint 21 close-out: [../sprint-21/close.md](../sprint-21/close.md) (Faz 4.5 lane, skeleton drafted cycle ~#1552, awaits Q6 owner verdict annotation)
> - Sprint 18 close: [../sprint-18/close.md](../sprint-18/close.md) (AtilCalculator FINAL wave, 8/8 SHIPPED)
> - RETRO-014 codification: [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md) (AtilCalculator FINAL substantive retro)
> - RETRO-016: https://github.com/atilproject/AtilCalculator/issues/680 (Layer 5 initial-add race — Faz 4.2 ADR-0048 amendment codification)
>
> **Post-Issue-#708-GO action sequence (per Issue #708 §5-Phase Plan):**
> 1. ✅ Owner GO on Issue #708 — DONE cycle ~1512 (Plan v3 final)
> 2. ✅ Orchestrator publishes `docs/sprints/sprint-22/plan.md` — DONE cycle ~1519 (this pointer refresh)
> 3. ✅ `current/plan.md` pointer refresh Sprint 21 ACTIVE → Sprint 22 PIVOT — DONE cycle ~1519 (this file)
> 4. ⏳ Pre-Kickoff Gate stamp on Issue #708 — DONE cycle ~1519 (plan_freshness_check)
> 5. ⏳ [ORCH→ALL] auto-ping broadcast (peer-poke.sh loop) — IN PROGRESS cycle ~1519
> 6. ⏳ Faz 0 Pre-Flight Snapshot (PM + Developer | Owner Accountable)
> 7. ⏳ Faz 4.5 Sprint 21 close-out (`docs/sprints/sprint-21/close.md`) — orchestrator lane, awaiting Q6 owner verdict
> 8. ⏳ Faz 4.2 Architect ADR set (5 ADRs: self-hosted runner arch + visibility design + monitoring strategy + redundancy plan + re-test criteria)
> 9. ⏳ Faz 4.3 Sizing joint (PM + arch + dev + tester) — Sprint 22 stories
> 10. ⏳ Faz 1-3 sprint execution (workflow update + 3-repo migration + visibility param) per Issue #708 lane assignments
> 11. ⏳ Faz 5 Post-Migration Continuity + Runner Monitoring + Re-Test (24h+)
>
> **Open owner questions (10 remaining, Q3 closed):**
> Q1 (atilproject org plan tier — Team minimum) | Q2 (VM 192.168.1.197 7/24 availability) | Q4 (template visibility default policy) | Q5 (runner label convention) | Q6 (Sprint 21 abandonment rationale — default carry-over) | Q7 (Issue #652 rename) | Q8 (dev-studio-launcher scope inclusion) | Q9 (runner monitoring strategy) | Q10 (workload balancing) | Q11 (2. VM redundancy timeline) | Q12 (Faz 5.9 re-test criteria)

— @orchestrator, 2026-06-30T10:45+03:00 = 07:45Z, current/plan.md pointer refresh (Sprint 21 ACTIVE → Sprint 22 PIVOT, per Issue #708 owner GO + Faz 4.4 lane per file ownership matrix `docs/sprints/**` = @orchestrator)
