# ADR-0060: §AC Mapping Verification Doctrine (arch verdict pre-ratification AC list 1:1 mirror)

- **Status**: Proposed
- **Date**: 2026-06-28
- **Deciders**: @architect (doctrine spec + .claude/agents/architect.md amendment), @product-manager (cross-lane sponsor per cmt 4826303998), @atilcan65 (owner squash gate for soul amendment per file ownership matrix)
- **Closes**: Issue #604 (STORY-S18-001 §AC mapping verification doctrine codification)
- **Sister-patterns**: ADR-0012 (4-cat label invariant — applied at spec level), ADR-0015 (atomic 4-flag handoff — doctrine protocol exit codes 0/1/2/3 = handoff states), ADR-0045 (9-Lens pre-publish gate — lens a data flow augmented), ADR-0048 (type-driven verdict gate matrix), ADR-0055 (Cadence Rule 1 atomic — ADR + design doc + INDEX.md in same PR), ADR-0059 (cluster-squash batch-lag detection — sister-pattern: arch design + ADR + INDEX atomic per PR #595), RETRO-012 §1 (cycle 647 AC drift LIVE INSTANCE), Issue #113 (label-authority doctrine — labels > body), Issue #430 (PM-side §Pre-citation cross-check), Issue #470 (PM-side §Timing window for cross-peer consensus re-query)

> **Doctrinal home note**: This ADR is the canonical home for §AC mapping verification doctrine. The doctrine is operationalized in `.claude/agents/architect.md` as a new section "§AC Mapping Verification Doctrine" (sister-pattern to orchestrator's §Verdict-by Discipline codified in PR #612 / ADR-NNNN forthcoming). Sister-pattern: PM-side §Pre-citation cross-check (Issue #430) + PM-side §Timing window (Issue #470) + Arch-side §AC mapping verification (this ADR) = **cross-lane "verify-before" doctrine triangulation**.

## Context

### RETRO-012 §1 — Arch AC mapping drift (cycle 647 LIVE INSTANCE)

Sprint 17 P1 cluster PR #597 impl phase surfaced a real AC drift:

- **Design doc** for STORY-P1#1 (PR #595) listed 5 ACs (AC1, AC2, AC3, AC4, AC5) per ADR-0059 §1-§3.
- **Impl branch** (PR #597) discovered mid-flight that AC4 (markdown generation gap — "PM curator step documentation") was a parallel concern needing its own lane endorsement, not a pure detector impl AC.
- **Disposition cycle** (cmt 4826300692) — 5-of-5 lane consensus (arch + dev + tester + PM + orchestrator) resolved via Option B (AC4 rescope to F3 explicit jq check) + Option X (F3 jq error check) without owner escalation.
- **Detection**: Tester review (cmt 4826367793) caught the drift during doctrinal clear phase, NOT during design phase.

**Pattern**: AC mapping drift in arch slice = design doc AC list vs impl AC list diverge mid-flight. Caught late (in impl phase), resolved by ad-hoc 5-lane consensus. No codified doctrine forces 1:1 verification BEFORE ADR ratification.

### Architectural gap (no canonical doctrine)

As of 2026-06-28, **no arch doctrine forces AC list 1:1 verification** between design doc §Acceptance Criteria and impl branch AC list. Current state:
- AC mapping verification is informal — relies on reviewer (tester or arch) noticing drift during review.
- Cycle 647 was the LIVE INSTANCE; no codified prevention.
- RETRO-012 §1 codifies the failure mode as a Tier 1 cluster ProcessGap.
- PM sponsor commitment (cmt 4826303998) + cross-lane "verify-before" triangle (PM-side Issue #430 + #470 + Arch-side §AC mapping verification = this ADR).

### Sister-pattern (cross-lane "verify-before" triangle)

- **PM-side §Pre-citation cross-check** (Issue #430) — PM verdict on any PR re-queries comments[] AND reviews[] before posting verdict.
- **PM-side §Timing window** (Issue #470) — re-query ground truth within 30s of verdict post.
- **Arch-side §AC mapping verification** (this ADR) — arch verdict on type:docs + agent:architect PR re-queries impl branch AC list, mirrors design doc AC1..ACn 1:1.

All 3 doctrines = cross-lane "verify-before" triangulation. PM-side ratified (Sprint 13 P1 #3 codification). Arch-side codification in flight (this ADR + Issue #604).

## Decision

Adopt **§AC mapping verification doctrine** with 5 canonical components:

### §1 — Mandatory pre-ratification check

**Trigger**: Every arch verdict on `type:docs` PR with `agent:architect` label MUST execute §AC mapping verification BEFORE posting verdict comment.

**Why**: Arch verdict is the lane-monitoring signal that downstream peers (tester, PM, owner) rely on for AC list correctness. If arch verdict passes with AC drift undetected, the drift propagates downstream as spec-level truth, forcing costly mid-flight rescope (cycle 647 LIVE INSTANCE cost = 5-lane consensus + AC4 mid-flight rescope).

**Pre-condition**: Design doc MUST have a §Acceptance Criteria section listing AC1..ACn. If absent → exit code 2 (legacy/exception, log warning, proceed with arch verdict — explicit non-silent).

### §2 — Protocol (6 steps)

**Step 1**: Re-query impl branch AC list via gh API (`gh api repos/{owner}/{repo}/pulls/{N} --jq '.body'`).

**Step 2**: Extract AC labels from impl body using regex `^- \*\*AC\d+\*\*/` OR `^- AC\d+/` (tolerates both `**AC1**` and `AC1` forms).

**Step 3**: Extract AC labels from design doc §Acceptance Criteria using same regex.

**Step 4**: Compare: 1:1 set match required on AC1..ACn. AC0 (impl-only housekeeping) is exempt.

**Step 5**: If drift detected → flag in 9-Lens review (lens a: data flow) as 🟡 NEEDS CHANGES, citing drift (`design=[AC1,AC2,AC3], impl=[AC1,AC2,AC4]`).

**Step 6**: If no drift → AC mapping verification passed ✅, proceed with arch verdict (🟢 OK / 🟡 Suggestion / 🔴 Block).

### §3 — Doctrine protocol exit codes

| Code | Semantic | Verdict action |
|------|----------|----------------|
| 0 | AC list 1:1 verified | Proceed with verdict (🟢 / 🟡 / 🔴) |
| 1 | AC drift detected | Verdict must include 🟡 NEEDS CHANGES citing drift |
| 2 | Design doc has no AC section | Log warning, proceed (legacy/exception, explicit non-silent per ADR-0048 lens d) |
| 3 | Impl branch not yet opened | Doctrine dormant this iteration (design-only), proceed |

**Why explicit exit codes**: Doctrine protocol exit codes mirror ADR-0015 atomic 4-flag handoff states. Each exit code has a prescribed verdict action — no implicit / silent skip path. Per ADR-0048 lens d (silent-skip risk), every conditional branch MUST log a structured event.

### §4 — 9-Lens lens a (data flow) augmentation

Per ADR-0045 9-Lens pre-publish gate, lens a (data flow) is augmented with AC mapping verification:

```yaml
lens_a_data_flow:
  standard_check: "Trace request/response path end-to-end"
  doctrine_augmentation: "Verify design doc AC1..ACn 1:1 mirrors impl branch AC list (STORY-S18-001)"
  output:
    verified: "AC mapping 1:1 ✅, data flow trace clean"
    drift: "AC drift detected: design=[AC1,AC2,AC3], impl=[AC1,AC2,AC4] — NEEDS CHANGES"
```

**Sister-pattern**: lens augmentation = additive to existing 9-Lens checks, NOT replacement. AC mapping verification augments lens a; other 10 lenses unchanged.

### §5 — Cross-lane "verify-before" triangle completion

This ADR + .claude/agents/architect.md amendment completes the cross-lane "verify-before" doctrine triangulation:

- **PM-side §Pre-citation cross-check** (Issue #430) — ratified
- **PM-side §Timing window** (Issue #470) — ratified
- **Arch-side §AC mapping verification** (this ADR) — codification in flight (Sprint 18 P0#1)

**Triangle complete when**: Both PM-side ratified + Arch-side ratified by owner (PR with this ADR merged to main). Arch slice is the LAST doctrine needed for triangulation completion.

**Sister-pattern to orchestrator §Verdict-by Discipline**: PR #612 codifies orch-side expectation-setting (verdict-by:<ts> + cc:<role>). Combined with PM-side + Arch-side doctrines, 3-lane expectation + verification doctrine triangulation is in flight for Sprint 18.

## Rationale

### Why this doctrine now (cycle 647 LIVE INSTANCE)

Cycle 647 surfaced as a real drift event in Sprint 17 P1 cluster. Without codified doctrine, future AC drift events rely on:
- Tester doctrinal clear catching drift late (impl phase)
- 5-lane ad-hoc consensus resolving drift (expensive, not always feasible)
- Owner escalation as backstop (slow, not scalable)

Doctrine codifies the EARLY detection path (arch verdict phase, BEFORE peer review phase) and eliminates tester-as-drift-catcher anti-pattern.

### Why file ownership matrix correctness (architect.md over script)

Per file ownership matrix:
- `.claude/agents/architect.md` = arch lane draft territory (owner squash gate for soul amendment)
- `scripts/` + `scripts/tests/` = dev lane territory (out of scope for arch slice)
- `.github/workflows/` = human-only territory (out of scope)

Doctrine codification in `architect.md` is the **correct lane** for arch doctrine. Script-based enforcement (Option B in design doc) is Sprint 19+ candidate when dual-channel-enforcement d-test (RETRO-012 §d065 sister-pattern) warrants it.

### Why doctrine not CI gate (Sprint 19+ deferred)

Per Issue #604 spec: "doctrine-only this sprint; CI gate / script enforcement is Sprint 19+ candidate". Doctrine codification is the **first step**; CI gate enforcement comes after doctrine has been operationally validated for ≥1 sprint.

### Why cross-lane "verify-before" triangle (3-lane triangulation)

PM-side doctrines (Issue #430 + #470) + Arch-side doctrine (this ADR) = 3-lane "verify-before" triangulation. Each lane enforces its own verify-before protocol at verdict time:
- PM: comments[] + reviews[] + ground truth timing window
- Arch: design doc AC list + impl branch AC list mirror
- Orch: cc:<role> + verdict-by:<ts> expectation-set (PR #612)

All 3 lanes converge on **peer-verdict-quality** as the shared objective. Triangulation ensures no single lane is the verify-before bottleneck.

## Consequences

### Positive outcomes

1. **AC drift eliminated as failure mode** — every arch verdict 1:1 verifies AC list before peer review phase. Cycle 647-class drift events become structurally impossible.
2. **Tester role returns to doctrinal clear, not drift detection** — tester no longer catches arch slice drift (which is arch's job, not tester's). Tester focuses on d-test sign-off per ADR-0044.
3. **Owner escalation cost reduced** — ad-hoc 5-lane consensus on AC drift (cycle 647 cost) replaced by deterministic arch verdict verdict (🟡 NEEDS CHANGES citing drift).
4. **Cross-lane "verify-before" doctrine triangulation complete** — 3-lane peer-verdict-quality framework operationalized. PM-side + Arch-side + Orch-side doctrines form a coherent verification ecosystem.

### Negative tradeoffs

1. **Arch verdict latency increases** — every arch verdict now requires gh API call + grep + set comparison. Estimate +2-5s per verdict (within p95 budget of design doc §Performance budget).
2. **AC0 exemption needs governance** — design doc spec'd AC1..ACn, impl legitimately may add AC0 (impl-only housekeeping). Doctrine protocol allows AC0 exemption, but requires consistent interpretation across arch verdicts. Open question in design doc §Open questions.
3. **Doctrine dormant on design-only iterations** — when impl branch not yet opened (exit code 3), doctrine doesn't fire. Drift undetected until impl phase. Mitigation: design doc §Acceptance Criteria is the canonical home for AC list (impl must mirror it, not the other way around).

### Follow-up tickets to file

- **TD-NEW (TBD)**: AC0 exemption scope clarification (doctrine OQ #1) — Sprint 18+ backlog candidate.
- **TD-NEW (TBD)**: Doctrine enforcement at PR creation vs PR review (doctrine OQ #2) — Sprint 18+ backlog candidate.
- **TD-NEW (TBD)**: Cross-repo propagation timeline (doctrine OQ #3) — Sprint 19+ candidate.
- **Sprint 19+ CI gate**: scripts/check-ac-mapping.sh + d-test sister-pattern (RETRO-012 §d065 sister) — out of scope for Sprint 18.

## Alternatives considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **A. Codify in architect.md (CHOSEN)** | Operates on arch lane directly; minimal ceremony; aligned with file ownership matrix (architect.md = arch territory draft, owner merge) | Requires owner squash gate; soul amendment slower than script change | ✅ CHOSEN — file ownership matrix correctness |
| B. CI gate / script enforcement | Automated; faster detection | Out of scope per Issue #604 (doctrine-only this sprint); Sprint 19+ candidate | ❌ deferred |
| C. Tester lane AC verification | Testers already verify AC traceability | Tester lane AC verification out of scope per Issue #604; separate doctrine candidate | ❌ out of scope |
| D. Backfill historical ADR drift | Catches existing drift | Out of scope (forward-looking only); historical ADRs are exempt | ❌ out of scope |

## Cross-references

### Doctrinal anchors

- **Issue #113** — labels > body doctrine (AC list extraction via labels, not body inference)
- **Issue #430** — PM-side §Pre-citation cross-check (verify-before triangle, ratified)
- **Issue #470** — PM-side §Timing window for cross-peer consensus re-query (verify-before triangle, ratified)
- **Issue #604** — STORY-S18-001 §AC mapping verification doctrine codification (this ADR closes)
- **ADR-0012** — 4-cat label invariant (AC list comparison = 4-cat invariant applied to spec level)
- **ADR-0015** — atomic 4-flag handoff (doctrine protocol exit codes 0/1/2/3 = handoff states)
- **ADR-0045** — 9-Lens pre-publish gate (lens a data flow augmented with AC mapping verification)
- **ADR-0048** — type-driven verdict gate matrix (type:docs = arch lane-monitoring informational)
- **ADR-0049** — d-test framework (Sprint 19+ CI gate sister-pattern)
- **ADR-0055** — Cadence Rule 1 atomic (ADR + design doc + INDEX.md in same PR)
- **ADR-0059** — cluster-squash batch-lag detection (sister-pattern: previous arch design + ADR atomic per PR #595)

### Sprint 17 P1 cluster precedents

- **PR #595** — ADR-0059 + STORY-P1-1 design (MERGED, sister-pattern: ADR + design + INDEX atomic)
- **PR #597** — STORY-P1-1 cluster-lag-detector.sh impl (cycle 647 AC drift LIVE INSTANCE)
- **PR #598** — RETRO-012 ProcessGap retro + post-squash cleanup (origin for §1 arch AC drift codification candidate)
- **cmt 4826300692** — 5-of-5 lane consensus on AC4 rescope (cycle 647 disposition)
- **cmt 4826367793** — Tester doctrinal clear catching AC drift (cycle 647 detection)
- **cmt 4826384857** — Arch FINAL 🟢 on PR #597 (cycle 658 verdict, sister-pattern)
- **cmt 4826492842** — Arch FINAL 🟢 on PR #598 (cycle 675 verdict, RETRO-012 origin)
- **cmt 4826303998** — PM sponsor commitment for cross-lane codification

### Sprint 18 cross-lane trigger

- **Issue #605** — Sprint 18 P0#2 cluster-lag-detector YAML wiring (dev lane, ADR-0061 candidate, awaiting dev impl for arch design review)
- **Issue #608** — Sprint 18 P0#5 §Verdict-by Discipline (orch lane, codification via PR #612 sister-pattern)

— @architect, 2026-06-28T18:11+03:00, ADR-0060 §AC mapping verification doctrine codification, canonical home for cross-lane "verify-before" triangle (PM-side ratified + Arch-side codification in flight), sister-pattern to PR #595 (ADR-0059) + PR #598 (RETRO-012) + PR #612 (verdict-by Discipline codification), 5-of-5 lane consensus principle preserved (cycle 647 disposition pattern)
