# STORY-S21-001

> **PM-regenerated from GitHub issue #630** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z; labels re-synced cycle ~#1231 per Issue #113 PM label-authority)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/630
> **State:** open
> **Labels (cycle ~#1231 re-sync, GitHub ground truth post-PR #667 squash):** type:feature, status:**done**, agent:**developer**, cc:architect, cc:developer, cc:tester

> **Sprint 21 sizing** (cycle ~#1213 ratification): Wave 1 PM-tracked, **2sp** (4-of-4 stamps per ADR-0021: PM=2, arch=S=1, dev=1, tester=0 → consensus 2sp per arch-dev Δ+1 concurrence).

---

## User Story

As a **solo developer / founder (P1)**, I want **the template repo to have `is_template=true`**, so that **GitHub UI shows "Use this template" button and `gh repo create --template` works**.

## Why now

Without this flag, no one can clone from template. This is the FIRST blocker for all downstream template usage. Without template flag, S21-002..S25 are unreachable for end users.

## Acceptance Criteria

- **AC1** — GIVEN a fresh template repo WHEN owner runs `gh api -X PATCH repos/<owner>/dev-studio-template -f is_template=true` THEN exit code 0 AND `is_template: true` in repo metadata.
- **AC2** — GIVEN template flag set WHEN user visits repo homepage on github.com THEN "Use this template" green button is visible.
- **AC3** — GIVEN template flag set WHEN user runs `gh repo create test-clone --template <owner>/dev-studio-template --clone` THEN new repo is created with template contents.

## Out of scope

- Custom template description, social preview image (deferred to Sprint 22+).
- Multiple template variants (Sprint 23+ candidate).

## Open questions

- [x] Template repo name (Q2) — **owner-ratified: `multi-agent-dev-studio-template`** ✅
- [x] Visibility default (Q3) — **owner-ratified: `--public` per ADR-0016** ✅

## Dependencies

- **Upstream:** none.
- **Downstream:** All other Sprint 21 stories depend on template flag being set.

## Metrics of success

- **Leading:** `gh api repos/<owner>/multi-agent-dev-studio-template | jq .is_template` returns `true` within 24h of story merge.
- **Lagging:** First external clone via `--template` flag succeeds (S21-023 captures this).

## Sizing

- **Hint:** 1 point (config change).
- **Final size:** 2sp (4-of-4 stamps captured cycle ~1169; ratifier cycle ~1189 by @atilcan65).

## Lane

- **Author:** developer (config change)
- **Reviewer:** architect (9-Lens per ADR-0045)
- **Tester:** developer-self (config verification)
- **PM:** @product-manager (story author)

## Sprint 21 Context

- **Epic:** E1 — Template Repository Structure
- **Wave:** Wave 1 (Day 1-3, foundation)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)