// AtilCalculator — skin system (STORY-003b commit 3).
//
// Subscribes to the `skin:change` CustomEvent dispatched by
// <atilcalc-mode-toggle> (defined in app-deferred.js) and swaps the
// 14 CSS custom properties on :root that styles.css consumes.
//
// AC6: <500ms transition. The body element gets a `transition:
// background 200ms, color 200ms` rule (added to styles.css in this
// commit) so the swap animates via the compositor instead of
// reflowing layout. We deliberately transition only `background` and
// `color` — these are GPU-compositable. `box-shadow` and `filter` are
// NOT transitioned (would be expensive on large surfaces).
//
// Palettes match the vision M4 spec: dark = #121212 (AtilCalculator
// default since STORY-001), light = #ffffff, retro = green CRT
// (#0a1a0a background + #33ff33 foreground — the Atil-suggested
// retro look from backlog grooming #22).

const PALETTES = {
  dark: {
    "--calc-bg": "#121212",
    "--calc-fg": "#f0f0f0",
    "--calc-display-bg": "#1e1e1e",
    "--calc-display-fg": "#f0f0f0",
    "--calc-keypad-bg": "#2a2a2a",
    "--calc-keypad-fg": "#f0f0f0",
    "--calc-keypad-border": "#333",
    "--calc-keypad-hover": "#3a3a3a",
    "--calc-op-bg": "#3a4a5a",
    "--calc-eq-bg": "#2a6a3a",
    "--calc-clr-bg": "#5a2a2a",
    "--calc-history-bg": "#181818",
    "--calc-history-fg": "#c0c0c0",
  },
  light: {
    "--calc-bg": "#ffffff",
    "--calc-fg": "#1a1a1a",
    "--calc-display-bg": "#f7f7f7",
    "--calc-display-fg": "#1a1a1a",
    "--calc-keypad-bg": "#eaeaea",
    "--calc-keypad-fg": "#1a1a1a",
    "--calc-keypad-border": "#cccccc",
    "--calc-keypad-hover": "#d8d8d8",
    "--calc-op-bg": "#cfe2f3",
    "--calc-eq-bg": "#b6d7a8",
    "--calc-clr-bg": "#f4cccc",
    "--calc-history-bg": "#f0f0f0",
    "--calc-history-fg": "#444444",
  },
  retro: {
    "--calc-bg": "#0a1a0a",
    "--calc-fg": "#33ff33",
    "--calc-display-bg": "#0f1f0f",
    "--calc-display-fg": "#33ff33",
    "--calc-keypad-bg": "#0f1f0f",
    "--calc-keypad-fg": "#33ff33",
    "--calc-keypad-border": "#1a3a1a",
    "--calc-keypad-hover": "#1a3a1a",
    "--calc-op-bg": "#1a3a1a",
    "--calc-eq-bg": "#2a5a2a",
    "--calc-clr-bg": "#3a1a1a",
    "--calc-history-bg": "#0a1a0a",
    "--calc-history-fg": "#33ff33",
  },
};

function applySkin(skin) {
  const palette = PALETTES[skin];
  if (!palette) {
    console.warn(`[atilcalc] unknown skin: ${skin}; falling back to dark`);
    return applySkin("dark");
  }
  for (const [prop, value] of Object.entries(palette)) {
    document.documentElement.style.setProperty(prop, value);
  }
  document.body.dataset.skin = skin;
}

function initTheme() {
  // Apply the skin the <atilcalc-mode-toggle> starts with (its
  // `active` attribute, defaulting to "dark"). This way the page
  // loads already styled, not flashing the default :root first.
  const toggle = document.querySelector("atilcalc-mode-toggle");
  const initial = (toggle && toggle.getAttribute("active")) || "dark";
  applySkin(initial);

  // Re-apply on every skin:change from the toggle.
  document.addEventListener("skin:change", (ev) => {
    const skin = ev.detail && ev.detail.skin;
    if (skin) applySkin(skin);
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initTheme);
} else {
  initTheme();
}
