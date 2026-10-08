// Velocita browser extension — background service worker / event page.
//
// Cross-browser MV3 code. Runs in Chrome / Edge as a service worker
// (Chrome MV3), in Firefox as a background scripts array (Firefox
// accepts the MV3 background shape but treats it as an event page).
//
// IMPORTANT — Firefox MV3 ignores `type: "module"` so this script must
// contain NO `import` / `export` statements. Plain script syntax only.
//
// Responsibilities:
//   1. On install, create context-menu entries that appear when the user
//      right-clicks a link / page / selection / video.
//   2. On context-menu click, build an AddRequest payload and try to
//      send it to the Native Messaging host. If the host isn't
//      reachable (Velocita isn't running or the host isn't installed
//      yet), fall back to opening a `velocita://add?url=…` URL so the
//      OS can wake / launch Velocita.
//   3. Intercept browser-initiated downloads (`chrome.downloads.onCreated`)
//      that match `shouldIntercept()` rules, collect cookies for
//      restricted downloads, route them to the host, then cancel+erase
//      the browser row.
//   4. Inject a MAIN-world sniffer script into every page (via
//      `chrome.scripting.executeScript({ world: "MAIN" })`) that hooks
//      fetch / XHR / MediaSource / createObjectURL and reports media
//      URLs back through the isolated-world content script.
//   5. Hold a tabId → URLs map of sniffed candidates in memory (mirrored
//      to `chrome.storage.local` so the SW survives a kill) and serve
//      the best URL when the floating button on a `<video>` element is
//      clicked.
//   6. Reply to popup "sendToHost" / "ping" messages.
//
// MV3 service-worker lifetime gotcha — all listeners MUST be
// registered at module top level (not inside onInstalled/onStartup).
// The SW can wake up between two callbacks and the browser dispatches
// to whatever listeners it saw at the top of the module on last load.
// Putting them inside onInstalled means the listener is silently dropped
// for the second-and-later wake cycle. Verified pattern; mirror from
// motrix-webextension background.js lines 193–198.

const HOST_NAME = "com.velocita.host";

// ── cross-browser namespace ─────────────────────────────────────
// `chrome` and `browser` are both available in Chrome, Edge, and
// Firefox — Firefox supports `chrome.*` aliases, but we use `browser`
// to follow Mozilla's docs.
const api = (typeof browser !== "undefined") ? browser : chrome;

// ── top-level state (module-scope) ───────────────────────────────

// Download IDs the SW has already redirected to Velocita. Used to
// short-circuit `onErased` if we ever add one, so we don't accidentally
// delete aria-tracked entries.
const redirectedToAria = new Set();

// Download IDs currently being processed (`onCreated` re-fires sometimes).
const processingDownloads = new Set();

// Memoized init promise. Concurrent wake-ups share it.
let initPromise = null;

// Sniffed URLs keyed by tabId. Each entry is
//   { urls: [{url, mime, ts}], lastAccess: number }
const sniffByTab = new Map();

// Sniff store keys / limits.
const SNIFF_KEY = "sniffByTab";
const SETTINGS_KEY = "velocita";
const SNIFF_TTL_MS = 30 * 60 * 1000;   // 30 min
const MAX_URLS_PER_TAB = 200;
const SNIFF_FLUSH_MS = 30 * 1000;       // 30 s
const FILENAME_WAIT_MS = 30 * 1000;     // 30 s

// Default settings stored under SETTINGS_KEY when the extension first
// installs.
const DEFAULT_SETTINGS = Object.freeze({
  enabled: true,                    // master intercept switch
  minFileSizeMB: 0,                 // 0 = no minimum
  blacklist: [],                    // string substrings; matched against URL
  showContextMenu: true,
});

// ── lifecycle / settings cache ──────────────────────────────────────────

function ensureInitialized() {
  if (initPromise) return initPromise;
  initPromise = (async () => {
    const stored = await api.storage.local.get([SNIFF_KEY, SETTINGS_KEY]);
    // Restore sniffed URLs.
    const obj = stored[SNIFF_KEY] || {};
    const now = Date.now();
    for (const k of Object.keys(obj)) {
      const v = obj[k];
      if (!v || !v.lastAccess) continue;
      if (now - v.lastAccess > SNIFF_TTL_MS) continue;
      sniffByTab.set(Number(k), v);
    }
    // Stamp default settings if missing.
    if (!stored[SETTINGS_KEY]) {
      await api.storage.local.set({ [SETTINGS_KEY]: { ...DEFAULT_SETTINGS } });
    }
    // Periodic persist of the sniff map.
    setInterval(flushSniffMap, SNIFF_FLUSH_MS);
  })();
  return initPromise;
}

async function getSettings() {
  await ensureInitialized();
  const { [SETTINGS_KEY]: s = {} } = await api.storage.local.get(SETTINGS_KEY);
  return { ...DEFAULT_SETTINGS, ...s };
}

async function flushSniffMap() {
  try {
    const obj = {};
    for (const [k, v] of sniffByTab.entries()) obj[k] = v;
    await api.storage.local.set({ [SNIFF_KEY]: obj });
  } catch (e) {
    console.error("Velocita: flushSniffMap failed", e);
  }
}

// ── core send / fall back ──────────────────────────────────────────────

async function sendToHost(payload) {
  // Try the Native Messaging host first.
  try {
    const ack = await api.runtime.sendNativeMessage(HOST_NAME, payload);
    return { ok: true, via: "host", ack };
  } catch (e) {
    // Host not found (Velocita not running, or NM not installed). Fall
    // back to a `velocita://add?url=…` URL — the OS launches Velocita
    // with the URL as argv, and `app_links` parses it back into the
    // AddRequest flow.
    const u = new URL("velocita://add");
    u.searchParams.set("url", payload.url);
    if (payload.referer) u.searchParams.set("referer", payload.referer);
    if (payload.tabTitle) u.searchParams.set("tabTitle", payload.tabTitle);
    if (payload.dedupKey) u.searchParams.set("dedupKey", payload.dedupKey);
    try {
      await api.tabs.create({ url: u.toString() });
    } catch (e2) {
      console.error("Velocita extension: fallback velocita:// failed", e2);
    }
    return { ok: false, via: "fallback", error: String(e) };
  }
}

async function pingHost() {
  // /api/ping lives on the loopback HTTP server. We don't depend on
  // it for correctness, but the popup uses it to show a
  // connected/disconnected indicator.
  const { host = "127.0.0.1", port = 16800 } =
    (await api.storage.local.get(["host", "port"]));
  const ctrl = new AbortController();
  const tid = setTimeout(() => ctrl.abort(), 1500);
  try {
    const res = await fetch(`http://${host}:${port}/api/ping`, {
      signal: ctrl.signal,
    });
    return { ok: res.ok, status: res.status };
  } catch (e) {
    return { ok: false, error: String(e) };
  } finally {
    clearTimeout(tid);
  }
}

// ── download interception ──────────────────────────────────────────────

// URL prefixes we never intercept — the browser handles them itself or
// they're not network resources we can replay through the host.
const UNINTERCEPTABLE = /^(about:|blob:|data:|javascript:|file:)/i;

function shouldIntercept(item, settings) {
  if (!item || !item.url) return false;
  if (UNINTERCEPTABLE.test(item.url)) return false;
  if (item.state && item.state !== "in_progress") return false;
  // Always intercept downloads that this extension triggered via the
  // context-menu ("Download with Velocita"). Chrome sets byExtensionName
  // to the extension's localized name; we match against ours.
  const myName = api.i18n?.getMessage("extensionName") || "";
  if (myName && item.byExtensionName === myName) return true;
  // Master switch.
  if (!settings.enabled) return false;
  // File size filter (only if Chrome knows the size).
  const minBytes = (settings.minFileSizeMB || 0) * 1024 * 1024;
  if (minBytes > 0 && item.fileSize > 0 && item.fileSize < minBytes) {
    return false;
  }
  // Blacklist substring match.
  const blacklist = settings.blacklist || [];
  for (const needle of blacklist) {
    if (needle && item.url.includes(needle)) return false;
  }
  return true;
}

// Resolve a download's final filename. Chrome fills `filename` late in
// the pipeline (after the server has been hit, before bytes are written).
// Lifted from motrix-webextension — the SW needs to wait because
// `filename` is empty in the first `onCreated` payload for "ask where
// to save" downloads.
function waitForFilename(id, timeoutMs) {
  return new Promise((resolve, reject) => {
    const deadline = setTimeout(() => {
      try { api.downloads.onChanged.removeListener(listener); } catch (_) {}
      reject(new Error("waitForFilename timed out"));
    }, timeoutMs || FILENAME_WAIT_MS);
    function listener(delta) {
      if (delta.id !== id) return;
      if (delta.filename && delta.filename.current) {
        clearTimeout(deadline);
        try { api.downloads.onChanged.removeListener(listener); } catch (_) {}
        resolve(delta.filename.current);
      }
    }
    api.downloads.onChanged.addListener(listener);
  });
}

async function handleIntercept(item) {
  await ensureInitialized();
  if (!item || processingDownloads.has(item.id)) return;
  processingDownloads.add(item.id);
  try {
    const settings = await getSettings();
    if (!shouldIntercept(item, settings)) return;

    // Resolve tab context (page URL + title) for the referer header.
    let pageUrl = null;
    let pageTitle = null;
    if (item.tabId != null) {
      try {
        const tab = await api.tabs.get(item.tabId);
        pageUrl = tab?.url || null;
        pageTitle = tab?.title || null;
      } catch (_) { /* tab may be gone */ }
    }

    // Wait for filename so the suggested `out` is sensible. On Firefox
    // we skip the pause() dance; it has no effect anyway in MV3 event
    // pages.
    let filename = item.filename || null;
    if (!filename) {
      try {
        filename = await waitForFilename(item.id);
      } catch (_) {
        // Bail without a filename; the host will let aria2 decide.
      }
    }

    // Collect cookies so restricted downloads can authenticate.
    const dlUrl = item.finalUrl || item.url;
    let cookieHeader = "";
    try {
      const cookies = await api.cookies.getAll({ url: dlUrl });
      cookieHeader = (cookies || [])
        .map((c) => `${c.name}=${c.value}`)
        .filter(Boolean)
        .join("; ");
    } catch (e) {
      console.error("Velocita: cookies.getAll failed", e);
    }

    const headers = [];
    if (cookieHeader) headers.push(`Cookie: ${cookieHeader}`);
    if (item.referrer) headers.push(`Referer: ${item.referrer}`);

    const dedupKey = `dl|${dlUrl}|${filename || ""}`;

    const ack = await sendToHost({
      type: "add",
      url: dlUrl,
      referer: pageUrl || item.referrer || null,
      tabTitle: pageTitle,
      dedupKey,
      cookieHeader: cookieHeader || null,
      headers,
      suggestedFilename: filename || null,
    });

    if (ack && ack.ok) {
      // Successfully handed off — erase the browser's row so the user
      // doesn't see a phantom download alongside the Velocita task.
      // On Firefox, erase-then-cancel is the safe order; on Chromium,
      // either order works. motrix comments echo this finding.
      redirectedToAria.add(item.id);
      try { await api.downloads.erase({ id: item.id }); } catch (_) {}
      try { await api.downloads.cancel(item.id); } catch (_) {}
    }
    // On failure, `sendToHost` already fell back to velocita:// — leave
    // the browser download alone so the user still has the file.
  } catch (e) {
    console.error("Velocita: handleIntercept failed", e);
  } finally {
    processingDownloads.delete(item.id);
  }
}

// ── context-menu wiring ────────────────────────────────────────────────

async function handleContextMenuClick(info) {
  let url = null;
  if (info.menuItemId === "velocita-download-link" && info.linkUrl) {
    url = info.linkUrl;
  } else if (info.menuItemId === "velocita-download-page" && info.pageUrl) {
    url = info.pageUrl;
  } else if (info.menuItemId === "velocita-download-video" && info.srcUrl) {
    url = info.srcUrl;
  }
  if (!url) return;
  await sendToHost({
    type: "add",
    url,
    referer: info.pageUrl || null,
    tabTitle: null,
    dedupKey: null,
  });
}

// ── sniff store + MAIN-world injection ─────────────────────────────────

function storeSniff(tabId, hit) {
  if (tabId == null || typeof tabId !== "number") return;
  if (!hit || typeof hit.url !== "string" || !hit.url) return;
  const now = Date.now();
  let bucket = sniffByTab.get(tabId);
  if (!bucket) {
    bucket = { urls: [], lastAccess: now };
    sniffByTab.set(tabId, bucket);
  }
  bucket.lastAccess = now;
  if (bucket.urls.length >= MAX_URLS_PER_TAB) return;
  if (bucket.urls.some((h) => h.url === hit.url)) return;
  bucket.urls.push({
    url: hit.url,
    mime: hit.mime || null,
    ts: hit.ts || now,
  });
}

async function injectSniffer(tabId) {
  if (tabId == null || typeof tabId !== "number") return;
  try {
    await api.scripting.executeScript({
      target: { tabId, allFrames: true },
      files: ["content/sniffer.js"],
      world: "MAIN",
      injectImmediately: true,
    });
  } catch (e) {
    // chrome://, file://, the Web Store, and some embedded viewers
    // refuse injection. Silent fail is fine.
  }
}

// Priority order — direct progressive > HLS master > DASH > .ts > other.
function scoreSniffedUrl(u) {
  const s = u.toLowerCase();
  if (s.includes(".mp4") || s.includes(".m4v")) return 5;
  if (s.includes(".m3u8")) return 4;
  if (s.includes(".mpd")) return 3;
  if (s.includes(".ts")) return 2;
  if (s.includes(".webm") || s.includes(".mkv")) return 1;
  return 0;
}

function pickBestSniff(sniffList, videoSrc) {
  if (!Array.isArray(sniffList) || sniffList.length === 0) return null;
  // If the video element's currentSrc matches a sniffed URL exactly,
  // it's almost always the right answer (the player already picked
  // it for us).
  if (videoSrc) {
    const direct = sniffList.find((h) => h.url === videoSrc);
    if (direct) return direct.url;
  }
  let best = null;
  let bestScore = -1;
  for (const h of sniffList) {
    const sc = scoreSniffedUrl(h.url);
    if (sc > bestScore) {
      best = h;
      bestScore = sc;
    }
  }
  return best ? best.url : null;
}

async function pickAndSend(tabId, videoSrc) {
  const bucket = sniffByTab.get(tabId);
  const candidates = bucket ? bucket.urls : [];
  const url = pickBestSniff(candidates, videoSrc);
  if (!url) return { ok: false, error: "no sniffed URL" };
  let pageUrl = null;
  let pageTitle = null;
  try {
    const tab = await api.tabs.get(tabId);
    pageUrl = tab?.url || null;
    pageTitle = tab?.title || null;
  } catch (_) {}
  const ack = await sendToHost({
    type: "add",
    url,
    referer: pageUrl,
    tabTitle: pageTitle,
    dedupKey: `sniff|${tabId}|${url}`,
  });
  return ack;
}

// ── message router (popup + content scripts) ──────────────────────────

api.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || typeof message !== "object") return false;

  // Popup → extension
  if (message.type === "sendToHost") {
    sendToHost(message.payload).then(sendResponse);
    return true;
  }
  if (message.type === "ping") {
    pingHost().then(sendResponse);
    return false;
  }

  // Settings (popup + content scripts + options)
  if (message.type === "velocita/getSettings") {
    getSettings().then((s) => sendResponse({ ok: true, settings: s }));
    return true;
  }
  if (message.type === "velocita/setSettings") {
    api.storage.local.set({ [SETTINGS_KEY]: message.payload || {} })
      .then(() => sendResponse({ ok: true }));
    return true;
  }
  if (message.type === "velocita/toggleEnabled") {
    (async () => {
      const cur = await getSettings();
      const next = { ...cur, enabled: !cur.enabled };
      await api.storage.local.set({ [SETTINGS_KEY]: next });
      sendResponse({ ok: true, enabled: next.enabled });
    })();
    return true;
  }

  // Content scripts → SW
  if (message.type === "velocita/injectSniffer") {
    // sender.tab is set for content-script-originated messages.
    injectSniffer(sender.tab?.id);
    return false;
  }
  if (message.type === "velocita/store") {
    storeSniff(sender.tab?.id, message.payload);
    return false;
  }
  if (message.type === "velocita/pickAndSend") {
    pickAndSend(sender.tab?.id, message.payload?.src).then(sendResponse);
    return true;
  }
  if (message.type === "velocita/listSniffs") {
    const bucket = sniffByTab.get(sender.tab?.id);
    sendResponse({ ok: true, urls: bucket?.urls ?? [] });
    return false;
  }

  return false;
});

// ── top-level listener registration (MV3 SW kill gotcha) ───────────────

api.runtime.onInstalled.addListener(async () => {
  try {
    await ensureInitialized();
    const settings = await getSettings();
    if (settings.showContextMenu) {
      // Context menu creation is best-effort; an old install may have
      // stale entries we can't replace. Catch and ignore.
      await api.contextMenus.create({
        id: "velocita-download-link",
        title: "Download with Velocita",
        contexts: ["link"],
      });
      await api.contextMenus.create({
        id: "velocita-download-page",
        title: "Download this page with Velocita",
        contexts: ["page", "selection"],
      });
      // "video" context is Chrome/Edge only — Firefox silently no-ops.
      try {
        await api.contextMenus.create({
          id: "velocita-download-video",
          title: "Download this video",
          contexts: ["video"],
        });
      } catch (_) {}
    }
  } catch (e) {
    console.error("Velocita extension: context menu setup failed", e);
  }
});

api.runtime.onStartup.addListener(() => {
  // Rehydrate on browser cold-launch (no onInstalled fires here).
  ensureInitialized();
});

// CRITICAL — register download interception at module top level so a
// service-worker wake cycle that skipped onInstalled still gets the
// event. motrix-webextension comment lines 193–198 documents this.
api.downloads.onCreated.addListener(handleIntercept);
api.contextMenus.onClicked.addListener(handleContextMenuClick);
api.tabs.onRemoved.addListener((tabId) => sniffByTab.delete(tabId));
// Belt-and-suspenders: hide the Chrome shelf so the user only sees
// downloads inside Velocita. No-op on Firefox (no `downloads.shelf`).
if (typeof api.downloads.setShelfEnabled === "function") {
  api.downloads.onChanged.addListener(() => {
    api.downloads.setShelfEnabled?.(false).catch(() => {});
  });
}