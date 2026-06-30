# Sprint 22 PIVOT — Orchestrator Plan

> **Active sprint:** **Sprint 22 — PIVOT: Self-Hosted Runner + 3-Repo Org Migration + Template Visibility**
> 📄 **PM-drafted scope:** [Issue #708](https://github.com/atilproject/AtilCalculator/issues/708) (owner GO verdict cycle ~#1512 follow-up, plan v3 final)
> 📄 **Predecessor (Sprint 21 STALLED):** [../sprint-21/close.md](../sprint-21/close.md) (Wave 1 pre-dispatch, PRs ready, sizing never executed — Q6 owner-decision: abandonment vs carry-over, default carry-over)
> 📄 **Predecessor (Sprint 18 PROJECT CLOSED):** [../sprint-18/close.md](../sprint-18/close.md) (AtilCalculator FINAL 8/8 SHIPPED)
> 📄 **Predecessor (Sprint 20 folded):** [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md) §6

## Mode

🚀 **SPRINT 22 PIVOT EXECUTION** — owner GO verdict (Issue #708, cycle ~#1512 follow-up). Strategy v3 final: 8 self-hosted runners (atilproject org, owner VM 192.168.1.197) + 3-repo org migration (atilcalculator + dev-studio-template + dev-studio-launcher → atilproject) + template visibility default-private. GH-hosted runner dependency ZERO. R3 SPOF (single VM) → 2. VM redundancy Sprint 23+.

## 5-Phase Plan (orchestrator-published, from Issue #708 §5-Phase Plan)

### Faz 0 — Pre-Flight Snapshot (~15 min) — PM + Developer — Owner accountable
8 runner health check + workload dry-run + inventory + dev-studio-init.sh self-hosted mode check.
**Exit gate:** Owner GO + 8 runners GREEN + balanced workload.

### Faz 1 — Self-Hosted Runner Workflow Update (~1 h) — Developer — Owner accountable
- ✅ 1.0 Runner install + registration — DONE by owner (8 runners registered to atilproject org)
- ✅ 1.3 Concurrent job test (8 parallel) — DONE by owner (manual pre-migration)
- ✅ 1.4 Failover test (1 runner kill) — DONE by owner (manual pre-migration)
- ⏳ **1.1 Workflow update** (`.github/workflows/*.yml`): `runs-on: ubuntu-latest` → `runs-on: [self-hosted, linux, x64, atilproject]` — developer + architect draft, owner merge
  - **🚦 CASE-PATCH LANDED cycle ~#1534** (head SHA `a279fb6`): case-sensitive labels `[self-hosted, Linux, X64, atilproject]` (capitalized L, X) per arch re-review v3 path; 11 workflow files updated; d094 d-test updated 8 string occurrences; self-test 3/3 GREEN post-patch
  - **🛑 CRITICAL-PATH STILL BLOCKED cycle ~#1566** (arch v3 CORRECTION cmt 4841705205): arch retracted v2 review (cmt 4841364913). v2 §Trust-but-Verify failure — claimed PR #710 validated self-hosted infra, but ground truth shows PR #710 modified 0 workflow files (only scripts/ + tests/), and its CI runs were GH-hosted `ubuntu-latest` (verified via REST API). Sprint 22 PIVOT runner infra NOT validated end-to-end. PM escalation cmt 4841710845 cycle ~#1536 confirms PR #709 branch has 0 CI runs after 9min+ queued — self-hosted runners not picking up workflow. **NEW IMPLICIT Faz 2.5 needed (owner action ~5-10min): enable atilproject org-runner access for atilproject/AtilCalculator repo** in GitHub Settings → Actions → Runners → "Allow GitHub Actions to use atilproject organization runners for this repository". PR #709 (Faz 1.1) blocked on Faz 2.5. PR #710 owner merge gate ACTIVE but does NOT validate runner infra (clone-URL scripts only). Sprint scope-change — owner-decision required.
- ⏳ **1.2 Smoke test**: first workflow run on self-hosted = GREEN CI
- ⏳ **1.5 Runner label audit** (architect code-review)

### Faz 2 — 3-Repo Org Migration (~4 h) — Owner (manual) — Owner accountable
- ✅ **2.1 GitHub transfer** — DONE cycle ~#1530 (owner directive "trigger Faz 2.1 now", orchestrator EXECUTED via gh api). 3 repos migrated: atilcan65 → atilproject. 55 open issues migrated, admin permission retained, auto-redirect active.
- ⏳ 2.2 Branch protection reset (owner) — NOT PROTECTED on new repo (BP does NOT migrate with transfer)
- ⏳ 2.3 Secrets re-create (owner+dev) — public key retained, values GONE
- ⏸️ 2.4 Local clone URL update (dev+all agents) — PREP done cycle ~#1521 (110 files MIGRATE/IGNORE/STAY-AT-USER-LEVEL), dev lane UNBLOCKED, branch `feat/sprint-22-pivot-faz-2-4-clone-url-update` exists, orchestrator bot clone updated as template
- ✅ **2.4 LANDED cycle ~#1560** (PR #710, arch 9-Lens FINAL 🟢 OK cmt 4841609319, tester sign-off 🟢 APPROVED cmt 4841547445 d095 4/4 GREEN, status:ready + cc:human, owner merge gate ACTIVE, 275+/40-, 16 files, 2 commits)
- 🟡 2.5 Webhook/board bağlantıları (orchestrator) — PARTIAL: URL drift fixed in 2 plan.md files + local git remote updated. Webhooks = 0 (none existed pre-transfer). Projects v2 boards owner-MISMATCH (user-owned vs org-owned can't link `linkProjectV2ToRepository`), `copyProjectV2` mutation available (items don't copy) — owner decision needed (Option A: copyProjectV2 + manual item re-add; Option B: new boards abandon history; Option C: re-transfer back)
- 🆕 **2.5b (NEW IMPLICIT, cycle ~#1566, arch cmt 4841705205) Owner enables atilproject org-runner access for atilproject/AtilCalculator repo** (~5-10min, owner-action only, NOT a code change) — GitHub Settings → Actions → Runners → toggle "Allow GitHub Actions to use atilproject organization runners for this repository". Gates Faz 1.1 (PR #709) green CI. Without this, self-hosted runners registered at org-level will NOT pick up workflow runs on this repo. Sprint scope-change (soul-level owner decision).
- ✅ **2.6 Issue/PR redirect doğrulama VERIFIED cycle ~#1568** (orchestrator lane) — sampled 5 redirects: 3 repos (AtilCalculator + dev-studio-template + dev-studio-launcher) + 1 issue (#470) + 1 PR (#626), all auto-redirect clean (atilcan65/* → atilproject/*), archived=false, owner=atilproject, html_url correctly redirected. Issue #708 cmt 4841791866 documents verification. No owner action required.
- ⏳ 2.7 Self-hosted runner auto-discovery (arch+dev) — arch cap-blocked 2/2 on Issue #680/682

### Faz 3 — Template Visibility Parameter (~6 h) — Developer — PM accountable
3.1 Template script ADR (architect) | 3.2 `--visibility` implementation (developer) | 3.3 d-test coverage (tester: explicit public/private/default/invalid) | 3.4 Template README update (developer+PM) | 3.5 Backward compat check (developer).

### Faz 4 — Sprint 22 Plan Ratification (~8 h) — PM + Orchestrator — Owner accountable
- ✅ 4.1 Sprint 22 scope önerisi (Issue #708 by PM, owner GO)
- ⏳ 4.2 Architect ADR set (5 ADRs)
  - **🆕 ADR-0061 DRAFT prepared cycle ~#1573** (architect local-work, NOT git-tracked per TD-035): `/tmp/adr-0061-sprint-22-pivot-runner-org-topology.md` (218 lines, 15.9 KB) — codifies Sprint 22 PIVOT self-hosted runner org-topology (8 org-level runners + access-grant gate doctrine + TD-036 silent QUEUE failure candidate). Deciders: @architect + @developer + @human + @orchestrator + @tester. Related: ADR-0030 (LAN-deploy), ADR-0014 (PROJECT_TOKEN), ADR-0043 (8-lens), ADR-0049 (d-test), ADR-0055 (Cadence Rule 1), Issue #711 (Faz 2.5b), PR #709, PR #710, arch cmt 4841705205. Sprint-gated: PR opens when Sprint 22 PIVOT Faz 4.2 active.
- ⏳ 4.3 Sizing joint (PM+arch+dev+test)
- ⏳ **4.4 Sprint 22 plan publish (this file, by orchestrator) + `current/plan.md` pointer refresh** — IN PROGRESS cycle ~1519
- ⏳ 4.5 Sprint 21 close-out (orchestrator)

### Faz 5 — Post-Migration Continuity + Runner Monitoring + Re-Test (24 h+) — PM + Developer — Owner accountable
5.1 CI run monitoring (developer+tester) | 5.2 Board sync verification (orchestrator) | 5.3 Issue/PR redirect sample check (PM) | 5.4 Agent lane + workflow continuity (PM+arch) | 5.5 Migration retro (PM) | 5.6 Runner up-time monitoring (dev+arch) | 5.7 Runner capacity dashboard (dev) | 5.8 2. VM redundancy planning (owner+arch) | **5.9 REAL-environment re-test (owner+developer)** — production-grade concurrent + failover verification.

## In-flight continuity (must survive migration)
- **PR #694** (tester d-test, agent:tester, status:ready, cc:human)
- **PR #695** (feat/docs, agent:developer, status:ready, verdict-by:2026-06-30T16:52:15Z)
- **Issue #652** (STORY-S21-020 ONBOARDING.md, agent:product-manager, status:backlog, parked Wave 5 per Issue #685) — Sprint 22 candidate
- **PR #710** (Faz 2.4 dev clone URL update, agent:developer, status:ready + cc:human, arch FINAL 🟢 OK + tester 🟢 APPROVED, owner merge gate ACTIVE)

## Lane assignments (per Role + Issue #708 §Peer actions)

### @architect
- Faz 1.5: Runner label audit (code-review)
- Faz 2.7: Self-hosted runner auto-discovery
- Faz 3.1: Template script ADR (`--visibility` design)
- Faz 4.2: 5 ADRs (self-hosted runner arch + visibility design + monitoring strategy + redundancy plan + re-test criteria)
- Faz 5.4: Agent lane continuity verification
- Faz 5.6: Runner monitoring setup
- Faz 5.8: 2. VM redundancy plan

### @developer
- Faz 0.1, 0.3, 0.4: Pre-flight inventory + runner health check + workload dry-run
- Faz 1.1: Workflow update (`.github/workflows/*.yml`)
- Faz 1.2: Smoke test (GREEN CI first run)
- Faz 1.5: Runner label audit collab
- Faz 2.4: Local clone URL update (post-migration)
- Faz 3.2: `--visibility` implementation
- Faz 3.4: Template README update
- Faz 3.5: Backward compat check
- Faz 5.6, 5.7: Runner monitoring + capacity dashboard
- Faz 5.9: Re-test coordination (with owner)

### @tester
- Faz 3.3: Visibility param d-test (parametric: explicit public/private/default/invalid)
- Faz 5.1: CI run monitoring (24 h)
- Faz 5.9: Re-test verification (sign-off)

### @product-manager
- Faz 0.x: Pre-flight participation
- Faz 4.1: Sprint 22 scope önerisi (Issue #708 ✅ DONE)
- Faz 4.3: Sizing joint
- Faz 3.4 collab: Template README
- Faz 5.3: Issue/PR redirect sample check
- Faz 5.5: Migration retro
- Faz 4.5 collab: Sprint 21 close-out co-authorship

### @orchestrator (assigned, this lane)
- Faz 2.5: Webhook / Project board bağlantıları (post-migration)
- Faz 4.4: Sprint 22 plan publish + `current/plan.md` pointer refresh — **IN PROGRESS**
- Faz 4.5: Sprint 21 close-out + retrospective
- Faz 5.2: Board sync verification

### @owner (soul-level decisions)
- Faz 2 (manual 3-repo org migration)
- Q1 (atilproject org plan tier — Team minimum)
- Q2 (VM 192.168.1.197 7/24 availability)
- Q4 (template visibility default policy)
- Q5 (runner label convention)
- Q6 (Sprint 21 abandonment rationale — soul-level)
- Q7 (Issue #652 rename)
- Q8 (dev-studio-launcher scope inclusion)
- Q9 (runner monitoring strategy)
- Q10 (workload balancing)
- Q11 (2. VM redundancy timeline)
- Q12 (Faz 5.9 re-test criteria)

## Risk register (8 risks, from Issue #708 §Risk register)
R1 GH runner limit (mitigated) | R2 Migration secrets/BR loss (Faz 2.2/2.3) | R3 8 runners same VM = SPOF (Faz 5.8) | R4 Default-private breaking (Faz 3.5) | R5 In-flight PR/issue migration loss (Faz 0.1) | R6 Real-env concurrent+failover (mitigated manual, re-test Faz 5.9) | R7 Label convention inconsistent (Faz 1.5) | R8 VM CPU/RAM bottleneck (Faz 5.7).

## Definition of Done (Sprint 22)
1. All 5 Faz exit gates passed (Faz 0/1/2/3/4 + Faz 5 monitored 24h+)
2. 8 self-hosted runners registered + GREEN + labelled `[self-hosted, linux, x64, atilproject]`
3. 3 repos migrated to atilproject org + secrets re-created + branch protection reset + clone URLs updated
4. `--visibility` parameter shipped + d-tests green + template README updated
5. 5 ADRs authored + accepted (self-hosted runner arch + visibility design + monitoring strategy + redundancy plan + re-test criteria)
6. Sprint 21 close-out published (docs/sprints/sprint-21/close.md)
7. Faz 5.9 real-env re-test PASSED (concurrent + failover sign-off by owner+developer+tester)
8. No P0/P1 bugs filed against Sprint 22 stories within 24 h of squash

## Open Questions (owner-level) — Q-status tracker
1. ~~atilproject org plan tier (Team minimum)~~ — ✅ **FULLY CLOSED cycle ~1520** (PM posted: atilproject Team subscription ACTIVATED, owner executed "ben organization'u team subscription'a çevirdim")
2. 🟡 VM 192.168.1.197 7/24 availability — **PARTIAL** (owner typed "he..." and truncated, awaiting completion)
3. ~~Backup runner stratejisi~~ — ✅ **CLOSED cycle ~1503** (pre-kickoff)
4. Template visibility default policy (recommendation: `--visibility` default `private`)
5. ~~Runner label convention~~ — ✅ **CLOSED-BY-IMPL cycle ~1521** (peer-validated PM+dev consensus: PR #709 commit `f6f50d5` uses `[linux, x64, atilproject]` 3-label form per GH Actions default)
6. Sprint 21 abandonment rationale (default carry-over per Issue #708 §In-flight migration continuity; close-out skeleton drafted cycle ~#1552)
7. Issue #652 rename (STORY-S21-020 → STORY-S22-XXX?)
8. dev-studio-launcher scope inclusion
9. Runner monitoring strategy (GH Actions built-in / custom / Grafana)
10. Workload balancing (round-robin / sticky / queue-based)
11. 2. VM redundancy timeline (Sprint 23+ / immediate)
12. Faz 5.9 re-test criteria (e.g., 8 parallel × 100 successful jobs + 5 failover scenarios + fail-rate < 1%)

**Q-progress**: 3 closed (Q1 fully active cycle ~1520, Q3 pre-kickoff cycle ~1503, Q5 closed-by-impl cycle ~1521), 1 partial (Q2), 7 open. Total: 11/12.

## Cross-refs
- Issue #708: https://github.com/atilproject/AtilCalculator/issues/708 (Sprint 22 PIVOT coordination, owner GO)
- Sprint 21 close-out: [../sprint-21/close.md](../sprint-21/close.md) (skeleton drafted cycle ~#1552, awaits Q6 owner verdict annotation; default carry-over per Issue #708 §In-flight migration continuity)
- Sprint 18 close (precedent): [../sprint-18/close.md](../sprint-18/close.md)
- RETRO-014 (codification backlog): [../sprint-18/RETRO-014.md](../sprint-18/RETRO-014.md)

## Owner verdicts log (cycle ~#1594+)

### FORK A/B/C — Option A confirmed (cycle ~#1594, 2026-06-30T13:21+03:00)

**Verdict**: **Option A** (owner chat cycle ~#1594) — Settings → Actions → Runners → "Allow GitHub Actions to use atilproject organization runners for this repository" toggle ON for atilproject/AtilCalculator (+ dev-studio-template + dev-studio-launcher).

**Sprint implications**:
- Sprint scope amendment: **NONE** (Option A is the as-designed original)
- ADR-0061 DRAFT amendment: **NONE** (org-runner topology preserved)
- PR #709 re-push: **NOT NEEDED** (case-patched head `a279fb6` stable)
- 8 org-level runners: **ALL FUNCTIONAL** post-toggle
- R3 SPOF: Sprint 23+ plan unchanged

**Cascade forecast**: T+3 min owner-toggle → T+5 min PR #709 CI picks up → T+8 min arch v3 verdict → T+10 min owner merge → T+12 min Sprint 22 PIVOT critical-path UNBLOCKED.

**Issue #708 verdict cmt**: [cmt 4842329133](https://github.com/atilproject/AtilCalculator/issues/708#issuecomment-4842329133) (cycle ~#1594)

**Cross-refs**: FORK-IN-THE-ROAD cmt 4841941588 (cycle ~#1577) → owner verdict Option A cycle ~#1594; Issue #711 (Faz 2.5b) → 🟢 will close post-Option-A verification; PR #709 → will GREEN post-toggle; arch cmt 4841705205 (cycle ~#1566 v3 CORRECTION) → resolved by Option A.

---

🤖 Generated by Orchestrator (agent:orchestrator) on Sprint 22 PIVOT kickoff (cycle ~1519, 2026-06-30T10:45+03:00). Plan source: PM-authored Issue #708 (Plan v3 final, owner GO verdict cycle ~#1512 follow-up). Pre-Kickoff Gate stamped on Issue #708. Q-status refreshed cycle ~#1554 (Q3 + Q5 added as closed; Sprint 21 close-out pointer de-pending). Cycle ~#1566 §Trust-but-Verify double-failure correction: Sprint 22 PIVOT critical-path reverted UNBLOCKED→BLOCKED on NEW IMPLICIT Faz 2.5b (Issue #711, owner-action ~5-10min, sprint scope-change +1). Cycle ~#1568 Faz 2.6 redirect sample VERIFIED (5/5 clean, archived=false, owner=atilproject). Cycle ~#1569 Sprint 21 carry-over sweep + arch WIP cap escalation (Issue #680+#682 cap-blocked 30h+). Cycle ~#1570 lightweight plan refresh.