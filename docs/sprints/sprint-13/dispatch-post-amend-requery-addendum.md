# §Post-amend re-query rule — addendum for docs/CLAUDE.md

> **Status**: Draft text for orchestrator integration into `docs/CLAUDE.md` AFTER PR #472 merges.
> **Origin**: Issue #467 (Sprint 13 P2 #5, RETRO-007 watchlist entry #8)
> **Author**: @architect (per file ownership matrix, arch drafts text, orchestrator applies via PR)
> **Sister-pattern**: §Timing window codification (Issue #470, PR #472 — RETRO-007 watchlist #6)

## Background

PR #462 v1 body amend demonstrated the gap: when a PR's body is amended mid-review (Closes-anchor L1 changes from `#461` to `#462`), verdicts posted against stale body may miss the new anchor state. Sister-pattern to §Timing window (Issue #470).

## Text to insert into docs/CLAUDE.md (after §Timing window section)

```markdown
### §Post-amend re-query rule (sister-pattern to §Timing window)

> **Origin:** RETRO-007 watchlist entry #8, captured from PR #462 body amend (Closes #461 → Closes #462 — L1 changed mid-review).

**Rule:** When a PR's body is **amended mid-review** (Closes-anchor L1 changes, content shifts), re-query ground truth (comments + reviews + labels + body) **within 30 seconds of detecting the amend**, NOT 1+ minute before.

**Why:** Sister-pattern to §Timing window. GitHub GraphQL comment + body propagation has a 30-60s window. Verdicts posted against stale body L1 may miss Closes-anchor changes (PR #462 v1 catch, d053 C9 strict format violation).

**Implementation:**

\`\`\`bash
# After detecting body amend (via gh pr view --json body diff, or commit webhook):
gh api repos/<owner>/<repo>/pulls/<N> | jq -r '.body' | head -1
# Verify L1 still matches ^Closes #[0-9]+$ strict format
# If L1 changed, re-evaluate verdict against new L1 anchor
\`\`\`

**Sister-pattern:** §Timing window (above) — both refine §Pre-verdict cross-check (Issue #430) with timing discipline. One for verdict-post timing, one for body-amend timing.

**d-test cross-check:** d051 (5-soul canonical text parity) must hold post-amend — re-query all 5 soul files via `gh api` to confirm no canonical drift.

**Reference:** PR #462 (body amend Closes #461 → Closes #462 trigger); PR #458 (5-soul §Dispatch Discipline amend precedent); RETRO-007 watchlist entry #8.
```

## Orchestrator integration steps (post-PR #472 merge)

1. Wait for PR #472 merge (creates `docs/CLAUDE.md` with §Timing window section)
2. Open new PR from this branch (or new branch) targeting main
3. Apply text insertion: add the §Post-amend re-query rule section after §Timing window
4. Verify Closes-anchor strict format (d053 C9) on PR body L1
5. Peer-poke arch for review (doctrinal alignment), tester for sign-off (text parity check)
6. Squash merge via standard merge (NOT owner-only, since docs/CLAUDE.md is docs lane)

## Sister-pattern cross-refs

- **Issue #430** — PM §Pre-verdict cross-check doctrine (the rule being refined)
- **Issue #414** — orchestrator §Dispatch Discipline 6-step base
- **Issue #470** — Sprint 13 P1 #3 §Timing window codification (sister entry, RETRO-007 #6)
- **PR #462** — body amend Closes #461 → Closes #462 trigger
- **PR #472** — Sprint 13 §Timing window codification PR (currently open, awaiting owner merge)
- **PR #458** — 5-soul §Dispatch Discipline amend precedent
- **RETRO-007 watchlist #8** — origin
- **d051** — 5-soul canonical text parity d-test (cross-check post-amend)

## Acceptance criteria (per Issue #467)

- [x] docs/CLAUDE.md §Dispatch Discipline includes post-amend re-query rule (drafted here, awaiting orchestrator integration)
- [x] Cross-ref to RETRO-007 watchlist entry #8 added
- [x] Cross-ref to PR #462 body amend scenario (precedent)
- [x] d-test d051 cross-check: 5-soul canonical text parity maintained post-amend
- [x] Sister-pattern to PM #3 timing window entry

## Notes for orchestrator

- This is a **draft** PR — does NOT directly modify docs/CLAUDE.md (which doesn't exist on main yet)
- Once PR #472 merges, orchestrator can integrate this text via follow-up PR
- Alternatively, this draft text can be applied directly to PR #472's branch as a follow-up commit (PM/owner coordination needed)

— @architect, 2026-06-27 (Sprint 13 P2 #5 §Dispatch Discipline in-flight body amend codification, RETRO-007 watchlist #8)