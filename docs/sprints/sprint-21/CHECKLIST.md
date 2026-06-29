# Sprint 21 — Execution Checklist

> **PM draft, 2026-06-29.** Day-by-day checklist for sprint execution. Owner + agents tick off as work proceeds.

---

## Pre-Kickoff (Owner Action Required)

- [ ] **Owner ratifies Sprint 21 scope** (proposed-scope.md)
- [ ] **Owner answers OPEN-QUESTIONS.md Q1-Q15** (or accept defaults)
- [ ] **Owner ratifies template repo name + license** (Q1, Q2)
- [ ] **Owner confirms Sprint 21 start date** (Q5)
- [ ] **PM creates `[Sprint 21] Multi-Agent Dev Studio Template: FINALIZE` issue** (orchestrator cc'd, status:ready)
- [ ] **Orchestrator publishes `docs/sprints/sprint-21/plan.md`** (PM drafts proposed-scope, orchestrator commits)
- [ ] **PM updates `docs/sprints/current/plan.md`** to point to Sprint 21 (per §plan-file-as-snapshot)
- [ ] **Architect reviews Sprint 21 scope, sizes stories with dev+tester** (joint sizing per ADR-0021)
- [ ] **Sprint 21 board populated** with 25 stories (Backlog column)

---

## Day 1-3 — Wave 1 Foundation (Parallel)

- [ ] **S21-001:** PM creates `is_template=true` API call task, dev executes
- [ ] **S21-002:** PM drafts LICENSE content (MIT default), dev opens PR
- [ ] **S21-008:** PM drafts `CLAUDE.md.tmpl`, dev renders + opens PR
- [ ] **S21-019:** PM polishes TEMPLATE-README.md (badges, links), opens PR
- [ ] **Daily standup posted** by orchestrator
- [ ] **PM heartbeat** to `/var/log/dev-studio/AtilCalculator/product-manager.heartbeat`

---

## Day 3-6 — Wave 2 Parameterization (depends on Wave 1)

- [ ] **S21-005:** PM identifies which files need `.tmpl`, dev creates source files
- [ ] **S21-003:** dev extends `dev-studio-init.sh` placeholder coverage
- [ ] **S21-004:** dev authors `audit-project-refs.sh`, tester writes d-test
- [ ] **S21-006:** PM cross-checks 5 soul files for placeholders, dev fixes
- [ ] **S21-007:** PM adds template-version header to souls, dev merges
- [ ] **Daily standups** (orchestrator)

---

## Day 5-8 — Wave 3 Scripts & Workflows (parallel with Wave 4)

- [ ] **S21-009:** PM inventories scripts, dev ensures all present
- [ ] **S21-010:** dev parameterizes scripts (uses `gh repo view` + env vars)
- [ ] **S21-011:** dev ensures all 10 workflows present
- [ ] **S21-012:** dev adds PROJECT_TOKEN prompt to init script
- [ ] **S21-013:** PM cross-checks 6 issue templates, dev opens PR for any gaps
- [ ] **S21-014:** PM drafts PR template, dev opens PR
- [ ] **Daily standups**

---

## Day 7-10 — Wave 4 ADRs & d-tests (parallel with Wave 3)

- [ ] **S21-015:** PM verifies `docs/decisions/INDEX.md` is current
- [ ] **S21-016:** architect drafts ADR-0001 template-architecture, opens PR
- [ ] **S21-017:** tester ensures all 40+ d-tests present, authors `run-all.sh`
- [ ] **S21-018:** tester authors `d070-template-render.sh` (RED first per ADR-0044)
- [ ] **9-Lens review** by architect on init script + audit script PRs
- [ ] **Daily standups**

---

## Day 9-12 — Wave 5 Validation & Versioning (depends on Wave 3+4)

- [ ] **S21-019:** PM polishes TEMPLATE-README.md (badges, links) — finalize
- [ ] **S21-020:** PM authors ONBOARDING.md, validates with fresh fixture dir (≤ 60 min target)
- [ ] **S21-021:** PM authors CONTRIBUTING.md, opens PR
- [ ] **S21-022:** tester authors `faz5-smoke.sh` covering 5 scenarios (RED first)
- [ ] **S21-023:** PM runs 2 fresh-clone validations (AtilCalculator copy + throwaway repo)
- [ ] **S21-024:** dev creates `.template-version`, init script wires it
- [ ] **S21-025:** PM updates CHANGELOG.md with Sprint 21 entry
- [ ] **Daily standups**

---

## Day 12-13 — Pre-Close Verification

- [ ] **All 25 stories Closed** (or explicitly deferred to Sprint 22 with owner approval)
- [ ] **All 40+ d-tests pass** on a fresh clone post-init (S21-017 verification)
- [ ] **`audit-project-refs.sh`** exits 0 on fresh clone (S21-004 verification)
- [ ] **Smoke test (`faz5-smoke.sh`)** exits 0 (S21-022 verification)
- [ ] **External walkthrough** captures time-to-first-standup (S21-020 verification)
- [ ] **2 fresh-clone validations** complete with all d-tests green (S21-023 verification)
- [ ] **PM drafts `docs/sprints/sprint-21/RETRO-021.md`** (substantive retro)
- [ ] **PM drafts `docs/sprints/sprint-21/close.md`** (sprint close-out)
- [ ] **Owner reviews close.md + retro, ratifies Sprint 21 Done**

---

## Day 14 — Sprint Close-out

- [ ] **Orchestrator publishes `close.md`** post-ratification
- [ ] **Orchestrator flips board: Sprint 21 → Done** for all stories
- [ ] **PM updates `docs/sprints/current/plan.md`** to next sprint (Sprint 22 or PROJECT CLOSE for AtilCalculator)
- [ ] **PM captures Sprint 21 retro candidates** for cross-project improvement
- [ ] **Owner celebrates** 🎉

---

## Cross-Cutting Concerns

### Test discipline (per ADR-0044)
- Every story with code/test: tester authors test FIRST (RED), dev implements (GREEN)
- d-test for new scripts: S21-018 (d070-template-render), S21-022 (faz5-smoke)
- No PR merges without tester sign-off

### Review discipline (per ADR-0045 9-Lens)
- Init script + audit script + any ADR: architect 9-Lens review
- Soul file changes: architect + PM review
- Workflow changes: architect + owner review (workflow is owner territory per CLAUDE.md file ownership)

### Merge discipline (per file ownership matrix)
- `docs/sprints/**` (sprint-21 plan, retro, close): orchestrator publishes post-ratification
- `docs/decisions/**` (ADR-0001): architect drafts, owner merges
- `scripts/**` (init script, audit, d-tests): developer + tester lane
- `.github/workflows/**`: owner merges (owner-only territory)
- `.claude/agents/**`: PM lane, owner merges

### Heartbeat discipline
- Every agent heartbeat on every action: `/var/log/dev-studio/AtilCalculator/<role>.heartbeat`
- PM heartbeat appends at every pickup cycle

### Label discipline (per ADR-0012 4-cat invariant)
- Every issue + PR has 4 labels: type, status, agent, cc
- Every handoff is atomic (ADR-0015: add new, remove old, in that order)
- `cc:human` = owner merge gate

---

## Sprint 21 Done Criteria (Restated)

Sprint 21 is **DONE** when:
1. All 25 stories Closed with passing AC
2. Fresh-clone validation: `gh repo create test --template` + init + d-tests all green
3. `audit-project-refs.sh` exits 0 on rendered clone
4. Owner walkthrough ≤ 60 min to first standup
5. All 10 workflows fire on test PR
6. CHANGELOG.md updated with Sprint 21 entry
7. No P0/P1 bugs filed in 24h post-squash
8. ≥ 3 throwaway clones validated end-to-end

---

## Post-Sprint 21 (Sprint 22+ Candidates)

- **Sprint 22 P1 #1:** Template-pull mechanism (auto-sync doctrine to existing clones) — depends on S21-024 versioning
- **Sprint 22 P1 #2:** Multi-project orchestrator (1 template → N projects at once)
- **Sprint 22 P2:** Marketplace listing (public discoverability)
- **Sprint 22 P3:** GUI installer (alternative to CLI init)

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** DRAFT (becomes active on owner ratification)