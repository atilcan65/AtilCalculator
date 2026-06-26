# ADR-0049 Amendment — Proposed 9-Lens Sub-check (k) JS Syntactic Correctness

- **Amendment to:** ADR-0049 §Implementation guide step 4 (lines 133-137, ccda247)
- **Status:** Proposed (2026-06-26)
- **Date:** 2026-06-26
- **Author:** @architect (proposal only — owner squash gate per `.claude/` ownership)
- **Refs:** Issue #444 (TD-031 follow-up), ADR-0049 §Implementation guide step 4, RETRO-006 §Behavioral d-test doctrine, Issue #441 (L337 backtick P0 regression), PR #438 hotfix

---

## Context

ADR-0049 §Implementation guide step 4 (ccda247) calls for adding 9-Lens sub-check **(k) JS syntactic correctness** to `.claude/agents/architect.md` §9-Lens Review Checklist. This amendment file proposes the **exact text** that should land in architect.md (line 100, after lens (j)).

Per **CLAUDE.md §File ownership matrix**: `.claude/` = human-only territory. This amendment PR is a **proposal** — the architect drafts the text, owner squash-merge applies it to architect.md.

---

## Proposed amendment to `.claude/agents/architect.md` §9-Lens Review Checklist

**Insert after line 100 (after lens (j) entry), as new line 101:**

```markdown
- **(k) JS syntactic correctness** [Issue #444, TD-031] — for any PR touching `.github/workflows/*.yml` with `actions/github-script` snippets, extract the embedded JavaScript and verify `node --check` passes. Catches edit-time typos: missing backticks (Issue #441 L337 regression), unclosed template literals, unbalanced parens, syntax errors that YAML linters miss. One-line static check at review time, sister-pattern to d050b behavioral runtime test. (TD-031 lesson)
```

**Cross-link addition** (after lens list, in §Pre-publish gate attestation paragraph at line 89):

```markdown
Each lens is a distinct verification mechanism backed by a known blind-spot TD; missing one is a doctrinally-tracked failure mode (TD-016/018/019/020 = lenses a-d, g; TD-028 = (h); TD-029 = (i); TD-030 = (j); **TD-031 = (k)**).
```

---

## Rationale

**Why a separate amendment file (not direct edit to architect.md)**:
- **CLAUDE.md §File ownership matrix**: `.claude/` = human-only territory. Architect cannot directly edit soul files.
- **Sister-pattern**: PR #447 (ADR-0048 §Live validation amendment) followed the same pattern — docs-only PR proposing ADR amendment, owner squash-merge.
- **Auditability**: Separate amendment file provides clear provenance for the change (who proposed, who approved, when).

**Why static (node --check) not behavioral (full eval)**:
- **Edit-time vs runtime**: Sub-check (k) is for architect review (edit-time, before merge). Sub-check (k) catches typos BEFORE merge. d050b (ADR-0049 framework) is the behavioral runtime gate (post-merge). Two-layer defense.
- **Speed**: `node --check` runs in <1 second. Behavioral eval would require workflow_dispatch + CI roundtrip (>30 seconds).
- **Sister-pattern**: Same as d046 family static linting for `.py` files (TC1/TC2/TC3 grep-based). (k) is the JS-equivalent.

**Why NOT all `.github/workflows/**` (only `actions/github-script` snippets)**:
- Per ADR-0049 §Open questions Q4: "should (k) apply to ALL `.github/workflows/**` or only `actions/github-script` snippets?"
- Recommendation: only `actions/github-script` snippets. Other workflow elements (yaml structure, action versions) are covered by other lenses:
  - YAML structure → lens (i) Platform hard constraints
  - Action SHA pins → lens (h) Workflow YAML SHA pin
  - API correctness → lens (j) Auto-generated file refs (when relevant)
- Lens (k) is specifically for **JS syntactic correctness** of inline scripts. Scoping prevents overlap with other lenses.

---

## Implementation steps

1. **Owner applies proposed text** to `.claude/agents/architect.md` line 100-101 (insert new line 101) and line 89 (TD-031 cross-link).
2. **Tester extends d046 family** with `node --check` invocation (per ADR-0049 step 4 line 136). Implementation file: `scripts/tests/d046-js-syntactic-check.sh` (sister-pattern to existing d046 tests).
3. **Cross-link to RETRO-006 §Behavioral d-test doctrine** — already cited in ADR-0049 §Sister-patterns (line 7). No additional cross-link needed at ADR level.
4. **Update ARCH-STATUS** in architect responses to include (k) lens attestation when reviewing workflow PRs.

---

## Acceptance criteria

- [ ] Owner applies proposed text to `.claude/agents/architect.md`
- [ ] Lens (k) appears in architect.md §9-Lens Review Checklist
- [ ] TD-031 cross-link added to §Pre-publish gate attestation paragraph
- [ ] d046 family extended with `node --check` invocation (tester lane)
- [ ] Next PR touching `.github/workflows/*.yml` with `actions/github-script` snippet uses lens (k) in arch verdict

---

## References

- **ADR-0049** §Implementation guide step 4 (lines 133-137) — call for sub-check (k)
- **Issue #444** — original proposal, TD-031 follow-up
- **TD-031** — rubber-stamp pattern + L337 syntactic regression (filed 2026-06-26T14:46Z)
- **Issue #441** (P0) — L337 backtick regression, this amendment's direct motivator
- **PR #438** hotfix — dropped closing backtick at L337 audit body
- **PR #445** — admin-merge of L337 fix
- **RETRO-006** §Behavioral d-test doctrine — sister-pattern, runtime layer
- **d046 family** — static lint test family, JS syntactic check extends this
- **Sister-pattern**: ADR-0048 §Live validation amendment (PR #447) — same docs-proposal-PR-owner-squash pattern

---

🤖 Architect amendment proposal @ 2026-06-26T20:55Z — Sprint 12 P1 step #6 (per Issue #451 plan.md), RETRO-007 pre-merge 4-cat verification applied (status:in-review + needs-architect-review + cc:product-manager + cc:developer + cc:human labels on opening PR)