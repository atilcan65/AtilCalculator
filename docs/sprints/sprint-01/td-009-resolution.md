# TD-009 Resolution — Per-agent worktrees (2026-06-18)

> **Status:** ✅ RESOLVED — option (a) shipped, worktrees live on disk.
> **Authoritative TD source:** `docs/tech-debt.md` (architect-owned) — this file is the *implementation log*, not the canonical TD record.
> **Author:** @orchestrator
> **Owner decision timestamp:** 2026-06-18 (~10:25Z, in chat with @atilcan65)

---

## TL;DR

TD-003 / TD-009 root cause = shared filesystem checkout + concurrent agent activity.
Fix chosen = **option (a) filesystem isolation via per-agent git worktrees**.

3 worktrees created at 3498d59 (PR #56 merge, post Sprint 1 P0 burn-down):
- `@architect` → `/home/atilcan/projects/atilcalc-architect` (branch: `main`)
- `@developer` → `/home/atilcan/projects/atilcalc-developer` (detached HEAD @ 3498d59)
- `@tester` → `/home/atilcan/projects/atilcalc-tester` (detached HEAD @ 3498d59)
- `@orchestrator` → remains on the main checkout `/home/atilcan/projects/AtilCalculator` (read-mostly)

Each agent must `cd` into their own path before any file work. `git branch --show-current` re-verification still required as belt-and-suspenders (TD-003 mitigation #1, kept in place).

---

## Why option (a)

From TD-003 (2026-06-17 18:31Z, PR #33 commit recovery) and TD-009 (2026-06-17 21:28Z, PR #42 review window), the three resolution options were:

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| (a) Git worktrees (filesystem isolation) | Zero infra change; `git` native; works offline; per-agent own cwd; bisects well | Detached HEAD ceremony for dev/tester; `gh` CLI callers must be in correct cwd | ✅ **CHOSEN** |
| (b) Per-agent working copies (separate clones) | Total isolation, no shared `.git/` | `.git` state desync risk; `gh` API + token confusion; harder to keep `main` fresh | rejected |
| (c) Pre-commit hook asserting branch ownership | Cheap; doesn't change layout | Doesn't help with Edit/Read on the wrong branch (TD-009 instance); only catches at commit time | rejected (orthogonal mitigation only) |

Option (a) is the **minimum viable filesystem isolation** — `git` does the heavy lifting, no infra change, no auth rework, scales to 5+ agents naturally.

---

## Setup commands (re-runnable)

```bash
# One-time (already done):
cd /home/atilcan/projects
git -C AtilCalculator worktree add ../atilcalc-architect main
git -C AtilCalculator worktree add --detach ../atilcalc-developer main
git -C AtilCalculator worktree add --detach ../atilcalc-tester main

# Re-sync after `main` advances (every agent's daily hygiene):
cd /home/atilcan/projects
git -C AtilCalculator fetch origin
# Architect (on main branch):
(cd ../atilcalc-architect && git pull --ff-only origin main)
# Developer + tester (detached): rebase current branch onto origin/main
(cd ../atilcalc-developer && git rebase origin/main)  # only if no in-flight work
(cd ../atilcalc-tester    && git rebase origin/main)  # only if no in-flight work
```

---

## Operational contract (per-agent)

1. **Always `cd` into your assigned worktree before any file op.** No exception.
2. **Re-verify with `git branch --show-current` after any tool call > 5s.** (TD-003 mitigation #1, retained.)
3. **`git status` after every file edit.** Confirm files are in the working tree before commit.
4. **PR-anchored file reads preferred** — use `gh pr view N --json files` instead of `cat` on the local copy when reviewing a peer's PR. (TD-009 mitigation #3.)
5. **Detached HEAD rule** — developer + tester must `git checkout -b <branch>` before any commit; never commit on detached HEAD (orphan commits).
6. **Orchestrator stays on main checkout** at `/home/atilcan/projects/AtilCalculator`. The current working branch on the main checkout reflects whatever dev was last on (post-merge dev may leave a non-main branch checked out — this is fine for orchestrator's read-only review role, but orchestrator must not commit there).

---

## What this changes for the existing workflow

| Old behavior | New behavior |
|---|---|
| All agents share `/home/atilcan/projects/AtilCalculator` working tree | Each agent has a dedicated path |
| `git checkout` collisions silently overwrite peer's working branch | Each worktree has its own HEAD, no contention |
| Orchestrator runs in same cwd as dev — risk of stepping on dev's branch | Orchestrator's checkout is read-mostly; no commit risk |
| Sprint 1 day 0 already saw 2 instances (TD-003, TD-009) of the bug | Going forward, multi-agent commits can't trample each other |

---

## Verification done at setup

```
$ git worktree list
/home/atilcan/projects/AtilCalculator      53d4e35 [chore/issue-57-regress-pin-conftest]
/home/atilcan/projects/atilcalc-architect  3498d59 [main]
/home/atilcan/projects/atilcalc-developer  3498d59 (detached HEAD)
/home/atilcan/projects/atilcalc-tester     3498d59 (detached HEAD)
```

Main is at 3498d59 (PR #56 merge). All worktrees start from the same commit → no drift.

---

## Open follow-ups

- **Tech-debt.md canonical update** — file an issue for @architect to move TD-009 to "Resolved items" (this file is the implementation log, not the source of truth).
- **#48 template port** — the worktree pattern must be ported to `dev-studio-template` so future projects (and AtilCalculator's Sprint 2+) start with this layout.
- **Orchestrator's main checkout** — currently parked on dev's branch `chore/issue-57-regress-pin-conftest` (53d4e35). Not blocking but should be `git checkout main`'d once PR #59 lands.
- **Daily re-sync ritual** — add a `scripts/sync-worktrees.sh` helper that does the `git pull --ff-only` / rebase dance. Sprint 2 chore.

---

## Why this is a sprint-01 doc, not just a tech-debt entry

TD-009 is *also* filed in `docs/tech-debt.md` (architect's domain), but the **implementation log** belongs in the sprint folder because:
- It documents a *process change* applied during Sprint 1
- It is referenced by the Sprint 1 retro (when written)
- It is the template port's source of truth (see #48)

Architect's tech-debt.md update will be a 1-line cross-reference to this file.

— Orchestrator, 2026-06-18T10:35:00+03:00
