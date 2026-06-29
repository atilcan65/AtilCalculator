# STORY-S21-002

> **PM-regenerated from GitHub issue #631** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z; labels re-synced cycle ~#1231 per Issue #113 PM label-authority)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/631
> **State:** **closed** (issue closed terminal — squash-merged via PR #661 mid-Sprint 21 cycle ~#1190)
> **Labels (cycle ~#1231 re-sync, GitHub ground truth):** type:feature, status:in-progress

> **Sprint 21 sizing** (cycle ~#1213 ratification): Wave 1 PM-tracked, **1sp** (4-of-4 triple concurrence per ADR-0021: PM=1, arch=S=1, dev=1, tester=1).

---

## User Story

As a **solo developer / founder (P1)**, I want **a `LICENSE` file with explicit license**, so that **license is unambiguous for users and contributors**.

## Why now

License is the #1 thing open-source users check. Missing license = all-rights-reserved by default, blocks adoption.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN owner opens `LICENSE` at root THEN file contains full MIT (or chosen) license text with copyright line parameterized as `Copyright (c) {{YEAR}} {{HUMAN_OWNER_NAME}}`.
- **AC2** — GIVEN template repo WHEN GitHub UI loads THEN repo sidebar shows license name (e.g., "MIT License").
- **AC3** — GIVEN `TEMPLATE-README.md` WHEN user reads THEN a "License" section references the LICENSE file.

## Out of scope

- Dual-license, contributor license agreement (CLA), per-file license headers.

## Open questions

- [x] License choice (Q1) — **owner-ratified: MIT** ✅

## Dependencies

- **Upstream:** none.
- **Downstream:** S21-019 (README references LICENSE).

## Metrics of success

- **Leading:** GitHub UI sidebar shows license name within 24h of merge.
- **Lagging:** First external user can `git clone` without license warnings.

## Sizing

- **Hint:** 1 point.
- **Final size:** 1sp (4-of-4 triple concurrence; shipped impl PR #661 + d074 PR #657; d079 .tmpl param coverage).

## Lane

- **Author:** developer
- **Reviewer:** architect (license-text correctness)
- **Tester:** developer-self
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E1 — Template Repository Structure
- **Wave:** Wave 1 (Day 1-3, foundation)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)