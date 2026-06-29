# STORY-S21-009

> **PM-regenerated from GitHub issue #640** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/640
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **solo developer / founder (P1)**, I want **all 25+ scripts in the template**, so that **all operational tools work out of the box**.

## Why now

Scripts are the operational backbone. Missing any one = operational gap.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `scripts/` THEN all 25+ scripts present: notify, peer-poke, agent-watch, agent-state, claim-next-ready, ping, codex-runner, dev-studio-init, dev-studio-start, bootstrap-labels, bootstrap-project-board, health-check, agent-doctor, agent-journal, reprime-agent, lint-notify-invocations, post-restart-label-guard, orchestrator-gap-scan, proactive-board-scan, strip-cascade-labels, cross-repo-close, cross-repo-scan, event-log, atomic-write, wip-idle-detect.
- **AC2** — GIVEN all scripts WHEN audited THEN all have `set -euo pipefail` and a top-of-file usage comment.
- **AC3** — GIVEN `scripts/README.md` WHEN user reads THEN all scripts listed with one-line purpose.

## Out of scope

- Per-project custom scripts (template ships canonical set).

## Dependencies

- **Upstream:** S21-005.
- **Downstream:** S21-010 (parameterization).

## Metrics of success

- **Leading:** `ls scripts/*.sh | wc -l` returns ≥ 25.
- **Lagging:** All scripts functional on fresh clone.

## Sizing

- **Hint:** 3 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens)
- **Tester:** tester (script-syntax + lint coverage)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E5 — Scripts Library
- **Wave:** Wave 3 (Day 7-9)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
