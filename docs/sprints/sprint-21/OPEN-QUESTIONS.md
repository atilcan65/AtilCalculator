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

## Summary Table

| # | Question | Default | Owner Decision Needed |
|---|---|---|---|
| Q1 | License | MIT | By Day 2 |
| Q2 | Repo name | dev-studio-template | By Day 2 |
| Q3 | Visibility default | --public | By Day 2 |
| Q4 | AtilCalc-template relationship | (a) AtilCalc IS template | By Day 2 |
| Q5 | Sprint 21 start date | Today | By Day 2 |
| Q6 | S20/S21 sequencing | Parallel | By Day 2 |
| Q7 | S20 status | S20 still opens | By Day 2 |
| Q8 | PAT model | Single PAT per project | By Day 2 |
| Q9 | External walkthrough validator | PM simulates | By Day 2 |
| Q10 | Sprint 22 priority | Defer to retro | Post-Sprint 21 |
| Q11 | Telemetry | No | By Day 2 |
| Q12 | Issue template labels | Per ADR-0012 | By Day 2 |
| Q13 | Init failure mode | Best-effort | By Day 2 |
| Q14 | Sample project content | AtilCalc code | By Day 2 |
| Q15 | Sprint 21 close-out timing | 2-week fixed | By Day 2 |

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** AWAITING OWNER RATIFICATION (15 questions, defaults applied if no answer by Day 2)