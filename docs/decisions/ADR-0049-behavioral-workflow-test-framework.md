# ADR-0049: Behavioral Workflow Test Framework (d050b) — workflow_dispatch + Mock PR Payload

- **Status**: Proposed
- **Date**: 2026-06-26
- **Deciders**: @architect + @tester (design), @developer (impl), @human-owner (.github/workflows/ territory)
- **Closes**: Issue #440 (priority:P0 hotfix per Issue #441 cascade)
- **Sister-patterns**: ADR-0044 (TDD RED-first), ADR-0048 (Layer 5 status:ready auto-add gating), ADR-0046 (load-bearing ADR §Implementation guide), RETRO-006 §Behavioral d-test doctrine

## Context

The label-check.yml workflow family (`actions/github-script` v7) has suffered **3 P0 regressions in 24 hours**:

| Date | Issue | Layer | Root cause | D-test gap |
|---|---|---|---|---|
| 2026-06-26T13:22Z | #436 | Layer 5 (L408+) | `context.event.action` runtime TypeError on `pull_request_target` | d048 TC1-TC4 content-anchor only |
| 2026-06-26T13:46Z | #439 | Layer 4 (L337) | Same `context.event.action` pattern, sister-bug | d048 TC5 added (Layer 5 only), TC6 missed Layer 4 syntactic check |
| 2026-06-26T14:42Z | #441 | Layer 4 (L337) | Hotfix dropped closing backtick during substitution, JS SyntaxError | d048 TC6 content-anchor (positive + negative grep) misses JS syntax |

**Pattern**: content-anchor grep catches **what strings exist** but not **whether the resulting JS parses** or **whether the workflow behaves correctly at runtime**.

**Architectural verdict gap (RETRO-006 cluster)**: My own 9-Lens review on PR #434 (🟢 OK), PR #438 v1 (🟢 OK), and PR #438 v2 (🟢 OK) all missed these regressions. **2nd rubber-stamp pattern confirmed** (PR #434 + PR #438 v2).

**RETRO-006 lesson**: workflow-script review requires **3-layer d-test defense**:
1. **Content anchor** (d048 family) — does the right string exist? (cheap, fast, catches obvious regressions)
2. **Syntactic correctness** (NEW) — does the modified JS parse? (catches edit-time typos like Issue #441)
3. **Behavioral runtime** (NEW) — does the workflow execute correctly with sample payloads? (catches semantic regressions like Issue #436)

## Decision

Adopt **workflow_dispatch + mock PR payload + behavioral assertion** as the d050b test framework shape. Implemented as:

- **Trigger**: `workflow_dispatch` with input schema `run_id`, `target_layer`, `mock_pr_payload`
- **Mock PR payload**: committed JSON fixtures at `scripts/tests/fixtures/d050b-mock-pr-{layer}.json` (hermetic, versioned, auditable)
- **Runtime assertion**: Node.js `assert` + github-script execution context, asserts (a) no TypeError/SyntaxError, (b) expected label transitions, (c) audit comment posted with expected marker
- **Sandbox mode**: `dry_run: true` input flag skips API calls (no real label edits, no real comments) — dispatch PR stays clean
- **CI integration**: triggers on `paths: .github/workflows/**` OR `paths: scripts/tests/d050b-**` OR `paths: scripts/tests/fixtures/d050b-**`

## Rationale

### Why workflow_dispatch (vs `act` local runner, vs shell mock)

| Option | Fidelity | Portability | Speed | Verdict |
|---|---|---|---|---|
| **workflow_dispatch + mock payload** | High (real GitHub Actions context) | High (no extra deps) | Medium (real workflow run) | ✅ **Adopt** |
| `act` local runner | Medium (known gaps with `actions/github-script` token context) | Low (needs Docker, not in `[dev]` extras) | Slow (boots container per run) | ❌ Rejected |
| Shell-based mock | Low (no actual `actions/github-script` eval) | High | Fast | ❌ Rejected (no semantic verification) |

### Why mock payload committed (vs generated inline)

- **Reproducibility**: same payload → same workflow behavior → same assertion result. Inlined payloads drift across PRs.
- **Audit trail**: PR reviews can inspect fixture diffs alongside workflow diffs.
- **Cross-sprint stability**: fixture stays valid even when workflow changes (test catches both regression AND expected behavior shift).

### Why `dry_run: true` sandbox

- **CI hygiene**: dispatch-triggering PR stays clean (no real label flips, no real comments).
- **Cost**: skipped API calls save Actions minutes (especially on Layer 5 stress tests).
- **Security**: dispatch to a throwaway mode = no surface for accidental destructive ops.

### Why trigger on `scripts/tests/d050b-**` + `fixtures/d050b-**`

- Test fixture breakage caught at PR time, not post-merge.
- TDD discipline (ADR-0044): test-first changes trigger the framework that verifies them.

## Consequences

### Positive

- **3rd P0 prevented**: Issues #436 + #439 + #441 would have been caught at PR time by d050b TCs TC4 + TC5.
- **Architect review burden reduced**: 9-Lens lens (j) auto-gen file refs + live-state verification now has a behavioral complement. Lens (b) Runtime preconditions + (f) Observability get an enforcement mechanism beyond content-anchor.
- **Test pyramid**: content-anchor (cheap, frequent) → syntactic (medium, on workflow PRs) → behavioral (expensive, on dispatch) — tiered by cost matches signal.
- **Issue #414 §Dispatch Discipline compatibility**: d050b tests code; Issue #414 fixes process. Orthogonal, no conflict.

### Negative

- **Cost**: ~3.0 SP Sprint 12 P1 (ADR 0.5 SP + d-test 1.0 SP + framework impl 1.0 SP + integration 0.5 SP). 1 sprint of investment for N sprints of regression prevention.
- **Maintenance**: d050b test fixtures need updating when workflow logic legitimately changes. Risk: fixtures drift, false-positive failures. Mitigation: TC versioning per layer (d050b-layer5-v2.json when behavior shifts).
- **`.github/workflows/` write**: any new dispatch workflow = human-only territory per file ownership matrix. Architect + tester draft, owner merges.
- **Token-spending attack surface**: `workflow_dispatch` is a known fork-PR abuse vector. Mitigation: `permissions: contents: read, issues: write` (least-privilege) + `if: github.event_name == 'workflow_dispatch' && github.event.inputs.run_id == expected` (input validation). Documented in §Security below.

### Sprint boundary

- `docs/decisions/ADR-0049-*.md` (this file) = **architect** lane
- `scripts/tests/d050b-*.sh` + `scripts/tests/fixtures/d050b-*.json` = **developer + tester** joint (impl + d-test)
- `.github/workflows/d050b-dispatch.yml` (new file) = **human-only** territory (architect + tester draft, owner merges per file ownership matrix)
- Issue #440 priority flip (`P2 → P0`) = **PM** lane (priority labels typically PM-owned)

## §Security (ADR-0027 threat model)

### Threat: Token-spending via dispatch spam

**Attack vector**: Fork PR or compromised PAT triggers `workflow_dispatch` repeatedly to exhaust Actions minutes budget.

**Mitigations**:
1. `permissions: contents: read, issues: write` (least-privilege; no `pull-requests: write` for dispatch workflow)
2. `if: github.event_name == 'workflow_dispatch' && github.event.inputs.run_id == expected_run_id` (input validation; expected_run_id passed via env var set by d050b runner script only)
3. Concurrency: `concurrency: { group: d050b-${{ inputs.run_id }}, cancel-in-progress: false }` (prevent parallel dispatch explosions)
4. Rate limit: d050b runner script enforces max 5 dispatches per hour per repo (configurable)
5. Audit: every dispatch logged with `actor`, `run_id`, `target_layer`, `dry_run` flag → auditable via `gh api repos/{owner}/{repo}/actions/runs`

**Residual risk**: Low. Dispatch is owner-gated, fixtures are committed, dry_run is default.

### Threat: Mock payload injection

**Attack vector**: Compromised fixture file (`.json`) injects malicious payload that exploits github-script eval.

**Mitigations**:
1. Fixtures are JSON-only (no YAML, no inline JS); strict schema validation in d050b runner script
2. Fixtures reviewed as code (PR review on `scripts/tests/fixtures/d050b-**`)
3. `dry_run: true` is default — even if payload is malicious, no real API calls execute

**Residual risk**: Negligible. Fixtures are code, code-reviewed, no eval surface beyond github-script which is sandboxed by GitHub.

## §Implementation guide (ADR-0046 pattern)

### Sprint 12 P1 work breakdown (3.0 SP)

1. **ADR-0049 (this file) — 0.5 SP — architect**:
   - ✅ Drafted (this PR)
   - TODO: PM ratification, label flip priority:P2 → priority:P0
   - TODO: Dev impl ack

2. **d050b d-test (RED) — 1.0 SP — tester**:
   - TODO: Author `scripts/tests/d050b-behavioral-workflow-test.sh` with TC1 (workflow_dispatch schema), TC2 (basic_pull_request_labeled), TC3 (silent_skip_non_docs), TC4 (context.event.action regression — would have caught #436), TC5 (context.event.action syntax-error regression — would have caught #441)
   - TODO: Author fixtures `scripts/tests/fixtures/d050b-mock-pr-{layer4,layer5}.json`
   - TODO: RED-first per ADR-0044 (TCs RED before impl)

3. **d050b framework impl — 1.0 SP — developer**:
   - TODO: Author `.github/workflows/d050b-dispatch.yml` (NEW, human-only territory, owner merges)
   - TODO: Author `scripts/tests/d050b-runner.sh` (dispatches to workflow_dispatch with input schema)
   - TODO: GREEN TCs (all 5 TCs PASS)

4. **Integration + 9-Lens update — 0.5 SP — architect + tester joint**:
   - TODO: Architect updates `architect.md §9-Lens Review Checklist` with new sub-check:
     - **(k) JS syntactic correctness** (NEW) — for any PR touching `.github/workflows/*.yml`, extract the `actions/github-script` snippet and verify `node --check` passes. Catches Issue #441-class regressions.
   - TODO: Tester extends `d046` family with `node --check` invocation
   - TODO: Document in RETRO-006 §Behavioral d-test doctrine

### Acceptance criteria (mirror Issue #440 ACs)

- **AC1**: ADR-0049 accepted (this file) ✅
- **AC2**: `scripts/tests/d050b-behavioral-workflow-test.sh` implements all 5 TCs (TC1 dispatch schema, TC2 basic, TC3 silent-skip, TC4 event.action regression, TC5 syntax regression)
- **AC3**: `.github/workflows/d050b-dispatch.yml` exists, owner-merged, all 5 TCs PASS in CI on main
- **AC4**: RED-first TDD: TCs RED before framework impl (proven by d050b-runner.sh smoke test failing pre-impl)
- **AC5**: Future PRs touching `.github/workflows/label-check.yml` can leverage d050b as regression gate (TC4 + TC5 prevent Issue #436 + #441 recurrence)

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **workflow_dispatch + mock payload** (this ADR) | High fidelity, real GH Actions context, hermetic | Needs new workflow file (human-only) | ✅ Adopt |
| `act` local runner | No GH Actions minutes cost, fast local dev | `actions/github-script` v7 gaps, Docker dep, no real GH context | ❌ Rejected |
| Shell mock with octokit stub | No extra infra, easy to write | Doesn't exercise real github-script eval, low fidelity | ❌ Rejected |
| Static JS lint + content-anchor only | Cheapest | Misses behavioral regressions (Issue #436-class) | ❌ Rejected |
| Move all workflow logic to Python | Avoids JS entirely | Massive refactor, breaks sister-pattern, no benefit | ❌ Rejected |

## Open questions

- [ ] **Q1**: Concurrency limit on dispatch — 5/hour sufficient or lower? (Dev to research)
- [ ] **Q2**: Dry-run mode skips audit comment OR posts a `<!-- d050b-dry-run -->` marker? (Tester to decide based on observability lens)
- [ ] **Q3**: Layer 4 fixture scope — start with L337 audit body only, or full cascade-strip path? (Tester to scope in test plan)
- [ ] **Q4**: 9-Lens sub-check (k) — should it apply to ALL `.github/workflows/**` or only `actions/github-script` snippets? (Architect to refine; recommend: all scripts, scoped review)

## References

- Issue #436 (P0) — original `context.event.action` TypeError, RETRO-006 trigger
- Issue #439 (P2) — L337 sister-bug, absorbed in PR #438 v2
- Issue #441 (P0) — L337 syntax regression, this ADR's direct motivator
- Issue #440 (P0) — d050b spec, this ADR's container
- PR #434 — Layer 5 status:ready gating (arch verdict miss)
- PR #438 v2 — Layer 5+4 hotfix (arch verdict miss #2)
- ADR-0044 — TDD RED-first doctrine
- ADR-0046 — Load-bearing ADR §Implementation guide pattern (this ADR follows)
- ADR-0048 — Layer 5 status:ready auto-add gating (workflow sister-pattern)
- RETRO-006 §Behavioral d-test doctrine — in flight, this ADR codifies

— @architect, 2026-06-26T14:50Z, ADR-0049 d050b behavioral workflow test framework (P0, Issue #440, Issue #441 cascade)
