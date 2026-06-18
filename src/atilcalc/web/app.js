// AtilCalculator — Web Components + keyboard FSM (STORY-003a).
//
// Per ADR-0018: vanilla JS, no build step, dark skin default, CSS custom
// properties. Per ADR-0019: the global keydown listener routes to an FSM
// that builds an expression and calls POST /api/evaluate on Enter.
//
// 3 states: idle → entering → evaluated → entering (on next digit).
// Allowed keys: 0-9, + - * /, ( ), Enter, Escape, Backspace, . — anything
// else is silently ignored.

const ALLOWED_KEYS = new Set([
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
  "+", "-", "*", "/",
  "(", ")",
  ".",
]);

// ----------------------------------------------------------------------------
// <atilcalc-display> — input/result line
// ----------------------------------------------------------------------------
class AtilcalcDisplay extends HTMLElement {
  static get observedAttributes() {
    return ["value", "result"];
  }

  constructor() {
    super();
    this.attachShadow({ mode: "open" });
  }

  connectedCallback() {
    this._render();
  }

  attributeChangedCallback() {
    this._render();
  }

  setInput(s) {
    this.setAttribute("value", s);
    this.dispatchEvent(new CustomEvent("display:change", { detail: { value: s } }));
  }

  setResult(s) {
    this.setAttribute("result", s);
    this.dispatchEvent(new CustomEvent("display:change", { detail: { result: s } }));
  }

  clear() {
    this.setInput("");
    this.setResult("");
  }

  _render() {
    if (!this.shadowRoot.innerHTML) {
      this.shadowRoot.innerHTML = `
        <style>
          :host {
            display: block;
            font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
            background: var(--calc-display-bg, #1e1e1e);
            color: var(--calc-display-fg, #f0f0f0);
            padding: 1rem;
            border-radius: 0.5rem;
            text-align: right;
            min-height: 4rem;
          }
          .input { font-size: 1.5rem; opacity: 0.9; min-height: 1.5rem; }
          .result { font-size: 2rem; font-weight: 600; min-height: 2rem; margin-top: 0.25rem; }
          .placeholder { opacity: 0.4; font-style: italic; }
        </style>
        <div class="input" id="input"></div>
        <div class="result" id="result"></div>
      `;
    }
    const input = this.shadowRoot.getElementById("input");
    const result = this.shadowRoot.getElementById("result");
    if (input) {
      const v = this.getAttribute("value") || "";
      input.innerHTML = v ? v : '<span class="placeholder">0</span>';
    }
    if (result) {
      result.textContent = this.getAttribute("result") || "";
    }
  }
}

customElements.define("atilcalc-display", AtilcalcDisplay);

// ----------------------------------------------------------------------------
// <atilcalc-keypad> — on-screen button grid (mouse + keyboard mirror)
// ----------------------------------------------------------------------------
class AtilcalcKeypad extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: "open" });
  }

  connectedCallback() {
    if (this.shadowRoot.innerHTML) return;
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; }
        .grid {
          display: grid;
          grid-template-columns: repeat(4, 1fr);
          gap: 0.5rem;
        }
        button {
          padding: 1rem;
          font-size: 1.25rem;
          border: 1px solid var(--calc-keypad-border, #333);
          background: var(--calc-keypad-bg, #2a2a2a);
          color: var(--calc-keypad-fg, #f0f0f0);
          border-radius: 0.5rem;
          cursor: pointer;
        }
        button:hover { background: var(--calc-keypad-hover, #3a3a3a); }
        button.op { background: var(--calc-op-bg, #3a4a5a); }
        button.eq { background: var(--calc-eq-bg, #2a6a3a); grid-column: span 2; }
        button.clr { background: var(--calc-clr-bg, #5a2a2a); }
      </style>
      <div class="grid">
        <button class="clr" data-k="Escape">C</button>
        <button data-k="Backspace">⌫</button>
        <button class="op" data-k="/">÷</button>
        <button class="op" data-k="*">×</button>
        <button data-k="7">7</button><button data-k="8">8</button>
        <button data-k="9">9</button><button class="op" data-k="-">−</button>
        <button data-k="4">4</button><button data-k="5">5</button>
        <button data-k="6">6</button><button class="op" data-k="+">+</button>
        <button data-k="1">1</button><button data-k="2">2</button>
        <button data-k="3">3</button><button data-k="(">(</button>
        <button data-k="0">0</button><button data-k=".">.</button>
        <button data-k=")">)</button><button class="eq" data-k="Enter">=</button>
      </div>
    `;
    this.shadowRoot.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("click", () => {
        this.dispatchEvent(
          new CustomEvent("keypad:press", {
            detail: { type: btn.dataset.k, value: btn.textContent },
            bubbles: true,
            composed: true,
          })
        );
      });
    });
  }
}

customElements.define("atilcalc-keypad", AtilcalcKeypad);

// ----------------------------------------------------------------------------
// <atilcalc-history> — last-N evaluations list
// ----------------------------------------------------------------------------
class AtilcalcHistory extends HTMLElement {
  static get observedAttributes() {
    return ["limit"];
  }

  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._entries = [];
  }

  connectedCallback() {
    this._render();
  }

  pushEntry(expr, result) {
    this._entries.unshift({ expr, result });
    const limit = parseInt(this.getAttribute("limit") || "50", 10);
    if (this._entries.length > limit) this._entries.length = limit;
    this._render();
    this.dispatchEvent(new CustomEvent("history:change", { detail: { entries: this._entries } }));
  }

  clear() {
    this._entries = [];
    this._render();
  }

  _render() {
    if (!this.shadowRoot.innerHTML) {
      this.shadowRoot.innerHTML = `
        <style>
          :host {
            display: block;
            max-height: 12rem;
            overflow-y: auto;
            background: var(--calc-history-bg, #181818);
            color: var(--calc-history-fg, #c0c0c0);
            padding: 0.5rem;
            border-radius: 0.5rem;
            font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.9rem;
          }
          .entry { padding: 0.25rem 0.5rem; border-bottom: 1px solid #2a2a2a; }
          .entry:last-child { border-bottom: none; }
          .expr { opacity: 0.7; }
          .result { font-weight: 600; float: right; }
          .empty { opacity: 0.4; font-style: italic; }
        </style>
        <div id="list"></div>
      `;
    }
    const list = this.shadowRoot.getElementById("list");
    if (this._entries.length === 0) {
      list.innerHTML = '<div class="empty">(no history yet)</div>';
      return;
    }
    list.innerHTML = this._entries
      .map(
        (e) =>
          `<div class="entry"><span class="expr">${e.expr}</span><span class="result">${e.result}</span></div>`
      )
      .join("");
  }
}

customElements.define("atilcalc-history", AtilcalcHistory);

// ----------------------------------------------------------------------------
// Global keyboard FSM (ADR-0019 §Observability + keyboard input layer)
// ----------------------------------------------------------------------------
const STATE = { IDLE: "idle", ENTERING: "entering", EVALUATED: "evaluated" };

const display = document.querySelector("atilcalc-display");
const history = document.querySelector("atilcalc-history");

let state = STATE.IDLE;
let currentInput = "";

function setInput(s) {
  currentInput = s;
  if (display) display.setInput(s);
}

function appendKey(k) {
  if (state === STATE.EVALUATED) {
    // After evaluation, the next digit starts a fresh input.
    setInput(k);
    state = STATE.ENTERING;
  } else {
    setInput(currentInput + k);
    state = STATE.ENTERING;
  }
}

function clearInput() {
  setInput("");
  state = STATE.IDLE;
}

function backspace() {
  if (currentInput.length === 0) return;
  setInput(currentInput.slice(0, -1));
  if (currentInput.length === 0) state = STATE.IDLE;
}

async function evaluate() {
  if (currentInput.length === 0) return;
  state = STATE.EVALUATED;
  try {
    const resp = await fetch("/api/evaluate", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ expr: currentInput }),
    });
    if (!resp.ok) {
      const body = await resp.json().catch(() => ({}));
      const errType = body?.error?.type || `HTTP ${resp.status}`;
      if (display) display.setResult(`error: ${errType}`);
      return;
    }
    const body = await resp.json();
    if (display) display.setResult(body.result);
    if (history) history.pushEntry(currentInput, body.result);
  } catch (err) {
    if (display) display.setResult(`error: network`);
  }
}

document.addEventListener("keydown", (ev) => {
  const k = ev.key;
  if (k === "Enter") {
    ev.preventDefault();
    evaluate();
    return;
  }
  if (k === "Escape") {
    ev.preventDefault();
    clearInput();
    return;
  }
  if (k === "Backspace") {
    ev.preventDefault();
    backspace();
    return;
  }
  if (ALLOWED_KEYS.has(k)) {
    ev.preventDefault();
    appendKey(k);
  }
  // Unknown keys: silently ignored (per contract test_keyboard_fsm.py).
});

// Mouse-driven input via the keypad (mirror of keyboard FSM).
document.addEventListener("keypad:press", (ev) => {
  const k = ev.detail.type;
  if (k === "Enter") return evaluate();
  if (k === "Escape") return clearInput();
  if (k === "Backspace") return backspace();
  if (ALLOWED_KEYS.has(k)) return appendKey(k);
});
