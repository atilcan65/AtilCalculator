# STORY-S21-006

> **PM-regenerated from GitHub issue #638** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/638
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all 5 soul files in the template**, so that **agents wake with correct doctrine on first standup**.

## Why now

Soul files are the agent identity. Missing any one = one agent wakes with no doctrine.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `.claude/agents/` THEN 5 files: orchestrator.md, product-manager.md, architect.md, developer.md, tester.md.
- **AC2** — GIVEN 5 soul files WHEN audit script runs THEN all reference `CLAUDE.md` as project doctrine source.
- **AC3** — GIVEN 5 soul files WHEN init script runs THEN all use `{{HUMAN_OWNER_NAME}}` for owner mention AND `{{GITHUB_OWNER}}/{{GITHUB_REPO}}` for repo refs.

## Out of scope

- Soul file customization per project (template ships canonical souls).

## Dependencies

- **Upstream:** S21-005.
- **Downstream:** S21-007 (versioning).

## Metrics of success

- **Leading:** `ls .claude/agents/*.md | wc -l` returns 5.
- **Lagging:** First standup on a fresh clone wakes all 5 agents without doctrine errors.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens on soul integrity)
- **Tester:** tester (audit-script coverage)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E3 — Agent Soul Files
- **Wave:** Wave 3 (Day 7-9)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
