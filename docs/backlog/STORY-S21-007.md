# STORY-S21-007

> **PM-regenerated from GitHub issue #639** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/639
> **State:** open
> **Labels:** [{"id":11260963624,"node_id":"LA_kwDOS9WE8s8AAAACnzSrKA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/type:feature","name":"type:feature","color":"a2eeef","default":false,"description":"New feature or capability"},{"id":11260964709,"node_id":"LA_kwDOS9WE8s8AAAACnzSvZQ","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/status:backlog","name":"status:backlog","color":"ededed","default":false,"description":"Not yet started, in backlog"},{"id":11260966204,"node_id":"LA_kwDOS9WE8s8AAAACnzS1PA","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/agent:tester","name":"agent:tester","color":"5319e7","default":false,"description":"Assigned to Tester agent"},{"id":11260967051,"node_id":"LA_kwDOS9WE8s8AAAACnzS4iw","url":"https://api.github.com/repos/atilcan65/AtilCalculator/labels/cc:tester","name":"cc:tester","color":"bfdadc","default":false,"description":"Review/awareness from Tester"}]

---

## User Story

As a **template maintainer (P2)**, I want **each soul file to carry a `template-version` header**, so that **clones can detect upstream drift**.

## Why now

Without versioning, clones silently drift from template. Versioning enables Sprint 22+ pull mechanism.

## Acceptance Criteria

- **AC1** — GIVEN template repo WHEN user inspects `.claude/agents/<role>.md` THEN header contains `<!-- template-version: {{TEMPLATE_VERSION}} -->`.
- **AC2** — GIVEN init script WHEN run THEN it writes the actual version from `.template-version` (not placeholder).
- **AC3** — GIVEN `agent-doctor.sh <role>` WHEN run THEN it reports `installed: <installed_version>` vs `latest: <latest_version>` (latest from upstream template fetch).

## Out of scope

- Auto-upgrade soul files, drift alerting.

## Dependencies

- **Upstream:** S21-024 (`.template-version` file exists).
- **Downstream:** Sprint 22+ template-pull mechanism.

## Metrics of success

- **Leading:** All 5 soul files have `template-version` header.
- **Lagging:** `agent-doctor.sh` reports drift correctly (Sprint 22+ validation).

## Sizing

- **Hint:** 2 points.
- **Final size:** TBD by arch+dev+tester joint sizing per ADR-0021.

## Lane

- **Author:** developer
- **Reviewer:** architect (9-Lens)
- **Tester:** tester (version-pinning test)
- **PM:** @product-manager

## Sprint 21 Context

- **Epic:** E3 — Agent Soul Files
- **Wave:** Wave 3 (Day 7-9)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
