# ADR-0012 — Required Label Set on Issue/PR Creation

**Status:** Accepted (amended 2026-06-21, 2026-06-26, 2026-06-27)
**Date:** 2026-06-14 (amended 2026-06-21, 2026-06-26, 2026-06-27)
**Supersedes:** —
**Related:** ADR-0002 (GitHub-Native Autonomy), ADR-0007 (Label Cleanup), ADR-0009 (Label Discipline), ADR-0013 (Status → Board Sync), ADR-0021 (Docs PR Convention), ADR-0015 (Atomic 4-flag handoff), Issue #213 (TEST-WAKE-ENFORCE doctrine gap, 3-layer), Issue #394 (this amendment's trigger, RETRO-005 #21), Issue #394 follow-up (amended 2026-06-27: §Part 1 ambiguity clarification), PR #393 (canonical cascade-strip case), PR #418 (P1 combined amend), PR #420 (ADR-0047 cross-repo watcher)

---

## Context

The dev-studio template defines four label categories that together encode
everything the autonomy loop and the human owner need to know about a piece
of work:

| Category | Examples | Purpose |
|---|---|---|
| `type:*` | `type:vision`, `type:feature`, `type:bug`, `type:docs`, `type:chore`, `type:refactor`, `type:incident` | What kind of work this is |
| `status:*` | `status:backlog`, `status:ready`, `status:in-progress`, `status:in-review`, `status:blocked`, `status:done` | Where in the flow it lives |
| `agent:*` | `agent:product-manager`, `agent:architect`, `agent:developer`, `agent:tester`, `agent:orchestrator`, `agent:human` | Who owns it |
| `cc:*` | `cc:product-manager`, `cc:architect`, `cc:developer`, `cc:tester`, `cc:orchestrator` | Who holds the active queue / next ball |

ADR-0009 codified the **handoff** discipline (when to flip `cc:*`), but it
did not codify the **birth** discipline: which labels must be present the
moment an issue or PR is *first* created. In practice we have observed
agents creating issues with only the `agent:*` + `cc:*` pair, leaving
`type:*` and `status:*` missing. Concrete failure observed on
2026-06-14 in the first `AtilCalculator` bootstrap:

- Issue #2 (PM-authored `docs(product): vision + personas`) had only
  `agent:human`, `cc:tester`, `needs-tester-signoff` — no `type:*`, no
  `status:*`. Board card landed in the "No Status" lane and the human
  could not filter the work by kind.
- Issue #3 (Architect-authored `ADR-0001`) had `type:feature` +
  `status:backlog` + `agent:architect` + `cc:architect` — correct, but
  the board Status field was still empty because GitHub does not sync
  the `status:*` label to the Projects v2 Status field automatically
  (see ADR-0013).

The agent soul docs already show example `gh issue create` /
`gh pr create` commands, but those examples only carry one or two
labels each, which has trained the agents to treat the rest as
optional.

## Decision

**Every issue and every PR opened by an agent — at the moment of
creation — MUST carry at least one label from each of the four
categories**: `type:*`, `status:*`, `agent:*`, `cc:*`. There is no
exception for "I'll add it later" or "the orchestrator will set
this." Missing categories at birth break two systems at once:

1. **Board hygiene** — type/status are how humans slice the backlog
   and how board automation rules (ADR-0013) decide which Status field
   value to set.
2. **Autonomy loop** — `agent:*` is the wake-up signal for `issue_assigned`
   and `cc:*` is the wake-up signal for queue position. Without both,
   the wrong agent gets woken or no agent wakes at all.

### Required-set table by event

| Event | `type:*` | `status:*` | `agent:*` | `cc:*` |
|---|---|---|---|---|
| New story issue (PM) | `type:feature` (or `type:bug`, etc.) | `status:backlog` (always at birth) | `agent:<next-owner>` | `cc:<next-owner>` |
| New design / ADR PR (Architect) | `type:docs` (ADR) or `type:refactor` (design impact) | `status:in-review` (PR is open) | `agent:architect` | `cc:product-manager`, `cc:developer` (paralel review) |
| New implementation PR (Developer) | `type:feature` / `type:bug` / `type:refactor` (match story) | `status:in-review` | `agent:developer` | `cc:tester`, plus `needs-tester-signoff` |
| New test-plan PR (Tester) | `type:docs` (test plan) or `type:feature` (test suite that ships) | `status:in-review` | `agent:tester` | `cc:developer` |
| New bug issue (Tester) | `type:bug` | `status:backlog` | `agent:developer` | `cc:developer` |
| New chore / refactor issue (any agent) | `type:chore` or `type:refactor` | `status:backlog` | `agent:<owner>` | `cc:<owner>` |
| Sprint-coordination issue (Orchestrator) | `type:chore` | `status:ready` (immediately actionable) | `agent:orchestrator` | `cc:<addressee>` |
| Incident issue (any agent) | `type:incident` | `status:in-progress` | `agent:developer` | `cc:developer`, `cc:architect` |

If an agent legitimately cannot decide a category (e.g. type is
ambiguous), the contract is **escalate, do not omit**: add a comment
asking the relevant owner to relabel, but ship the issue with a
best-guess label so the four-category invariant holds.

### Type-driven invariants (amended 2026-06-21, Issue #213)

In addition to the four-category invariant above, certain `type:*`
values impose **type-driven label requirements** that apply
**regardless of the opening agent**. These are stricter than the
agent-driven table and take precedence in case of conflict.

| `type:*` value | Required additional labels at open | Rationale |
|---|---|---|
| `type:bug` | `cc:tester` + `needs-tester-signoff` | Bug fixes are correctness-bearing. The tester's correctness principle (label-driven wake per ADR-0002) requires explicit test-review handoff. Without these labels, the bug PR can sit in `status:ready` for hours with **zero reviewer verdicts** (silent skip, observed 2026-06-21 on PR #212 — Issue #213 §Context). |
| `type:docs` | (no test required) | ADR-0021 §docs PR convention: docs PRs are owner-merge-gated by default. Tester signoff is not required. ADR-0021 is the controlling doctrine for the docs-PR exception. |
| `type:incident` | (no test required, but `cc:architect` mandatory) | Incident PRs are time-critical; the agent-driven table already mandates `cc:developer` + `cc:architect`. Tester review is the architect's call per `verdict-by` urgency. |
| All other `type:*` | (no test required) | Feature, chore, refactor: tester review is per the agent-driven table. |

#### Interaction with the agent-driven table

The type-driven invariant is **stricter** than the agent-driven
table in some combinations:

- **Example 1**: an architect opens a `type:bug` PR for a code defect
  in a docs PR's CI workflow. The agent-driven table for the
  architect row does NOT mandate `cc:tester`. The type-driven
  invariant DOES — `type:bug` → `cc:tester` + `needs-tester-signoff`
  are mandatory. **The type-driven invariant wins.**
- **Example 2**: a developer opens a `type:docs` PR. The agent-driven
  table for the developer row says `cc:tester` is mandatory. The
  type-driven invariant says `type:docs` → no test required. **The
  type-driven invariant wins** (docs PR is owner-merge-gated per
  ADR-0021).
- **Example 3**: a tester files a `type:bug` issue (not PR) for a
  developer to fix. The agent-driven table says `cc:developer`. The
  type-driven invariant applies to PRs only — issues are governed by
  the agent-driven table alone.

#### Owner override

For `type:bug` PRs only, the owner may skip the `cc:tester` +
`needs-tester-signoff` requirement with **explicit rationale in the
PR body** (e.g. "emergency hotfix, CI gate enforces test coverage
separately"). This is the **owner-override** exception, parallel to
the owner-override doctrine in ADR-0031. The PR must still carry
all other four-category labels.

#### Enforcement

The `label-check.yml` workflow (see §Enforcement below) is the
authoritative CI gate. Layer 3 of Issue #213 §3-Layer Solution
extends `label-check.yml` with a type-driven check:

```yaml
# pseudocode for the type-driven branch
if (issue_or_pr.type == "type:bug"
    and (missing "cc:tester" or missing "needs-tester-signoff")):
    fail_check(message="type:bug PR/issue must have cc:tester + needs-tester-signoff at open per ADR-0012 §Type-driven invariants")
```

The owner-overrides via PR-body rationale are **CI-passed by
default** (the workflow does not parse PR body); the audit trail is
the PR body + comment thread. This is a known limitation; future
work could add a PR-body parser.

### Enforcement

Documentation alone is not enough — agents have already proven they
will skip steps under time pressure. Therefore this ADR is shipped
alongside GitHub Actions workflows. The four-category invariant
itself is enforced by `label-check.yml`. The **type-driven
invariants** (added in the 2026-06-21 amendment) are enforced by the
same workflow, with a type-driven branch per §Type-driven invariants
§Enforcement above. Both extensions are human-only files
(`.github/workflows/`) — agents propose via PR, owner approves.

The two authoritative workflows are:

1. **`label-check.yml`** (this ADR). On every issue/PR `opened`,
   `reopened`, `labeled`, `unlabeled` event, the workflow verifies
   that all four categories have at least one label. If the
   `type:*` is `type:bug`, the workflow additionally checks for
   `cc:tester` + `needs-tester-signoff` per §Type-driven invariants.
   If any required label is missing, the workflow:
   - posts an inline comment listing exactly which categories are
     missing (and which type-driven invariants, if applicable),
   - fails the check (visible in the PR "Checks" UI),
   - re-fires on every subsequent label change so the agent fix-back
     loop can drive it green.
2. **`status-label-to-board.yml`** (ADR-0013). Mirrors `status:*`
   label changes onto the Projects v2 Status field so the board no
   longer drifts from labels.

### Cascade-strip scope-tightening (amended 2026-06-26, Issue #394)

The `label-check.yml` workflow's **duplicate `status:*` removal**
and **`status:ready` auto-add** behaviors must be **scope-tightened**
to avoid cascade-stripping the reviewer chain. This amendment
specifies the doctrinal contract; the actual workflow change is
**owner-merge gated** per CLAUDE.md §File ownership matrix
(`.github/workflows/` = human-only territory — agents propose via
PR, owner approves + merges).

#### Part 1 — Duplicate `status:*` removal MUST be scope-limited

When a PR or issue has multiple `status:*` labels (e.g.,
`status:in-review + status:ready`), the workflow MUST remove
**only the duplicate label** (the most-recent one) and MUST NOT
cascade-strip the rest of the reviewer chain (`cc:*` +
`needs-*-signoff` labels). The **canonical primary status**
(the first-applied one — i.e. the original status before the
duplicate was added) MUST be preserved.

**Canonical case** — PR #393 (2026-06-25): an arch verdict
auto-cleanup added `status:ready` while `status:in-review` was
still present (mutual exclusion violation, per §Future work
below). Manual `--remove-label "status:ready"` then triggered the
workflow to cascade-strip `status:in-review + cc:tester +
needs-tester-signoff` as "cleanup", breaking the reviewer chain.
Manual restoration of all four labels was needed.

**Canonical-primary identification** (clarified 2026-06-27, Issue #394 follow-up): the canonical primary is the **first-applied** (oldest) `status:*` label on the issue/PR, identified by sorting all `status:*` labels by `createdAt` timestamp ascending and selecting the first. The **duplicate** is the most-recent (newest) one and is the one removed. This corresponds to the PR #393 canonical case: `status:in-review` was first-applied (preserved), `status:ready` was most-recent (removed).

> **Doctrine history** — the 2026-06-26 amendment (commit 500b2ef) used the phrasing "most recent / first-applied" with a slash, which the architect's own §Spec review (2026-06-27, dual-channel ping to ORCH + comment on Issue #394) flagged as **self-contradictory**. This 2026-06-27 amendment removes the slash and replaces the function name with the unambiguous `first_applied` (oldest by createdAt = preserved).

**Scope rule** (pseudocode for owner-approved workflow update):

```yaml
# pseudocode for the cascade-strip-tightening branch
if (len(status_labels) > 1):
    # Identify the canonical primary status: FIRST-APPLIED (oldest by createdAt = preserved)
    primary = first_applied(status_labels)  # sorts statusLabels by createdAt ascending; primary = oldest
    # Remove ONLY the duplicate (most-recent = newest), never the reviewer chain
    for label in status_labels:
        if label != primary:
            gh_pr_remove_label(label)  # do NOT touch cc:* / needs-*-signoff
    # DO NOT touch: cc:tester, cc:developer, cc:human,
    #                needs-tester-signoff, needs-architect-review
```

#### Part 2 — `status:ready` auto-add requires cleared reviewer chain

The `label-check.yml` auto-add of `status:ready` (observed in the
PR #393 cascade) MUST fire **only when the reviewer chain is fully
cleared**, not merely because an arch verdict was posted.

| PR `type:*` | Required cleared state for `status:ready` auto-add |
|---|---|
| `type:docs` (per ADR-0021) | Arch verdict posted (`needs-architect-review` removed) — **no tester signoff required** |
| `type:bug`, `type:feature`, `type:refactor` (non-docs) | `needs-tester-signoff` cleared by tester APPROVED verdict — **arch verdict alone is insufficient** |
| `type:chore`, `type:incident` | Tester signoff required (same as feature) |

**Rationale**: The PR's `status:ready` semantically means "ready for
owner merge gate" (per §Decision §Required-set table by event —
`status:ready` row mandates `cc:human` for owner merge). For
non-docs PRs, the tester's correctness principle (per
`.claude/agents/tester.md` §Standard Workflows) is a **prerequisite**
for the owner merge gate — owner cannot merge a non-docs PR with a
missing tester verdict. The `status:ready` auto-add logic must
respect this prerequisite.

#### Interaction with ADR-0015 (atomic 4-flag handoff)

The atomic 4-flag handoff (ADR-0015) prescribes:

```bash
gh issue edit N \
  --add-label    "agent:<next>" \
  --add-label    "cc:<next>" \
  --remove-label "cc:<self>" \
  --remove-label "agent:<self>"
```

**Key constraint**: the atomic handoff removes `cc:<self>` and
`agent:<self>`, but it does NOT remove `status:*` or
`needs-*-signoff` — those are managed by the workflow per the
parts above. If a 4-flag handoff is observed by the workflow as
creating a duplicate `status:*`, the cascade-strip-tightening rule
in Part 1 applies (remove only the duplicate, preserve the rest).

#### Acceptance criteria

- [ ] `.github/workflows/label-check.yml` Part 1 fix: removing
      duplicate `status:*` does NOT cascade-strip reviewer chain
      (`cc:*` + `needs-*-signoff` preserved)
- [ ] `.github/workflows/label-check.yml` Part 2 fix: `status:ready`
      auto-add only when reviewer chain is fully cleared (per
      type-driven table above)
- [ ] d-test for the workflow fix (workflow validation hermetic
      test, 3 TCs minimum: docs PR arch verdict alone →
      `status:ready`, non-docs PR tester verdict → `status:ready`,
      non-docs PR arch verdict alone → `status:ready` NOT
      auto-added)
- [ ] Regression: PR #391 + #393 patterns do NOT reoccur in next
      5 PRs
- [ ] Owner approval per file ownership matrix (`.github/workflows/`
      = human-only territory; this ADR is the architect-authored
      doctrine/spec, the actual workflow file change is owner-merge
      gated)

#### Sister-ADR / sister-pattern context

- **Issue #394** — this amendment's trigger, RETRO-005 #21 candidate
- **PR #393** — canonical cascade-strip case
- **PR #391** — docs PR auto-flip pattern (related, non-cascade)
- **ADR-0015** — atomic 4-flag handoff (operational companion to
  this enforcement-side specification)
- **RETRO-005 candidates** #17, #19, #21, #26 — automation-drift /
  staleness / unintended-side-effects pattern family

#### Out of scope for this amendment

- The actual `.github/workflows/label-check.yml` file change —
  **owner-merge gated** per CLAUDE.md §File ownership matrix. This
  ADR specifies the doctrinal contract; the owner implements in
  workflow YAML.
- Mutual-exclusion gate for `status:*` (the broader "exactly one
  `status:*` at a time" check) — still §Future work below; this
  amendment is the **scope-tightening** of the cascade behavior, not
  the introduction of new gate logic.

### Examples for each agent (canonical `gh` commands)

PM creating a vision-derived PR:

```bash
gh pr create \
  --title "docs(product): vision + personas (intake #<N>)" \
  --body "Closes #<N>'s vision intake..." \
  --label "type:docs" \
  --label "status:in-review" \
  --label "agent:human" \
  --label "cc:architect"
```

PM creating a story issue:

```bash
gh issue create \
  --title "STORY-NNN: <one-liner>" \
  --body "..." \
  --label "type:feature" \
  --label "status:backlog" \
  --label "agent:tester" \
  --label "cc:tester"
```

Architect creating an ADR PR:

```bash
gh pr create \
  --title "docs(adr): ADR-NNNN <slug>" \
  --body "Proposes <decision>..." \
  --label "type:docs" \
  --label "status:in-review" \
  --label "agent:architect" \
  --label "cc:product-manager" \
  --label "cc:developer"
```

Developer opening an implementation PR (draft):

```bash
gh pr create --draft \
  --title "feat(scope): STORY-NNN <one-liner>" \
  --body "Implements STORY-NNN..." \
  --label "type:feature" \
  --label "status:in-review" \
  --label "agent:developer" \
  --label "cc:tester" \
  --label "needs-tester-signoff"
```

Tester filing a bug issue:

```bash
gh issue create \
  --title "BUG: <one-liner>" \
  --body "Repro steps..." \
  --label "type:bug" \
  --label "status:backlog" \
  --label "agent:developer" \
  --label "cc:developer" \
  --label "priority:P1"
```

Orchestrator opening a sprint-coordination issue:

```bash
gh issue create \
  --title "Sprint N kickoff" \
  --body "Plan..." \
  --label "type:chore" \
  --label "status:ready" \
  --label "agent:orchestrator" \
  --label "cc:product-manager"
```

## Consequences

### Positive

- Every artifact carries enough metadata for the autonomy loop and
  the human owner to act on it from the first second.
- Board lanes are never "No Status" again (combined with ADR-0013).
- The `label-check` workflow turns a soft norm into a CI gate, which
  matches how every other discipline gate (tests, lint, CI green)
  works in this template.
- Future agent roles (we may add `agent:designer`, `agent:devops`
  later) inherit the same contract for free.

### Negative

- Agents must remember more parameters at creation time. Mitigation:
  every soul doc now contains the canonical `gh` command for the
  agent's most common create flows.
- One more CI workflow to maintain. Mitigation: `label-check.yml` is
  ~80 lines and uses only the GitHub Actions `actions/github-script@v7`
  primitive — no third-party deps.
- Issues created via the GitHub web UI by humans may initially miss
  labels. Mitigation: the same `label-check` workflow comments with
  exact missing labels, and the human can fix in one click; the
  template's GUI issue templates also pre-fill the labels.

### Out of scope

- Replacing labels with a typed enum field on the Projects v2 board.
  Considered, rejected: GitHub Actions on label change is universally
  reliable; field-update events are not.
- Auto-fixing missing labels via the workflow. Considered, rejected:
  the agent should learn to set labels at birth; auto-fix hides the
  defect.

## Future work

- Add `priority:*` to the required-set (currently optional). Likely
  to follow once agents are stable on the four-category baseline.
- Extend `label-check.yml` to verify mutual exclusion in some
  categories (e.g. exactly one `status:*` at a time).
- **Type-driven CI gate for `label-check.yml`** (Layer 3 of Issue #213
  §3-Layer Solution). Currently the type-driven invariants are
  documented in this ADR but not yet enforced in CI. The CI
  extension is human-only (`.github/workflows/`) and pending owner
  approval. See `docs/decisions/ADR-0012-required-label-set.md`
  §Type-driven invariants §Enforcement for the pseudocode that
  owner-approved workflows should implement.
- **PR-body parser for owner-override audit trail**: future work
  could extend the type-driven CI gate to parse the PR body for
  owner-override rationale (currently unaudited).
