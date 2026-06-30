# ONBOARDING.md — 10-Minute Owner Walkthrough

> **Source of truth:** [Issue #652](https://github.com/atilcan65/AtilCalculator/issues/652) (STORY-S21-020, PM-owned, Wave 5 PM lane).
> **Author:** @product-manager.
> **For:** Solo developer / founder (P1) who just adopted this template and wants to run the first standup without reading 10 docs.
> **Validation:** PM-validated walkthrough on fresh fixture dir (AC3 — completed in S21-020b).
> **Last reviewed:** 2026-06-30 (cycle ~#1799, Sprint 23 PM lane kickoff).

---

## Before you begin (≤ 30 seconds)

You need:

- **Python 3.11+** (`python3 --version` → `Python 3.11.x` or newer)
- **tmux** (`tmux -V` → `tmux 3.x`)
- **GitHub CLI authenticated** (`gh auth status` → `Logged in to github.com as <you>`)
- **`sudo` access** (for `/var/log/dev-studio/` heartbeat dir — dev-studio creates it on first run)
- This repo cloned locally and `cd`'d into

If any prereq is missing, open a `type:bug` issue via `gh issue create --label "type:bug" --label "status:backlog" --label "agent:developer"` with your prereq check output, or check existing issues via `gh issue list --label "type:bug" --state open`. Debugging prereqs is out of scope for the 10-min walkthrough.

---

## Step 1 — Verify repo state (≤ 30s)

```bash
git status              # → On branch main, nothing to commit (working tree clean)
gh repo view --json nameWithOwner,name
```

**Expected output:** `nameWithOwner: <your-org>/<your-repo>` (e.g., `atilcan65/AtilCalculator`). If you see a fork, you're in the wrong clone — re-clone from the template.

---

## Step 2 — Install dev dependencies (≤ 1 min)

```bash
pip install -e .[dev]
```

**Expected output:** `Successfully installed atilcalc-0.1.0 ... pytest-8.3.4 ruff-0.8.6 mypy-1.13.0 ...` and the `atilcalc` console-script is now on `PATH`. If you see `error: subprocess-exit-code-1`, your Python is too old — upgrade to 3.11+.

---

## Step 3 — Run tests (≤ 1 min)

```bash
pytest -q
```

**Expected output:** `N passed in X.XXs` (no failures, no errors). Skips are OK on a fresh clone — e.g., Playwright-dependent tests will skip if Playwright isn't installed locally; that's expected and doesn't block onboarding. If anything fails (F), you're on a broken baseline — `git pull` and re-run.

---

## Step 4 — Lint + type-check (≤ 1 min)

```bash
ruff check && mypy src/atilcalc/engine
```

**Expected output:** `All checks passed!` (ruff) and `Success: no issues found in N source files` (mypy). The engine module is the type-checked surface per [`ADR-0017`](../../decisions/ADR-0017-tech-stack.md) §architecture rule.

---

## Step 5 — Read project context (≤ 1 min)

```bash
cat CLAUDE.md
```

**Expected output:** Project name, repo URL, tech stack (Python 3.11+, Decimal precision, pytest/ruff/mypy), team composition (5 agents + 1 human), and a §Definition of Done. This is the single source of truth — keep it open in a tab.

---

## Step 6 — Read vision + persona (≤ 1 min)

```bash
cat docs/product/vision.md docs/product/personas.md
```

**Expected output:** Your product's one-paragraph vision statement and your P1 persona profile (the user you're building for). P2 personas are explicitly out of MVP scope (see `personas.md` §PM's anti-pattern check).

---

## Step 7 — Check the board (≤ 1 min)

```bash
gh project view --owner <your-org> --format json | jq '.project.title, (.fields.nodes[] | select(.name == "Status")) | .options[].name'
```

**Expected output:** Project title matches your repo name; status options are `Backlog`, `Ready`, `In Progress`, `In Review`, `Done`. If the project is missing, see [`scripts/bootstrap-project-board.sh`](../../scripts/bootstrap-project-board.sh).

---

## Step 8 — Read the current sprint plan (≤ 1 min)

```bash
cat docs/sprints/current/plan.md
```

**Expected output:** Pointer to the active sprint (e.g., `Sprint 23 — ...`), 5-phase or wave breakdown, DoD criteria, open owner questions, cross-refs to predecessors. The orchestrator publishes this; the PM contributes the backlog seed.

---

## Step 9 — Launch the 5-agent team (≤ 1 min)

```bash
./scripts/dev-studio-start.sh
```

**Expected output:** A tmux session named `dev-studio` opens with **6 panes** (3 rows × 2 cols): orchestrator + product-manager (top), architect + developer (middle), tester + human (bottom). Each agent pane touches its heartbeat file at `/var/log/dev-studio/<project>/<role>.heartbeat`. Detach with `Ctrl-b d`; re-attach with `tmux attach -t dev-studio`.

---

## Step 10 — Wait for the first standup (≤ 1 min)

The orchestrator auto-posts a `[Sprint NN] Daily Standup` issue at **09:00 Europe/Istanbul** every working day. To trigger one immediately for a smoke test:

```bash
gh issue create \
  --title "[Sprint 23] Daily Standup (smoke test)" \
  --body "Triggered by ONBOARDING.md Step 10. Each agent should post status within 60s." \
  --label "type:chore" --label "status:ready" \
  --label "agent:orchestrator" --label "cc:human"
```

**Expected output:** Standup issue opened; each agent (`@orchestrator`, `@product-manager`, `@architect`, `@developer`, `@tester`) posts a status comment within ~60s. If an agent misses, check its heartbeat file — if it's stale > 5 min, the watcher has gone silent (restart with `bash scripts/reprime-agent.sh <role>`).

---

## Total: ≤ 10 minutes

If all 10 steps complete with their expected outputs, **you're ready to operate the multi-agent dev-studio team**. Next:

- Open your first user story (copy `docs/backlog/STORY-001.md` as `STORY-100.md`, edit persona + capability + outcome + AC1-3, file via `gh issue create`).
- Wait for the orchestrator's next sprint kickoff (`[Sprint NN] Kickoff` issue) or trigger Sprint 24+ planning yourself.
- Read [`docs/product/vision.md`](./vision.md) for your product goals and [`docs/product/personas.md`](./personas.md) for the user you're building for.

## Out of scope (deferred)

- Video walkthrough (deferred per Issue #652 §Out of scope)
- GUI installer (deferred)
- Multi-user guest persona (P2 — future epic, not MVP)
- Production deploy / release process (separate ADR-0010 §Runtime infra)

## Related docs

- [`docs/product/vision.md`](./vision.md) — Product vision + success metrics M1-MN
- [`docs/product/personas.md`](./personas.md) — P1 (MVP) + P2 (future) personas
- [`docs/sprints/current/plan.md`](../sprints/current/plan.md) — Active sprint pointer
- [`docs/decisions/ADR-0017-tech-stack.md`](../decisions/ADR-0017-tech-stack.md) — Tech stack source of truth
- [`.claude/CLAUDE.md`](../../CLAUDE.md) — Full project doctrine (read after this walkthrough)

---

🤖 Generated with [Claude Code](https://claude.com/claude-code) — Sprint 23 PM lane, Issue #652 AC1+AC2 delivery.