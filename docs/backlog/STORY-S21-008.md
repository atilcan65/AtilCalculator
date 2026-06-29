# STORY-S21-008

> **PM-regenerated from GitHub issue #632** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/632
> **State:** open
> **Labels:** [{"id":11260964122,"node_id":"LA_kwDOS9WE8s8AAAACnzStGg","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:docs","name":"type:docs","color":"0075ca","default":false,"description":"Documentation"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **`CLAUDE.md` at repo root with full doctrine**, so that **Claude Code auto-loads it on every agent wake**.

## Why now

CLAUDE.md is auto-loaded by Claude Code. Missing it = agents have no doctrine context.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects root THEN `CLAUDE.md` exists, ≥ 200 lines, covers: Product, Team, Process, Tech stack, DoD, Communication, Auto-Ping Hard-Rule, Autonomy Loop, Required Label Set, Handoff Discipline, Things agents must NEVER do, File ownership matrix.
- **AC2** — GIVEN `CLAUDE.md` WHEN user reads THEN it references `docs/decisions/` for ADRs.
- **AC3** — GIVEN `CLAUDE.md` WHEN init script runs THEN placeholders resolved (`{{HUMAN_OWNER_NAME}}`, `{{GITHUB_OWNER}}/{{GITHUB_REPO}}`).

## Out of scope

- Per-agent CLAUDE.md (template has one root CLAUDE.md).

## Dependencies

- **Upstream:** S21-005.
- **Downstream:** All agent soul files (CLAUDE.md is their doctrine source).

## Metrics of success

- **Leading:** `wc -l CLAUDE.md` returns ≥ 200.
- **Lagging:** First agent wake on fresh clone has full doctrine context.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer (with PM review on doctrine content)
- **Reviewer:** architect (9-Lens) + human (CLAUDE.md is human-only territory per file ownership matrix — developer drafts, human approves)
- **Tester:** developer-self (markdown lint)
- **PM:** @product-manager (doctrine content co-author)

## Sprint 21 Context

- **Epic:** E4 — CLAUDE.md
- **Wave:** Wave 1 (Day 1-3, foundation) — CLAUDE.md is foundation, blocks all soul file correctness

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
