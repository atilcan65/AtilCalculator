# Sprint 1 — Proposed Scope (PM sizing consensus, awaiting owner commit)

> **Status:** 🟡 PM-aggregated consensus from [Issue #22](https://github.com/atilcan65/AtilCalculator/issues/22) sizing ceremony.
> **Source for stories:** orchestrator's [`docs/sprints/sprint-01/plan.md`](./plan.md) (DRAFT, 2026-06-17 18:13 +03:00).
> **Sizing input:** 4 sizing comments on #22 (architect 15:55Z, developer 16:01Z, tester 16:02Z, architect revision 17:26Z) + 1 architect follow-up (R-3 hard-dep, 18:27Z).
> **Capacity:** 35-45 SP (5 agents × 14 days, per `plan.md`).
> **Committed:** **20 SP** of work (44-57% capacity utilisation — comfortable buffer for unplanned work + ceremony time).
> **Already done (not in commit):** STORY-004 (PR #13 merged 17:19:13Z) and STORY-006 implementation (PR #9 merged 15:16:51Z; story remains open for verification + #6 close-out).

---

## Sprint goal (from `plan.md`)

Lay the foundation that enables MVP-1 (engine + keyboard-first web shell) to ship in Sprint 2:

- VM is production-ready (hardened) so HTTP surface can be exposed on LAN.
- Engine module is in place with decimal-precision 4-ops + percent + parentheses, mypy-clean, fully tested.
- HTTP surface (FastAPI + static SPA shell) is in place with keyboard-only basic UX.
- Doctrine gaps from Sprint 0 (issue #10 cc:tester removal) are resolved.

---

## Committed stories — PM consensus (Fibonacci)

| Story | Issue | Title | Priority | Arch SP | Dev SP | Test SP | **Consensus** |
|---|---|---|---|---|---|---|---|
| STORY-001 | [#15](https://github.com/atilcan65/AtilCalculator/issues/15) | VM hardening | P0 | 3 | 3 | 2 | **3** |
| STORY-002 | [#16](https://github.com/atilcan65/AtilCalculator/issues/16) | Engine module (4 ops, decimal precision) | P0 | 3 | 5 | 5 | **5** |
| STORY-003a | [#30](https://github.com/atilcan65/AtilCalculator/issues/30) | Web shell — core (FastAPI + 3 components + keyboard FSM) | P0 | 5 | 5 | 3 | **5** |
| STORY-003b | [#31](https://github.com/atilcan65/AtilCalculator/issues/31) | Web shell — deferred (3 components + E2E + LAN-bind) | P0 | 3 | 3 | 3 | **3** |
| STORY-003 (parent) | [#17](https://github.com/atilcan65/AtilCalculator/issues/17) | Keyboard-first web shell (family tracker) | P0 | — | — | — | family tracker |
| STORY-004 | [#18](https://github.com/atilcan65/AtilCalculator/issues/18) | Front-end framework ADR (vanilla JS + Web Components) | P1 | (author) | 2 | 2 | **DONE** (PR #13) |
| STORY-005 | [#20](https://github.com/atilcan65/AtilCalculator/issues/20) | Doctrine — verdict:* sentinel label (Option A) | P1 | 3 | 2 | 2 | **3** |
| STORY-006 | [#19](https://github.com/atilcan65/AtilCalculator/issues/19) | Watcher dedup completion + Issue #6 close-out | P1 | 1 | 1 | 1 | **1** |
| **Committed total (excl. done)** | | | | | | | **20 SP** |
| **Sprint 1 utilisation** | | | | | | | **44-57%** of 35-45 SP capacity |

**Sizing rule applied:** per `product-manager.md` §Hard Rules (Keep stories ≤ 5 SP; split if larger). Original STORY-003 sized at 8 SP by developer → split per developer's own recommended split boundary (003a = 5 SP, 003b = 3 SP). Architect's "do NOT split" rationale heard; PM's hard rule took precedence because the split boundary was architecturally clean (HTTP boundary + interaction FSM in 003a; deferred components + E2E + LAN-bind in 003b). See [Issue #17](https://github.com/atilcan65/AtilCalculator/issues/17) split comment for full rationale.

**Divergence flagged:** STORY-002 (architect 3 vs developer 5 vs tester 5) — PM took the max (5 SP) because engine is the risk and TDD red→green→polish cycle is real time. Architect's slice (design + boundary review, ~1h) is lighter than the implementation/test effort.

---

## Story-by-story detail

### STORY-001 — VM hardening [P0, blocker for any HTTP LAN exposure] — 3 SP — #15

- **Owner:** @developer (writes) + @architect (review of ufw/fail2ban config) + @tester (smoke test)
- **Why P0:** [`vision.md`](../../product/vision.md) §Operational Constraints — "Production-ready needs SSH-key auth, ufw firewall rules, fail2ban, password-auth disabled. **This is a Sprint 1 prerequisite for safely exposing the HTTP surface on the LAN**".
- **Acceptance criteria:** (from `plan.md`)
  - [ ] SSH key auth enabled, password auth disabled (`PasswordAuthentication no` in `sshd_config`)
  - [ ] Root SSH login disabled (`PermitRootLogin no`)
  - [ ] `ufw` firewall active: default deny incoming, allow SSH (custom port), allow HTTP surface port
  - [ ] `fail2ban` installed and active for SSH (default jail)
  - [ ] Backups: state file backup script + systemd timer
  - [ ] Documented: `docs/ops/vm-hardening.md` with before/after state, applied commands, rollback steps
  - [ ] Verification: from a fresh terminal, password SSH attempt fails, key SSH succeeds
- **Out of scope:** HTTPS/TLS (Sprint 2), automated security updates (separate story).
- **DoD:** Owner SSH-keys verified on the VM, all items green, ops doc merged to main.

### STORY-002 — Engine module (MVP-1 core) [P0] — 5 SP — #16

- **Owner:** @developer (writes) + @architect (review) + @tester (signoff)
- **Why P0:** vision M1 "first MVP ships with zero float errors" — engine is the heart of MVP-1.
- **Active state:** TDD-red contract suite drafted in [PR #23](https://github.com/atilcan65/AtilCalculator/pull/23) (PM verdict ✅ APPROVE at 16:17:44Z, AC3 hybrid percent convention applied); implementation in [PR #26](https://github.com/atilcan65/AtilCalculator/pull/26) (developer's TDD-green branch, in review).
- **Acceptance criteria:** (from `plan.md`)
  - [ ] `src/atilcalc/engine/` package, pure-Python, no I/O (per ADR-0017 engine ↔ UI separation invariant)
  - [ ] Four operations: `+`, `−`, `×`, `÷` with `decimal.Decimal` precision (M1: `0.1 + 0.2 == 0.3` passes)
  - [ ] Parentheses support: `2 * (3 + 4) == 14`
  - [ ] Percent operator: `100 + 5% == 105` (hybrid convention per PM verdict on #23 — see [issue #22 comment at 16:17:44Z](https://github.com/atilcan65/AtilCalculator/issues/22#issuecomment-4732735625))
  - [ ] `mypy --strict` clean on `src/atilcalc/engine/`
  - [ ] `ruff check` clean
  - [ ] `pytest` parametrized: ≥30 test cases including decimal edge cases
  - [ ] ≥90% coverage on `src/atilcalc/engine/`
  - [ ] Public API documented (docstring on every public function)
  - [ ] `CHANGELOG.md` [Unreleased] → Added entry
- **Out of scope:** Scientific functions (trig, log, √, !) — Sprint 2 per owner Q3 answer (in `vision.md` §Open Questions).
- **DoD:** Engine module merged to main, all tests green, mypy/ruff clean, no P0/P1 bugs filed within 24h.

### STORY-003a — Web shell core (FastAPI + 3 components + keyboard FSM) [P0] — 5 SP — #30

- **Owner:** @developer (writes) + @architect (review of front-end pattern reuse from ADR-0018) + @tester (signoff)
- **Why P0 split:** Parent STORY-003 (#17) sized at 8 SP by developer (>5 SP PM ceiling). PM split at the architecturally clean boundary: HTTP boundary + interaction FSM stays cohesive; deferred UI + E2E moves to 003b.
- **Acceptance criteria:** (per #30 body)
  - [ ] FastAPI backend with `/` route serving static SPA shell (`src/atilcalc/web/`)
  - [ ] 3 Web Components: `<atilcalc-display>`, `<atilcalc-keypad>`, `<atilcalc-history>` (per ADR-0018)
  - [ ] Keyboard FSM: 3 states (idle/typing/result), single global `keydown` listener with allowlist
  - [ ] Display: input line + result line, large readable font, dark skin default
  - [ ] Calls engine via `POST /api/evaluate` per R-3 (ADR-0019) contract
  - [ ] Help pop-up (`?`) lists all keyboard shortcuts
- **Dependencies:**
  - ADR-0018 (front-end framework decision) — **DONE** (PR #13 merged 17:19:13Z, R-1 housekeeping flipped to Accepted at 9241d76)
  - STORY-002 (engine `evaluate()` API exists) — **active in PR #26**
  - **R-3 (ADR-0019 — API contract ADR) — NEW HARD DEP** (architect committed to draft in this session per [Issue #22 comment 18:27:55Z](https://github.com/atilcan65/AtilCalculator/issues/22#issuecomment-4733492896))
- **Out of scope:** mode-toggle / help-popup / error-toast components (→ 003b), Playwright E2E (→ 003b), LAN-bind (→ 003b), history persistence (→ Sprint 2).
- **DoD:** 3 components rendering + keyboard FSM responsive + engine integration tests green; no P0/P1 bugs in 24h.

### STORY-003b — Web shell deferred (3 components + Playwright E2E + LAN-bind) [P0] — 3 SP — #31

- **Owner:** @developer (writes) + @tester (Playwright harness + E2E signoff)
- **Acceptance criteria:** (per #31 body)
  - [ ] 3 deferred Web Components: `<atilcalc-mode-toggle>`, `<atilcalc-help-popup>`, `<atilcalc-error-toast>`
  - [ ] Playwright E2E test: digit entry → result via keyboard only (M3 acceptance test)
  - [ ] LAN-bind: `0.0.0.0:PORT`, accessible at `http://192.168.1.199:PORT` (per vision §Operational Constraints)
  - [ ] `CHANGELOG.md` [Unreleased] → Added entry
- **Dependencies:**
  - STORY-003a (core shell ships first) — hard
  - **STORY-001 (VM hardening — ufw HTTP port + SSH key auth)** — hard; LAN test impossible without VM hardening
- **DoD:** E2E green on `http://192.168.1.199:PORT` from a fresh terminal; M3 acceptance test passes.

### STORY-003 (parent) — Keyboard-first web shell [P0] — family tracker — #17

- **Status:** Open with `agent:developer, status:backlog, cc:architect`. Body references 003 split.
- **PM recommendation to orchestrator:** close #17 once #30 + #31 land with a "Superseded by #30 (003a) + #31 (003b) per Sprint 1 sizing ceremony #22" comment. **PM does not close stories** (per `product-manager.md` §Hard Rules); flagging for orchestrator's bookkeeping step.

### STORY-004 — Front-end framework ADR [P1] — DONE — #18

- **Status:** ✅ **DONE.** ADR-0018 authored by @architect, PM verdict APPROVE at [PR #13 comment 4732266079](https://github.com/atilcan65/AtilCalculator/pull/13#issuecomment-4732266079) (15:24:14Z, vanilla JS + Web Components), owner merged at 17:19:13Z (commit 8a1fd89). R-1 housekeeping flipped status to Accepted at commit 9241d76.
- **No Sprint 1 work remaining** — issue #18 can be closed by orchestrator.

### STORY-005 — Doctrine: verdict:* sentinel label (Option A) [P1] — 3 SP — #20

- **Owner:** @architect (label taxonomy + label-check CI amendment) + owner (workflow merge for `.github/workflows/label-check.yml`)
- **Scope revision:** Originally scoped at 5-8 SP under Option C (full `verdict:*` label taxonomy). **Owner overrode on [Issue #10](https://github.com/atilcan65/AtilCalculator/issues/10) (Option A for Sprint 1, Option C deferred to Sprint 2 P1).** Revised scope per architect's [Issue #22 comment 17:26:21Z](https://github.com/atilcan65/AtilCalculator/issues/22#issuecomment-4733182990): design doc + 5 soul doc amendment text proposals + PR + Sprint 2 follow-up ticket.
- **Why P1:** Issue #10 root cause — every PR review cycle currently hits this doctrine conflict, generating stale_cc wake-loop noise.
- **Sizing consensus:** arch 3 (revised) / dev 2 / test 2 → **3 SP** (was higher under Option C).
- **Note:** `cc:human` label does not exist in repo (architect will auto-ping owner via `notify.sh` at PR-ready time per `CLAUDE.md` §Handoff Label Discipline).

### STORY-006 — Watcher dedup fix completion [P1] — 1 SP — #19

- **Owner:** @tester (verify dedup works) + @orchestrator (close Issue #6 post-verification)
- **Why P1:** BUG #6 — every agent currently sees duplicate wake events on `issue_assigned` / `label_change` / `pr_review_requested` kinds. Wastes attention, pollutes logs.
- **Status:** [PR #9](https://github.com/atilcan65/AtilCalculator/pull/9) (tester's content-hash ID fix) **merged 15:16:51Z** (commit 8628e68). Story = verify dedup works in production + close Issue #6.
- **Sizing consensus:** arch 1 / dev 1 / test 1 → **1 SP** (wrap-up only).
- **DoD:** PR #9 merged ✅, `agent-doctor.sh` shows dedup count > 0, Issue #6 closed.

---

## Dependency DAG (Sprint 1 commit order)

```
ADR-0017 Accepted (PR #5 merged 30c93f4)          ADR-0018 Accepted (PR #13 merged 8a1fd89)
   │                                                    │
   ▼                                                    ▼
STORY-002 Engine module (#16) ◄───── [ACTIVE: PR #23 + #26 in review]
   │
   ▼
R-3 (ADR-0019) API contract ADR  ◄──── [NEW: architect drafting in this session]
   │
   ▼
STORY-003a Web shell core (#30)          STORY-001 VM hardening (#15)  ◄── independent
   │                                            │
   │                                            │
   ▼                                            ▼
STORY-003b Web shell deferred (#31) ◄─── depends on both 003a + 001
   │
   ▼
Sprint 2 follow-ups (history, skins, scientific functions, Option C verdict:*)

STORY-005 verdict:* Option A (#20)  ◄── independent (parallel track)
STORY-006 dedup wrap-up (#19)       ◄── independent (PR #9 merged, verify + close #6)

STORY-003 parent tracker (#17)      ◄── close once #30 + #31 land
STORY-004 (#18)                      ◄── DONE, close
```

---

## Risks & mitigations

| Risk | Severity | Mitigation | Owner |
|---|---|---|---|
| R-3 (ADR-0019) blocks STORY-003a PR review | P0 | Architect committed to draft + open PR within the hour (per [Issue #22 comment 18:27:55Z](https://github.com/atilcan65/AtilCalculator/issues/22#issuecomment-4733492896)). STORY-003a developer holds off on PR until R-3 merges. | @architect |
| STORY-001 (VM hardening) blocks STORY-003b (LAN test) | P0 | STORY-001 must finish (or at least: SSH key + ufw allow HTTP port) before 003b LAN test. Localhost-only 003a work can proceed in parallel. | @developer |
| Decimal precision edge cases in engine (0.1+0.2, div-by-zero, large-number rounding) | P0 | TDD-red contract suite already authored (PR #23) with adversarial probes; 30+ parametrised test cases required. | @developer + @tester |
| Owner review bandwidth (Sprint 0 owner was bottleneck on PR #5, #8, #9) | P1 | Sprint 1 has 4 PRs needing owner merge (STORY-002, 003a, 005, R-3). PM pings ahead. STORY-003b is also owner-merge but sequenced later. | @orchestrator + PM |
| Engine ↔ UI separation invariant (vision.md, ADR-0017) | P0 | Architect reviews STORY-002 PR + STORY-003a/003b PRs for boundary compliance. | @architect |
| PR #23 superseded by PR #26 (engine implementation) | P1 | Per tester's [PR #23 comment at 17:33:37Z](https://github.com/atilcan65/AtilCalculator/pull/23#issuecomment-4733271005), contract suite content was merged into the `STORY-002-engine-module` branch (commit `c279754`). PR #23 effectively stale; can be closed by developer once PR #26 lands. | @developer |
| Sprint 2 P1 queue (Option C verdict:*, persistence ADR) not yet filed | P1 | Architect will file post-Sprint-1 per [Issue #22 comment 17:26:21Z](https://github.com/atilcan65/AtilCalculator/issues/22#issuecomment-4733182990). Not in Sprint 1 commit. | @architect |

---

## Definition of Done (sprint-level, from `plan.md`)

Sprint 1 is **DONE** when ALL of:

1. All 5 committed stories (excluding 003 parent tracker) merged to main with owner approval.
2. CI green on main post-merge.
3. `docs/sprints/sprint-01/retrospective.md` written.
4. Sprint 2 backlog drafted (grooming-ready).
5. No P0/P1 bugs filed against Sprint 1 stories within 24h.

---

## Sprint 2 P1 follow-up queue (NOT in Sprint 1 commit)

Filed post-Sprint-1 by @architect per [Issue #22 comment 17:26:21Z](https://github.com/atilcan65/AtilCalculator/issues/22#issuecomment-4733182990):

- **Option C `verdict:*` sentinel label** (full taxonomy, deferred from STORY-005)
- **STORY-007 (stretch)** — Persistence layer ADR (SQLite vs JSON-flat-file vs nothing)
- **STORY-008 (stretch)** — PR reviewer auto-assignment script
- **Sprint 2 must-haves** (from `vision.md` M2/M4/M5): history, skin system, scientific functions (if not in MVP-1)

---

## PM next actions (this PR's exit)

1. **This PR opens** with 4-cat labels (type:docs, status:in-review, agent:human, cc:orchestrator). Owner reviews + merges.
2. **Auto-ping orchestrator** with sizing consensus signal (per `product-manager.md` §Auto-Ping Hard-Rule).
3. **Auto-ping architect / developer / tester** with per-story sizing consensus for their records.
4. **Orchestrator publishes committed scope** (per `product-manager.md` §Sprint planning step 5) — PM does not own this step.
5. **PM stays in polling mode** for STORY-002/003a/003b PR review requests + the R-3 ADR review.

---

## Change log

- **2026-06-17T18:30Z** — Initial draft. PM-aggregated from Issue #22 sizing ceremony (4 comments + 1 R-3 follow-up). 20 SP committed (excl. STORY-004 done). Awaiting owner commit.
