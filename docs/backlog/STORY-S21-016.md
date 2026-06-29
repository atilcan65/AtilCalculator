# STORY-S21-016

> **PM-regenerated from GitHub issue #634** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/634
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **an ADR documenting template architecture decisions**, so that **future contributors understand the parameterization strategy**.

## Why now

Without ADR-0001, contributors don't know why placeholders are used over build-time codegen.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user reads `docs/decisions/ADR-0001-template-architecture.md` THEN it covers: single-repo vs monorepo (decision: single repo), parameterization strategy (decision: placeholders + init script), secrets strategy (decision: per-project init prompt), distribution strategy (decision: gh template).
- **AC2** — GIVEN ADR-0001 WHEN user searches THEN it is referenced from `TEMPLATE-README.md` and `CLAUDE.md`.
- **AC3** — GIVEN ADR-0001 WHEN read THEN it cross-references: ADR-0016 (public-by-default), ADR-0014 (PROJECT_TOKEN), ADR-0012 (label invariant).

## Out of scope

- Multi-template architecture, per-project ADR selection.

## Dependencies

- **Upstream:** none.
- **Downstream:** S21-015 (ADR library depends on this), all parameterization decisions trace back to this ADR.

## Metrics of success

- **Leading:** `docs/decisions/ADR-0001-template-architecture.md` exists, ≥ 200 lines.
- **Lagging:** New contributors cite ADR-0001 when proposing parameterization changes.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** architect (ADR is architect territory per file ownership matrix)
- **Reviewer:** PM (acceptance criteria test plan) + human (ADR approval gate)
- **Tester:** architect-self (9-Lens coverage per ADR-0045)
- **PM:** @product-manager (story author, AC alignment)

## Sprint 21 Context

- **Epic:** E8 — ADRs
- **Wave:** Wave 2 (Day 4-6, foundational ADR)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
