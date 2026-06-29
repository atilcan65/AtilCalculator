# STORY-S21-025

> **PM-regenerated from GitHub issue #654** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/654
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **template maintainer (P2)**, I want **`CHANGELOG.md` for the template**, so that **doctrine updates are traceable**.

## Why now

Without CHANGELOG, contributors don't know what changed between versions.

## Acceptance Criteria

- **AC1** — GIVEN `CHANGELOG.md` WHEN user reads THEN it follows Keep-a-Changelog format.
- **AC2** — GIVEN `CHANGELOG.md` WHEN user reads THEN each entry: version, date, added/changed/deprecated/removed/fixed/security.
- **AC3** — GIVEN `CHANGELOG.md` WHEN read THEN latest entry matches `.template-version` (e.g., `## [1.0.0] - 2026-06-29`).

## Out of scope

- Auto-generation from PRs, release notes.

## Dependencies

- **Upstream:** S21-024 (version pin).
- **Downstream:** Sprint 22+ adoption metrics.

## Metrics of success

- **Leading:** `CHANGELOG.md` follows Keep-a-Changelog, latest entry matches version.
- **Lagging:** External contributors reference CHANGELOG before upgrading.

## Sizing

- **Hint:** 1 point.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** PM (PM-authored CHANGELOG for Sprint 21 close-out)
- **Reviewer:** developer (Keep-a-Changelog format check)
- **Tester:** developer-self (markdown lint)
- **PM:** @product-manager (primary author)

## Sprint 21 Context

- **Epic:** E12 — Template Versioning & Distribution
- **Wave:** Wave 5 (Day 13-14, sprint close-out)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
