# Sprint 1 — Foundation (2026-06-17 → 2026-07-01, 14 days)

> **Status:** 🟡 DRAFT — planning ready, **PR #5 + PR #9 merge sonrası kickoff**
> **Kickoff gate:** PR #5 (ADR-0017 reframe → Accepted) + PR #9 (watcher dedup fix → MERGED) + Issue #11 owner answers (✅)
> **Capacity:** 5 agents × 14 days (orchestrator + PM + architect + developer + tester)
> **Sprint goal:** Lay the foundation that enables MVP-1 to ship in Sprint 2.

---

## Sprint Goal

Lay the foundation that enables MVP-1 (engine + keyboard-first web shell) to ship in Sprint 2:
- VM is production-ready (hardened) so HTTP surface can be exposed on LAN.
- Engine module is in place with decimal-precision 4-ops + percent + parentheses, mypy-clean, fully tested.
- HTTP surface (FastAPI + static SPA shell) is in place with keyboard-only basic UX.
- Doctrine gaps from Sprint 0 (issue #10 cc:tester removal) are resolved.

## Capacity & commitment

- **Sprint length:** 14 days (2026-06-17 → 2026-07-01)
- **Agent capacity:** 5 agents × 14 days ≈ 35-45 story-points (assuming 0.5–1 point/day/agent, given context-switching overhead)
- **Committed stories:** 4 main + 2 supporting
- **Stretch:** if velocity allows, persistence-layer ADR draft

---

## Committed stories (must-have)

### STORY-001 — VM hardening [P0, BLOCKER for any HTTP exposure]

**Owner:** @developer (closest to VM) + @architect (review of ufw/fail2ban config)
**Why P0:** vision.md §Operational Constraints — "Production-ready needs SSH-key auth, ufw firewall rules, fail2ban, password-auth disabled. **This is a Sprint 1 prerequisite for safely exposing the HTTP surface on the LAN**"

**Acceptance criteria:**
- [ ] SSH key auth enabled, password auth disabled (`PasswordAuthentication no` in `sshd_config`)
- [ ] Root SSH login disabled (`PermitRootLogin no`)
- [ ] `ufw` firewall active: default deny incoming, allow SSH (custom port), allow HTTP surface port (Sprint 1'de belli olur)
- [ ] `fail2ban` installed and active for SSH (default jail)
- [ ] Backups: state file backup script (per OPERATIONS.md §6.2) + systemd timer
- [ ] Documented: `docs/ops/vm-hardening.md` with before/after state, applied commands, rollback steps
- [ ] Verification: from a fresh terminal, password SSH attempt fails, key SSH succeeds

**Out of scope:** HTTPS/TLS (Sprint 2), automated security updates (separate story).

**Definition of done:** Owner SSH-keys verified on the VM, all above items green, ops doc merged to main.

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
| STORY-001 (VM hardening) blocks STORY-003 (web shell) from being tested on the LAN | P0 | STORY-001 must finish first (or at least: SSH key + ufw allow HTTP port) before STORY-003 LAN test |
| STORY-005 (verdict:* label) needs owner workflow merge — bottleneck | P1 | Schedule early in sprint, parallel with STORY-002/003 |
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
