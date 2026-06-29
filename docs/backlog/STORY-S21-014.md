# STORY-S21-014

> **PM-regenerated from GitHub issue #645** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/645
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **a PR template**, so that **PRs follow the doctrine convention**.

## Why now

PR template is the doctrine checkpoint. Without it, PRs miss doctrine-impact section.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `.github/` THEN `PULL_REQUEST_TEMPLATE.md` exists with sections: Summary, Doctrine impact, ADR cross-ref, Test plan, Owner checklist.
- **AC2** — GIVEN PR template WHEN user reads THEN it is referenced from `CONTRIBUTING.md`.
- **AC3** — GIVEN PR template WHEN user fills "docs only" checkbox THEN CI labeler auto-applies `type:docs` (per ADR-0012 label invariant).

## Out of scope

- Per-PR-type templates (template has one canonical).

## Dependencies

- **Upstream:** S21-021 (CONTRIBUTING.md references).
- **Downstream:** All future PR creation flow.

## Metrics of success

- **Leading:** `PULL_REQUEST_TEMPLATE.md` exists at `.github/` root with all 5 sections.
- **Lagging:** First external PR follows template structure.

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (doctrine-impact section quality)
- **Tester:** developer-self (markdown lint)
- **PM:** @product-manager (acceptance-criteria test plan section co-author)

## Sprint 21 Context

- **Epic:** E7 — Issue & PR Templates
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
