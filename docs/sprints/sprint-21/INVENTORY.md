# Sprint 21 — Inventory: Every Artifact in the Template

> **PM audit, 2026-06-29.** This is the exhaustive list of every file the template must contain.
> Source: `find /home/atilcan/projects/AtilCalculator -type f -not -path '*/\.git/*' -not -path '*/\.venv/*' -not -path '*/__pycache__/*'` filtered for template-worthiness.

---

## 1. Soul Files (5 — PM Hard Rule: all 5 must be in template)

| File | Size | Status | Parameterized? |
|---|---|---|---|
| `.claude/agents/orchestrator.md` | 22.9 KB | ✅ exists | ⏳ audit pending |
| `.claude/agents/product-manager.md` | 40.6 KB | ✅ exists | ⏳ audit pending |
| `.claude/agents/architect.md` | 35.5 KB | ✅ exists | ⏳ audit pending |
| `.claude/agents/developer.md` | 23.9 KB | ✅ exists | ⏳ audit pending |
| `.claude/agents/tester.md` | 35.7 KB | ✅ exists | ⏳ audit pending |

**Action:** All 5 files must use `{{HUMAN_OWNER_NAME}}` for owner mention, `{{GITHUB_OWNER}}/{{GITHUB_REPO}}` for repo refs. Audit script `audit-project-refs.sh` validates post-init.

---

## 2. CLAUDE.md (Project Doctrine — PM Hard Rule: must be in template root)

| File | Status | Notes |
|---|---|---|
| `CLAUDE.md` (root) | ⚠️ gitignored (per file ownership matrix) | Source of truth for Claude Code. Must be in template as `.tmpl`, init script renders to root. |

**Action:** Create `CLAUDE.md.tmpl`, init script renders to root, `.gitignore` updated to NOT gitignore it (template has it tracked).

---

## 3. Scripts (template keeps entire `scripts/` tree, ~40 files)

### Core operational scripts

| Script | Purpose | Status |
|---|---|---|
| `scripts/notify.sh` | Telegram notification (legacy form, kept for backward compat) | ✅ exists |
| `scripts/peer-poke.sh` | Dual-channel peer wake per ADR-0033 | ✅ exists |
| `scripts/agent-watch.sh` | Autonomy loop per ADR-0002 | ✅ exists |
| `scripts/agent-state.sh` | State management (watermark, dedup) | ✅ exists |
| `scripts/agent-state-repair.sh` | State recovery | ✅ exists |
| `scripts/claim-next-ready.sh` | Auto-claim per ADR-0038 | ✅ exists |
| `scripts/ping.sh` | Escalation to human | ✅ exists |
| `scripts/agent-doctor.sh` | Agent health diagnostic | ✅ exists |
| `scripts/agent-journal.sh` | Agent activity log | ✅ exists |
| `scripts/agent-context-monitor.sh` | Context size monitor | ✅ exists |
| `scripts/agent-wake.sh` | Manual agent wake | ✅ exists |
| `scripts/agent-watch-verdicts.sh` | Verdict-specific watch | ✅ exists |

### Init & bootstrap scripts

| Script | Purpose | Status |
|---|---|---|
| `scripts/dev-studio-init.sh` | Render `.tmpl` files, resolve placeholders | ✅ exists (parametrization audit pending) |
| `scripts/dev-studio-start.sh` | tmux session + 5 instance restart | ✅ exists |
| `scripts/bootstrap-labels.sh` | Seed 35 labels | ✅ exists |
| `scripts/bootstrap-project-board.sh` | GitHub Projects v2 board setup | ✅ exists |
| `scripts/reprime-agent.sh` | Send [REPRIME] to an agent | ✅ exists |

### Operational hygiene scripts

| Script | Purpose | Status |
|---|---|---|
| `scripts/health-check.sh` | System health | ✅ exists |
| `scripts/lint-notify-invocations.sh` | Lint `notify.sh` calls | ✅ exists |
| `scripts/post-restart-label-guard.sh` | Post-restart label state guard | ✅ exists |
| `scripts/orchestrator-gap-scan.sh` | Orchestrator gap detection | ✅ exists |
| `scripts/orchestrator-status-flip.sh` | Status label flip utility | ✅ exists |
| `scripts/proactive-board-scan.sh` | Board state proactive scan | ✅ exists |
| `scripts/strip-cascade-labels.sh` | Cascade label stripper | ✅ exists |
| `scripts/cross-repo-close.sh` | Cross-repo PR auto-close | ✅ exists |
| `scripts/cross-repo-scan.sh` | Cross-repo scan | ✅ exists |
| `scripts/event-log.sh` | Event log utility | ✅ exists |
| `scripts/atomic-write.sh` | Atomic write helper | ✅ exists |
| `scripts/wip-idle-detect.sh` | WIP/idle watchdog | ✅ exists |
| `scripts/deploy-runner.sh` | Deploy runner helper | ✅ exists |
| `scripts/run-server.sh` | Server runner | ✅ exists |
| `scripts/status-action-driver.sh` | Status action driver | ✅ exists |
| `scripts/apply-reprime-protocol.py` | REPRIME Python impl | ✅ exists |

### Helper utilities

| Script | Purpose | Status |
|---|---|---|
| `scripts/pre-push` | Pre-push hook | ✅ exists |
| `scripts/kickoff` | Kickoff helper | ✅ exists |
| `scripts/install` | Install helper | ✅ exists |

### d-test family (40+)

| Test | Purpose | Status |
|---|---|---|
| `scripts/tests/d006-stable-event-ids.sh` | Event ID stability | ✅ exists |
| `scripts/tests/d007-api-observability.sh` | API observability | ✅ exists |
| `scripts/tests/d011-status-action-driver.sh` | Status driver | ✅ exists |
| `scripts/tests/d012-stale-verdict-schema.sh` | Verdict schema | ✅ exists |
| `scripts/tests/d013-issue-assigneeship-authority.sh` | Assigneeship authority | ✅ exists |
| `scripts/tests/d014-rca-9-preflight-venv-create.sh` | Venv preflight | ✅ exists |
| `scripts/tests/d015-dev-idle-prevention.sh` | Dev idle prevention | ✅ exists |
| `scripts/tests/d016-rca-11-runtime-deps-explicit.sh` | Runtime deps | ✅ exists |
| `scripts/tests/d017-rca-12-cross-user-port-8000.sh` | Port 8000 | ✅ exists |
| `scripts/tests/d018-rca-14-uvicorn-orphan-kill.sh` | Uvicorn orphan | ✅ exists |
| `scripts/tests/d019-e2e-deploy-verify.sh` | E2E deploy | ✅ exists |
| `scripts/tests/d022-proactive-board-detections.sh` | Board detection | ✅ exists |
| `scripts/tests/d023-rca18-buffer-ttl.sh` | Buffer TTL | ✅ exists |
| `scripts/tests/d024-agent-wake.sh` | Agent wake | ✅ exists |
| `scripts/tests/d025-cmd-set-argjson-contract.sh` | cmd-set contract | ✅ exists |
| `scripts/tests/d027-state-recovery.sh` | State recovery | ✅ exists |
| `scripts/tests/d028-no-standby.sh` | No-standby | ✅ exists |
| `scripts/tests/d029-no-standby-watcher-text.sh` | Watcher text | ✅ exists |
| `scripts/tests/d030-cmd-set-quoting-guard.sh` | Quoting guard | ✅ exists |
| `scripts/tests/d031-claim-next-ready.sh` | Auto-claim | ✅ exists |
| `scripts/tests/d032-rca-19-status-transition-wake.sh` | Status transition | ✅ exists |
| `scripts/tests/d034-proactive-wip-idle.sh` | WIP idle | ✅ exists |
| `scripts/tests/d035-cross-repo-close.sh` | Cross-repo close | ✅ exists |
| `scripts/tests/d036a/b/c/d-cli-*.sh` | CLI tests | ✅ exists |
| `scripts/tests/d036-pr-verdict-detect.sh` | PR verdict detect | ✅ exists |
| `scripts/tests/d036-state-dedup-ring.sh` | State dedup | ✅ exists |
| `scripts/tests/d037-notify-deprecation.sh` | Notify deprecation | ✅ exists |
| `scripts/tests/d037-v8-verdict-posted.sh` | V8 verdict | ✅ exists |
| `scripts/tests/d038-ping-wrapper.sh` | Ping wrapper | ✅ exists |
| `scripts/tests/d039-lint-notify-invocations.sh` | Notify lint | ✅ exists |
| `scripts/tests/d040-deploy-path-guard.sh` | Deploy path | ✅ exists |
| `scripts/tests/d041-platform-constraint-linter.sh` | Platform constraint | ✅ exists |
| `scripts/tests/d043-platform-constraint-linter-ext.sh` | Platform constraint ext | ✅ exists |
| `scripts/tests/d046a/b/c-*.sh` | 9-Lens checks | ✅ exists |
| `scripts/tests/ci-detects-pyproject.sh` | CI pyproject detect | ✅ exists |
| `scripts/tests/run-all.sh` | **NEW** — Run all d-tests | ⏳ to author |

**Action:** All d-tests must pass on a fresh clone post-init. S21-017 author `run-all.sh`.

---

## 4. GitHub Workflows (10)

| Workflow | Purpose | Status |
|---|---|---|
| `.github/workflows/ci.yml` | CI: ruff → mypy → pytest | ✅ exists |
| `.github/workflows/label-check.yml` | 4-cat invariant per ADR-0012 | ✅ exists |
| `.github/workflows/label-cleanup.yml` | Cascade label cleanup | ✅ exists |
| `.github/workflows/status-label-to-board.yml` | Board sync per ADR-0013 | ✅ exists |
| `.github/workflows/lint-and-test.yml` | Lint + test combined | ✅ exists |
| `.github/workflows/post-squash.yml` | Post-squash hooks | ✅ exists |
| `.github/workflows/secret-canary.yml` | Secret leak canary | ✅ exists |
| `.github/workflows/cross-repo-close.yml` | Cross-repo PR auto-close | ✅ exists |
| `.github/workflows/ai-pr-review.yml` | AI PR review | ✅ exists |
| `.github/workflows/deploy.yml` | Deploy automation | ✅ exists |

**Action:** All 10 must be parameterized. PROJECT_TOKEN reference works post-init (S21-012).

---

## 5. Issue Templates (6)

| Template | Purpose | Status |
|---|---|---|
| `.github/ISSUE_TEMPLATE/vision-intake.yml` | Vision intake form | ✅ exists |
| `.github/ISSUE_TEMPLATE/bug.yml` | Bug report | ✅ exists |
| `.github/ISSUE_TEMPLATE/feature-request.yml` | Feature request | ✅ exists |
| `.github/ISSUE_TEMPLATE/incident.yml` | Production incident | ✅ exists |
| `.github/ISSUE_TEMPLATE/agent-stall.yml` | Agent stall | ✅ exists |
| `.github/ISSUE_TEMPLATE/config.yml` | Issue chooser config | ✅ exists |

**Action:** All 6 must auto-apply 4-cat labels on submission (S21-013).

---

## 6. PR Template (1)

| Template | Purpose | Status |
|---|---|---|
| `.github/PULL_REQUEST_TEMPLATE.md` | PR submission form | ❌ **MISSING** — Sprint 21 to author |

**Action:** S21-014 creates this with sections: Summary, Doctrine impact, ADR cross-ref, Test plan, Owner checklist.

---

## 7. ADRs (60+)

| ADR | Title | Status |
|---|---|---|
| ADR-0001 (template-architecture) | **NEW** — Template architecture (single repo, parameterization, secrets, distribution) | ⏳ S21-016 to author |
| ADR-0002 | Autonomy loop | ✅ exists |
| ADR-0010 | Per-project watchers | ✅ exists |
| ADR-0011 | Watcher dropin override | ✅ exists |
| ADR-0012 | Required label set (4-cat) | ✅ exists |
| ADR-0013 | Status-label-to-board sync | ✅ exists |
| ADR-0014 | PROJECT_TOKEN secret | ✅ exists |
| ADR-0015 | Atomic agent handoff | ✅ exists |
| ADR-0016 | Public-by-default | ✅ exists |
| ADR-0017 | Tech stack | ✅ exists |
| ADR-0018 | Front-end framework | ✅ exists |
| ADR-0019 | Amendment 2-decimal/envelope | ✅ exists |
| ADR-0019 | API contract | ✅ exists |
| ADR-0020 | Label mutation transactionality | ✅ exists |
| ADR-0021 | Docs PR convention | ✅ exists |
| ADR-0022 | Persistence layer | ✅ exists |
| ADR-0023 | Frontend architecture | ✅ exists |
| ADR-0024 | Stale verdict watchdog schema | ✅ exists |
| ADR-0025 | Bound standby exception | ✅ exists |
| ADR-0026 | Queue empty mention check | ✅ exists |
| ADR-0027 | Deploy automation | ✅ exists |
| ADR-0030 | Self-hosted runner LAN deploy | ✅ exists |
| ADR-0031 | Owner override doctrine | ✅ exists |
| ADR-0032 | RCA-18 dedup buffer pollution | ✅ exists |
| ADR-0033 | Auto-ping dual-channel | ✅ exists |
| ADR-0034 | Agent state cmd-set argjson | ✅ exists |
| ADR-0035 | Layer3 open-only fire | ✅ exists |
| ADR-0036 | Status transition wake | ✅ exists |
| ADR-0037 | Proactive gap scan | ✅ exists |
| ADR-0038 | Amendment watcher enforcement | ✅ exists |
| ADR-0038 | Amendment workstream awareness | ✅ exists |
| ADR-0038 | Auto-claim protocol | ✅ exists |
| ADR-0039 | WIP idle watchdog | ✅ exists |
| ADR-0040 | Cross-repo PR auto-close | ✅ exists |
| ADR-0041 | Event model v8 verdict posted | ✅ exists |
| ADR-0042 | Orchestrator role | ✅ exists |
| ADR-0043 | 8-Lens architect review | ✅ exists |
| ADR-0044 | Verdict-by scope clarification | ✅ exists |
| ADR-0045 | Auto-generated file refs design | ✅ exists |
| ADR-0046 | Load-bearing ADR implementation | ✅ exists |
| ADR-0047 | Cross-repo watcher | ✅ exists |
| ADR-0048 | Status ready auto-add gating | ✅ exists |
| ADR-0049 | Amendment subcheck k | ✅ exists |
| ADR-0049 | Behavioral workflow test framework | ✅ exists |
| ADR-0050 | Pre-merge 4-cat verification | ✅ exists |
| ADR-0051 | Engine perf flake vs regression | ✅ exists |
| ADR-0052 | CI rerun race codification | ✅ exists |
| ADR-0053 | Layer-5 race pattern | ✅ exists |
| ADR-0054 | 9-Lens enforcement | ✅ exists |
| ADR-0055 | d-test ID uniqueness | ✅ exists |
| ADR-0056 | Layer-5 idempotency reconcile | ✅ exists |
| ADR-0057 | Closes-anchor guard | ✅ exists |
| ADR-0058 | Comment-trigger guard | ✅ exists |
| ADR-0059 | Cluster squash batch lag detection | ✅ exists |
| ADR-0060 | AC mapping verification doctrine | ✅ exists |
| `INDEX.md` | ADR index | ✅ exists |

**Action:** All ADRs are project-agnostic doctrine. Init script does NOT modify ADRs. S21-015 verifies INDEX.md is current.

---

## 8. Project Root Files

| File | Purpose | Status |
|---|---|---|
| `TEMPLATE-README.md` | Template quickstart | ✅ exists |
| `README.md` | Project README (post-init) | ✅ exists |
| `CHANGELOG.md` | Project changelog | ✅ exists |
| `LICENSE` | License file | ❌ **MISSING** — S21-002 to author |
| `CODEOWNERS` | GitHub code owners | ✅ exists |
| `pyproject.toml` | Python project metadata | ✅ exists |
| `.gitignore` | Git ignore | ✅ exists |
| `.gitattributes` | Git attributes | ⚠️ audit pending |
| `.template-version` | Template version pin | ❌ **MISSING** — S21-024 to author |

---

## 9. Documentation (`docs/`)

| File | Purpose | Status |
|---|---|---|
| `docs/CLAUDE.md` | Public doctrine summary | ✅ exists |
| `docs/CONTEXT-HYGIENE.md` | REPRIME doctrine | ✅ exists |
| `docs/TELEGRAM-SETUP.md` | Telegram bot setup | ✅ exists |
| `docs/peer-poke-spec.md` | Peer-poke spec | ✅ exists |
| `docs/tech-debt.md` | Tech debt tracker | ✅ exists |
| `docs/decisions/INDEX.md` | ADR index | ✅ exists |
| `docs/decisions/ADR-*.md` | 60+ ADRs | ✅ exists |
| `ONBOARDING.md` | **NEW** — 10-min owner walkthrough | ❌ **MISSING** — S21-020 to author |
| `CONTRIBUTING.md` | **NEW** — Template contribution guide | ❌ **MISSING** — S21-021 to author |

---

## 10. Sample Project Code

| File | Purpose | Status |
|---|---|---|
| `src/atilcalc/` | Sample engine module | ✅ exists (AtilCalculator-specific, init script replaces with `<project-name>/`) |
| `tests/engine/`, `tests/cli/`, `tests/api/`, `tests/web/`, `tests/integration/` | Sample tests | ✅ exists |
| `systemd/` | Systemd unit files | ✅ exists (AtilCalculator-specific, init script replaces) |

**Action:** Init script replaces `atilcalc` → `<project-name>` everywhere. S21-003 + S21-004 (audit script) gate this.

---

## 11. Pre-installed Examples

| File | Purpose | Status |
|---|---|---|
| `docs/product/vision.md` | Sample vision doc | ⚠️ audit pending (project-specific or template?) |
| `docs/product/personas.md` | Sample personas doc | ⚠️ audit pending |
| `docs/backlog.json` | Sample backlog | ⚠️ audit pending |
| `docs/backlog/STORY-NNN.md` | Sample story template | ⚠️ audit pending |
| `docs/sprints/sprint-NN/proposed-scope.md` | Sample sprint plan | ⚠️ audit pending |
| `docs/sprints/sprint-NN/RETRO-NN.md` | Sample retro template | ⚠️ audit pending |
| `docs/sprints/sprint-NN/close.md` | Sample close template | ⚠️ audit pending |
| `docs/glossary.md` | Sample glossary | ⚠️ audit pending |

**Action:** S21-003 + S21-004 audit which docs are "doctrine templates" (kept as-is) vs "AtilCalculator-specific" (replaced on init).

---

## 12. Sprint 21 Net-New Files (deliverables)

**Files to CREATE:**

1. `.github/PULL_REQUEST_TEMPLATE.md` (S21-014)
2. `LICENSE` (S21-002)
3. `.template-version` (S21-024)
4. `ONBOARDING.md` (S21-020)
5. `CONTRIBUTING.md` (S21-021)
6. `docs/decisions/ADR-0001-template-architecture.md` (S21-016)
7. `scripts/tests/d070-template-render.sh` (S21-018)
8. `scripts/tests/run-all.sh` (S21-017)
9. `scripts/audit-project-refs.sh` (S21-004)
10. `<file>.tmpl` source files (S21-005) — for README.md, CLAUDE.md, .claude/agents/*.md, etc.

**Files to MODIFY:**

1. `scripts/dev-studio-init.sh` — extend placeholder coverage (S21-003)
2. `.gitignore` — un-gitignore `CLAUDE.md` (template-tracked) (S21-008)
3. `TEMPLATE-README.md` — polish with badges, links (S21-019)
4. `CHANGELOG.md` — add Sprint 21 entry (S21-025)

---

## 13. Total File Count

- **Currently in AtilCalculator that template keeps:** ~140 files (5 souls + 1 CLAUDE.md + 40 scripts + 40 d-tests + 10 workflows + 6 issue templates + 60 ADRs + 1 INDEX + 8 docs + 1 README + 1 CHANGELOG + 1 TEMPLATE-README + 1 CODEOWNERS + 1 pyproject + 1 .gitignore + sample src/ + sample tests/ + systemd/)
- **Net-new for Sprint 21:** 10 files
- **Modified for Sprint 21:** 4 files
- **Total in template post-Sprint 21:** ~150 files

---

**Drafted by:** @product-manager
**Date:** 2026-06-29
**Status:** DRAFT (awaiting owner ratification)