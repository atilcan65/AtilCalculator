# Sprint 21 — Multi-Agent Dev Studio Template

> **Orchestrator publish.** Meta-artifact (sprint goal + capacity + lanes + acceptance).
> **PM source:** [`./proposed-scope.md`](./proposed-scope.md) (PR #626 squash @ a5e09422, 2026-06-29)
> **Story source:** [`./STORY-MAP.md`](./STORY-MAP.md) (12 epics, 25 stories, ~63 SP)
> **Owner directive (2026-06-29):** *"Simdi artık bu projedeki tüm ajanları ve scriptleri güzel hale getirdik, ve ben bunları template'e koymak istiyorum... Hiç bir detayı kaçırma. tüm agent soullardan claudeçmd ye kadar herşey olmalı."*

---

## 1. Sprint Goal

Ship a `gh repo create --template` ready **Multi-Agent Dev Studio Template** repo where a developer can clone → init → first standup in **≤ 60 minutes**, with all 5 agents, all scripts, all ADRs, all workflows, all d-tests, all issue/PR templates, and a validated onboarding guide.

**Not in scope:** template distribution marketplace, auto-update from upstream (Sprint 22+), multi-project orchestration (Sprint 23+).

**Owner ratification inputs (Q1-Q3 answered, Q4-Q15 deferred):**
- Q1 LICENSE = **MIT** ✅
- Q2 REPO NAME = **generic isim** (PM proposed `multi-agent-dev-studio-template`, confirm)
- Q3 VISIBILITY = **public** ✅
- Q4-Q15 = deferrable to Sprint 21 planning ceremony

**Architect decisions (PR #629 ADR-0001, owner squash gate):**
- §1 single-repo template (Q4 (a) ratified, monorepo + separate-repo rejected — YAGNI)
- §2 `{{...}}` placeholder parameterization (rejected env var / build-time codegen)
- §3 per-project init prompt for secrets (R10 P0 secret leakage mitigation)
- §4 `gh repo create --template` distribution (rejected copier/cookiecutter — Sprint 22+)
- §5 cross-refs ADR-0012/0014/0045/0047

---

## 2. Capacity & Sizing

| Metric | Value |
|---|---|
| Stories | 25 |
| Epics | 12 (E1-E12) |
| Story points | ~63 SP |
| Team capacity | ~90 SP/sprint |
| Buffer | ~30% (27 SP slack) |
| Sprint length | 2 weeks (2026-06-29 → 2026-07-13) |

**Joint sizing discipline:** ADR-0021 — arch + dev + tester size each story before dev claims. Orchestrator verifies sizing stamp before claim-next-ready fires.

---

## 3. State at Sprint Kickoff (orchestrator verification, 2026-06-29)

| Domain | AtilCalculator baseline | Sprint 21 target |
|---|---|---|
| Soul files | 5/5 (orch, PM, arch, dev, tester) | 5/5 parameterized + `.tmpl` |
| Scripts | 40+ | All scripts use placeholders, init renders |
| ADRs | 60+ (ADR-0001..ADR-0060) | All in template (current set canonical) |
| Workflows | 10 | All 10 wired + parameterized |
| d-tests | 40+ | All 40+ in template + d070 new |
| Issue templates | 6 | All 6 in template |
| PR template | (none) | **CREATE** `.github/PULL_REQUEST_TEMPLATE.md` |
| Templates | TEMPLATE-README, README, CHANGELOG, pyproject, src/, tests/, docs/, scripts/, systemd/ | All in template |

**Gap (~30%):** parameterization + audit + PR template + smoke tests + onboarding + license + version pin.

---

## 4. Personas (per proposed-scope §3)

- **P1 — Solo Developer / Founder (primary)**: `gh repo create myproject --template` → first standup in ≤60min
- **P2 — Tech Lead at Startup (secondary)**: 2-3 repos in parallel, single-source-of-truth template
- **P3 — Open-Source Maintainer (tertiary)**: discoverable, well-documented, low contribution friction

---

## 5. Story Map (epics → stories, 12 epics, 25 stories)

| # | Epic | Stories | Lane |
|---|---|---|---|
| E1 | Template Repository Structure | S21-001, S21-002 | owner/dev |
| E2 | Parameterization & Init Script | S21-003, S21-004, S21-005 | dev |
| E3 | Agent Soul Files | S21-006, S21-007 | arch |
| E4 | CLAUDE.md | S21-008 | arch/PM |
| E5 | Scripts Library | S21-009, S21-010 | dev |
| E6 | GitHub Workflows | S21-011, S21-012 | dev/owner (secrets) |
| E7 | Issue & PR Templates | S21-013, S21-014 | PM |
| E8 | ADRs | S21-015, S21-016 (ADR-0001, PR #629) | arch |
| E9 | d-test Family | S21-017, S21-018 | test |
| E10 | Documentation | S21-019, S21-020, S21-021 | PM |
| E11 | Validation & Smoke Tests | S21-022, S21-023 | test |
| E12 | Template Versioning & Distribution | S21-024, S21-025 | dev/test |

**Issue numbering:** #630 = S21-001, #654 = S21-025 (all created 2026-06-29 by PM)

---

## 6. Wave Plan (per PR #628 body)

### Wave 1 (Day 1-3): Foundation
- **S21-001** Template Flag + "Use this template" Button
- **S21-002** LICENSE File (MIT)
- **S21-008** CLAUDE.md at Project Root
- **S21-019** TEMPLATE-README.md Polish

### Wave 2 (Day 4-6): Parameterization
- S21-003 (init script), S21-004 (refs audit), S21-005 (.tmpl files)
- S21-006, S21-007 (soul files parameterized + version pin)

### Wave 3 (Day 7-9): Plumbing
- S21-009, S21-010 (scripts), S21-011, S21-012 (workflows), S21-013, S21-014 (issue/PR templates)

### Wave 4 (Day 10-12): Validation
- S21-015, S21-016 (ADRs), S21-017, S21-018 (d-tests), S21-022, S21-023 (smoke + fresh-clone)

### Wave 5 (Day 13-14): Polish & Close
- S21-020, S21-021 (ONBOARDING + CONTRIBUTING), S21-024, S21-025 (version + changelog)

---

## 7. Lane Assignments & Dispatch

- **PM (@product-manager)**: story creation ✅ done, joint sizing on Wave 1, Wave dispatch
- **Architect**: ADR-0001 (PR #629), S21-008 + S21-016 commitment, 9-Lens on Sprint 21 follow-ups
- **Developer**: impl lane picks up Wave 1 stories (S21-001/002/008/019) post-sizing
- **Tester**: d-test coordination per ADR-0044 RED-first, owner of E9 + E11 + S21-025 (CHANGELOG)
- **Orchestrator**: plan.md (this file), Sprint 21 standup notes, RETRO-015 capture, Wave dispatch verification
- **Owner**: 3 squash gates in flight (#628 pointer, #629 ADR-0001, plan.md publish), per-Wave ratify

---

## 8. Top Risks (per arch 9-Lens on PR #626)

| ID | Severity | Risk | Mitigation |
|---|---|---|---|
| R10 | P0 | Secret leakage | secret-canary + pre-commit + init script `ghp_*` scan |
| R1 | P1 | Param creep | scope-control on `gh repo create --template` |
| R8 | P2 | Doctrine conflict | all template ADRs reconcile with current dev-studio doctrine |
| R2 | P1 | Doctrine drift | version pin + agent-doctor reports |
| R5 | P2 | Fresh-clone failure | S21-023 ≥2 clone validation |

Full register: [`./RISK-REGISTER.md`](./RISK-REGISTER.md) (10 risks total)

---

## 9. Acceptance Criteria (Sprint 21 success)

- ✅ AC1 — `gh repo create myproject --template <owner>/multi-agent-dev-studio-template --clone` succeeds
- ✅ AC2 — Init script renders all placeholders idempotently (running twice = same result, Q4 caveat)
- ✅ AC3 — `agent-watch.sh orchestrator` fires within 5min of first standup
- ✅ AC4 — All 5 soul files load + REPRIME protocol works on fresh clone
- ✅ AC5 — All 40+ d-tests pass on fresh clone (S21-017)
- ✅ AC6 — External fresh-clone validation: ≥2 distinct clones succeed (S21-023)
- ✅ AC7 — Owner onboarding walkthrough: ≤60min clone-to-first-standup (validated by external user)

---

## 10. Sequencing Gate (current state, 2026-06-29T02:56Z)

```
PR #626 squash ✅ DONE (a5e09422, 02:39:23Z, scope ratified)
PR #628 squash ⏳ owner (pointer refresh, current/plan.md → Sprint 21)
PR #629 squash ⏳ owner (ADR-0001, doc/decisions/)
plan.md publish ⏳ THIS PR (orchestrator lane, doc/sprints/sprint-21/plan.md)
─────────────────────────────────────────────────────────
Wave 1 joint sizing ⏳ PM + arch + dev + tester (post plan.md)
Wave 1 dispatch ⏳ PM assigns to dev lane
Sprint 21 implementation ⏳ sequential wave-by-wave
```

---

## 11. Cross-references

- **Issue #627** (CLOSED) — Sprint 21 FINALIZE coordination, ceremonial gate
- **PR #625** (MERGED @ e4bfa3e) — Sprint 18 PROJECT CLOSE (predecessor)
- **PR #626** (MERGED @ a5e09422) — Sprint 21 scope ratified
- **PR #628** (OPEN) — current/plan.md pointer refresh, owner squash gate
- **PR #629** (OPEN) — ADR-0001 template architecture, owner squash gate
- **Issues #630-#654** — Sprint 21 stories (S21-001..S21-025), PM-authored
- **Docs**: [`./CHECKLIST.md`](./CHECKLIST.md), [`./INVENTORY.md`](./INVENTORY.md), [`./RISK-REGISTER.md`](./RISK-REGISTER.md), [`./OPEN-QUESTIONS.md`](./OPEN-QUESTIONS.md)
- **ADRs**: ADR-0001 (template arch), ADR-0012 (4-cat invariant), ADR-0014 (PROJECT_TOKEN), ADR-0021 (joint sizing), ADR-0024 (verdict-by), ADR-0044 (RED-first TDD), ADR-0045 (9-Lens), ADR-0059 (curator flow)

---

## 12. Doctrine Notes

- **File ownership matrix**: docs/sprints/sprint-NN/plan.md = @orchestrator (this file ✅)
- **PM lane LOCKED** (Sprint 13+): PM cc'd on docs/sprints/souls PRs, NOT scripts/ refactors
- **§plan-file-as-snapshot sister-pattern**: PM refreshes current/plan.md pointer (PR #628)
- **§Pre-Kickoff Gate**: ✅ all 5 pre-flight checks passed before Sprint 21 ceremony dispatch
- **RETRO-014 §6**: Sprint 19 SKIPPED per owner directive; Sprint 20 PROJECT CLOSED = Sprint 18 squash (option b)
- **RETRO-015 candidate**: dual-edit pattern (PR #628 + #629 both touched current/plan.md with identical content)

---

— @orchestrator, 2026-06-29T02:57:00Z (Sprint 21 plan.md, plan_freshness_check: 2026-06-29T02:57:00Z + ISSUE-627-closed + PR-626-merged + PR-628-pending + PR-629-pending)