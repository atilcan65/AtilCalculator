// AtilCalculator — deferred Web Components (STORY-003b + STORY-012).
//
// Per ADR-0018: vanilla JS, no build step, dark skin default, CSS custom
// properties. Three components split out of the STORY-003a app.js so the
// app.js diff stays minimal and reviewable. Each component uses open
// Shadow DOM (matches the existing 3 components from STORY-003a).
//
// STORY-012: the help-popup's keyboard shortcut list is now data-driven
// from src/atilcalc/web/shortcuts.js (single source of truth per
// ADR-0023 §Help popup content). The popup renders 3 sections — Basic,
// History, Scientific — covering all 19 shortcuts.
//
// 1. <atilcalc-mode-toggle> — 3-button group (dark / light / retro). Click
//    sets a `data-skin` attribute on <body> and dispatches a `skin:change`
//    event. The skin system (commit 3) listens for that event and swaps
//    the CSS custom properties.
//
// 2. <atilcalc-help-popup> — modal <dialog> listing all keyboard shortcuts.
//    Opened by dispatching a `help:open` event (FSM wires `?` to it in
//    commit 4). Closes on Esc or click outside. The help list is rendered
//    into the shadow DOM from a small data structure so it stays in sync
//    with the FSM's allowlist (commit 4 single source of truth).
//
// 3. <atilcalc-error-toast> — transient banner that listens for
//    `engine:error` CustomEvents (dispatched by the FSM in commit 4 on
//    4xx/5xx responses). Auto-dismisses after 5s (configurable via the
//    `duration` observedAttribute; AC3 + TC-3 cover both auto-dismiss
//    and Esc-dismiss).

// ----------------------------------------------------------------------------
// <atilcalc-mode-toggle> — dark / light / retro skin switcher
// ----------------------------------------------------------------------------
class AtilcalcModeToggle extends HTMLElement {
  static get observedAttributes() {
    return ["active"];
  }

  constructor() {
    super();
    this.attachShadow({ mode: "open" });
  }

  connectedCallback() {
    if (this.shadowRoot.innerHTML) return;
    this.shadowRoot.innerHTML = `
      <style>
        :host {
          display: inline-flex;
          gap: 0.25rem;
          padding: 0.25rem;
          border: 1px solid var(--calc-keypad-border, #333);
          border-radius: 0.5rem;
          background: var(--calc-keypad-bg, #2a2a2a);
        }
        button {
          padding: 0.5rem 0.75rem;
          font-size: 0.875rem;
          border: 1px solid transparent;
          background: transparent;
          color: var(--calc-keypad-fg, #f0f0f0);
          border-radius: 0.375rem;
          cursor: pointer;
          font-family: inherit;
        }
        button[aria-pressed="true"] {
          background: var(--calc-op-bg, #3a4a5a);
          border-color: var(--calc-keypad-border, #333);
        }
        button:hover { background: var(--calc-keypad-hover, #3a3a3a); }
      </style>
      <button type="button" data-skin="dark" aria-pressed="false">dark</button>
      <button type="button" data-skin="light" aria-pressed="false">light</button>
      <button type="button" data-skin="retro" aria-pressed="false">retro</button>
    `;
    this.shadowRoot.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("click", () => {
        const skin = btn.dataset.skin;
        this.setAttribute("active", skin);
        document.body.dataset.skin = skin;
        this.dispatchEvent(
          new CustomEvent("skin:change", {
            detail: { skin },
            bubbles: true,
            composed: true,
          })
        );
      });
    });
    this._syncActive();
  }

  attributeChangedCallback() {
    this._syncActive();
  }

  _syncActive() {
    const active = this.getAttribute("active") || "dark";
    this.shadowRoot.querySelectorAll("button").forEach((btn) => {
      btn.setAttribute("aria-pressed", btn.dataset.skin === active ? "true" : "false");
    });
  }
}

customElements.define("atilcalc-mode-toggle", AtilcalcModeToggle);

// ----------------------------------------------------------------------------
// <atilcalc-help-popup> — modal keyboard-shortcut reference
// ----------------------------------------------------------------------------
// Import the shortcut registry (single source of truth per ADR-0023).
// The registry drives both the keyboard FSM (app.js) and this popup.
import { SHORTCUTS } from "./shortcuts.js";

const HELP_SECTIONS = [
  { id: "basic", title: "Basic" },
  { id: "history", title: "History" },
  { id: "scientific", title: "Scientific" },
];

class AtilcalcHelpPopup extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._open = false;
  }

  connectedCallback() {
    if (this.shadowRoot.innerHTML) return;
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: contents; }
        .backdrop {
          position: fixed; inset: 0;
          background: rgba(0, 0, 0, 0.6);
          display: none; align-items: center; justify-content: center;
          z-index: 1000;
        }
        :host([open]) .backdrop { display: flex; }
        dialog {
          background: var(--calc-display-bg, #1e1e1e);
          color: var(--calc-display-fg, #f0f0f0);
          border: 1px solid var(--calc-keypad-border, #333);
          border-radius: 0.5rem;
          padding: 1.5rem;
          min-width: 18rem;
          max-width: 32rem;
          font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
        }
        h2 { margin: 0 0 0.75rem 0; font-size: 1.1rem; }
        h3 {
          margin: 1rem 0 0.4rem 0;
          font-size: 0.95rem;
          color: var(--calc-display-fg, #f0f0f0);
          border-bottom: 1px solid var(--calc-keypad-border, #333);
          padding-bottom: 0.2rem;
        }
        .help-section:first-of-type h3 { margin-top: 0; }
        table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
        th, td { text-align: left; padding: 0.25rem 0.5rem; }
        th { border-bottom: 1px solid var(--calc-keypad-border, #333); }
        kbd {
          background: var(--calc-keypad-bg, #2a2a2a);
          padding: 0.1rem 0.4rem; border-radius: 0.25rem;
          border: 1px solid var(--calc-keypad-border, #333);
        }
      </style>
      <div class="backdrop" part="backdrop">
        <dialog open>
          <h2>Keyboard shortcuts</h2>
          ${HELP_SECTIONS.map(
            (section) => {
              const items = SHORTCUTS[section.id] || [];
              return `
                <section class="help-section" data-section="${section.id}">
                  <h3>${section.title}</h3>
                  <table><tbody>
                    ${items
                      .map(
                        (s) =>
                          `<tr><th><kbd>${s.keys}</kbd></th><td>${s.action}</td></tr>`
                      )
                      .join("")}
                  </tbody></table>
                </section>
              `;
            }
          ).join("")}
        </dialog>
      </div>
    `;
    this.shadowRoot.querySelector(".backdrop").addEventListener("click", (ev) => {
      // close on click outside the dialog
      if (ev.target === ev.currentTarget) this.close();
    });
    this.addEventListener("keydown", (ev) => {
      if (ev.key === "Escape" && this._open) {
        ev.stopPropagation();
        this.close();
      }
    });
    document.addEventListener("help:open", () => this.open());
    document.addEventListener("help:close", () => this.close());
  }

  open() {
    this._open = true;
    this.setAttribute("open", "");
    // focus trap (lightweight) — focus first <kbd> in the dialog
    const firstKbd = this.shadowRoot.querySelector("kbd");
    if (firstKbd) firstKbd.focus();
  }

  close() {
    this._open = false;
    this.removeAttribute("open");
  }
}

customElements.define("atilcalc-help-popup", AtilcalcHelpPopup);

// ----------------------------------------------------------------------------
// <atilcalc-error-toast> — transient error banner
// ----------------------------------------------------------------------------
class AtilcalcErrorToast extends HTMLElement {
  static get observedAttributes() {
    return ["duration"];
  }

  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._timer = null;
  }

  connectedCallback() {
    if (this.shadowRoot.innerHTML) return;
    this.shadowRoot.innerHTML = `
      <style>
        :host {
          position: fixed; top: 1rem; left: 50%;
          transform: translateX(-50%);
          z-index: 1100;
          display: none;
          max-width: 90vw;
        }
        :host([visible]) { display: block; }
        .toast {
          background: var(--calc-clr-bg, #5a2a2a);
          color: #fff;
          padding: 0.75rem 1.25rem;
          border-radius: 0.5rem;
          font-family: system-ui, sans-serif;
          font-size: 0.95rem;
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
        }
        .type { font-weight: 700; margin-right: 0.5rem; }
      </style>
      <div class="toast" role="alert" aria-live="assertive">
        <span class="type" id="type"></span><span id="msg"></span>
      </div>
    `;
    document.addEventListener("engine:error", (ev) => this.show(ev.detail));
    document.addEventListener("engine:error:clear", () => this.hide());
    document.addEventListener("keydown", (ev) => {
      if (ev.key === "Escape" && this.hasAttribute("visible")) {
        ev.stopPropagation();
        this.hide();
      }
    });
  }

  attributeChangedCallback(_name, _old, _new) {
    // duration change is honoured on the next show() call.
  }

  show(detail) {
    const typeEl = this.shadowRoot.getElementById("type");
    const msgEl = this.shadowRoot.getElementById("msg");
    if (typeEl) typeEl.textContent = (detail && detail.type) || "error";
    if (msgEl) msgEl.textContent = (detail && detail.message) || "";
    this.setAttribute("visible", "");
    if (this._timer) clearTimeout(this._timer);
    const ms = parseInt(this.getAttribute("duration") || "5000", 10);
    this._timer = setTimeout(() => this.hide(), ms);
  }

  hide() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
    }
    this.removeAttribute("visible");
  }
}

customElements.define("atilcalc-error-toast", AtilcalcErrorToast);
