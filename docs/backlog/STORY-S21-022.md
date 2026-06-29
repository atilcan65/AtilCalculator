# STORY-S21-022

> **PM-regenerated from GitHub issue #649** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/649
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **a smoke-test script that runs on every PR**, so that **template changes can't break clones**.

## Why now

Without smoke test in CI, template PRs can ship broken.

## Acceptance Criteria

- **AC1** — GIVEN `scripts/tests/faz5-smoke.sh` WHEN run THEN it covers: dry-run (no init), broken-tmpl (init fails), idempotency (rerun OK), fresh-clone (full init), manual-edit (init rerender preserves manual edits).
- **AC2** — GIVEN smoke test WHEN run in `.github/workflows/ci.yml` THEN triggers on template-repo PRs.
- **AC3** — GIVEN smoke test WHEN run THEN exit code gates merge (CI red = no merge).

## Out of scope

- Network-based smoke (real GitHub clone).

## Dependencies

- **Upstream:** S21-018 (d070-template-render shares fixtures).
- **Downstream:** S21-023 (fresh-clone validation).

## Metrics of success

- **Leading:** `scripts/tests/faz5-smoke.sh` covers all 5 sub-scenarios.
- **Lagging:** CI red gates merge on template PRs.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (CI integration per ADR-0012 label invariant)
- **Tester:** tester (sign-off per ADR-0044)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E11 — Validation & Smoke Tests
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
