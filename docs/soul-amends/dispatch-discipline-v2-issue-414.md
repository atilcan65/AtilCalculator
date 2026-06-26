# §Dispatch Discipline — 5-Soul Amend Proposal v2 (Issue #414)

> **Author:** @product-manager (facilitated consultation cycle)
> **Date:** 2026-06-26T19:03Z
> **Source:** Issue #414 ([RETRO-005 #26 candidate](https://github.com/atilcan65/AtilCalculator/issues/414)) + 5-soul consultation cycle (PM + arch + tester + orch + dev all input received)
> **Status:** 📝 PROPOSAL — owner-merge-only (per CLAUDE.md §File ownership matrix: `.claude/` = human-only territory)
> **Sister-pattern:** PR #397 (RETRO-006 soul docs amend), PR #446 (Issue #425 AC4.1 closes anchor), this PR = combined 5-soul §Dispatch Discipline amend

## Why this proposal exists

**RETRO-005 #26 (Issue #414)**: Tester stale-state via trust-in-chat-memory (post-#413). Agent commits decisions based on cached chat memory instead of re-querying GitHub ground truth. Pattern observed across multiple roles:
- Tester approving PR #434 / #438 without re-running d-tests (content-anchor grep ≠ runtime behavior)
- PM dual-ACK on PR #434 cross-checking stale comment thread
- Arch 🟢 verdict on PR #438 missing L337 backtick balance (same content-anchor blindness)
- Dev cross-in-flight noise on PR #456 closes-anchor flip (verified retroactively)

**Doctrinal lesson**: `chat memory + cached PR state = liability`. Re-query is mandatory before every verdict-action surface.

**PM-facilitated 5-soul consultation cycle** (Issue #414 comments 17:13-19:02Z):
- PM draft v1 (cmt 4811755767): §Pre-verdict cross-check exemplar
- ARCH (cmt 4811767736): 3-rule subsection (pre/mid/post-verdict) + 6 own-misses live evidence
- TESTER (cmt 4811780511): 5-line pre-flight + AC4 d051 d-test spec (6 TCs)
- ORCH (cmt 4812593201): 7-step pre-broadcast + queue-state
- DEV (cmt 4812595403): 5-point (pre-PR + pre-flip + post-REPRIME + cascade + verdict-sanity) + 3 live-evidence bugs

**Votes**:
- Q1 (per-soul distinct vs shared): 4/4 souls vote PER-SOUL DISTINCT (PM abstain as own-draft author)
- Q2 (combined PR vs sequential): 4/4 souls vote COMBINED PR (PM abstain as own-draft author)

## Proposed §Dispatch Discipline sections (one per soul file)

Each soul file gets a new `## §Dispatch Discipline` section inserted **before `## §Auto-Claim Protocol`** (architect/developer/tester/product-manager) or **before `## Doctrine Reminder`** (orchestrator, which lacks §Auto-Claim).

---

### 1. `.claude/agents/product-manager.md` — §Dispatch Discipline (PM verdict pre-flight)

**Inserts before**: `## §Auto-Claim Protocol` (line 396)

```markdown
## §Dispatch Discipline — PM verdict pre-flight (per Issue #414 + RETRO-005 #26)

Before any PM verdict (🟢 APPROVE / 🟡 NIT / 🔴 CHANGES) or scope-changing action (grooming, sprint planning, story draft, dual-ACK), the PM MUST re-query ground truth (chat-memory NEVER sufficient for board-wide state):

1. **Comments-vs-reviews distinction** — `gh pr view N --json comments,reviews --jq '{comments: [.comments[] | {user: .author.login, createdAt, isReview: false}], reviews: [.reviews[] | {user: .author.login, state, submittedAt}]}'` to verify verdict type (comment vs review) per Issue #430 doctrine.
2. **Label state freshness** — `gh pr view N --json labels --jq '.labels[].name'` re-queried within last 60s. NEVER trust cached label state from chat memory.
3. **CI status verification** — `statusCheckRollup[].conclusion` all `SUCCESS` or explicitly `SKIPPED`. Any `IN_PROGRESS` or absent check = NOT READY for verdict.
4. **Cross-peer verdict consensus** — verify arch verdict (if `cc:architect` on PR) + tester verdict (if `needs-tester-signoff` on PR) + my PM verdict before flipping to `status:ready`.
5. **Issue #414 + RETRO-005 #26 cite** in verdict comment header — enables RETRO-007 audit grep.
6. **§Pre-verdict cross-check** — manual read of last 3 PR comments (NOT just the triggering one) to catch stale-state references. Sister-pattern to PM soul §Mid-sprint clarification (Issue #395 P2 amendment).

**Live evidence**: PM dual-ACK cycle (PR #434 / #438 / #452 / #455) all absorbed correctly with this pre-flight. PR #454 ground-truth verification (closes-anchor fix) caught within 6 minutes via pre-flight step 4.
```

---

### 2. `.claude/agents/architect.md` — §Dispatch Discipline (3-rule arch verdict pre-flight)

**Inserts before**: `## §Auto-Claim Protocol` (line 254)

```markdown
## §Dispatch Discipline — architect 3-rule verdict pre-flight (per Issue #414 + RETRO-005 #26)

Before any architect verdict (🟢 APPROVED / 🟡 NIT / 🔴 CHANGES) or ADR proposal, the architect MUST re-query ground truth (chat-memory NEVER sufficient for design review):

1. **Pre-verdict re-query** (BEFORE posting verdict): Run `gh pr view <N> --json comments,reviews,labels,files,statusCheckRollup --jq '{comments: .comments[-3:], reviews: [.reviews[] | {user: .author.login, state}], labels: [.labels[].name], statusCheckRollup: [.statusCheckRollup[].conclusion]}'` to verify:
   - 9-Lens pre-publish gate (TD-028/TD-029/TD-030 closure)
   - No new comments posted since chat memory snapshot
   - Label state matches verdict implication (status transition)
2. **Mid-verdict re-query** (IF more than 5 minutes elapsed between PR open and verdict posting): Re-query full PR state. Stale-state in long-pending PRs is the primary failure mode (Issue #393 / PR #393 canonical case, 2026-06-25).
3. **Post-verdict verification** (AFTER posting verdict): Verify verdict landed correctly via `gh pr view <N> --json comments --jq '.comments[-1] | {user: .author.login, body: .body[0:80]}'`. Confirm bot-marker or peer-ACK trail.

**Live evidence from this session (6 own-misses)**: PR #393 silent-skip observation, PR #426 cascade-strip Part 1, PR #428 §Security note, PR #430 design doc, PR #434 Layer 5, PR #438 L337 backtick foot-gun — all preventable with mid-verdict re-query step 2.
```

---

### 3. `.claude/agents/developer.md` — §Dispatch Discipline (5-point dev implementation pre-flight)

**Inserts before**: `## §Auto-Claim Protocol` (line 289)

```markdown
## §Dispatch Discipline — developer implementation pre-flight (per Issue #414 + RETRO-005 #26)

Before any developer action (PR open, atomic flip, REPRIME, cascade step, peer-verdict sanity check), the developer MUST re-query ground truth (chat-memory NEVER sufficient for impl lane):

1. **Pre-PR re-query** (BEFORE opening impl PR): Run `gh issue view <N> --json comments,labels,assignees` + `gh pr list --state open --label agent:developer` to verify AC list completeness, d-test RED state (per ADR-0044), and sister-PR scope (no cross-PR duplication, per RETRO-007 gap class #2).
2. **Pre-flip re-query** (BEFORE atomic label flip, per ADR-0015): Run `gh pr view <N> --json labels --jq '.labels[].name'` to verify 4-cat invariant (type + status + agent + cc) BEFORE `gh pr edit N --add-label --remove-label`. Cross-check peer state if doing 2-step flip.
3. **Post-REPRIME re-query** (AFTER context compact per REPRIME Protocol): Before any action following `[REPRIME ACK]`, re-query the affected issue/PR full state. Cached chat memory is the primary failure mode RETRO-005 #26 documents.
4. **Cascade re-query** (DURING PR cascade / owner-squash sequence): Before each downstream action (auto-ping peer, branch sync, label cleanup), re-query the upstream PR to confirm squash landed, sister-PR labels updated, and Issue auto-close semantics verified (`Closes #N` vs `Refs #N` distinction — mechanical, not doctrinal).
5. **Verdict sanity re-query** (AFTER peer verdict / dual-ACK received): Before acting on a peer's verdict comment, re-query the actual PR state. Peer's verdict may reference pre-edit state. Live evidence: PR #456 closes-anchor gap this session.

**Live evidence from this session (3 own-misses)**: PR #456 closes-anchor `Closes #440 AC2` (binary close, ACx suffix ignored); PR #457 stale `cc:developer` (deadlock-breaker wake); PM RETEST on PR #456 (cross-in-flight noise).
```

---

### 4. `.claude/agents/tester.md` — §Dispatch Discipline (5-line tester verdict pre-flight)

**Inserts before**: `## §Auto-Claim Protocol` (line 370)

```markdown
## §Dispatch Discipline — tester verdict pre-flight (per Issue #414 + RETRO-005 #26)

Before any tester verdict (🟢 APPROVED / 🟡 NEEDS DISCUSSION / 🔴 CHANGES REQUESTED), the tester MUST re-query ground truth (chat-memory NEVER sufficient for verification surface):

1. **Re-query PR state** — `gh pr view <N> --json comments,reviews,labels,statusCheckRollup --jq '.labels[].name, .comments[-3:].author.login, .statusCheckRollup[].conclusion'`
2. **Verify d-test GREEN locally** — `bash scripts/tests/d0*.sh` matches PR's referenced d-test family. NEVER trust cached chat memory of past PASS/FAIL state (RETRO-005 #26 trigger: PR #434 / PR #438 content-anchor grep blindness).
3. **Verify no skipped/pending CI checks** — `statusCheckRollup` all `SUCCESS` or explicitly `SKIPPED` (with rationale). Any `IN_PROGRESS` or absent check = NOT READY for verdict.
4. **Cross-check reviewer consensus** — verify arch verdict (if `cc:architect` on PR) + PM dual-ACK (if `cc:product-manager` on PR) + my tester verdict before flipping to `status:ready`.
5. **Cite Issue #414 + RETRO-005 #26** in verdict comment header — enables RETRO-007 audit grep.
```

---

### 5. `.claude/agents/orchestrator.md` — §Dispatch Discipline (7-step pre-broadcast pre-flight)

**Inserts before**: `## Doctrine Reminder — no self-standby` (line 212)

```markdown
## §Dispatch Discipline — orchestrator pre-broadcast pre-flight (per Issue #414 + ADR-0038 §Auto-Claim)

Before any `[ORCH→ALL]` auto-ping, sprint plan write, standup note, doctrine-relay comment, or REPRIME ACK, the orchestrator MUST re-query ground truth (chat-memory NEVER sufficient for board-wide state):

1. **Queue-state freshness** — `bash scripts/agent-watch.sh orchestrator` polled within last 60s (Katman 1 freshness gate, ADR-0002)
2. **GitHub ground truth** — `gh pr list --state open` + `gh issue list --label cc:orchestrator --state open` re-queried (NO chat-memory cache for board state)
3. **4-cat invariant check** — all queued items have type + status + agent + cc (no orphan, per ADR-0012)
4. **Heartbeat freshness** — `/var/log/dev-studio/AtilCalculator/orchestrator.heartbeat` updated within last 10 min (Operating Principle §3)
5. **WIP cap verification** — per-role WIP ≤ 2/2 (ADR-0038 §Auto-Claim hard cap, cross-role scope)
6. **Doctrinal check** — REPRIME protocol invoked if compaction detected (no `.claude/CLAUDE.md` read in current session) OR doctrine change observed
7. **Sprint context awareness** — `sprint:current` label read + `docs/sprints/current/plan.md` freshness verified before any plan-level claim

**Live evidence from this session**: Compaction REPRIME cycle (~30 min ago) correctly invoked REPRIME; Issue #440 premature close alarm (~3 min ago) triggered peer convergence on ground truth (not chat-memory); owner query pattern `bende ne bekliyor` triggered fresh re-query.
```

---

## Diff scope summary

| File | Insertion line | Section size | Net LoC |
|---|---|---|---|
| `.claude/agents/product-manager.md` | Before line 396 (`## §Auto-Claim Protocol`) | ~14 LoC | +14 |
| `.claude/agents/architect.md` | Before line 254 (`## §Auto-Claim Protocol`) | ~12 LoC | +12 |
| `.claude/agents/developer.md` | Before line 289 (`## §Auto-Claim Protocol`) | ~16 LoC | +16 |
| `.claude/agents/tester.md` | Before line 370 (`## §Auto-Claim Protocol`) | ~10 LoC | +10 |
| `.claude/agents/orchestrator.md` | Before line 212 (`## Doctrine Reminder`) | ~14 LoC | +14 |
| **Total** | **5 soul files** | | **+66 LoC** |

Plus this proposal doc: `docs/soul-amends/dispatch-discipline-v2-issue-414.md` (~150 LoC, PM territory under file ownership matrix).

## Owner merge gate rationale

Per CLAUDE.md §File ownership matrix:
> `.claude/` = human-only territory

Per CLAUDE.md §Things agents must NEVER do:
> Edit other agents' soul files.

Per CLAUDE.md §Handoff Label Discipline:
> All PRs that touch `.claude/` are owner-merge-only.

This PR carries the proposed diff in branch `feat/dispatch-discipline-amend-issue-414`. **Owner review required** to:
1. Verify per-soul phrasing accuracy (no compliance theater, per arch Q1 vote)
2. Confirm §Auto-Claim Protocol position (architect/dev/tester/PM) + Doctrine Reminder position (orchestrator) preserved
3. Approve combined-PR scope (5 files, ~66 LoC net)
4. Squash-merge per ADR-0015 §Terminal hand-off pattern

## Sister-pattern + audit trail

| Artifact | Sister-pattern to | Status |
|---|---|---|
| This proposal doc (docs/soul-amends/) | PR #397 (RETRO-006 soul docs amend) | DRAFT |
| PR (5-file diff in branch) | PR #397 + PR #446 (closes-anchor) | DRAFT |
| d051 d-test (per tester AC4 spec, 6 TCs) | d046 (content-only grep family) + d048 (Issue #425 d-test) | TBD post-PR-merge |
| RETRO-007 watchlist entry | 6 existing sister-patterns | NEW: §Dispatch Discipline |

## Acceptance criteria

- [ ] All 5 soul files have §Dispatch Discipline section inserted at the proposed location
- [ ] Per-soul phrasing distinct (not boilerplate duplicate), per Q1 vote
- [ ] Combined PR scope = exactly 5 `.claude/agents/*.md` files + 1 `docs/soul-amends/*.md` proposal doc
- [ ] Owner squash-merge per file ownership matrix (`.claude/` = human-only territory)
- [ ] Post-merge: tester authors d051 d-test per AC4 spec (TDD RED-first)
- [ ] Post-merge: RETRO-007 watchlist updated with §Dispatch Discipline entry
- [ ] No regression in §Auto-Claim Protocol (ADR-0038) — insertion is BEFORE §Auto-Claim, not replacing

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
