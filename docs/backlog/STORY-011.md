# STORY-011: Scientific functions (trig / log / √ / !) — engine + UI affordances

## User Story
As a **P1 — Atil (owner-operator, software/infrastructure professional — trig/log workflows in shell scripts and one-off calculations)**,
I want **the calculator to handle scientific functions — `sin`, `cos`, `tan` (with rad/deg toggle), `log`, `ln`, `√` (sqrt), `!` (factorial) — both in the engine and via UI affordances (a mode-toggle for scientific layout, function-name autocomplete or button grid)**,
So that **I can switch from "I need 5 + 3" to "I need sin(45°) + log(100)" without leaving the keyboard (M2 + vision §Top-3-to-5 "bilimsel fonksiyon destekli")**.

## Why now
The vision's "bilimsel fonksiyon destekli" (scientific-function-supported) wording targets MVP-1 parity per the must-have list (4 operations + scientific functions). Sprint 1 explicitly deferred scientific functions to Sprint 2 per owner Q3 answer (vision §Open Questions Q3 + Sprint 1 plan.md §Out-of-scope). The engine `evaluate()` API exists (PR #26, STORY-002), and `<atilcalc-help-popup>` shipped in Sprint 1 (STORY-003b) — both are stable integration points.

## Acceptance Criteria
- **AC1** — GIVEN the engine evaluates `sin(0)` WHEN called via `evaluate("sin(0)")` THEN it returns `Decimal("0")` (radians default per math convention; documented in engine docstring).
- **AC2** — GIVEN the engine evaluates `cos(0)` with `deg=True` mode WHEN called THEN it returns `Decimal("1")` (degrees mode — toggleable via context or engine flag, not in expression syntax to avoid ambiguity).
- **AC3** — GIVEN the engine evaluates `sin(45 deg)` (inline unit suffix) WHEN called THEN it returns `Decimal("0.707106781186547524400844362104849039284835937688...")` (45° in radians, full decimal precision).
- **AC4** — GIVEN the engine evaluates `log(100)` (base-10) WHEN called THEN it returns `Decimal("2")`.
- **AC5** — GIVEN the engine evaluates `ln(2.71828182845904523536)` (natural log, base-e) WHEN called THEN it returns `Decimal("1.000000000000000000000000000")` (within engine precision).
- **AC6** — GIVEN the engine evaluates `sqrt(2)` WHEN called THEN it returns `Decimal("1.414213562373095048801688724")` (28-digit precision default).
- **AC7** — GIVEN the engine evaluates `5!` (factorial) WHEN called THEN it returns `Decimal("120")`. GIVEN `0!` THEN `Decimal("1")`. GIVEN `100!` THEN the full-precision Decimal (factorial grows fast; precision budget checked).
- **AC8** — GIVEN the engine evaluates `tan(90 deg)` (undefined — tan(π/2) = ∞) WHEN called THEN it raises `UndefinedOperatorError` (or a new `DomainError` subclass — architect's call at sizing) which maps to HTTP 400 per ADR-0019 §Engine exception → HTTP status mapping.
- **AC9** — GIVEN the user toggles `<atilcalc-mode-toggle>` to "scientific" WHEN the UI updates THEN the keypad reveals sin/cos/tan/log/ln/√/! buttons + a rad/deg indicator; pressing these via keyboard (e.g., `s` for sin, `l` for log) inserts the function name + open paren.
- **AC10** — GIVEN `<atilcalc-help-popup>` is opened (via `?` key) WHEN scientific mode is active THEN the popup lists all scientific function shortcuts + rad/deg toggle.

## Out of scope
- Custom user-defined functions.
- Programmer mode (hex/binary/bitwise) — explicit out per vision §Out-of-scope.
- Complex numbers (engine is real-valued Decimal).
- Symbolic algebra / equation solving.
- Unit conversion (km/mile, kg/lb, °C/°F) — explicit out per vision §Out-of-scope.
- Hyperbolic functions (sinh, cosh, tanh) — Sprint 3+ stretch.

## Open questions
- [ ] **Architect**: Engine function-name tokenizer design — `sin(45)` (function-call form) vs `45 sin` (postfix) vs `sin 45` (prefix space)? PM recommends `sin(45)` (matches math notation + easier to parse unambiguously). Existing engine uses `(` for grouping — need to ensure no tokenizer conflict. → architect + developer
- [ ] **Architect**: Unit suffix `45 deg` — single-token scanner rule or pre-processor? PM recommends single-token rule (consistent with `5%` in Sprint 1 hybrid percent convention). → architect
- [ ] **Architect**: New `DomainError` exception for tan(90°), log(-1), sqrt(-1)? Or reuse `UndefinedOperatorError` (per ADR-0019 amendment §Exception taxonomy, "reserved for FUTURE operators that parse but cannot dispatch")? PM recommends new `DomainError` subclass — semantically distinct from "operator not implemented". → architect
- [ ] **Developer**: Precision for transcendental functions — `decimal.Decimal` has `Decimal.ln()` / `Decimal.sin()` via `mpmath`? PM no preference; architect + developer decide at implementation. → developer
- [ ] **Owner**: Should scientific functions be in MVP-1 (parity with vision's "bilimsel fonksiyon destekli") or MVP-2? PM interpretation: Sprint 1 plan.md committed to Sprint 2 — Q3 is settled for MVP-1 completion. → owner (confirm if needed at sizing)

## Mockups / references
- vision.md §Top-3-to-5 must-haves (Core calculation engine: "trigonometry (`sin` / `cos` / `tan` + rad/deg toggle), logarithm (`log` / `ln`), constants (`e`, `π`)")
- ADR-0019 §Engine exception taxonomy (PR #63 amendment: `UndefinedOperatorError` reserved for Sprint 2+ operators)
- ADR-0017 §Engine ↔ UI separation invariant (engine does no I/O; functions are pure)
- Sprint 1 plan.md §STORY-002 ACs (engine already supports `+`, `-`, `*`, `/`, `%`, parentheses; Sprint 2 extends with scientific)

## Dependencies
- **Upstream**:
  - STORY-002 Engine module (Merged, PR #26 — `evaluate()` API exists)
  - ADR-0019 amendment (PR #63 — `UndefinedOperatorError` scope clarified)
  - `<atilcalc-help-popup>` Web Component (Sprint 1, shipped)
  - `<atilcalc-mode-toggle>` Web Component (Sprint 1, shipped)
- **Downstream**: Sprint 3+ polish — M2 stickiness validation with mixed simple+scientific usage.

## Metrics of success
- **Leading**: scientific function evaluation precision matches reference values to 28 digits (acceptance test parametrised against known constants).
- **Leading**: scientific UI mode toggle latency p95 <200ms (mode switch is local CSS variable update).
- **Lagging**: M2 stickiness signal — owner uses scientific functions ≥3× per week (proxy: history records containing scientific function names).
- **Lagging**: zero P0/P1 bugs filed within 24h post-launch (DoD #6).