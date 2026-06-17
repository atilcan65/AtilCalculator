# ADR-0017 — Tech stack for AtilCalculator

**Status:** Proposed
**Date:** 2026-06-17
**Deciders:** @architect (drafting), @atilcan65 (final approval), @product-manager + @developer + @tester (consulted via PR review)
**Supersedes:** —
**Related:** ADR-0010 (per-project watchers, Bash+systemd), ADR-0012 (label invariant), ADR-0014 (PROJECT_TOKEN canary), ADR-0016 (public-by-default). All bootstrap ADRs that constrain tooling cost.

---

## Context

`.claude/CLAUDE.md` §Tech stack carried the placeholder
`<FILL IN: languages, frameworks, infra. Architect maintains this.>` since
template render. Sprint 0 cannot start any feature story until that
placeholder is resolved — developer has nothing to scaffold, tester
nothing to wire, PM nothing to size against.

The product vision (`docs/product/vision.md`) is being drafted by
@product-manager in parallel (Issue #2). The orchestrator's coordination
issue (#3) explicitly says this work runs **in parallel** with vision
intake and is independent until PM needs feasibility input. So the
stack must be chosen with the **bootstrap-constraint set** as the only
hard input, plus a heuristic guess of product shape ("calculator").

### Hard constraints inherited from the template (ADR-0010 ff.)

| Constraint | Source | Implication |
|---|---|---|
| GitHub-native workflow (Issues, PRs, Projects v2, Actions) | ADR-0012, ADR-0013, ADR-0014 | CI runs on GitHub Actions; toolchain must install in <90s on `ubuntu-latest` |
| Bash + Python in `scripts/` (every agent tool, watcher, notify) | ADR-0010, ADR-0011 | Python already required at runtime → adding Python to product stack is **zero marginal toolchain cost** |
| systemd user-services on Linux for watcher cadence | ADR-0010 | Server-side product code, if any, runs as a long-lived process under systemd |
| Telegram notifications via shell pipe (`scripts/notify.sh`) | (template) | No coupling to product stack |
| Public repository default | ADR-0016 | No closed-source artefacts; license-compatible dependencies only |
| Pre-existing CI scaffold (`.github/workflows/ci.yml`) skips when `package.json` absent and runs Node 20 when present | template render | **Soft hint** the template expected Node, not binding |
| 4-cat label invariant + atomic hand-off | ADR-0012, ADR-0015 | No effect on product code |

### Soft constraints (product-shape guesses, pre-vision)

The product is called **AtilCalculator**. Without `docs/product/vision.md`,
the architect treats this as a **two-way-door problem** (Bezos): pick a
stack where the calculator's **computation engine is a pure library**
that can be wrapped by a CLI today and a web/mobile/service frontend
tomorrow. The wrong stack here is one that bakes the UI surface into
the engine.

Sub-cases the stack must keep open:
1. CLI calculator (`atilcalc 2+2`)
2. Web calculator (browser-rendered keypad, eval server-side or in WASM)
3. HTTP API (`POST /eval` returning JSON) — for embedding in other tools
4. Library import (`pip install atilcalc` / `npm i atilcalc`) — for power users scripting

A stack that nails (1) and leaves (2)–(4) cheap is the target.

---

## Decision

**Adopt Python 3.11+ as the primary language for AtilCalculator, with `pytest` for tests, `ruff` for lint, and Typer for CLI scaffolding. The expression engine is a pure-Python module with no UI dependencies; UI surfaces (CLI now, HTTP API or WASM later) wrap that module.**

### Concrete stack — minimal first cut

| Layer | Tooling | Why |
|---|---|---|
| Language | **Python 3.11+** | Bootstrap scripts already require Python; zero new CI install step. `decimal.Decimal` solves float-precision arithmetic out of the box. |
| Package manager | **`pip` + `pyproject.toml` (PEP 621)** | Stdlib-friendly, no `poetry`/`pdm` lock-in. Editable installs (`pip install -e .`) make dev → test loop tight. |
| Test framework | **`pytest`** | Industry default, parametrisation native, fixture model maps cleanly onto tester's TDD-red-first workflow. |
| Lint / format | **`ruff`** (lint+format) | One binary, replaces flake8 + black + isort. Runs in ms. |
| Type check | **`mypy --strict`** on the engine module only | Pure-function engine = high-leverage typing target. UI code stays untyped for now (deferred until non-CLI surface lands). |
| CLI scaffolding | **`typer`** (built on Click) | Declarative, type-hint driven, generates `--help` automatically. Easy to swap for argparse if Typer pulls in too much. |
| Numeric precision | **`decimal.Decimal`** (stdlib) | Avoids IEEE-754 surprises. `0.1 + 0.2 == Decimal("0.3")` works correctly. |
| HTTP (future) | **FastAPI** (deferred) | Listed for direction only; not adopted in this ADR. PM must request the HTTP surface before we add it. |
| Build / packaging | **`python -m build`** (sdist + wheel) | Stdlib path, no `setuptools`-vs-`hatch` debate. |
| Distribution (future) | **PyPI** publish + optional **PyInstaller** for single-binary CLI | Deferred to a release-time ADR. |
| Runtime infra | **systemd user-service** (only if HTTP surface lands) | Aligned with ADR-0010 watcher pattern. No new infra primitives. |

### Repository layout

```
src/
  atilcalc/
    __init__.py
    engine/         # Pure-function expression engine (no I/O)
      __init__.py
      parser.py
      evaluator.py
    cli/            # Typer app — depends on engine, not vice versa
      __init__.py
      __main__.py
tests/
  engine/           # pytest, parametrised; mirrors src/atilcalc/engine
  cli/              # CliRunner-based, mirrors src/atilcalc/cli
pyproject.toml      # PEP 621 metadata, [project] + [tool.ruff] + [tool.pytest.ini_options]
```

The **engine ↔ UI separation** is the load-bearing decision; everything
else is a swappable detail.

### CI implications

`.github/workflows/ci.yml` currently scaffolds for Node (`package.json`
gate). The first developer story under this ADR must:
- add a `pyproject.toml` so `pip install -e .[dev]` works
- update `ci.yml` to detect `pyproject.toml` and run `ruff check`, `mypy src/atilcalc/engine`, `pytest -q`

The CI edit is a `.github/workflows/` change → human-only per
`CLAUDE.md` §Things agents must NEVER do. Architect/developer **propose**
the diff via PR; human merges. This ADR documents the *intent*; the
actual workflow PR is a separate change tracked by the first dev story.

### What this ADR does *not* decide

- **Front-end framework** (React / Vue / Svelte / WASM). Deferred until PM
  asks for a non-CLI surface. Picking now would be a one-way door against
  a non-existent requirement.
- **Persistence layer** (SQLite / Postgres / none). Deferred. A calculator
  may not need persistence at all; if "history" becomes a story, a fresh
  ADR adds it.
- **AuthN/AuthZ**. Deferred. A pure-eval CLI has none; an HTTP API would
  trigger a security-scoped ADR.
- **Telemetry / observability**. Deferred until a long-lived surface
  exists. The engine itself emits no metrics; structured logs land when
  the HTTP/UI surface lands.

---

## Alternatives considered

### A. Python 3.11 + pytest + Typer (chosen)

- **Pros**: zero new CI install cost; matches existing bootstrap toolchain
  (scripts are Python); `decimal.Decimal` solves precision; tightest
  TDD loop on `ubuntu-latest`; pure-function engine is naturally
  type-checkable.
- **Cons**: weak in-browser story (would need WASM via Pyodide or a
  rewrite to JS); CPython startup ~50 ms feels slow for a one-shot CLI;
  packaging culture is more contested than Node's (poetry vs hatch vs pip).
- **Verdict**: **Chosen.** The pros are aligned with concrete current
  constraints; the cons are deferred problems (browser, perf) that
  don't bind until PM asks for them.

### B. TypeScript / Node.js 20 + Vitest + Commander

- **Pros**: CI already scaffolded for Node 20 (template hint); huge
  package ecosystem; clean pivot to Next.js or Vite for a web surface;
  `npm i -g atilcalc` is one command.
- **Cons**: introduces a second toolchain (Python for scripts/, Node for
  product) → CI must install both for any combined workflow; floating-
  point arithmetic requires `decimal.js` (not stdlib, extra dep); JS
  async noise creeps into synchronous arithmetic; lock-file churn is
  worse than `pyproject.toml`.
- **Verdict**: Rejected. The CI hint is soft (the workflow's
  `package.json` gate is purely opportunistic). Forcing two toolchains
  for a calculator is not worth the future browser pivot, which Pyodide
  or a thin BFF could also serve.

### C. Go 1.22 + standard testing + Cobra

- **Pros**: single static binary (trivial distribution); `math/big`
  for precision; fast startup; strong concurrency primitives if the
  product ever grows to a server.
- **Cons**: new toolchain in CI (`actions/setup-go`); calculator has
  no concurrency need; weakest of the three for browser pivot
  (TinyGo+WASM is a long road); ergonomics of generics-light arithmetic
  code is bumpy compared to Python.
- **Verdict**: Rejected. Go's strengths are wasted on a calculator's
  workload; its costs (toolchain, browser story) are paid for nothing.

### D. Rust + cargo + clap (engine in Rust, WASM frontend)

- **Pros**: maximum runtime performance; memory-safe; WASM target is
  first-class for a future web surface; `rust-decimal` for precision.
- **Cons**: cold-compile time on `ubuntu-latest` is ~3–5 min for a
  trivial project; ramp-up cost is real (lifetime, ownership);
  premature optimisation per ADR heuristic — a calculator does not
  need Rust's perf budget; tooling cost dwarfs problem complexity.
- **Verdict**: Rejected. Violates "boring tech wins" and "design for
  the next order of magnitude, not the next ten." Reconsider only if a
  future story actually demands sub-millisecond eval.

### E. Bash-only with bats-core for tests

- **Pros**: zero new toolchain (the entire dev-studio is Bash anyway);
  no install step; pipes well with the existing `scripts/` style.
- **Cons**: Bash arithmetic is integer-only (`$(( ))`); `bc` and `awk`
  patch floats but with awkward syntax; `bats-core` testing exists but
  has weaker parametrisation than `pytest`; no realistic path to a
  web/library surface.
- **Verdict**: Rejected. The toolchain savings are real but the
  product surface ceiling is too low; we'd be rewriting at the first
  user request beyond CLI.

### F. Defer the choice until PM vision lands

- **Pros**: avoids guessing about non-CLI surfaces; lowest commitment.
- **Cons**: blocks Sprint 1 indefinitely; PM's vision intake takes its
  own time; developer + tester are idle in the meantime. The whole
  point of running #3 in parallel with #2 is to **not** block on
  vision.
- **Verdict**: Rejected. The orchestrator's Issue #3 explicitly
  authorised parallel work; deferring violates the orchestrator's
  scope call. The pure-engine + thin-wrapper architecture **is** the
  way to defer the UI-surface decision without deferring the engine.

---

## Consequences

### Positive

1. **CI install cost is zero**: Python is already on every dev-studio
   workstation and on `ubuntu-latest` by default. No new `setup-*`
   action required for the engine; only `pip install -e .[dev]`.
2. **Engine portability is preserved**: the pure-function engine can be
   wrapped by Typer (today), FastAPI (later), or compiled via Pyodide
   to WASM (later still) without rewriting the arithmetic.
3. **Test loop is tight**: `pytest -q` on the engine completes in
   <1 s for typical specs; tester's TDD-red phase costs nothing in CI
   minutes.
4. **`decimal.Decimal` removes a class of bugs**: tester can write
   "0.1 + 0.2 == 0.3" assertions without inventing a float-tolerance
   fixture.
5. **Stack matches author skill**: the dev-studio agents are Python-
   fluent (scripts/ track record). No ramp.

### Negative / risks

1. **Native-binary distribution path is non-trivial**. PyInstaller
   works but is slow and produces large bundles. If PM ships a
   single-binary CLI for power users, that's a follow-up ADR (`R-1`
   below).
2. **Browser pivot requires extra work**. If PM picks a web surface,
   the engine must be either (a) wrapped by FastAPI as a backend
   service, or (b) compiled to WASM via Pyodide. Both are doable;
   neither is free. Tracked as `R-2`.
3. **CPython startup latency** (~50 ms) is visible on one-shot CLI
   invocations. Tolerable for v1; would matter if shell-heavy users
   run thousands of calcs/sec. Mitigation: a future `atilcalcd`
   daemon mode (deferred).
4. **Lock-in to Python's packaging history**. PyPI publish flow is
   well-trodden but has its own toolchain choices (twine vs hatch vs
   build). We default to stdlib `build` to minimise surface.

### Follow-up tickets to file (after this ADR is accepted)

- `R-1`: Distribution-mode ADR — when PM requests single-binary CLI,
  decide PyInstaller vs Nuitka vs PyPI-only.
- `R-2`: UI-surface ADR — when PM requests non-CLI surface, decide
  FastAPI backend vs Pyodide-WASM vs full JS rewrite.
- `R-3`: Update `.github/workflows/ci.yml` to detect `pyproject.toml`
  and run `ruff`/`mypy`/`pytest`. This is a `.github/workflows/`
  change → **human-merged PR**, not architect-or-developer-merged.
  Tracked as a developer story dependent on this ADR.
- `R-4`: First developer story should scaffold `src/atilcalc/engine/`
  and `pyproject.toml`. PM creates the story; sizing is **XS** if the
  engine is just "parse and evaluate `+ - * /` on integers/decimals",
  **S** if precedence + parentheses included from day one.

### Tech-debt entries opened

None at acceptance. The deferred UI/distribution decisions are not
debt — they are explicit "irreversibility budget" the architect is
holding for the PM's vision. Re-evaluate if PM vision lands within
this sprint.

---

## Open questions (PR review please address)

- [ ] **@product-manager**: does the calculator vision rule out a CLI-first
  shape? If the MVP is a web app, A's engine-first design still holds,
  but `R-2` becomes a P1 follow-up immediately.
- [ ] **@developer**: any objection to Typer? It pulls in Click as a
  dependency; some prefer pure argparse. Speak up before story R-4.
- [ ] **@tester**: pytest + parametrisation matches your TDD workflow?
  Or would you prefer hypothesis property-based tests as the default?
  (Hypothesis can be added later as an optional dev-dep.)
- [ ] **@atilcan65**: approval gate per Issue #3 AC — please comment
  "approved" on Issue #3 once this ADR is sound.

---

## References

- Bootstrap ADRs that constrain this choice:
  - [ADR-0010 — Per-project systemd watchers](./ADR-0010-per-project-watchers.md)
  - [ADR-0012 — Required label set](./ADR-0012-required-label-set.md)
  - [ADR-0014 — PROJECT_TOKEN canary](./ADR-0014-project-token-secret.md)
  - [ADR-0016 — Public-by-default](./ADR-0016-public-by-default.md)
- PEP 621 (`pyproject.toml` [project] metadata):
  https://peps.python.org/pep-0621/
- `decimal` stdlib (precision arithmetic):
  https://docs.python.org/3/library/decimal.html
- Typer (CLI scaffolding): https://typer.tiangolo.com/
- ruff (lint+format): https://docs.astral.sh/ruff/
- Bezos one-way-door heuristic (cited in soul):
  internal — see `.claude/agents/architect.md` §Decision-making heuristics.

---

## Acceptance gate

This ADR moves from **Proposed → Accepted** when:
1. @atilcan65 comments "approved" on Issue #3.
2. PR (this doc) is merged to `main` with developer + tester + PM sign-off
   recorded as PR reviews.
3. `.claude/CLAUDE.md` §Tech stack section is updated in the same PR.
4. `docs/decisions/INDEX.md` lists ADR-0017.
