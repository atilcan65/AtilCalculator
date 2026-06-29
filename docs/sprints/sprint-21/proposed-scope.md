# Sprint 21 — Multi-Agent Dev Studio Template: FINALIZE

> **PM draft.** Orchestrator publishes `plan.md` post-ratification.
> **Owner directive (2026-06-29):** "tüm agent soullardan claudeçmd ye kadar herşey olmalı" — every artifact from soul files to CLAUDE.md must be in the template.

---

## 1. Sprint Goal

**One-sentence goal:** Ship a `gh repo create --template` ready **Multi-Agent Dev Studio Template** repo where a developer can clone → init → first standup in **≤ 60 minutes**, with all 5 agents, all scripts, all ADRs, all workflows, all d-tests, all issue/PR templates, and a validated onboarding guide.

**Not this sprint's goal:** Template distribution marketplace, auto-update from upstream (Sprint 22+), multi-project orchestration (Sprint 23+).

---

## 2. State at sprint kickoff (PM inventory, 2026-06-29)

| Domain | Existing in AtilCalculator | Sprint 21 target |
|---|---|---|
| Soul files | 5/5 (orch, PM, arch, dev, tester) | 5/5 parameterized + `.tmpl` |
| Scripts | 40+ (`notify.sh`, `peer-poke.sh`, `agent-watch.sh`, `claim-next-ready.sh`, `dev-studio-init.sh`, `bootstrap-labels.sh`, `bootstrap-project-board.sh`, `ping.sh`, `codex-runner.sh`, `agent-doctor.sh`, d-tests, etc.) | All scripts use placeholders, init script renders them |
| ADRs | 60+ (ADR-0001..ADR-0060) | All in template (current set is the canonical doctrine) |
| Workflows | 10 (`label-check.yml`, `status-label-to-board.yml`, `ci.yml`, `lint-and-test.yml`, `post-squash.yml`, `secret-canary.yml`, `cross-repo-close.yml`, `label-cleanup.yml`, `ai-pr-review.yml`, `deploy.yml`) | All 10 wired + parameterized |
| d-tests | 40+ (d006..d046, d048..d058 etc.) | All 40+ in template, all passing on fresh clone |
| Issue templates | 6 (vision-intake, bug, feature-request, incident, agent-stall, config) | All 6 in template |
| PR template | (none found in current scan) | **CREATE** `.github/PULL_REQUEST_TEMPLATE.md` |
| Project root | `TEMPLATE-README.md`, `README.md`, `CHANGELOG.md`, `pyproject.toml`, `src/`, `tests/`, `docs/`, `scripts/`, `systemd/` | All in template |
| Doctrine docs | `docs/CLAUDE.md`, `docs/CONTEXT-HYGIENE.md`, `docs/TELEGRAM-SETUP.md`, `docs/peer-poke-spec.md`, `docs/tech-debt.md`, `docs/decisions/INDEX.md` | All in template |

**Gap analysis:** ~70% already in place. Sprint 21 closes the remaining 30%:
- Parameterization (`{{REPO_ROOT}}`, `{{GITHUB_OWNER}}`, `{{GITHUB_REPO}}`, `{{HUMAN_OWNER_NAME}}`, `{{PROJECT_NAME}}`)
- Audit which files reference project name → render via `dev-studio-init.sh`
- Add missing PR template
- External-clone smoke test (≥ 2 fresh clones succeed)
- Owner onboarding guide (validated by external walkthrough)
- d-test suite smoke test on fresh clone
- `dev-studio-init.sh` harden: idempotency, retry-on-rate-limit, error reporting
- License decision (MIT/Apache/internal)
- Public README polish
- CONTRIBUTING.md for template improvements
- Template-version pin (`.template-version` file)

---

## 3. Personas

### P1 — Solo Developer / Founder (primary)
- **Profile:** 1-3 person team building a SaaS or tool, no dedicated ops
- **Context:** Wants multi-agent dev studio but can't afford 6-week bootstrap
- **Pain points:** Multi-agent setup is brittle; secrets config is confusing; soul files have hidden dependencies; doctrine drift between local notes and shared repo
- **Success looks like:** `gh repo create myproject --template atilcan65/dev-studio-template`, run init script, see 5 agents wake on first standup

### P2 — Tech Lead at a Startup (secondary)
- **Profile:** 5-15 engineers, wants consistent multi-agent doctrine across multiple repos
- **Context:** Manages 2-3 repos in parallel, each needs same agent/script/ADR stack
- **Pain points:** Drift between repos, manual sync burden, "which repo has the latest ADR-0033 fix?"
- **Success looks like:** Single source-of-truth template, per-repo secrets isolation, optional pull-script to sync doctrine updates

### P3 — Open-Source Maintainer (tertiary)
- **Profile:** Maintains a public template repo, gets PRs from contributors
- **Context:** Wants template to be discoverable, easy to contribute to, well-documented
- **Pain points:** Doc rot, contribution friction, license ambiguity
- **Success looks like:** Public README, CONTRIBUTING.md, clear license, d-test suite catches regressions on every PR

---

## 4. Story Map (epics → stories)

### Epic E1 — Template Repository Structure
- **STORY-S21-001:** As P1, I want a `gh repo create --template` ready repo, so that template flag is enabled and "Use this template" button shows on GitHub
  - **AC1** — `gh api -X PATCH repos/<owner>/dev-studio-template -f is_template=true` succeeds (template flag set)
  - **AC2** — GitHub UI shows green "Use this template" button on repo homepage
  - **AC3** — `gh repo create test-clone --template <owner>/dev-studio-template --clone` succeeds
- **STORY-S21-002:** As P1, I want a `LICENSE` file with explicit license (MIT/Apache/internal), so that license is unambiguous
  - **AC1** — `LICENSE` file at repo root, content matches chosen license (MIT per Q1 ratification)
  - **AC2** — GitHub repo sidebar shows license
  - **AC3** — `TEMPLATE-README.md` License section references LICENSE file

### Epic E2 — Parameterization & Init Script
- **STORY-S21-003:** As P1, I want a `dev-studio-init.sh` that resolves all placeholders, so that project name flows through every file
  - **AC1** — `bash scripts/dev-studio-init.sh` exits 0 on a fresh clone with prompts for `GITHUB_OWNER`, `GITHUB_REPO`, `HUMAN_OWNER_NAME`, `PROJECT_NAME`
  - **AC2** — All `{{...}}` placeholders replaced (init script greps for `{{` post-render, fails if any remain)
  - **AC3** — Idempotent: running twice does not corrupt state (placeholder round-trip safe)
- **STORY-S21-004:** As P1, I want a parameterization audit, so that no hardcoded "AtilCalculator" / "atilcan65" leaks into the clone
  - **AC1** — Audit script `scripts/audit-project-refs.sh` greps for forbidden hardcoded refs (`AtilCalculator`, `atilcan65`, `atilcalc-architect-td012`)
  - **AC2** — Audit passes on `dev-studio-init.sh`-rendered clone
  - **AC3** — Audit fails on pre-init clone (proves it caught something)
- **STORY-S21-005:** As P1, I want `.tmpl` source files alongside rendered outputs, so that template changes are diff-able
  - **AC1** — `README.md.tmpl`, `CLAUDE.md.tmpl`, `orchestrator.md.tmpl`, etc. exist as source
  - **AC2** — `dev-studio-init.sh` reads `.tmpl` and writes rendered output
  - **AC3** — Diff between two consecutive renders = 0 (deterministic)

### Epic E3 — Agent Soul Files (5)
- **STORY-S21-006:** As P1, I want all 5 soul files in the template (orchestrator, PM, architect, developer, tester), so that agents wake with correct doctrine
  - **AC1** — `.claude/agents/orchestrator.md`, `product-manager.md`, `architect.md`, `developer.md`, `tester.md` all present
  - **AC2** — All 5 reference `CLAUDE.md` as project doctrine source
  - **AC3** — All 5 use placeholder `{{HUMAN_OWNER_NAME}}` for owner mention
- **STORY-S21-007:** As P1, I want soul files to be versioned against template-version, so that agents can detect drift
  - **AC1** — `.claude/agents/<role>.md` header includes `template-version: {{TEMPLATE_VERSION}}` line
  - **AC2** — Init script writes the actual version (not placeholder)
  - **AC3** — `agent-doctor.sh <role>` reports soul-file template-version vs current repo `.template-version`

### Epic E4 — CLAUDE.md (Project Root Doctrine)
- **STORY-S21-008:** As P1, I want `CLAUDE.md` at repo root, so that doctrine is auto-loaded by Claude Code
  - **AC1** — `CLAUDE.md` exists at repo root, ≥ 200 lines, covers all sections in current AtilCalculator `CLAUDE.md` (Product, Team, Process, Tech stack, DoD, Communication, Auto-Ping Hard-Rule, Autonomy Loop, Required Label Set, Handoff Discipline, Things agents must NEVER do, File ownership matrix)
  - **AC2** — `CLAUDE.md` references `docs/decisions/` for ADRs
  - **AC3** — `CLAUDE.md` is parameterized (`{{HUMAN_OWNER_NAME}}`, `{{GITHUB_OWNER}}/{{GITHUB_REPO}}`)

### Epic E5 — Scripts Library
- **STORY-S21-009:** As P1, I want the full script library in the template, so that all operational tools work
  - **AC1** — `scripts/` contains: `notify.sh`, `peer-poke.sh`, `agent-watch.sh`, `agent-state.sh`, `claim-next-ready.sh`, `ping.sh`, `codex-runner.sh`, `dev-studio-init.sh`, `dev-studio-start.sh`, `bootstrap-labels.sh`, `bootstrap-project-board.sh`, `health-check.sh`, `agent-doctor.sh`, `agent-journal.sh`, `reprime-agent.sh`, `lint-notify-invocations.sh`, `post-restart-label-guard.sh`, `orchestrator-gap-scan.sh`, `proactive-board-scan.sh`, `strip-cascade-labels.sh`, `cross-repo-close.sh`, `cross-repo-scan.sh`, `event-log.sh`, `atomic-write.sh`, `wip-idle-detect.sh`
  - **AC2** — All scripts have `set -euo pipefail` and a top-of-file usage comment
  - **AC3** — `scripts/README.md` index lists all scripts with one-line purpose
- **STORY-S21-010:** As P1, I want all scripts parameterized for project, so that hardcoded paths break on clone
  - **AC1** — `audit-project-refs.sh` (from S21-004) catches hardcoded refs in scripts
  - **AC2** — Scripts use `$(gh repo view --json name -q .name)` or env vars instead of hardcoded names
  - **AC3** — Init script env file `~/.dev-studio-env` template is generated per-project

### Epic E6 — GitHub Workflows
- **STORY-S21-011:** As P1, I want all 10 workflows in the template, so that CI/label-check/board-sync fire on first PR
  - **AC1** — `.github/workflows/` contains: `ci.yml`, `label-check.yml`, `label-cleanup.yml`, `status-label-to-board.yml`, `lint-and-test.yml`, `post-squash.yml`, `secret-canary.yml`, `cross-repo-close.yml`, `ai-pr-review.yml`, `deploy.yml`
  - **AC2** — All workflows pass `gh workflow list` after init
  - **AC3** — `label-check.yml` references 4-cat invariant (ADR-0012) in workflow description
- **STORY-S21-012:** As P1, I want `PROJECT_TOKEN` secret handling, so that board-sync workflow has the right scope
  - **AC1** — Init script prompts for `PROJECT_TOKEN` and writes via `gh secret set PROJECT_TOKEN`
  - **AC2** — `docs/TELEGRAM-SETUP.md` covers PROJECT_TOKEN alongside TELEGRAM_BOT_TOKEN
  - **AC3** — Init script validates `PROJECT_TOKEN` has `project` scope (warns if missing, suggests `gh auth refresh`)

### Epic E7 — Issue & PR Templates
- **STORY-S21-013:** As P1, I want all 6 issue templates in `.github/ISSUE_TEMPLATE/`, so that contributors see the right form
  - **AC1** — `vision-intake.yml`, `bug.yml`, `feature-request.yml`, `incident.yml`, `agent-stall.yml`, `config.yml` all present
  - **AC2** — All templates auto-apply the 4-cat label invariant on submission (per ADR-0012)
  - **AC3** — `agent-stall.yml` references `agent-doctor.sh` in body
- **STORY-S21-014:** As P1, I want a PR template, so that PRs follow the doctrine convention
  - **AC1** — `.github/PULL_REQUEST_TEMPLATE.md` exists with sections: Summary, Doctrine impact, ADR cross-ref, Test plan, Owner checklist
  - **AC2** — PR template is referenced from CONTRIBUTING.md
  - **AC3** — Section headers trigger CI labeler (auto-apply `type:docs` if "docs only" checked, etc.)

### Epic E8 — ADRs (Architecture Decision Records)
- **STORY-S21-015:** As P1, I want the full ADR library committed, so that doctrine is discoverable
  - **AC1** — `docs/decisions/INDEX.md` lists all 60+ ADRs with one-line summary each
  - **AC2** — All ADRs follow the template (Context, Decision, Consequences, Alternatives)
  - **AC3** — Init script does NOT modify ADRs (they are doctrine, project-agnostic)
- **STORY-S21-016:** As P1, I want a new ADR-0001 specific to template architecture, so that template-vs-clone distinction is documented
  - **AC1** — `docs/decisions/ADR-0001-template-architecture.md` covers: single-repo vs monorepo, parameterization strategy (placeholders vs env vs build), secrets strategy (per-project init prompt), distribution strategy (gh template vs copier vs cookiecutter)
  - **AC2** — ADR is referenced from `TEMPLATE-README.md` and `CLAUDE.md`
  - **AC3** — ADR cross-references: ADR-0016 (public-by-default), ADR-0014 (PROJECT_TOKEN), ADR-0012 (label invariant)

### Epic E9 — d-test Family
- **STORY-S21-017:** As P1, I want all 40+ d-tests in `scripts/tests/`, so that agent runtime is verifiable on fresh clone
  - **AC1** — `scripts/tests/` contains all d-tests: d006, d007, d011-d018, d022-d025, d027-d032, d034-d041, d043, d046a/b/c
  - **AC2** — All d-tests exit 0 on a fresh clone post-init
  - **AC3** — `scripts/tests/run-all.sh` runs all d-tests in dependency order, exits 0 if all pass
- **STORY-S21-018:** As P1, I want a d-test for the template itself, so that template changes don't break clones
  - **AC1** — `scripts/tests/d070-template-render.sh` validates `dev-studio-init.sh` on a fixture dir
  - **AC2** — Test covers: happy path, idempotency, missing placeholder, broken `.tmpl` syntax
  - **AC3** — Test runs in < 30 seconds (no network calls)

### Epic E10 — Documentation
- **STORY-S21-019:** As P1, I want `TEMPLATE-README.md`, so that template users see the value prop first
  - **AC1** — `TEMPLATE-README.md` already exists, polish: add badges (CI, license, template-version), add Quick Start GIF/ASCII, link to ONBOARDING.md
  - **AC2** — README mentions all 5 agents by name, lists all 5 workflows
  - **AC3** — README links to: ONBOARDING.md, TELEGRAM-SETUP.md, CONTEXT-HYGIENE.md, ADR-INDEX.md
- **STORY-S21-020:** As P1, I want a 10-minute owner onboarding guide `ONBOARDING.md`, so that I can run first standup without reading 10 docs
  - **AC1** — `ONBOARDING.md` walks through: clone → init → label-seed → board → first issue → first PR → first standup, in ≤ 10 steps
  - **AC2** — Each step has expected output (what success looks like)
  - **AC3** — Validated by ≥ 1 external walkthrough (PM simulates with a fresh fixture dir)
- **STORY-S21-021:** As P1, I want `CONTRIBUTING.md` for template improvements, so that contributors know the review process
  - **AC1** — `CONTRIBUTING.md` covers: PR template, ADR requirement for doctrine changes, d-test requirement, owner approval gate
  - **AC2** — References CODEOWNERS for review routing
  - **AC3** — Links to `docs/decisions/INDEX.md`

### Epic E11 — Validation & Smoke Tests
- **STORY-S21-022:** As P1, I want a smoke-test script that runs on every PR, so that template changes can't break clones
  - **AC1** — `scripts/tests/faz5-smoke.sh` (already mentioned in TEMPLATE-README) covers: dry-run, broken-tmpl, idempotency, fresh-clone, manual-edit
  - **AC2** — Smoke test runs in CI (`.github/workflows/ci.yml` triggers on template-repo PRs)
  - **AC3** — Smoke test exit code gates merge
- **STORY-S21-023:** As P2, I want ≥ 2 fresh-clone validations, so that the template is proven to work end-to-end
  - **AC1** — Clone A: AtilCalculator → fresh-clone test (PM re-runs init on a copy, validates all d-tests pass)
  - **AC2** — Clone B: throwaway test repo (PM creates `atilcan65/dev-studio-template-smoke` as test, runs init, validates)
  - **AC3** — Both clones' d-test reports attached to Sprint 21 close.md

### Epic E12 — Template Versioning & Distribution
- **STORY-S21-024:** As P2, I want a template-version pin (`.template-version`), so that clones can detect upstream drift
  - **AC1** — `.template-version` file at repo root, semver (e.g. `1.0.0`)
  - **AC2** — Init script writes the version into `.claude/agents/<role>.md` headers
  - **AC3** — `agent-doctor.sh <role>` reports `template-version: <installed>` vs `<latest>`
- **STORY-S21-025:** As P2, I want a CHANGELOG.md for the template, so that doctrine updates are traceable
  - **AC1** — `CHANGELOG.md` follows Keep-a-Changelog format
  - **AC2** — Each entry: version, date, added/changed/deprecated/removed/fixed/security
  - **AC3** — Latest entry matches `.template-version`

---

## 5. Sprint Capacity & Sequencing

**Team:** 5 agents (PM, arch, dev, tester, orchestrator). Owner is merge gate + scope-change decision.

**Capacity assumption (PM does not estimate alone, this is rough):**
- Dev: ~30 story points / sprint (full-stack for template work — script + doc + CI)
- Tester: ~25 points (d-test authoring + smoke-test validation)
- Architect: ~15 points (ADR review + 9-Lens on template PRs)
- PM: ~10 points (story grooming + scope-change + retro)
- Orchestrator: ~10 points (board sync + ceremony facilitation)

**Sprint 21 story count:** 25 stories (5 epics × ~5 stories, plus infra epics).

**Sizing strategy (per ADR-0021 §Status flip matrix, requires arch+dev+tester joint sizing):**
- Most stories: 2-3 points (small, well-defined)
- A few stories: 5 points (PR template creation, smoke-test external validation)
- All stories: ≤ 5 points (PM Hard Rule: split larger ones)

**Sequencing (proposed dependency graph):**

```
[Wave 1 — Foundation, days 1-3]
  S21-001, S21-002, S21-008, S21-019
  (template flag, license, CLAUDE.md, README polish — independent, parallel)

[Wave 2 — Parameterization, days 3-6]
  S21-003, S21-004, S21-005, S21-006, S21-007
  (init script, audit, .tmpl, soul files, version pinning — depends on Wave 1)

[Wave 3 — Scripts & Workflows, days 5-8]
  S21-009, S21-010, S21-011, S21-012, S21-013, S21-014
  (script lib, parameterization, workflows, secrets, issue/PR templates — depends on Wave 2)

[Wave 4 — ADRs & d-tests, days 7-10]
  S21-015, S21-016, S21-017, S21-018
  (ADR lib, ADR-0001 template-arch, d-tests, d070-template-render — depends on Wave 2)

[Wave 5 — Validation & Versioning, days 9-12]
  S21-020, S21-021, S21-022, S21-023, S21-024, S21-025
  (onboarding, contributing, smoke-test, fresh-clone validation, version pin, changelog — depends on Wave 3+4)
```

---

## 6. Done Criteria (Sprint 21)

Sprint 21 is **Done** only if ALL of these hold:

1. **All 25 stories Closed** with passing AC (per Definition of Done in CLAUDE.md)
2. **External clone works:** A fresh `gh repo create test --template` + `bash scripts/dev-studio-init.sh` exits 0 with all d-tests green
3. **No hardcoded project refs:** `scripts/audit-project-refs.sh` exits 0 on a rendered clone
4. **Owner walkthrough validated:** PM simulates the 10-step onboarding, captures time-to-first-standup
5. **All 10 workflows fire correctly** on a test PR in a fresh clone
6. **CHANGELOG.md** updated with Sprint 21 entry
7. **No P0/P1 bugs** filed against template within 24h post-squash
8. **At least 3 throwaway clones** validated end-to-end (AtilCalculator, dev-studio-template-smoke, owner-test-clone)

---

## 7. Out of Scope (Sprint 21)

Explicitly NOT doing:

- ❌ Multi-project orchestration (1 template → N projects at once) — Sprint 22+
- ❌ Auto-update from upstream template (template pull mechanism) — Sprint 22+
- ❌ GUI for template selection — Sprint 24+
- ❌ Telemetry across clones (which projects use template, version distribution) — out of scope
- ❌ Marketplace listing / discoverability — owner decision
- ❌ Per-agent PAT issuance (5 agents on 1 PAT is current AtilCalculator model, kept for Sprint 21)
- ❌ Container image for dev environment (template is git-based only)

---

## 8. Dependencies

- **Upstream:**
  - AtilCalculator current state (the source of truth for what gets templatized) — already in repo
  - Existing d-tests pass on AtilCalculator — already true
- **Downstream (Sprint 22+ candidates):**
  - Template-pull mechanism (S21-024 enables versioning detection → Sprint 22 builds the pull)
  - Multi-project orchestrator (depends on template being stable)
- **External:**
  - GitHub `is_template=true` API — works as of 2026-06-29
  - `gh repo create --template` — works
  - `gh secret set` — works

---

## 9. Open Questions (for owner)

See `OPEN-QUESTIONS.md` for the full list. Key questions:

- **Q1:** License? (MIT / Apache-2.0 / internal-only / dual-license)
- **Q2:** Template repo name? (`dev-studio-template` vs `multi-agent-template` vs other)
- **Q3:** Visibility default? (`--public` per ADR-0016, or `--private` opt-in?)
- **Q4:** AtilCalculator relationship? Is AtilCalculator itself the template, or a clone-of-template? (Affects whether AtilCalculator gets the `.template-version` file too)
- **Q5:** Sprint 21 start date? (Today 2026-06-29, or specific kickoff date)
- **Q6:** Does Sprint 20 close-out happen in parallel, or before Sprint 21 kickoff?

---

## 10. Risks

See `RISK-REGISTER.md` for full register. Top 3:

- **R1 (P1):** Parameterization scope creep — 100+ files reference project name. Mitigation: `audit-project-refs.sh` gates merge
- **R2 (P1):** Doctrine drift between template and AtilCalculator — if Sprint 21 ships a template, AtilCalculator must be a "clone of template + customizations". Mitigation: dual-license model where AtilCalculator keeps current state, template is a frozen snapshot + init script
- **R3 (P2):** First-time user confusion — owner onboarding guide must be validated by ≥ 1 external walkthrough. Mitigation: S21-023 throwaway clones

---

## 11. Metrics of Success

- **Leading:**
  - Story closure rate (target: 25/25 by sprint end)
  - d-test pass rate on fresh clone (target: 100% of 40+ d-tests)
  - External walkthrough time-to-first-standup (target: ≤ 60 min)
- **Lagging:**
  - Adoption (count of new projects using template in 30 days post-release)
  - Bug reports filed against template in 30 days (target: < 5)
  - Contributor PRs to template in 60 days (target: ≥ 3 from non-owner)

---

## 12. PM RECOMMENDATION

**Recommendation (a):** Proceed with Sprint 21 as scoped. Open Sprint 21 with `gh issue create --title "[Sprint 21] Multi-Agent Dev Studio Template: FINALIZE" --label type:chore --label status:ready --label agent:orchestrator --label cc:product-manager`. Owner ratifies scope, orchestrator publishes `plan.md`, sprint kicks off.

**Alternative (b) — if owner wants to validate the template first:** Run S21-022 + S21-023 (smoke test + fresh-clone validation) as a 1-week spike, then commit to full Sprint 21 scope based on validation results.

**Recommendation if owner wants to close AtilCalculator first:** Sprint 20 PROJECT CLOSE → Sprint 21 template work (current PM RECOMMENDATION in AtilCalculator context was PROJECT CLOSE; owner's directive may be a pivot, not a contradiction).

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** DRAFT (awaiting owner ratification)
**Lane:** docs/sprints/sprint-21/ (PM-owned, per file ownership matrix)