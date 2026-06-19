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
// <atilcalc-history> — last-N evaluations list (STORY-008 wiring)
// ----------------------------------------------------------------------------
// Sprint 1 surface (pushEntry, clear, history:change event) PRESERVED.
// STORY-008 adds: loadPage({limit?, before?, q?}), search(q), retry(), and
// history:entry-selected + history:error events. AC1 (initial render via
// GET /api/history) wired here; AC2-AC6 in follow-up commits.
// ----------------------------------------------------------------------------
class AtilcalcHistory extends HTMLElement {
  static get observedAttributes() {
    return ["limit"];
  }

  constructor() {
    super();
    this.attachShadow({ mode: "open" });
    this._entries = [];
    this._loading = false;
    this._error = null;
  }

  connectedCallback() {
    this._render();
    // AC1: initial fetch on mount. Errors are non-fatal — render shows
    // (no history yet) and history:error event fires for the parent.
    this.loadPage({ limit: this.limit }).catch(() => {});
    this._bindSearch();
    this._bindEntrySelection();
  }

  get limit() {
    return parseInt(this.getAttribute("limit") || "50", 10);
  }

  // loadPage — fetch a page from GET /api/history. Replaces _entries on
  // success. Preserves AC4 optimistic-append semantics: callers that want
  // optimistic prepend + background re-sync should call pushEntry() first
  // (Sprint 1 surface), which itself triggers loadPage() in the background.
  async loadPage({ limit, before, q } = {}) {
    const params = new URLSearchParams();
    params.set("limit", String(limit || this.limit));
    if (before) params.set("before", before);
    if (q) params.set("q", q);

    this._loading = true;
    this._error = null;
    this._render();

    try {
      const resp = await fetch(`/api/history?${params}`);
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      const data = await resp.json();
      this._entries = (data.history || []).slice(0, this.limit);
      this._loading = false;
      this._render();
      this.dispatchEvent(new CustomEvent("history:change", { detail: { entries: this._entries } }));
    } catch (err) {
      this._loading = false;
      this._error = err.message;
      this._render();
      this.dispatchEvent(new CustomEvent("history:error", { detail: { phase: "load", error: err.message } }));
    }
  }

  // search — AC2. Same as loadPage with q param; debounce lives in input
  // handler (added in AC2 commit). Provided as a method so the parent or
  // tests can trigger search programmatically.
  search(q) {
    return this.loadPage({ limit: this.limit, q });
  }

  // retry — AC6. Manual retry after retry-exhausted state. Just re-runs
  // loadPage; the per-request backoff (250/500/1000ms, max 3) lives in
  // _fetchWithBackoff (added in AC6 commit).
  retry() {
    return this.loadPage({ limit: this.limit });
  }

  // pushEntry — Sprint 1 surface PRESERVED. Adds optimistically to the head
  // of _entries, then triggers background re-sync against the backend
  // (AC4 optimistic-append contract).
  pushEntry(expr, result) {
    this._entries.unshift({ expr, result, ts: new Date().toISOString() });
    if (this._entries.length > this.limit) this._entries.length = this.limit;
    this._render();
    this.dispatchEvent(new CustomEvent("history:change", { detail: { entries: this._entries } }));
    // Background re-sync — fire-and-forget; errors surface via history:error.
    this.loadPage({ limit: this.limit }).catch(() => {});
  }

  clear() {
    this._entries = [];
    this._render();
  }

  // _bindSearch — AC2. Wires the search input's `input` event to a debounced
  // call to search(). Debounce window: 100ms (matches AC2 perf budget; per
  // PR #103 backoff alignment the spec uses 100ms debounce). Re-binds are
  // no-ops (idempotent via _searchBound guard).
  _bindSearch() {
    if (this._searchBound) return;
    const input = this.shadowRoot.querySelector("input[type=search]");
    if (!input) return;
    this._searchBound = true;
    this._searchDebounce = null;
    input.addEventListener("input", () => {
      clearTimeout(this._searchDebounce);
      const q = input.value;
      this._searchDebounce = setTimeout(() => {
        this.search(q).catch(() => {});
      }, 100);
    });
  }

  // _bindEntrySelection — AC3. Wires click + keydown(Enter) on .entry
  // elements (delegated on shadowRoot). Dispatches history:entry-selected
  // event with {expr, result, ts} detail. Idempotent via _entrySelBound.
  _bindEntrySelection() {
    if (this._entrySelBound) return;
    const list = this.shadowRoot.getElementById("list");
    if (!list) return;
    this._entrySelBound = true;
    const select = (target) => {
      const entry = target.closest(".entry");
      if (!entry) return;
      const expr = entry.getAttribute("data-expr") || "";
      const result = entry.getAttribute("data-result") || "";
      const ts = entry.getAttribute("data-ts") || "";
      this.dispatchEvent(new CustomEvent("history:entry-selected", {
        bubbles: true,
        composed: true,
        detail: { expr, result, ts }
      }));
    };
    list.addEventListener("click", (ev) => select(ev.target));
    list.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter") {
        ev.preventDefault();
        select(ev.target);
      }
    });
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
          input[type=search] {
            width: 100%;
            box-sizing: border-box;
            background: rgba(255,255,255,0.05);
            color: var(--calc-history-fg, #c0c0c0);
            border: 1px solid rgba(255,255,255,0.1);
            border-radius: 0.25rem;
            padding: 0.25rem 0.5rem;
            margin-bottom: 0.5rem;
            font-family: inherit;
            font-size: inherit;
          }
          input[type=search]:focus { outline: none; border-color: var(--calc-history-fg, #c0c0c0); }
          .entry { padding: 0.25rem 0.5rem; border-bottom: 1px solid #2a2a2a; cursor: pointer; }
          .entry:last-child { border-bottom: none; }
          .entry:hover { background: rgba(255,255,255,0.05); }
          .entry:focus { outline: 2px solid var(--calc-history-fg, #c0c0c0); outline-offset: -2px; }
          .expr { opacity: 0.7; }
          .result { font-weight: 600; float: right; }
          .empty { opacity: 0.4; font-style: italic; }
          .loading { opacity: 0.5; font-style: italic; }
          .error { opacity: 0.7; color: #ff8080; font-style: italic; }
        </style>
        <input type="search" class="search" placeholder="Search history…" aria-label="Search history" />
        <div id="list"></div>
      `;
      // _render just replaced innerHTML — rebind the search input listener.
      this._searchBound = false;
      this._bindSearch();
      this._entrySelBound = false;
      this._bindEntrySelection();
    }
    const list = this.shadowRoot.getElementById("list");
    if (this._loading && this._entries.length === 0) {
      list.innerHTML = '<div class="loading">(loading history…)</div>';
      return;
    }
    if (this._error && this._entries.length === 0) {
      list.innerHTML = `<div class="error">(history unavailable: ${this._error})</div>`;
      return;
    }
    if (this._entries.length === 0) {
      list.innerHTML = '<div class="empty">(no history yet)</div>';
      return;
    }
    list.innerHTML = this._entries
      .map(
        (e) =>
          `<div class="entry" tabindex="0" data-ts="${e.ts || ""}" data-expr="${(e.expr || "").replace(/"/g, "&quot;")}" data-result="${(e.result || "").replace(/"/g, "&quot;")}"><span class="expr">${e.expr}</span><span class="result">${e.result}</span></div>`
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

// AC3: <atilcalc-history> dispatches history:entry-selected on click + Enter.
// Wire it to populate the display (input + result line) — Sprint 1's display
// component already exposes setInput + setResult; we just listen at this level
// since the FSM lives here (ADR-0018 §vanilla JS + Web Components).
if (history) {
  history.addEventListener("history:entry-selected", (ev) => {
    const { expr, result } = ev.detail || {};
    if (typeof expr === "string") setInput(expr);
    if (display && typeof result === "string") display.setResult(result);
    state = STATE.ENTERING;
  });
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
      const errMsg = body?.error?.message || resp.statusText || "request failed";
      if (display) display.setResult(`error: ${errType}`);
      // AC3: dispatch engine:error so <atilcalc-error-toast> can render.
      document.dispatchEvent(
        new CustomEvent("engine:error", {
          detail: { type: errType, message: errMsg, status: resp.status },
        })
      );
      return;
    }
    const body = await resp.json();
    if (display) display.setResult(body.result);
    if (history) history.pushEntry(currentInput, body.result);
  } catch (err) {
    if (display) display.setResult(`error: network`);
    document.dispatchEvent(
      new CustomEvent("engine:error", {
        detail: { type: "NetworkError", message: String(err) },
      })
    );
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
    // The help pop-up and error-toast each have their own Esc handlers
    // (registered with stopPropagation) that fire first when they're
    // open. The fallthrough here clears the input.
    clearInput();
    return;
  }
  if (k === "Backspace") {
    ev.preventDefault();
    backspace();
    return;
  }
  // AC2: `?` opens the keyboard-shortcut help pop-up.
  if (k === "?") {
    ev.preventDefault();
    document.dispatchEvent(new CustomEvent("help:open"));
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
