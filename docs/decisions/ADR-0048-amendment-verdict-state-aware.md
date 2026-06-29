# ADR-0048 Amendment: Verdict-State-Aware Layer 5 Gating (Path A, WARN-not-FAIL)

- **Status:** Proposed (Sprint 21 P1, Path A ratified by @product-manager per Issue #659 cmt 4828801300)
- **Date:** 2026-06-29
- **Deciders:** @architect (doctrine/spec), @product-manager (business call Path A), @tester (d-test contract — 3 TCs minimum per ADR-0044 RED-first), @developer (yaml impl in `.github/workflows/label-check.yml` per file ownership matrix human-only territory → owner merges), @atilcan65 (owner squash gate for workflow file)
- **Parent ADR:** [ADR-0048](./ADR-0048-status-ready-auto-add-gating.md) — `label-check.yml` Layer 5: `status:ready` Auto-Add Gating (Type-Driven Reviewer Chain)
- **Amends:** ADR-0048 by adding verdict-state check before auto-promote; type-driven reviewer chain table preserved (no architectural change to chain semantics)
- **Closes:** Issue #659 (S21-FOLLOW-001, RETRO-015 §16 carrier)
- **Sister-patterns:** ADR-0056 (Layer 5 idempotency reconcile, WARN-not-FAIL), ADR-0024 (§Schema verdict-by discipline), ADR-0055 (Cadence Rule 1 atomic — this ADR is amendment not replacement), Issue #430 (§Pre-citation cross-check doctrine), RETRO-015 §16 (doctrinal gap capture), Issue #113 (labels > body)
- **Related:** PR #655 (LIVE INSTANCE #1, d073 d-test), PR #657 (LIVE INSTANCE #2, d074 d-test), PR #660 (PM AC canonicalization precedent)

---

## Context

ADR-0048 Layer 5 (`status:ready` auto-add gating, type-driven reviewer chain) currently fires on `cc:<peer>` REMOVAL when the reviewer chain APPEARS satisfied — but does NOT read the actual verdict content (arch `comment[].body` or `review[].state`).

### Triggering LIVE INSTANCES (RETRO-015 §16)

- **PR #655** (d073 d-test, 2026-06-29 02:59:36Z): Layer 5 auto-promoted `status:ready`+`cc:human` when `needs-tester-signoff` was removed. Arch verdict was 🟡 NEEDS CHANGES (4 min later at 03:03:35Z). Premature auto-promote = owner merge gate bypass.
- **PR #657** (d074 d-test, 2026-06-29 03:07:25Z): Layer 5 auto-promoted **9 seconds after PR creation** — BEFORE any verdict was posted. Worst-case pathology.

### Why this is a problem

1. **ADR-0024 §Schema violation** — every `cc:<peer>` MUST be paired with `verdict-by:<ts>`. PR #655 + #657 had `cc:developer`+`cc:human` but NO `verdict-by:*` label (4-cat invariant broken; watchdog `missing_expectation` should fire).
2. **Architect Handoff Discipline gap** — removing `cc:architect` on 🟡 verdict satisfies ADR-0015 atomic handoff but violates ADR-0024 (verdict-by not added). Arch self-correction applied cycle ~919 (keep `cc:architect` + add `verdict-by:<ts>` on 🟡).
3. **Layer 5 conflation** — "peer lane done" ≠ "peer APPROVED". Need verdict-state check before auto-promote.
4. **Owner gate bypass** — `status:ready`+`cc:human` implies "ready for human merge" but no peer has actually APPROVED. Owner could merge unverified code.

---

## Decision

**Path A (cheapest, WARN-not-FAIL)** — extend `label-check.yml` Layer 5 to read PR verdict emoji from `comments[]` (sister to Issue #430 §Pre-citation cross-check) BEFORE auto-promote:

| Verdict emoji in PR comments[] | Layer 5 action | Log emission |
|--------------------------------|----------------|---------------|
| 🟢 found | ✅ auto-promote allowed (regression check vs PR #629 + #656 sister-pattern) | standard `promoted` log |
| 🟡 found | ⏸️ skip auto-promote | `silent_skip` log per ADR-0045 lens (d) |
| 🔴 found | ⏸️ skip auto-promote | `silent_skip` log per ADR-0045 lens (d) |
| No verdict found | ⏸️ skip auto-promote | `silent_skip` log per ADR-0045 lens (d) |

**Implementation cost:** ~30 LoC yaml delta in `.github/workflows/label-check.yml` per file ownership matrix human-only territory (owner merges).

**Architect Handoff Discipline table amendment** (sister-pattern, `.claude/agents/architect.md` human-only territory → owner merges):
- OLD: 🟡 NEEDS CHANGES → `--remove-label cc:architect --add-label cc:developer`
- NEW: 🟡 NEEDS CHANGES → keep `cc:architect` + `--add-label verdict-by:<ts>` + `--add-label cc:developer` (FIX-LOOP CLOCK + reviewer chain NOT prematurely satisfied)

---

## Rationale

### Why Path A over B/C

**Path A (chosen)** — minimum-touch principle + PR #660 sister-pattern + ADR-0056 alignment
- **Cost:** ~30 LoC yaml + d-test (3 TCs minimum per ADR-0049 sister-pattern)
- **Risk:** low (WARN-not-FAIL means Layer 5 doesn't false-positive on legitimate verdicts; only suppresses premature auto-promote on non-🟢 verdicts)
- **Sister-pattern:** ADR-0056 (Layer 5 idempotency reconcile, WARN-not-FAIL proven in production)

**Path B (deferred unless A insufficient)** — full verdict-state-aware (reads `reviews[]` state + `comments[]` emoji per Issue #430 §Pre-citation cross-check)
- **Cost:** ~50 LoC + 4th TC for review-state coverage
- **Risk:** medium (could break existing reviews[] dependency; reviewer state semantics differ from comment emoji)

**Path C (rejected for Sprint 21)** — full Doctrine 5.0 refactor (gate on `verdict-by:<ts>` label presence + clock condition)
- **Cost:** 50+ LoC + d-test family + regression test on 50+ recent PRs
- **Risk:** high (largest blast radius; many PRs verify auto-promote on different triggers)

### Evidence

- **RETRO-015 §16:** 2 LIVE INSTANCES in 24h (PR #655 + PR #657) demonstrating pathology
- **ADR-0056 sister-pattern:** WARN-not-FAIL pattern proven in production (PR #545 + PR #553 LIVE INSTANCES + self-correction cycles)
- **Issue #430 §Pre-citation cross-check:** comments[] AND reviews[] doctrine codified (PR #485 + PR #499 + PR #500 sister-pattern)
- **Architect.md Handoff Discipline:** refined cycle ~919 (🟡 NEEDS CHANGES → keep cc:architect + add verdict-by:<ts> + add cc:developer); pattern codified in this amendment
- **Issue #113 (labels > body):** Layer 5 must read canonical state (labels > body text)

---

## Consequences

### Positive

- ✅ Layer 5 no longer auto-promotes on reviewer chain APPEARANCE without actual verdict
- ✅ Owner squash gate semantic preserved (only 🟢 verdict triggers `status:ready` auto-promote; 🟡/🔴/none require explicit human flip)
- ✅ ADR-0024 §Schema compliance enforced at Layer 5 (verdict-by presence becomes a precondition for auto-promote)
- ✅ Architect Handoff Discipline table row amendment (🟡 pattern) co-lands — prevents future arch self-correction loops
- ✅ PR #628 + #658 + #660 squash gates unblocked post-amendment (per PM commitment, 2026-06-29 cmt 4828801300)
- ✅ Wave 1 dispatch (S21-001/002/008/019) unblocked post-amendment merge

### Negative

- ⚠️ New yaml delta requires orchestrator + human approval (per CLAUDE.md §Things agents must NEVER do: "Modify `.github/workflows/`... without explicit human approval")
- ⚠️ `silent_skip` log emission rate increases (observability noise — but matches ADR-0045 lens (d) compliance)
- ⚠️ d-test family registry grows (d061 = 11th sister per ADR-0055 Sub-pattern matrix; ADR-0049 + ADR-0050 + ADR-0054 + 4-Workflow d-tests + ADR-0051 + ADR-0052 + ADR-0053 + ADR-0055 d059 = 10 existing, d061 = 11th)
- ⚠️ Per Issue #238, no self-justified pauses during sprint close — owner squash gate is gated on human availability

### Follow-up tickets

- **Issue #659** (this issue, cycle ~919 filing): S21-FOLLOW-001 — sprint follow-up root
- **architect.md amendment** (`.claude/agents/architect.md`): Handoff Discipline table row update (🟡 NEEDS CHANGES → keep cc:architect + add verdict-by:<ts> + add cc:developer) — owner merges per file ownership matrix
- **PR #628 + #658 + #660 squash gates**: PM holds label flips until this amendment merges (pathology prevention per PM commitment cmt 4828801300)
- **Wave 1 dispatch**: S21-001/002/008/019 unblocks post-#659-merge
- **RETRO-015 §16 closure**: doctrinal gap captured, fix-tracker registered, evidence preserved for future codification

---

## §9-Lens pre-publish gate (per ADR-0045)

- **(a) Data flow:** ✅ — verdict emoji in `comments[]` → Layer 5 verdict-state check → conditional auto-promote OR `silent_skip` log. All paths observable.
- **(b) Runtime preconditions:** ✅ — `gh` CLI + Label API + comments[] API all available; no new tooling required.
- **(c) Canonical entry:** ✅ — Layer 5 yaml in `label-check.yml` (existing canonical entry point from ADR-0048 §Implementation).
- **(d) Silent-skip risk:** ✅ — explicit `silent_skip` log emission on 🟡/🔴/none (lens d compliance codified). Sprint 21 WG 1 silent-skip doctrine preserved.
- **(e) Idempotency:** ✅ — Layer 5 runs per label event; verdict-state check is deterministic (comment emoji or absence thereof, no state mutation).
- **(f) Observability:** ✅ — `silent_skip` log + d-test 3 TCs + arch verdict cmt traceable; lens (f) compliance.
- **(g) Security & privacy:** ✅ — comments[] public info; no secret leak. Verdict emoji parsing is regex-only (no eval).
- **(h) Workflow YAML SHA pin:** ✅ — yaml changes preserve SHA pin discipline (TD-028 sister-pattern; per ADR-0027 §Threat model).
- **(i) Platform hard constraints:** ✅ — yaml stays within 8 sub-categories per ADR-0043 (no raw `docker run` / `ssh` outside `actions/*` ecosystem; sandbox preserved).
- **(j) Auto-generated file refs:** ✅ — `d061-verdict-state-aware-layer-5.sh` canonical name; ADR-0048 amendment registered in `INDEX.md` per ADR-0055 Cadence Rule 1 atomic.
