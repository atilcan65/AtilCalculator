# Tech Stack Candidates — pre-vision notes

**Status:** Throwaway notes (per @atilcan65 ruling on Issue #3, comment 2026-06-17T13:23Z)
**Author:** @architect
**Sprint:** 0 (bootstrap)
**Locked until:** Issue #2 (vision intake) merges
**Becomes:** ADR-0017 after vision lands + human approves a candidate

> ⚠️ This is **not** an architectural decision. It is the architect's
> pre-work — alternatives explored, constraints catalogued, leaning
> recorded — so that once `docs/product/vision.md` lands the ADR can
> be written in one sitting rather than from scratch.
>
> Per Issue #3 owner ruling: no stack is **chosen** until vision merges
> and human approves the candidate list.

---

## Constraints inherited from bootstrap (hard, vision-independent)

These constraints hold no matter what the calculator turns out to be.

| Constraint | Source | Implication |
|---|---|---|
| GitHub Actions CI on `ubuntu-latest` | template | Toolchain must install in <90s |
| Python already required by `scripts/` (watcher, notify, init) | ADR-0010 | Python adds zero CI install cost |
| systemd user-services for long-lived processes | ADR-0010 | If product runs server-side, runs under systemd |
| Telegram via `scripts/notify.sh` | template | No coupling to product stack |
| Public repo, MIT-style license-compatible deps | ADR-0016 | No closed-source artefacts |
| 4-cat label + atomic handoff | ADR-0012, ADR-0015 | No effect on product code |
| Existing `ci.yml` scaffolds Node 20 if `package.json` exists | template render | **Soft hint** — opportunistic gate, not binding |

## Soft assumptions (vision-dependent — will be revisited)

The product is named **AtilCalculator**. Without `docs/product/vision.md`:

- It might be a **CLI** (`atilcalc 2+2`).
- It might be a **web app** (browser keypad).
- It might be an **HTTP API** for embedding.
- It might be a **library** (`pip install` / `npm i`).
- It might be a **financial engine** (Decimal-precision arithmetic + audit log).
- It might be a **scientific calc** (symbolic math, plots).

Each of these locks a different stack. The architect's job here is to **enumerate** candidates, not pick.

## Candidate stacks (catalogue, not ranked)

### A. Python 3.11 + pytest + Typer + decimal stdlib

- **Best for**: CLI calculator, library shape, HTTP API later via FastAPI
- **Pros**: matches bootstrap (Python already in `scripts/`); `decimal.Decimal` stdlib; tightest pytest TDD loop; pure-function engine portable to FastAPI / Pyodide
- **Cons**: weak in-browser without Pyodide/WASM; CPython startup ~50 ms; packaging fragmented (pip vs poetry vs hatch)
- **Pre-vision lean**: high. Reversible from CLI to most other surfaces.

### B. TypeScript / Node 20 + Vitest + Commander (+ optional Next.js)

- **Best for**: web-first calculator (Next.js / Vite), or CLI that pivots to browser
- **Pros**: existing `ci.yml` scaffold hint; huge ecosystem; cleanest web pivot; `decimal.js` widely used
- **Cons**: introduces second toolchain (Python in scripts/, Node in product); async noise on sync arithmetic; lockfile churn
- **Pre-vision lean**: medium. Strong if vision = web app from day one.

### C. Go 1.22 + std testing + Cobra + math/big

- **Best for**: single-binary CLI for distribution, or HTTP service
- **Pros**: static binary; fast startup; `math/big` stdlib; no GC pause concerns
- **Cons**: new toolchain in CI; weakest browser pivot (TinyGo+WASM is a road); ergonomics light on generics-friendly math
- **Pre-vision lean**: low unless vision = distributable CLI binary as primary surface.

### D. Rust + cargo + clap + rust-decimal

- **Best for**: max-perf engine + WASM frontend for web
- **Pros**: WASM target first-class; memory-safe; no GC
- **Cons**: cold compile 3–5 min on ubuntu-latest; lifetime/ownership ramp; premature optimisation per soul heuristic
- **Pre-vision lean**: very low. Only reconsider if vision = real-time math (DSP, finance HFT).

### E. Bash + bats-core

- **Best for**: throwaway CLI with no precision concerns
- **Pros**: zero new toolchain
- **Cons**: integer-only arithmetic in `(())`; no realistic web/library pivot
- **Pre-vision lean**: near-zero. Listed for completeness.

### F. Python engine + WASM compile (Pyodide)

- **Best for**: web-first calculator that wants to share engine code with a CLI
- **Pros**: one engine codebase covers CLI (Python) + browser (Pyodide WASM); aligns with bootstrap
- **Cons**: Pyodide bundle is ~6 MB cold; not all stdlib works; toolchain (Pyodide + esbuild) is two-headed
- **Pre-vision lean**: medium. Becomes the architect's recommendation if vision = web with offline-capable engine.

## Architecture invariant (vision-independent)

Whatever language wins, the **engine ↔ UI separation** holds:

```
src/
  <engine module>/   # pure functions; parse + evaluate; no I/O
  <ui surface>/      # wraps engine; CLI / HTTP / browser
tests/
  engine/            # parametrised; engine is high-test-leverage
  ui/                # thin smoke + integration
```

This is the only piece I'd commit to before vision lands — it is true
under all six candidates.

## Open questions for PM (Issue #2 / vision intake)

These are the questions that, when answered, pick the stack:

1. **Primary surface**: CLI, web, HTTP API, library, or multi-surface?
2. **Distribution model**: PyPI/npm install? Single binary? Hosted service? Embedded in another product?
3. **Precision class**: integer-only? IEEE-754 acceptable? Decimal-precision required? Symbolic (SymPy/SageMath)?
4. **Offline capability**: must run with no network (so WASM/binary)? Server-side eval OK?
5. **Performance budget**: human-perceptible latency OK (50 ms)? Sub-millisecond required?
6. **Audit / replay**: are calc results logged for compliance? If yes → engine emits structured events.
7. **Multi-user**: shared state? Auth? (Or single-user shell tool?)
8. **Persistence**: history, saved sessions, named variables? Or stateless?

Without answers to **#1, #2, #3**, no stack can be chosen responsibly.

## Architect's pre-vision lean (for the record, not binding)

**If forced to guess right now**, I'd lean toward **Candidate A** (Python +
pytest + Typer) because:

- It's the cheapest stack that keeps the most options open via the
  engine/UI separation.
- It matches existing toolchain (zero CI install cost).
- `decimal.Decimal` covers most precision classes (1-5).
- Pyodide bridge (Candidate F) is available later without rewriting
  the engine.

But this is **a guess, not a decision**. The actual ADR waits.

## Constraints I won't compromise on (vision-independent)

- ❌ **No second language in CI** unless the product surface demands it
  (i.e., do not pick Node for the CLI just because `ci.yml` already
  scaffolds it).
- ❌ **No production code with `float` arithmetic** for money or any
  domain requiring exact decimals.
- ❌ **No "we'll add tests later"** — TDD red-first is the team's
  contract (tester soul).
- ❌ **No frontend framework choice before there's a frontend story.**

## What happens next

1. @atilcan65 + @product-manager land vision on Issue #2 → merge `docs/product/vision.md`.
2. @atilcan65 picks (or asks me to pick) one candidate from this list.
3. I write **ADR-0017** for real, fill in `.claude/CLAUDE.md` §Tech stack
   (or, if file is gitignored, route the update via the upstream template
   per the open question I posted on Issue #3).
4. PR #5 (currently draft, retracted) is either reused (rebase) or
   closed and replaced.
5. First Sprint 1 stories get sized against the chosen stack.

## References

- Issue #3 ruling: https://github.com/atilcan65/AtilCalculator/issues/3#issuecomment-4730694494
- Bootstrap ADRs: 0010 / 0012 / 0014 / 0016 in `docs/decisions/`
- PR #5 (draft, retracted): https://github.com/atilcan65/AtilCalculator/pull/5
- Vision intake (blocker): Issue #2
