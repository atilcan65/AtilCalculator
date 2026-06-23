# STORY-CLI-002: Multi-op expressions with operator precedence

## User Story
As a **P1 — Atil (owner-operator, software/infrastructure professional, 5–20 calcs/day)**,
I want **the CLI to evaluate multi-operator expressions with correct precedence (e.g., `2 + 3 * 4` = `14`, not `20`) and parenthesized grouping (e.g., `(2 + 3) * 4` = `20`)**,
So that **I can paste compound expressions from notes/Slack/email into the terminal and get the right answer without manually computing intermediate results (M1 extension).**

## Why now
- STORY-CLI-001 ships basic arithmetic (4 ops, no precedence). STORY-CLI-002 extends with precedence.
- P1 (Atil) context: "engineering arithmetic, ad-hoc numbers from meetings/notes/Slack" — multi-op expressions are the norm, not single ops.
- Foundation for STORY-CLI-003 (REPL) — REPL needs precedence for the same reason.
- Reuses the Sprint 1 engine + STORY-CLI-001 CLI wrapper; minimal new code.

## Acceptance Criteria
- **AC1** — GIVEN the CLI is installed WHEN the user runs `atilcalc '2 + 3 * 4'` THEN stdout shows `14` (multiplication before addition).
- **AC2** — GIVEN the CLI is installed WHEN the user runs `atilcalc '(2 + 3) * 4'` THEN stdout shows `20` (parentheses override precedence).
- **AC3** — GIVEN the CLI is installed WHEN the user runs `atilcalc '2 + 3 + 4 * 5'` THEN stdout shows `25` (left-to-right for same-precedence, multiplication before addition).
- **AC4** — GIVEN the CLI is installed WHEN the user runs `atilcalc '10 - 2 * 3'` THEN stdout shows `4` (subtraction precedence correct).
- **AC5** — GIVEN the CLI is installed WHEN the user runs `atilcalc '100 / 5 / 2'` THEN stdout shows `10` (left-to-right division).
- **AC6** — GIVEN the CLI is installed WHEN the user runs `atilcalc '2 ** 3'` THEN stdout shows `8` (power operator, integer exponent, decimal base).
- **AC7** — GIVEN a parametrised regression test (≥15 cases covering `+`, `-`, `*`, `/`, `**`, parens, mixed precedence, nested parens, unary minus) WHEN `pytest` runs THEN all cases pass. Test file: `tests/cli/test_precedence.py`.
- **AC8** — GIVEN unbalanced parens (`atilcalc '(1 + 2'`) WHEN parsed THEN stderr shows a parse error and exit code is non-zero. No traceback.
- **AC9** — GIVEN a unary minus (`atilcalc '-5 + 3'`) WHEN evaluated THEN stdout shows `-2` (unary minus binds tighter than binary).
- **AC10** — GIVEN `mypy --strict` + `ruff check` runs on the parser module THEN no errors.

## Out of scope
- Scientific functions (sin, cos, etc.) — Sprint 8+ or web surface
- Variables / assignment (`x = 5; x + 1`) — out of MVP per vision
- Function calls (`sqrt(9)`) — Sprint 8+
- Custom operators — out of MVP
- REPL session (STORY-CLI-003)

## Open questions
- [ ] **Architect**: Parser approach — recursive descent vs `pyparsing` vs `lark`? ADR-0017 §Tech stack is stdlib-bias; PM suggests stdlib `re` + recursive descent. → architect
- [ ] **Developer**: Token precedence table — Python-style or strict math (no implicit `*` for `2(3+4)`)? → developer
- [ ] **Owner**: Power operator `**` — include in Sprint 7 or defer to Sprint 8? PM recommends include (small impl, big UX value for compound interest). → owner @atilcan65
- [ ] **Tester**: AC7 test count — 15 minimum or higher? PM suggests 15 + edge cases (unbalanced parens, unary minus, empty parens) = 18 total. → tester

## Mockups / references
- STORY-CLI-001 (basic arithmetic) — upstream
- Sprint 1 STORY-002 (engine module) — Decimal precision extended to multi-op
- `docs/product/vision.md` §M1 (Accuracy, multi-op context)

## Dependencies
- **Upstream**: STORY-CLI-001 (basic arithmetic) — must land first
- **Downstream**: STORY-CLI-003 (REPL) consumes this

## Metrics of success
- **Leading**: AC7 test count + mypy + ruff pass
- **Lagging**: P1 (Atil) uses CLI for compound expressions in daily work; Sprint 7 close feedback

— @product-manager, 2026-06-23T13:30Z, STORY-CLI-002 proposed for Sprint 7 P0 (depends on STORY-CLI-001)
