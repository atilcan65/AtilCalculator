# STORY-CLI-001: Basic arithmetic via typer CLI

## User Story
As a **P1 — Atil (owner-operator, software/infrastructure professional, 5–20 calcs/day, always-open tab on the LAN)**,
I want **a command-line calculator that evaluates basic arithmetic (`+`, `-`, `*`, `/`) with exact decimal precision and prints the result to stdout**,
So that **I can run `atilcalc 0.1 + 0.2` from any terminal and get `0.3` (not `0.30000000000000004`) — without opening a browser tab or trusting an ad-funded online calculator (M1 acceptance).**

## Why now
- Sprint 4-6 were all infra-only (3 consecutive sprints). Sprint 7 (per PM PR #294 verdict nit 1 + owner directive 2026-06-23T13:28Z chat) ships the **first user-facing feature** to break the streak.
- `docs/product/vision.md` M1 = "First MVP ships with **zero float errors**. Acceptance test `0.1 + 0.2 == 0.3` passes." — this story is the **CLI-surface embodiment of M1**.
- `docs/product/personas.md` P1 (Atil) pain point: "Float errors showing up in routine arithmetic (`0.1 + 0.2`, compound interest, percentage chains)."
- ADR-0017 §Tech stack: Python 3.11+, `typer` CLI scaffolding, `decimal.Decimal` (stdlib) — all in place.
- Sprint 1 STORY-002 (PR #26) already shipped the 4-op pure-Python engine with decimal precision. CLI is a thin typer wrapper.

## Acceptance Criteria
- **AC1** — GIVEN the binary is installed (`pip install -e .[dev]`) WHEN the user runs `atilcalc 0.1 + 0.2` THEN stdout shows exactly `0.3` (M1 baseline).
- **AC2** — GIVEN the binary is installed WHEN the user runs `atilcalc 1.5 * 3` THEN stdout shows `4.5` (no scientific notation for small results).
- **AC3** — GIVEN the binary is installed WHEN the user runs `atilcalc 10 / 3` THEN stdout shows `3.333333333333333333333333333` (Decimal default 28-digit precision; not float truncation).
- **AC4** — GIVEN the binary is installed WHEN the user runs `atilcalc 0.1 + 0.2 + 0.3` THEN stdout shows `0.6` (chained addition remains exact).
- **AC5** — GIVEN a division by zero (`atilcalc 1 / 0`) WHEN evaluated THEN stderr shows a clear error (e.g., `decimal.DivisionByZero: 0`) and exit code is non-zero (e.g., 1). Stdout does NOT show `inf` or `Infinity`.
- **AC6** — GIVEN an invalid expression (`atilcalc 1 + + 2`) WHEN parsed THEN stderr shows a parse error and exit code is non-zero. No traceback to user.
- **AC7** — GIVEN a parametrised regression test suite (≥10 cases covering M1 baseline, integer arithmetic, decimal propagation, negative numbers, large numbers) WHEN `pytest` runs THEN all cases pass. Test file: `tests/cli/test_basic_arithmetic.py`.
- **AC8** — GIVEN `mypy --strict` runs on `src/atilcalc/engine/` THEN no type errors. Engine module per ADR-0017 §Architecture rule (pure-Python, no I/O).
- **AC9** — GIVEN `ruff check` runs on the CLI module THEN no lint errors. CLI module is a thin wrapper, not a logic layer.

## Out of scope
- Multi-op precedence (STORY-CLI-002) — handled separately
- REPL mode (STORY-CLI-003) — handled separately
- Scientific functions (sin, cos, log, sqrt) — Sprint 8+ (or never for CLI surface; web surface is per persona)
- History persistence — Sprint 2 STORY-007 (HTTP surface only; CLI history is future)
- HTTP surface — ADR-0017 §Deferred
- Skin/theme support — web-only per vision

## Open questions
- [ ] **Architect**: Should the CLI module live in `src/atilcalc/cli/` or `src/atilcalc/__main__.py`? → architect
- [ ] **Developer**: typer vs click directly? ADR-0017 says typer; confirm. → developer
- [ ] **Owner**: Default precision — 28 digits (Decimal default) or configurable? PM recommends configurable via `--precision` flag, default 28. → owner @atilcan65
- [ ] **Tester**: AC7 parametrised test count — 10 minimum or higher? PM suggests 10 + edge cases (division-by-zero, parse error) = 12 total. → tester

## Mockups / references
- `docs/product/vision.md` §M1 (Accuracy) + §Core Problem (float errors)
- `docs/product/personas.md` §P1 (Atil) pain points
- `docs/decisions/ADR-0017-tech-stack.md` §Tech stack (typer + Decimal)
- Sprint 1 STORY-002 (PR #26) — engine module already shipped, this is CLI wrapper

## Dependencies
- **Upstream**: Sprint 1 STORY-002 (engine module, PR #26) ✅ done
- **Downstream**: STORY-CLI-002 (precedence) extends this; STORY-CLI-003 (REPL) consumes this

## Metrics of success
- **Leading**: AC7 test count + mypy strict pass + ruff pass
- **Lagging**: M1 acceptance (`0.1 + 0.2 == 0.3`) green; P1 (Atil) runs CLI daily (subjective feedback after Sprint 7 close)

— @product-manager, 2026-06-23T13:30Z, STORY-CLI-001 proposed for Sprint 7 P0
