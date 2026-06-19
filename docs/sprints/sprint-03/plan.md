# Sprint 3 — Operational Hardening + Retro Ceremony (2026-06-20 → 2026-07-03, 14 days)

> **Status:** 🟢 ACTIVE — kickoff complete, sizing ceremony closed (Issue #135, 2026-06-19T19:54Z)
> **Scope source of truth:** [backlog.json](backlog.json) — 10 SP operational stories (post owner-impl DEPLOY-003 reduction)
> **Capacity:** 5 agents × 14 days ≈ 35-45 SP (Sprint 1/2 baseline)
> **Sprint goal:** Close the prod-liveness gap (deploy automation per ADR-0027) + capture Sprint 2 lessons (retro + template port). All MVP-1 features shipped in Sprint 2; Sprint 3 is **operational hardening + retro ceremony**, NOT feature work.
> **Last actuals update:** 2026-06-19T19:55Z (PM + owner sizing acks in; architect/developer/tester inputs in flight as amendments)

---

## Sprint Goal

**Operational + ceremonial close-out.** Sprint 2 P1 merged 5 of 6 P1 feature stories, but the production site doesn't auto-update — owner has been manually SSH-deploying since Sprint 1. Sprint 3 ships the GitHub Action deploy pipeline (per ADR-0027, merged via PR #128) so any future `main` merge flows to prod automatically, AND writes the Sprint 2 retro so the lessons are durable, AND ports the Sprint 1+2 lessons to the dev-studio template (Issue #48 unblock per owner directive 2026-06-18T21:56Z).

Sprint 3 is **infrastructure + retro**, not new features. MVP-1 metrics M1-M5 are all at "shipped" status from Sprint 2.

---

## Capacity & commitment

- **Sprint length:** 14 days (2026-06-20 → 2026-07-03)
- **Agent capacity:** 5 agents × 14 days ≈ 35-45 SP
- **Committed operational stories:** 4 (10 SP) — DEPLOY-001, RETRO-003, TEMPLATE-PORT, DEPLOY-004 (deferred)
- **Already-shipped in Sprint 2→3 boundary:** DEPLOY-002 (owner-impl, secrets set 2026-06-19T19:44Z) + DEPLOY-003 (owner-impl PR #134, merged 2026-06-19T19:30:01Z)
- **Buffer:** 25-35 SP for unplanned work + Sprint 2 P1 24h burn-in bugs (until 2026-06-20T18:33:04Z) + ceremonies + on-call + Sprint 2 retro amendments

**Buffer is intentionally large** — Sprint 3 is a stabilization sprint, not a delivery sprint. Buffer absorbs:
- Sprint 2 P0/P1 bugs from 24h burn-in
- Sprint 3 in-flight deploy retries
- Sprint 2 retro action items that surface during the ceremony
- On-call rotation
- Re-scoping if DEPLOY-001 first deploy fails

---

## Committed stories (must-have)

### DEPLOY-001 — Trigger pipeline (.github/workflows/deploy.yml + scripts/deploy-runner.sh) [P0]

**Owner:** @developer (writes) + @tester (contract review) + @architect (design drift detection) + @human (workflow file merge approval)
**Why P0:** Closes the prod-liveness gap. ADR-0027 §1+2+5+6. Once shipped, every `main` merge auto-deploys via GitHub Action.

**Acceptance criteria:**

- [ ] `feat/deploy-001-workflow` branch from main (developer started at 2026-06-19T~20:00Z, commit a5105ce)
- [ ] `.github/workflows/deploy.yml` per ADR-0027 §Decision.1+2:
  - Trigger: `push to main` (branch filter, no PR-push noise)
  - Action steps: checkout → ssh-action (SHA-pinned) → `git reset --hard origin/main` → `systemctl --user restart atilcalc-web.service` → `curl -fsS http://$DEPLOY_HOST:PORT/healthz` smoke test
  - Secrets referenced via `${{ secrets.DEPLOY_SSH_KEY }}`, `${{ secrets.DEPLOY_HOST }}`, `${{ secrets.DEPLOY_USER }}` only
  - Auto-rollback on smoke-test failure: `git reset --hard HEAD@{1}` + restart + retry healthz
- [ ] `scripts/deploy-runner.sh` per ADR-0027 §Idempotency (idempotent, fail-soft, structured logging)
- [ ] Action runs complete in <5 min (GH Actions + SSH + restart + smoke)
- [ ] All `uses:` lines pinned by 40-char SHA (NOT tag, per ADR-0027 §Threat model)
- [ ] **Owner gate**: workflow file merge requires explicit owner approval (CLAUDE.md §File ownership matrix — `.github/workflows/` is human-only)

**Out of scope:** staging environment, multi-host deploy, blue/green (Sprint 4+ if needed)

**Definition of done:** PR merged with owner approval, ≥3 successful auto-deploys on real `main` merges, smoke-test failure path validated at least once (intentional bad merge → rollback verified).

---

### DEPLOY-002 — Secret wiring (DEPLOY_SSH_KEY + DEPLOY_HOST + DEPLOY_USER repo secrets) [P0] — **✅ DONE (owner-impl 2026-06-19T19:44Z)**

**Owner:** @human (actions) + @developer (rotation procedure doc)
**Why P0:** Gate for DEPLOY-001. Without secrets, workflow can't authenticate to prod.

**Status (2026-06-19T19:55Z):** ✅ DONE — owner generated ed25519 keypair on prod host, added public key to `~/.ssh/authorized_keys`, set 3 repo secrets via `gh secret set` at 19:44:05-20Z.

**Remaining work (small):**

- [ ] `docs/ops/secret-rotation.md` — 5-step rotation procedure per ADR-0027 §4 (owner-maintained, quarterly cadence)
- [ ] First rotation due: 2026-09-19 (90 days from keypair generation)

**Out of scope:** automated rotation tooling (Sprint 4+ if rotation becomes a hotspot)

**Definition of done:** Rotation procedure doc committed; DEPLOY-001 workflow uses the secrets; 1 successful auto-deploy validates the keypair+secret flow end-to-end.

---

### RETRO-003 — Sprint 2 retrospective [P1]

**Owner:** @product-manager (drafts retro input) + @orchestrator (publishes `docs/sprints/sprint-02/retrospective.md`)
**Why P1:** Sprint 2 lessons need to be durable. Captures owner-impl pattern (7 instances Sprint 1+2!), PR #81 doctrine gap, PM agent-watch improvements.

**Acceptance criteria:**

- [ ] PM drafts retro input starting **2026-06-20T18:34Z** (after Sprint 2 burn-in window ends 2026-06-20T18:33:04Z)
- [ ] Retro includes Sprint 2 P1 actuals: 5 stories, 25 SP final, all merged to main
- [ ] Retro includes **owner-impl pattern retrospective** (7 instances total Sprint 1+2: 6 in Sprint 2 P1 + 1 in Sprint 3 DEPLOY-003) — is this sustainable? PM validation?
- [ ] Retro includes **A10 + A12 doctrine debt filings** (status-label hygiene + body date-gate check)
- [ ] Retro includes **TD-013 + TD-014** (HWM-advancing re-fire pattern, cc:* auto-revert pattern)
- [ ] Orchestrator publishes `docs/sprints/sprint-02/retrospective.md` (mirror Sprint 1 pattern at `docs/sprints/sprint-01/retrospective.md`)
- [ ] Tech-debt log `docs/tech-debt.md` updated with new TD rows (TD-013, TD-014, etc.)
- [ ] PR merged with owner approval

**Out of scope:** Sprint 3 in-flight retrospective (Sprint 3 retro will be a separate ceremony)

**Definition of done:** Retro doc merged to main, tech-debt log updated, PM + orchestrator sign-off in PR comments.

---

### TEMPLATE-PORT — Issue #48 unblock (Sprint 1+2 lessons → dev-studio-template) [P1]

**Owner:** @developer (writes) + @architect (soul/script review) + @human (repo create if needed)
**Why P1:** Per owner directive 2026-06-18T21:56Z, dry-run gate REMOVED. Template port is GO. Future projects need this scaffolding.

**Acceptance criteria:**

- [ ] Issue #48 unblock: dev-studio-template repo created (owner action, ~5 min) if not exists at github.com/atilcan65/dev-studio-template
- [ ] **PR-T1** through **PR-T7** per Issue #48 spec:
  - PR-T1: `scripts/proactive-board-scan.sh` (source from #44 impl)
  - PR-T2: `scripts/agent-watch.sh` Katman 1+2 patches (source from #119 impl)
  - PR-T3: `scripts/atomic-label-edit.sh` (source from #47 impl)
  - PR-T4: ADR for label-mutation transactionality (source from ADR-0020)
  - PR-T5: ADR for docs-pr convention (source from ADR-0021)
  - PR-T6: `.claude/agents/*.md` soul files (5 files, adapted from AtilCalculator)
  - PR-T7: `.github/workflows/label-tx.yml` CI gate (source from #47)
- [ ] Each PR reviewed by @architect (souls + scripts correctness)
- [ ] **Test plan regen** (PR #133 closed-not-merged loss): tester regenerates DEPLOY-001/002/003 test plan docs as part of this work or in parallel docs PR
- [ ] Template-spawned test project has the patterns active out-of-the-box (d015 9/9 cases pass on fresh spawn)
- [ ] **Owner gate on each PR**: template is soul-bearing, owner approval per ADR-0021

**Out of scope:** All AtilCalculator-specific refs (ADR numbers 0001-0027, worktree paths `/home/atilcan/projects/atilcalc-*`, prod host `192.168.1.199`) — template is greenfield

**Definition of done:** All 7 PRs merged to dev-studio-template main; template-spawned test project validates the patterns work; Issue #48 closed.

---

### DEPLOY-004 — `scripts/deploy-status.sh` audit query [P2] — **DEFERRED to Sprint 4**

**Owner:** @developer
**Why P2 (deferred):** Audit query for deploy marker file. Low value vs other Sprint 3 priorities. Buffer absorbs if Sprint 3 mid-sprint review shows >30% buffer remaining.

**Status:** Deferred. Sprint 3 mid-sprint review (2026-06-27) decides pull-in or punt to Sprint 4.

---

## Architect pre-work (parallel to implementation, ~0-1 SP)

Architect has **no new ADRs required** in Sprint 3. ADR-0027 already Accepted (PR #128, merged 2026-06-19T18:41:26Z). DEPLOY-003 endpoint added to API surface — possible ADR-0019 amend-3 needed (architect open question in sizing ceremony) — 1 SP equivalent if so. **Awaiting architect sizing response on #135.**

---

## New runtime dependencies (ADR-pinned)

**None** for Sprint 3 implementation. DEPLOY-001 uses:
- `appleboy/ssh-action` OR raw `ssh` (developer choice, both SHA-pinned per ADR-0027 §Threat model)
- Existing `atilcalc-web.service` systemd user-service (ADR-0010, ADR-0017)
- New endpoint `GET /healthz` already shipped in DEPLOY-003 (PR #134, b435f5e)

No new pip packages.

---

## Risks & dependencies

| Risk | Severity | Mitigation | Owner |
|---|---|---|---|
| Owner bandwidth on 2 gates (workflow approval now, secrets done) | P0 | Keypair done 19:44Z; workflow approval within 24h of PR open; @orchestrator pings at 1h+ stale | @human + @orchestrator |
| DEPLOY-001 first deploy fails (workflow file syntax / SSH key issues) | P1 | Sprint 3 buffer absorbs 1-2 retries; smoke test catches regressions; rollback path tested in DoD | @developer + @human |
| Sprint 2 P1 24h burn-in — P0/P1 bug filed after 2026-06-20T18:33:04Z | P1 | 25-35 SP buffer absorbs bug fix work without re-planning | @developer + @tester |
| Template port (Issue #48) — dev-studio-template repo may not exist | P1 | Owner creates repo (~5 min); dev can fork from AtilCalculator if needed | @human + @developer |
| RETRO-003 PM agent may not have bandwidth to draft at 18:34Z | P2 | PM is on standby per ADR-0025; can be woken by orchestrator @-mention on #135 | @orchestrator + @product-manager |
| Owner-impl pattern continues on DEPLOY-001 (instead of dev writing) | P2 | Pattern validated 7x (6 in Sprint 2 + 1 in Sprint 3 DEPLOY-003); no shift if owner implements | @human + @orchestrator |
| Test plan docs lost (PR #133 closed-not-merged) | P1 | Tester regenerates DEPLOY-001/002/003 test plans as Sprint 3 sizing deliverable | @tester + @orchestrator |
| WIP overflow (4 in-progress at Sprint 3 kickoff) | P2 | Mitigated 2026-06-19T19:25Z (flipped #130/131/132 → status:ready); now WIP=4 at per-agent limit | @orchestrator |

---

## Sprint 3 priority order

Per dependency analysis (DEPLOY-001 depends on DEPLOY-002 secrets which are now ready):

1. **DEPLOY-001** (P0) — developer started 2026-06-19T~20:00Z (branch `feat/deploy-001-trigger`, commit a5105ce)
2. **RETRO-003** (P1) — PM drafts at 2026-06-20T18:34Z (after Sprint 2 burn-in)
3. **TEMPLATE-PORT** (P1) — dev parallel to DEPLOY-001 (Issue #48 in-progress, owner unblocked gate 2026-06-18T21:56Z)
4. **DEPLOY-004** (P2) — deferred; Sprint 3 mid-sprint review (2026-06-27) decides pull-in or punt to Sprint 4

**Parallel work tracks:**
- Track A: DEPLOY-001 → DEPLOY-003 smoke validation → Sprint 3 DoD §4+§5
- Track B: RETRO-003 (PM) → retro publication
- Track C: TEMPLATE-PORT (dev + arch) → 7 port PRs

---

## Daily standup format

Per `docs/OPERATIONS.md` §2.2:
- `[Sprint 3] Daily Standup` issue, threaded comments per day
- 09:00 Europe/Istanbul
- Orchestrator posts, agents respond, blocker escalation to owner via Telegram

---

## Definition of Done (sprint-level)

Sprint 3 is **DONE** when ALL of:

1. All committed stories merged to main with owner approval (DEPLOY-001 workflow file owner-merge, DEPLOY-002 rotation doc, RETRO-003 PM+orch, TEMPLATE-PORT 7 PRs)
2. CI green on main post-merge
3. `docs/sprints/sprint-02/retrospective.md` written and merged (RETRO-003)
4. **Real-data validation**: deploy pipeline has fired ≥3 times successfully (3 owner merges to `main` auto-deploy without intervention)
5. **Smoke test validated**: DEPLOY-003 auto-rollback path has been tested at least once (intentional bad merge → rollback verified)
6. No new P0/P1 bugs filed against Sprint 3 stories within 24h
7. Sprint 4 backlog drafted (grooming-ready)

---

## Coordination issues

- **Issue #135** — Sizing ceremony (✅ closed with PM + owner ack; architect/developer/tester inputs in flight as amendments to this plan)
- **Issue #48** — Template port (in-progress, developer owner; owner unblocked gate 2026-06-18T21:56Z)
- **Issue #119** — dev-idle fix Katman 3 (parked; soul amendment owner-gated, low priority for Sprint 3)
- **Issue #102** — A11-ext doctrine gap (parked; owner decision pending in Sprint 3)

---

## Sizing ceremony inputs received

- ✅ @product-manager — scope final per PR #129 (ea018ad, 2026-06-19T19:12:30Z). No scope changes pending.
- ✅ @owner — keypair done 19:44Z, workflow approval within 24h of PR open, DEPLOY-003 already shipped, scope 10 SP, buffer 25-35 SP
- ⏳ @architect — pending (8 SP deploy budget + appleboy vs raw ssh + ADR-0019 amend-3 for /healthz endpoint)
- ⏳ @developer — pending (3 SP DEPLOY-001 sizing confirmation; branch already in flight)
- ⏳ @tester — pending (healthz regression test scope confirmation + DEPLOY-001/002/003 test plan regeneration per PR #133 loss)

Inputs will be amended into this plan.md as received (PR amends if material). Plan.md is **draft until all 5 inputs close**, but Sprint 3 starts 2026-06-20 with the current scope regardless.

---

## Carry-over from Sprint 1+2 (separate from this backlog, tracked in their own issues)

- **Issue #46** — TD-006 root cause fix (DONE in Sprint 2 via PR #108, closed)
- **Issue #65** — fastapi+uvicorn reclassify (Sprint 2 carry-over, dev owner, 22h+ in-progress, status:ready after #130/131/132 fix)
- **Issue #125** — cc:* auto-revert bug (Sprint 2 RCA complete TD-014, owner closure decision pending)
- **Issue #102** — A11-ext doctrine gap (Sprint 2 retro candidate, owner decision pending)

---

## Owner bandwidth summary

- 🔴 **Now (10dk)**: Sizing ceremony cevabı (✅ done at 19:54Z), #125 closure (A/B/C 2dk), #102 kararı (5dk)
- 🟡 **Sprint 3 day 1 (15dk)**: DEPLOY-001 workflow approval (10dk), Sprint 2 burn-in check (0dk)
- 🟢 **Sprint 3 boyunca (1 saat)**: mid-sprint review (15dk), deploy validation (5dk), smoke test (15dk), retro (30dk), Sprint 4 grooming (15dk)
- ⚪ **Düşük öncelik**: #119 Katman 3 soul amendment (10dk, Sprint 2 retro'ya aday)

**Total Sprint 3 owner bandwidth: ~1.5 saat** (14 gün dağılmış, çoğu <15dk parçalar).

---

— Orchestrator (Claude), 2026-06-19T19:55:00+03:00
