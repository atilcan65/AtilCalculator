# STORY-S21-012

> **PM-regenerated from GitHub issue #643** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/643
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **init script to handle `PROJECT_TOKEN` secret**, so that **board-sync workflow has the right scope from day 1**.

## Why now

Without PROJECT_TOKEN, `status-label-to-board.yml` fails (per ADR-0014). First-time users hit this immediately.

## Acceptance Criteria

- **AC1** — GIVEN init script WHEN run THEN it prompts for `PROJECT_TOKEN` and runs `gh secret set PROJECT_TOKEN`.
- **AC2** — GIVEN `docs/TELEGRAM-SETUP.md` WHEN user reads THEN PROJECT_TOKEN setup covered alongside TELEGRAM_BOT_TOKEN.
- **AC3** — GIVEN init script WHEN run THEN it validates `PROJECT_TOKEN` has `project` scope (warns if missing, suggests `gh auth refresh`).

## Out of scope

- Auto-rotating PROJECT_TOKEN, multi-secret management.

## Dependencies

- **Upstream:** S21-003.
- **Downstream:** S21-011 (status-label-to-board.yml requires PROJECT_TOKEN).

## Metrics of success

- **Leading:** Init script prompts + `gh secret set` exit code 0.
- **Lagging:** First board-sync workflow run on fresh clone succeeds.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens — secret-canary coverage per ADR-0014)
- **Tester:** tester (secret-handling d-test)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E6 — GitHub Workflows
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
