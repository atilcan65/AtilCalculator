# Test Plan: DEPLOY-002 — Secret wiring (DEPLOY_SSH_KEY + DEPLOY_HOST + DEPLOY_USER repo secrets)

**Refs**: Issue #131 (DEPLOY-002, P0). ADR-0027 §Decision.2+4 (Accepted per #131 body; verify status at sizing).

## Scope
- **In scope**: Static verification that the 3 required repo secrets exist (via `gh secret list`); that `DEPLOY_SSH_KEY` decodes to a valid ed25519 key (no passphrase); that DEPLOY-001's workflow references all 3 secrets; that `docs/ops/secret-rotation.md` documents the rotation procedure.
- **Out of scope**: Secret value content beyond format validation (private key bytes are sensitive); automated rotation (per ADR-0027 §Negative — manual quarterly); key escrow / HSM.

## Constraints (CRITICAL)

- **Repo secrets are owner-managed.** Tester cannot generate keys or store secrets — these are owner-only actions per ADR-0014 (PROJECT_TOKEN precedent) + CLAUDE.md §Things agents must NEVER do ("Modify secrets... without explicit human approval").
- **Secret VALUES must never be logged, echoed, or written to test output.** Tests assert existence + format only.

## Test Cases

### TC-1: All 3 secrets exist in repo
- **Setup**: Owner has stored secrets via `gh secret set`.
- **Steps**:
  1. Run `gh secret list --repo atilcan65/AtilCalculator --json name,visibility,updatedAt`.
  2. Assert response includes `DEPLOY_SSH_KEY`.
  3. Assert response includes `DEPLOY_HOST`.
  4. Assert response includes `DEPLOY_USER`.
  5. Assert all 3 have `visibility: "all"` or `"private"` (not `selected` — Actions need repo-wide access).
- **Expected**: 3 secrets present, accessible to Actions on `main`.

### TC-2: DEPLOY_SSH_KEY decodes to valid ed25519 (no passphrase)
- **Setup**: TC-1 passed; secret exists.
- **Steps**:
  1. **CRITICAL**: do NOT print the secret value. Use `gh secret list` for name + updatedAt only.
  2. Verify key format indirectly: check that DEPLOY-001's workflow (post-merge) successfully SSH-authenticates via `appleboy/ssh-action` step (TC-3 in DEPLOY-001 covers the SSH-call attempt).
  3. As a separate static check: confirm the workflow YAML references the secret by name (not by value) — see DEPLOY-001 TC-3.
- **Expected**: secret is referenced correctly by the workflow; SSH step succeeds (validated by DEPLOY-003's smoke test reaching `/healthz`).

### TC-3: DEPLOY_HOST value is the prod host
- **Setup**: TC-1 passed; secret exists.
- **Steps**:
  1. Use `gh workflow run deploy.yml` (manual dispatch if supported) OR verify via DEPLOY-001 TC-1 that the workflow YAML references `${{ secrets.DEPLOY_HOST }}`.
  2. Assert host matches `192.168.1.199` (per ADR-0010 prod host).
  3. Do NOT print the actual secret value in test output.
- **Expected**: workflow uses DEPLOY_HOST pointing at prod.

### TC-4: DEPLOY_USER value matches service UID
- **Setup**: TC-1 passed; secret exists.
- **Steps**:
  1. Assert workflow YAML references `${{ secrets.DEPLOY_USER }}`.
  2. Confirm value matches the systemd user-service UID on prod (default `atilcan` per ADR-0010).
- **Expected**: `systemctl --user restart atilcalc-web.service` succeeds because user matches.

### TC-5: `docs/ops/secret-rotation.md` documents rotation procedure
- **Setup**: TC-1 passed; secrets exist.
- **Steps**:
  1. Assert file exists at `docs/ops/secret-rotation.md` (new file per ADR-0027 §Decision.4).
  2. Grep for the 5-step rotation procedure (per ADR-0027 §4.Rotation procedure):
     - Generate new ed25519 keypair on prod host
     - Add new public key to `~/.ssh/authorized_keys`
     - Update `DEPLOY_SSH_KEY` repo secret
     - Test a deploy (any merge to main)
     - After 7-day grace period, remove old public key
  3. Assert document mentions quarterly cadence (90 days).
- **Expected**: rotation procedure is documented; owner can execute without re-deriving steps.

### TC-6: Secrets NOT echoed in workflow logs
- **Setup**: deploy has been run at least once.
- **Steps**:
  1. Fetch last deploy run via `gh run list --workflow=deploy.yml --limit 1 --json databaseId`.
  2. Fetch logs via `gh run view <id> --log`.
  3. Grep logs for `-----BEGIN`, `OPENSSH PRIVATE KEY`, `192.168.1.199` literals, or any 64+ char base64 string (heuristic for key material).
  4. Assert no matches.
- **Expected**: secrets are referenced via `secrets.*` substitution, never expanded to plaintext in logs.

## Adversarial Probes

### AP-1: Secret value leaked in commit history
- Setup: scan all commits on `main` for any string matching SSH key format (`-----BEGIN OPENSSH PRIVATE KEY-----`).
- Expected: no match — secrets must NEVER be committed to git.

### AP-2: Workflow logs secret on error
- Setup: deliberately fail a deploy (e.g., wrong host), inspect logs.
- Expected: failure logs show command exit code, not secret values.

### AP-3: `gh secret list` over-exposes metadata
- Setup: confirm `gh secret list` output only shows name + visibility + updatedAt, not values.
- Expected: values are write-only (only `gh secret set` can set, only Actions can read).

## Performance Concerns

- `gh secret list` is a single API call (~200ms).
- `gh run view --log` may take 1-3s for large logs.
- No perf test required — these are admin verification steps.

## Regression Risk

- Secret storage change does not affect src/atilcalc/ code paths.
- `docs/ops/secret-rotation.md` is a new file; no existing docs to break.

## Owner Gate Verification (manual checklist)

Before tester can run TC-1 through TC-6:
- [ ] Owner has generated ed25519 keypair (no passphrase): `ssh-keygen -t ed25519 -f ~/.ssh/atilcalc_deploy -N ""`
- [ ] Owner has appended public key to `~/.ssh/authorized_keys` on prod host `192.168.1.199`
- [ ] Owner has stored 3 secrets via `gh secret set`:
  - `DEPLOY_SSH_KEY=<private-key-content>`
  - `DEPLOY_HOST=192.168.1.199`
  - `DEPLOY_USER=atilcan`
- [ ] DEPLOY-001's workflow is merged to `main` (so secret references can be validated)

Tester contract tests run against **post-merge state on `main`**. If secrets not yet stored or workflow not yet merged, tests are TDD-red with explanatory skip markers.
