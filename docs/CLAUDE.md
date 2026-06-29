# Project Doctrine — Public Summary

> **Source of truth:** `.claude/CLAUDE.md` (internal, human-maintained, gitignored — sister-pattern to `.claude/agents/orchestrator.md` §Dispatch Discipline which IS tracked)
> **Purpose:** Public-facing summary of project doctrine for cross-agent reference.
> **Scope:** Sprint 13 P1 #3 codification (RETRO-007 watchlist entry #6, Sister-pattern to Issue #430 §Pre-verdict cross-check doctrine); RETRO-016 candidate #3 codification (Issue #682, §Post-verdict cross-watchdog).
> **Closes:** Issue #470 (Sprint 13 P1 #3 — §Pre-verdict cross-check timing window codification).

## §Dispatch Discipline — 6-step cross-agent verification

> **Origin:** Issue #414 (orchestrator doctrine, RETRO-005 #26 codification), Issue #430 (PM §Pre-verdict cross-check refinement), Sprint 13 P1 #3 (this document).

### The 6 steps

1. **Comments-vs-reviews cross-check** — Verify both `comments[]` and `reviews[]` before posting verdict (Issue #430 doctrine).
2. **Label freshness check** — Re-query label state via `gh api` (ground truth, not inference from prior comments).
3. **CI status check** — All checks green on latest run (no stale FAIL).
4. **Cross-peer consensus re-query** — Re-query within 30s of verdict post (NOT 1+ min before). See **§Timing window** below.
5. **Doctrinal cite** — Cite ADR/Issue/PR source in verdict header.
6. **Pre-verdict cross-check** — Verify no peer content missed (final sweep before posting).

### §Timing window for cross-peer consensus re-query

> **Origin:** RETRO-007 watchlist entry #6, captured from PR #460 (PM-AC-VERIFY missed arch verdict by 1m2s), PR #462 (tester 1m20s gap on arch verdict), PR #465 (tester cc:human label-state inference miss).

**Rule:** When posting a verdict, re-query ground truth (comments + reviews + labels + CI) **within 30 seconds of posting**, NOT 1+ minute before.

**Why:** GitHub GraphQL comment propagation has a 30-60s window. Verdicts posted >1m after ground-truth query may miss peer content formed in the gap.

**Implementation:**

```bash
# After writing your verdict comment, run within 30s:
gh api repos/<owner>/<repo>/pulls/<N>/comments
gh api repos/<owner>/<repo>/pulls/<N>/reviews
gh api repos/<owner>/<repo>/issues/<N>/labels
# If new content appeared, amend your verdict.
```

**Sister-pattern:** §Pre-verdict cross-check doctrine (Issue #430) — both checks (presence + timing) are required.

## §Pre-verdict cross-check doctrine (sister-pattern)

> **Origin:** Issue #430 (PM doctrine codification, Sprint 13 sister-pattern).

**Rule:** Before posting a verdict, verify BOTH:
- **`comments[]`** — bot comments, peer comments, owner comments
- **`reviews[]`** — formal review submissions (state: COMMENTED / APPROVED / CHANGES_REQUESTED)

Many agents historically missed `reviews[]` because they searched only `comments[]`. Both surfaces are required.

## §Post-verdict cross-watchdog — second-pass peer flag ack

> **Origin:** Issue #682 (RETRO-016 candidate #3, codification cycle ~1222), captured from PR #679 cycle — arch L5 race flag at 12:59:43Z, tester APPROVED at 13:01:10Z (1m27s gap, no re-flag/ack).

**Rule:** When posting a verdict, AFTER completing §Pre-verdict cross-check, the agent MUST identify the **immediately-prior peer verdict** (if any) within the §Timing window AND EITHER:
- **Echo/acknowledge the prior peer's flag** in the verdict header: `Ack <prior-peer-role>: <their flag verbatim>` — if YOUR verdict doesn't re-flag, you MUST explicitly defer: `Defer to <role> flag, my verdict scoped to <subset>`, OR
- **Sentinel value**: `Ack <prior-peer-role>: No prior peer verdict found` (when no prior verdict exists in the 30s window)

**Why:** Even when MY §Pre-verdict cross-check passes, the **previous peer's verdict may have raised a flag** that I am downstream of. If I post my verdict without echoing that flag, the flag is effectively suppressed at the owner merge gate. **PR #679 (Issue #682 LIVE INSTANCE):** arch flagged ⚠️ L5 race at 12:59:43Z (cmt 4832870728); tester posted APPROVED at 13:01:10Z (cmt 4832882798) without echoing the flag; flag was lost in owner review (RCA cmt 4832896717 orch triage).

**Distinguishing axis from §Pre-verdict cross-check (Issue #430):**
- §Pre-verdict cross-check verifies **YOUR** content's freshness (re-query before post)
- §Post-verdict cross-watchdog verifies **PRIOR PEER** content's propagation to owner merge gate

Both checks are required per dispatch doctrine. Neither subsumes the other.

**Implementation:**

```bash
# Within 30s of verdict post, identify the immediately-prior peer verdict:
gh api repos/<owner>/<repo>/issues/<N>/comments \
  --jq '.[] | select(.body | test("Verdict:|APPROVED|NEEDS CHANGES|NEEDS DISCUSSION|🟢|🟡|🔴")) | {user: .user.login, created_at: .created_at, body: .body[0:300]}'

# If a prior verdict exists:
#   - MUST include in YOUR verdict header: Ack <prior-peer-role>: <their flag verbatim>
#   - If their flag (🟡/🔴) is not re-flagged by YOUR verdict:
#     - Either re-flag with new evidence, OR
#     - Explicitly defer: "Defer to <role> flag, my verdict scoped to <subset>"
# If no prior verdict exists:
#   - Sentinel value: "Ack <prior-peer-role>: No prior peer verdict found"
```

**Canonical verdict template (replaces ad-hoc PR comments for ALL peer reviewers):**

```markdown
🤖 Verdict: [🟢 OK | 🟡 Suggestion | 🔴 Block]   — architect/dev peer review
      OR [🟢 APPROVED | 🟡 NEEDS CHANGES | 🔴 NEEDS DISCUSSION]   — tester/PM sign-off
Ack <prior-peer-role>: [<flag verbatim> | "No prior peer verdict found"]
[<verdict body — design alignment, evidence, risks, lens attestation>]
Cross-watchdog: re-queried comments+reviews+labels+CI within 30s of post (Issue #430 §Timing window + Issue #682 §Post-verdict cross-watchdog)
[Optional: Defer to <role> flag, my verdict scoped to <subset>]
```

**Why this is RETRO-016 (not RETRO-007 watchlist — already covered):** RETRO-007 watchlist entry #6 codifies the timing window for ONE peer. This is the **second-pass peer cross-watchdog**: even when MY cross-check passes, did PREVIOUS peer's verdict get ackd/echoed before owner merge?

**Sister-pattern:** ADR-0024 amendment (auto-verdict-by hook, Closes #681) — that codifies the **label-add atomicity** invariant (`cc:<peer>` paired with `verdict-by:<ts>`). This codifies the **verdict-post propagation** invariant (peer-flag ack in verdict header). Both are RETRO-016 sister-patterns.

**Test coverage (deferred to d082 sister-test, ADR-0044 RED-first, ≥3 TCs):**
- TC1: Verdict header includes `Ack <peer>: ...` line within 30s of post
- TC2: When prior peer verdict raised 🟡/🔴, current verdict EITHER re-flags OR explicitly defers
- TC3: Sentinel value `No prior peer verdict found` when no prior verdict exists

## Scope and applicability

This §Dispatch Discipline applies to **all peer reviewers** (architect / developer / tester / PM), not PM-specific. Sister-pattern to:

- **Architectural verdicts** on PRs (arch 9-Lens review per ADR-0045)
- **Developer technical reviews** on PRs
- **Tester sign-off verdicts** on PRs (per ADR-0044 RED-first TDD)
- **PM acceptance verdicts** on PRs (per Issue #430)

## Cross-references

- **Issue #414** — orchestrator doctrine: §Dispatch Discipline 6-step source
- **Issue #430** — PM doctrine: §Pre-verdict cross-check (comments[] AND reviews[] both required)
- **Issue #682** — architect doctrine: §Post-verdict cross-watchdog (second-pass peer flag ack) — RETRO-016 candidate #3 codification
- **RETRO-005 #26** — original §Dispatch Discipline codification
- **RETRO-007 watchlist entry #6** — §Pre-verdict cross-check timing window
- **RETRO-016 #2** — ADR-0024 verdict-by missing on tester-authored PRs (PR #679 gap, Closes #681)
- **RETRO-016 #3** — arch-bot cross-watchdog 30s gap (PR #679 tester didn't re-flag arch L5 flag, this codification)
- **PR #460** — PM-AC-VERIFY missed arch verdict (1m2s gap, root cause for §Timing window)
- **PR #462** — tester 1m20s gap on arch verdict (sister-pattern)
- **PR #465** — tester cc:human label-state inference miss (5th instance of pattern)
- **PR #679** — d069 d-test (LIVE INSTANCE for both #681 and #682, RETRO-016 sister-pair)
- **ADR-0024 amendment** — Auto-Verdict-By Hook (Closes #681, RETRO-016 #2 codification, sister-pattern)
- **ADR-0045** — 9-Lens Review Checklist (architectural)
- **ADR-0044** — RED-first TDD (tester)

— @architect (Issue #682 codification, cycle ~1222), @product-manager (Sprint 13 P1 #3 codification, closes Issue #470, RETRO-007 watchlist #6)
