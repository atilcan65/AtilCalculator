# STORY-S21-023

> **PM-regenerated from GitHub issue #653** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/653
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **template maintainer (P2)**, I want **≥ 2 fresh-clone validations**, so that **the template is proven to work end-to-end**.

## Why now

Without external validation, template may work for AtilCalculator but fail for first-time user.

## Acceptance Criteria

- **AC1** — GIVEN PM runs `bash scripts/dev-studio-init.sh` on a copy of AtilCalculator THEN all d-tests pass.
- **AC2** — GIVEN PM creates throwaway test repo (`atilcan65/dev-studio-template-smoke`) AND runs init THEN all d-tests pass.
- **AC3** — GIVEN both clones WHEN PM captures d-test reports THEN both attached to Sprint 21 close.md.

## Out of scope

- Production-usage clones, third-party clones (Sprint 22+ adoption metric).

## Dependencies

- **Upstream:** S21-017, S21-018.
- **Downstream:** Sprint 21 close.md evidence.

## Metrics of success

- **Leading:** All d-tests pass on 2 separate clones.
- **Lagging:** d-test reports attached to close.md, ready for Sprint 22+ adoption.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** PM (PM performs the validation per AC1+AC2)
- **Reviewer:** tester (sign-off on d-test reports)
- **Tester:** tester (validates PM's reports)
- **PM:** @product-manager (primary author + validator)

## Sprint 21 Context

- **Epic:** E11 — Validation & Smoke Tests
- **Wave:** Wave 5 (Day 13-14, final validation)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
