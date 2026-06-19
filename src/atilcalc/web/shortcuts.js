// AtilCalculator — keyboard shortcut registry (STORY-012, ADR-0023).
//
// Single source of truth for both surfaces:
//   - The keyboard FSM in app.js imports SHORTCUT_KEYS + SCIENTIFIC_INSERT
//     to wire single-letter handlers.
//   - The <atilcalc-help-popup> Web Component imports SHORTCUTS to render
//     the 3 sections (Basic | History | Scientific).
//
// Adding/removing a shortcut here updates both surfaces. The bidirectional
// invariant (test_help_popup.py AP-2) asserts that every single-char key
// declared in this registry has a handler in app.js — so the FSM and the
// popup can never drift.

// ----------------------------------------------------------------------------
// 3 sections, 19 total shortcuts (per AC2)
// ----------------------------------------------------------------------------
export const SHORTCUTS = {
  basic: [
    { keys: "0-9", action: "append digits" },
    { keys: "+-*/", action: "append operators" },
    { keys: "Enter", action: "evaluate (equals)" },
    { keys: "Esc", action: "clear input" },
    { keys: "Backspace", action: "delete last char" },
    { keys: "?", action: "open this help" },
  ],
  history: [
    { keys: "↑↓", action: "navigate history" },
    { keys: "Enter", action: "load entry into input" },
    { keys: "/", action: "search-focus" },
    { keys: "Esc", action: "close-search" },
  ],
  scientific: [
    { keys: "s", action: "insert sin(" },
    { keys: "c", action: "insert cos(" },
    { keys: "t", action: "insert tan(" },
    { keys: "l", action: "insert log(" },
    { keys: "n", action: "insert ln(" },
    { keys: "r", action: "insert sqrt(" },
    { keys: "!", action: "factorial" },
    { keys: "d", action: "deg/rad toggle" },
    { keys: "m", action: "mode toggle" },
  ],
};

// ----------------------------------------------------------------------------
// FSM wiring — single-letter keys that must be handled in app.js
// ----------------------------------------------------------------------------
// Keys are listed as a JSON-quoted set so test_help_popup.py AP-2 extracts
// each one: re.findall(r'"([a-zA-Z!?])"', _registry_src) → {"s","c","t",
// "l","n","r","!","d","m","?"}. The assertion then checks each of those
// chars appears in app.js source.
export const SHORTCUT_KEYS = ["s", "c", "t", "l", "n", "r", "!", "d", "m", "?"];

// What the FSM appends for each scientific single-letter key (s/c/t/l/n/r/!).
// The remaining keys (d/m/?) dispatch CustomEvents (see app.js).
export const SCIENTIFIC_INSERT = {
  "s": "sin(",
  "c": "cos(",
  "t": "tan(",
  "l": "log(",
  "n": "ln(",
  "r": "sqrt(",
  "!": "!",
};
