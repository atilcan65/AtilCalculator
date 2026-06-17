# Sprint 0 — Bootstrap (2026-06-17 → 2026-06-17, 1 day)

> **Status:** ✅ CLOSED — Sprint 0 kapandı, Sprint 1 grooming başlayabilir.
> **Close-out date:** 2026-06-17T14:49:53Z (PR #8 merge)
> **Original goal:** dev-studio-template'den açılan ilk gerçek projeyi (AtilCalculator) çalışır hale getirmek: vizyon, tech stack, agent altyapısı, label seti, ilk ADR.

---

## Sprint Goal (initial)

dev-studio multi-agent sistemi AtilCalculator projesi üzerinde uçtan uca çalışır hale gelsin:
- Sahibinin vizyonu alınsın ve PM tarafından canonicalize edilsin.
- Tech stack ve mimari kararları ADR olarak yazılsın.
- Agent watch döngüsü, label invariant, board sync çalışsın.
- İlk Sprint 1 backlog'u için temeller hazır olsun.

## Capacity

- **Süre:** 1 gün (formal 2 haftalık sprint değil, bootstrap)
- **Agents:** orchestrator + PM + architect + developer + tester (5/5 alive)
- **Human involvement:** vision intake (#4), 2 review (PR #5 + PR #8), 1 critical fix decision (PR #9)

## Committed stories

| # | Title | Status | Done |
|---|---|---|---|
| #1 | Bootstrap (architect self-block, superseded) | CLOSED | ✅ |
| #2 | [Sprint 0] Vision Intake & Product Brief | CLOSED | ✅ (PR #8 merge ile) |
| #3 | [S0] Tech Stack & Architecture Skeleton | OPEN — Architect owns, PR #5 draft | ⏳ Sprint 1'e taşınır |
| #4 | [Vision] AtilCalculator (raw intake) | CLOSED | ✅ |
| #6 | BUG: agent-watch double-fires on issue_assigned | IN-PROGRESS — fix PR #9 draft | ⏳ Sprint 1 P0 |
| #10 | Doctrine conflict: cc:tester vs 4-cat invariant | BACKLOG — owner intervention needed | ⏳ Sprint 1 |

## Delivered artifacts

- **PR #8 MERGED** (c254293): `docs/product/vision.md` + `docs/product/personas.md` + `docs/backlog.json` (initial empty)
- **PR #5 DRAFT**: ADR-0017 tech stack (engine-first / web-first reframe landed, tester signoff pending)
- **PR #9 DRAFT**: BUG #6 watcher dedup fix (branch temiz, reviewer atanmamış)
- **PR #7 CLOSED**: pre-draft stack candidates (superseded by PR #5)

## Sprint 0 specific outcomes (beyond original scope)

- **Sahipli intaken alındı** ve 9 bölümlük vision canonicalize edildi (vision.md).
- **Owner 4 open question sorusu** Sprint 1 grooming öncesi cevaplanmalı:
  1. SPA vs server-rendered HTML+JS?
  2. CHANGELOG'daki FastAPI /healthz + /hello/{name} gerçek mi yoksa template artefaktı mı?
  3. Scientific functions MVP-1 mi MVP-2 mi?
  4. History DB backup cadence?
  5. (Bonus) Docs language: İngilizce + Türkçe mirror?
- **VM hardening** Sprint 1 P0 prerequisite olarak işaretlendi (SSH key auth, ufw, fail2ban, password-auth off).
- **Watch dedup bug** bulundu ve çözümü PR #9'da (merge'i Sprint 1'de).
- **Doctrine conflict** (#10) tespit edildi — Sprint 1'de verdict:* sentinel label önerisi.

## Risks identified

| Risk | Severity | Mitigation |
|---|---|---|
| PR #5 tester signoff hâlâ yok | P1 | Sprint 1 day 1'de tester'a ping at, 4-cat invariant PR öncesi doğrula |
| PR #9 reviewer atanmamış | P0 | Owner merge kararı verir (PR kendi açtığı, basit fix) |
| B vs B+E sistemik çözüm açık | P2 | Sprint 1 grooming'e STORY-007 olarak |
| VM hardening yapılmadan HTTP surface açılmaz | P0 | Sprint 1'in ilk günü, MVP-1 kodundan önce |

## Velocity / metrics

- **PRs opened:** 4 (#5, #7, #8, #9)
- **PRs merged:** 1 (#8)
- **PRs closed:** 1 (#7 — superseded)
- **PRs still open:** 2 (#5 draft, #9 draft)
- **Issues opened:** 6 (#1, #2, #3, #4, #6, #10)
- **Issues closed:** 3 (#1, #2, #4)
- **ADRs written:** 0 (PR #5 not yet merged)
- **Wakes received:** ~30 (5 hours of agent-watch activity)
- **Stale-cc deadlock-breaker fires:** 5+ (reveals missing label taxonomy)

## Sprint 0 retro (initial)

### What worked
- Vision intake → PM canonicalization → PR flow worked first time
- Owner-in-the-loop critical decisions didn't bottleneck (vision came in 13:23Z, PM PR opened 13:35Z)
- Agent-watch caught 2 real bugs (#6 dedup, #10 doctrine conflict) before they hit production
- 4-cat invariant CI guard prevented multiple label-anarchy states

### What hurt
- Stale-cc deadlock-breaker döngüsü: PR'larda `cc:orchestrator` release edilemedi (repo'da `cc:human` label yok) → ping-pong yaptı
- B vs B+E sistemik çözümü bootstrap sırasında çözülmedi, Sprint 1'e taşındı
- PR #9 branch composition sorunu (ADR-0017 commit'leri karışmış) — tester rebase'i 35dk'da çözdü, erken uyarı (split verdict) işe yaradı

### What we learned
- **Orchestrator "D moduna geçtim" trade-off**: stale_cc döngüsünden kaçınmak için GitHub aksiyonu almamak bir seçenek, ama PR #8 merge'i gelince kaçırılmış olurdu. Daha iyi: deadlock-breaker'ın varsayımı değişmeli (örn. "benim işim bitti" → "PR status:ready oldu").
- **Reviewer atanmadan merge olan PR'lar**: PR #9 sahibi tarafından açılmış, hiç reviewer yok, sahibinin kendisi merge edecek. Bu küçük PR'larda OK ama feature PR'larda riskli.

---

## Sprint 1 — Handover

**Sprint 1'in ilk iş günü öncelik sırası:**

1. **PR #9 merge** (sahibin kararı) — BUG #6 fix, sprint'in ilk dakikalarında
2. **PR #5 reframe → ready → review → merge** — ADR-0017 Accepted olmadan Sprint 1 stories başlayamaz
3. **Sprint 1 grooming kickoff** — PM backlog'a ilk story'leri koyar:
   - STORY-001: VM hardening (SSH key, ufw, fail2ban, password off)
   - STORY-002: Engine module (4 ops + decimal precision, per vision M1)
   - STORY-003: Keyboard-first web shell (per vision M3)
   - STORY-004: HTTP surface (FastAPI + static, owner SPA kararı sonrası)
   - STORY-005: Front-end framework ADR (architect, Sprint 1 mid)
   - STORY-006: Persistence layer ADR (architect, Sprint 2 prep)
   - STORY-007: Doctrine conflict — verdict:* sentinel label (architect + owner workflow merge)
   - STORY-008: Watcher dedup fix'i sistemik hale getirme (B+E önerisi)

4. **Owner answers to 5 vision Open Questions** — Sprint 1 grooming block'lanmaması için

**Sprint 1 plan document:** Will be created at `/sprint-start` invocation.

— Orchestrator, 2026-06-17T17:55:00+03:00
