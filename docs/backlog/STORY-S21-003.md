# STORY-S21-003 [⚠️ OBSOLETE — REPLACED BY S21-003a + S21-003b]

> **PM-regenerated from GitHub issue #636** (recovery from cross-worktree data loss at 2026-06-29T03:08:43Z; labels re-synced + OBSOLETE marker added cycle ~#1236 per RETRO-016 #6)
> **Issue:** https://github.com/atilcan65/AtilCalculator/issues/636
> **State:** ⚠️ **OBSOLETE — Story SPLIT into S21-003a + S21-003b** per arch §Size-negotiation cycle ~#1221 (Issue #693 sub-issue opened)
> **Labels (cycle ~#1236 re-sync, GitHub ground truth post-orchestrator board-hygiene cycle ~#1249):** type:feature, status:ready, agent:developer, cc:product-manager, cc:architect, cc:developer, cc:tester, cc:human

> **d-test-coupled marker** (RETRO-016 #6 codification, PM Dispatch Protocol v0.1 PR #700):
> - **S21-003** (this parent, OBSOLETE) → SPLIT into:
>   - **S21-003a** ([Issue #636](https://github.com/atilcan65/AtilCalculator/issues/636)) — agent:developer (impl), `d-test-coupled: NO` (impl story, default lane)
>   - **S21-003b** ([Issue #693](https://github.com/atilcan65/AtilCalculator/issues/693)) — agent:tester (kept by orchestrator cycle ~#1249), `d-test-coupled: YES — d070b` (sister-pattern d070a covers S21-003a + S21-003b in d-test, tester-led narrow scope per arch SPLIT 2sp)
> - **Pre-dispatch lint behavior** (per PM Dispatch Protocol v0.1):
>   - Issue #636 (S21-003a): `agent:developer` ✓, body has no `d-test-coupled` marker → impl lane CORRECT
>   - Issue #693 (S21-003b): `agent:tester` ✓, body has `d-test-coupled: YES — d070b` marker → d-test-coupled lane CORRECT

---

## Original Story (Pre-SPLIT context)

As a **solo developer / founder (P1)**, I want **`dev-studio-init.sh` to resolve all `{{...}}` placeholders**, so that **project name flows through every file in the clone**.

## Why now

Without this, every clone has hardcoded "AtilCalculator" / "atilcan65" everywhere — broken out of the box.

## Original Acceptance Criteria (now split across S21-003a + S21-003b)

- **AC1** (now in S21-003a #636) — GIVEN fresh clone WHEN user runs `bash scripts/dev-studio-init.sh` AND answers prompts for `GITHUB_OWNER`, `GITHUB_REPO`, `HUMAN_OWNER_NAME`, `PROJECT_NAME` THEN init script writes all rendered files AND exit code 0.
- **AC2** (now in S21-003a #636) — GIVEN init script completed WHEN user runs `grep -r '{{' . --exclude-dir=.git --exclude-dir=.venv` THEN 0 matches.
- **AC3** (now in S21-003a #636) — GIVEN init script completed WHEN user re-runs `bash scripts/dev-studio-init.sh` THEN idempotent (running twice does not corrupt state, no diff after second run). Per Q4 arch caveat.
- **AC4** (now in S21-003b #693) — Advanced prompt UX: interactive prompts, validation, error reporting (deferrable if S21-003a core ships first).

## SPLIT History

- **Cycle ~#1221**: PM opened Issue #693 as sub-issue of #636 per arch §Size-negotiation (XL=5 → L=3 + M=2 SPLIT for scope isolation).
- **Cycle ~#1221**: STORY-S21-003 file retained as parent for historical context; S21-003a + S21-003b tracked in separate files.
- **Cycle ~#1228**: PM Wave 2 promotion set `agent:tester` on #636 + #693 (PM labeling error cycle ~#1228, 5-cycle drift per RETRO-016 #6).
- **Cycle ~#1249**: Orchestrator board-hygiene resolved: #636 flipped back to `agent:developer` (impl story), #693 kept `agent:tester` (d-test-coupled per d070b).
- **Cycle ~#1236** (this commit): OBSOLETE marker added to STORY-S21-003.md per RETRO-016 #6 prevention pattern (post-mortem codification).

## Out of scope

- Interactive GUI init, web-based init.

## Dependencies

- **Upstream:** S21-005 (.tmpl source files exist).
- **Downstream:** S21-004 (audit script), S21-012 (PROJECT_TOKEN handling), S21-018 (d070 test).

## Metrics of success

- **Leading:** `grep -r '{{' . --exclude-dir=.git` returns 0 matches on post-init clone.
- **Lagging:** S21-023 fresh-clone validation passes (PM runs init on 2 separate clones, all d-tests pass).

## Sizing

- **Original hint:** 5 points (large: extends existing init script, requires audit of all references).
- **SPLIT final sizes** (cycle ~#1213 ratification):
  - S21-003a (#636): 3sp (arch SPLIT push-back accepted)
  - S21-003b (#693): 2sp (arch SPLIT push-back accepted)
  - **Total: 5sp = 3+2 (matches original hint)**

## Lane (Pre-SPLIT)

- **Author:** developer
- **Reviewer:** architect (9-Lens idempotency + silent_skip per ADR-0045 lens d+e)
- **Tester:** tester (d070-template-render covers this)
- **PM:** @product-manager

## Lane (Post-SPLIT)

- **S21-003a (#636) impl** → `agent:developer`, cc:tester for d-test contract
- **S21-003b (#693) d-test** → `agent:tester` (d-test-coupled), cc:developer for impl handoff
- **PM observation lane** (sister-pattern to PR #694 d093 ACK cycle ~#1228 + PR #698 d091 ACK cycle ~#1232)

## Sprint 21 Context

- **Epic:** E2 — Parameterization & Init Script
- **Wave:** Wave 2 (Day 4-6)

## Cross-references

- **Issue #636** — S21-003a (impl story, agent:developer)
- **Issue #693** — S21-003b (d-test-coupled, agent:tester)
- **Issue #685** — Sprint 21 Joint Sizing (decision E Wave 5 deferral; SPLIT captured cycle ~#1213)
- **RETRO-016 candidate #6** — PM-side pre-dispatch lint (PR #700 PM Dispatch Protocol v0.1)
- **PR #700** — PM Dispatch Protocol v0.1 codification
- **PM cycle ~#1233 post-mortem** — Issue #690 cmt 4835213200 (5-cycle Wave 2 drift root cause)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)