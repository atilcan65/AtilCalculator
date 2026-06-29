# Sprint 21 — Story Map

> **PM draft, 2026-06-29.** Each story has INVEST format, Gherkin AC, dependencies, sizing hint (final size = arch+dev+tester joint sizing per ADR-0021).

---

## Epic Index

| Epic | Stories | Focus |
|---|---|---|
| E1 — Template Repository Structure | S21-001, S21-002 | Template flag, license |
| E2 — Parameterization & Init Script | S21-003, S21-004, S21-005 | Render `.tmpl`, audit hardcoded refs |
| E3 — Agent Soul Files | S21-006, S21-007 | All 5 souls parameterized, versioned |
| E4 — CLAUDE.md | S21-008 | Project root doctrine |
| E5 — Scripts Library | S21-009, S21-010 | All scripts + audit-pass |
| E6 — GitHub Workflows | S21-011, S21-012 | All 10 workflows + secrets |
| E7 — Issue & PR Templates | S21-013, S21-014 | 6 issue + 1 PR template |
| E8 — ADRs | S21-015, S21-016 | ADR lib + ADR-0001 template-arch |
| E9 — d-test Family | S21-017, S21-018 | 40+ d-tests + d070 new |
| E10 — Documentation | S21-019, S21-020, S21-021 | README + ONBOARDING + CONTRIBUTING |
| E11 — Validation & Smoke Tests | S21-022, S21-023 | Smoke-test script + 2 fresh-clone validation |
| E12 — Template Versioning & Distribution | S21-024, S21-025 | Version pin + changelog |

**Total: 25 stories across 12 epics.**

---

## Story Details

### S21-001 — Template Flag + "Use this template" Button
- **User Story:** As P1, I want the template repo to have `is_template=true`, so that GitHub UI shows "Use this template" button and `gh repo create --template` works.
- **Why now:** Without this, no one can clone from template. Blocks all downstream stories.
- **AC1** — GIVEN a fresh template repo WHEN owner runs `gh api -X PATCH repos/<owner>/dev-studio-template -f is_template=true` THEN exit code 0 AND `is_template: true` in repo metadata.
- **AC2** — GIVEN template flag set WHEN user visits repo homepage on github.com THEN "Use this template" green button is visible.
- **AC3** — GIVEN template flag set WHEN user runs `gh repo create test-clone --template <owner>/dev-studio-template --clone` THEN new repo is created with template contents.
- **Out of scope:** Custom template description, social preview image (deferred to Sprint 22+).
- **Deps:** none.
- **Size hint:** 1 point (config change).

### S21-002 — LICENSE File
- **User Story:** As P1, I want a `LICENSE` file with explicit license, so that license is unambiguous for users and contributors.
- **Why now:** License is the #1 thing open-source users check. Missing license = all-rights-reserved by default, blocks adoption.
- **AC1** — GIVEN template repo WHEN owner opens `LICENSE` at root THEN file contains full MIT (or chosen) license text with copyright line parameterized as `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}`.
- **AC2** — GIVEN template repo WHEN GitHub UI loads THEN repo sidebar shows license name (e.g., "MIT License").
- **AC3** — GIVEN `TEMPLATE-README.md` WHEN user reads THEN a "License" section references the LICENSE file.
- **Out of scope:** Dual-license, contributor license agreement (CLA), per-file license headers.
- **Deps:** Q1 (license choice) — owner decision.
- **Size hint:** 1 point.

### S21-003 — Init Script: Full Placeholder Resolution
- **User Story:** As P1, I want `dev-studio-init.sh` to resolve all `{{...}}` placeholders, so that project name flows through every file in the clone.
- **Why now:** Without this, every clone has hardcoded "AtilCalculator" / "atilcan65" everywhere — broken out of the box.
- **AC1** — GIVEN fresh clone WHEN user runs `bash scripts/dev-studio-init.sh` AND answers prompts for `GITHUB_OWNER`, `GITHUB_REPO`, `HUMAN_OWNER_NAME`, `PROJECT_NAME` THEN init script writes all rendered files AND exit code 0.
- **AC2** — GIVEN init script completed WHEN user runs `grep -r '{{' . --exclude-dir=.git --exclude-dir=.venv` THEN 0 matches (no unresolved placeholders).
- **AC3** — GIVEN init script completed WHEN user re-runs `bash scripts/dev-studio-init.sh` THEN idempotent (running twice does not corrupt state, no diff after second run).
- **Out of scope:** Interactive GUI init, web-based init.
- **Deps:** S21-005 (.tmpl source files exist).
- **Size hint:** 5 points (large: extends existing init script, requires audit of all references).

### S21-004 — Project Refs Audit Script
- **User Story:** As P1, I want `audit-project-refs.sh` to catch hardcoded "AtilCalculator" / "atilcan65" refs, so that I can validate the template renders cleanly.
- **Why now:** Without this, hardcoded refs leak through. The audit script is the regression guard.
- **AC1** — GIVEN audit script WHEN run on pre-init clone THEN exits 1 (catches `AtilCalculator` or `atilcan65` in tracked files).
- **AC2** — GIVEN audit script WHEN run on post-init clone THEN exits 0 (no hardcoded refs).
- **AC3** — GIVEN audit script WHEN run in CI on a template PR THEN blocks merge if exit 1.
- **Out of scope:** Catching `atilcalc-architect-td012` (machine-specific dir), checking binary files.
- **Deps:** S21-003.
- **Size hint:** 2 points.

### S21-005 — `.tmpl` Source Files
- **User Story:** As P1, I want `.tmpl` source files alongside rendered outputs, so that template changes are diff-able and re-renderable.
- **Why now:** Without `.tmpl` sources, every template change means editing rendered output, losing the source.
- **AC1** — GIVEN template repo WHEN user inspects THEN `README.md.tmpl`, `CLAUDE.md.tmpl`, `.claude/agents/orchestrator.md.tmpl`, etc. exist as source files.
- **AC2** — GIVEN init script WHEN run THEN it reads `.tmpl` and writes rendered output (e.g., `README.md.tmpl` → `README.md`).
- **AC3** — GIVEN two consecutive init runs on same clone WHEN diff compared THEN 0 differences (deterministic).
- **Out of scope:** All files as `.tmpl` (only files with placeholders need it).
- **Deps:** S21-003 (init script reads .tmpl).
- **Size hint:** 3 points (touches ~20 files).

### S21-006 — All 5 Soul Files in Template
- **User Story:** As P1, I want all 5 soul files in the template, so that agents wake with correct doctrine on first standup.
- **Why now:** Soul files are the agent identity. Missing any one = one agent wakes with no doctrine.
- **AC1** — GIVEN template repo WHEN user inspects `.claude/agents/` THEN 5 files: orchestrator.md, product-manager.md, architect.md, developer.md, tester.md.
- **AC2** — GIVEN 5 soul files WHEN audit script runs THEN all reference `CLAUDE.md` as project doctrine source.
- **AC3** — GIVEN 5 soul files WHEN init script runs THEN all use `{{HUMAN_OWNER_NAME}}` for owner mention AND `{{GITHUB_OWNER}}/{{GITHUB_REPO}}` for repo refs.
- **Out of scope:** Soul file customization per project (template ships canonical souls).
- **Deps:** S21-005.
- **Size hint:** 3 points.

### S21-007 — Soul File Template-Version Pin
- **User Story:** As P2, I want each soul file to carry a `template-version` header, so that clones can detect upstream drift.
- **Why now:** Without versioning, clones silently drift from template. Versioning enables Sprint 22+ pull mechanism.
- **AC1** — GIVEN template repo WHEN user inspects `.claude/agents/<role>.md` THEN header contains `<!-- template-version: {{TEMPLATE_VERSION}} -->`.
- **AC2** — GIVEN init script WHEN run THEN it writes the actual version from `.template-version` (not placeholder).
- **AC3** — GIVEN `agent-doctor.sh <role>` WHEN run THEN it reports `installed: <installed_version>` vs `latest: <latest_version>` (latest from upstream template fetch).
- **Out of scope:** Auto-upgrade soul files, drift alerting.
- **Deps:** S21-024 (`.template-version` file exists).
- **Size hint:** 2 points.

### S21-008 — CLAUDE.md at Project Root
- **User Story:** As P1, I want `CLAUDE.md` at repo root with full doctrine, so that Claude Code auto-loads it on every agent wake.
- **Why now:** CLAUDE.md is auto-loaded by Claude Code. Missing it = agents have no doctrine context.
- **AC1** — GIVEN template repo WHEN user inspects root THEN `CLAUDE.md` exists, ≥ 200 lines, covers: Product, Team, Process, Tech stack, DoD, Communication, Auto-Ping Hard-Rule, Autonomy Loop, Required Label Set, Handoff Discipline, Things agents must NEVER do, File ownership matrix.
- **AC2** — GIVEN `CLAUDE.md` WHEN user reads THEN it references `docs/decisions/` for ADRs.
- **AC3** — GIVEN `CLAUDE.md` WHEN init script runs THEN placeholders resolved (`{{HUMAN_OWNER_NAME}}`, `{{GITHUB_OWNER}}/{{GITHUB_REPO}}`).
- **Out of scope:** Per-agent CLAUDE.md (template has one root CLAUDE.md).
- **Deps:** S21-005.
- **Size hint:** 3 points.

### S21-009 — Full Script Library in Template
- **User Story:** As P1, I want all 25+ scripts in the template, so that all operational tools work out of the box.
- **Why now:** Scripts are the operational backbone. Missing any one = operational gap.
- **AC1** — GIVEN template repo WHEN user inspects `scripts/` THEN all 25+ scripts present (notify, peer-poke, agent-watch, agent-state, claim-next-ready, ping, codex-runner, dev-studio-init, dev-studio-start, bootstrap-labels, bootstrap-project-board, health-check, agent-doctor, agent-journal, reprime-agent, lint-notify-invocations, post-restart-label-guard, orchestrator-gap-scan, proactive-board-scan, strip-cascade-labels, cross-repo-close, cross-repo-scan, event-log, atomic-write, wip-idle-detect).
- **AC2** — GIVEN all scripts WHEN audited THEN all have `set -euo pipefail` and a top-of-file usage comment.
- **AC3** — GIVEN `scripts/README.md` WHEN user reads THEN all scripts listed with one-line purpose.
- **Out of scope:** Per-project custom scripts (template ships canonical set).
- **Deps:** S21-005.
- **Size hint:** 3 points.

### S21-010 — Scripts Parameterized
- **User Story:** As P1, I want all scripts parameterized for project, so that hardcoded paths break on clone.
- **Why now:** Without parameterization, scripts reference AtilCalculator paths in a different project.
- **AC1** — GIVEN audit script (S21-004) WHEN run on template THEN 0 hardcoded `AtilCalculator` or `atilcan65` refs in `scripts/`.
- **AC2** — GIVEN scripts WHEN inspected THEN they use `$(gh repo view --json name -q .name)` or env vars (`${GITHUB_REPO}`) instead of hardcoded names.
- **AC3** — GIVEN init script WHEN run THEN `~/.dev-studio-env` template is generated per-project with `GITHUB_OWNER`, `GITHUB_REPO`, `HUMAN_OWNER_NAME`.
- **Out of scope:** Refactoring every script (only scripts with hardcoded refs touched).
- **Deps:** S21-009.
- **Size hint:** 5 points (large: touches many scripts).

### S21-011 — All 10 Workflows in Template
- **User Story:** As P1, I want all 10 GitHub workflows in the template, so that CI/label-check/board-sync fire on first PR.
- **Why now:** Workflows are the automation backbone. Missing any one = automation gap.
- **AC1** — GIVEN template repo WHEN user inspects `.github/workflows/` THEN all 10 present: ci.yml, label-check.yml, label-cleanup.yml, status-label-to-board.yml, lint-and-test.yml, post-squash.yml, secret-canary.yml, cross-repo-close.yml, ai-pr-review.yml, deploy.yml.
- **AC2** — GIVEN all workflows WHEN init script runs THEN all pass `gh workflow list` (syntax valid).
- **AC3** — GIVEN `label-check.yml` WHEN user reads THEN workflow description references 4-cat invariant (ADR-0012).
- **Out of scope:** Per-project workflow customization.
- **Deps:** S21-005.
- **Size hint:** 2 points.

### S21-012 — PROJECT_TOKEN Secret Handling
- **User Story:** As P1, I want init script to handle `PROJECT_TOKEN` secret, so that board-sync workflow has the right scope from day 1.
- **Why now:** Without PROJECT_TOKEN, `status-label-to-board.yml` fails (per ADR-0014). First-time users hit this immediately.
- **AC1** — GIVEN init script WHEN run THEN it prompts for `PROJECT_TOKEN` and runs `gh secret set PROJECT_TOKEN`.
- **AC2** — GIVEN `docs/TELEGRAM-SETUP.md` WHEN user reads THEN PROJECT_TOKEN setup covered alongside TELEGRAM_BOT_TOKEN.
- **AC3** — GIVEN init script WHEN run THEN it validates `PROJECT_TOKEN` has `project` scope (warns if missing, suggests `gh auth refresh`).
- **Out of scope:** Auto-rotating PROJECT_TOKEN, multi-secret management.
- **Deps:** S21-003.
- **Size hint:** 3 points.

### S21-013 — All 6 Issue Templates
- **User Story:** As P1, I want all 6 issue templates in `.github/ISSUE_TEMPLATE/`, so that contributors see the right form on new issue.
- **Why now:** Issue templates set contributor expectations. Without them, contributors write free-form issues that miss 4-cat labels.
- **AC1** — GIVEN template repo WHEN user inspects `.github/ISSUE_TEMPLATE/` THEN all 6 present: vision-intake.yml, bug.yml, feature-request.yml, incident.yml, agent-stall.yml, config.yml.
- **AC2** — GIVEN issue templates WHEN user opens new issue THEN template auto-applies 4-cat labels on submission (per ADR-0012).
- **AC3** — GIVEN `agent-stall.yml` WHEN user reads THEN body references `agent-doctor.sh`.
- **Out of scope:** Custom templates per project.
- **Deps:** none.
- **Size hint:** 2 points.

### S21-014 — PR Template
- **User Story:** As P1, I want a PR template, so that PRs follow the doctrine convention.
- **Why now:** PR template is the doctrine checkpoint. Without it, PRs miss doctrine-impact section.
- **AC1** — GIVEN template repo WHEN user inspects `.github/` THEN `PULL_REQUEST_TEMPLATE.md` exists with sections: Summary, Doctrine impact, ADR cross-ref, Test plan, Owner checklist.
- **AC2** — GIVEN PR template WHEN user reads THEN it is referenced from `CONTRIBUTING.md`.
- **AC3** — GIVEN PR template WHEN user fills "docs only" checkbox THEN CI labeler auto-applies `type:docs` (per ADR-0012 label invariant).
- **Out of scope:** Per-PR-type templates (template has one canonical).
- **Deps:** S21-021 (CONTRIBUTING.md references).
- **Size hint:** 2 points.

### S21-015 — Full ADR Library
- **User Story:** As P1, I want all 60+ ADRs committed, so that doctrine is discoverable.
- **Why now:** ADRs are the architectural memory. Without them, new agents have no context.
- **AC1** — GIVEN template repo WHEN user reads `docs/decisions/INDEX.md` THEN all 60+ ADRs listed with one-line summary each.
- **AC2** — GIVEN all ADRs WHEN inspected THEN all follow template (Context, Decision, Consequences, Alternatives).
- **AC3** — GIVEN init script WHEN run THEN ADRs are NOT modified (doctrine is project-agnostic).
- **Out of scope:** Per-project custom ADRs (template ships canonical set).
- **Deps:** S21-016 (ADR-0001 template-architecture).
- **Size hint:** 1 point (verification).

### S21-016 — ADR-0001 Template Architecture
- **User Story:** As P1, I want an ADR documenting template architecture decisions, so that future contributors understand the parameterization strategy.
- **Why now:** Without ADR-0001, contributors don't know why placeholders are used over build-time codegen.
- **AC1** — GIVEN template repo WHEN user reads `docs/decisions/ADR-0001-template-architecture.md` THEN it covers: single-repo vs monorepo (decision: single repo), parameterization strategy (decision: placeholders + init script), secrets strategy (decision: per-project init prompt), distribution strategy (decision: gh template).
- **AC2** — GIVEN ADR-0001 WHEN user searches THEN it is referenced from `TEMPLATE-README.md` and `CLAUDE.md`.
- **AC3** — GIVEN ADR-0001 WHEN read THEN it cross-references: ADR-0016 (public-by-default), ADR-0014 (PROJECT_TOKEN), ADR-0012 (label invariant).
- **Out of scope:** Multi-template architecture, per-project ADR selection.
- **Deps:** none.
- **Size hint:** 2 points.

### S21-017 — All 40+ d-tests in Template + run-all.sh
- **User Story:** As P1, I want all 40+ d-tests in `scripts/tests/`, so that agent runtime is verifiable on fresh clone.
- **Why now:** d-tests are the regression guard. Missing any one = silent runtime failure.
- **AC1** — GIVEN template repo WHEN user inspects `scripts/tests/` THEN all 40+ d-tests present.
- **AC2** — GIVEN d-tests WHEN user runs `bash scripts/tests/run-all.sh` THEN all exit 0 on fresh clone post-init.
- **AC3** — GIVEN run-all.sh WHEN read THEN it runs d-tests in dependency order (alphabetical or topological).
- **Out of scope:** Per-project custom d-tests.
- **Deps:** S21-018 (d070-template-render must pass first).
- **Size hint:** 2 points.

### S21-018 — d070-template-render Test
- **User Story:** As P1, I want a d-test for the template itself, so that template changes don't break clones.
- **Why now:** Without d070, template PRs can break clones without CI catching it.
- **AC1** — GIVEN template repo WHEN user runs `bash scripts/tests/d070-template-render.sh` THEN it validates `dev-studio-init.sh` on a fixture dir.
- **AC2** — GIVEN d070 WHEN run THEN it covers: happy path (placeholder resolved), idempotency (rerun is no-op), missing placeholder (fails), broken `.tmpl` syntax (fails).
- **AC3** — GIVEN d070 WHEN run THEN it completes in < 30 seconds (no network calls).
- **Out of scope:** Network-based validation (real clone), d071+ future tests.
- **Deps:** S21-003, S21-005.
- **Size hint:** 3 points.

### S21-019 — TEMPLATE-README.md Polish
- **User Story:** As P1, I want `TEMPLATE-README.md` polished with badges and links, so that first impression is professional.
- **Why now:** README is the first thing users see. Polish = trust signal.
- **AC1** — GIVEN TEMPLATE-README.md WHEN user reads THEN badges present: CI status, license, template-version.
- **AC2** — GIVEN TEMPLATE-README.md WHEN user reads THEN all 5 agents named, all 5 workflows listed.
- **AC3** — GIVEN TEMPLATE-README.md WHEN user reads THEN links to: ONBOARDING.md, TELEGRAM-SETUP.md, CONTEXT-HYGIENE.md, ADR-INDEX.md.
- **Out of scope:** GIF/animated demo, video walkthrough.
- **Deps:** S21-020 (ONBOARDING.md exists).
- **Size hint:** 2 points.

### S21-020 — ONBOARDING.md (10-min Owner Walkthrough)
- **User Story:** As P1, I want a 10-minute owner onboarding guide, so that I can run first standup without reading 10 docs.
- **Why now:** Without ONBOARDING.md, first-time users are lost. This is THE adoption blocker.
- **AC1** — GIVEN ONBOARDING.md WHEN user follows steps 1-10 THEN each step ≤ 1 min, total ≤ 10 min.
- **AC2** — GIVEN ONBOARDING.md WHEN user reads THEN each step has expected output ("you should see X").
- **AC3** — GIVEN ONBOARDING.md WHEN PM simulates with fresh fixture dir THEN walks through all 10 steps successfully, captures actual time.
- **Out of scope:** Video walkthrough, GUI installer.
- **Deps:** S21-001, S21-002, S21-003 (template is functional).
- **Size hint:** 5 points (large: external validation required).

### S21-021 — CONTRIBUTING.md
- **User Story:** As P1, I want a `CONTRIBUTING.md` for template improvements, so that contributors know the review process.
- **Why now:** Without CONTRIBUTING.md, contributors don't know the doctrine-change review gate.
- **AC1** — GIVEN CONTRIBUTING.md WHEN user reads THEN it covers: PR template, ADR requirement for doctrine changes, d-test requirement, owner approval gate.
- **AC2** — GIVEN CONTRIBUTING.md WHEN read THEN it references CODEOWNERS for review routing.
- **AC3** — GIVEN CONTRIBUTING.md WHEN read THEN it links to `docs/decisions/INDEX.md`.
- **Out of scope:** Per-contributor CLA, code style guide.
- **Deps:** S21-014 (PR template exists).
- **Size hint:** 2 points.

### S21-022 — Smoke Test Script
- **User Story:** As P1, I want a smoke-test script that runs on every PR, so that template changes can't break clones.
- **Why now:** Without smoke test in CI, template PRs can ship broken.
- **AC1** — GIVEN `scripts/tests/faz5-smoke.sh` WHEN run THEN it covers: dry-run (no init), broken-tmpl (init fails), idempotency (rerun OK), fresh-clone (full init), manual-edit (init rerender preserves manual edits).
- **AC2** — GIVEN smoke test WHEN run in `.github/workflows/ci.yml` THEN triggers on template-repo PRs.
- **AC3** — GIVEN smoke test WHEN run THEN exit code gates merge (CI red = no merge).
- **Out of scope:** Network-based smoke (real GitHub clone).
- **Deps:** S21-018 (d070-template-render shares fixtures).
- **Size hint:** 3 points.

### S21-023 — Fresh-Clone Validation (≥ 2 clones)
- **User Story:** As P2, I want ≥ 2 fresh-clone validations, so that the template is proven to work end-to-end.
- **Why now:** Without external validation, template may work for AtilCalculator but fail for first-time user.
- **AC1** — GIVEN PM runs `bash scripts/dev-studio-init.sh` on a copy of AtilCalculator THEN all d-tests pass.
- **AC2** — GIVEN PM creates throwaway test repo (`atilcan65/dev-studio-template-smoke`) AND runs init THEN all d-tests pass.
- **AC3** — GIVEN both clones WHEN PM captures d-test reports THEN both attached to Sprint 21 close.md.
- **Out of scope:** Production-usage clones, third-party clones (Sprint 22+ adoption metric).
- **Deps:** S21-017, S21-018.
- **Size hint:** 3 points.

### S21-024 — `.template-version` Pin
- **User Story:** As P2, I want a template-version pin (`.template-version`), so that clones can detect upstream drift.
- **Why now:** Without versioning, clones silently drift from template.
- **AC1** — GIVEN template repo WHEN user inspects root THEN `.template-version` exists with semver (e.g., `1.0.0`).
- **AC2** — GIVEN init script WHEN run THEN it writes the version into `.claude/agents/<role>.md` headers.
- **AC3** — GIVEN `agent-doctor.sh <role>` WHEN run THEN it reports `template-version: <installed>` vs `<latest>`.
- **Out of scope:** Auto-upgrade, drift alerting.
- **Deps:** S21-007 (soul files reference version).
- **Size hint:** 2 points.

### S21-025 — CHANGELOG.md Update
- **User Story:** As P2, I want `CHANGELOG.md` for the template, so that doctrine updates are traceable.
- **Why now:** Without CHANGELOG, contributors don't know what changed between versions.
- **AC1** — GIVEN CHANGELOG.md WHEN user reads THEN it follows Keep-a-Changelog format.
- **AC2** — GIVEN CHANGELOG.md WHEN user reads THEN each entry: version, date, added/changed/deprecated/removed/fixed/security.
- **AC3** — GIVEN CHANGELOG.md WHEN read THEN latest entry matches `.template-version` (e.g., `## [1.0.0] - 2026-06-29`).
- **Out of scope:** Auto-generation from PRs, release notes.
- **Deps:** S21-024 (version pin).
- **Size hint:** 1 point.

---

## Sizing Summary

| Story | Size hint | Epic |
|---|---|---|
| S21-001 | 1 | E1 |
| S21-002 | 1 | E1 |
| S21-003 | 5 | E2 |
| S21-004 | 2 | E2 |
| S21-005 | 3 | E2 |
| S21-006 | 3 | E3 |
| S21-007 | 2 | E3 |
| S21-008 | 3 | E4 |
| S21-009 | 3 | E5 |
| S21-010 | 5 | E5 |
| S21-011 | 2 | E6 |
| S21-012 | 3 | E6 |
| S21-013 | 2 | E7 |
| S21-014 | 2 | E7 |
| S21-015 | 1 | E8 |
| S21-016 | 2 | E8 |
| S21-017 | 2 | E9 |
| S21-018 | 3 | E9 |
| S21-019 | 2 | E10 |
| S21-020 | 5 | E10 |
| S21-021 | 2 | E10 |
| S21-022 | 3 | E11 |
| S21-023 | 3 | E11 |
| S21-024 | 2 | E12 |
| S21-025 | 1 | E12 |
| **Total** | **63 points** | |

**Capacity check:** Team total ~90 points/sprint. 63 fits with buffer for retros, ceremonies, scope-change. S21-003 + S21-010 + S21-020 are the 5-pointers (large).

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** DRAFT (awaiting owner ratification + arch+dev+tester joint sizing)