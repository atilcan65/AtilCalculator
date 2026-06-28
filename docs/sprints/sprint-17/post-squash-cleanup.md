# Post-Squash Cleanup Runbook — PR #597 squash landing

> **Trigger**: Owner squashes PR #597 (or rate-limit reset → gh pr ready → owner squash)
> **Author**: @orchestrator (pre-staged @ 2026-06-28T17:32+03:00)
> **Cluster**: Sprint 17 P1 cluster close — Issue #584 closes via Closes anchor on PR #597

## Pre-state (verified 2026-06-28T17:32+03:00)

| Item | State | Labels (4-cat) |
|---|---|---|
| PR #597 | isDraft=TRUE, dual-🟢 | type:feature + status:ready + agent:developer + cc:orchestrator + cc:human |
| Issue #584 | open | type:feature + status:in-progress + agent:architect + **agent:developer** + cc:orchestrator + cc:tester + cc:human |
| Issue #587 | open | type:feature + status:in-progress + agent:developer + cc:human |

> **Note on Issue #584 double `agent:*`**: pre-existing state from arch + dev dual-lane contribution period. Cleanup is terminal (post-squash).

## Cleanup actions (post-squash, single sweep)

### Step 1 — PR #597 squash event hook

```bash
# Watch for squash event via REST polling (since GraphQL rate-limited):
# curl -s https://api.github.com/repos/atilcan65/AtilCalculator/pulls/597 | jq '.merged, .merge_commit_sha'
# Trigger: merged == true AND merge_commit_sha is set
```

### Step 2 — Issue #584 terminal cleanup (anchor auto-closes)

GitHub auto-closes via `Closes #584` anchor in PR body. Verify:

```bash
curl -s -H "Authorization: token $(gh auth token)" \
  https://api.github.com/repos/atilcan65/AtilCalculator/issues/584 | jq '.state'
# Expected: "closed"
```

Then flip labels to terminal Done state:

```bash
gh issue edit 584 \
  --remove-label "agent:architect" \
  --remove-label "agent:developer" \
  --remove-label "cc:orchestrator" \
  --remove-label "cc:tester" \
  --remove-label "cc:human" \
  --add-label "status:done"
```

### Step 3 — Issue #587 terminal cleanup

Issue #587 (STORY-P1#4 d-test) closes when d064 turns GREEN on main. PR #596 (d-test impl, MERGED @ 13:01:18Z, commit 2fae093) carries d064, so this should have already auto-closed. If not:

```bash
# Verify d064 GREEN on main
bash scripts/tests/d064-cluster-lag.sh

# If green on main but issue still open, investigate:
gh issue view 587 --json state,title

# Manual close if needed (with comment explaining d064 GREEN on main):
gh issue close 587 --comment "d064 cluster-lag d-test GREEN on main via PR #596 (commit 2fae093). Issue closes via Closes anchor deferred — applying manual close since PR #596 body used 'refs' not 'closes' anchor."
```

### Step 4 — Sprint 17 P1 cluster close-out ledger update

Append to `docs/sprints/sprint-17/close.md` (PM lane, owner ratifies):

```markdown
### PR #597 (squash-pending, dual-🟢)
- Title: feat(post-squash): STORY-P1#1 cluster-squash batch-lag detection impl (closes #584)
- Squash SHA: <filled at squash time>
- Closes: #584, #587 (cascade via d064 GREEN on main)
- Arch 🟢 cmt: 4826384857
- Tester 🟢 cmt: 4826367793
- Arch lane: final 9-Lens alignment check ✅
- Tester lane: d064 d-test alignment (F2 TC4 amend + F3 TC6 added) ✅
- Owner squash click @ <timestamp>
```

### Step 5 — Board sync + final ping

> **NOTE**: `scripts/peer-poke.sh` only exists on main branch (added via PR #4695a15 in Sprint 13). On feature branches, use `scripts/notify.sh -l info -w -r <role>` directly. Both forms are ADR-0033 dual-channel compliant.

```bash
# Auto-ping to PM (retro ceremony prep) — use scripts/notify.sh (universal) or scripts/peer-poke.sh (main-only):
scripts/notify.sh -l info -w -r product-manager "[ORCH→PM] PR #597 SQUASHED ✅, cluster 7/7 + #584 + #587 closed. Sprint 17 P1 cluster DONE. RETRO-012 ready to codify."

# Auto-ping to arch + dev + tester (cluster close ACK):
scripts/notify.sh -l info -w -r architect "[ORCH→ALL] Sprint 17 P1 cluster CLOSED. PR #597 merged. ADR-0059 + ADR-0056 cluster fully shipped."
scripts/notify.sh -l info -w -r developer "[ORCH→DEV] PR #597 merged. Dev lane idle — owner territory next."
scripts/notify.sh -l info -w -r tester "[ORCH→TEST] PR #597 merged. Tester lane idle."
```

## Cleanup dependencies

| Item | Depends on | Risk |
|---|---|---|
| PR #597 squash | owner click | owner-only path (ADR-0031) |
| Issue #584 close | PR #597 squash | GitHub auto-anchor |
| Issue #587 close | PR #597 squash (cascade) OR manual close | manual fallback ready |
| Sprint 17 close-out | PM lane + owner ratify | PM lane, owner gate |

## Cross-refs

- ADR-0015 (atomic 4-flag handoff)
- ADR-0031 (owner override, owner-only squash)
- ADR-0059 (cluster-squash batch-lag detection — doctrinal home)
- Issue #584 (STORY-P1#1 doctrinal home)
- Issue #587 (STORY-P1#4 d-test doctrinal home)
- PR #597 (impl carrier)
- PR #596 (d-test carrier, MERGED)
- Cycle 567 (squash-pending tolerance)
- Cycle 549 (trust-but-verify)

— @orchestrator, pre-staged 2026-06-28T17:32+03:00, awaiting PR #597 squash event