# STORY-S21-004

> **PM-regenerated from GitHub issue #651** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/651
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **`audit-project-refs.sh` to catch hardcoded "AtilCalculator" / "atilcan65" refs**, so that **I can validate the template renders cleanly**.

## Why now

Without this, hardcoded refs leak through. The audit script is the regression guard.

## Acceptance Criteria

- **AC1** — GIVEN audit script WHEN run on pre-init clone THEN exits 1 (catches `AtilCalculator` or `atilcan65` in tracked files).
- **AC2** — GIVEN audit script WHEN run on post-init clone THEN exits 0 (no hardcoded refs).
- **AC3** — GIVEN audit script WHEN run in CI on a template PR THEN blocks merge if exit 1.

## Out of scope

- Catching `atilcalc-architect-td012` (machine-specific dir), checking binary files.

## Dependencies

- **Upstream:** S21-003.
- **Downstream:** S21-022 (smoke test uses this), S21-023 (validation uses this).

## Metrics of success

- **Leading:** Audit script exits 1 on pre-init fixture dir, 0 on post-init.
- **Lagging:** CI gates merge on template PRs.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens)
- **Tester:** tester (d070 covers this)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E2 — Parameterization & Init Script
- **Wave:** Wave 2 (Day 4-6)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
