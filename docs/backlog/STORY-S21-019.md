# STORY-S21-019

> **PM-regenerated from GitHub issue #633** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/633
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **`TEMPLATE-README.md` polished with badges and links**, so that **first impression is professional**.

## Why now

README is the first thing users see. Polish = trust signal.

## Acceptance Criteria

- **AC1** — GIVEN `TEMPLATE-README.md` WHEN user reads THEN badges present: CI status, license, template-version.
- **AC2** — GIVEN `TEMPLATE-README.md` WHEN user reads THEN all 5 agents named, all 5 workflows listed.
- **AC3** — GIVEN `TEMPLATE-README.md` WHEN user reads THEN links to: ONBOARDING.md, TELEGRAM-SETUP.md, CONTEXT-HYGIENE.md, ADR-INDEX.md.

## Out of scope

- GIF/animated demo, video walkthrough.

## Dependencies

- **Upstream:** S21-020 (ONBOARDING.md exists).
- **Downstream:** First impression for new users.

## Metrics of success

- **Leading:** `TEMPLATE-README.md` ≥ 100 lines, all 3 badges present.
- **Lagging:** First external user cites README as helpful.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** PM (PM-authored documentation)
- **Reviewer:** developer (markdown lint) + human (final approval)
- **Tester:** developer-self
- **PM:** @product-manager (primary author)

## Sprint 21 Context

- **Epic:** E10 — Documentation
- **Wave:** Wave 1 (Day 1-3, foundation — first impression)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
