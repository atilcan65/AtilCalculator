# STORY-S21-005

> **PM-regenerated from GitHub issue #635** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/635
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **`.tmpl` source files alongside rendered outputs**, so that **template changes are diff-able and re-renderable**.

## Why now

Without `.tmpl` sources, every template change means editing rendered output, losing the source.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects THEN `README.md.tmpl`, `CLAUDE.md.tmpl`, `.claude/agents/orchestrator.md.tmpl`, etc. exist as source files.
- **AC2** — GIVEN init script WHEN run THEN it reads `.tmpl` and writes rendered output (e.g., `README.md.tmpl` → `README.md`).
- **AC3** — GIVEN two consecutive init runs on same clone WHEN diff compared THEN 0 differences (deterministic).

## Out of scope

- All files as `.tmpl` (only files with placeholders need it).

## Dependencies

- **Upstream:** none.
- **Downstream:** S21-003, S21-006, S21-008, S21-009, S21-011.

## Metrics of success

- **Leading:** `find . -name '*.tmpl' | wc -l` returns ≥ 20.
- **Lagging:** Init script renders all `.tmpl` files successfully.

## Sizing

- **Hint:** 3 points (touches ~20 files).
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens)
- **Tester:** tester (d070 covers this)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E2 — Parameterization & Init Script
- **Wave:** Wave 2 (Day 4-6)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
