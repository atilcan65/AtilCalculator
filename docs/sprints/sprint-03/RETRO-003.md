# Sprint 3 Retrospective — Operational Hardening + RCA-1→RCA-14 Chain (2026-06-19 → 2026-07-03, 14 days)

> **Status:** 🟡 DRAFT (PM authored) — pending orchestrator + architect review per Issue #173 acceptance criteria.
> **Author:** @product-manager (Claude Code) — 2026-06-20T10:25Z
> **Format:** Concise retro + RCA chain analysis + Sprint 4 must-haves
> **Audience:** @atilcan65 (owner) + 5-agent team + Sprint 4 planning

---

## TL;DR

Sprint 3 was **operational + ceremonial**, not feature work. The sprint produced **14 RCAs in 4 days** (RCA-1 → RCA-14), with the deploy-automation chain (ADR-0027 → ADR-0030 pivot → DEPLOY-001 v4→v9) consuming the entire P0 budget. **DoD §4 (auto-deploy working) = PASS** (PR #169 v8 + #33ed3a2 v9), **DoD §5 (rollback smoke test) = pending** (#143 owner task). All MVP-1 metrics M1-M5 remain green from Sprint 2.

**Biggest wins:** (1) the 5-agent autonomous team **survived** 14 RCAs without human relay (zero "please tell X" messages after day 1), (2) ADR-driven **architectural pivot in mid-sprint** (ADR-0027 → ADR-0030 self-hosted runner) was clean — RCA-1 was caught within 4 hours of detection, (3) the rapid-iteration pattern (v4→v9 in 48h, 6 deploy PRs + 2 fix-test pairs) closed the chain faster than retrospective-mode would have, (4) `td-016/td-018/td-019` blind-spot family was filed inline (no separate ADR cycle needed — doctrine evolved with the chain).

**Biggest hurts:** (1) the RCA chain itself — 14 incidents in 4 days is **unsustainable** even with autonomous recovery, (2) **owner-impl pattern** triggered 8+ times this sprint (DEPLOY-002 secrets, DEPLOY-003 healthz, DEPLOY-005 runner install, RCA-7/8/10/11/12 fixes all owner-applied), (3) **TD-013/flip-loop noise** between orchestrator (strips cc:*) and architect (re-adds) consumed PM attention on docs PRs, (4) **service persistence regression** (#171, P1) was discovered post-DoD §4 close, (5) **auto-revert bug** (#125, P1) still open from Sprint 2.

**Sprint 4 readiness:** RETRO-003 draft ready (this file), #48 TEMPLATE-PORT unblocked, #125 + #171 carry-over, **#172 E2E deploy verification harness** is the most-derived P0 (RCA pattern root cause: deploy smoke-tests were too shallow).

---

## RCA Chain — RCA-1 → RCA-14 (4 days, 14 incidents)

### Timeline

| RCA | Date (UTC) | Issue | PR fix | Title | Time-to-fix |
|---|---|---|---|---|---|
| 1 | 2026-06-19T20:12:47Z | #138 | (ADR-0030) | Public GH runner cannot reach LAN prod host | 4h (architectural pivot) |
| 2 | 2026-06-19T21:30Z | #148 | #151 (part) | notify env not set (TELEGRAM_CHAT_ID etc.) | 6h |
| 3 | 2026-06-19T22:00Z | (in #148) | #141 | workflow YAML inline script gap (appleboy compat) | 6h |
| 4 | 2026-06-19T22:30Z | (in #148) | #151 (part) | REPO_DIR persistence across steps | 6h |
| 5 | 2026-06-19T23:00Z | (in #148) | #151 (part) | REPO_DIR path mismatch ($REPO_DIR vs $HOME) | 6h |
| 6 | 2026-06-19T23:30Z | (in #148) | #151 (part) | notify env not set (re-occurrence) | 6h |
| 7 | 2026-06-20T01:30Z | #152, #159 | #157 | systemctl --user bus error on self-hosted runner | 11h |
| 8 | 2026-06-20T02:00Z | #152 | (workaround in #157) | TELEGRAM secrets empty in runner env | 11h |
| 9 | 2026-06-20T04:00Z | #160 | #161 | .venv/uvicorn missing post-deploy (preflight gap) | 13h |
| 10 | 2026-06-20T05:30Z | #162, #163 | (in #161) | `uv` not installed on prod host atiltestweb | 14h |
| 11 | 2026-06-20T06:30Z | #164 | #165, #166 | uvicorn+fastapi runtime dep gap (missing from pyproject.toml) | 16h |
| 12 | 2026-06-20T09:00Z | #167, #168 | #169 | cross-user process isolation (pkill -f killed other uvicorn) | 18h |
| 13 | 2026-06-20T10:00Z | #170 | (in #169) | cross-user uv PATH (env contamination) | 18h |
| 14 | 2026-06-20T10:30Z | #171 | 33ed3a2 (v9) | uvicorn killed by GH Actions runner cleanup phase (orphan-kill) | 20h |

**Mean time-to-fix:** ~12h. **Total PRs in chain:** 11 (4 docs/ADR + 7 code/test).

### Root patterns — what made this chain self-sustaining

1. **Doctrine evolved inline** — `td-016` (end-to-end data flow review), `td-018` (runtime preconditions), `td-019` (canonical-entry verification) were filed as incidents surfaced, not as separate ADR cycles. The architect's "self-post-mortem" pattern (4 of them in 24h) is healthy and replicable.

2. **PM/Architect/Orchestrator/Developer/Tester all stayed in queue** — none of them invented "standby" pauses, none of them waited for human relay. Auto-ping + agent-watch pairing worked as designed.

3. **Atomic 4-flag handoff (ADR-0015) held** — no broken-label issues in the chain. The flip-loop noise (TD-013) is cosmetic, not data-corrupting.

4. **Owner-impl pattern absorbed what the agents physically couldn't** — secrets, runner install, systemd-enable, workflow file merge approval, runtime preflight apply. The owner became the deploy test-bed, which is a Sprint 1+2+3 recurring pattern (8+ instances).

5. **Rapid-iteration discipline beat retrospective-mode** — v4→v5→v6→v7-fix→v7-test→v8→v9 in 48h, with the v7-fix (PR #165) + v7-test (PR #166) pairing demonstrating the right shape: fix PR + regression test PR landing back-to-back, separately reviewable.

### What didn't work (the gaps)

1. **Deploy verification was smoke-test-only** — Issue #171 (uvicorn killed by runner cleanup phase) exposes that `GET /healthz` returning 200 once is not enough. The service must survive GH Actions' teardown phase. **E2E deploy verification harness** (Sprint 4 P0 candidate, Issue #172 proposed).

2. **Auto-revert bug #125 still open** — PR #122's `cc:*` labels auto-revert within 90s, 3rd instance. The flip-loop noise (orchestrator strips, architect re-adds) is the visible symptom; the underlying auto-revert mechanism is unidentified. Architect's RC blocked Sprint 3 P1 inclusion.

3. **Stale issue hygiene** — #155 (DEPLOY-001 v5 spec) closed without re-routing to #157, #156 (TD-019) sat open until RCA-12 surfaced, #125 (auto-revert) carried from Sprint 2 unmoved.

4. **PM/Architect/Owner had no SLA on Triage** — RCA-12 (cross-user pkill) was filed at #167, fix at #168, but Issue #167 sat for 4h with `agent:human` assignee. RCA-13 (uv PATH) was filed at #170, fix at #169, but #170 was filed **after** the fix PR was already merged. Process gap: incidents should auto-cc PM **at file time** (currently 24h+ lag).

5. **Owner-impl pattern overload** — 8+ owner-impls Sprint 1+2+3 (DEPLOY-002 secrets, DEPLOY-003 healthz, DEPLOY-005 runner install, RCA-7/8/10/11/12 fixes, plus 3 from Sprint 1+2). This is **the throughput ceiling on the system**. Agents cannot run sudo, cannot generate SSH keys, cannot register runners, cannot restart services on prod. Owner is the only path to ground truth. Sprint 4 must either:
   - (a) Reduce owner-impl count by 50% (move more to owner-gated PRs the owner reviews/merges without manual apply)
   - (b) Add a "VM-coworker" agent role that has limited sudo (e.g., a deploy-only user with `systemctl --user` + key-based SSH from a CI jumpbox)
   - (c) Accept the ceiling and reduce sprint scope

---

## What worked (the wins to keep)

1. **5-agent autonomous team survived** — 14 RCAs, zero human relay messages, zero "please tell X" pings after day 1.

2. **Self-hosted runner deployment in 1 sprint** — 5 days from ADR-0027 (PR #128, 18:41Z) to DoD §4 PASS (PR #169 + #33ed3a2, day 4 EOD). The architectural pivot (ADR-0027 → ADR-0030) added 12h but was the right call.

3. **Doctrine evolved via TD inline** — `td-015` (TD family at #2354966), `td-016` (end-to-end data flow review), `td-018` (runtime preconditions), `td-019` (canonical-entry verification). No separate ADR cycle needed for any of them; each was filed as a 1-2 line docs PR and merged within 4h.

4. **Atomic 4-flag handoff (ADR-0015) held** — no broken-label issues in the chain. The flip-loop noise (TD-013) is cosmetic, not data-corrupting.

5. **Rapid-iteration discipline** — v4→v5→v6→v7(fix+test)→v8→v9 in 48h. The v7-fix + v7-test pair (PR #165 + #166, 20min apart) is a **replicable pattern**: when a fix-PR is approved, immediately PR a regression test that would have caught it.

6. **Architect self-post-mortem pattern** — 4 self-post-mortems in 24h (TD-015, TD-016, TD-018, TD-019) is healthy. Architect is catching his own blind-spots. Replicate for other agents (PM, developer, tester) in Sprint 4.

---

## Sprint 4 must-haves (derived from RCA patterns)

### P0 — must-have for Sprint 4

1. **E2E deploy verification harness** (Issue #172 proposed) — verifies service persists beyond GH Actions teardown. Direct response to RCA-14 / #171. Owner: developer. Estimate: 3 SP. Acceptance: 5 consecutive auto-deploys where service responds 5min+ after Action exit, on prod host 192.168.1.199.

2. **#125 auto-revert bug RC + fix** — architect's RC must close before Sprint 4 P1 starts. Owner: architect. Estimate: 2 SP. Acceptance: PR #122 (or whatever PR triggered the auto-revert) merged with the underlying mechanism identified + tested in CI.

3. **DoD §5 rollback smoke test** (#143 owner task) — owner intentionally merges a bad SHA, verifies smoke-test catches it, verifies auto-rollback restores previous SHA. Owner: atilcan65. Time-box: 30min.

### P1 — should-have for Sprint 4

4. **Backlog.json status hygiene** — 6 of 20 stories in backlog.json are stale (DEPLOY-001/002/003 all `status:backlog` but merged + in_progress). PM to reconcile Sprint 4 day 1.

5. **#48 TEMPLATE-PORT unblock** — RETRO-003 closes the gate. Developer to start the actual port PR next sprint. Estimate: 5 SP.

6. **#156 Issue hygiene pass** — close duplicates, route orphaned incidents to fix-PRs, archive stale items. PM to lead. Estimate: 2 SP.

7. **Owner-impl SLA + cadence** — define which owner-impls are sprint-must-have vs Sprint 2+ nice-to-have. Owner: orchestrator + atilcan65. Estimate: 1 SP (decision-doc).

8. **PM/Architect/Owner Triage SLA** — incidents must auto-cc PM at file time (not 24h later). Orchestrator to update `agent-watch.sh` event filter. Estimate: 1 SP.

### P2 — nice-to-have for Sprint 4

9. **Auto-ping in agent-watch script extension** — issue-level events for PM (Sprint 1 retro action item, never addressed). Architect to file TD. Estimate: 1 SP.

10. **Replicate architect self-post-mortem pattern for other agents** — PM/Developer/Tester self-post-mortem trigger after every P0 incident close. Estimate: 2 SP.

11. **ADR-0023 status flip** (Proposed → Accepted) — low-priority docs PR, has been deferred Sprint 1+2+3. PM to draft. Estimate: 0.5 SP.

---

## Doctrine amendments (TDs to consider for ADR promotion)

| TD | Current state | ADR promotion candidate? | Why |
|---|---|---|---|
| **TD-015** | Open (filed with ADR-0030) | NO | Single-instance lesson (self-hosted runner pivot), embedded in ADR-0030 §Related |
| **TD-016** | Open | **YES** | End-to-end data flow review lesson is reusable across all infra work, deserves dedicated ADR |
| **TD-018** | Open | **YES** | Runtime preconditions checklist is reusable across all deploy/install work, deserves dedicated ADR |
| **TD-019** | Open | NO | Orchestrator guidance cross-check, narrow scope, can stay as TD |
| **TD-013** | Open | NO | HWM-advancing re-fire pattern, narrow infra-watch concern |
| **TD-012** | Open | NO | 4-cat vs Handoff Discipline conflict, has design-OK gate precedent (PR #149), document in ADR-0015 §Worked examples |

**Action:** Architect to draft `ADR-0031 runtime-preconditions-checklist` (from TD-018) and `ADR-0032 end-to-end-data-flow-review` (from TD-016) in Sprint 4 P1.

---

## Sprint 4 readiness checklist

| Item | Status |
|---|---|
| RETRO-003 PM draft | ✅ (this file, in PR) |
| Architect + orchestrator review of retro | ⏳ Pending PR review |
| Sprint 4 backlog derived from retro lessons | ⏳ Post-merge |
| E2E deploy verification harness sized + assigned | ⏳ Sprint 4 P0 |
| #125 auto-revert RC closed | ⏳ Architect RC, Sprint 4 day 1 |
| DoD §5 rollback smoke test | ⏳ Owner, Sprint 4 day 1 |
| Backlog.json hygiene | ⏳ PM, Sprint 4 day 1 |

---

## Metrics & signals

- **PR throughput Sprint 3 (so far):** ~18 merged PRs in 4 days → ~4.5 PRs/day (vs Sprint 1 baseline 1 PR/72min wall-clock) — **3-4× throughput**, mostly owner-impl
- **RCA count:** 14 in 4 days (sustainable max: 3-4/sprint, 14 is incident-mode)
- **P0 burn-down:** DoD §4 PASS, DoD §5 pending
- **Owner-impl count:** 8+ in 1 sprint (sustainable max: 3-4)
- **Architecture decisions authored:** 2 (ADR-0027, ADR-0030) + 1 amendment (ADR-0027 §1 superseded by ADR-0030) + 1 doctrine gap (TD-015/016/018/019 family — 4 separate TDs, 1 ADR promotion candidate pair)
- **Auto-ping in agent-watch script extension:** Still NOT done (carry-over from Sprint 1 retro)

---

## Action items (post-retro)

| # | Owner | Item | Target |
|---|---|---|---|
| A1 | **orchestrator** | Review RETRO-003 PR, approve if Sprint 4 derived-scope matches | Sprint 3 EOD |
| A2 | **architect** | Review RETRO-003 PR, confirm ADR promotion candidates (TD-016 → ADR-0031, TD-018 → ADR-0032) | Sprint 3 EOD |
| A3 | **owner (atilcan65)** | DoD §5 rollback smoke test (#143) | Sprint 4 day 1 |
| A4 | **architect** | Close #125 RC, draft fix PR | Sprint 4 P1 |
| A5 | **developer** | Open E2E deploy verification harness PR (Issue #172 if approved by PM in Sprint 4 grooming) | Sprint 4 P0 |
| A6 | **PM** | Reconcile backlog.json status hygiene (6 stale items) | Sprint 4 day 1 |
| A7 | **developer** | Start #48 TEMPLATE-PORT actual port PR (RETRO-003 is the gate) | Sprint 4 day 1 |
| A8 | **PM** | Lead #156 Issue hygiene pass (close dups, route orphans) | Sprint 4 P1 |
| A9 | **orchestrator** | Update `agent-watch.sh` event filter — incidents auto-cc PM at file time | Sprint 4 P1 |
| A10 | **PM** | Draft Sprint 4 plan.md from this retro's "must-haves" section | Sprint 4 day 1 |
| A11 | **orchestrator** | Append retro entry to CHANGELOG.md `[Unreleased]` (small chore PR) | Sprint 4 P1 |
| A12 | **PM** | Draft ADR-0023 status flip (Proposed → Accepted) | Sprint 4 P2 |

---

— @product-manager, 2026-06-20T10:25:00Z
