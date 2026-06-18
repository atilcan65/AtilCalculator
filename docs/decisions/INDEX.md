# Architecture Decision Records — Index

This index lists every ADR the team has produced. ADRs are immutable once
`Accepted`; superseding decisions live in a new ADR that references the old
one in its `Supersedes` field.

| ID | Title | Status | Date | Deciders | Related |
|----|-------|--------|------|----------|---------|
| [ADR-0010](./ADR-0010-per-project-watchers.md) | Per-Project Systemd Watchers | Accepted | 2026-06-14 | atil can | Supersedes ADR-0006 (instance topology); related to ADR-0002, ADR-0003 |
| [ADR-0011](./ADR-0011-watcher-dropin-override.md) | Watcher Per-Instance Config via Drop-In Override | Accepted | 2026-06-14 | atil can | Refines ADR-0010 (implementation detail of per-instance config) |
| [ADR-0012](./ADR-0012-required-label-set.md) | Required Label Set on Issue/PR Creation | Accepted | 2026-06-14 | atil can | Related to ADR-0002, ADR-0007, ADR-0009; sister of ADR-0013 |
| [ADR-0013](./ADR-0013-status-label-to-board-sync.md) | Sync `status:*` Labels to Projects v2 Board | Accepted (auth superseded by ADR-0014) | 2026-06-14 | atil can | Related to ADR-0007; sister of ADR-0012 |
| [ADR-0014](./ADR-0014-project-token-secret.md) | PROJECT_TOKEN repo secret for board sync workflow | Accepted | 2026-06-14 | atil can | Supersedes ADR-0013 auth section; related to ADR-0013 |
| [ADR-0015](./ADR-0015-atomic-agent-handoff.md) | Atomic Agent Hand-off (preserve 4-cat invariant) | Accepted | 2026-06-14 | atil can | Refines ADR-0009 cc-flip; ensures ADR-0012 invariant during agent transitions |
| [ADR-0016](./ADR-0016-public-by-default.md) | Public-by-default for bootstrapped projects | Accepted | 2026-06-17 | atil can | Related to ADR-0014 (PROJECT_TOKEN canary quota interaction) |
| [ADR-0017](./ADR-0017-tech-stack.md) | Tech stack for AtilCalculator (Python 3.11 + pytest + Typer; pure-engine + thin-wrapper) | Accepted | 2026-06-17 | atil can | First product-level ADR; sister to bootstrap ADRs 0010, 0012, 0014, 0016. Accepted via PR #5 (commit 30c93f4). Amended via PR #66 (runtime vs dev dependency classification). |
| [ADR-0018](./ADR-0018-front-end-framework.md) | Front-end framework for MVP-1 web shell (vanilla JS + Web Components, no build step) | Accepted | 2026-06-17 | atil can | Implements Sprint 1 STORY-004; depends on ADR-0017 + vision §M3 (keyboard-only) + §M4 (skin swap <500ms). Accepted via PR #13 (commit 8a1fd89). §Open questions resolved by ADR-0023. |
| [ADR-0019](./ADR-0019-api-contract.md) | HTTP API contract for the engine wrapper (FastAPI surface) | Accepted (amended via PR #63 + PR #84) | 2026-06-17 | @architect, @pm, @dev, @tester | Sprint 1 R-3 (API contract); the boundary the entire product stands on. Accepted via PR #33; amended §Decimal trailing-zero + §Exception taxonomy via PR #63; amended §mpmath transcendentals + §factorial cap + §DomainError + §GET /api/history envelope via PR #84. |
| [ADR-0020](./ADR-0020-label-mutation-transactionality.md) | Label-Mutation Transactionality (atomic CLI wrapper + CI gate) | Accepted | 2026-06-18 | @architect, @orchestrator, @dev, @tester | Closes TD-004 + TD-006 + TD-008 family. Accepted via PR #62. |
| [ADR-0021](./ADR-0021-docs-pr-convention.md) | Docs PR Convention (default `agent:<author>` only; peer `cc:*` requires cross-cutting rationale) | Accepted | 2026-06-18 | @architect, @orchestrator, @dev, @tester | Closes TD-006 subclass on docs PRs. Sister to ADR-0020. Accepted via PR #62. |
| [ADR-0022](./ADR-0022-persistence-layer.md) | Persistence layer (SQLite file backend + shared-volume cross-device sync) | Accepted | 2026-06-18 | @architect, @pm, @dev, @tester | Sprint 2 P1 R-5. STORY-007 + STORY-010 backend. Depends on ADR-0019 §Idempotency + §Decimal serialization. Accepted via PR #82. |
| [ADR-0023](./ADR-0023-frontend-architecture.md) | Frontend architecture: theming model, skin system, Web Component contracts | Accepted | 2026-06-18 | @architect, @pm, @dev, @tester | Sprint 2 P1 R-2. STORY-009 + STORY-010 frontend. Supersedes ADR-0018 §Open questions. Accepted via PR #83. |

## Conventions

- **Path**: `docs/decisions/ADR-NNNN-<slug>.md`
- **ID**: monotonically increasing, zero-padded to 4 digits
- **Slug**: kebab-case, short, filename-safe
- **Status lifecycle**: Proposed → Accepted → (optionally) Superseded by ADR-MMMM
- **Header**: every ADR starts with `# ADR-NNNN: <title>` followed by a YAML-style frontmatter block (Status, Date, Deciders, Supersedes, Related)

## Pending proposals

_None at this time. Sprint 2 P1 architect pre-work (Issue #80) is complete — 3 ADRs accepted (PRs #82, #83, #84). Next ADR work will be Sprint 2 P2 backlog items (TBD at Sprint 2 mid-sprint planning)._
