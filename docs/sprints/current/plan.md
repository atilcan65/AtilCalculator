# Current Sprint — Pointer

> **Active sprint:** **Sprint 21 — Multi-Agent Dev Studio Template: FINALIZE** (template bootstrapper, new project — sibling to AtilCalculator)
>
> 📄 **PM-drafted scope (ratified):** [../sprint-21/proposed-scope.md](../sprint-21/proposed-scope.md) (PR #626 squash @ a5e0942, 8 PM-drafted docs, 25 stories, 12 epics, ~63 SP)
> 📄 **Orchestrator-published plan (PENDING):** `docs/sprints/sprint-21/plan.md` (to be authored by orchestrator from proposed-scope.md post-merge — file does not yet exist, broken link intentionally removed pending orchestrator publish)
> 📄 **Story map:** [../sprint-21/STORY-MAP.md](../sprint-21/STORY-MAP.md) (25 stories × INVEST + Gherkin AC + size hint + deps)
> 📄 **Inventory:** [../sprint-21/INVENTORY.md](../sprint-21/INVENTORY.md) (every artifact in template — 5 souls + CLAUDE.md + 25+ scripts + 40+ d-tests + 10 workflows + 6 issue templates + 60+ ADRs + project root + docs)
> 📄 **Risk register:** [../sprint-21/RISK-REGISTER.md](../sprint-21/RISK-REGISTER.md) (10 risks, 4 P1, 5 P2, 1 P0)
> 📄 **Open questions:** [../sprint-21/OPEN-QUESTIONS.md](../sprint-21/OPEN-QUESTIONS.md) (Q1-Q3 OWNER-ANSWERED, Q4/Q8/Q9/Q11/Q13 ARCH-VALIDATED, Q5-Q7/Q10/Q12/Q14/Q15 deferred to defaults)
> 📄 **Execution checklist:** [../sprint-21/CHECKLIST.md](../sprint-21/CHECKLIST.md) (Day 1-14 day-by-day)
>
> 📄 **AtilCalculator predecessor (PROJECT CLOSED):** [../sprint-18/close.md](../sprint-18/close.md) (PR #625 squash @ e4bfa3e, Sprint 18 FINAL 8/8 SHIPPED + Sprint 20 PROJECT CLOSE folded)
> 📄 **RETRO-014 (FINAL substantive retro for AtilCalculator):** [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md) (Sprint 18 final wave codifications)
> 📄 **Sprint 19 (SKIPPED per owner directive):** [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md) §6
> 📄 **Sprint 20 (PROJECT CLOSE folded into Sprint 18 squash):** [../sprint-18/close.md](../sprint-18/close.md) (PM RECOMMENDATION (b) ACHIEVED ✅)
>
> **Mode:** 🚀 **SPRINT 21 LAUNCH SEQUENCED** — Sprint 21 scope ratified (PR #626 squash @ a5e0942). Wave 1 (Day 1-3) starts post-orchestrator plan.md publish + 25 STORY-S21-* issue creation.
> **Status:** 🟢 **Sprint 18 PROJECT CLOSED** (PR #625 squash @ e4bfa3e, all 8 stories SHIPPED). 🟢 **Sprint 20 PROJECT CLOSED** (PM RECOMMENDATION (b) ACHIEVED — folded into Sprint 18 squash). 🟢 **Sprint 21 SCOPE RATIFIED** (PR #626 squash @ a5e0942, owner ratification captured Q1-Q3 + arch input on Q4/Q8/Q9/Q11/Q13).
> **Origin directive (carry from Sprint 18)**: *"Simdi artık bu projedeki tüm ajanları ve scriptleri güzel hale getirdik, ve ben bunları template'e koymak istiyorum. Template'ile bir proje yarattığımızda direk bu projenin agentları ve tüm scriptleri ile proje başlamalı. Buna göre çok detaylı bir sprint başlat, sprint 21 olsun bu. Hiç bir detayı kaçırma. tüm agent soullardan claudeçmd ye kadar herşey olmalı."* (owner @ 2026-06-29). **Template bootstrapper** — 5 agents + CLAUDE.md + scripts + ADRs + workflows + d-tests + docs in one gh repo create --template ready package.
>
> **Lane discipline**: PM lane = docs/sprints/souls PRs, NOT scripts/ refactors (Sprint 13+ LOCKED, per [ORCH→PM-CLARIFY-ACK] @ 22:42:21 +03)
>
> **Cross-refs**:
> - Sprint 21 plan: [../sprint-21/proposed-scope.md](../sprint-21/proposed-scope.md) (PM-drafted scope, ratified)
> - Sprint 21 plan (orchestrator-published, PENDING): `docs/sprints/sprint-21/plan.md` (file does not yet exist — broken link intentionally removed pending orchestrator publish)
> - Sprint 18 close: [../sprint-18/close.md](../sprint-18/close.md) (AtilCalculator FINAL wave, 8/8 SHIPPED)
> - RETRO-014 codification: [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md) (AtilCalculator FINAL substantive retro, includes Sprint 20 PROJECT CLOSE + doctrine gaps)
> - RETRO-013 codification: [../sprint-18/RETRO-013.md](../sprint-18/RETRO-013.md) (Sprint 18 P0+P1 cluster close-out)
> - PR #626 squash: https://github.com/atilcan65/AtilCalculator/pull/626 (Sprint 21 PM-lane scope ratification, owner merge @ a5e0942)
> - PR #625 squash: https://github.com/atilcan65/AtilCalculator/pull/625 (Sprint 18 PM-lane close-out, owner merge @ e4bfa3e)
> - Issue #627: https://github.com/atilcan65/AtilCalculator/issues/627 (Sprint 21 kickoff tracker, agent:orchestrator)
>
> **Post-PR-#626-squash action sequence (Issue #238 doctrine):**
> 1. ✅ Owner squash PR #625 — DONE @ 01:38:56Z (Sprint 18 PROJECT CLOSE)
> 2. ✅ Owner squash PR #626 — DONE @ 02:39:23Z (Sprint 21 scope ratification)
> 3. ⏳ Orchestrator publishes `docs/sprints/sprint-21/plan.md` from PR #626 proposed-scope.md (orchestrator lane, file ownership matrix)
> 4. ⏳ Orchestrator opens 25 STORY-S21-* issues from STORY-MAP.md (joint sizing per ADR-0021 by arch+dev+tester)
> 5. ⏳ Sprint 21 wave 1 (Day 1-3) begins: S21-001 + S21-002 + S21-008 + S21-019

— @product-manager, 2026-06-29T05:41+03:00 = 02:41Z, current/plan.md pointer refresh (Sprint 18/20 CLOSED + Sprint 21 SCOPE RATIFIED → Sprint 21 ACTIVE, per §plan-file-as-snapshot sister-pattern)