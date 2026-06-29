# STORY-S21-017

> **PM-regenerated from GitHub issue #647** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/647
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all 40+ d-tests in `scripts/tests/`**, so that **agent runtime is verifiable on fresh clone**.

## Why now

d-tests are the regression guard. Missing any one = silent runtime failure.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `scripts/tests/` THEN all 40+ d-tests present.
- **AC2** — GIVEN d-tests WHEN user runs `bash scripts/tests/run-all.sh` THEN all exit 0 on fresh clone post-init.
- **AC3** — GIVEN run-all.sh WHEN read THEN it runs d-tests in dependency order (alphabetical or topological).

## Out of scope

- Per-project custom d-tests.

## Dependencies

- **Upstream:** S21-018 (d070-template-render must pass first).
- **Downstream:** S21-023 (fresh-clone validation runs all d-tests).

## Metrics of success

- **Leading:** `ls scripts/tests/d*.sh | wc -l` returns ≥ 40.
- **Lagging:** `run-all.sh` exits 0 on fresh clone.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (d-test framework consistency per ADR-0049)
- **Tester:** tester (sign-off lane per ADR-0044)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E9 — d-test Family
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
