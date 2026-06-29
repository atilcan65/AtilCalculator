# STORY-S21-013

> **PM-regenerated from GitHub issue #644** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/644
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all 6 issue templates in `.github/ISSUE_TEMPLATE/`**, so that **contributors see the right form on new issue**.

## Why now

Issue templates set contributor expectations. Without them, contributors write free-form issues that miss 4-cat labels.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `.github/ISSUE_TEMPLATE/` THEN all 6 present: vision-intake.yml, bug.yml, feature-request.yml, incident.yml, agent-stall.yml, config.yml.
- **AC2** — GIVEN issue templates WHEN user opens new issue THEN template auto-applies 4-cat labels on submission (per ADR-0012).
- **AC3** — GIVEN `agent-stall.yml` WHEN user reads THEN body references `agent-doctor.sh`.

## Out of scope

- Custom templates per project.

## Dependencies

- **Upstream:** none.
- **Downstream:** All future issue creation flow.

## Metrics of success

- **Leading:** `ls .github/ISSUE_TEMPLATE/*.yml | wc -l` returns 6.
- **Lagging:** First external contributor successfully files a 4-cat-labeled issue via template.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer (template YAML)
- **Reviewer:** architect + human (workflow YAML is human gate per file ownership matrix)
- **Tester:** tester (template syntax check)
- **PM:** @product-manager (content co-author for PM-lane templates: vision-intake, feature-request)

## Sprint 21 Context

- **Epic:** E7 — Issue & PR Templates
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
