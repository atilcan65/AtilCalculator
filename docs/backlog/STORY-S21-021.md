# STORY-S21-021

> **PM-regenerated from GitHub issue #648** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/648
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **a `CONTRIBUTING.md` for template improvements**, so that **contributors know the review process**.

## Why now

Without CONTRIBUTING.md, contributors don't know the doctrine-change review gate.

## Acceptance Criteria

- **AC1** — GIVEN `CONTRIBUTING.md` WHEN user reads THEN it covers: PR template, ADR requirement for doctrine changes, d-test requirement, owner approval gate.
- **AC2** — GIVEN `CONTRIBUTING.md` WHEN read THEN it references CODEOWNERS for review routing.
- **AC3** — GIVEN `CONTRIBUTING.md` WHEN read THEN it links to `docs/decisions/INDEX.md`.

## Out of scope

- Per-contributor CLA, code style guide.

## Dependencies

- **Upstream:** S21-014 (PR template exists).
- **Downstream:** External contributor onboarding.

## Metrics of success

- **Leading:** `CONTRIBUTING.md` ≥ 50 lines, all 4 AC1 topics covered.
- **Lagging:** First external contributor follows the gate.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** PM (PM-authored documentation)
- **Reviewer:** architect (doctrine-change review gate accuracy)
- **Tester:** developer-self (markdown lint)
- **PM:** @product-manager (primary author)

## Sprint 21 Context

- **Epic:** E10 — Documentation
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
