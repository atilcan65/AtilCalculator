# ADR-0062 — Layer 5 Label-Change Event Verdict-Gate Extension (RETRO-016 #5 carrier)

- **Status:** Proposed (Sprint 22 P2 doctrine hardening, Closes Issue #696 AC1 + RETRO-016 #5 cluster)
- **Date:** 2026-06-30
- **Deciders:** @architect (doctrine/spec), @product-manager (Path C business ratification per Issue #696 §Recommended path), @tester (d-test contract — 3 TCs minimum per ADR-0049 + ADR-0044 RED-first), @developer (yaml impl in `.github/workflows/label-check.yml` per file ownership matrix human-only territory → owner merges), @atilcan65 (owner squash gate for workflow file)
- **Parent ADR:** [ADR-0048-amendment-verdict-state-aware](./ADR-0048-amendment-verdict-state-aware.md) (Path A, WARN-not-FAIL, closed Issue #659)
- **Amends:** ADR-0048-amendment-verdict-state-aware by extending Path A's verdict-emoji check from PR-creation events to **all `cc:<peer>` label-change events** (path P0 of Issue #696 #Risk)
- **Closes:** Issue #696 (RETRO-016 #5 — Layer 5 false-positive `status:ready` on 🔴 verdict, PR #695 LIVE INSTANCE)
- **Sister-patterns:** ADR-0048 (Layer 5 auto-add gating), ADR-0048-amendment (Path A verdict-state-aware, PR-creation only), ADR-0056 (Layer 5 idempotency reconcile, WARN-not-FAIL proven), ADR-0012 (cascade-strip Part 1 + Part 2), ADR-0044 (TDD RED discipline), ADR-0049 (d-test framework), ADR-0055 (Cadence Rule 1 atomic — this ADR + INDEX.md row in same PR), Issue #659 (S21-FOLLOW-001 Path A ratification), Issue #675 (P0 Layer 5 misfire regression), Issue #430 (PM §Pre-citation cross-check), Issue #470 (PM §Timing window 30s), RETRO-015 §16 (origin carrier), RETRO-016 #1 (Issue #680), RETRO-016 #3 (Issue #682), RETRO-016 #5 (THIS Issue #696), PR #695 (LIVE INSTANCE)

---

## Context

ADR-0048-amendment (Path A, WARN-not-FAIL, closed Issue #659) extended Layer 5 (`status:ready` auto-add) to read PR verdict emoji from `comments[]` BEFORE auto-promoting. This closed the PR #655 + #657 pathology (premature `status:ready`+`cc:human` before tester verdict).

**However, the Path A amendment fires only on `pull_request_target` events at `opened`/`reopened` action** (per `if:` clause line 237). It does NOT cover **label-change events** when the tester/arch lane transfer fires after verdict.

### Triggering LIVE INSTANCE (RETRO-016 #5)

**PR #695** (2026-06-29, tester triage cmt 4835036231):
- 16:52:18Z — PR-creation path: Layer 5 Path A verdict-emoji gate correctly REFUSED (cmt 4834982398)
- 16:56:42Z — Label-change path: tester delivered 🔴 CHANGES REQUESTED verdict (cmt 4835022750); tester flipped labels per tester.md table:
  - `--remove-label needs-tester-signoff --remove-label cc:tester --add-label cc:developer`
- 16:56:52Z — Layer 5 saw: `needs-tester-signoff` absent + `cc:developer` present → "reviewer chain complete" → auto-ADDED `status:ready` (FALSE POSITIVE — verdict was 🔴)
- 16:57:14Z — Dev manually re-ADDED `status:in-review`
- 16:57:23Z — Layer 5 cascade-strip removed `status:ready` (correct outcome, but for wrong reason — should have been verdict-emoji check, not cascade-strip)

**Net pathology**: `status:ready` was added on a 🔴 verdict PR, signaling "ready for owner merge gate" when in reality the reviewer was asking for changes. Owner could have merged broken code.

### Root cause

Layer 5's verdict-state-aware logic (ADR-0048-amendment Path A) is wired into **PR-creation events only** (line 237 `if`). When the tester transfers lane (🔴 verdict → `cc:developer` + remove `needs-tester-signoff`), Layer 5 sees the label change but doesn't re-check verdict state because the event is `pull_request_target` `labeled cc:developer`, not PR-creation.

**Doctrine gap**: Path A's verdict-emoji check is meant to be **stateful across the PR lifecycle**, but is currently gated to a single event type.

## Decision

**Path C** — extend Layer 5 Path A's verdict-emoji check to fire on **all `cc:<peer>` label-change events** (per Issue #696 §Recommended path, ~10 LoC js delta).

### Path C scope (chosen)

The verdict-emoji check (lines 575-580 of `label-check.yml`) currently only runs in the "should we auto-promote" branch. Path C extracts this logic into a **gating pre-check** that runs at the **start of Layer 5**, BEFORE any auto-add decision:

```javascript
// Path C (proposed — line ~491 after Bot-actor + status:* short-circuit):

// ------------------------------------------------------------------
// RETRO-016 #5 (Issue #696): verdict-emoji gate on label-change events.
// Sister-pattern: ADR-0048-amendment Path A (PR-creation only) extended
// to all cc:<peer> add/remove events. Prevents false-positive status:ready
// on tester 🔴 verdict lane transfer (PR #695 LIVE INSTANCE).
// ------------------------------------------------------------------
const onlyLabelChangeCc = (
  evtAction === 'labeled' || evtAction === 'unlabeled'
) && context.payload.label &&
context.payload.label.name &&
(context.payload.label.name.startsWith('cc:') ||
 context.payload.label.name === 'needs-tester-signoff' ||
 context.payload.label.name === 'needs-architect-review');
if (onlyLabelChangeCc) {
  // Read LATEST PR verdict emoji from comments[] (same logic as Path A)
  const { data: comments } = await github.rest.issues.listComments({ owner, repo, issue_number: number, per_page: 100 });
  let latestVerdict = null;
  const verdictRe = /🟢|🟡|🔴/g;
  for (const c of comments) {
    if (!c.user || c.user.type === 'Bot') continue;
    const m = c.body && c.body.match(verdictRe);
    if (m) latestVerdict = m[m.length - 1];
  }
  if (latestVerdict === '🔴' || latestVerdict === '🟡') {
    core.info(`[Layer 5 RETRO-016 #5] verdict gate REFUSED on ${evtAction} ${context.payload.label.name} (latest verdict=${latestVerdict}). Skip status:ready auto-add.`);
    // Silent-skip audit per ADR-0045 lens (d) — Issue #696 false-positive prevention
    const skipBody = [
      '<!-- adr-0062-verdict-gate-skip -->',
      '**Layer 5 verdict-gate skip (ADR-0062 — RETRO-016 #5)**',
      '',
      `- **Trigger**: \`labeled\`/\`unlabeled\` event on \`${context.payload.label.name}\``,
      `- **Latest verdict in comments**: ${latestVerdict}`,
      `- **Action**: SKIP \`status:ready\` auto-add (verdict not 🟢)`,
      `- **PR**: #${number}`,
      `- **Workflow run**: \`${{ github.run_id }}\``,
      `- **ADR**: \`docs/decisions/ADR-0062-amendment-layer-5-label-change-verdict-gate.md\``,
    ].join('\n');
    const existing = comments.find(c => c.user && c.user.type === 'Bot' && c.body && c.body.includes('<!-- adr-0062-verdict-gate-skip -->'));
    if (existing) {
      await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body: skipBody });
    } else {
      await github.rest.issues.createComment({ owner, repo, issue_number: number, body: skipBody });
    }
    return;
  }
}
// If latestVerdict === '🟢' or null, fall through to existing logic
```

### Decision rules

| Trigger event | Latest verdict in `comments[]` | Layer 5 verdict-gate action |
|---------------|--------------------------------|----------------------------|
| `labeled cc:<peer>` (post-verdict lane transfer) | 🔴 | REFUSE `status:ready` auto-add + silent_skip log |
| `labeled cc:<peer>` | 🟡 | REFUSE + silent_skip |
| `labeled cc:<peer>` | 🟢 | FALL THROUGH (existing logic OK — `cc:human` + `status:ready` if reviewer chain cleared) |
| `labeled cc:<peer>` | null (no verdict yet) | REFUSE + silent_skip (default-deny, sister to ADR-0048 silent_skip lens d) |
| `unlabeled cc:<peer>` (lane removal) | 🔴 | REFUSE + silent_skip |
| `unlabeled cc:<peer>` | 🟢/null | FALL THROUGH (existing logic) |
| `labeled/unlabeled needs-tester-signoff` | 🔴 | REFUSE + silent_skip (tester re-rejected post-APPROVED) |
| `labeled/unlabeled needs-architect-review` | 🔴 | REFUSE + silent_skip |
| PR opened/reopened event (Path A) | (existing Path A logic preserved) | unchanged |

### Why Path C (not A/B from Issue #696 §Fix candidates)

**Path A (verdict:* labels)** — explicit machine-readable labels. **Rejected for Sprint 22 P2**:
- (+) Cleanest machine semantics
- (-) Label clutter; requires agent discipline to set on every verdict comment
- (-) ADR-0024 already mandates `verdict-by:*` (clock not content); adding `verdict:*` doubles the label schema
- (-) Out-of-scope for Sprint 22 P2 hardening (RETRO-016 cluster ratification gate)

**Path B (cross-event `pulls.listReviews` API call)** — `reviews[]` state check. **Rejected**:
- (+) No new label schema
- (-) Latency: extra API call per label-change; rate-limit risk on high-traffic repos (per Issue #696 §Cons)
- (-) Reviewer state semantics (`APPROVED`/`CHANGES_REQUESTED`/`COMMENTED`) differ from comment emoji; would need separate doctrine gap
- (-) Reviews API can lag behind comments (Path A already uses `comments[]`)

**Path C (cc:<peer> + verdict-emoji combo gate)** — **CHOSEN**:
- (+) Minimal API calls (piggyback on existing `listComments` call already in Path A branch)
- (+) Reuses existing verdict-emoji regex from Path A (lines 575-580)
- (+) ~10 LoC js delta; sister-pattern to Path A's existing logic
- (+) Default-deny on null (defense-in-depth)
- (+) Audit-trail marker pattern consistent with existing Layer 5 markers
- (-) Triggers on every cc:* label event (modest perf, GitHub Actions budget fine)
- (-) Defaults to silent_skip on null verdict (could block legitimate flow if verdict not posted yet — but Path A already has this fallback in PR-creation path, behavior is consistent)

### Why now (Sprint 22 P2 not later)

RETRO-016 cluster (#1, #3, #5, #6) has 4 LIVE INSTANCES in 2 days (PR #679 + #695 + #705 + #692). Pattern is **active, not historical**. Sprint 22 P2 doctrine hardening is the right vehicle — same workshop that closed Issue #546 (ADR-0056) + Issue #659 (ADR-0048 amendment) + Issue #604 (ADR-0060).

## Rationale

### Why extend Path A vs new gate logic

| Option | Cost | Audit trail | Path A reuse | Verdict |
|--------|------|-------------|--------------|---------|
| **A. New gate logic (separate workflow step)** | ~50 LoC | New marker | 0% | ❌ Duplicate infrastructure |
| **B. Independent re-implementation** | ~80 LoC | New marker | 0% | ❌ Maintenance burden ×2 |
| **C. Extend Path A's check to label-change (THIS)** | ~10 LoC | Reuse Path A markers | 100% | ✅ **Chosen** |
| **D. Wait for ADR-0048-amendment v2 (future scope)** | 0 (deferred) | n/a | n/a | ❌ RETRO-016 #5 still active pathology |

### Evidence

- **PR #695** — primary LIVE INSTANCE (cmt 4835025543 Layer 5 false-positive log + cmt 4835030264 cascade-strip remediation)
- **PR #679** — sister-pattern (RETRO-016 #1, Issue #680)
- **PR #692** — sister-pattern (RETRO-016 #3, Issue #682)
- **PR #705** — Layer 4 cascade-strip sister-pattern (RETRO-016 #6, Issue #706)
- **ADR-0048-amendment Path A** — proven WARN-not-FAIL pattern in production; Path C is an extension, not a new doctrine

### Compatibility

- ✅ Backward compatible with Path A's PR-creation gate (unchanged)
- ✅ Backward compatible with ADR-0056 idempotency reconcile (Layer 5 self-corrects on next label event)
- ✅ Backward compatible with ADR-0055 (d-test uniqueness — this ADR does NOT introduce a new d-test, reuses Path A's TC family)

## Consequences

### Positive

- ✅ PR #695 false-positive pattern closed; `status:ready` will NOT auto-add on 🔴 verdict lane transfers
- ✅ Owner merge gate no longer at risk from tester lane-transfer false-positives
- ✅ 9-Lens lens (b) Runtime preconditions + lens (d) Silent-skip improved (no metric = no production kept)
- ✅ Sister-pattern symmetry with Path A's PR-creation gate (consistent doctrine across event types)
- ✅ ~10 LoC implementation (within Sprint 22 P2 budget)
- ✅ Compatible with ADR-0055 Cadence Rule 1 (no new d-test, reuse existing)

### Negative (mitigated below)

- ⚠️ Extra `listComments` API call on every cc:* label-change event (R1) — mitigate: Layer 5 already calls listComments in PR-creation branch; only on label-change events does it add 1 call, GitHub Actions budget fine (~5000/hr)
- ⚠️ Default-deny on null verdict could block legitimate flow if verdict not posted yet (R2) — mitigate: Path A already exhibits this behavior in PR-creation branch (lines 575-580 default to skip); behavior is consistent
- ⚠️ Owner merge required per file ownership matrix (R3) — mitigate: arch drafts ADR + d-test, tester signs off, owner merges workflow file (Sprint 22 P2 codification workshop standard flow)
- ⚠️ Per-event label-change fires could trigger false-skips if reviewer posts verdict AFTER lane transfer (R4) — mitigate: silent_skip audit comment + next label-change event re-evaluates (idempotent like ADR-0056)

### d-test integration

**Reuses Path A d-test family** — no new d-test required (per ADR-0055 Cadence Rule 1 uniqueness):

- d073 (PR #655 carrier, ADR-0048-amendment) — TC2 extended: add TC2.5 (label-change 🔴 false-positive)
- d074 (PR #657 carrier) — unchanged
- Sister: **d097** (Sprint 22 PIVOT runner access-grant regression, reserved cycle ~#1587 per ADR-0061)

### Sister-pattern: future prevention

- **Issue #706** (RETRO-016 #6) — Layer 4 cascade-strip + Layer 5 TC4 reversal race on tester APPROVED. **Separate ADR** (ADR-0063) — distinct Layer 4 doctrine gap.
- **Issue #680** (RETRO-016 #1) — already closed by PR #683 (Layer 5 initial-add race)
- **Issue #682** (RETRO-016 #3) — closed by PR #692 (cross-watchdog 30s gap)

## Implementation checklist (Sprint 22 P2 codification)

**Pre-Faz 0 (arch + tester)**:
- [ ] d073 + d074 d-test extension drafted (tester-led, RED-first per ADR-0044)
- [ ] 3 minimum TCs: TC-X.1 (labeled cc:* + 🔴 verdict → skip), TC-X.2 (labeled cc:* + 🟢 verdict → fall through), TC-X.3 (null verdict → skip)

**Faz 0 (arch authored)**: ✅ THIS ADR (docs PR lane; sprint-gated)

**Faz 1 (dev + tester)**:
- [ ] 1.1 yaml impl in `.github/workflows/label-check.yml` (~10 LoC js, file ownership matrix human-only → owner merges)
- [ ] 1.2 d-test TC-X.1/2/3 GREEN

**Faz 2 (owner)**:
- [ ] 2.1 Owner squash PR + workflow file change (file ownership matrix)

**Faz 3 (orch + all)**:
- [ ] 3.1 RETRO-016 watchlist updated: #5 closed by THIS ADR
- [ ] 3.2 Issue #696 status:done

## Cross-refs

- **Issue #696** — primary carrier (RETRO-016 #5)
- **PR #695** — LIVE INSTANCE
- **ADR-0048-amendment-verdict-state-aware** — Path A foundation (this ADR extends)
- **ADR-0056** — Layer 5 idempotency reconcile (WARN-not-FAIL pattern proven)
- **ADR-0055** — Cadence Rule 1 atomic d-test uniqueness (no new d-test)
- **File ownership matrix**: `.github/workflows/` = human-only (arch + tester draft, owner merges)
- **RETRO-016** cluster: #1 (Issue #680) + #3 (Issue #682) + #5 (Issue #696, THIS) + #6 (Issue #706, ADR-0063)

— @architect, cycle ~#1610, 2026-06-30T10:56:30Z + 03:00 = 07:56:30Z, drafted post-claim-next-ready auto-pickup
