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
  btn.className = "velocita-floating";
  btn.setAttribute("aria-label", "Download with Velocita");
  btn.title = "Download with Velocita";

  Object.assign(btn.style, {
    position: "absolute",
    zIndex: "2147483647",
    width: "36px",
    height: "36px",
    borderRadius: "18px",
    border: "0",
    cursor: "pointer",
    top: "8px",
    right: "8px",
    backgroundColor: "rgba(0,0,0,0.55)",
    backgroundImage: `url("${getIconUrl()}")`,
    backgroundRepeat: "no-repeat",
    backgroundPosition: "center",
    backgroundSize: "20px 20px",
    boxShadow: "0 1px 4px rgba(0,0,0,0.35)",
    color: "#fff",
    padding: "0",
    display: "none",          // shown by reposition() when in viewport
    opacity: "0",
    transition: "opacity 120ms linear",
  });

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
  // Position relative to the page (we placed the button on
  // documentElement, so absolute = viewport coordinates).
  const top = Math.max(window.scrollY + r.top + 8, window.scrollY);
  const left = Math.max(window.scrollX + r.right - 44, window.scrollX);
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

function onDownloadClick(media) {
  if (gPaused) return;
  const btn = BUTTONS.get(media);
  const src = (media.currentSrc || media.src || null);
  api.runtime.sendMessage(
    { type: "velocita/pickAndSend", payload: { src } },
    (resp) => {
      // sendResponse may arrive after the SW dies — Chrome keeps the
      // channel open, just no callback fires. Treat as failure if no
      // response.
      if (!resp || !resp.ok) flashError(btn);
    },
  );
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
    attributeFilter: ["src", "currentSrc", "style", "class"],
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

// Console marker — useful when manually debugging the SW.
console.info("[velocita] content script installed");