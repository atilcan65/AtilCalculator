# Sprint 21 — Open Questions for Owner

> **PM draft, 2026-06-29.** Each question needs owner answer before sprint kickoff (or by Day 2 of sprint at latest).

---

## Q1 — License Choice

**Question:** Which license for the template repo?
- **(a) MIT** — most permissive, encourages adoption, no copyleft
- **(b) Apache-2.0** — permissive + explicit patent grant
- **(c) Internal-only / Closed** — proprietary, restricts redistribution
- **(d) Dual-license** — MIT for open-source use, separate commercial license

**Default if no answer by Day 2:** MIT (most permissive, standard for templates).

**Affects:** S21-002 (LICENSE file), `TEMPLATE-README.md` License section, GitHub repo sidebar.

---

## Q2 — Template Repo Name

**Question:** What is the canonical repo name?
- **(a) `dev-studio-template`** (current usage in TEMPLATE-README.md)
- **(b) `multi-agent-template`**
- **(c) `multi-agent-dev-studio-template`**
- **(d) Other** (owner specifies)

**Default if no answer by Day 2:** `dev-studio-template` (current usage).

**Affects:** repo URL references in docs, ADR-0001 cross-refs, init script prompts.

---

## Q3 — Visibility Default

**Question:** Default visibility for new clones via `gh repo create --template`?
- **(a) `--public` (per ADR-0016)** — recommended, avoids Actions spending limits
- **(b) `--private` opt-in** — privacy-first, but Actions costs may surprise user
- **(c) Prompt user during init** — flexible, but extra step

**Default if no answer by Day 2:** `--public` (per ADR-0016 doctrine).

**Affects:** `TEMPLATE-README.md` Quick Start, init script default visibility flag.

---

## Q4 — AtilCalculator Relationship to Template

**Question:** Is AtilCalculator itself the template, or a clone-of-template?
- **(a) AtilCalculator IS the template** — current state. Template ships as a snapshot of AtilCalculator + init script.
- **(b) AtilCalculator is a clone of template** — refactor AtilCalculator to consume template. AtilCalculator keeps customizations on top of clone.
- **(c) AtilCalculator stays separate** — AtilCalculator is one project, template is another. Manual sync required.

**Default if no answer by Day 2:** (a) — current state, AtilCalculator is the source.

**Affects:** `.template-version` in AtilCalculator? (yes if (b), no if (a)/(c)). ADR-0001 framing.

---

## Q5 — Sprint 21 Start Date

**Question:** When does Sprint 21 kick off?
- **(a) Today (2026-06-29)** — start now, finish in 2 weeks (2026-07-13)
- **(b) Specific date** — owner specifies
- **(c) After Sprint 20 close-out** — wait for S20 PROJECT CLOSE

**Default if no answer by Day 2:** (a) — start today.

**Affects:** sprint kickoff issue creation, board sync, ceremony schedule.

---

## Q6 — Sprint 20 vs Sprint 21 Sequencing

**Question:** Sprint 20 PROJECT CLOSE happens before or in parallel with Sprint 21?
- **(a) Sequential** — Sprint 20 close-out fully complete, then Sprint 21 kicks off
- **(b) Parallel** — Sprint 20 close-out and Sprint 21 kickoff happen same week, board handles both
- **(c) Sprint 20 abandoned** — owner cancels S20 PROJECT CLOSE in favor of S21 template

**Default if no answer by Day 2:** (b) — parallel, board capacity.

**Affects:** ceremony schedule, doc updates, board state.

---

## Q7 — AtilCalculator Sprint 19 Status

**Question:** Sprint 19 was SKIPPED per owner directive. Sprint 20 was triggered but not yet opened. With Sprint 21 added, what happens to Sprint 20?
- **(a) Sprint 20 still opens** (PROJECT CLOSE for AtilCalculator) — Sprint 21 is parallel work
- **(b) Sprint 20 cancelled** — owner pivots entirely to template, AtilCalculator close-out happens post-template
- **(c) Sprint 20 + Sprint 21 = single sprint** — combined scope

**Default if no answer by Day 2:** (a) — Sprint 20 still opens as PROJECT CLOSE.

**Affects:** PR #625 owner squash gate, Sprint 20 close.md authoring.

---

## Q8 — Per-Agent PAT Issuance

**Question:** Currently all 5 agents share one PAT. For the template, is this the model?
- **(a) Single PAT per project** (current AtilCalculator model) — simpler, but no per-agent attribution
- **(b) Per-agent PAT per project** — better attribution, more setup burden
- **(c) Per-agent PAT only for orchestrator** — hybrid, dev/tester/etc use orchestrator's PAT

**Default if no answer by Day 2:** (a) — current model.

**Affects:** `TELEGRAM-SETUP.md`, init script secrets prompt.

---

## Q9 — External Walkthrough Validator

**Question:** S21-020 ONBOARDING.md requires external walkthrough. Who validates?
- **(a) PM simulates** with fresh fixture dir — fast, but PM has insider knowledge
- **(b) Owner recruits 1 external user** — slow, more realistic
- **(c) Both** — PM first pass, owner second pass

**Default if no answer by Day 2:** (a) — PM simulates (only path available without external user).

**Affects:** S21-020 acceptance, time-to-first-standup measurement.

---

## Q10 — Sprint 21 → Sprint 22 Hand-off

**Question:** Sprint 22 candidate stories (template-pull, multi-project orchestrator, marketplace). Which is priority?
- **(a) Template-pull** (auto-sync doctrine updates to existing clones) — natural follow-on to S21-024 versioning
- **(b) Multi-project orchestrator** (1 template → N projects at once) — bigger scope
- **(c) Marketplace** (public template discovery) — UX, not core
- **(d) Skip planning** — defer Sprint 22 scope to post-Sprint 21 retro

**Default if no answer by Day 2:** (d) — defer to post-Sprint 21 retro.

**Affects:** Sprint 22 backlog grooming timing.

---

## Q11 — Telemetry Across Clones

**Question:** Sprint 21 ships template. Do we want telemetry on which projects use the template (version distribution, bug rate)?
- **(a) Yes** — opt-in telemetry, owner controls
- **(b) No** — template ships without telemetry, opt-in later

**Default if no answer by Day 2:** (b) — no telemetry in Sprint 21.

**Affects:** init script hooks, doc.

---

## Q12 — Issue Template 4-cat Auto-Label

**Question:** Issue templates auto-apply 4-cat labels on submission. Which labels are auto-applied per template?
- **vision-intake.yml** → `type:vision`, `agent:product-manager`, `cc:product-manager`, `status:backlog`
- **bug.yml** → `type:bug`, `agent:developer`, `cc:developer`, `priority:P1` (default)
- **feature-request.yml** → `type:feature`, `agent:product-manager`, `cc:product-manager`, `status:backlog`
- **incident.yml** → `type:incident`, `agent:orchestrator`, `cc:orchestrator`, `priority:P0`
- **agent-stall.yml** → `agent:human`, `priority:P1`

**Default if no answer by Day 2:** Above labels (per ADR-0012 doctrine + AtilCalculator current behavior).

**Affects:** S21-013 implementation.

---

## Q13 — Init Script Failure Mode

**Question:** If `dev-studio-init.sh` fails partway (e.g., network drop), what happens?
- **(a) Atomic rollback** — script reverts to pre-init state on any failure
- **(b) Best-effort with manual cleanup** — script logs failure, user cleans up manually
- **(c) Resume from failure point** — script saves state, user reruns to resume

**Default if no answer by Day 2:** (b) — best-effort, documented in ONBOARDING.md.

**Affects:** init script complexity, ONBOARDING.md troubleshooting section.

---

## Q14 — Sample Project Content

**Question:** Template ships with sample code (`src/atilcalc/`, `tests/`). Should this be:
- **(a) AtilCalculator's actual code** — owner customizes or replaces on init
- **(b) Generic `sample-app/` placeholder** — clearer that it's a sample
- **(c) Empty dirs with README** — minimal, user adds their own code

**Default if no answer by Day 2:** (a) — AtilCalculator's code (current state).

**Affects:** init script file replacement logic, sample/README.

---

## Q15 — Sprint 21 Close-out Timing

**Question:** Sprint 21 ends when?
- **(a) 2-week sprint ending 2026-07-13** (if kickoff today)
- **(b) All 25 stories done** — sprint ends on last story merge, not fixed date
- **(c) Owner-decided** — owner calls end-of-sprint

**Default if no answer by Day 2:** (a) — fixed 2-week sprint.

**Affects:** retro timing, board state.

---

## Summary Table (Q1/Q2/Q3 ANSWERED 2026-06-29T02:18Z, Q4/Q8/Q9/Q11/Q13 ARCH-VALIDATED 02:22Z, Q5-Q7/Q10/Q12/Q14/Q15 DEFERRED to defaults)

| # | Question | Default | Owner/Arch Decision | Status |
|---|---|---|---|---|
| Q1 | License | MIT | **MIT** ✅ | OWNER-ANSWERED |
| Q2 | Repo name | dev-studio-template | **multi-agent-dev-studio-template** ✅ (PM-confirmed "generic isim") | OWNER-ANSWERED |
| Q3 | Visibility default | --public | **public** ✅ | OWNER-ANSWERED |
| Q4 | AtilCalc-template relationship | (a) AtilCalc IS template | **arch RECOMMENDS (a)** — matches default | ARCH-VALIDATED ✅ |
| Q5 | Sprint 21 start date | Today | — | DEFERRED → default applies |
| Q6 | S20/S21 sequencing | Parallel | — | DEFERRED → default applies |
| Q7 | S20 status | S20 still opens | — | DEFERRED → default applies |
| Q8 | PAT model | Single PAT per project | **arch CONCURS (a)** — matches default | ARCH-VALIDATED ✅ |
| Q9 | External walkthrough validator | PM simulates | **arch CONCURS (a)** — 9-Lens caveats noted | ARCH-VALIDATED ✅ |
| Q10 | Sprint 22 priority | Defer to retro | — | DEFERRED → default applies |
| Q11 | Telemetry | No | **arch ENDORSES (b)** — matches RETRO-013 minimalism | ARCH-VALIDATED ✅ |
| Q12 | Issue template labels | Per ADR-0012 | — | DEFERRED → default applies |
| Q13 | Init failure mode | Best-effort | **arch CONCURS (b)** — YAGNI, S21-022 smoke-test gating | ARCH-VALIDATED ✅ |
| Q14 | Sample project content | AtilCalc code | — | DEFERRED → default applies |
| Q15 | Sprint 21 close-out timing | 2-week fixed | — | DEFERRED → default applies |

---

## Arch Caveats (Q4/Q8/Q9/Q13 — captured in PR #626 cmt 4828413749)

### Q4 Caveat — Init script idempotency
- When initializing a new project, the init script (S21-003) MUST rename `AtilCalculator` references project-wide
- 9-Lens lens (e) Idempotency: init script rename MUST be idempotent (running twice = same result)
- Implication: `audit-project-refs.sh` (S21-004) gates init completion

### Q8 Caveat — Init script scope boundary
- Init script MUST NOT touch `TELEGRAM-SETUP.md` secrets — that's project-level, not template-level
- Project init is the OWNER's job, not template's
- Implication: TELEGRAM_BOT_TOKEN setup stays in `docs/TELEGRAM-SETUP.md` (owner-driven), not auto-injected by init script

### Q9 Caveat — PM validation checklist (S21-020 AC3)
- Validation MUST include: (i) init script idempotency check (re-run produces same result), (ii) 9-Lens on at least one init-script PR, (iii) d070-template-render test passes (S21-018)
- Lens (j) cross-cut: live-state verification requires actual fresh-clone executions (not synthesized)
- Implication: S21-022 smoke test script + S21-023 fresh-clone validation explicitly include idempotency + 9-Lens + d070

### Q13 Caveat — Init script error handling
- Init script MUST leave clear failure markers (which files failed, why)
- Lens (e) Idempotency: best-effort means re-running init on a half-failed project should ATTEMPT to recover / complete (not stop on first failure)
- Lens (d) Silent-skip risk: every skip MUST log a `silent_skip` event (per ADR-0045 lens d sister pattern TD-016)
- S21-022 mitigation: smoke test is the end-of-init validation gate — if smoke test fails after best-effort init, owner knows to investigate

---

---

## Ratification Cross-Refs

- **Issue #627 comment thread:** owner Q1/Q2/Q3 captured by orchestrator 02:18Z, PM confirmed Q2 interpretation 02:18:30Z
- **PR #626 body:** updated with ratification header (LICENSE: MIT, REPO NAME: multi-agent-dev-studio-template, VISIBILITY: public)
- **PR #626 verdict:** arch 🟢 APPROVE @ 02:10:02Z (9-Lens per ADR-0045)
- **PR #626 status:** Layer 5 status:ready auto-applied (ADR-0048)
- **PR #626 verdict-by:** 2026-07-01T00:00:00Z (ADR-0024 informational)

**Post-merge action sequence** (per Issue #238 doctrine + Sprint 21 launch plan):
1. Owner squash PR #626 (Sprint 21 scope ratification)
2. Owner squash PR #625 (Sprint 20 PROJECT CLOSE for AtilCalculator)
3. Orchestrator publishes `docs/sprints/sprint-21/plan.md` from PR #626 proposed-scope.md post-merge
4. PM updates `docs/sprints/current/plan.md` pointer (Sprint 17 → Sprint 21 active per §plan-file-as-snapshot)
5. Orchestrator opens 25 STORY-S21-* issues from STORY-MAP.md (joint sizing by arch+dev+tester per ADR-0021)
6. Sprint 21 wave 1 (Day 1-3) begins: S21-001 + S21-002 + S21-008 + S21-019

---

**Drafted by:** @product-manager
**Ratified by:** @atilcan65 (Q1/Q2/Q3 @ 2026-06-29T02:18Z, Issue #627)
**Arch-validated by:** @atilcan65 (Q4/Q8/Q9/Q11/Q13 @ 2026-06-29T02:22Z, PR #626 cmt 4828413749, 9-Lens applied)
**Date:** 2026-06-29
**Status:** 🟢 RATIFIED — Q1-Q3 owner-locked, Q4/Q8/Q9/Q11/Q13 arch-validated, Q5-Q7/Q10/Q12/Q14/Q15 deferred to defaults

**Sprint 21 fully unblocked.** Only owner squash gate remains. ADR-0001 (S21-016) can draft after PR #626 merge.
**Status:** AWAITING OWNER RATIFICATION (15 questions, defaults applied if no answer by Day 2)