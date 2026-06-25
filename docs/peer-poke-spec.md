# Peer-Poke Discipline Spec — Dual-Channel Auto-Ping Contract

> **Status:** Canonical (PR for review, owner-gated merge)
> **Date:** 2026-06-25
> **Authored by:** @orchestrator (per Issue #389 §Why owner-only + PM Gap 1 fix recommendation)
> **Owner-gated:** @human (per file ownership matrix — .claude/ + docs/ root cross-listed)
> **Related:** [ADR-0033](./decisions/ADR-0033-auto-ping-dual-channel.md) (dual-channel doctrine), [Issue #296](https://github.com/atilcan65/AtilCalculator/issues/296) (parent, auto-closed by PR #383), [Issue #389](https://github.com/atilcan65/AtilCalculator/issues/389) (this spec's tracker), [PR #383](https://github.com/atilcan65/AtilCalculator/pull/383) (scripts/peer-poke.sh MERGED), [CLAUDE.md §Auto-Ping Hard-Rule](../.claude/CLAUDE.md)

---

## Preamble — Sprint 1-line context

This spec complements `CLAUDE.md §Handoff Label Discipline` (ADR-0015) by formalizing the **notification discipline** (how peers are woken) that pairs with the **handoff discipline** (how queue/owner/cc labels are flipped). The two doctrines are orthogonal: handoff discipline governs GitHub label state, peer-poke discipline governs agent tmux wake. Issue #395 (PM-OK cross-check doctrine) is a third, verdict-discipline axis — also orthogonal. All three ship Sprint 8.

---

## Deliverable 1 — scripts/peer-poke.sh helper (SHIPPED via PR #383)

The script is already on `main` (commit `4725122`, merged 2026-06-25T18:03:04Z). This deliverable records the interface for cross-reference.

### Interface

```bash
scripts/peer-poke.sh <role> "<message>"
# Wraps: notify.sh -l info -w -r <role> <message>
# Refuses to call without -w (the whole point of this script).
```

### Doctrinal contract

| Behavior | Expectation |
|---|---|
| Success | Telegram post (human mirror) + tmux pane wake (peer agent), both within 5s |
| Missing args | Exit 2 + usage to stderr |
| `-w` without `-r` | Exit 2 (notify.sh rejects, no silent channel-skew) |
| tmux unavailable / role unknown / pane not found | Silent no-op, exit 0 |

### Doctrinal test (d296-peer-poke-helper.sh, 3 TCs)

- T1: argv capture — `peer-poke.sh <role> "<msg>"` → `notify.sh -l info -w -r <role> "<msg>"`
- T2: missing args → exit 2 + usage to stderr
- T3: `bash -n` syntactically valid

### Sister script

`scripts/ping.sh` — identical wrapper semantics, slightly different argument-handling edges. See `d038 vs d296` d-tests for the contract diff.

---

## Deliverable 2 — 5-soul §Peer-Poke Discipline amendment (owner-only territory, 15 LoC per soul)

Per `CLAUDE.md §File ownership matrix`, `.claude/agents/*.md` is **human-only territory**. Orchestrator drafts text below; owner applies via git (per Issue #389 §Why owner-only). Dev writes the diff (Stage 1 of owner directive 4-stage workflow); tester verifies no regression (Stage 2); owner runs final merge (Stage 3).

### Canonical §Peer-Poke Discipline text (paste into each soul)

```markdown
## §Peer-Poke Discipline — Dual-Channel Auto-Ping

Per **ADR-0033** (dual-channel doctrine), waking a peer agent from tmux context
requires BOTH (a) a Telegram message AND (b) a tmux pane wake. Telegram-only
(the legacy `notify.sh -l <role>` form) is broken — peer tmux panes never wake.

**Always use `scripts/peer-poke.sh <role> "<msg>"`** — it bakes the correct
invocation shape (`-l info -w -r <role>`) into a single helper, so the wrong
form is unreachable through this entry point.

**Allowed pattern** (1:1 handoff):
  `scripts/peer-poke.sh <peer-role> "[<YOU>→<PEER>] <≤80 char reason>"`
  followed by ≤2 lines of context (PR/Issue link + body).

**Forbidden pattern** (legacy Telegram-only):
  `scripts/notify.sh -l <role> "<msg>"` ← peer tmux never wakes, footgun.

**Multi-role broadcasts** (e.g., `[ORCH→ALL] sprint kickoff`) are NOT covered
by `peer-poke.sh` — single-role only. Defer to Sprint 8+ P3 (multi-role helper).
```

### Per-soul context line (insert immediately after the canonical block above)

Per PM verdict (cmt 4803630200) + architect endorsement (cmt 4803639733), the context lines below are the **canonical text** (exact, no paraphrase):

| Soul file | Context line (paste after canonical block) |
|---|---|
| `.claude/agents/orchestrator.md` | "Default to `peer-poke.sh` for all 1:1 peer handoffs. Multi-role broadcasts remain manual (loop over roles) until §Peer-Poke Discipline v2 adds broadcast helper." |
| `.claude/agents/product-manager.md` | "You ping @architect for design alignment and @orchestrator for scope/sprint decisions. Most PM-to-peer routing is label-driven (cc:* per Handoff Label Discipline). `peer-poke.sh` is for explicit one-shots: verdict requests, scope clarifications, RETRO-005 lead prompts, mid-sprint cross-check doctrine gates (#395)." |
| `.claude/agents/architect.md` | "You ping @developer after PR design review (🟢 verdict) and @orchestrator for sprint-architect input. Dual-channel mandatory via `peer-poke.sh`." |
| `.claude/agents/developer.md` | "You ping @tester when opening PR (`status:in-review` + `cc:tester` + `needs-tester-signoff`) and @architect on schema changes. Dual-channel via `peer-poke.sh`." |
| `.claude/agents/tester.md` | "You ping @developer on CHANGES REQUESTED, @architect on doctrinal gaps, @orchestrator on P0/P1 incidents. Dual-channel via `peer-poke.sh`." |

### Preamble (insert before canonical block, per PM Gap 4 + arch endorsement)

```
§Peer-Poke Discipline complements (does NOT replace) Handoff Label Discipline (ADR-0015).
Use peer-poke.sh for 1:1 peer notification; use cc:* labels for ownership transfer.
```

### Insertion order (per soul, top to bottom)

```
1. Preamble        (above — distinguishes notification discipline from ownership transfer)
2. Canonical block (above — the shared §Peer-Poke Discipline text)
3. Per-soul context line (from table below — distinct per role)
```

Owner applies in this exact order in each of the 5 soul files.

### Wording-fix notes (PM verdict, Issue #389 cmt 4803630200)

- **PM context line**: replaced original "sizing review PM-led" with PM suggested rewrite — sizing is joint arch+dev+tester, PM coordinates via labels not peer-poke.
- **Orchestrator context line**: scope-narrowed to 1:1 (PM Gap 3 Option 1). Multi-role broadcast helper deferred Sprint 8+ P3.
- **Preamble** (PM Gap 4): added explicit "complements, does NOT replace" framing to prevent future soul readers from conflating notification discipline with ownership transfer discipline.

### Architect pre-conditions (verdict cmt 4803639733) — all met

1. Cite ADR-0033 explicitly ✅ (preamble references ADR-0033)
2. Distinguish peer-poke (notification) from Handoff Label Discipline (ownership transfer) ✅ (PM Gap 4 preamble)
3. Reference `peer-poke.sh` as canonical helper ✅ (canonical block, no `notify.sh -l` mention)
4. Scope-narrow per PM Gaps 2-3 ✅ (context lines above)
5. Per-soul context line matches Issue #389 §What table + PM verdict ✅

### 4-cat label contract on the 5 soul PRs (arch Obs-1, M-severity)

Per ADR-0012 4-cat invariant + file ownership matrix (`.claude/agents/*.md` = human-only), each of the 5 PRs should carry:

```
type:docs + status:in-review + agent:architect + cc:human
```

Rationale: docs-only (no behavior change), pre-merge status, architect-adjacent doctrine (PR #383 architect-owned spec), owner merge gate per file matrix.

### Cross-soul canonical parity guard (arch Obs-2, L-severity)

All 5 souls must reference the SAME canonical §Peer-Poke Discipline text + a DISTINCT per-soul context line. Owner opens 5 PRs from a single branch with single base commit (atomic discipline) OR add d046-peer-poke-canonical-parity.sh d-test.

### Acceptance criteria

- [ ] All 5 soul files have canonical §Peer-Poke Discipline text (from §Deliverable 2 above)
- [ ] Per-soul context line inserted (table above)
- [ ] All 5 PRs merged to main (each `Closes #389`)
- [ ] No regression: 5-soul canonical text does not conflict with existing soul sections
- [ ] Sprint 8 onboarding test: new agent reads soul, applies canonical pattern (self-verification)

---

## Doctrinal context — why this spec exists

### Gap analysis (Issue #296 §Problem)

**Without `scripts/peer-poke.sh` + 5-soul amendment**, new agent sessions reading their soul file still see the **legacy pattern** (`notify.sh -l <role>` Telegram-only) in §Peer-Poke Discipline examples. Footgun stays open for the next onboarding.

**Five agent soul files used to show the legacy form** in their §Peer-Poke Discipline examples, so new agents learned the wrong pattern. PR #383 ships the script portal (correct invocation shape baked in); this spec's Deliverable 2 ships the example-onboard portal (canonical soul text + per-soul context line).

### Pattern family cross-refs

- **Issue #296** (parent, auto-closed by PR #383) — script portion DONE; soul amendment tracked here
- **Issue #389** — 5-soul §Peer-Poke Discipline amendment owner-gated (this spec's tracker)
- **Issue #320** (notify.sh -l <role> footgun RCA) — root cause observation
- **ADR-0033** — dual-channel doctrine (canonical anchor)
- **CLAUDE.md §Auto-Ping Hard-Rule** — operating principle

### Anti-patterns (do not do)

- ❌ `scripts/notify.sh -l <role> "<msg>"` (legacy Telegram-only, peer tmux never wakes)
- ❌ `scripts/peer-poke.sh` for multi-role broadcasts (single-role only, defer Sprint 8+ P3)
- ❌ Direct tmux send-keys (bypasses notify.sh + Telegram mirror)

---

— Orchestrator spec draft @ 2026-06-25T19:56+03:00, Sprint 8 Stage 0 (PM Gap 1 fix per Issue #389 cmt 4803630200)