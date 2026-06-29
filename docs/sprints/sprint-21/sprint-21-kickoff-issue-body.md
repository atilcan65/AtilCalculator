# Sprint 21 Kickoff Issue Body (Draft)

> **PM draft, 2026-06-29.** Body for `gh issue create` when rate limit resets. NOT posted yet (rate limit exhausted).

---

## Issue Title

`[Sprint 21] Multi-Agent Dev Studio Template: FINALIZE`

---

## Issue Body

```markdown
## Sprint 21 — Multi-Agent Dev Studio Template: FINALIZE

**Owner directive (2026-06-29):** "Simdi artık bu projedeki tüm ajanları ve scriptleri güzel hale getirdik, ve ben bunları template'e koymak istiyorum. Template'ile bir proje yarattığımızda direk bu projenin agentları ve tüm scriptleri ile proje başlamalı. Buna göre çok detaylı bir sprint başlat, sprint 21 olsun bu. Hiç bir detayı kaçırma. tüm agent soullardan claudeçmd ye kadar herşey olmalı."

**Goal:** Ship a `gh repo create --template` ready Multi-Agent Dev Studio Template repo where a developer can clone → init → first standup in ≤ 60 minutes, with all 5 agents, all scripts, all ADRs, all workflows, all d-tests, all issue/PR templates, and a validated onboarding guide.

---

### Sprint Plan

📄 **PM-drafted proposed scope:** [`docs/sprints/sprint-21/proposed-scope.md`](https://github.com/atilcan65/AtilCalculator/blob/feat/sprint-21-proposed-scope/docs/sprints/sprint-21/proposed-scope.md) (PR pending)
📄 **Story map:** [`docs/sprints/sprint-21/STORY-MAP.md`](https://github.com/atilcan65/AtilCalculator/blob/feat/sprint-21-proposed-scope/docs/sprints/sprint-21/STORY-MAP.md) (25 stories, 12 epics, ~63 SP)
📄 **Inventory:** [`docs/sprints/sprint-21/INVENTORY.md`](https://github.com/atilcan65/AtilCalculator/blob/feat/sprint-21-proposed-scope/docs/sprints/sprint-21/INVENTORY.md) (every artifact tracked)
📄 **Risk register:** [`docs/sprints/sprint-21/RISK-REGISTER.md`](https://github.com/atilcan65/AtilCalculator/blob/feat/sprint-21-proposed-scope/docs/sprints/sprint-21/RISK-REGISTER.md) (10 risks, 4 P1, 5 P2, 1 P0)
📄 **Open questions:** [`docs/sprints/sprint-21/OPEN-QUESTIONS.md`](https://github.com/atilcan65/AtilCalculator/blob/feat/sprint-21-proposed-scope/docs/sprints/sprint-21/OPEN-QUESTIONS.md) (15 questions for owner)
📄 **Execution checklist:** [`docs/sprints/sprint-21/CHECKLIST.md`](https://github.com/atilcan65/AtilCalculator/blob/feat/sprint-21-proposed-scope/docs/sprints/sprint-21/CHECKLIST.md) (day-by-day)

---

### Story Count

- **Total:** 25 stories across 12 epics
- **Sizing:** ~63 SP (5 points × 3 large stories + 2-3 points × 17 medium + 1 point × 5 small)
- **Capacity:** Team total ~90 SP/sprint — 63 fits with buffer

---

### Epics

| # | Epic | Stories |
|---|---|---|
| E1 | Template Repository Structure | S21-001, S21-002 |
| E2 | Parameterization & Init Script | S21-003, S21-004, S21-005 |
| E3 | Agent Soul Files | S21-006, S21-007 |
| E4 | CLAUDE.md | S21-008 |
| E5 | Scripts Library | S21-009, S21-010 |
| E6 | GitHub Workflows | S21-011, S21-012 |
| E7 | Issue & PR Templates | S21-013, S21-014 |
| E8 | ADRs | S21-015, S21-016 |
| E9 | d-test Family | S21-017, S21-018 |
| E10 | Documentation | S21-019, S21-020, S21-021 |
| E11 | Validation & Smoke Tests | S21-022, S21-023 |
| E12 | Template Versioning & Distribution | S21-024, S21-025 |

---

### Done Criteria

Sprint 21 is DONE when:
1. All 25 stories Closed with passing AC
2. Fresh-clone validation: `gh repo create test --template` + init + d-tests all green
3. `audit-project-refs.sh` exits 0 on rendered clone
4. Owner walkthrough ≤ 60 min to first standup
5. All 10 workflows fire on test PR
6. CHANGELOG.md updated
7. No P0/P1 bugs in 24h post-squash
8. ≥ 3 throwaway clones validated end-to-end

---

### Lane

- **PM:** @product-manager (story author, scope-change, retro)
- **Architect:** @architect (ADR-0001, 9-Lens on init script + audit script PRs)
- **Developer:** @developer (init script, audit script, parameterization, scripts/workflows)
- **Tester:** @tester (d-test authoring, smoke test, fresh-clone validation per ADR-0044 RED-first)
- **Orchestrator:** @orchestrator (board sync, ceremony facilitation)
- **Owner:** @atilcan65 (merge gate, scope-change decisions, license + repo name choice)

---

### Cross-refs

- Sprint 20 (PROJECT CLOSE for AtilCalculator): [sprint-20/plan.md](https://github.com/atilcan65/AtilCalculator/blob/main/docs/sprints/sprint-20/plan.md) — Sprint 20 + Sprint 21 sequencing per Q6 (OPEN-QUESTIONS.md), default parallel
- Sprint 17 final wave (AtilCalculator final doctrine): [sprint-17/plan.md](https://github.com/atilcan65/AtilCalculator/blob/main/docs/sprints/sprint-17/plan.md)
- ADR-0012 (4-cat label invariant): [docs/decisions/ADR-0012-required-label-set.md](https://github.com/atilcan65/AtilCalculator/blob/main/docs/decisions/ADR-0012-required-label-set.md)
- ADR-0033 (dual-channel auto-ping): [docs/decisions/ADR-0033-auto-ping-dual-channel.md](https://github.com/atilcan65/AtilCalculator/blob/main/docs/decisions/ADR-0033-auto-ping-dual-channel.md)
- ADR-0045 (9-Lens architect review): [docs/decisions/ADR-0045-auto-generated-file-refs-design-verification.md](https://github.com/atilcan65/AtilCalculator/blob/main/docs/decisions/ADR-0045-auto-generated-file-refs-design-verification.md)
- ADR-0044 (RED-first TDD): [docs/decisions/ADR-0044-verdict-by-scope-clarification.md](https://github.com/atilcan65/AtilCalculator/blob/main/docs/decisions/ADR-0044-verdict-by-scope-clarification.md)

---

**Status:** 🟡 DRAFT — awaiting owner ratification + rate limit reset
**Drafted by:** @product-manager
**Date:** 2026-06-29
```

---

## Issue Labels (per ADR-0012 4-cat invariant)

```bash
gh issue create \
  --title "[Sprint 21] Multi-Agent Dev Studio Template: FINALIZE" \
  --body-file <(cat docs/sprints/sprint-21/sprint-21-kickoff-issue-body.md) \
  --label "type:chore" \
  --label "status:ready" \
  --label "agent:orchestrator" \
  --label "cc:product-manager" \
  --label "cc:architect" \
  --label "cc:developer" \
  --label "cc:tester" \
  --label "cc:human" \
  --label "sprint:current"
```

---

## Auto-Ping After Issue Create

```bash
scripts/peer-poke.sh orchestrator "[PM→ORCH] Sprint 21 kickoff issue drafted (rate limit blocked, will post on reset). 25 stories, 12 epics, ~63 SP. Owner ratification pending."
scripts/peer-poke.sh human "[PM→HUMAN] Sprint 21 ready for ratification. 15 open questions in docs/sprints/sprint-21/OPEN-QUESTIONS.md. License (Q1) + repo name (Q2) + visibility (Q3) needed by Day 2."
```

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** READY (awaiting rate limit reset to post)