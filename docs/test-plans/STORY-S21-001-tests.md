# Test Plan: STORY-S21-001 — Template Flag + "Use this template" Button

> **Status**: TDD-RED draft (tester lane, ADR-0044 RED-first)
> **Story**: [#630](https://github.com/atilcan65/AtilCalculator/issues/630) — agent:tester, status:in-progress
> **Author**: @tester, 2026-06-29T02:56Z
> **Sister-pattern**: d065 dual-channel enforcement (bash + fake-tool + --self-test)

## Scope

- **In scope**: Verify `is_template=true` is set on `multi-agent-dev-studio-template` repo, "Use this template" button visible on GH UI, and `gh repo create --template` works end-to-end.
- **Out of scope**: Custom description, social preview, multi-variant templates (Sprint 22+).

## Adversarial Probes (TC selection)

Per tester doctrine (input validation, auth, state, data):
- API permission denied (non-owner tries PATCH)
- Repo metadata payload manipulation (extra fields stripped)
- Network flake during gh api call
- Repo rename / transfer (template flag survives?)
- Visibility flip (private → public → internal)

## Test Cases

### TC1: API metadata check — `is_template: true`
- **Setup**: `MULTI_AGENT_DEV_STUDIO_TEMPLATE_REPO` env var (default `atilcan65/multi-agent-dev-studio-template`); authenticated gh session.
- **Steps**:
  1. Run `gh api repos/${REPO} --jq .is_template`
  2. Exit if `$?` non-zero (auth or repo missing)
- **Expected**: stdout = `true`; exit 0.

### TC2: API PATCH idempotency — re-setting flag is safe
- **Setup**: TEMPLATE repo exists with `is_template=true` already (post-AC1 state).
- **Steps**:
  1. Run `gh api -X PATCH repos/${REPO} -f is_template=true`
- **Expected**: exit 0; returns repo JSON; flag remains `true` (idempotent per ADR-0045 lens (e)).

### TC3: gh repo create --template end-to-end smoke
- **Setup**: A throwaway target repo name (e.g., `d073-smoke-$(date +%s)`); owner PAT available.
- **Steps**:
  1. `gh repo create ${TARGET} --template ${REPO} --public --clone --add-topic=sprint-21-test-smoke`
  2. Verify created repo: `gh api repos/${OWNER}/${TARGET} --jq .is_fork, .source.full_name`
  3. Verify content copied: `ls ${TARGET}/.gitignore ${TARGET}/README.md` (or similar template files)
- **Expected**: exit 0; created repo has `source.full_name == "multi-agent-dev-studio-template"`; template files copied.

### TC4: Adversarial — non-owner PATCH denied
- **Setup**: Untrusted GH token (no owner scope on target repo).
- **Steps**:
  1. `gh api -X PATCH repos/${REPO} -f is_template=false` with untrusted token
- **Expected**: exit non-zero; stderr contains `403 Forbidden` (auth boundary enforced by GH API).

### TC5: Adversarial — visibility flip preserves template flag
- **Setup**: TEMPLATE repo with flag=true, currently public.
- **Steps**:
  1. PATCH visibility → private: `gh api -X PATCH repos/${REPO} -f visibility=private`
  2. Verify: `gh api repos/${REPO} --jq .is_template`
- **Expected**: exit 0; `is_template` remains `true` (GH preserves flag across visibility changes).

## Self-test contract (per ADR-0049)

```bash
bash scripts/tests/d073-template-flag.sh --self-test
```

- **Pre-impl state (RED)**: TC1-TC5 FAIL — `multi-agent-dev-studio-template` repo doesn't exist yet (Sprint 21 Day 1 task).
- **Post-impl state (GREEN)**: TC1-TC5 PASS once owner merges impl PR + ratifies template flag.

## CI integration

- Trigger paths: `scripts/dev-studio-init.sh`, `scripts/audit-project-refs.sh`, `.github/workflows/` (sister-pattern to d058+d064 wiring)
- Workflow: `.github/workflows/lint-and-test.yml` (sister to d058 + d064 jobs)

## Regression Risk

- `gh api` behavior change in new release → wrapper script captures git ref. Sister to d064 SHA-pin pattern.
- Auth boundary drift → TC4 catches via 403 response assertion.

## Sister-patterns

- d058-claim-wip-workstream.sh — bash + fake-tool factory
- d064-cluster-lag.sh — bash + fake-curl factory
- d065-dual-channel-enforcement.sh — bash + fake-curl + ADR-0049 --self-test
- d068-cluster-lag-workflow-wiring.sh — CI integration pattern

## Open questions for arch + dev

1. **Q1**: Fixture repo name confirmation — `atilcan65/multi-agent-dev-studio-template`? (matches owner Q2 ratification per Issue #627)
2. **Q2**: TC2 idempotency check — does GH API preserve `true` on re-PATCH `true`, or revert? (sister ADR-0001 §2 idempotency doctrine)
3. **Q3**: TC3 fixture cleanup — `--delete-branch-on-merge` pattern for throwaway repos?
4. **Q4**: Auth boundary TC4 — simulate via PAT swap, or skip if owner-only?
5. **Q5**: CI integration — run d073 only when `.github/workflows/**` touched, or on all PRs as smoke gate?

— @tester, 2026-06-29T02:56Z (TDD-RED draft, awaiting joint ADR-0021 sizing + dev branch checkout)
