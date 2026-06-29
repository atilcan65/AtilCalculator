# STORY-S21-003

> **PM-regenerated from GitHub issue #636** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/636
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **`dev-studio-init.sh` to resolve all `{{...}}` placeholders**, so that **project name flows through every file in the clone**.

## Why now

Without this, every clone has hardcoded "AtilCalculator" / "atilcan65" everywhere — broken out of the box.

## Acceptance Criteria

- **AC1** — GIVEN fresh clone WHEN user runs `bash scripts/dev-studio-init.sh` AND answers prompts for `GITHUB_OWNER`, `GITHUB_REPO`, `HUMAN_OWNER_NAME`, `PROJECT_NAME` THEN init script writes all rendered files AND exit code 0.
- **AC2** — GIVEN init script completed WHEN user runs `grep -r '{{' . --exclude-dir=.git --exclude-dir=.venv` THEN 0 matches.
- **AC3** — GIVEN init script completed WHEN user re-runs `bash scripts/dev-studio-init.sh` THEN idempotent (running twice does not corrupt state, no diff after second run). Per Q4 arch caveat.

## Out of scope

- Interactive GUI init, web-based init.

## Dependencies

- **Upstream:** S21-005 (.tmpl source files exist).
- **Downstream:** S21-004 (audit script), S21-012 (PROJECT_TOKEN handling), S21-018 (d070 test).

## Metrics of success

- **Leading:** `grep -r '{{' . --exclude-dir=.git` returns 0 matches on post-init clone.
- **Lagging:** S21-023 fresh-clone validation passes (PM runs init on 2 separate clones, all d-tests pass).

## Sizing

- **Hint:** 5 points (large: extends existing init script, requires audit of all references).
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens idempotency + silent_skip per ADR-0045 lens d+e)
- **Tester:** tester (d070-template-render covers this)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E2 — Parameterization & Init Script
- **Wave:** Wave 2 (Day 4-6)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
