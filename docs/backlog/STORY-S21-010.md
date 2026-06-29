# STORY-S21-010

> **PM-regenerated from GitHub issue #642** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/642
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all scripts parameterized for project**, so that **hardcoded paths break on clone**.

## Why now

Without parameterization, scripts reference AtilCalculator paths in a different project.

## Acceptance Criteria

- **AC1** — GIVEN audit script (S21-004) WHEN run on template THEN 0 hardcoded `AtilCalculator` or `atilcan65` refs in `scripts/`.
- **AC2** — GIVEN scripts WHEN inspected THEN they use `$(gh repo view --json name -q .name)` or env vars (`${GITHUB_REPO}`) instead of hardcoded names.
- **AC3** — GIVEN init script WHEN run THEN `~/.dev-studio-env` template is generated per-project with `GITHUB_OWNER`, `GITHUB_REPO`, `HUMAN_OWNER_NAME`.

## Out of scope

- Refactoring every script (only scripts with hardcoded refs touched).

## Dependencies

- **Upstream:** S21-009.
- **Downstream:** All scripts validated by S21-023 fresh-clone test.

## Metrics of success

- **Leading:** `audit-project-refs.sh scripts/` exits 0.
- **Lagging:** All scripts run cleanly on a non-AtilCalculator clone.

## Sizing

- **Hint:** 5 points (large: touches many scripts).
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens)
- **Tester:** tester (audit-script coverage)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E5 — Scripts Library
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
