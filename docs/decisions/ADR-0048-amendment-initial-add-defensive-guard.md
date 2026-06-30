# ADR-0048 Amendment #2: Layer 5 Initial-Add Defensive Guard (DRAFT-PR + idempotent DELETE)

- **Status:** Proposed (RETRO-016 codification cycle ~1135)
- **Date:** 2026-06-29
- **Deciders:** @architect (doctrine/spec), @tester (d-test contract — extend d077 + add d078 per ADR-0044 RED-first), @developer (yaml impl proposal in `.github/workflows/label-check.yml` per file ownership matrix human-only territory → owner merges), @atilcan65 (owner squash gate for workflow file)
- **Parent ADR:** [ADR-0048](./ADR-0048-status-ready-auto-add-gating.md) — `label-check.yml` Layer 5: `status:ready` Auto-Add Gating (Type-Driven Reviewer Chain)
- **Sibling amendment:** [ADR-0048-amendment-verdict-state-aware](./ADR-0048-amendment-verdict-state-aware.md) — RE-ADD path bug (Issue #675 fix). THIS amendment is for INITIAL-ADD path bug (Issue #680).
- **Amends:** ADR-0048 §Type-driven reviewer chain table + §Pseudocode by adding (a) `hasStatus(inReview)` defensive guard before DELETE, (b) `isDraft` skip-guard before status:ready auto-add, (c) DRAFT-PR row in type-driven table
- **Closes:** Issue #680 (RETRO-016 candidate #1 — L5 initial-add race from PR #679)
- **Sister-patterns:** ADR-0048-amendment-verdict-state-aware (RE-ADD path), ADR-0056 (Layer 5 idempotency reconcile), ADR-0053 (Layer 5 race pattern), Issue #675 (sister LIVE INSTANCE — RE-ADD pathology), Issue #679 (RE-ADD fix PR #677), PR #679 (this amendment's LIVE INSTANCE — INITIAL-ADD pathology), PR #677 (sister fix PR for Issue #675), RETRO-016 watchlist candidate
- **Related:** ADR-0012 (4-cat label invariant), ADR-0015 (atomic handoff), ADR-0024 (verdict-by schema), Issue #113 (labels > body doctrine), Issue #523 (Layer 5 race pattern carrier), Issue #430 (PM §Pre-citation cross-check sister-pattern)

---

## Context

ADR-0048 Layer 5 (`status:ready` auto-add gating, type-driven reviewer chain) was already amended once via [ADR-0048-amendment-verdict-state-aware](./ADR-0048-amendment-verdict-state-aware.md) (RETRO-015 §16, Issue #675 fix, PR #677 merged Sprint 21 P1) to add verdict-state check before auto-promote. That fix addresses the **RE-ADD pathology** — Layer 5 re-adding `status:ready` on every `unlabeled` event regardless of verdict.

PR #679 (2026-06-29 12:43Z, d069 v2 parameterization, tester-authored, type:feature, DRAFT) surfaced a **DIFFERENT defect class — INITIAL-ADD pathology**:

### Live failure trace (PR #679)

| Time (UTC) | Actor | Action | Result |
|---|---|---|---|
| 12:43:0?Z | tester | Open PR #679 | Labels: `type:feature, status:ready, agent:tester, cc:{orch,arch,dev,human}` (no `status:in-review`) |
| 12:56:53Z | github-actions[bot] | Layer 5 trigger `pull_request_target.opened` | Pseudocode enters "non-docs path, type:feature" branch |
| 12:56:53Z | github-actions[bot] | `gh_pr_add_label("status:ready")` | ✅ success (idempotent — already present) |
| 12:56:54Z | github-actions[bot] | `gh_pr_remove_label("status:in-review")` | ❌ **HttpError 404: Label does not exist** |
| 12:56:54Z | github-actions[bot] | Unhandled error → **label-check job FAIL** | Issue #680 root cause |

### Defect class enumeration

The current ADR-0048 §Pseudocode has TWO initial-add path bugs:

1. **Unconditional `gh_pr_remove_label("status:in-review")`** — assumes every PR has `status:in-review` to remove. Tester-authored PRs opened via `gh pr create --label "status:ready" ...` skip the in-review phase (tester lane convention; d-test cluster gate flow per ADR-0044 + ADR-0059). Result: 404 crash + label-check job failure.

2. **No `isDraft` check** — DRAFT PRs (PR #679 was `isDraft=true` per gh api) are NOT ready for owner merge gate. Auto-adding `status:ready` to a DRAFT PR prematurely signals "ready for owner merge" — bypasses reviewer chain AND owner squash gate doctrine. Issue #523 sister-pattern: Layer 5 race pathology.

### Sister-pattern comparison

| Defect | Sister ADR | Trigger | Fix |
|---|---|---|---|
| RE-ADD (Issue #675) | ADR-0048-amendment-verdict-state-aware | `pull_request_target.unlabeled` fires repeatedly | Verdict-state check (🟢/🟡/🔴) before auto-promote |
| **INITIAL-ADD (Issue #680, THIS)** | **THIS ADR** | `pull_request_target.opened` on PR without `status:in-review` OR on DRAFT PR | (a) `hasStatus(inReview)` guard before DELETE, (b) `isDraft` skip-guard before status:ready |

Both are Layer 5 race pathologies but distinct defect classes. Both need separate amendments.

---

## Decision

**Three amendments to ADR-0048 §Type-driven reviewer chain table + §Pseudocode:**

### Amendment 1 — Defensive `hasStatus(inReview)` guard (idempotent DELETE)

Replace the unconditional DELETE in all three pseudocode branches (docs / non-docs / unknown) with a presence-check:

```javascript
// OLD (ADR-0048 §Pseudocode, all 3 branches):
gh_pr_add_label("status:ready")
gh_pr_remove_label("status:in-review")  // ← 404 crash if label absent

// NEW (this amendment):
gh_pr_add_label("status:ready")
if (hasLabel(pr, "status:in-review")) {  // ← defensive guard
  gh_pr_remove_label("status:in-review")
}
// else: silent skip + log (lens d observability per ADR-0048 amendment #1)
```

Rationale: Sister-pattern to ADR-0048-amendment-verdict-state-aware §"Idempotency via comments.find" — every state mutation MUST be idempotent (lens e per architect 9-Lens review). DELETE on absent label = 404 + job fail + cycle waste.

### Amendment 2 — `isDraft` skip-guard for `status:ready` auto-add

Add a draft-check BEFORE the type-driven reviewer chain table logic:

```javascript
// NEW (this amendment, prepended to Layer 5 main logic):
if (pr.isDraft) {
  create_audit_comment(marker="adr-0012-status-ready-gating-skip", reason="DRAFT PR — work-in-progress, not ready for owner merge gate")
  return  // skip all status:ready auto-add for DRAFT PRs
}
```

Rationale: DRAFT PRs are work-in-progress. Per ADR-0045 lens (d) silent-skip risk, premature `status:ready` on DRAFT PR is production-blind auto-promote — owner sees `status:ready + cc:human` and may merge without final reviewer chain resolution. This is the exact Issue #523 race pathology pattern.

### Amendment 3 — Type-driven reviewer chain table extension

Add a DRAFT row to the type-driven table:

| `pr.isDraft` value | Layer 5 action | Rationale |
|---|---|---|
| `true` (DRAFT) | ⏸️ Skip ALL auto-add (`status:ready` + `cc:human` companion) | DRAFT = work-in-progress, owner merge gate NOT applicable |
| `false` (non-DRAFT, ready-for-review) | Apply type-driven table as before | Existing semantics preserved |

Existing rows (`type:*` × reviewer-chain state) are unchanged.

### Updated pseudocode (complete, post-amendment)

```javascript
// Layer 5 main logic — POST-amendment-#2 (this ADR)
async function layer5_status_ready_autoadd(pr) {
  // Amendment 2 (this ADR): DRAFT-PR skip-guard
  if (pr.isDraft) {
    create_audit_comment(marker="adr-0012-status-ready-gating-skip", reason="DRAFT PR")
    return
  }

  // Existing type-driven logic (ADR-0048 §Pseudocode)
  if (pr_type == "type:docs" AND agent in [architect, product-manager, orchestrator]) {
    if (needs-architect-review is ABSENT OR pm_verdict_posted OR orch_verdict_posted) {
      gh_pr_add_label("status:ready")
      // Amendment 1 (this ADR): defensive guard
      if (hasLabel(pr, "status:in-review")) {
        gh_pr_remove_label("status:in-review")
      }
      create_audit_comment(marker="adr-0012-status-ready-gating", reason="docs PR verdict sufficient")
    } else {
      create_audit_comment(marker="adr-0012-status-ready-gating-skip", reason="docs PR but no verdict yet")
    }
  } else if (pr_type in [type:bug, type:feature, type:refactor, type:chore, type:incident]) {
    // Apply ADR-0048-amendment-verdict-state-aware verdict-state check first
    if (verdict_state === "approved" AND needs-tester-signoff is ABSENT) {
      gh_pr_add_label("status:ready")
      // Amendment 1 (this ADR): defensive guard
      if (hasLabel(pr, "status:in-review")) {
        gh_pr_remove_label("status:in-review")
      }
      create_audit_comment(marker="adr-0012-status-ready-gating", reason="non-docs PR verdict cleared")
    } else {
      create_audit_comment(marker="adr-0012-status-ready-gating-skip", reason="non-docs PR verdict pending")
    }
  } else {
    // Unknown type — defensive default (non-docs path)
    if (needs-tester-signoff is ABSENT) {
      gh_pr_add_label("status:ready")
      if (hasLabel(pr, "status:in-review")) {
        gh_pr_remove_label("status:in-review")
      }
      create_audit_comment(marker="adr-0012-status-ready-gating", reason="unknown type, default path")
    }
  }
}
```

### Sister-pattern to d077 (Layer 5 misfire regression d-test)

The existing **d077** (`scripts/tests/d077-layer-5-misfire.sh`) tests the **RE-ADD** pathology (Issue #675 fix). This amendment requires a **NEW d-test** to test the **INITIAL-ADD** pathology:

- **d078** (proposed): Layer 5 initial-add defensive guard regression test (Issue #680 carrier)
  - TC1: PR opened WITHOUT `status:in-review` (tester-flow simulation) → Layer 5 does NOT 404-crash, status:ready added idempotently
  - TC2: DRAFT PR (isDraft=true) → Layer 5 SKIPS status:ready auto-add entirely + logs `silent_skip` (lens d observability)
  - TC3: Non-DRAFT PR WITH status:in-review → Layer 5 adds status:ready + removes status:in-review (regression — existing behavior preserved)
  - TC4: Non-DRAFT PR WITHOUT status:in-review → Layer 5 adds status:ready + skips DELETE (defensive guard active)
  - TC5: All 4 TCs verify audit comment marker `adr-0012-status-ready-gating-skip` for skip paths + `adr-0012-status-ready-gating` for add paths
  - Per ADR-0044 RED-first: pre-impl 5/5 FAIL on main, post-impl 5/5 GREEN

Worktree PR proposal (for owner squash gate):
- `docs/decisions/ADR-0048-amendment-initial-add-defensive-guard.md` (THIS file)
- `scripts/tests/d078-layer-5-initial-add-defensive-guard.sh` (new d-test, ≥5 TCs)
- `scripts/tests/INDEX.md` entry for d078 (Cadence Rule 1 atomic per ADR-0055 §1)
- `.github/workflows/label-check.yml` (yaml impl — human-only territory, owner merges)

---

## Rationale

1. **Defensive guard (Amendment 1)** — Sister-pattern to ADR-0048-amendment-verdict-state-aware §"Idempotency via comments.find" + lens (e) Idempotency of architect 9-Lens review. Every state mutation MUST be idempotent. DELETE on absent label is a crash, not a feature.

2. **DRAFT-PR skip-guard (Amendment 2)** — Sister-pattern to Issue #523 Layer 5 race pathology carrier. DRAFT PRs are work-in-progress per GitHub PR lifecycle. Auto-promoting DRAFT PRs to `status:ready` bypasses reviewer chain + owner merge gate doctrine. This is exactly the race pattern the RE-ADD amendment fixed for the OPPOSITE trigger event.

3. **Type-driven table extension (Amendment 3)** — DRAFT vs non-DRAFT is a binary pre-condition that supersedes all type-driven logic. Adding it to the table documents the behavior canonically.

4. **Cost-benefit**: ~15 LoC yaml delta in `.github/workflows/label-check.yml` (human-only territory, owner merge gate). Fixes P1 LIVE INSTANCE (PR #679). Sister-pattern to a prior P0 fix (PR #677 / Issue #675) — same fix-philosophy, different defect class.

5. **Reversibility**: This amendment is purely additive (defensive guards). It does NOT change existing type-driven semantics for non-DRAFT PRs. If revert needed, the existing ADR-0048 behavior is preserved by removing the two guards.

---

## Consequences

### Positive

- (+) Fixes PR #679 L5 race (Layer 5 initial-add path now respects DRAFT state + DELETE idempotency)
- (+) Eliminates 404 crash on `status:in-review` DELETE for tester-flow PRs (skip-in-review lane convention)
- (+) DRAFT PRs correctly handled — work-in-progress status preserved, no premature owner merge signal
- (+) New d078 d-test guards the regression per ADR-0044 RED-first
- (+) Sister-pattern alignment with RE-ADD amendment (ADR-0048-amendment-verdict-state-aware) — same defense-in-depth philosophy

### Negative

- (-) ~15 LoC yaml delta in `.github/workflows/label-check.yml` (human-only territory per file ownership matrix — owner merges)
- (-) New d-test (d078) authoring effort (~250 LOC bash + grep + awk, --self-test contract per ADR-0049 sister-pattern)
- (-) ADR-0048 §Pseudocode updates — already documented in §Updated pseudocode above, no breaking change

### Follow-up tickets

- [ ] Worktree PR for yaml impl (`.github/workflows/label-check.yml`) — owner squash gate (file ownership matrix)
- [ ] d078 d-test authoring per ADR-0044 RED-first (tester lane, ~5 TCs)
- [ ] RETRO-016 codification carrier (this amendment IS RETRO-016 candidate #1)

### Cross-references

- **Closes**: Issue #680 (RETRO-016 candidate #1)
- **Sister**: Issue #675 (RE-ADD pathology, already fixed via PR #677)
- **Carrier for**: PR #679 (LIVE INSTANCE — INITIAL-ADD pathology)
- **Doc**: `docs/designs/PR-679-layer-5-initial-add-design.md` (parallel design doc, separate file)
- **Codifies**: RETRO-016 watchlist entry "L5 misfire initial-add path (distinct from Issue #675 re-add)"
- **Sister-pattern**: ADR-0048-amendment-verdict-state-aware (RE-ADD amendment), ADR-0056 (Layer 5 idempotency reconcile), ADR-0053 (Layer 5 race pattern)

---

## Acceptance Criteria

1. ADR amendment file `docs/decisions/ADR-0048-amendment-initial-add-defensive-guard.md` exists and is Accepted status post-owner-merge
2. `docs/decisions/INDEX.md` updated with this ADR (cross-ref to ADR-0048 + Issue #680)
3. d078 d-test authored per ADR-0044 RED-first (≥5 TCs, --self-test contract per ADR-0049)
4. yaml impl PR opened with workflow diff (owner squash gate per file ownership matrix)
5. PR #679 re-triggered post-impl — Layer 5 initial-add path no longer crashes (label-check PASS)

---

— @architect, 2026-06-29T13:08+03:00 = 10:08Z, claim-680 (RETRO-016 cycle ~1135), WIP=1/2 active.