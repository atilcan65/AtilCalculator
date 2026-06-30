# STORY-S21-020

> **PM-regenerated from GitHub issue #652** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z; labels re-synced cycle ~#1230 per Issue #113 PM label-authority)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/652
> **State:** open
> **Labels (cycle ~#1799 Sprint 23 PM claim, GitHub ground truth):** type:docs, status:in-progress, agent:product-manager, cc:developer, cc:human

> **Sprint 23 sizing** (cycle ~#1799 PM claim per orchestrator dual-channel wake + Issue #733 owner verdict Q2 ASAP start NOW): 6sp SPLIT (3+3) per cycle ~#1221 spec — S21-020a (write 10 steps, 3sp) + S21-020b (validate via S21-023 fresh-clone walkthrough, 3sp).
> **S21-020a cycle ~#1799 progress:** ONBOARDING.md drafted at `docs/product/ONBOARDING.md` (~210 lines, 10 numbered steps with expected outputs each ≤ 1 min, total ≤ 10 min). PR pending open.
> **S21-020b pending:** PM-validated walkthrough on fresh fixture dir (AC3).

---

## User Story

As a **solo developer / founder (P1)**, I want **a 10-minute owner onboarding guide**, so that **I can run first standup without reading 10 docs**.

## Why now

Without ONBOARDING.md, first-time users are lost. This is THE adoption blocker.

## Acceptance Criteria

- **AC1** — GIVEN `ONBOARDING.md` WHEN user follows steps 1-10 THEN each step ≤ 1 min, total ≤ 10 min.
- **AC2** — GIVEN `ONBOARDING.md` WHEN user reads THEN each step has expected output ("you should see X").
- **AC3** — GIVEN `ONBOARDING.md` WHEN PM simulates with fresh fixture dir THEN walks through all 10 steps successfully, captures actual time.

## Out of scope

- Video walkthrough, GUI installer.

## Dependencies

- **Upstream:** S21-001, S21-002, S21-003 (template is functional).
- **Downstream:** All user adoption metrics.

## Metrics of success

- **Leading:** `ONBOARDING.md` has 10 numbered steps.
- **Lagging:** PM-validated walkthrough completes in ≤ 10 min on fresh fixture dir.

## Sizing

- **Hint:** 5 points (large: external validation required).
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021 (deferred to next ceremony per Issue #685 decision E).
- **Cycle ~#1221 spec:** 6sp SPLIT (3+3) — S21-020a (placeholder path) + S21-020b (full validation).

## Lane

- **Author:** PM (PM-authored documentation, validates via S21-023 fresh-clone walkthrough)
- **Reviewer:** developer (step accuracy) + human (final approval)
- **Tester:** PM (PM-self-test per AC3, capture time in S21-023 close.md)
- **PM:** @product-manager (primary author)

## Sprint 21 Context

- **Epic:** E10 — Documentation
- **Wave:** Wave 5 (Day 13-14, final validation sprint)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)