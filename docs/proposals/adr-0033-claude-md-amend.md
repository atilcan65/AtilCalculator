# Proposal: ADR-0033 — Auto-Ping Hard-Rule amendment (.claude/CLAUDE.md)

**Status:** Proposed (owner-gated, .claude/ human-only)
**Date:** 2026-06-21
**Author:** @architect
**Closes:** Issue #221 (architect scope second half: CLAUDE.md update)
**Related:** [ADR-0033](../decisions/ADR-0033-auto-ping-dual-channel.md), [PR #223](https://github.com/atilcan65/AtilCalculator/pull/223)

---

## Why

`scripts/notify.sh` is currently single-channel (Telegram-only). Agents do not read Telegram, so peer-agent pings suffer ~60s wake lag from the watcher's 60s poll cycle. ADR-0033 closes this gap by mandating **dual-channel** for any Auto-Ping to a peer agent: Telegram (human mirror) + tmux pane (agent wake) in <5s.

The Auto-Ping Hard-Rule section in `.claude/CLAUDE.md` is the **human-only authoritative copy** of this doctrine. This proposal contains the exact text changes the owner should apply to `.claude/CLAUDE.md` to align it with ADR-0033.

**File ownership note**: `.claude/` is human-only per `CLAUDE.md §File ownership matrix`. Architects propose via PR, owner applies manually. This file (`docs/proposals/adr-0033-claude-md-amend.md`) is the architect's proposal; the owner copies the §Proposed changes below into `.claude/CLAUDE.md` after merging this PR.

---

## Proposed changes (apply to `.claude/CLAUDE.md`)

### Edit 1 — "Hangi durumda kime" table: add dual-channel column note (after line 101)

**Location**: §Auto-Ping Hard-Rule → §Hangi durumda kime, after the table (around line 101-102, before §What you do NOT need to ask at line 103).

**Insert** (right after the table, before the blank line before "### What you do NOT need to ask"):

```markdown
> **Channel doctrine** (ADR-0033, Issue #221): for any Auto-Ping whose target is a **peer agent** (not human), `notify.sh` MUST be called with `-w -r <role>` to reach both Telegram (human mirror) AND tmux pane (agent wake in <5s). Telegram-only pings to agents are a **silent-drop risk** — peer doesn't see Telegram; wakes only on next poll cycle (~60s lag).
>
> - Telegram-only (`notify.sh -l <role> "msg"`) → allowed ONLY for `human` target (humans don't have a tmux pane).
> - Dual-channel (`notify.sh -w -r <role> "msg"`) → REQUIRED for `orchestrator`, `product-manager`, `architect`, `developer`, `tester` targets.
> - Missing `-r` with `-w` → exit 2 with error (no silent skew).
```

### Edit 2 — "What you do NOT need to ask": add Telegram-only anti-pattern (after line 107)

**Location**: §Auto-Ping Hard-Rule → §What you do NOT need to ask, after the third ❌ bullet (line 107).

**Insert** (after line 107, before the blank line before §Eskalasyon istisnaları):

```markdown
- ❌ "Telegram yeterli mi, tmux wake gerekiyor mu?" — **Hayır**, agent peer'ları için her zaman dual-channel (`-w -r <role>`). Telegram tek başına insan kanalıdır; agent'lar Telegram'ı okumaz (ADR-0033).
```

### Edit 3 — "Eskalasyon istisnaları": add silent-drop risk clause (after line 117, before "Bunlarda" at line 119)

**Location**: §Auto-Ping Hard-Rule → §Eskalasyon istisnaları, after the 5th bullet ("Production deploy/release kararı" at line 117).

**Insert** (after line 117, before the blank line before "Bunlarda"):

```markdown
- **Auto-Ping to peer agent uses single-channel (Telegram only)** — `notify.sh` default. This is a **silent-drop risk** (peer doesn't see Telegram; wakes only on next 60s poll cycle). Must use `-w -r <role>` per ADR-0033. This is the doctrine gap closed by Issue #221.
```

### Edit 4 — Format example: update to use dual-channel (replace lines 82-87)

**Location**: §Auto-Ping Hard-Rule → §Format, the example block at lines 82-87.

**Replace**:

```diff
- Örnek:
- ```
- scripts/notify.sh -l architect "[DEV→ARCH] PR #20 ready for design-alignment review
- https://github.com/atilcan65/AtilCalculator/pull/20
- Check: import path, bind string, sync handler"
- ```
+ Örnek (dual-channel, peer-agent target per ADR-0033):
+ ```
+ scripts/notify.sh -w -r architect -l info "[DEV→ARCH] PR #20 ready for design-alignment review
+ https://github.com/atilcan65/AtilCalculator/pull/20
+ Check: import path, bind string, sync handler"
+ ```
+
+ Telegram-only (legacy, human target only):
+ ```
+ scripts/notify.sh -l human "[ARCH→HUMAN] PR #220 owner-gate pending review
+ https://github.com/atilcan65/AtilCalculator/pull/220"
+ ```
```

---

## Manual application instructions (for owner)

After this PR is merged, the owner should:

1. Open `.claude/CLAUDE.md` in the local repo checkout (the file is git-ignored; not visible on GitHub).
2. Apply Edits 1, 2, 3, 4 above using the line-number anchors and old/new content provided.
3. Verify the §Auto-Ping Hard-Rule section now reads as in the diff preview.
4. Mirror the change to `atilcan65/dev-studio-template` if the template's `.claude/CLAUDE.md` has the same section (out of scope for this PR — separate issue per Issue #221 §Out of scope).

The proposal file can be kept in `docs/proposals/` for the audit trail (PR #223 will reference it).

---

## Out of scope (per Issue #221 §Out of scope)

- Template port (`atilcan65/dev-studio-template`) — separate issue
- Multi-pane broadcast (`-r all`) — explicitly rejected in ADR-0033
- Replacing Telegram — Telegram works fine for humans; the gap is agent-side

---

## Cross-references

- **ADR-0033**: `docs/decisions/ADR-0033-auto-ping-dual-channel.md` (full doctrine, decision, consequences)
- **PR #223**: https://github.com/atilcan65/AtilCalculator/pull/223 (architect's ADR + INDEX PR)
- **Issue #221**: Sprint 4 P0 dual-channel fix
- **Sister fix**: ADR-0032 / PR #217 (RCA-18 dedup buffer TTL) — closes the *reactive* half of the RCA-18 chain; this proposal closes the *preventive* half

— @architect, 2026-06-21T20:50:00Z
