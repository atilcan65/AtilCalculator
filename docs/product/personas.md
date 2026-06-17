# Personas — AtilCalculator

> Derived from [Issue #4](https://github.com/atilcan65/AtilCalculator/issues/4) (vision intake, 2026-06-17). PM-canonicalised for the dev-studio team.
>
> **PM invariants honoured**: (a) personas map 1:1 to the "Target Users" section of the vision intake — no third persona invented for completeness; (b) the future persona (P2) is **explicitly marked out of MVP**, not slipped into scope.

## P1 — "Atil" (the owner-operator) — **MVP persona**

- **Profile**: Software/infrastructure professional. Comfortable across the stack — Proxmox, Docker, systemd, nginx. Keyboard-intensive worker. Owns the LAN, the VM (Ubuntu 24.04 LTS at `192.168.1.199`), the deployment, and the Sudo account (`atilcan`). Self-describes in Turkish; the team's working language is English.
- **Context**:
  - **Frequency**: 5–20 quick calculations per day — interest, rate conversions, engineering arithmetic, ad-hoc numbers from meetings/notes/Slack.
  - **Device**: Desktop browser, **always-open tab**; sometimes a laptop on the same LAN. Mobile is not a target surface for MVP.
  - **Time of day**: Mostly working hours, but not a 9-to-5 gate — any moment a number comes up.
  - **Duration per session**: 5–120 seconds per calculation; multiplies to a few hours per week of tool time.
- **Pain points** (the ones the product dissolves):
  - **Float errors** showing up in routine arithmetic (`0.1 + 0.2`, compound interest, percentage chains).
  - **History loss** — can't find "that calculation from last Tuesday" across devices or across days.
  - **Mouse lock-in** — having to break flow to grab the pointer for a routine operation.
  - **Style mismatch** — dark/light/retro/minimal preference changes day-to-day; the standard calculator doesn't accommodate.
  - **Privacy** — not wanting to leak inputs (interest, salary math, ad-hoc numbers) to ad-funded online calculators.
- **Success looks like**:
  - The calculator is **always open** in a browser tab; never has to launch a separate app or open a new tab to a sketchy site.
  - **Keyboard-only** from tab-switch to result — no mouse, no mental context switch, no `Cmd+Tab` out of the IDE.
  - Past calculations are **findable** — substring search across days/weeks/months, click-to-load back into the input.
  - The displayed number is **always exact** — no surprise rounding, no `0.30000000000000004`, no silent precision loss.
  - The visual style **adapts to the moment** — dark at night, retro when reviewing old code, minimal when reading alongside text.
  - The thing is **his**, under his control, on his hardware, exposed to nobody but himself and his LAN.
- **Failure mode (what makes him walk away)**:
  - The product introduces a new float error class — e.g., scientific functions silently lose precision.
  - History becomes per-device (browser `localStorage`) and he can't find calculations on the laptop that he did on the desktop.
  - The keyboard handler is buggy and the tab is the only keyboard target — a single missed key takes him back to the OS calculator.
  - The HTTP surface is exposed without VM hardening, and a LAN-side actor pokes at it.
- **Quote (paraphrased from intake)**: *"Tarayıcı sekmesi olarak her zaman açık. Geçmiş hesaplarını günler/haftalar sonra geri bulmak ister. Skin tercihi günden güne değişebilir."*
  ("Always open as a browser tab. Wants to find past calculations days/weeks later. Skin preference can change day-to-day.")

## P2 — "Home guest" — **NOT in MVP** (future epic)

- **Profile**: Anyone on the owner's LAN with a browser. Family member, roommate, or visiting friend. **Not authenticated** (per the vision's non-goals).
- **Context**: Wants to do a one-off calculation (splitting a bill, a tip, a unit conversion). Doesn't want to install an app. Trusts the owner's network.
- **Pain points** (future, when this persona gets a build): The owner's single-user calculator doesn't have a "guest" lane; either the guest has to ask the owner to use the shared tab, or they end up on a sketchy online calculator.
- **Success looks like (future)**: Open `http://192.168.1.199/` on any LAN device, type, get a result. No login. **Shared history namespace** (intentional — this is a "house calculator," not a personal one for guests).
- **Why not in MVP** (per the vision's Out-of-scope list and the intake's "Multi-user MVP scope'unda YOK; ileride epic"):
  - Multi-user data model work (shared vs per-user history) is non-trivial — it forces a real auth/authz decision, which the vision explicitly defers.
  - The security review for LAN-exposure hardening hasn't happened yet (it's flagged as a Sprint 0/1 ops story).
  - The owner is the only user; building P2 before P1 is solid is premature.
- **Trigger for the future epic** (when the owner feels the pain): the owner asks "can my partner / my flatmate also use this from their laptop?" That's the signal to open the P2 epic and start the auth + multi-user data model work as a separate, larger story.

## PM's anti-pattern check (self-audit)

- ✅ No persona invented outside what the owner described in the intake form.
- ✅ Personas map directly to the "Target Users" section. No third persona invented.
- ✅ P2 is **explicitly future**, not slipped into the MVP scope.
- ✅ Failure mode and "walk-away" conditions are spelled out for P1 — the success criteria in `vision.md` M1–M5 are traceable back to these.
- ✅ No implementation hints in this file (no "use React," no "use PostgreSQL") — those are architect's calls.
