# ADR-0063 — Layer 4 Cascade-Strip Scope-Tightening Part 2: Lane-Transition Skip (RETRO-016 #6 carrier)

- **Status:** Proposed (Sprint 22 P2 doctrine hardening, Closes Issue #706 AC1 + RETRO-016 #6 cluster)
- **Date:** 2026-06-30
- **Deciders:** @architect (doctrine/spec), @product-manager (Path A business ratification per Issue #706 §Recommended path), @tester (d-test contract — 3 TCs minimum per ADR-0049 + ADR-0044 RED-first), @developer (yaml impl in `.github/workflows/label-check.yml` per file ownership matrix human-only territory → owner merges), @atilcan65 (owner squash gate for workflow file)
- **Parent ADR:** [ADR-0012-required-label-set](./ADR-0012-required-label-set.md) — §Cascade-strip scope-tightening Part 1 (PR #426)
- **Amends:** ADR-0012 by adding **Part 2.5** — Layer 4 cascade-strip MUST skip `unlabeled` events with `cc:*` or `needs-*-signoff` label names (lane-transition events are verdict semantics, not status-reset signals)
- **Closes:** Issue #706 (RETRO-016 #6 — Layer 4 cascade-strip + Layer 5 TC4 reversal race strip status:ready on tester APPROVED PRs, PR #705 LIVE INSTANCE)
- **Sister-patterns:** ADR-0012 (cascade-strip Part 1 — scope-limit duplicate status:* removal), ADR-0012 Part 2 (`status:ready` auto-add gating, ADR-0048), ADR-0048 (Layer 5 status:ready auto-add), ADR-0048-amendment-verdict-state-aware (Path A), ADR-0056 (Layer 5 idempotency reconcile), ADR-0062 (RETRO-016 #5 — Layer 5 label-change verdict gate), ADR-0044 (TDD RED discipline), ADR-0049 (d-test framework), ADR-0055 (Cadence Rule 1 atomic — this ADR + INDEX.md row in same PR), Issue #675 (P0 Layer 5 misfire regression), Issue #393 (PR #393 canonical cascade-strip case), Issue #394 (Part 1 amendment carrier), Issue #430 (PM §Pre-citation cross-check), Issue #470 (PM §Timing window 30s), RETRO-016 #1 (Issue #680), RETRO-016 #3 (Issue #682), RETRO-016 #5 (Issue #696), RETRO-016 #6 (THIS), PR #705 (LIVE INSTANCE), PR #426 (Layer 4 cascade-strip yaml, sister-pattern Part 1)

---

## Context

ADR-0012 §Cascade-strip scope-tightening Part 1 (PR #426, merged Sprint 12) established that when a PR has multiple `status:*` labels (e.g., `status:in-review + status:ready`), Layer 4 must remove **only the duplicate** (most-recent by createdAt) and preserve the canonical primary (oldest). It MUST NOT cascade-strip the reviewer chain (`cc:*` + `needs-*-signoff`).

**However, Part 1's cascade-strip fires on the `unlabeled` event regardless of what was unlabeled.** When the `unlabeled` label is `cc:tester` or `needs-tester-signoff` (i.e., a **lane-transition event** signaling tester verdict posted), Part 1's strip is **incorrect** — the layer is interpreting a verdict lane transfer as a duplicate-status trigger.

### Triggering LIVE INSTANCE (RETRO-016 #6)

**PR #705** (2026-06-29, @tester APPROVED cmt 4836513798):

| Time (Z) | Bot marker | Layer | Action |
|----------|------------|-------|--------|
| 19:58:21Z | (tester verdict) | — | PR Review APPROVED posted (tester self-sign-off) |
| 19:58:36Z | `<!-- adr-0012-cascade-strip-tightening -->` | Layer 4 | Trigger: `unlabeled cc:tester`. Status labels observed: `status:in-review, status:ready`. Primary (oldest): `status:in-review`. **Removed: `status:ready`** as duplicate |
| 19:58:38Z | `<!-- adr-0012-status-ready-gating -->` | Layer 5 | Trigger: `unlabeled needs-tester-signoff`. `status:ready` auto-added (per ADR-0048 §Type-driven) |
| 19:59:45Z | `<!-- adr-0012-status-ready-gating-reversal -->` | Layer 5 TC4 reversal | Trigger: `undefined` event, action=`labeled`, label=`needs-tester-signoff`. **Removed: `status:ready`** ("tester re-rejected after APPROVED — needs-tester-signoff re-added" per bot log) |

**Net pathology**: `status:ready` added then removed twice. Final state: no `status:*` label on PR (`type:feature + agent:developer + cc:human` only). **4-cat invariant visually broken** until owner manually re-adds `status:ready`.

### Root cause

**Layer 4 cascade-strip (`.github/workflows/label-check.yml` L319-423)**:
- Reads `target.labels` from event payload snapshot (line 345)
- Sees `[status:in-review, status:ready, ...]` at `unlabeled cc:tester` event time
- Line 387-399: sorts by `earliestByName.get()` createdAt, treats newer `status:ready` as duplicate, removes it
- **Bug**: Doesn't distinguish between Layer 5's INTENTIONAL `status:ready` add (per ADR-0048, auto-promote on reviewer-chain-clear) and an accidentally-duplicated `status:*` label

**Layer 5 TC4 reversal handler (`.github/workflows/label-check.yml` L500-521)**:
- Fires on `labeled needs-tester-signoff && hasLabel('status:ready')`
- Removes `status:ready` unconditionally
- **Bug**: Doesn't verify the `labeled needs-tester-signoff` event was triggered by an actual tester re-rejection (vs. a phantom/side-effect re-label from Layer 4 cascade-strip)

**Race window**:
1. Tester approves → triggers `unlabeled cc:tester` + `unlabeled needs-tester-signoff` (sequence not guaranteed)
2. Layer 4 fires on `unlabeled cc:tester` → sees 2 status labels → cascade-strips `status:ready`
3. Layer 5 fires on `unlabeled needs-tester-signoff` (sister event) → re-adds `status:ready`
4. Some `labeled needs-tester-signoff` event fires (Layer 4 cascade-strip side-effect, or workflow re-trigger) → Layer 5 TC4 reversal removes `status:ready` again
5. Net: `status:ready` absent

## Decision

**Path A** (recommended per Issue #706 §Recommended path) — extend Layer 4 cascade-strip scope-tightening with **Part 2.5 — Lane-transition event skip**. Layer 4 MUST skip `unlabeled` events where the unlabeled label starts with `cc:` or `needs-`, because these are **intentional lane transitions**, not status-reset signals.

### §Part 2.5 Lane-Transition Skip (proposed)

Additive to ADR-0012 §Part 1 (PR #426) + §Part 2 (ADR-0048 status:ready auto-add gating):

```yaml
# PSEUDOCODE (label-check.yml Layer 4, line ~364 early-return):
# ------------------------------------------------------------------
# ADR-0063 Part 2.5 (Issue #706 RETRO-016 #6): Layer 4 cascade-strip
# MUST skip unlabeled events where the unlabeled label is a lane-
# transition signal (cc:* or needs-*-signoff). Verdict lane transfers
# are verdict semantics, not status-reset triggers.
# Sister-pattern: ADR-0048 silent_skip lens d; Issue #675 TC1 short-
# circuit on status:* unlabeled. PR #705 LIVE INSTANCE.
# ------------------------------------------------------------------
if (evtAction === 'unlabeled' &&
    context.payload.label &&
    (context.payload.label.name.startsWith('cc:') ||
     context.payload.label.name.startsWith('needs-'))) {
  core.info(`[Layer 4 RETRO-016 #6] lane-transition short-circuit (label=${context.payload.label.name}) — verdict semantics, not status reset.`);
  return;  // skip cascade-strip; allow existing logic to handle status:* state
}
```

### Decision rules

| Event type | Unlabeled label is `cc:*` or `needs-*` | Layer 4 action |
|------------|----------------------------------------|----------------|
| `unlabeled cc:tester` (tester lane transfer) | ✅ yes | **SKIP cascade-strip** (Part 2.5) |
| `unlabeled cc:developer` (dev lane transfer) | ✅ yes | **SKIP** |
| `unlabeled cc:architect` (arch lane transfer) | ✅ yes | **SKIP** |
| `unlabeled cc:human` (owner lane transfer) | ✅ yes | **SKIP** |
| `unlabeled needs-tester-signoff` (signoff cleared) | ✅ yes | **SKIP** |
| `unlabeled needs-architect-review` (signoff cleared) | ✅ yes | **SKIP** |
| `unlabeled status:ready` (manual flip per Issue #675 TC1) | ❌ no (status:) | Existing logic (Layer 5 silent_skip) — handled by separate branch |
| `unlabeled status:in-review` (manual flip) | ❌ no | Existing cascade-strip logic (Part 1 — preserves canonical primary) |

### Why Path A (not B/C from Issue #706 §Recommended fix candidates)

**Path B (Layer 5 TC4 reversal verify re-rejection signal)** — adds sender-type check + re-rejection signal in same event payload. **Rejected**:
- (+) No false-strip on legitimate re-rejection
- (-) Doesn't fix the underlying Layer 4 over-strip pathology (race still observable via `unlabeled cc:tester` → cascade-strip fires before Layer 5 re-add)
- (-) Combines multiple event semantics into one check (sender-type + re-rejection signal); harder to d-test
- (-) Layer 5 reversal handler has different scope than Layer 4 cascade-strip; mixing concerns

**Path C (post-event state fetch)** — both Layer 4 and Layer 5 fetch CURRENT labels via `github.rest.issues.listLabels` instead of reading from event snapshot. **Rejected**:
- (+) No stale-snapshot race
- (-) Latency: extra API call per event (Layer 4 + Layer 5 × N events)
- (-) GitHub Actions rate-limit risk on high-traffic repos (~5000/hr cap)
- (-) Sister-pattern: ADR-0062 already prefers piggybacking on existing API calls
- (-) Doesn't address the doctrinal gap (Layer 4 interpreting lane-transition as status-reset)

**Path A (Layer 4 lane-transition skip)** — **CHOSEN**:
- (+) Minimal LoC js delta (~6 LoC, sister-pattern to Issue #675 TC1 short-circuit)
- (+) Doctrinal clarity: lane-transition events are verdict semantics (Lane Discipline per ADR-0015), Layer 4 (status-cascade layer) should not interpret them
- (+) Sister-pattern to Layer 5 TC1 (Issue #675 silent_skip) — both layers short-circuit on lane-transition `unlabeled` events
- (+) No new API calls (uses event payload already in scope)
- (+) Compatible with ADR-0056 (Layer 5 idempotency reconcile) — Layer 5 still self-corrects on next label event
- (-) Doesn't address Layer 5 TC4 reversal phantom-trigger separately (separate doctrine gap, deferred)

### Why now (Sprint 22 P2 not later)

RETRO-016 cluster (#1, #3, #5, #6) has 4 LIVE INSTANCES in 2 days (PR #679 + #695 + #705 + #692). Pattern is **active, not historical**. Sprint 22 P2 doctrine hardening is the right vehicle.

PR #705 specifically blocks Sprint 21 Wave 2 PR squash cadence — current state has `type:feature + agent:developer + cc:human` only (no `status:*`); owner cannot squash until `status:ready` is manually re-added (one-shot operator action per Issue #706 §Decision matrix option (b)).

## Rationale

### Why extend Layer 4 (not Layer 5 reversal handler)

| Option | Cost | Doctrinal clarity | Symmetry | Verdict |
|--------|------|-------------------|----------|---------|
| **A. Layer 4 lane-transition skip (THIS)** | ~6 LoC | High (lane-transition ≠ status-reset) | Sister-pattern Issue #675 TC1 | ✅ **Chosen** |
| **B. Layer 5 reversal verify re-rejection** | ~25 LoC | Medium (sender-type check + signal) | None | ❌ Doesn't fix L4 over-strip |
| **C. Both Layer 4 + Layer 5 fetch current state** | ~40 LoC | Low (state-reconciliation in two layers) | None | ❌ Latency + rate-limit |
| **D. Disable Layer 4 cascade-strip entirely** | ~0 LoC | Very low (loses Part 1 duplicate removal) | None | ❌ Reverts PR #393 fix |

### Evidence

- **PR #705** — primary LIVE INSTANCE (bot audit-trail 19:58:36 + 19:58:38 + 19:59:45)
- **PR #393** — canonical Part 1 case (PR #426 amend) — sister-pattern
- **PR #679** — RETRO-016 #1 sister
- **PR #695** — RETRO-016 #5 sister (Issue #696)
- **ADR-0048-amendment** — Path A verdict-state-aware WARN-not-FAIL proven in production
- **ADR-0056** — Layer 5 idempotency reconcile WARN-not-FAIL proven in production

### Compatibility

- ✅ Backward compatible with ADR-0012 Part 1 (canonical-primary duplicate removal preserved for non-lane-transition events)
- ✅ Backward compatible with ADR-0048 (Layer 5 `status:ready` auto-add unchanged; only Layer 4 cascade-strip fires less often)
- ✅ Backward compatible with ADR-0056 (Layer 5 idempotency reconcile still self-corrects on next event)
- ✅ Backward compatible with ADR-0062 (RETRO-016 #5 — Layer 5 label-change verdict gate; orthogonal concern, no overlap)

## Consequences

### Positive

- ✅ PR #705 race pattern closed; `status:ready` will not be cascade-stripped on lane-transition `unlabeled` events
- ✅ Layer 4 doctrine gap closed (Layer 4 = duplicate-status layer; NOT verdict-lane layer)
- ✅ 9-Lens lens (b) Runtime preconditions + lens (d) Silent-skip improved (Layer 4 silent_skip on lane-transition)
- ✅ Sister-pattern symmetry with Layer 5 TC1 (Issue #675) — both layers short-circuit on lane-transition `unlabeled`
- ✅ ~6 LoC implementation (within Sprint 22 P2 budget; well below Path B + C cost)
- ✅ PR #705 owner-disposition actionable: re-add `status:ready` (Issue #706 §Decision matrix option (b))

### Negative (mitigated below)

- ⚠️ Edge case: what if a PR has actual `status:*` duplicate + concurrent `cc:tester` removal? (R1) — mitigate: duplicate-status removal is Part 1 sister-pattern; Part 2.5 only skips when the UNLABELED label is `cc:*` or `needs-*`; if a separate `status:*` add/remove fires, Part 1 still applies
- ⚠️ Layer 5 TC4 reversal handler remains unfixed (separate phantom-trigger pathology) (R2) — mitigate: deferred to Sprint 23+ (out of RETRO-016 #6 scope; Layer 5 reversal is distinct concern)
- ⚠️ Owner merge required per file ownership matrix (R3) — mitigate: standard Sprint 22 P2 codification workshop flow (arch drafts, tester signs off, owner merges)
- ⚠️ PR #705 still needs manual `status:ready` re-add (R4) — mitigate: one-shot operator action per Issue #706 §Decision matrix option (b); document in PR #705 squash notes

### d-test integration

**New d-test required** — d098 (Sprint 22 P2 codification, sister-pattern d069/d073/d075/d076/d077/d081/d091/d093 family):

```bash
# d098 d-test contract (proposed, ADR-0049 + ADR-0044 RED-first):
# 3 minimum TCs per ADR-0049:
# TC1: PR with status:in-review + status:ready → unlabeled cc:tester → status:ready preserved (Part 2.5 SKIP)
# TC2: PR with status:in-review + status:ready → unlabeled status:in-review → status:ready preserved as canonical primary (Part 1 unchanged)
# TC3: Regression — PR with actual duplicate status:in-review + status:in-review-stale → unlabeled status:in-review-stale → status:in-review-stripe removed (Part 1 unchanged)
# Optional TC4: PR #705 replay simulation (full Lane 4 + Lane 5 sequence, verify final state has status:ready)
```

**Cadence Rule 1 atomic (ADR-0055 §1)**: this ADR + d098 + INDEX.md row in same PR.

### Sister-pattern: future prevention

- **Issue #696** (RETRO-016 #5) — Layer 5 false-positive verdict-gate on cc:* label-change. **Separate ADR** (ADR-0062) — Layer 5 doctrine gap; orthogonal concern.
- **Issue #680** (RETRO-016 #1) — already closed by PR #683 (Layer 5 initial-add race)
- **Issue #682** (RETRO-016 #3) — closed by PR #692 (cross-watchdog 30s gap)
- **Layer 5 TC4 reversal handler phantom-trigger** (R2 above) — Sprint 23+ P3 candidate

## Implementation checklist (Sprint 22 P2 codification)

**Pre-Faz 0 (arch + tester)**:
- [ ] d098 d-test drafted (tester-led, RED-first per ADR-0044)
- [ ] 3 minimum TCs as above (TC1/2/3) + optional TC4 PR #705 replay

**Faz 0 (arch authored)**: ✅ THIS ADR (docs PR lane; sprint-gated)

**Faz 1 (dev + tester)**:
- [ ] 1.1 yaml impl in `.github/workflows/label-check.yml` (~6 LoC js, file ownership matrix human-only → owner merges)
- [ ] 1.2 d098 TC1/2/3 GREEN

**Faz 2 (owner)**:
- [ ] 2.1 Owner manually re-add `status:ready` to PR #705 (one-shot operator action per Issue #706 §Decision matrix option (b))
- [ ] 2.2 Owner squash PR #705 + sprint 22 wave merge (status:ready restored, 4-cat invariant intact)
- [ ] 2.3 Owner squash workflow file change PR for Part 2.5

**Faz 3 (orch + all)**:
- [ ] 3.1 RETRO-016 watchlist updated: #6 closed by THIS ADR
- [ ] 3.2 Issue #706 status:done

## Cross-refs

- **Issue #706** — primary carrier (RETRO-016 #6)
- **PR #705** — LIVE INSTANCE (bot audit-trail)
- **ADR-0012** — cascade-strip Part 1 (this ADR adds Part 2.5)
- **ADR-0048** — status:ready auto-add gating (Part 2 of ADR-0012 cascade-strip scope-tightening)
- **ADR-0048-amendment** — Path A verdict-state-aware
- **ADR-0056** — Layer 5 idempotency reconcile
- **ADR-0062** — RETRO-016 #5 sister (Layer 5 label-change verdict gate)
- **File ownership matrix**: `.github/workflows/` = human-only (arch + tester draft, owner merges)
- **RETRO-016** cluster: #1 (Issue #680) + #3 (Issue #682) + #5 (Issue #696, ADR-0062) + #6 (Issue #706, THIS)

— @architect, cycle ~#1610, 2026-06-30T10:56:30Z + 03:00 = 07:56:30Z, drafted post-claim-next-ready auto-pickup
