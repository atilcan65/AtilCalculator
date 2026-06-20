# STORY-013: Implicit first operand from history (calc-ans style)

## User Story
As a **P1 — Atil (owner-operator, software/infrastructure professional, 5–20 calcs/day, keyboard-only, always-open tab)**,
I want **when I start a new expression with an operator (`+`, `-`, `*`, `/`, `^`) instead of a number, the calculator to use the most recent successful result from history as the implicit first operand**,
So that **I can chain operations without retyping the previous result (e.g., after `42 + 8 = 50`, I just type `+ 12` to get `62`, instead of `50 + 12`)**.

## Why now
P1 currently does 5–20 calcs/day, often chained (compound interest, percentage adjustments, ad-hoc arithmetic). Re-typing the prior result breaks flow on the keyboard-only path — the prior result is right there in `<atilcalc-history>`, but the user has to read it, type it, then type the operator. This is the same muscle-memory shortcut that physical calculators (TI, Casio, macOS Calculator) and Excel-after-`Enter` provide. PRD backlog overflow (P2, RETRO-003 §Sprint 4 must-haves P2 list noted "minor UX wins" but didn't enumerate this one — the owner surfaced it directly via chat 2026-06-20).

## Acceptance Criteria
- **AC1** — GIVEN the most recent history entry has `{expr: "42 + 8", result: "50"}` WHEN the user submits `+ 12` to `POST /api/evaluate` THEN the server returns `{result: "62", ...}` (i.e., `50 + 12 = 62`, with the previous result used as the implicit left operand).
- **AC2** — GIVEN the most recent history entry is `{expr: "0.1 + 0.2", result: "0.3"}` WHEN the user submits `* 4` THEN the server returns `{result: "1.2"}` (i.e., `0.3 * 4 = 1.2`). Decimal precision preserved per ADR-0019 §Decimal serialization.
- **AC3** — GIVEN the user submits `^ 2` (exponentiation, no left operand) WHEN the previous result was `5` THEN the server returns `{result: "25"}` (i.e., `5 ^ 2 = 25`).
- **AC4** — GIVEN the history is empty (first calculation) WHEN the user submits `+ 5` THEN the server returns 400 with `error.type = "NoHistoryError"` (or equivalent) and a clear message — NOT a silent 500, NOT a misleading 0.
- **AC5** — GIVEN the most recent history entry is an ERROR (e.g., `{expr: "1/0", result: "<error>"}` or `{status: "error"}`) WHEN the user submits `+ 5` THEN the server uses the **last successful** result (skips the error entry), and if no successful result exists, returns the same `NoHistoryError` as AC4.
- **AC6** — GIVEN the user submits a normal expression with explicit left operand (e.g., `50 + 12`) THEN behavior is unchanged (no regression on the existing 4-op + scientific path).
- **AC7** — GIVEN the implicit-operand result `62` is computed WHEN it returns to the browser THEN a new history record is written (idempotency per ADR-0019) with `expr: "50 + 12"` (the **fully-resolved** expression), NOT `+ 12`. The history shows the user what was actually computed, even if the input was terse. (This is the right call: history is for audit, not for input echo.)
- **AC8** — GIVEN the keyboard FSM in `<atilcalc-input>` WHEN the user types `+` then a space then `12` and presses Enter THEN the same implicit-operand path fires (keyboard-only end-to-end, no mouse required, P1 success criteria).
- **AC9** — GIVEN Sprint 4 P0 E2E-DEPLOY-VERIFY harness is in place WHEN this story ships THEN the implicit-operand path is covered by `tests/api/test_implicit_operand.py` with cases for AC1-AC8 + a Decimal precision regression test (e.g., `(0.1 + 0.2) * 3 = 0.9`, chain 2 implicit operands).
- **AC10** — GIVEN the engine's `evaluator.evaluate()` function WHEN called with `expr="+ 12"` AND a context `last_result=Decimal("50")` THEN the engine returns `Decimal("62")` — pure function, no I/O (ADR-0017 §engine purity). The HTTP layer wires the `last_result` from history before calling the engine.

## Out of scope
- **Multi-step implicit chains** (e.g., type `+ 5` then `- 3` using TWO prior results) — only the most recent result is the implicit operand. Excel-style `=A1+A2` reference syntax is explicitly out of MVP per vision §Out of scope.
- **Named variables / memory registers** (TI `M+`, `MR`, `Ans` keys) — the history IS the memory. No separate `ans` register; if the user wants `MR` they look at the top of history.
- **Implicit-operand on the CLI surface** (`atilcalc eval` Typer command) — web shell only for MVP. CLI stays explicit-operand for scripting clarity.
- **Implicit-operand on scientific functions** (`sin`, `cos`, `log` etc., per STORY-011) — these are unary, they don't take a left operand. The implicit-operand rule only applies to binary operators.
- **History manipulation** (delete entry, mark as "ignore", pin as `ans`) — out of scope; if the user wants a different `ans` they re-do the calc they want.
- **Per-session vs cross-device `ans`** — `ans` is **server-side from the most recent history record**, not browser-session. Cross-device consistency follows naturally from STORY-007 (SQLite shared backend).

## Open questions
- [ ] **Architect**: should the engine take `last_result` as a separate parameter (cleaner, ADR-0017 purity) or should the HTTP layer pre-process the string (`+ 12` → `50 + 12` before engine call)? PM recommendation: **engine takes `last_result` as parameter** (pure-function, testable in isolation, no string munging). → architect @ sizing
- [ ] **Architect**: AC5 fallback (skip error entries) — does this match the existing persistence layer's "last successful result" semantics, or is there a more idiomatic way (e.g., a dedicated `last_successful_result` column in the history table)? → architect @ sizing
- [ ] **Tester**: AC7 audit-style history (`expr: "50 + 12"` resolved) — does this break any existing UI contract (e.g., the `<atilcalc-history>` component expects the user's typed string)? PM believes it improves the audit story, but tester should verify no UI regression. → tester @ test plan
- [ ] **Owner**: AC8 keyboard FSM behavior — is `+` immediately after Enter (no space) acceptable, or do we require `+` then operand (no space requirement)? Owner preference; PM recommends "operator followed by operand on same line" (e.g., `+ 12` or `+12` both work) for muscle-memory parity with macOS Calculator. → owner @atilcan65

## Mockups / references
- macOS Calculator "Continue calculation" behavior (after `=`, typing `+ 5` reuses the result)
- TI-83 `Ans` key (2nd → Ans(-), then operator)
- Excel: after `Enter`, the cell value becomes the implicit operand for the next formula starting with an operator
- ADR-0019 §API contract (POST /api/evaluate body shape)
- ADR-0017 §engine purity (pure-Python, no I/O, no UI deps)
- STORY-007 (SQLite persistent history)
- STORY-011 (scientific functions, unary, do not take implicit operand)
- Sprint 3 RETRO-003 (PRD backlog overflow — UX wins not enumerated)

## Dependencies
- **Upstream**:
  - STORY-007 (DONE — persistent history backend) — `last_result` reads from SQLite
  - STORY-011 (DONE — transcendentals + factorial) — unary operators unaffected
  - ADR-0019 (DONE — POST /api/evaluate contract)
  - ADR-0017 (DONE — engine purity invariant)
  - Sprint 4 P0 E2E-DEPLOY-VERIFY (in-flight — for AC9 test coverage)
- **Downstream**:
  - STORY-008 history UI (may want to surface "this is an implicit-operand calc" badge in history rows — defer to Sprint 5+)
  - Sprint 5+ feature work that touches the evaluator

## Metrics of success
- **Leading**: implicit-operand path returns same response time as explicit-operand path (<50ms p99 per ADR-0019).
- **Leading**: 100% Decimal precision preserved across implicit-operand chains (e.g., `(0.1 + 0.2) * 3 = 0.9` byte-exact per ADR-0019 §Decimal serialization).
- **Lagging**: M2 stickiness signal — owner uses implicit-operand path in 30%+ of chained calcs (proxy: ratio of history records where `expr` starts with operator vs explicit-operand). 4-week measurement window post-launch.
- **Lagging**: keyboard-only end-to-end — AC8 covered by Playwright test; M3 acceptance (per persona §Success looks like) holds.
