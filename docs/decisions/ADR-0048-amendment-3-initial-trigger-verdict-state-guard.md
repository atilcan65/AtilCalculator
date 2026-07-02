# ADR-0048 Amendment 3: Layer 5 Initial-Trigger Verdict-State Guard (type:docs + no peer verdict = suppress)

- **Status:** Proposed (Sprint 23 P0 carrier, Issue #744 closeout)
- **Date:** 2026-07-01
- **Deciders:** @architect (doctrine/spec), @tester (d-test contract — extend d077 with TC6 sister-test + add d-test authorship per ADR-0044 RED-first), @developer (yaml impl proposal in `.github/workflows/label-check.yml` per file ownership matrix human-only territory → owner merges), @atilcan65 (owner squash gate for workflow file)
- **Parent ADR:** [ADR-0048](./ADR-0048-status-ready-auto-add-gating.md) — `label-check.yml` Layer 5: `status:ready` Auto-Add Gating (Type-Driven Reviewer Chain)
- **Sibling amendments:**
  - [ADR-0048-amendment-verdict-state-aware](./ADR-0048-amendment-verdict-state-aware.md) — 🟡/🔴 verdict emoji in comments[] → suppress. Path A ratified by @product-manager per Issue #659 cmt 4828801300. THIS amendment EXTENDS amend-1 by adding ABSENT-verdict suppression (closes the initial-trigger pathology).
  - [ADR-0048-amendment-initial-add-defensive-guard](./ADR-0048-amendment-initial-add-defensive-guard.md) — DRAFT-PR skip + idempotent DELETE on `status:in-review`. Closes Issue #680. NOT overlapping with THIS amendment (different defect class — this is verdict-state absence, not DELETE idempotency).
- **Amends:** ADR-0048 §Type-driven reviewer chain table (NEW row for type:docs + ABSENT-verdict suppression) + §Pseudocode Step 2.5 (extend with absent-verdict branch) + §Pseudocode Step 2 verdict-state pre-condition. Reverses Fallback-to-fast on type:docs initial-trigger pathology.
- **Closes:** Issue #744 (Layer-5 misfire TC6 variant — type:docs + no wake labels + no peer verdict still auto-promoted to status:ready, d077-TC6 candidate)
- **Sister-patterns:** ADR-0048-amendment-verdict-state-aware (RE-ADD + 🟡/🔴 path, Path A), ADR-0048-amendment-initial-add-defensive-guard (DRAFT-PR + DELETE idempotency, Issue #680 fix), ADR-0056 (Layer 5 idempotency reconcile), ADR-0024 (§Schema verdict-by discipline), ADR-0044 (RED-first TDD), ADR-0049 (d-test ≥3 sister-pattern)
- **Live instance:** PR #736 ONBOARDING.md (cycle ~#2507 detection, owner-revert cycle ~#2515) — opened 23h after PR #677 fix, STILL received premature status:ready + cc:human
- **TD-021 cluster:** 6th live instance (PR #736 = #6 after #122, #157, #161, #675/PR #677 cluster)
- **Related:** PR #677 (sister fix PR for RE-ADD pathology, d077 5/5 GREEN), PR #736 (LIVE INSTANCE — INITIAL-ADD pathology), Issue #430 (§Pre-citation cross-check comments+reviews both required), Issue #113 (labels > body doctrine), Issue #659 (Path A ratification cmt 4828801300), Issue #680 (sister fix amend-2), RETRO-016 watchlist candidate

---

## Context

ADR-0048 Layer 5 (`status:ready` auto-add gating, type-driven reviewer chain) currently fires `shouldAddReady = true` for type:docs PRs when the docsAuthor check passes (architect/PM/orchestrator) AND `needs-architect-review` is absent. Two prior amendments partially close the gap:

- **Amendment 1 (verdict-state-aware)** added a verdict-emoji gate that suppresses when `latestVerdict === '🟡'` or `'🔴'`. This was Path A ratified by @product-manager per Issue #659 cmt 4828801300 to address re-add loops on label-removal events.
- **Amendment 2 (initial-add defensive guard)** added a `hasStatus(inReview)` defensive DELETE guard + `isDraft` skip-guard to address PR #679 type:feature initial-trigger pathology on tester-flow PRs.

Neither amendment addresses the **initial-trigger** pathology for type:docs PRs:

### Live failure trace — PR #736 (cycle ~#2507)

| Time (UTC) | Actor | Action | Result |
|---|---|---|---|
| 2026-06-30T20:30:44Z | @product-manager | `gh pr create --label "type:docs,status:ready,agent:product-manager,cc:developer,cc:human"` (no wake labels) | PR #736 opened |
| 2026-06-30T20:30:45Z | github-actions[bot] | Layer 5 trigger `pull_request_target` (action=opened) | Step 2: `isDocs=true`, `docsAuthor=true` (PM), `archCleared=true` (no `needs-architect-review`) → `shouldAddReady=true` |
| 2026-06-30T20:30:45Z | github-actions[bot] | comments[] scan: 0 entries → `latestVerdict=null` | Path A emoji gate (Amend 1): 🟡/🔴 absent → suppress NOT triggered (gate only suppresses on 🟡/🔴, not on ABSENT verdict) |
| 2026-06-30T20:30:46Z | github-actions[bot] | `addLabel('status:ready')` + `addLabel('cc:human')` | ✅ PREMATURE: status:ready + cc:human applied with ZERO peer verdicts in comments[] or reviews[] |

### Why amend-1 didn't catch this

Amend-1's gate (label-check.yml L571-590) only OVERRIDES Step 2's positive decision when verdict is 🟡 or 🔴. It does NOT add a precondition that verdict MUST be present. For a fresh PR with 0 comments (PR #736 initial state), `latestVerdict === null`, the conditional `if (latestVerdict === '🟡' || latestVerdict === '🔴')` evaluates false, and Step 2's `shouldAddReady=true` propagates through unchanged.

### Why amend-2 didn't catch this

Amend-2's defensive guards focus on (a) DELETE idempotency for PRs without `status:in-review` and (b) DRAFT-PR skip. PR #736 was neither — it was non-DRAFT AND was opened with `status:ready` directly (no in-review transition). Amend-2 doesn't gate on verdict-state.

### Defect class enumeration (sister-pattern to amend-1/amend-2)

| Defect class | Sister ADR | Trigger | Fix in label-check.yml | Status |
|---|---|---|---|---|
| RE-ADD with 🟡/🔴 verdict (Issue #659) | Amend-1 (verdict-state-aware) | `pull_request_target.unlabeled` fires while 🔴 or 🟡 in comments[] | Path A emoji gate (L571-590) | ✅ Fixed (PR #677) |
| RE-ADD in re-fire loop (Issue #675) | Amend-1 (verdict-state-aware) | `pull_request_target.unlabeled` repeated | verdict:changes-requested label gate (L604-607) + bot-actor exclusion (L496-499) | ✅ Fixed (PR #677) |
| INITIAL-ADD on DRAFT / PR without `status:in-review` (Issue #680, PR #679) | Amend-2 (initial-add defensive guard) | `pull_request_target.opened` on DRAFT | `hasStatus(inReview)` guard + `isDraft` skip-guard | ✅ Implemented (PR #680) |
| **INITIAL-ADD on type:docs + no wake labels + NO peer verdict (Issue #744, PR #736) — THIS** | **Amend-3 (initial-trigger verdict-state guard)** | `pull_request_target.opened` (or early `labeled`) for type:docs when 0 verdicts in comments[] / 0 reviews[] / 0 verdict-by labels | **NEW Step 2 verdict-state pre-condition**: `verdictPresentIn(comments, reviews, verdict_by)` MUST be `true` for `shouldAddReady=true` | 🔴 OPEN (this amendment) |

### Failure mode consequences

- **ADR-0024 §Schema violation** — Every `cc:<peer>` MUST be paired with `verdict-by:<ts>`. PR #736 had `cc:developer` + `cc:human` but NO `verdict-by:*` label — 4-cat invariant broken; watchdog `missing_expectation` should fire.
- **Owner gate bypass** — `status:ready + cc:human` implies "ready for human merge" but no peer has APPROVED. Owner may inadvertently squash-merge without proper peer review chain.
- **Tester wake race** — Tester's wake-label (`needs-tester-signoff`) is absent for type:docs (per ADR-0021 docs PR convention, tester prereq optional). So Layer 5 has no defensive signal that "tester hasn't seen this yet" — verdicts must be the gate.

---

## Decision

**Amend-3 (chosen) — extend Amend-1's Path A verdict-emoji gate with ABSENT-verdict suppression, scoped to type:docs initial-trigger.**

### Type-driven reviewer chain table — NEW row

| `type:*` value | Required cleared state for `status:ready` auto-add | ADR reference |
|---|---|---|
| `type:docs` + `agent:architect` / `agent:product-manager` / `agent:orchestrator` | **`(archCleared OR verdictPresent) AND latestVerdict ∉ {🟡, 🔴}`** | ADR-0048 + THIS amend-3 + Amend-1 (Path A) |
| `type:bug` / `type:feature` / `type:refactor` / `type:chore` / `type:incident` | `(testerCleared AND verdictPresent) AND latestVerdict ∉ {🟡, 🔴}` | ADR-0048 + Amend-1 (extend verdictPresent to all paths) |
| All other / unknown `type:*` | Defensive default → Amend-1's verdict-label gate (verdict:changes-requested) | ADR-0048 §Type-driven invariants |

### `verdictPresent` predicate (NEW, post-amend-3)

```yaml
verdictPresent := (
  latestVerdict === '🟢'                                    # Path A emoji gate — explicit OK
  OR hasLabel('verdict:approved')                            # Amend-1 verdict-label taxonomy extension
  OR verdict-by:<ts> label present                          # ADR-0024 §Schema — verdict timestamp recorded
  OR reviews[] state ∈ {APPROVED, COMMENTED}                # formal review submission
)
```

If `verdictPresent === false` AND `shouldAddReady === true` from Step 2 → **suppress** + emit silent_skip per ADR-0045 lens (d).

### Updated Pseudocode (delta from Amend-1's L571-590 region)

```yaml
# Step 2.5: Path A verdict-emoji gate (Amend-1) + verdict-state presence gate (Amend-3, THIS).
# Extend amend-1's "suppress on 🟡/🔴" to also "suppress on ABSENT verdict" for INITIAL-TRIGGER
# on type:docs PRs (Issue #744 pathology).

# (Amend-1 logic, preserved verbatim — does NOT regress)
let latestVerdict = null;
for await (const page of github.paginate.iterator(
  github.rest.issues.listComments, { owner, repo, issue_number: number, per_page: 100 }
)) {
  for (const c of page.data) {
    if (!c.user || c.user.type === 'Bot') continue;
    const m = c.body && c.body.match(/🟢|🟡|🔴/g);
    if (m) latestVerdict = m[m.length - 1];
  }
}

# NEW (Amend-3): verdictPresent pre-condition for INITIAL-TRIGGER on type:docs.
# Skip this check for RE-ADD paths (action=unlabeled) — Amend-1 handles those.
# Skip this check for NON-DOCS PRs (tester prereq OR verdict:changes-requested label
# already gates those per Amend-1 L604-607).
const isInitialTrigger = evtAction === 'opened' || (
  evtAction === 'labeled' && !context.payload.label.name.startsWith('status:') &&
  !context.payload.label.name.startsWith('verdict:')
);
const verdictPresent = (
  latestVerdict === '🟢' ||
  hasLabel('verdict:approved') ||
  hasLabel('verdict-by') ||                                       # prefix-match (any timestamp)
  reviews.length > 0                                              # reviews[] state check (NEW — fetch below)
);
# Fetch reviews[] (sister-pattern to Issue #430 §Pre-citation cross-check)
let reviews = [];
for await (const page of github.paginate.iterator(
  github.rest.pulls.listReviews, { owner, repo, pull_number: number, per_page: 100 }
)) {
  reviews = reviews.concat(page.data);
}

if (isInitialTrigger && isDocs && docsAuthor && !verdictPresent) {
  shouldAddReady = false;
  skipReason = `Amend-3 verdict-state gate: type:docs PR initial-trigger but no peer verdict (comments=0, reviews=0, verdict-by=absent, verdict:approved=absent) — Issue #744, REFUSED`;
}

# (Amend-1's 🟡/🔴 suppression unchanged — applies to ALL paths)
if (latestVerdict === '🟡' || latestVerdict === '🔴') {
  shouldAddReady = false;
  skipReason = `Amend-1 verdict-emoji gate: latest peer verdict=${latestVerdict} (Issue #659, REFUSED)`;
}

# (Amend-1's verdict-label gate unchanged — applies to ALL paths)
if (hasLabel('verdict:changes-requested')) {
  shouldAddReady = false;
  skipReason = `Amend-1 verdict-label gate: verdict:changes-requested label present (Issue #675 Option A, REFUSED)`;
}
```

### What this does NOT change

- Amend-1's 🟡/🔴 emoji gate (L571-590) is preserved verbatim.
- Amend-1's verdict:changes-requested label gate (L604-607) is preserved verbatim.
- Amend-2's `hasStatus(inReview)` DELETE guard + `isDraft` skip-guard (Issue #680 fix) is preserved.
- The non-docs path is NOT affected by Amend-3 — type:bug/type:feature/etc. still gate on `testerCleared` (Amend-1 logic sufficient because those types REQUIRE needs-tester-signoff label upfront per ADR-0012 §Type-driven invariants, so absent-verdict + absent-tester-wake is the canonical pre-review state).
- `owner merge gate` doctrine is unchanged — owner may still squash-merge any status:ready PR; this amendment only prevents PREMATURE auto-promotion.

### Effort / reversibility

- **Cost:** ~40 LoC yaml delta (predicate definition + reviews[] fetch + suppress branch), all additive. ~250 LoC bash for d-test extension (d077-TC6) per ADR-0049 sister-pattern.
- **Reversibility:** purely additive. Existing Amend-1/Amend-2 behavior preserved. If revert needed, removing the Amend-3 `if (isInitialTrigger && isDocs && docsAuthor && !verdictPresent) { … }` block restores prior behavior.
- **Risk:** low. Amend-1's verdict:changes-requested label + emoji gate independently gate; Amend-3 adds ONE more condition. Worst case: d077-TC6 regression guard catches overshoot.

---

## Rationale

### Why extend Amend-1 (verdict-state-aware) vs new d-test only

**Path A chosen** — amend Amend-1's gate with ABSENT-verdict branch + new d077-TC6 sister-test. Smaller blast radius than carving a new Amend-4 with overlapping scope.

**Alternative: separate Amend-4 (rejected)** — would address only one defect class (type:docs initial-trigger) without touching Amend-1. Adds maintenance burden (4 amendments to keep aligned) without architectural benefit.

**Alternative: extend Amend-2 (initial-add defensive guard) (rejected)** — Amend-2 scopes DELETE idempotency + DRAFT skip; amending its scope to verdict-state would conflate two defect classes (delete-idempotency vs verdict-absence).

### Why `reviews[] state ∈ {APPROVED, COMMENTED}` (NEW sister to Amend-1's `comments[]` emoji)

Path A ratified Amend-1 by @product-manager per Issue #659 cmt 4828801300 used `comments[]` ONLY because PR #655 + PR #657 had verdicts posted as comments, not formal reviews. Issue #430 §Pre-citation cross-check doctrine establishes that **BOTH `comments[]` AND `reviews[]` surfaces must be checked**. For type:docs PRs where formal reviewer submissions are rare, `comments[]` is the primary signal; but `reviews[]` is still part of the canonical verdict source and should be in `verdictPresent` predicate.

### Why `verdict-by:*` label prefix-match

ADR-0024 §Schema codifies `verdict-by:<iso-timestamp>` as the canonical verdict-timestamp carrier. Owner + verifier consent to this label taxonomy. Prefix-matching on `verdict-by` (any timestamp suffix) is the canonical "verdict recorded" signal.

### Why `verdict:approved` label (sister to amend-1's `verdict:changes-requested`)

Amend-1 already references `verdict:changes-requested` as the explicit CHANGES_REQUESTED label. Symmetric `verdict:approved` label for explicit APPROVED signal (defense-in-depth — explicit label IS a verdict even if emoji is absent). Mirrors `verdict:changes-requested` taxonomy.

---

## Consequences

### Positive

- (+) Closes PR #736 INITIAL-TRIGGER pathology (Issue #744) — type:docs PRs without wake labels do NOT auto-promote until peer verdict lands.
- (+) Eliminates owner-merge-gate bypass risk for type:docs PRs without prior review chain.
- (+) Symmetric with Amend-1 (🟢 in comments == verdict:approved label == APPROVED review == verdict-by:* present).
- (+) d-test extension (d077-TC6) provides regression guard per ADR-0044 RED-first.
- (+) New reviews[] fetch surfaces fmt-aware verdict source (sister-pattern to Issue #430).
- (+) Purely additive — Amend-1/Amend-2 behavior preserved.

### Negative

- (-) ~40 LoC yaml delta in `.github/workflows/label-check.yml` (human-only territory per file ownership matrix — owner merges).
- (-) New `reviews[]` fetch adds ONE API call per Layer 5 invocation (~50ms p95; non-blocking — workflow already fetches `comments[]`).
- (-) d-test extension (d077-TC6) authoring effort (~100 LoC bash delta on top of existing d077 5/5 GREEN).
- (-) ADR-0048 §Pseudocode updates — already documented in §Updated Pseudocode above, no breaking change.

### Follow-up tickets

- [ ] Worktree PR for yaml impl (`.github/workflows/label-check.yml` Amend-3 block) — owner squash gate (file ownership matrix)
- [ ] d077-TC6 d-test extension per ADR-0044 RED-first (tester lane, 1 TC sister-pattern ≥3 to existing TC1-TC5)
- [ ] docs/tech-debt.md update — TD-021 entry adds #744 as 6th live instance + Amend-3 as resolution path
- [ ] RETRO-016 codification (this amendment IS RETRO-016 candidate for the Sprint 23 close-out)
- [ ] owner decision on PR #736 squash (cycle ~#2515 — owner already chose to squash despite state correction; this amendment codifies the doctrinal position)

### Cross-references

- **Closes**: Issue #744 (Layer-5 misfire TC6 variant)
- **Parent**: ADR-0048 + Amend-1 (verdict-state-aware) + Amend-2 (initial-add defensive guard)
- **Sister**: PR #677 (Amend-1 fix PR), PR #680 (Amend-2 fix PR — hypothetical/scheduled)
- **Carrier**: PR #736 (6th live TD-021 instance, cycle ~#2507 detection)
- **Codifies**: RETRO-016 watchlist entry "Layer 5 initial-trigger type:docs variant"
- **Sister-pattern**: ADR-0056 (Layer 5 idempotency reconcile), ADR-0053 (Layer 5 race pattern), ADR-0055 (Cadence Rule 1 atomic)
- **Live instance timeline**: PR #736 opened 2026-06-30T20:30:44Z + Layer 5 auto-promote at 20:30:45Z + orchestrator state correction at 2026-07-01T03:49:33Z (cycle ~#2507, Issue #430 §Pre-citation cross-check caught empty comments/reviews/verdict-by triple-absence)

---

## Acceptance Criteria

1. ADR amendment file `docs/decisions/ADR-0048-amendment-3-initial-trigger-verdict-state-guard.md` exists and is **Proposed** status (pre-PR)
2. `docs/decisions/INDEX.md` updated with this amend-3 (cross-ref to ADR-0048 + Issue #744), Cadence Rule 1 atomic per ADR-0055 §1
3. `docs/tech-debt.md` updated with TD-021 entry noting PR #736 as 6th live instance + Amend-3 as resolution path
4. d077-TC6 d-test extension authored per ADR-0044 RED-first (≥1 TC sister-pattern ≥3 to existing TC1-TC5)
5. yaml impl PR opened with workflow diff (owner squash gate per file ownership matrix — `.github/workflows/` is human-only territory)
6. PR #736 re-triggered post-impl — Layer 5 initial-trigger on type:docs no longer fires prematurely (status:ready + cc:human NOT applied until verdict present)
7. new live instance detection — if another type:docs PR triggers premature auto-promote, d077-TC6 fails (RED-first intact)

---

## 9-Lens pre-publish attestation (ADR-0045)

| Lens | Status | Notes |
|---|---|---|
| (a) Data flow | 🟢 | Pure docs/contract amendment — no runtime data flow change beyond yaml impl. |
| (b) Runtime preconditions | 🟢 | Workflow yaml only; `reviews[]` fetch uses existing GitHub API token scope. |
| (c) Canonical entry point | 🟢 | `docs/decisions/ADR-0048-amendment-3-*.md` per ADR-0001 + ADR-0055 append-only invariant. |
| (d) Silent-skip risk | 🟢 | Suppression branch emits silent_skip per Amend-1 convention (L612-633 unchanged). |
| (e) Idempotency | 🟢 | All guards additive; no existing branch modified. Reverse path is "delete the amend-3 block" — single hunk. |
| (f) Observability | 🟢 | `verdictPresent` predicate logs each surface check (comments/reviews/verdict-by/verdict:approved) in `skipReason` for diagnosis. Sister-pattern to Amend-1's emoji gate. |
| (g) Security & privacy | 🟢 | No new surface; reads same `comments[]` and `reviews[]` as Amend-1. No auth surface change. |
| (h) Workflow YAML SHA pin | 🟢 | actions/github-script SHA already pinned (`@f28e40c7f34bde8b3046d885e986cb6290c5673b`) per ADR-0027 + ADR-0043 lens (h). New yaml diff is in human-only territory; owner squash gate. |
| (i) Platform hard constraints | 🟢 | yaml in `.github/workflows/` per ADR-0043 8 sub-categories; new steps added within existing job structure. timeout + concurrency preserved. No raw `docker`/`ssh`. |
| (j) Auto-gen + live-state | 🟢 | Hand-written; references existing PR #736 + PR #677 + Issues #659, #680, #744 + d077 (verified above). |

---

— @architect (cycle ~#1952+, Issue #744 closeout, claim-next-ready.sh rate-limited so manual claim via direct PR), WIP=1/2 (Issue #744 active + PR #737 review just closed, in cadence review mode).

Co-Authored-By: Claude <noreply@anthropic.com>
