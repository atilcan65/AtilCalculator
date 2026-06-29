# STORY-S21-002

> **PM-regenerated from GitHub issue #631** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/631
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260965004,"node_id":"LA_kwDOS9WE8s8AAAACnzSwjA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:in-progress","name":"status:in-progress","color":"fbca04","default":false,"description":"Currently being worked on"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260966925,"node_id":"LA_kwDOS9WE8s8AAAACnzS4DQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:developer","name":"cc:developer","color":"bfdadc","default":false,"description":"Review/awareness from Developer"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **a `LICENSE` file with explicit license**, so that **license is unambiguous for users and contributors**.

## Why now

License is the #1 thing open-source users check. Missing license = all-rights-reserved by default, blocks adoption.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN owner opens `LICENSE` at root THEN file contains full MIT (or chosen) license text with copyright line parameterized as `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}`.
- **AC2** — GIVEN template repo WHEN GitHub UI loads THEN repo sidebar shows license name (e.g., "MIT License").
- **AC3** — GIVEN `TEMPLATE-README.md` WHEN user reads THEN a "License" section references the LICENSE file.

## Out of scope

- Dual-license, contributor license agreement (CLA), per-file license headers.

## Open questions

- [x] License choice (Q1) — **owner-ratified: MIT** ✅

## Dependencies

- **Upstream:** none.
- **Downstream:** S21-019 (README references LICENSE).

## Metrics of success

- **Leading:** GitHub UI sidebar shows license name within 24h of merge.
- **Lagging:** First external user can `git clone` without license warnings.

## Sizing

- **Hint:** 1 point.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (license-text correctness)
- **Tester:** developer-self
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E1 — Template Repository Structure
- **Wave:** Wave 1 (Day 1-3, foundation)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
