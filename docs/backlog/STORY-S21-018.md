# STORY-S21-018

> **PM-regenerated from GitHub issue #637** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/637
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **a d-test for the template itself**, so that **template changes don't break clones**.

## Why now

Without d070, template PRs can break clones without CI catching it.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user runs `bash scripts/tests/d070-template-render.sh` THEN it validates `dev-studio-init.sh` on a fixture dir.
- **AC2** — GIVEN d070 WHEN run THEN it covers: happy path (placeholder resolved), idempotency (rerun is no-op), missing placeholder (fails), broken `.tmpl` syntax (fails).
- **AC3** — GIVEN d070 WHEN run THEN it completes in < 30 seconds (no network calls).

## Out of scope

- Network-based validation (real clone), d071+ future tests.

## Dependencies

- **Upstream:** S21-003, S21-005.
- **Downstream:** S21-022 (smoke test shares fixtures), S21-023 (validation uses this).

## Metrics of success

- **Leading:** d070 exits 0 on fixture dir.
- **Lagging:** All 4 sub-tests (happy/idempotent/missing/broken) covered.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (d-test framework per ADR-0049)
- **Tester:** tester (sign-off per ADR-0044)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E9 — d-test Family
- **Wave:** Wave 2 (Day 4-6, gates S21-003)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
