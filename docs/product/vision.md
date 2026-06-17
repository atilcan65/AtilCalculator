# Product Vision — AtilCalculator

> Source: [Issue #4](https://github.com/atilcan65/AtilCalculator/issues/4) (owner-submitted 2026-06-17 via the `vision-intake.yml` template; PM-canonicalised into this document 2026-06-17).
>
> **Language note**: the owner's original intake is in Turkish. This document is a clean-up English translation for the dev-studio team — English is the project's working language (per `CHANGELOG.md`, the existing `docs/decisions/ADR-00xx-*.md` set, and the agent `*.md` files). Owner-facing artefacts (README, in-app help, skins) may still be Turkish at the owner's discretion; that's a per-story decision, not a vision-level one.
>
> **PM invariants honoured**: (a) no scope invented beyond what the owner wrote; (b) every section is traceable to a field in the vision-intake form; (c) Open Questions flagged where PM needed to disambiguate, not silently decided.

## Statement

**AtilCalculator is a minimal, keyboard-first, history-keeping, skin-changeable web calculator with scientific function support. Self-hosted on the owner's home Linux server, it serves daily and advanced calculation needs in a single always-open browser tab.**

## Core Problem

Today the owner uses the operating system's bundled calculator or ad-hoc online sites. The recurring pains are:

- **IEEE 754 float errors** in routine arithmetic — `0.1 + 0.2 ≠ 0.3` shows up often enough to erode trust.
- **No persistent, cross-device history** — calculations are lost when the tab closes, or locked to one device / one session. There is no way to find "that calculation from last Tuesday" two weeks later.
- **Scientific and simple UX rarely coexist** — basic-mode calculators can't do trigonometry; scientific ones drown the simple operations under a panel of buttons.
- **Mouse-driven by default** — most calculators force the user to leave the keyboard for routine input.
- **No skin/theme control** — the owner's reading-style preference (dark / light / retro / minimal) changes day to day; the standard calculators don't accommodate.
- **Privacy and control** — online calculators leak inputs (and the act of searching) to third parties. The owner wants a self-hosted tool under their own control on their own hardware.

The product dissolves all of the above with a single always-open browser tab, usable keyboard-only, with LAN-synced history, switchable skins, and exact decimal arithmetic.

## Target Users

See [`docs/product/personas.md`](./personas.md) for the full persona spec. Summary:

- **P1 — "Atil" (the owner-operator)**: Primary persona. Software/infrastructure professional, keyboard-intensive, 5–20 calculations/day, always-open tab on the LAN.
- **P2 — "Home guest" (NOT in MVP)**: Future multi-user extension. LAN access without auth, shared namespace. Explicitly out of MVP per the vision's non-goals.

## Success Metrics (M1–M5)

- **M1 — Accuracy**: First MVP ships with **zero float errors**. Acceptance test `0.1 + 0.2 == 0.3` passes, alongside a broader parametrised regression suite covering decimal precision edge cases.
- **M2 — Daily-use stickiness**: The owner uses the calculator **≥5 times per day for 7 consecutive days** without falling back to OS/online tools. Proxy signal: history records ≥35/week.
- **M3 — Keyboard-only**: **All basic operations** (digit entry, operators, equals, clear, delete, history nav) are reachable using the keyboard only. Direct digit/operator keys; `Enter` = equals; `Esc` = clear; `Backspace` = delete. Verified by an E2E test (Playwright or equivalent).
- **M4 — Skin transition**: Switching between the ≥3 built-in skins completes in **<500 ms with no visual flicker**. Skin preference persists across sessions and across devices on the LAN.
- **M5 — History performance**: The history view opens in **<100 ms with 1,000+ records**, supports substring search, and lets the user click any record to load it back into the input.

## Top-3-to-5 must-haves for v1 (intentionally four, kept tight)

- **Core calculation engine** — four operations (`+ − × ÷`), parentheses, exponent (`^`), percent (`%`), square root (`√`), factorial (`!`), trigonometry (`sin` / `cos` / `tan` + rad/deg toggle), logarithm (`log` / `ln`), constants (`e`, `π`). **Exact decimal arithmetic** — no IEEE-754 surprises. Per the architect's framing in [ADR-0017](https://github.com/atilcan65/AtilCalculator/pull/5) (currently in PR-review; architect will reframe per PM business verdict), this is a **pure-function module with no I/O**, wrappable by any UI surface.
- **Keyboard-first web UX** — always-open browser tab, mouse optional. Built-in keyboard help pop-up (triggered by `?`).
- **Persistent cross-device history** — every completed expression + result is stored in the backend (not browser `localStorage`), chronological list, click-to-load, substring search. **Multi-device** because the owner moves between desktop and laptop on the same LAN.
- **Skin system** — at least 3 ready skins (Dark, Light, Retro / terminal-green). Skins are CSS-variable-set files; adding a new skin = adding one file (developer-side, not user-side).

> PM note: graphs, function plotting, unit conversion, programmer mode, custom-skin UI, and offline / PWA are all **explicitly out of MVP** — see Out-of-scope below. The list stops at four to keep the v1 surface small and shippable.

## Out of Scope (MVP)

- Multi-user / authentication
- Mobile-first responsive layout (desktop browser is the target; mobile "working" is a bonus, not a design constraint)
- Graphing / function plotting
- Unit conversion (km ↔ mile, kg ↔ lb, °C ↔ °F, etc.)
- Programmer mode (hex / binary / bitwise)
- Custom skin creation UI (a new skin = a developer adds a CSS file; no in-app editor in v1)
- Offline / PWA (LAN connectivity is assumed; no service worker, no offline cache)
- Cloud sync (self-host stays on the owner's own server; no third-party sync, no remote backup service)

## Operational Constraints

- **Host**: Owner's home LAN Linux VM, **Ubuntu 24.04 LTS**.
- **IP**: `192.168.1.199` (LAN-only; **not** exposed to the public internet).
- **Current VM state**: Fresh install; only the SSH port is open; no other services installed yet.
- **Sudo user**: `atilcan`.
- **Security gap to address in Sprint 0 / Sprint 1**: root SSH login + password authentication are currently enabled. Production-ready needs SSH-key auth, `ufw` firewall rules, `fail2ban`, password-auth disabled. **This is a Sprint 1 prerequisite for safely exposing the HTTP surface on the LAN** — flagged as a separate story, not an engine-code concern.
- **Backup**: History DB needs a periodic backup plan. **Not yet scoped**; PM + Architect will scope this with the persistence-layer story in Sprint 2.
- **Secrets**: VM access credentials are **not** stored in this repository. They live in `~/.dev-studio-env` on the VM itself.
- **Repo convention**: Direct push to `main` is forbidden (enforced by local pre-push hook + branch protection). All changes go through PRs; only the owner merges.

## Workflow Constraints (inherited from `dev-studio-template`)

- **5 Claude Code agents** — Orchestrator, Product Manager, Architect, Developer, Tester.
- **ADR-driven** — every architecture-shaping decision gets an `ADR-NNNN-*.md` in `docs/decisions/`.
- **Telegram notifications** — severity-based, routed via `scripts/notify.sh`.
- **Sprint cadence** — 2-week sprints; current state is Sprint 0 (bootstrap), not yet committed.

## Timeline (rough estimate from owner)

- **No rush**. Correctness and documentation are prioritised over speed.
- **MVP-1** (engine + keyboard-first web UI): **~2 sprints**.
- **MVP-2** (history + skin system): **+1 to 2 sprints**.
- **Scientific functions placement** (trig, log, √, !): PM + Architect to decide. Could land in MVP-1 for parity with the vision's "bilimsel fonksiyon destekli" line, or in MVP-2 if MVP-1 ships only the four ops + percent. See Open Questions.

## Tech Stack Direction (architect-decided; not PM-decided)

- **Direction is set by [ADR-0017](https://github.com/atilcan65/AtilCalculator/pull/5)** — Python 3.11+, `pytest`, `ruff`, `mypy`, `Typer`, `decimal.Decimal`. **Engine ↔ UI separation** is the load-bearing decision; everything else is swappable.
- **PM business verdict on ADR-0017** (comment on the PR): engine layer and the separation are **approved as-is**; the **CLI-first framing** in §Decision needs to be reframed to **engine-first / web-first delivery, CLI as a thin wrapper later**, because the vision's primary surface is the always-open browser tab, not the CLI. Architect downgraded the PR to draft in agreement; reframed version expected.
- **Owner preference hint** (from intake): minimum-dependency stack, AMD/Linux-ecosystem friendly, low-memory footprint. Owner is comfortable with Proxmox, Docker, systemd, nginx. PM is not blocking on these.
- **Front-end framework** is a separate ADR; PM will request it as a Sprint 1 workstream (see Open Questions).

## Open Questions

These are the items PM needs an answer on (or has flagged for a follow-up) before Sprint 1 backlog grooming. **PM will not invent stories around these** — each gets a clear answer first.

- [ ] **@atilcan65** — Is the always-open browser tab a **single-page web app** (likely FastAPI + static SPA — better for the skin system, client-side state, and keyboard handling) or a **server-rendered HTML+JS** approach (lighter, less interactive)? PM is leaning SPA for the skin system + keyboard-first UX. → owner
- [ ] **@atilcan65** — The existing `CHANGELOG.md` references FastAPI `/healthz` + `/hello/{name}` (STORY-001/002/004) and a SIGTERM handler (fix #61). Are these **historical references from the dev-studio-template** (PM's default assumption), or **v1 scope you want revived verbatim**? → owner
- [ ] **@atilcan65** — Should scientific functions (trig, log, √, !) land in **MVP-1** (parity with the vision's "bilimsel fonksiyon destekli" wording) or in **MVP-2** with the skin system? → owner
- [ ] **@atilcan65** — Backup cadence for the history DB: daily snapshot, weekly snapshot, or on-demand? PM recommends daily snapshot, weekly off-site sync (when Sprint 2 brings persistence). → owner
- [ ] **@atilcan65** — Docs language: keep this vision document English-only (current state, matches project convention), or add a Turkish mirror section for owner-facing reference? → owner
- [ ] **@architect** — The engine ↔ UI boundary in ADR-0017 — is that a separate ADR, or a one-line note in ADR-0017? PM prefers a separate ADR so the boundary is independently discoverable. → architect
- [ ] **@architect** — Persistence layer (SQLite vs flat file vs nothing) — when does this become an ADR? Likely Sprint 2, not Sprint 1. → architect
- [ ] **@architect** — VM hardening story (SSH key auth, `ufw`, `fail2ban`, password-auth off) — this is a Sprint 0/Sprint 1 ops story, separate from engine code. Who owns it — `@developer` (closest to the VM) or a dedicated "ops" agent? → architect + orchestrator

## PM Next Steps

1. **Open a docs PR** with this `vision.md`, `personas.md`, and the initial `docs/backlog.json` (empty, awaiting Sprint 1 grooming after the architect ADR settles).
2. **Sprint 1 backlog drafting** (per `product-manager.md` §Sprint planning) begins **only after**:
   - This vision PR merges.
   - ADR-0017 reframes per the PM business verdict and moves to Accepted.
   - Architect drafts a front-end-framework ADR (or commits to a Sprint 1 decision).
3. **PM will not invent Sprint 1 stories** before all three conditions above hold, per `product-manager.md` §Vision Intake anti-patterns.
4. Once the conditions hold, PM will file Sprint 1 stories for: (a) the engine, (b) the keyboard-first web shell, (c) the HTTP surface, (d) VM hardening, and (e) the persistence-layer ADR scope. These will reference the Open Questions above and will only proceed with explicit owner answers.

## Change Log

- **2026-06-17** — Initial draft. PM-canonicalised from [Issue #4](https://github.com/atilcan65/AtilCalculator/issues/4). Awaiting owner review.
