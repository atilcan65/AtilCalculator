# STORY-CLI-003: REPL mode (interactive session)

## User Story
As a **P1 — Atil (owner-operator, keyboard-intensive worker, 5–20 calcs/day in 5–120s sessions)**,
I want **an interactive REPL mode (`atilcalc --repl`) where I type expressions and get results back, session-stays-open until I send EOF/Ctrl-D, no mouse, no separate window**,
So that **I can do a quick burst of calculations (5-10 in a row, e.g., splitting a bill) without re-typing `atilcalc` for each one (M3 keyboard-first analog, deferred HTTP/Web spirit).**

## Why now
- `docs/product/vision.md` M3 = "All basic operations ... are reachable using the keyboard only." The HTTP/Web surface is deferred (ADR-0017 §Deferred). CLI REPL is the **keyboard-first analog** that P1 can use today, before HTTP ships.
- P1 (Atil) session profile: "5-120 seconds per calculation; multiplies to a few hours per week of tool time." REPL fits the burst-use pattern.
- Foundation for Sprint 8+ CLI history (last-N results in session) and Sprint 9+ HTTP REPL.
- Sprint 7 ships the CLI; Sprint 8+ extends.

## Acceptance Criteria
- **AC1** — GIVEN the CLI is installed WHEN the user runs `atilcalc --repl` THEN a prompt is shown (e.g., `atilcalc> `) and the REPL waits for input on stdin.
- **AC2** — GIVEN the REPL is running WHEN the user types `0.1 + 0.2` + Enter THEN stdout shows `0.3` and a new prompt appears.
- **AC3** — GIVEN the REPL is running WHEN the user types `(2 + 3) * 4` + Enter THEN stdout shows `20` (uses STORY-CLI-002 precedence).
- **AC4** — GIVEN the REPL is running WHEN the user types `exit` or `quit` + Enter THEN the REPL exits with code 0 and a goodbye message (e.g., `bye`).
- **AC5** — GIVEN the REPL is running WHEN the user sends EOF (Ctrl-D on Unix, Ctrl-Z + Enter on Windows) THEN the REPL exits with code 0 and no error message.
- **AC6** — GIVEN the REPL is running WHEN the user types an invalid expression (e.g., `1 + + 2`) THEN stderr shows a parse error, exit code 0 (REPL continues), and a new prompt appears. The REPL does NOT exit on parse error.
- **AC7** — GIVEN the REPL is running WHEN the user types `/help` THEN stdout shows a help message with available commands (`/help`, `/exit`, `/quit`).
- **AC8** — GIVEN a session-level test (3-5 expressions in sequence, mixed valid/invalid, exit cleanly) WHEN the test harness drives stdin THEN all assertions pass. Test file: `tests/cli/test_repl.py`.
- **AC9** — GIVEN `mypy --strict` + `ruff check` runs on the REPL module THEN no errors.

## Out of scope
- Session-level history (last-N results with up-arrow recall) — Sprint 8+
- Auto-completion (tab completion of operators) — Sprint 8+
- Syntax highlighting — out of MVP
- Multi-line expressions (continuation with `\` or unclosed parens) — Sprint 8+ or never
- REPL inside HTTP/Web — Sprint 9+
- History persistence across sessions — Sprint 2 STORY-007 (HTTP only); CLI session history is future

## Open questions
- [ ] **Architect**: REPL loop — `prompt_toolkit` (rich) vs stdlib `input()` (minimal)? ADR-0017 §Tech stack is stdlib-bias; PM suggests stdlib `input()` for Sprint 7, `prompt_toolkit` defer to Sprint 8 if Atil wants arrow recall. → architect
- [ ] **Developer**: Prompt format — `atilcalc> ` (with trailing space) or `> ` (terse)? PM suggests `atilcalc> ` for clarity. → developer
- [ ] **Owner**: Include `/help` and `/exit` slash-commands, or use bare `exit`/`quit`? PM suggests both (slash prefix for future extensibility). → owner @atilcan65
- [ ] **Tester**: AC8 test scope — 3-5 expressions in sequence, or more comprehensive? PM suggests 5 + edge cases (Ctrl-D, parse error mid-session, exit). → tester

## Mockups / references
- `docs/product/vision.md` §M3 (Keyboard-only) — REPL is the CLI analog
- `docs/product/personas.md` §P1 (Atil) — keyboard-intensive, 5-120s sessions
- STORY-CLI-001 + STORY-CLI-002 — REPL consumes both

## Dependencies
- **Upstream**: STORY-CLI-001 (basic arithmetic) + STORY-CLI-002 (precedence) — must both land
- **Downstream**: Sprint 8+ session history; Sprint 9+ HTTP REPL

## Metrics of success
- **Leading**: AC8 session test pass + mypy + ruff pass
- **Lagging**: P1 (Atil) uses REPL for daily burst-calculations; Sprint 7 close feedback

— @product-manager, 2026-06-23T13:30Z, STORY-CLI-003 proposed for Sprint 7 P0 (depends on STORY-CLI-001 + 002)
