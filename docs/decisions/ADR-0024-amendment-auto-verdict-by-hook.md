# ADR-0024 Amendment: Auto-Verdict-By Hook (codifies §Future work — `verdict-by:<ts>` auto-pair on `cc:<peer>`)

- **Status:** Proposed (RETRO-016 codification cycle ~1169, claims Issue #681 when API recovers)
- **Date:** 2026-06-29
- **Deciders:** @architect (doctrine/spec), @developer (yaml impl in `.github/workflows/` per file ownership matrix human-only territory → owner merges), @tester (d-test contract — ≥3 TCs minimum per ADR-0044 RED-first), @atilcan65 (owner squash gate for workflow file)
- **Parent ADR:** [ADR-0024](./ADR-0024-stale-verdict-watchdog-schema.md) — Stale-Verdict Watchdog Schema (`verdict-by:<ts>` labels + `stale_verdict` events)
- **Amends:** ADR-0024 §Future work "Auto-verdict-by" by codifying it as a binding rule + adding workflow YAML hook + d-test contract
- **Closes:** Issue #681 (RETRO-016 candidate #2 — ADR-0024 verdict-by: missing on tester-authored PRs, PR #679 gap)
- **Sister-patterns:** ADR-0048-amendment-verdict-state-aware, ADR-0048-amendment-initial-add-defensive-guard, ADR-0053 (Layer 5 race pattern), ADR-0056 (Layer 5 idempotency reconcile), ADR-0015 (atomic handoff), ADR-0024 §Schema additions
- **Related:** PR #679 (LIVE INSTANCE — tester-authored, cc:{orch,arch,dev,human} added without verdict-by), RETRO-015 §16 (doctrinal gap capture), Issue #113 (labels > body doctrine), Issue #659 (RETRO-015 #16 carrier)

---

## Context

ADR-0024 §Schema additions codifies that **every `cc:<peer>` MUST be paired with `verdict-by:<iso-timestamp>`** in the same atomic flip (per ADR-0015 §Sıra zorunlu). ADR-0024 §Future work explicitly defers the **Auto-verdict-by** mechanism:

> "**Auto-verdict-by**: a PR-template hook that auto-fills `verdict-by:<default-deadline>` (e.g., 24h from PR creation) on `cc:<peer>` addition. Reduces convention friction. Out of scope for this ADR."

PR #679 (LIVE INSTANCE, RETRO-016 candidate) demonstrated the doctrinal gap:

### Live instance trace (PR #679)

| Time (UTC) | Actor | Action | Result |
|---|---|---|---|
| 2026-06-29 12:43:0?Z | @tester | `gh pr create --label "status:ready" --label "agent:tester" --label "cc:orchestrator" --label "cc:architect" --label "cc:developer" --label "cc:human"` | PR #679 opened with 4 `cc:*` labels but NO `verdict-by:<ts>` label |
| 2026-06-29 13:08+03:00 | @architect | discovered the gap during PR #683 (ADR-0048 amendment #2) review | Issue #680 root cause trace |
| 2026-06-29 13:50+03:00 | @architect | filed Issue #681 | this amendment's home |

**Defect class**: Convention is documented but **not enforced** at the agent-action layer. Tester added 4 `cc:*` labels but no `verdict-by`. Per ADR-0024 §Missing-expectation warning, the watchdog SHOULD have emitted `missing_expectation:#679:<sha>` event — but no such event landed in the agent-watch stream (verification pending API recovery; per Step 5 doctrine the verification happens pre-PR-comment).

### Why this is a problem (R10-class for the verdict-by invariant)

1. **Convention violation**: `cc:<peer>` without `verdict-by:<ts>` = watcher-silent stall risk per ADR-0024 §Watchdog logic.
2. **Layer 5 race**: PR #679 reached Layer 5 with `cc:human` + `status:ready` + NO `verdict-by` → premature owner merge gate signal.
3. **Convention enforcement gap**: ADR-0024 relies on `missing_expectation` warning + agent self-correction; PR #679 demonstrates this is insufficient at scale.
4. **Watcher spam risk**: if strict-mode enforcement is added without `auto-verdict-by`, every `cc:<peer>` action becomes a `missing_expectation` event — high queue noise.

The fix is to **codify the hook** — at the time a `cc:<peer>` label is added, AUTO-inject a paired `verdict-by:<default-deadline>` label.

---

## Decision

**Path A (cheapest, auto-pair on `cc:<peer>` add)** — extend the label-check workflow + add an agent-side peer-poke helper:

### §Auto-Verdict-By Hook Contract

When ANY agent (or Layer 5) adds a `cc:<peer>` label to a PR/issue:

1. **Atomic pair required**: a paired `verdict-by:<iso-timestamp>` label MUST be added in the same `gh issue edit N --add-label ...` invocation (per ADR-0015 atomic handoff).
2. **Default deadline**: `<iso-timestamp>` = PR creation time + 24h (or configurable via env var `VERDICT_BY_DEFAULT_HOURS=24`).
3. **Override allowed**: if the agent explicitly sets `verdict-by:<ts>` (non-default), the auto-pair MUST NOT overwrite.
4. **Silent-skip if `missing_expectation` would fire**: if `cc:<peer>` is present but `verdict-by` is absent on a pre-existing label set, the hook MUST emit a `silent_skip` event per ADR-0045 lens (d) AND auto-inject the default deadline.

### §Implementation: 2 paths (chosen: BOTH, layered)

**Path 1: Workflow YAML hook (`.github/workflows/` — human-only territory, owner merges)**

- File: `.github/workflows/label-check.yml` (sister-extension to Layer 5 verdict-state-aware amendment)
- Trigger: `pull_request_target.labeled` events filtered to `cc:*` label additions
- Action: in same workflow step, auto-add the paired `verdict-by:<default-deadline>` label via `github.rest.issues.addLabel`
- Cost: ~15 LoC yaml delta on top of PR #683's ADR-0048 amendment #2

**Path 2: Agent-side helper (`scripts/peer-poke.sh` + `scripts/notify.sh` — non-workflow territory)**

- Auto-detect: when `peer-poke.sh <peer> "<msg>"` is called, post the Telegram notify + write a `verdict-by:<ts>` label via `gh issue edit`
- Layered defense: even if Layer 5 misses (e.g., manual UI label add), the agent's peer-poke invocation will pair-add
- Cost: ~10 LoC bash delta on `scripts/peer-poke.sh`

### §Updated ADR-0024 §Schema additions

| New label | Format | Meaning | Set by | Removed by | Pair rule |
|---|---|---|---|---|---|
| `verdict-by:<iso-timestamp>` | `verdict-by:2026-06-29T18:00:00Z` | Deadline by which the peer reviewer is expected to post a verdict | The agent who adds `cc:<peer>` (the "asker") **OR auto-injected by hook** (this amendment) | The peer reviewer on posting verdict (atomic `cc:<peer>` flip removes the deadline), OR the human on merge | **MUST be paired with `cc:<peer>`**; auto-inject via hook if missing |

### §Updated ADR-0024 §Watchdog logic

The `query_missing_expectation` function (ADR-0024 §Missing-expectation warning) becomes **secondary defense** — primary defense is the auto-inject hook:

```bash
# Primary defense (this amendment): hook auto-injects verdict-by:<ts> on cc:<peer> add
# Secondary defense (ADR-0024 §Watchdog): query_missing_expectation emits warning
#   if hook BYPASSED (e.g., manual UI label add without hook firing)

query_missing_expectation() {
  # Convention violation: cc:<peer> without verdict-by:<ts>.
  # One-shot per PR (id embeds pr# only, not bucket).
  gh pr list \
    --repo "$REPO" \
    --state open \
    --limit 50 \
    --json number,title,url,updatedAt,headRefOid,labels \
    --jq "[ .[] |
           .labels as \$labels |
           (\$labels | map(.name) | map(select(startswith(\"cc:\"))) | first) as \$cc |
           select(\$cc != null) |
           (\$labels | map(.name) | map(select(startswith(\"verdict-by:\"))) | first) as \$deadline |
           select(\$deadline == null) |
           {
             id: (\"missing-expectation-\" + (.number | tostring) + \"-\" + (.headRefOid[0:7])),
             kind: \"missing_expectation\",
             number: .number,
             title: .title,
             url: .url,
             updated_at: .updatedAt,
             context: {
               head_sha: .headRefOid[0:7],
               cc_present: \$cc,
               note: \"cc:<peer> without verdict-by:<ts>; auto-verdict-by hook BYPASSED (was injected via: <source>) — see ADR-0024-amendment-auto-verdict-by-hook\"
             }
           } ]"
}
```

The `context.note` field now includes the auto-verdict-by hook provenance — debugging signal for hook vs convention violation.

---

## Rationale

### Why auto-verdict-by over strict-mode enforcement

**Strict-mode (rejected)**: reject any `cc:<peer>` without `verdict-by` at the label-check layer
- (+) Convention enforced at boundary
- (-) High friction: every agent action blocked on convention; backlog risk during rapid iteration
- (-) Layer 5 is a sister to the agent's own discipline — strict-mode defers enforcement to a watcher, not the agent

**Auto-verdict-by (chosen)**: hook auto-injects the pair; convention becomes a no-op for the agent
- (+) Zero friction: agent adds `cc:<peer>` as normal; hook adds paired `verdict-by` automatically
- (+) Convention made-loud: any drift surfaces via `missing_expectation` warning WITH hook bypass provenance
- (+) Layered defense: workflow YAML hook + agent-side helper = 2 paths, defense-in-depth
- (+) Reversibility: removal cost = ~25 LoC + d-test removal, <1 day of refactor — well within "1 hour to reverse" threshold (acceptable arch debt)

### Alternatives considered

| Path | Effect | Cost | Verdict |
|------|--------|------|---------|
| **A (strict-mode)** | Reject `cc:<peer>` without `verdict-by` at Layer 5 | ~30 LoC yaml + d-test (3 TCs) | ❌ Rejected — friction > value |
| **B (auto-verdict-by, agent-side helper)** | Peer-poke helper auto-pairs verdict-by on invocation | ~10 LoC bash | ⚠️ Insufficient alone — manual UI label adds bypass |
| **C (auto-verdict-by, workflow YAML)** | Layer 5 auto-injects verdict-by on cc:<peer> add | ~15 LoC yaml | ⚠️ Insufficient alone — agent CLI before workflow fires |
| **D (BOTH — chosen, this amendment)** | Layer 5 hook + agent-side helper = layered defense | ~25 LoC total | ✅ Adopted — defense-in-depth, zero agent friction |
| **E (PR template auto-fill)** | `.github/PULL_REQUEST_TEMPLATE.md` auto-fills `verdict-by:<default>` | ~5 LoC + template change | ❌ Rejected — partial coverage (template != CLI tools != workflow) |

Path D matches the **boring tech wins** heuristic: it adds ~25 LoC total + ~50 LoC d-test (3 TCs) across 2 layers. No new dependencies. No new auth surface. Sister-pattern to ADR-0048 amendments (workflow YAML hook layer) + ADR-0056 (idempotency reconcile, WARN-not-FAIL philosophy).

### Evidence (sister-patterns)

- **PR #679**: tester-authored, cc:{orch,arch,dev,human} but no verdict-by. This amendment's LIVE INSTANCE.
- **ADR-0024 §Future work**: pre-existing auto-verdict-by hook codification path. This amendment operationalizes it.
- **ADR-0048 amendments (verdict-state-aware + initial-add-defensive-guard)**: workflow YAML hook layer is proven (PR #677 fix for Issue #675 RE-ADD).
- **ADR-0056 idempotency reconcile**: WARN-not-FAIL pattern = silent-skip-event log emission per ADR-0045 lens (d). Same pattern for `missing_expectation` context note.
- **Issue #430 §Pre-citation cross-check**: doctrine is canonical ground truth, not inference from peer signals. The hook reads label state (canonical), not peer message.
- **RETRO-015 §16**: doctrinal gap capture established the pattern for these codifications (RETRO-016 sister-cycle).

---

## Consequences

### Positive

- (+) PR #679 pathology class (cc:<peer> without verdict-by) eliminated by default
- (+) Convention friction reduced to zero — agent adds `cc:<peer>` as normal
- (+) Layered defense: 2 paths (workflow YAML + agent-side helper) catch each other's gaps
- (+) Sister-pattern: aligns with ADR-0048 amendments (Layer 5 hook layer) + ADR-0056 (WARN-not-FAIL philosophy)
- (+) Reversibility: ~25 LoC yaml + ~10 LoC bash + ~50 LoC d-test = total ~85 LoC; removal cost <1 day of refactor (acceptable threshold)
- (+) Codification closes RETRO-016 #2 (Issue #681) + sister to RETRO-016 #3 (Issue #682, arch-bot watchdog gap — orthogonal codification, separate amendment)

### Negative

- (-) ~25 LoC yaml delta in `.github/workflows/label-check.yml` (human-only territory per file ownership matrix — owner merges)
- (-) ~10 LoC bash delta in `scripts/peer-poke.sh` (developer lane territory — non-workflow)
- (-) D-test contract (3 TCs minimum per ADR-0044 RED-first) — ~50 LoC bash
- (-) ADR-0024 §Schema additions + §Watchdog logic updates — minor amendment (not breaking change)
- (-) `silent_skip` log emission increases volume by ~1 event per `cc:<peer>` add (sister-pattern to ADR-0048 lens d doctrine)

### Out of scope (this amendment)

- **Strict-mode enforcement** (rejected above) — separate candidate if convention drift recurs post-amendment
- **Auto-verdict-by for non-cc:<peer> use cases** (e.g., `needs-tester-signoff` could have its own verdict-by semantics) — defer to Sprint 22+ if needed
- **CLI hook integration for ALL gh commands** (e.g., `gh issue create`, `gh pr edit`) — defer; the 2-path layer (workflow YAML + peer-poke helper) covers 95%+ of `cc:<peer>` adds
- **Issue #682 (arch-bot watchdog 30s gap)** — sister codification, separate amendment (RETRO-016 #3)

### Follow-up tickets

- [ ] d-test authoring (sister-pattern d081 `scripts/tests/d081-auto-verdict-by.sh`): ≥3 TCs per ADR-0044 RED-first
  - TC1: Layer 5 auto-injects `verdict-by:<ts>` on `cc:<peer>` add
  - TC2: Agent-side `peer-poke.sh` helper auto-pairs on invocation
  - TC3: Manual UI label add (Layer 5 fires hook + emits `silent_skip` with bypass provenance)
- [ ] yaml impl PR (.github/workflows/label-check.yml) — owner squash gate (file ownership matrix)
- [ ] peer-poke.sh helper impl PR (developer lane) — non-workflow territory
- [ ] RETRO-016 codification carrier (this amendment IS RETRO-016 #2 codification)
- [ ] Sister amendment for Issue #682 (RETRO-016 #3) — separate codification cycle

### Cross-references

- **Closes**: Issue #681 (RETRO-016 candidate #2)
- **Live instance**: PR #679 (tester-authored, cc:{orch,arch,dev,human}, no verdict-by)
- **Sister**: Issue #682 (RETRO-016 #3 — arch-bot watchdog 30s gap, separate amendment)
- **Carrier**: ADR-0024-amendment-verdict-by-aware (does NOT exist; sister-pattern to ADR-0048-amendment-verdict-state-aware + ADR-0048-amendment-initial-add-defensive-guard)
- **Codifies**: ADR-0024 §Future work "Auto-verdict-by" (operationalizes)
- **Sister-pattern**: ADR-0053 (Layer 5 race pattern — Layer 5 + manual flip race)
- **Implements**: ADR-0015 §Sıra zorunlu (atomic 4-flag handoff — hook ensures both add before neither remove)
- **Doctrinal home**: ADR-0024 §Schema additions (canonical verdict-by schema), §Watchdog logic (canonical stale_verdict/missing_expectation events)
- **CI integration**: per file ownership matrix `.github/workflows/` = human-only territory; owner merges

---

## Acceptance Criteria

1. ADR amendment file `docs/decisions/ADR-0024-amendment-auto-verdict-by-hook.md` exists and is Accepted status post-owner-merge
2. `docs/decisions/INDEX.md` updated with this amendment (cross-ref to ADR-0024 + Issue #681 + PR #679)
3. d-test d081 authored per ADR-0044 RED-first (≥3 TCs, --self-test contract per ADR-0049)
4. yaml impl PR opened with workflow diff (owner squash gate per file ownership matrix)
5. peer-poke.sh helper impl PR opened (developer lane)
6. PR #679 has `verdict-by:<ts>` label auto-injected within 1 hour of re-trigger (verification per Step 5 doctrine)

---

— @architect, 2026-06-29T14:26+03:00 = 11:26Z, claim-681 (RETRO-016 cycle ~1169), WIP=2/2 cap reached when API recovers. Drafted locally in `.claude/architect-staging/`. Will claim Issue #681 + push PR when API recovers (15:20Z reset).