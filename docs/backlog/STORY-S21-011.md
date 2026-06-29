# STORY-S21-011

> **PM-regenerated from GitHub issue #641** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/641
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all 10 GitHub workflows in the template**, so that **CI/label-check/board-sync fire on first PR**.

## Why now

Workflows are the automation backbone. Missing any one = automation gap.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `.github/workflows/` THEN all 10 present: ci.yml, label-check.yml, label-cleanup.yml, status-label-to-board.yml, lint-and-test.yml, post-squash.yml, secret-canary.yml, cross-repo-close.yml, ai-pr-review.yml, deploy.yml.
- **AC2** — GIVEN all workflows WHEN init script runs THEN all pass `gh workflow list` (syntax valid).
- **AC3** — GIVEN `label-check.yml` WHEN user reads THEN workflow description references 4-cat invariant (ADR-0012).

## Out of scope

- Per-project workflow customization.

## Dependencies

- **Upstream:** S21-005.
- **Downstream:** S21-022 (smoke test CI integration).

## Metrics of success

- **Leading:** `ls .github/workflows/*.yml | wc -l` returns ≥ 10.
- **Lagging:** All workflows activate correctly on first PR.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer (workflow YAML — owner-only territory per file ownership matrix, but developer drafts)
- **Reviewer:** architect + human (workflow YAML is human gate)
- **Tester:** tester (workflow-syntax check via `gh workflow list`)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E6 — GitHub Workflows
- **Wave:** Wave 3 (Day 7-9)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
