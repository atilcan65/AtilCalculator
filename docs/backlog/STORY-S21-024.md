# STORY-S21-024

> **PM-regenerated from GitHub issue #650** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/650
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **template maintainer (P2)**, I want **a template-version pin (`.template-version`)**, so that **clones can detect upstream drift**.

## Why now

Without versioning, clones silently drift from template.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects root THEN `.template-version` exists with semver (e.g., `1.0.0`).
- **AC2** — GIVEN init script WHEN run THEN it writes the version into `.claude/agents/<role>.md` headers.
- **AC3** — GIVEN `agent-doctor.sh <role>` WHEN run THEN it reports `template-version: <installed>` vs `<latest>`.

## Out of scope

- Auto-upgrade, drift alerting.

## Dependencies

- **Upstream:** none.
- **Downstream:** S21-007 (soul files reference version), S21-025 (CHANGELOG entry).

## Metrics of success

- **Leading:** `.template-version` exists with semver.
- **Lagging:** `agent-doctor.sh` reports version correctly (Sprint 22+ validation).

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (versioning strategy)
- **Tester:** tester (semver + agent-doctor integration)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E12 — Template Versioning & Distribution
- **Wave:** Wave 4 (Day 10-12)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
