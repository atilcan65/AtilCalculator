"""AtilCalculator web shell (STORY-003a).

Per ADR-0018, the web shell is **vanilla JS + Web Components** — no build
step, no npm toolchain, no framework. The browser is the runtime. The
3 Web Components are:

- ``<atilcalc-display>``   — shows current expression + result
- ``<atilcalc-keypad>``    — 4x4 button grid + on-screen feedback
- ``<atilcalc-history>``   — last N evaluations, keyboard-navigable

Plus a 3-state keyboard FSM (idle → entering → evaluated) that gates
which keys are accepted at any moment (per AC2/3/5/6 of STORY-003a).

The bootstrap commit leaves this directory with a minimal HTML shell;
the Web Components + FSM land in the TDD-green commits per the contract
suite (PR #37 tests/web/) and d007 T1 (which only checks api/, not web/).
"""
