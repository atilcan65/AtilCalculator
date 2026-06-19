// AtilCalculator — skin system (STORY-009, refs #71).
//
// AC1 + AC6: 3 skin files (dark, light, retro) live in src/atilcalc/web/skins/.
// AC2: <500ms transition — body has `transition: background 200ms, color 200ms`
//      in styles.css. GPU-compositable properties only (no box-shadow/filter).
// AC3: cross-reload persistence via localStorage (Story-010 will swap to
//      SQLite-backed for cross-device persistence; localStorage stays as
//      the per-session fallback so the spec AC3 holds in MVP-1).
//
// On load:
//   1. Read localStorage("atilcalc-skin") — if valid + matches a known skin,
//      apply that. Otherwise fetch GET /api/skin (server's source of truth)
//      and apply. If both fail, fall back to "dark".
//   2. Subscribe to `skin:change` events from <atilcalc-mode-toggle>; on
//      change, PUT /api/skin + Idempotency-Key + update localStorage.
//   3. Skin palette is CSS-driven (each skin CSS file defines its own
//      :root[data-skin="<name>"] block); this script only flips the
//      data-skin attribute on <html> so the right cascade applies.

const SKINS_DIR = "/skins";  // served as static files via FastAPI mount
const KNOWN_SKINS = ["dark", "light", "retro"];
const STORAGE_KEY = "atilcalc-skin";
const DEFAULT_SKIN = "dark";

function _isValidSkin(name) {
  return typeof name === "string" && KNOWN_SKINS.includes(name);
}

function _readLocalStorage() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return _isValidSkin(stored) ? stored : null;
  } catch (_e) {
    return null;  // SSR or disabled storage
  }
}

function _writeLocalStorage(skin) {
  try {
    localStorage.setItem(STORAGE_KEY, skin);
  } catch (_e) {
    // best-effort
  }
}

function applySkin(skin) {
  const target = _isValidSkin(skin) ? skin : DEFAULT_SKIN;
  // Set data-skin on <html> so the right :root[data-skin="..."] block
  // (from skins/<name>.css) applies.
  document.documentElement.dataset.skin = target;
  document.body.dataset.skin = target;
  _writeLocalStorage(target);
}

async function fetchCurrentSkin() {
  try {
    const resp = await fetch("/api/skin", { method: "GET" });
    if (!resp.ok) return DEFAULT_SKIN;
    const body = await resp.json();
    return _isValidSkin(body.skin) ? body.skin : DEFAULT_SKIN;
  } catch (_e) {
    return DEFAULT_SKIN;
  }
}

async function putSkin(skin, idempotencyKey) {
  try {
    const resp = await fetch("/api/skin", {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "Idempotency-Key": idempotencyKey,
      },
      body: JSON.stringify({ skin }),
    });
    return resp.ok;
  } catch (_e) {
    return false;
  }
}

function _uuidV4() {
  // Lightweight UUID v4 (crypto.randomUUID is widely available, but fallback
  // for old browsers + test environments).
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return "00000000-0000-4000-8000-" + Math.floor(Math.random() * 10 ** 12).toString(16).padStart(12, "0");
}

async function initTheme() {
  // Priority: localStorage (fast) → server (source of truth) → default.
  const local = _readLocalStorage();
  if (local) {
    applySkin(local);
  } else {
    const serverSkin = await fetchCurrentSkin();
    applySkin(serverSkin);
  }

  // Sync the toggle's `active` attribute with the applied skin so the
  // UI reflects the correct state on load.
  const toggle = document.querySelector("atilcalc-mode-toggle");
  if (toggle) {
    toggle.setAttribute("active", document.documentElement.dataset.skin || DEFAULT_SKIN);
  }

  // Persist user-initiated skin changes from the toggle.
  document.addEventListener("skin:change", async (ev) => {
    const skin = ev.detail && ev.detail.skin;
    if (!_isValidSkin(skin)) return;
    applySkin(skin);
    // Push to server so it becomes the server-side default for the next
    // page load + cross-session (when STORY-010 lands, persistence layer
    // will read from SQLite instead of in-memory).
    await putSkin(skin, _uuidV4());
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initTheme);
} else {
  initTheme();
}