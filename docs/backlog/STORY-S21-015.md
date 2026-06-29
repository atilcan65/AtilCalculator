# STORY-S21-015

> **PM-regenerated from GitHub issue #646** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/646
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all 60+ ADRs committed**, so that **doctrine is discoverable**.

## Why now

ADRs are the architectural memory. Without them, new agents have no context.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user reads `docs/decisions/INDEX.md` THEN all 60+ ADRs listed with one-line summary each.
- **AC2** — GIVEN all ADRs WHEN inspected THEN all follow template (Context, Decision, Consequences, Alternatives).
- **AC3** — GIVEN init script WHEN run THEN ADRs are NOT modified (doctrine is project-agnostic).

## Out of scope

- Per-project custom ADRs (template ships canonical set).

## Dependencies

- **Upstream:** S21-016 (ADR-0001 template-architecture).
- **Downstream:** New agents wake with full ADR context.

## Metrics of success

- **Leading:** `ls docs/decisions/ADR-*.md | wc -l` returns ≥ 60.
- **Lagging:** First agent wake on fresh clone has full doctrine context.

## Sizing

- **Hint:** 1 point (verification).
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer (verification only)
- **Reviewer:** architect (doctrine completeness check)
- **Tester:** tester (INDEX.md consistency check)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E8 — ADRs
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
