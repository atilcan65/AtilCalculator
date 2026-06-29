# STORY-S21-020

> **PM-regenerated from GitHub issue #652** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/652
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **a 10-minute owner onboarding guide**, so that **I can run first standup without reading 10 docs**.

## Why now

Without ONBOARDING.md, first-time users are lost. This is THE adoption blocker.

## Acceptance Criteria

- **AC1** — GIVEN `ONBOARDING.md` WHEN user follows steps 1-10 THEN each step ≤ 1 min, total ≤ 10 min.
- **AC2** — GIVEN `ONBOARDING.md` WHEN user reads THEN each step has expected output ("you should see X").
- **AC3** — GIVEN `ONBOARDING.md` WHEN PM simulates with fresh fixture dir THEN walks through all 10 steps successfully, captures actual time.

## Out of scope

- Video walkthrough, GUI installer.

## Dependencies

- **Upstream:** S21-001, S21-002, S21-003 (template is functional).
- **Downstream:** All user adoption metrics.

## Metrics of success

- **Leading:** `ONBOARDING.md` has 10 numbered steps.
- **Lagging:** PM-validated walkthrough completes in ≤ 10 min on fresh fixture dir.

## Sizing

- **Hint:** 5 points (large: external validation required).
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** PM (PM-authored documentation, validates via S21-023 fresh-clone walkthrough)
- **Reviewer:** developer (step accuracy) + human (final approval)
- **Tester:** PM (PM-self-test per AC3, capture time in S21-023 close.md)
- **PM:** @product-manager (primary author)

## Sprint 21 Context

- **Epic:** E10 — Documentation
- **Wave:** Wave 5 (Day 13-14, final validation sprint)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
