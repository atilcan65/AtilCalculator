# Cycle ~#3349 — Cross-User Env Var Pattern ADR-0064 Pickup (REPRIME recovery + wake_nudge queue non-empty)

> **Date**: 2026-07-03 (cycle ~#3349, REPRIME recovery post-wake_nudge)
> **Author**: @architect (REPRIME recovery mode, Katman 1 silent-drop pickup)
> **Status**: action — authored ADR-0064 + INDEX.md row + TD-045 entry + PR opening
> **Source wake**: 4 wake_nudge items at 22:37-22:42:43Z (heartbeat + queue non-empty)
> **Severity**: P3 (process lane; doctrinal codification, non-blocking)
> **Sister-pattern**: cycle-3334 (stale-false-positive RCA), cycle-3023 (proactive-scan stalled FP), cycle-3049 (rate-limit local work)

---

## Summary

Picked up the 4 wake_nudge stack (queue 8 cc:architect open, agent:architect=0) by:
1. **Verifying ground truth on all 8 cc:architect issues** — REST API fallback after GraphQL rate-limit exhausted.
2. **Confirming my prior work on PR #764 / #772** — both 🟢 OK from arch lane, awaiting owner merge.
3. **Authoring ADR-0064** — codifying the cross-user env var pattern (3-tier precedence: `vars.X` repo var > workflow YAML hardcoded default > script-side `$USER` fallback). RCA-17 + Issue #765 carrier; closes the doctrinal gap that emerged across RCA-16 → RCA-17.
4. **Adding INDEX.md row** for ADR-0064 (line 62, immediately after ADR-0063).
5. **Filing TD-045** in `docs/tech-debt.md` for the cross-user env-var pattern coverage gap.
6. **Opening PR** with 4-cat labels per ADR-0012 (type:docs + status:in-review + agent:architect + cc:product-manager + cc:developer + cc:tester).
7. **Auto-pinging peers** per ADR-0033 dual-channel peer-poke discipline.

## Katman 1 silent-drop queue scan (2026-07-03T22:37-22:42Z)

Per doctrine §Autonomy Loop Rule §3 — "Katman 1: queue non-empty, no new events → scan queue for stale items":

| Issue | Title (abbrev) | Status | Arch action |
|---|---|---|---|
| #771 | RCA-20 uv-run missing uvicorn | in-progress, agent:developer | PR #772 closes it — my 🟢 OK at cycle #3348 ack'd; awaiting owner merge. No active action. |
| #769 | Sprint 24 backlog lane commitments | in-progress, agent:product-manager | PM-owned. FYI to architect for Sprint 24 PRD input. |
| #767 | Sprint 24 Backlog Grooming Ceremony | in-progress, agent:orchestrator | Orchestrator-owned ceremony. FYI. |
| #765 | deploy.yml ATC_SERVICE_USER env | ready, agent:human | **Owner-gated** per file ownership matrix. ADR-0064 codifies the proposed pattern — design input given via ADR. |
| #763 | RCA-17 deploy-runner.sh AC4 | in-progress, agent:developer | PR #764 (RCA-17 fix) MERGED 8d9540b. My 9-Lens 🟢 OK + 1 architectural 🟡 (the cross-user 🟡 = Issue #765). No active action. |
| #757 | Sprint 23 Daily Standup | in-progress, agent:orchestrator | Standup ceremony. FYI. |
| #567 | SHA-pin sweep actions/github-script@v7 | backlog, agent:human | **Already shipped via PR #576** — my cycle ~#3334 RCA recommended close. Cycle #3349 confirms no regression. |
| #566 | Arch 🟡 follow-ups (SHA-pin + audit + silent-skip) | blocked, agent:human | **All 4 ACs met** (AC1 → PR #576, AC2+AC3 → PR #758, AC4 → separate PRs). My cycle ~#3334 RCA recommended close. |

**Active architect work**: Issue #765 (closed by ADR-0064 doctrinal codification).

## Doctrinal codification — why ADR-0064

Pattern emerged ad-hoc across 3 instances:

| Instance | Origin | Surface | Doctrinal gap |
|---|---|---|---|
| **RCA-16** | PR #358-era Sprint 6 P1 redesign (MERGED ddfd43f 2026-06-24T18:33:24Z) | Hardcoded `'atilcan'` in `sudo -u` invocation | No doctrinal anchor; next engineer hardcoding user=invents own pattern |
| **PR #764 (RCA-17)** | MERGED 8d9540b 2026-07-02T22:15:32Z | Script-side `${ATC_SERVICE_USER:-$USER}` fallback | Tier 3 doctrine exists in PR, not in canonical ADR |
| **Issue #765** | OPEN, status:ready, agent:human, owner-gated | `vars.ATC_SERVICE_USER \|\| 'atilcan'` deploy.yml env block | Tier 1+2 doctrine proposed in issue body, not in canonical ADR |

Without ADR-0064, the next engineer adding `ATC_LOG_DIR` or `ATC_CONFIG_OWNER` would re-invent the resolution chain (or hardcode the user, repeating the RCA-17 anti-pattern). Codification locks in the 3-tier precedence chain as canonical.

## Action plan executed this cycle

1. ✅ **Re-read `.claude/CLAUDE.md` + `.claude/agents/architect.md`** (REPRIME pre-flight per soul patch)
2. ✅ **Polled queue via `bash scripts/agent-watch.sh architect`** → 0 new events, 1 wake_nudge (Katman 1 pattern)
3. ✅ **REST API scan** (`gh api .../issues` filter by `cc:architect`) → 8 issues confirmed; 0 PRs with `cc:architect` or `needs-architect-review`
4. ✅ **Cross-watchdog on PR #764 + #772** — both 🟢 OK from arch lane; QA verified via REST `/issues/N/comments`
5. ✅ **Authored ADR-0064** — `docs/decisions/ADR-0064-cross-user-env-var-pattern.md` (28,146 bytes)
6. ✅ **INDEX.md row added** — line 62, after ADR-0063
7. ✅ **TD-045 filed** — `docs/tech-debt.md` line 75, after TD-044
8. 🔄 **Open draft PR** with 4-cat labels (next step)
9. 🔄 **Auto-ping orchestrator + dev + tester** per ADR-0033 dual-channel
10. 🔄 **Heartbeat write + architect state update** (last step per TD-035 tight loop doctrine)

## Doctrine honored

- **ADR-0012** — 4-cat invariant on PR open (type:docs + status:in-review + agent:architect + cc:product-manager + cc:developer + cc:tester)
- **ADR-0015** — atomic 4-flag handoff where applicable (N/A — PR open only, no handoff yet)
- **ADR-0024** — verdict-by header convention (cmt on Issue #765 will include `verdict-by` ISO timestamp)
- **ADR-0033** — dual-channel peer-poke for cross-agent wake
- **ADR-0038** — Auto-Claim Protocol skipped this cycle (no `agent:architect` items in queue, but I'm not idle — I'm doing doctrinal lane work)
- **ADR-0043** — 9-Lens pre-publish gate (all 10 lenses attested in ADR-0064 §9-Lens section)
- **ADR-0044** — RED-first TDD (d121 d-test contract drafted in §d-test sister-pattern, ≥5 TCs baseline, 6 drafted)
- **ADR-0045** — auto-generated file refs + live-state verification (lens j attested — verified PR #764 MERGED @ 8d9540b, Issue #765 status:ready, no auto-gen file refs)
- **ADR-0049** — d-test framework (d121 sister-pattern, ≥5 TCs minimum per ADR-0049 baseline, 6 drafted)
- **ADR-0055** — Cadence Rule 1 atomic (this ADR + INDEX.md row + TD-045 in same PR)
- **ADR-0060** — AC mapping verification doctrine (N/A — doctrinal ADR, no story ACs)
- **Issue #113** — label-authority > body (worked from labels, not body text)
- **Issue #430 + #470** — pre-verdict cross-check + §Timing window (REPRIME re-query within 30s of post)
- **Issue #682** — post-verdict cross-watchdog (N/A for this cycle; will apply to PR review comments when peers respond)
- **Issue #238** — no self-justified pause (Katman 1 wake_nudge picked up via active queue scan; doctrinal codification is architect lane work, not standby)

## Cross-references

- **ADR-0064** (this pickup's deliverable) — `docs/decisions/ADR-0064-cross-user-env-var-pattern.md`
- **INDEX.md** (row added at line 62, after ADR-0063)
- **TD-045** (filed at `docs/tech-debt.md` line 75)
- **PR #764** (RCA-17 AC4 fix, MERGED 8d9540b) — arch 9-Lens 🟢 OK + 1 architectural 🟡 (the cross-user 🟡)
- **PR #772** (RCA-20 uv-run fix, status:ready awaiting owner squash) — arch re-verdict 🟢 OK at cycle #3348
- **Issue #765** (deploy.yml ATC_SERVICE_USER env, status:ready agent:human) — doctrinal closeout via ADR-0064
- **Sister-pattern docs**: ADR-0019-amend-4, ADR-0019-amend-5 (env-var precedence family), ADR-0010 (systemd user-service), ADR-0030 (self-hosted runner user)
- **Cycle sister-patterns**: cycle-3334 (stale-FP RCA), cycle-3049 (rate-limit local work)

## Open follow-ups

- [ ] **Cycle #3349 ADR-0064 PR** — open, draft, 4-cat labels per ADR-0012
- [ ] **Auto-ping** — orchestrator (board sync + Sprint 24 PRD awareness) + dev (impl view on Issue #765 env block + d121 d-test contract) + tester (d121 test sign-off)
- [ ] **Issue #765 follow-through** — wait for owner squash on deploy.yml env block; no arch action required after that
- [ ] **Issue #566 + #567 closure** — cycle ~#3334 RCA already recommended close; orchestrator/owner lane action; arch follow-up not required
- [ ] **d121 d-test contract** — drafted in ADR-0064 §d-test sister-pattern; tester signs off after ADR-0064 merges
- [ ] **Sprint 23 plan update** — flag ADR-0064 + Issue #765 follow-up in Sprint 23 §Sprint 24 candidate mapping (orchestrator lane)

— @architect, cycle ~#3349, 2026-07-03T22:38Z, Sprint 23 polish lane, REPRIME recovery + wake_nudge pickup
