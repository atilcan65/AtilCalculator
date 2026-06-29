# STORY-S21-008

> **PM-regenerated from GitHub issue #632** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z; labels re-synced cycle ~#1231 per Issue #113 PM label-authority)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/632
> **State:** **closed** (issue closed terminal — squash-merged via PR #668 cycle ~#1190; CLAUDE.md on main ≥80% line coverage)
> **Labels (cycle ~#1231 re-sync, GitHub ground truth post-PR #668 squash):** type:docs, status:**done**, agent:**developer**, cc:architect, cc:developer, cc:tester

> **Sprint 21 sizing** (cycle ~#1213 ratification): Wave 1 PM-tracked, **3sp** (per arch ↑ AC4 ≥80% line coverage of current AtilCalculator CLAUDE.md: PM=2, arch=L=3, dev=2, tester=0 → consensus 3sp).

---

## User Story

As a **solo developer / founder (P1)**, I want **`CLAUDE.md` at repo root with full doctrine**, so that **Claude Code auto-loads it on every agent wake**.

## Why now

CLAUDE.md is auto-loaded by Claude Code. Missing it = agents have no doctrine context.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects root THEN `CLAUDE.md` exists, ≥ 200 lines, covers: Product, Team, Process, Tech stack, DoD, Communication, Auto-Ping Hard-Rule, Autonomy Loop, Required Label Set, Handoff Discipline, Things agents must NEVER do, File ownership matrix.
- **AC2** — GIVEN `CLAUDE.md` WHEN user reads THEN it references `docs/decisions/` for ADRs.
- **AC3** — GIVEN `CLAUDE.md` WHEN init script runs THEN placeholders resolved (`{{HUMAN_OWNER_NAME}}`, `{{GITHUB_OWNER}}/{{GITHUB_REPO}}`).
- **AC4** — GIVEN `CLAUDE.md` WHEN line coverage measured THEN ≥ 80% of current AtilCalculator `CLAUDE.md` content preserved (arch L=3 ↑ from XL=5 per ≥80% coverage requirement).

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
- **Final size:** 3sp (4-of-4 stamps captured cycle ~1169; shipped impl PR #668 + d075 PR #669).

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