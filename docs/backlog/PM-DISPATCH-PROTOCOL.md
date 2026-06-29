# PM Dispatch Protocol — lane-discipline reference

> **Origin**: RETRO-016 candidate #6 (PM-side pre-dispatch lint, cycle ~#1233 PM post-mortem on Issue #690)
> **PM owner**: @product-manager (docs/backlog/ = PM lane per file ownership matrix)
> **Cycle**: 2026-06-29 (Sprint 21 Day 1-2 post-mortem)
> **Codification**: Sprint 14+ candidate (current status: PM-authored reference doc; ADR/PR cycle for codification pending)

## §Context — why this doc exists

Cycle ~#1228 PM Wave 2 promotion (S21-003a/b/004/005/006/007 to `status:ready`) set `agent:tester` on 5 impl stories. This was a **lane-discipline violation** per ADR-0044 RED-first TDD:

- **Impl stories** = `agent:developer` (dev lane, with `cc:tester` for d-test contract review)
- **d-test PRs** = `agent:tester` (tester lane, separate work unit)
- **d-test-coupled stories** (e.g., S21-003b d070-coupled) = `agent:tester` (tester-led, narrow scope)

Dev flagged cycle ~#1226 (cmt 4835170395 on Issue #690). PM MISSED 5 cycles. Orchestrator resolved via board-hygiene action cycle ~#1249 (5th flag).

**Lesson**: PM's Wave promotion checklist must verify lane discipline BEFORE `status:backlog → status:ready` flip. Otherwise wrong-lane auto-claim fires (ADR-0038), and downstream agents do work they shouldn't.

## §The 5-step Wave Promotion Checklist

Before flipping ANY story from `status:backlog → status:ready`:

- [ ] **(1) Lane discipline check** — Is this an impl story or a d-test-coupled story?
  - **Impl story** (default): `agent:developer` + `cc:tester` (d-test contract review)
  - **d-test-coupled story** (rare): `agent:tester` + `cc:developer` (impl handoff after d-test GREEN)
  - Detection: `gh issue view $issue --jq '.body' | grep -i "d-test-coupled"` — if match, use d-test-coupled lane

- [ ] **(2) Sizing ratified** — 4-of-4 stamps per ADR-0021 (PM, arch, dev, tester) + owner ratification on Issue #685 (Sprint 21 Joint Sizing). Hint size in story header matches Issue #685 ratification comment.

- [ ] **(3) Sister-pattern check** — Is the d-test PR separate from impl PR?
  - Per ADR-0044 RED-first: d-test PR authored by tester FIRST (RED on main), then impl PR by dev (GREEN)
  - PM must NOT pre-bundle d-test authorship with story ownership

- [ ] **(4) Dependencies mapped** — Upstream + Downstream explicit in story body. Sprint 21 cadence: Wave N dispatch must reference Wave N-1 dependency completion (e.g., S21-005 depends on S21-001 template flag landing).

- [ ] **(5) Lane-appropriate cc set** — cc:human (owner merge gate) ALWAYS. Plus role-specific cc:
  - impl story: `cc:tester` (d-test contract) + `cc:architect` (9-Lens per ADR-0045) + `cc:developer` (impl lane)
  - d-test-coupled story: `cc:developer` (impl handoff) + `cc:architect` (9-Lens) + `cc:product-manager` (PM observation)

If any checkbox fails: **DO NOT flip status**. Resolve first, then flip.

## §Dual-Listing Rule

When in doubt, prefer **dual-listing** (impl + d-test as separate labels/work units):

| Story type | agent | cc | Why |
|---|---|---|---|
| Pure impl story | `agent:developer` | `cc:tester`, `cc:architect` | Dev owns impl; tester reviews d-test contract |
| d-test-coupled (small) | `agent:tester` | `cc:developer`, `cc:architect` | Tester owns d-test authoring; dev hands off impl |
| Pure docs story | `agent:product-manager` | `cc:developer`, `cc:architect` | PM owns doc; dev reviews step accuracy |
| Sprint ceremony story | `agent:orchestrator` | `cc:all` | Orchestrator owns ceremony; all agents notify |

**Default to `agent:developer` for impl stories.** Only use `agent:tester` when story body explicitly states "d-test-coupled" (e.g., d070b coverage).

## §Pre-Dispatch Lint (Sprint 14+ codification)

Codification candidate from RETRO-016 #6 (PM-side pre-dispatch lint):

```bash
# Pre-flight check before PM Wave promotion (status:backlog → status:ready)
for issue in $(gh issue list --label status:ready --json number --jq '.[].number'); do
  agent=$(gh api repos/atilcan65/AtilCalculator/issues/$issue \
    --jq '.labels[].name | select(startswith("agent:"))[0]')
  body=$(gh api repos/atilcan65/AtilCalculator/issues/$issue --jq '.body')
  
  if [[ "$agent" == "agent:tester" ]] && ! echo "$body" | grep -qi "d-test-coupled"; then
    echo "⚠️  PM LINT FAIL: Issue #$issue has agent:tester but is NOT d-test-coupled"
    echo "    → Flip to agent:developer BEFORE Wave promotion"
  fi
done
```

Sister-pattern: RETRO-007 watchlist entry #6 (PM AC-VERIFY timing) + RETRO-016 candidates #1-5 (defense-in-depth doctrine).

## §Auto-Claim Compatibility

Per ADR-0038 auto-claim protocol: tester/dev auto-claim stories labeled `agent:<their-role> AND status:ready`.

**Failure mode**: PM sets `agent:tester` on impl story → tester auto-claims → tester writes d-test PR (correct lane) but story ownership is wrong → dev doesn't know it's their impl story → impl PR never authored → d-test PR stays RED forever.

**Prevention**: Pre-dispatch lint above. Verify lane BEFORE flipping `status:ready`.

## §PM ACK Discipline

PM ACKs on d-test PRs (tester lane) are ✅ OK — that's PM observation lane per "PM cc'd on docs/backlog/souls PRs" sister-pattern.

PM ACKs on impl PRs (dev lane) are ✅ OK when scoped to AC verification per Issue #430 §Pre-verdict cross-check.

PM ACKs **confirming tester auto-claim on impl stories** are ✗ WRONG — must verify lane discipline FIRST. Cycle ~#1232 PM cycle ~#1226 dev flag missed this.

## §Cross-references

- **Issue #690** — Wave 2 dispatch (5th flag cycle ~#1249, PM post-mortem cmt 4835213200)
- **Issue #685** — Sprint 21 Joint Sizing (decision E Wave 5 deferral)
- **ADR-0012** — 4-cat invariant
- **ADR-0038** — Auto-claim protocol (WIP cap + auto-claim gate)
- **ADR-0044** — RED-first TDD (d-test PR separate from impl PR)
- **ADR-0045** — 9-Lens (architect review)
- **ADR-0059** — Cluster-squash (d-test + impl + squash cadence)
- **Issue #113** — PM label-authority (PM naming + label ground-truth)
- **Issue #238** — §No-self-standby (Katman 1 = take OTHER queue items)
- **Issue #430** — §Pre-verdict cross-check
- **Issue #682** — §Post-verdict cross-watchdog (PR #692 codification)
- **Issue #414** — §Pre-flip (PM atomic-flips cluster dispatch to dev BEFORE dev claim)
- **RETRO-007 watchlist entry #6** — PM AC-VERIFY timing (sister-pattern)
- **RETRO-016 candidates #1-5** — defense-in-depth doctrine
- **RETRO-016 candidate #6** — THIS doc (PM-side pre-dispatch lint Sprint 14+)
- **§PM lane LOCKED Sprint 13+** — docs/sprints/souls cc patterns (PM-lane-appropriate scope)

## §Sprint 14+ Action Items

1. **Codify pre-dispatch lint** as ADR (architect-owned, PM co-author): "PM Wave Promotion Pre-Dispatch Lint (RETRO-016 #6)"
2. **Update `.claude/agents/product-manager.md`** §Backlog grooming workflow with the 5-step checklist (human-only territory, owner merges)
3. **Add `scripts/lint-pm-dispatch.sh`** — automated lint with 4 TCs:
   - TC1: All `status:ready` impl stories have `agent:developer`
   - TC2: All `agent:tester` stories have `d-test-coupled` body marker OR are d-test PRs
   - TC3: All `status:ready` stories have `cc:human` (owner squash gate)
   - TC4: Sister-pattern check (d-test PR separate from impl PR for impl stories)
4. **Sprint 14 ceremony** — add §PM dispatch protocol review to sprint planning

## §Versioning

- v0.1 — 2026-06-29 cycle ~#1233 — PM initial authoring (this version)
- v0.2 — pending — codification PR + ADR + d-test framework integration

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)