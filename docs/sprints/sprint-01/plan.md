# Sprint 1 — Foundation (2026-06-17 → 2026-07-01, 14 days)

<<<<<<< HEAD
> **Status:** 🟢 ACTIVE — kickoff complete (PR #32 merged 2026-06-17T20:23:26Z)
> **Scope source of truth:** [proposed-scope.md](proposed-scope.md) — 20 SP from sizing ceremony #22 (closed)
> **Capacity:** 5 agents × 14 days (orchestrator + PM + architect + developer + tester)
> **Sprint goal:** Lay the foundation that enables MVP-1 to ship in Sprint 2.
> **Last actuals update:** 2026-06-17T21:15Z (post PR #40 merge). Plan.md edited via branch `chore/sprint-01-actuals-pr40`.
=======
> **Status:** 🟢 ACTIVE — kickoff complete (PR #32 merged 2026-06-17T20:23:26Z, commit 2564081)
> **Scope source of truth:** [proposed-scope.md](proposed-scope.md) — 20 SP from sizing ceremony #22 (closed)
> **Capacity:** 5 agents × 14 days (orchestrator + PM + architect + developer + tester)
> **Sprint goal:** Lay the foundation that enables MVP-1 to ship in Sprint 2.
> **Post-merge hygiene (orchestrator):** plan.md updated 2026-06-17T20:26Z to reflect actual merge state (was DRAFT-stale, see git log for what was on main before PR #32).
>>>>>>> 09a2aa1 (chore(sprint): Sprint 1 plan.md post-merge hygiene (DRAFT→ACTIVE))

---

## Sprint Goal

Lay the foundation that enables MVP-1 (engine + keyboard-first web shell) to ship in Sprint 2:
<<<<<<< HEAD
- VM is production-ready (hardened) so HTTP surface can be exposed on LAN. → ✅ **Dev deliverable done** (PR #40, script + runbook + tests); ⏳ owner apply step on 192.168.1.199 pending
- Engine module is in place with decimal-precision 4-ops + percent + parentheses, mypy-clean, fully tested. → ✅ **DONE** (PR #26 STORY-002, merged)
- HTTP surface (FastAPI + static SPA shell) is in place with keyboard-only basic UX. → ⏳ **In progress** (STORY-003a core #30 ready, STORY-003b LAN-bind #31 blocked on #30 + VM apply)
- Doctrine gaps from Sprint 0 (issue #10 cc:tester removal) are resolved. → ✅ **DONE** (PR #36 design merged, PR #33 ADR-0019, Issue #10 closed by owner 2026-06-17T20:27Z)

## Sprint 1 actuals (live, day 0 evening)

**PRs merged (9):** #24, #26, #23 (closed/superseded), #29, #33, #34, #36, #32, #40 — see git log on main.

**Issues closed (5):** #12 (kickoff, by PR #32), #22 (sizing, by PR #32), #18 (STORY-004, by PR #13), #10 (doctrine, owner 20:27Z), #15 (STORY-001, by PR #40).

**Issues cancelled (1):** #38 (Sprint 2 P1 Option C verdict-sentinel) — owner decision 2026-06-17T21:13:31Z: "we are not going to do this update". Will NOT be in Sprint 2 scope.

**Open issues (3):** #30 (STORY-003a core, dev queue ready, blocked on PR #37), #31 (STORY-003b LAN-bind, blocked on #30 + VM apply), #35 (d007 observability, ships with #30).

**Open PRs (2):** #37 (STORY-003a TDD red contract suite, draft, awaiting architect verdict on 2 blocker asks), #39 (tech-debt doc, draft, sprint lens OK).

**Mid-sprint check:** 1 P0 done (#15 dev part), 1 P0 in-flight (#30 ready), 1 P0 blocked (#31). STORY-002 + STORY-006 done.
=======
- VM is production-ready (hardened) so HTTP surface can be exposed on LAN.
- Engine module is in place with decimal-precision 4-ops + percent + parentheses, mypy-clean, fully tested. ✅ **DONE** (PR #26, STORY-002, merged)
- HTTP surface (FastAPI + static SPA shell) is in place with keyboard-only basic UX. → **In progress** (STORY-003a + d007 follow-up, dev queue ready)
- Doctrine gaps from Sprint 0 (issue #10 cc:tester removal) are resolved. ✅ **DONE** (PR #36 STORY-005 design, merged; PR #33 R-3 ADR, merged; Issue #10 closable)

## Sprint 1 actuals (live)

**PRs merged to date (Sprint 1, day 0):**
- PR #24 — BUG #14 watcher dedup fix (re-fire suppression) — 8fb5889
- PR #26 — STORY-002 engine module (1042 lines) — be90555
- PR #23 — Engine TDD red (superseded by #26) — c279754 (closed)
- PR #29 — R-1 housekeeping (ADR-0017 + ADR-0018 → Accepted) — 213b170
- PR #33 — ADR-0019 R-3 HTTP API contract — 3f91b87
- PR #34 — Issue #25 fix (pr_comment_mention + issue_comment_mention content-stable) — 0d12df5
- PR #36 — STORY-005 verdict-sentinel design (Option C, Sprint 1 sign-off) — ecaba25
- PR #32 — Sprint 1 proposed scope (sizing ceremony #22 output) — 2564081

**Issues closed post-merge hygiene (this commit batch):** #12 (kickoff), #22 (sizing ceremony). Issue #18 (STORY-004) was already closed via PR #13.

**Open issues (live state):** #10 (recommend close — PR #36 resolved), #15 (STORY-001 VM hardening P0, **not started**), #30 (STORY-003a, dev queue ready), #35 (d007, ships with #30), #31 (STORY-003b, blocked on #30 + #15), #38 (Sprint 2 P1 follow-up, future).
>>>>>>> 09a2aa1 (chore(sprint): Sprint 1 plan.md post-merge hygiene (DRAFT→ACTIVE))

## Capacity & commitment

- **Sprint length:** 14 days (2026-06-17 → 2026-07-01)
- **Agent capacity:** 5 agents × 14 days ≈ 35-45 story-points (assuming 0.5–1 point/day/agent, given context-switching overhead)
- **Committed stories:** 4 main + 2 supporting
- **Stretch:** if velocity allows, persistence-layer ADR draft

---

## Committed stories (must-have)

### STORY-001 — VM hardening [P0, BLOCKER for any HTTP exposure]

**Status (2026-06-17T21:14Z):** ✅ **Dev deliverable MERGED** (PR #40, SHA 7136a20). ⏳ Owner apply step pending.

**Owner:** @developer (script + runbook + tests, completed) + @architect (review) + @human (apply on 192.168.1.199)
**Why P0:** vision.md §Operational Constraints — "Production-ready needs SSH-key auth, ufw firewall rules, fail2ban, password-auth disabled. **This is a Sprint 1 prerequisite for safely exposing the HTTP surface on the LAN**"

**Acceptance criteria:**
- [x] SSH key auth enabled, password auth disabled (`PasswordAuthentication no` in `sshd_config`) — script ready, owner applies
- [x] Root SSH login disabled (`PermitRootLogin no`) — script ready
- [x] `ufw` firewall active: default deny incoming, allow SSH + HTTP surface port — script ready
- [x] `fail2ban` installed and active for SSH — script ready (bantime=600s, maxretry=5, findtime=60s)
- [x] Backups: state file backup script (per OPERATIONS.md §6.2) + systemd timer (daily 02:00 UTC, retention 14 days)
- [x] Documented: `docs/ops/vm-hardening.md` (362 lines) with before/after state, applied commands, rollback steps
- [ ] Verification: from a fresh terminal, password SSH attempt fails, key SSH succeeds — **owner runs `verify_all()` post-apply**

**Out of scope:** HTTPS/TLS (Sprint 2), automated security updates (separate story), `--rollback` flag (P1 follow-up).

**Definition of done:** Story fully done when owner runs apply script on VM + verify_all() exit 0 + AC7 end-to-end checklist green. Issue #15 already auto-closed by PR #40 merge; owner apply step is implicit follow-up.

---

### STORY-002 — Engine module (MVP-1 core) [P0]

**Owner:** @developer (writes) + @architect (review) + @tester (signoff)
**Why P0:** vision M1 "first MVP ships with zero float errors" — engine is the heart of MVP-1.

**Acceptance criteria:**
- [ ] `src/atilcalc/engine/` package, pure-Python, no I/O (per ADR-0017 engine ↔ UI separation invariant)
- [ ] Four operations: `+`, `−`, `×`, `÷` with `decimal.Decimal` precision (M1: `0.1 + 0.2 == 0.3` passes)
- [ ] Parentheses support: `2 * (3 + 4) == 14`
- [ ] Percent operator: `100 + 5% == 105`
- [ ] `mypy --strict` clean on `src/atilcalc/engine/`
- [ ] `ruff check` clean
- [ ] `pytest` parametrized: ≥30 test cases including decimal edge cases (0.1+0.2, division by zero raises, large numbers, etc.)
- [ ] ≥90% coverage on `src/atilcalc/engine/`
- [ ] Public API documented (docstring on every public function)
- [ ] `CHANGELOG.md` [Unreleased] → Added entry

**Out of scope:** Scientific functions (trig, log, √, !) — Sprint 2 per owner Q3 answer.

**Definition of done:** Engine module merged to main, all tests green, mypy/ruff clean, no P0/P1 bugs filed within 24h.

---

### STORY-003 — Keyboard-first web shell [P0]

**Owner:** @developer (writes) + @architect (review of front-end framework choice — see STORY-005) + @tester (signoff)
**Why P0:** vision M3 "all basic operations reachable using keyboard only" — UX is the product.

**Acceptance criteria:**
- [ ] FastAPI backend with `/` route serving static SPA shell
- [ ] Static SPA: HTML + CSS + minimal JS, served from `src/atilcalc/web/`
- [ ] Keyboard-first: `0-9`, `+ − * /`, `Enter` (=), `Esc` (clear), `Backspace` (delete), `?` (help pop-up)
- [ ] Display: input line + result line, large readable font, dark skin default
- [ ] Calls engine module via internal HTTP API (e.g., `POST /api/evaluate` with `{expr: "2+3"}` → `{result: 5}`)
- [ ] Help pop-up (`?`) lists all keyboard shortcuts
- [ ] E2E test (Playwright or equivalent): digit entry → result via keyboard only
- [ ] Accessible from LAN: binds to 0.0.0.0:PORT, accessible at http://192.168.1.199:PORT
- [ ] `CHANGELOG.md` [Unreleased] → Added entry

**Out of scope:** History (Sprint 2), skin system (Sprint 2), scientific functions (Sprint 2).

**Definition of done:** Owner can open the URL in a browser, type `0.1 + 0.2` on keyboard, see `0.3` as result, no mouse needed.

---

### STORY-004 — Front-end framework ADR [P1]

**Owner:** @architect
**Why P1:** Sprint 1 STORY-003 says "minimal JS" but the PM question (vision §Open Questions, answered) says SPA. Architect needs to pick: vanilla JS + htmx, or a real SPA framework (Svelte/React/Vue). Vision §Operational Constraints note "minimum-dependency stack" → favors lean choice.

**Acceptance criteria:**
- [ ] New ADR `docs/decisions/ADR-NNNN-front-end-framework.md` (number assigned by architect)
- [ ] Compares ≥3 options: vanilla JS + htmx, Svelte (no build step possible?), single-file React/Vue (CDN-loaded)
- [ ] Recommendation justified against vision constraints (minimum-dep, AMD-friendly, low-memory, owner-comfort)
- [ ] Sprint 1 STORY-003 implementation reuses the chosen pattern
- [ ] Owner approves the ADR (status: Accepted)

**Definition of done:** ADR merged to main, status: Accepted, STORY-003 PR uses the chosen approach.

---

### STORY-005 — Doctrine: `verdict:*` sentinel label [P1, from issue #10]

**Owner:** @architect (label taxonomy decision) + @human (workflow merge — `.github/workflows/label-check.yml` change)
**Why P1:** Issue #10 root cause — every PR review cycle currently hits this doctrine conflict, generating stale_cc wake-loop noise.

**Acceptance criteria:**
- [ ] New labels created: `verdict:approved`, `verdict:changes-requested`, `verdict:pending` (via `bootstrap-labels.sh` amendment)
- [ ] `.github/workflows/label-check.yml` accepts `verdict:*` in the `cc:*` slot
- [ ] 5 soul docs §Handoff Discipline updated: `remove cc:<role>` → `remove cc:<role>` + `add verdict:<state>`
- [ ] Regression test: tester APPROVE on a PR → CI green, no stale_cc re-fire on that PR for 30 min
- [ ] PR filed with all 4 changes, owner merges

**Out of scope:** General label taxonomy redesign.

**Definition of done:** Label-check CI accepts `verdict:*`, soul docs updated, regression test green for ≥24h.

---

### STORY-006 — Watcher dedup fix completion [P1, from PR #9]

**Owner:** @tester (already opened PR #9, just needs merge) → @orchestrator (close #6 after merge)
**Why P1:** BUG #6 — every agent currently sees duplicate wake events on issue_assigned / label_change / pr_review_requested kinds. Wastes attention, pollutes logs.

**Acceptance criteria:**
- [ ] PR #9 merged to main (tester's content-hash ID fix)
- [ ] Agent state files (`/var/log/dev-studio/AtilCalculator/agent-state/*.json`) show `processed_event_ids` working: same event re-delivered → not re-processed
- [ ] `agent-doctor.sh` reports dedup count > 0 (proof the fix works)
- [ ] Issue #6 closed

**Definition of done:** PR #9 merged, `agent-doctor` shows dedup working, #6 closed.

---

## Stretch stories (nice-to-have, only if capacity allows)

### STORY-007 (stretch) — Persistence layer ADR

**Owner:** @architect
**Why stretch:** vision mentions history DB in M5, but Sprint 2 deliverable, Sprint 1'de ADR draft yeterli.

**Acceptance criteria:**
- [ ] New ADR `docs/decisions/ADR-NNNN-persistence-layer.md`
- [ ] Compares SQLite (file-based) vs JSON-flat-file vs nothing-yet
- [ ] Recommendation for Sprint 2 implementation
- [ ] Owner approves

### STORY-008 (stretch) — PR reviewer auto-assignment

**Owner:** @architect or @developer (implementation in `scripts/`)
**Why stretch:** Avoid "reviewer never assigned" class of bug that PR #9 hit.

**Acceptance criteria:**
- [ ] Script `scripts/auto-assign-reviewers.sh` reads PR labels and assigns reviewers per role
- [ ] Triggered from `agent-watch.sh` on new PR
- [ ] Tests: 3 PR scenarios (developer, architect, tester author) → correct reviewer assigned

---

## Risks & dependencies

| Risk | Severity | Mitigation |
|---|---|---|
| STORY-001 (VM hardening) blocks STORY-003b (LAN-bind) from LAN testing | P0 | **Dev deliverable DONE (PR #40)**; owner apply on 192.168.1.199 still pending — `sudo bash scripts/ops/apply-vm-hardening.sh` + runbook §AC7 verification |
| STORY-005 (verdict:* label) needs owner workflow merge — bottleneck | P1 | **CANCELLED** by owner 21:13Z (Issue #38 closed). Option C verdict-sentinel will NOT be implemented in Sprint 2 |
| Engine ↔ UI separation invariant must hold (vision.md, ADR-0017) | P0 | Architect reviews STORY-002 PR + STORY-003 PR for boundary compliance |
| Owner review bandwidth — Sprint 0 owner was bottleneck on PR #5, #8, #9 | P1 | Sprint 1 has more PRs (STORY-002, 003, 005) — owner needs to allocate review time. PM pings ahead. |

---

## Daily standup format

Per `docs/OPERATIONS.md` §2.2:
- `[Sprint 1] Daily Standup` issue, threaded comments per day
- 09:00 Europe/Istanbul
- Orchestrator posts, agents respond, blocker escalation to owner via Telegram

## Definition of Done (sprint-level)

Sprint 1 is **DONE** when ALL of:
1. All 6 committed stories merged to main with owner approval
2. CI green on main post-merge
3. `docs/sprints/sprint-01/retrospective.md` written
4. Sprint 2 backlog drafted (grooming-ready)
5. No P0/P1 bugs filed against Sprint 1 stories within 24h

— Orchestrator (Claude), 2026-06-17T18:13:00+03:00
