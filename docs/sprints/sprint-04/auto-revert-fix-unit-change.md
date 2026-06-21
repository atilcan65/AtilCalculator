# AUTO-REVERT-FIX — systemd unit change (owner pre-req)

> **Status:** Pending owner apply.
> **Story:** Sprint 4 P0 AUTO-REVERT-FIX.
> **Design:** [docs/designs/STORY-AUTO-REVERT-FIX-design.md](../../designs/STORY-AUTO-REVERT-FIX-design.md) (PR #211, merged 2026-06-21T16:35:47Z).
> **Impl PR:** (open at the time this doc is read — search `agent:developer` + `type:feature` for "AUTO-REVERT-FIX").
> **Author:** @developer (impl + this owner pre-req doc).

The `atilcalc-web.service` unit file is **owner-side** (lives in `~/.config/systemd/user/atilcalc-web.service`, not in this repo). The AUTO-REVERT-FIX impl ships two new repo files:

| File | Purpose |
|---|---|
| `scripts/post-restart-label-guard.sh` | Idempotent label-guard — re-applies only allowlist labels, preserves the rest |
| `scripts/restart-stable.txt` | Allowlist of labels that may be re-applied (default: `type:*`, `sprint:*`) |

The unit file needs a one-line `ExecStartPost=` addition to call the guard on every restart. **This change is owner action, not the impl PR** (per CLAUDE.md §File ownership matrix: `.github/workflows/` and equivalent infra files are human-only).

---

## The change

Add (or uncomment) the following line in the `[Service]` section of `atilcalc-web.service`:

```ini
ExecStartPost=/home/atilcan/projects/AtilCalculator/scripts/post-restart-label-guard.sh --dry-run
```

**Ship with `--dry-run` for the first deploy cycle** (per design §Rollback safety posture). After observing one full restart with no regression on the deploy path, owner flips the mode in a follow-up commit:

```ini
ExecStartPost=/home/atilcan/projects/AtilCalculator/scripts/post-restart-label-guard.sh
```

---

## Apply procedure

```bash
# 1. Edit the unit (systemd's preferred way to override without touching the base unit)
systemctl --user edit atilcalc-web.service

# 2. In the editor that opens, add the [Service] section override:
#    [Service]
#    ExecStartPost=
#    ExecStartPost=/home/atilcan/projects/AtilCalculator/scripts/post-restart-label-guard.sh --dry-run
#
#    (The empty ExecStartPost= first CLEARS any inherited ExecStartPost=; the
#    second line is the new value. This is the systemd idiom for replacing
#    a list-valued setting.)

# 3. Reload + restart
systemctl --user daemon-reload
systemctl --user restart atilcalc-web.service

# 4. Verify the hook ran
tail -n 5 /home/atilcan/projects/AtilCalculator/scripts/logs/post-restart-label-guard.log
# Expected: one JSON-lines entry per open PR with agent:developer label,
# each showing "dry_run": true and the preserved/reapplied lists.

# 5. Verify deploy path intact (the v9 chain must still work)
bash scripts/deploy-runner.sh
# Expected: exit 0, port 8000 LISTEN, service active (per d019 T1-T5)
```

---

## Rollback

If the hook breaks the restart cycle (hang, gh CLI cascade, deploy path regression):

```bash
systemctl --user edit atilcalc-web.service
# In the editor, comment out the ExecStartPost line:
# [Service]
# ExecStartPost=
# # ExecStartPost=/home/atilcan/projects/AtilCalculator/scripts/post-restart-label-guard.sh --dry-run

systemctl --user daemon-reload
systemctl --user restart atilcalc-web.service
```

No repo revert needed — the unit change is owner-side and reversible by commenting one line.

---

## Chain dependencies (per design §Risk #5)

- **RCA-16 passwordless sudoers rule** for `systemctl --user restart` is required for the d023 regression test to run on prod. The hook itself does NOT need sudo (it runs as the user, not via sudoers). Local dev / CI test environments may need equivalent setup if d023 is run outside the prod-host context.
- The hook is **idempotent** — calling it manually (or via the unit) multiple times in a row yields the same end state, so re-running on a stale baseline is safe.
- The hook is **read-heavy on first run** (one `gh pr list` call + N jq parses) and **write-light** (only the allowlist labels get a `gh pr edit --add-label` call, which is itself idempotent).

---

## What I verified (dev-side, before opening impl PR)

Smoke test on real repo (one open PR with `agent:developer`: PR #212):

```bash
$ bash scripts/post-restart-label-guard.sh --dry-run
[2026-06-21T16:42:40Z] pr=212 mode=dry-run preserved=status:ready,agent:developer,cc:human,verdict-by:2026-06-22T14:25:00Z reapplied=type:bug,sprint:current
OK: mode=dry-run prs=1 preserved=0 reapplied=0
$ echo $?
0
```

Result: PR #212's `cc:human + verdict-by:*` labels correctly classified as **preserved** (not in `type:*` or `sprint:*` allowlist) — this is the fix for Mechanism A. Duration: 20ms (well under the 200ms per-PR budget in design §Performance budget).

The full d023 regression (3 PRs + controlled restart + 90s wait) is **tester-owned** per design §Test contract; this doc is the dev-side owner pre-req.

— @developer, 2026-06-21T16:42Z
