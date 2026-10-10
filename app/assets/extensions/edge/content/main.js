// Velocita content script — isolated world.
//
// Runs at document_start on every frame. Responsibilities:
//   1. Discover <video> and <audio> elements as they appear (MutationObserver).
//   2. Render a small floating download button on each one (top-right).
//   3. Ask the background SW to inject the MAIN-world sniffer once per
//      top-frame.
//   4. Bridge window messages from the MAIN-world sniffer up to the SW
//      via chrome.runtime.sendMessage.
//   5. On button click, ask the SW to pick the best sniffed URL and
//      send it to the Velocita host.
//
// Cross-browser: prefer `browser` (Firefox) over `chrome` (Chromium) and
// polyfill the missing one. Must be plain script (no `import`/`export`)
// so Firefox's MV3 background bundle can run it.

const api = (typeof browser !== "undefined") ? browser : chrome;

// ── helpers ────────────────────────────────────────────────────────

const SEEN = new WeakSet();           // HTMLMediaElement we've already wrapped
const BUTTONS = new WeakMap();       // HTMLMediaElement -> HTMLButtonElement
const HOVER_TIMER = new WeakMap();   // HTMLButtonElement -> { hideAt, armed }
// At most ONE quality menu is open at a time (opening one closes any
// other). Tracked with two plain variables — NOT a WeakMap, because the
// close/cleanup paths need to enumerate the open menu and WeakMap is
// neither iterable nor sized. Lifecycle: showQualityMenu sets both,
// closeAllMenus clears both, removeButton closes when the media owning
// the menu goes away.
let activeMenu = null;               // currently open menu element
let activeMenuMedia = null;          // media element the menu belongs to
const RESIZE_OBSERVERS = new WeakMap(); // HTMLMediaElement -> ResizeObserver

// Pause state (global "pause all" + per-site "pause this site"). Read
// from chrome.storage.local; kept in sync via storage.onChanged so toggles
// in the popup take effect on already-open pages immediately.
let gPaused = false;

function computePaused(velocita) {
  return !velocita ||
    velocita.enabled === false ||
    (Array.isArray(velocita.pausedSites) &&
      velocita.pausedSites.includes(location.hostname));
}

function isMedia(n) {
  return n && (n.tagName === "VIDEO" || n.tagName === "AUDIO");
}

function getIconUrl() {
  // Detect dark mode preference via matchMedia.
  const dark = api?.runtime?.getURL && (
    typeof window !== "undefined" &&
    window.matchMedia &&
    window.matchMedia("(prefers-color-scheme: dark)").matches
  );
  return api.runtime.getURL(dark ? "icons/floating-dark.svg" : "icons/floating.svg");
}
function ensureButton(media) {
  if (!isMedia(media) || SEEN.has(media)) return;
  SEEN.add(media);

  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "velocita-floating velocita-pill";
  btn.setAttribute("aria-label", "Download with Velocita");
  btn.title = "Download with Velocita";

  Object.assign(btn.style, {
    position: "absolute",
    zIndex: "2147483647",
    width: "82px",
    height: "30px",
    borderRadius: "15px",
    border: "0",
    cursor: "pointer",
    top: "8px",
    right: "8px",
    backgroundColor: "rgba(0,0,0,0.62)",
    boxShadow: "0 2px 6px rgba(0,0,0,0.35)",
    color: "#fff",
    padding: "0 10px",
    display: "none",          // shown by reposition() when in viewport
    opacity: "0",
    transition: "opacity 120ms linear",
    fontFamily:
      '-apple-system, "Segoe UI", system-ui, Roboto, sans-serif',
    fontSize: "12px",
    fontWeight: "500",
    lineHeight: "30px",
    letterSpacing: "0.2px",
  });

  // Inline icon + label so the pill width is content-driven.
  const icon = document.createElement("img");
  icon.src = getIconUrl();
  icon.alt = "";
  icon.style.width = "14px";
  icon.style.height = "14px";
  icon.style.marginRight = "6px";
  icon.style.verticalAlign = "-2px";
  btn.appendChild(icon);
  btn.appendChild(document.createTextNode("Save"));

  btn.addEventListener("click", (e) => {
    e.stopPropagation();
    e.preventDefault();
    onDownloadClick(media);
  });

  // Hover-to-show, auto-hide timer (idle 3 s).
  const stateRef = { hideAt: null, armed: false };
  HOVER_TIMER.set(btn, stateRef);
  btn.addEventListener("mouseenter", () => {
    stateRef.armed = true;
    btn.style.opacity = "1";
  });
  btn.addEventListener("mouseleave", () => {
    stateRef.armed = false;
    if (stateRef.hideAt) clearTimeout(stateRef.hideAt);
    stateRef.hideAt = setTimeout(() => {
      if (!stateRef.armed) btn.style.opacity = "0";
    }, 3000);
  });

  document.documentElement.appendChild(btn);
  BUTTONS.set(media, btn);
  reposition(media);

  // ResizeObserver — catches size changes that MutationObserver does
  // not (player expanding its container, CSS-driven resizes, PiP
  // entering/leaving, intrinsic aspect changes after `loadedmetadata`).
  try {
    const ro = new ResizeObserver(() => reposition(media));
    ro.observe(media);
    RESIZE_OBSERVERS.set(media, ro);
  } catch (_) {}

  // Direct media-element events that can shift the player layout
  // (controls appearing/disappearing on play/pause, src swap on
  // `emptied`, PiP transitions). All fire before the next paint, so
  // the pill follows within one frame.
  const onMediaEvent = () => reposition(media);
  for (const ev of [
    "loadedmetadata",
    "emptied",
    "play",
    "pause",
    "ratechange",
    "enterpictureinpicture",
    "leavepictureinpicture",
  ]) {
    media.addEventListener(ev, onMediaEvent, { passive: true });
  }

  // Run an initial hover-show so the user discovers the button.
  setTimeout(() => {
    if (!stateRef.armed) {
      btn.style.opacity = "0.85";
      if (stateRef.hideAt) clearTimeout(stateRef.hideAt);
      stateRef.hideAt = setTimeout(() => {
        if (!stateRef.armed) btn.style.opacity = "0";
      }, 2500);
    }
  }, 600);
}

function removeButton(media) {
  const btn = BUTTONS.get(media);
  if (btn && btn.parentNode) btn.parentNode.removeChild(btn);
  const ro = RESIZE_OBSERVERS.get(media);
  if (ro) {
    ro.disconnect();
    RESIZE_OBSERVERS.delete(media);
  }
  if (activeMenuMedia === media) closeAllMenus();
  BUTTONS.delete(media);
  SEEN.delete(media);
}

function reposition(media) {
  const btn = BUTTONS.get(media);
  if (!btn) return;
  if (gPaused) {
    btn.style.display = "none";
    return;
  }
  const r = media.getBoundingClientRect();
  // Off-screen or tiny — hide.
  const inView = r.width >= 80 && r.height >= 60 &&
    r.bottom > 0 && r.top < window.innerHeight &&
    r.right > 0 && r.left < window.innerWidth;
  btn.style.display = inView ? "block" : "none";
  if (!inView) return;
  // Anchor top-right of the video. Pill is 82px wide → leave 8px gap
  // from the right edge: left = videoRight - 82 - 8 = videoRight - 90.
  const top = Math.max(window.scrollY + r.top + 8, window.scrollY);
  const left = Math.max(window.scrollX + r.right - 90, window.scrollX);
  btn.style.top = `${top}px`;
  btn.style.left = `${left}px`;
}

function repositionAll() {
  document.querySelectorAll("video, audio").forEach(reposition);
}

// ── main world sniff bridge ────────────────────────────────────────

window.addEventListener("message", (ev) => {
  if (ev.source !== window) return;
  const d = ev.data;
  if (!d || d.kind !== "velocita/sniff" || typeof d.url !== "string") return;
  if (gPaused) return;
  api.runtime.sendMessage({
    type: "velocita/store",
    payload: { url: d.url, mime: d.mime || null, ts: d.ts || Date.now() },
  }).catch(() => {});
});

// ── click flow ──────────────────────────────────────────────────────

function flashError(btn) {
  if (!btn) return;
  const prev = btn.style.outline;
  btn.style.outline = "2px solid #ff5252";
  setTimeout(() => { btn.style.outline = prev; }, 1500);
}

// ── quality menu ──────────────────────────────────────────────────
// Open a vertical list of quality options anchored just below the
// pill. On selection, send that URL via `velocita/sendUrl` and close.
// Click outside closes.
function closeAllMenus() {
  if (activeMenu) {
    if (activeMenu.parentNode) activeMenu.parentNode.removeChild(activeMenu);
    activeMenu = null;
    activeMenuMedia = null;
  }
}

// Always opens a FRESH menu (closing any existing one first). The
// pill-click toggle ("click again to close") is handled by the caller
// in onDownloadClick, so the loading→variants refresh can call this
// twice without accidentally closing itself.
function showQualityMenu(media, btn, variants) {
  closeAllMenus();
  const menu = document.createElement("div");
  menu.className = "velocita-menu";
  Object.assign(menu.style, {
    position: "absolute",
    zIndex: "2147483647",
    minWidth: "220px",
    background: "rgba(20,20,22,0.94)",
    borderRadius: "8px",
    padding: "4px",
    boxShadow: "0 6px 18px rgba(0,0,0,0.45)",
    display: "flex",
    flexDirection: "column",
    gap: "2px",
    fontFamily:
      '-apple-system, "Segoe UI", system-ui, Roboto, sans-serif',
    color: "#fff",
  });

  const header = document.createElement("div");
  header.textContent = "Choose quality";
  Object.assign(header.style, {
    fontSize: "11px",
    color: "rgba(255,255,255,0.55)",
    padding: "6px 10px 4px",
    letterSpacing: "0.4px",
    textTransform: "uppercase",
  });
  menu.appendChild(header);

  variants.forEach((v, idx) => {
    const item = document.createElement("button");
    item.type = "button";
    item.dataset.url = v.url;
    item.dataset.label = v.label || "";
    Object.assign(item.style, {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: "10px",
      width: "100%",
      padding: "8px 10px",
      border: "0",
      background: "transparent",
      color: "#fff",
      fontSize: "13px",
      textAlign: "left",
      cursor: "pointer",
      borderRadius: "4px",
    });
    // Two-line item: main label (e.g. "1080p60") over the detail line
    // ("1920×1080 · 4221 kbps · H.264") — mirrors what IDM shows, so
    // same-resolution variants at different bitrates stay distinguishable.
    const left = document.createElement("span");
    Object.assign(left.style, {
      display: "flex",
      flexDirection: "column",
      gap: "1px",
      minWidth: "0",
    });
    const labelSpan = document.createElement("span");
    labelSpan.textContent = v.label || `Variant ${idx + 1}`;
    Object.assign(labelSpan.style, {
      fontSize: "13px",
      fontWeight: "500",
      whiteSpace: "nowrap",
    });
    left.appendChild(labelSpan);
    if (v.detail) {
      const detailSpan = document.createElement("span");
      detailSpan.textContent = v.detail;
      Object.assign(detailSpan.style, {
        fontSize: "10px",
        color: "rgba(255,255,255,0.55)",
        whiteSpace: "nowrap",
      });
      left.appendChild(detailSpan);
    }
    item.appendChild(left);
    if (idx === 0) {
      const best = document.createElement("span");
      best.textContent = "Best";
      Object.assign(best.style, {
        fontSize: "10px",
        color: "rgba(255,255,255,0.55)",
        background: "rgba(255,255,255,0.08)",
        padding: "2px 6px",
        borderRadius: "8px",
      });
      item.appendChild(best);
    }
    item.addEventListener("mouseenter", () => {
      item.style.background = "rgba(255,255,255,0.10)";
    });
    item.addEventListener("mouseleave", () => {
      item.style.background = "transparent";
    });
    item.addEventListener("click", async (e) => {
      e.stopPropagation();
      e.preventDefault();
      closeAllMenus();
      const resp = await api.runtime
        .sendMessage({
          type: "velocita/sendUrl",
          payload: { url: v.url },
        })
        .catch(() => null);
      if (!resp || !resp.ok) flashError(btn);
    });
    menu.appendChild(item);
  });

  // Position the menu just below the pill, right-aligned.
  const pillRect = btn.getBoundingClientRect();
  const top = pillRect.bottom + window.scrollY + 6;
  const left = pillRect.right + window.scrollX - 220;
  menu.style.top = `${top}px`;
  menu.style.left = `${Math.max(left, window.scrollX + 4)}px`;

  document.documentElement.appendChild(menu);
  activeMenu = menu;
  activeMenuMedia = media;
}

async function onDownloadClick(media) {
  if (gPaused) return;
  const btn = BUTTONS.get(media);
  const src = (media.currentSrc || media.src || null);
  // Toggle: clicking the pill while its menu is open closes it.
  if (activeMenuMedia === media) {
    closeAllMenus();
    return;
  }
  // Open the menu immediately with a "Loading…" item, then fill it in
  // once the SW replies. Gives instant feedback while the manifest
  // fetch is in flight.
  showQualityMenu(media, btn, [
    { url: src || "", label: "Loading qualities…" },
  ]);
  // Mark the loading item as non-interactive.
  const menu = activeMenu;
  if (menu) {
    const loading = menu.querySelector("button");
    if (loading) {
      loading.disabled = true;
      loading.style.color = "rgba(255,255,255,0.6)";
      loading.style.cursor = "default";
    }
  }

  let resp;
  try {
    resp = await api.runtime.sendMessage({
      type: "velocita/getQualities",
      payload: { src },
    });
  } catch (_) {
    resp = null;
  }
  if (!resp || !resp.ok) {
    closeAllMenus();
    // Fall back to single-URL send so the user still gets the file.
    const fallback = await api.runtime
      .sendMessage({
        type: "velocita/pickAndSend",
        payload: { src },
      })
      .catch(() => null);
    if (!fallback || !fallback.ok) flashError(btn);
    return;
  }
  if (!resp.variants || resp.variants.length <= 1) {
    // Single URL — no menu needed, send directly.
    closeAllMenus();
    const single = (resp.variants && resp.variants[0]) || null;
    const url = single ? single.url : src;
    const ack = await api.runtime
      .sendMessage({
        type: "velocita/sendUrl",
        payload: { url },
      })
      .catch(() => null);
    if (!ack || !ack.ok) flashError(btn);
    return;
  }
  // Replace the loading menu with the real variant list.
  showQualityMenu(media, btn, resp.variants);
}

// ── observers ──────────────────────────────────────────────────────

const mo = new MutationObserver((muts) => {
  for (const m of muts) {
    m.addedNodes.forEach((n) => {
      if (!(n instanceof HTMLElement)) return;
      if (isMedia(n)) ensureButton(n);
      const inner = n.querySelectorAll && n.querySelectorAll("video, audio");
      if (inner) inner.forEach(ensureButton);
    });
    if (m.type === "attributes" && isMedia(m.target)) {
      reposition(m.target);
    }
  }
});

try {
  mo.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["src", "currentSrc", "style", "class", "controls"],
  });
} catch (_) { /* observing a detached document (very early) */ }

const io = new IntersectionObserver((entries) => {
  for (const e of entries) {
    const btn = BUTTONS.get(e.target);
    if (btn && btn.style.display !== "none") {
      btn.style.opacity = e.isIntersecting ? "0.85" : "0.35";
    }
  }
}, { threshold: [0, 0.1] });

document.querySelectorAll("video, audio").forEach((m) => {
  ensureButton(m);
  io.observe(m);
});

window.addEventListener("scroll", repositionAll, { passive: true });
window.addEventListener("resize", repositionAll);
document.addEventListener("fullscreenchange", repositionAll);
document.addEventListener("webkitfullscreenchange", repositionAll);

// ── tell the SW to inject the MAIN-world sniffer ───────────────────

api.runtime.sendMessage({ type: "velocita/injectSniffer" }).catch(() => {});

// ── pause-state live sync ──────────────────────────────────────────
// Initial read + storage.onChanged keep the floating button and sniff
// bridge in sync with "pause all" / "pause this site" toggles from the
// popup, on every already-open page.
function applyPaused(velocita) {
  gPaused = computePaused(velocita);
  if (gPaused) closeAllMenus();
  repositionAll();
}
api.storage.local
  .get("velocita")
  .then((s) => applyPaused(s && s.velocita))
  .catch(() => {});
api.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.velocita) {
    applyPaused(changes.velocita.newValue);
  }
});

// Click anywhere outside a pill / menu closes any open quality menu.
// closeAllMenus() is a cheap no-op when nothing is open.
document.addEventListener("click", () => {
  closeAllMenus();
});

// Console marker — useful when manually debugging the SW.
console.info("[velocita] content script installed");