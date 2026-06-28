# Post-Squash Cleanup Runbook — Sprint 18 P0 cluster

> **Trigger**: Owner squashes Sprint 18 P0 cluster bundle (PR #614 + #615 + #616) — or rate-limit reset → gh pr ready → owner squash
> **Author**: @orchestrator (pre-staged @ 2026-06-28T21:28+03:00)
> **Cluster**: Sprint 18 P0 cluster close — Issue #604 (via PR #615 Closes anchor) + Issue #605 (via PR #616 Closes anchor) auto-close; Issue #607 needs **manual close** (PR #614 uses Refs not Closes)

## Pre-state (verified 2026-06-28T21:28+03:00)

| Item | State | Labels (4-cat) | Squash anchor |
|---|---|---|---|
| PR #614 | isDraft=TRUE, dual-🟢 (tester+arch) | type:feature + status:ready + agent:developer + cc:human + cc:product-manager | `Refs #607` (manual close required) |
| PR #615 | isDraft=TRUE, dual-🟢 (tester+arch-self) | type:docs + status:ready + agent:architect + cc:human | `Closes #604` (auto-close) |
| PR #616 | isDraft=TRUE, dual-🟢 (tester+arch) | type:feature + status:ready + agent:developer + cc:human | `Closes #605` (auto-close) |
| Issue #604 | open | type:feature + status:in-review + agent:architect + cc:* | closes via PR #615 |
| Issue #605 | open | type:feature + status:in-progress + agent:developer + cc:* | closes via PR #616 |
| Issue #607 | open | type:feature + status:in-progress + agent:developer + cc:* | **MANUAL close required** (PR #614 uses Refs not Closes) |

> **Sister-pattern to Sprint 17 P1 cluster**: PR #597 (squashed @ 1d04ccc) + PR #598 (squashed @ bf1e237) + PR #601 (squashed @ d8739d6) — same squash-pending pattern, same terminal cleanup cadence.

## Cleanup actions (post-squash, single sweep)

### Step 1 — Squash event hook (per PR)

```bash
# Watch for squash events via REST polling (since GraphQL rate-limited):
for pr in 614 615 616; do
  curl -s "https://api.github.com/repos/atilcan65/AtilCalculator/pulls/$pr" | \
    python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'PR #\$pr merged={d.get(\"merged\")} merge_commit_sha={d.get(\"merge_commit_sha\")}')
"
done
# Trigger: merged == true AND merge_commit_sha is set
```

### Step 2 — Issue #604 + #605 terminal cleanup (auto-close anchors)

GitHub auto-closes via `Closes #NNN` anchors in PR bodies.

```bash
# Verify auto-close
for issue in 604 605; do
  curl -s -H "Authorization: token $(gh auth token)" \
    "https://api.github.com/repos/atilcan65/AtilCalculator/issues/$issue" | \
    python3 -c "import json, sys; print(f'Issue #$issue state: {json.load(sys.stdin)[\"state\"]}')"
done
# Expected: both "closed"

# Then flip labels to terminal Done state
for issue in 604 605; do
  gh issue edit $issue \
    --remove-label "agent:architect" --remove-label "agent:developer" \
    --remove-label "cc:product-manager" --remove-label "cc:developer" \
    --remove-label "cc:tester" --remove-label "cc:human" --remove-label "cc:architect" \
    --add-label "status:done"
done
```

### Step 3 — Issue #607 MANUAL close (Refs anchor pattern) — DEV LANE OWNERS

> **Owner correction (2026-06-28T21:39+03:00):** Per file ownership matrix, `scripts/tests/d065-dual-channel-enforcement.sh` = dev lane territory → Issue #607 (STORY-S18-004) closure belongs to **dev lane**, NOT orchestrator. Pre-staged comment transferred to dev lane at `/tmp/issue-607-close-comment.md`.

PR #614 uses `Refs #607` (not `Closes #607`) per dev lane discipline (d-tests ref the story, don't close it). Manual close required with comment — **executed by dev lane**:

```bash
# Verify d065 GREEN on main post-merge (dev lane)
bash scripts/tests/d065-dual-channel-enforcement.sh
# Expected: 5/5 TCs GREEN

# Manual close Issue #607 with explanation comment (dev lane)
gh issue close 607 --comment "$(cat /tmp/issue-607-close-comment.md)"
```

Then flip labels to terminal Done state (dev lane):

```bash
gh issue edit 607 \
  --remove-label "agent:developer" \
  --remove-label "cc:product-manager" --remove-label "cc:architect" \
  --remove-label "cc:tester" --remove-label "cc:human" \
  --add-label "status:done"
```

**Pre-staged asset (already on disk, dev lane owns):** `/tmp/issue-607-close-comment.md` (661 bytes, generated @ 2026-06-28T21:39+03:00).

### Step 4 — Sister-pattern squash bundle (5 PRs total, including orchestrator lane)

After #614/#615/#616 squash, the broader bundle also includes:

| PR | Lane | Anchor | Cleanup mode |
|---|---|---|---|
| #612 | orchestrator (me) | Closes #608 | auto-close + label flip |
| #613 | PM curator | (PM tracker) | per #602 kickoff issue |

These are independent of the dev P0 cluster squash — separate squash actions by owner.

### Step 5 — Dev lane auto-claim cycle (dev lane owns)

> **Owner clarification:** After #607 close (Step 3, dev lane), dev lane WIP slot releases. Auto-claim cycle picks up next #609/#610/#611 (P1#6/#7/#8, all status:ready):

- **#609** STORY-S18-006 WIP cap script miscounts fix (scripts/wip-cap-check.sh status filter)
- **#610** STORY-S18-007 Proactive-scan wip_overflow false positive fix (AT-CAP vs OVERFLOW semantics)
- **#611** STORY-S18-008 d064 CI workflow integration (cluster-lag d-test CI gate)

Dev lane expected to claim #609 first per sprint priority order (P1#6 before P1#7/#8). Orchestrator monitors + verifies, does NOT claim.

## Cross-refs

- **PR #614** — d065 dual-channel-enforcement regression guard
- **PR #615** — ADR-0060 §AC mapping verification doctrine (closes #604)
- **PR #616** — cluster-lag-detector YAML wiring + d068 d-test (closes #605)
- **Issue #604** — STORY-S18-001 §AC mapping verification (P0#1, closes via PR #615)
- **Issue #605** — STORY-S18-002 cluster-lag YAML wiring (P0#2, closes via PR #616)
- **Issue #607** — STORY-S18-004 d065 dual-channel-enforcement d-test (P1#4, manual close via this runbook)
- **ADR-0060** — §AC mapping verification doctrine (Sprint 18 codification lineage)
- **ADR-0024** — verdict-by:<ts> convention
- **RETRO-012 §4a** — verdict-by codification origin
- **ADR-0031** — Owner override (sprint scope + squash gate)
- **ADR-0044** — verdict-by SLA scope (TDD RED exclusion)
- **docs/sprints/sprint-17/post-squash-cleanup.md** — sister-pattern reference

— @orchestrator, 2026-06-28T21:28+03:00, Sprint 18 P0 cluster post-squash cleanup runbook (pre-staged, awaiting owner squash click)
