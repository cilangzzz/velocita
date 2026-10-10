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
  enabled: true,                    // master intercept switch ("pause all")
  minFileSizeMB: 0,                 // 0 = no minimum
  blacklist: [],                    // string substrings; matched against URL
  pausedSites: [],                  // hostnames to skip ("pause this site")
  showContextMenu: true,
  // Per-request header injection — every add path (intercept, context
  // menu, sniff pick, quality menu) funnels through sendToHost, so
  // these three toggles control the global "what to send to aria2"
  // behavior. Each is opt-OUT: defaults to true so the existing
  // download behavior is preserved on update.
  injectCookies: true,              // chrome.cookies.getAll → "Cookie:" header
  injectUserAgent: true,            // navigator.userAgent → "User-Agent:" header
  injectReferer: true,              // payload.referer → aria2 "referer" option
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

async function ensureContextMenus() {
  let settings;
  try {
    settings = await getSettings();
  } catch (_) {
    settings = { ...DEFAULT_SETTINGS };
  }
  if (!settings.showContextMenu) return;
  // Each create call is idempotent by id. `chrome.contextMenus.removeAll`
  // would also work but races with a same-tick user right-click; the
  // upsert-by-id approach is safer.
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
  // `image` shows the menu on right-click of <img>, <picture><source>,
  // and elements with CSS `background-image` (the latter also exposes
  // `info.srcUrl`). On Firefox the background-image case isn't supported
  // but plain <img> works.
  await api.contextMenus.create({
    id: "velocita-download-image",
    title: "Download this image with Velocita",
    contexts: ["image"],
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

// Loopback HTTP endpoint (the desktop app's BrowserIntegrationService).
const DEFAULT_HOST = "127.0.0.1";
const DEFAULT_PORT = 16800;

// How long we wait on a Native-Messaging send before falling through to
// the HTTP path. When Velocita is closed but the NM host is registered,
// Chrome spawns the host (the full velocita.exe), which becomes the
// primary app and never ACKs the NM frame — so without a timeout this
// promise would hang forever.
const NM_TIMEOUT_MS = 3500;

async function loopbackBase() {
  const { host = DEFAULT_HOST, port = DEFAULT_PORT } =
    await api.storage.local.get(["host", "port"]);
  return `http://${host}:${port}`;
}

// Tells the running desktop app our extension ID so it can add
// `chrome-extension://<id>/` to the host JSON's `allowed_origins`.
// Chrome refuses to deliver Native-Messaging messages to an origin not
// listed there, and an unpacked extension's ID is path-derived and
// unknowable at install time — so we self-register over loopback HTTP
// (whose CORS already whitelists chrome-extension:// origins).
async function registerWithApp() {
  try {
    const base = await loopbackBase();
    const ctrl = new AbortController();
    const tid = setTimeout(() => ctrl.abort(), 1500);
    try {
      const res = await fetch(`${base}/api/register-extension`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: api.runtime.id }),
        signal: ctrl.signal,
      });
      return res.ok;
    } finally {
      clearTimeout(tid);
    }
  } catch (e) {
    console.debug("Velocita: register-extension failed (app not running?)", e);
    return false;
  }
}

// Delivers the AddRequest payload over the loopback HTTP service
// (`/api/add`). Works whenever Velocita is running, independently of
// Native-Messaging registration. CORS is open to extension origins.
async function sendViaHttp(payload) {
  try {
    const base = await loopbackBase();
    const ctrl = new AbortController();
    const tid = setTimeout(() => ctrl.abort(), 3000);
    try {
      const res = await fetch(`${base}/api/add`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          url: payload.url,
          referer: payload.referer || null,
          tabTitle: payload.tabTitle || null,
          cookieHeader: payload.cookieHeader || null,
          headers: payload.headers || null,
          dedupKey: payload.dedupKey || null,
          suggestedFilename: payload.suggestedFilename || null,
          source: "extension",
        }),
        signal: ctrl.signal,
      });
      if (!res.ok) return { ok: false, status: res.status };
      return { ok: true, via: "http", status: res.status };
    } finally {
      clearTimeout(tid);
    }
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

// Promise.race with a hard deadline. Both arms resolve (never reject) so
// the caller can't leak an unhandled rejection from the losing arm.
function withTimeout(promise, ms, fallback) {
  let timer;
  return Promise.race([
    promise.then((v) => v, () => fallback),
    new Promise((resolve) => {
      timer = setTimeout(() => resolve(fallback), ms);
    }),
  ]).finally(() => clearTimeout(timer));
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// The browser's own User-Agent — the same one the server saw when the
// page loaded, so CDNs that gate on UA accept the replayed request.
// Without this, aria2 announces itself as `aria2/<version>` and many
// hotlink-protected CDNs answer 403.
function browserUA() {
  try {
    return navigator.userAgent || null;
  } catch (_) {
    return null;
  }
}

// Shapes the aria2 `header` option array from the enriched payload.
// Referer deliberately goes via the dedicated `referer` FIELD (the
// desktop maps it to aria2's `referer` option, which wins when both
// are set) — not duplicated here.
function buildHeaderArray(payload) {
  const headers = [];
  if (payload.cookieHeader) headers.push(`Cookie: ${payload.cookieHeader}`);
  if (payload.userAgent) headers.push(`User-Agent: ${payload.userAgent}`);
  return headers;
}

// Header-array helpers used to gate injection toggles. Case-insensitive —
// HTTP header names are case-insensitive per RFC 7230.
function stripHeader(payload, name) {
  const prefix = name.toLowerCase() + ":";
  if (Array.isArray(payload.headers)) {
    payload.headers = payload.headers.filter(
      (h) => typeof h !== "string" || h.toLowerCase().indexOf(prefix) !== 0,
    );
  }
}
function hasHeader(payload, name) {
  const prefix = name.toLowerCase() + ":";
  return (
    Array.isArray(payload.headers) &&
    payload.headers.some(
      (h) => typeof h === "string" && h.toLowerCase().indexOf(prefix) === 0,
    )
  );
}

// File basename — aria2's `out` option is a filename relative to `dir`,
// never a path. waitForFilename hands us an absolute local path, so
// strip everything up to the last separator.
function baseName(p) {
  if (!p) return null;
  const base = String(p).split(/[\\/]/).pop();
  return base || null;
}

async function sendToHost(payload) {
  // Enrich every outbound add with auth context for the target URL,
  // gated by the user's "inject X" toggles in settings.
  //   * cookies via chrome.cookies.getAll (HttpOnly included) unless the
  //     caller already collected some,
  //   * the browser's own User-Agent,
  //   * the `headers` array shaped for aria2's `header` option.
  // All add paths (download intercept, context menu, sniff pick, quality
  // menu, popup) funnel through here, so call sites stay dumb.
  if (payload && payload.url) {
    const s = await getSettings().catch(() => ({}));
    const wantCookie  = s.injectCookies !== false;
    const wantUA      = s.injectUserAgent !== false;
    const wantReferer = s.injectReferer !== false;

    // First, strip whatever the toggles disable (and any header entry
    // the caller pre-supplied) so the field never reaches aria2.
    if (!wantReferer) delete payload.referer;
    if (!wantCookie)  delete payload.cookieHeader;
    if (!wantUA)      stripHeader(payload, "user-agent");

    // Then enrich only what is still wanted and missing.
    if (wantCookie && !payload.cookieHeader) {
      try {
        const cookies = await api.cookies.getAll({ url: payload.url });
        const cookieHeader = (cookies || [])
          .map((c) => `${c.name}=${c.value}`)
          .filter(Boolean)
          .join("; ");
        if (cookieHeader) payload.cookieHeader = cookieHeader;
      } catch (_) {
        // cookies.getAll can fail on chrome:// pages etc. — proceed bare.
      }
    }
    if (wantUA && !hasHeader(payload, "user-agent")) {
      if (!payload.userAgent) payload.userAgent = browserUA();
    }
    if (
      (wantCookie && payload.cookieHeader) ||
      (wantUA && (payload.userAgent || hasHeader(payload, "user-agent")))
    ) {
      if (!Array.isArray(payload.headers) || payload.headers.length === 0) {
        payload.headers = buildHeaderArray(payload);
      }
    }
  }

  // 1) Native Messaging — the preferred transport: no browser prompts,
  //    and spawning the host doubles as the "wake the app" mechanism.
  //    Bounded by NM_TIMEOUT_MS because a spawned-but-unresponsive host
  //    (app was closed and is still booting) never ACKs.
  try {
    const ack = await withTimeout(
      api.runtime.sendNativeMessage(HOST_NAME, payload),
      NM_TIMEOUT_MS,
      null,
    );
    if (ack) return { ok: true, via: "host", ack };
    console.debug("Velocita: NM host did not ACK (app was closed?)");
  } catch (e) {
    // Host not registered for this origin, or NM unavailable — the HTTP
    // path below still works when Velocita is running. Chrome's message
    // for an allowed_origins mismatch is "Specified native messaging host
    // not found." — that exact string proves the host JSON needs our ID.
    console.debug(
      "Velocita: NM send failed, falling back to HTTP:",
      (e && e.message) ? e.message : String(e),
    );
  }

  // 2) Loopback HTTP — works whenever Velocita is up, regardless of NM
  //    registration. Register our ID first so the NEXT NM attempt works.
  await registerWithApp();
  const h1 = await sendViaHttp(payload);
  if (h1.ok) return h1;

  // 3) App was probably closed; the NM attempt in (1) just spawned it.
  //    Give the GUI a couple of seconds to bind the loopback port, then
  //    retry HTTP once.
  await sleep(2500);
  await registerWithApp();
  const h2 = await sendViaHttp(payload);
  if (h2.ok) return h2;

  // 4) Last-resort fallback: open `velocita://add?url=…` in a new tab so
  //    the OS can launch Velocita (registered as a URL-scheme handler).
  //    This path triggers Chrome's external-protocol confirmation prompt
  //    ("This site is trying to open Velocita") — only reached when both
  //    NM and loopback HTTP failed, which means Velocita was not running
  //    AND the host JSON's allowed_origins didn't list this extension (so
  //    NM couldn't wake it either). Keeping this path as a backstop means
  //    a fresh-install user (no self-registration yet) still gets their
  //    download queued.
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
  return {
    ok: false,
    via: "fallback",
    error: "Velocita is not running — opened wake-up tab",
  };
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

function hostOf(u) {
  try {
    return new URL(u).hostname || null;
  } catch (_) {
    return null;
  }
}

function shouldIntercept(item, settings) {
  if (!item || !item.url) return false;
  if (UNINTERCEPTABLE.test(item.url)) return false;
  if (item.state && item.state !== "in_progress") return false;
  // Always intercept downloads that this extension triggered via the
  // context-menu ("Download with Velocita"). Chrome sets byExtensionName
  // to the extension's localized name; we match against ours.
  const myName = api.i18n?.getMessage("extensionName") || "";
  if (myName && item.byExtensionName === myName) return true;
  // Master switch ("pause all sites").
  if (!settings.enabled) return false;
  // Per-site pause list ("pause this site").
  if (settings.pausedSites && settings.pausedSites.length) {
    const host = hostOf(item.url);
    if (host && settings.pausedSites.includes(host)) return false;
  }
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

    // Cookies + User-Agent are attached centrally in sendToHost (it
    // covers every add path, not just interception). Here we only wait
    // for the browser-determined filename so the desktop can pass it
    // to aria2 as `out`.
    const dlUrl = item.finalUrl || item.url;

    const dedupKey = `dl|${dlUrl}|${filename || ""}`;

    const ack = await sendToHost({
      type: "add",
      url: dlUrl,
      referer: pageUrl || item.referrer || null,
      tabTitle: pageTitle,
      dedupKey,
      suggestedFilename: baseName(filename),
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
  // Bail when globally paused or the target site is paused.
  let settings;
  try {
    settings = await getSettings();
  } catch (_) {
    return;
  }
  if (!settings.enabled) return;
  if (settings.pausedSites && settings.pausedSites.length) {
    const pageHost = info.pageUrl ? hostOf(info.pageUrl) : null;
    const srcHost = info.srcUrl ? hostOf(info.srcUrl) : null;
    if (pageHost && settings.pausedSites.includes(pageHost)) return;
    if (srcHost && settings.pausedSites.includes(srcHost)) return;
  }
  let url = null;
  if (info.menuItemId === "velocita-download-link" && info.linkUrl) {
    url = info.linkUrl;
  } else if (info.menuItemId === "velocita-download-page" && info.pageUrl) {
    url = info.pageUrl;
  } else if (info.menuItemId === "velocita-download-image" && info.srcUrl) {
    url = info.srcUrl;
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

// ── HLS master playlist → quality variants ──────────────────────────
// Parses a master playlist and returns a list of quality options
// `{url, label, detail}` sorted highest-quality first. A media playlist
// (segments only, no #EXT-X-STREAM-INF) returns `null` — we don't
// expose segment lists to the user; the whole playlist is sent to
// aria2 instead.
//
// Per-variant attributes surfaced (matching what IDM shows):
//   RESOLUTION (width×height), BANDWIDTH / AVERAGE-BANDWIDTH (kbps),
//   FRAME-RATE (fps), CODECS (video codec friendly name).

// Maps the video codec tag from the CODECS attribute to a friendly
// name. CODECS is a comma list ("avc1.640028,mp4a.40.2") — the first
// video codec wins; audio codecs are ignored.
function parseVideoCodec(codecs) {
  if (!codecs) return null;
  const list = String(codecs)
    .split(",")
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  const video = list.find(
    (c) =>
      c.startsWith("avc1") ||
      c.startsWith("avc3") ||
      c.startsWith("hvc1") ||
      c.startsWith("hev1") ||
      c.startsWith("av01") ||
      c.startsWith("vp09") ||
      c.startsWith("vp8"),
  );
  if (!video) return null;
  if (video.startsWith("avc")) return "H.264";
  if (video.startsWith("hvc") || video.startsWith("hev")) return "H.265";
  if (video.startsWith("av01")) return "AV1";
  if (video.startsWith("vp09")) return "VP9";
  if (video.startsWith("vp8")) return "VP8";
  return null;
}

function parseHlsMaster(text, baseUrl) {
  const lines = text.split(/\r?\n/);
  const variants = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (!line.startsWith("#EXT-X-STREAM-INF:")) continue;
    const info = line.substring("#EXT-X-STREAM-INF:".length);
    const urlLine = (lines[i + 1] || "").trim();
    if (!urlLine) continue;
    let abs;
    try {
      abs = new URL(urlLine, baseUrl).toString();
    } catch (_) {
      abs = urlLine;
    }
    // Attribute reader: handles both quoted values (CODECS="a,b" — the
    // comma inside quotes must NOT end the match) and bare numbers
    // (BANDWIDTH=2147000).
    const attr = (name) => {
      const quoted = info.match(new RegExp(`${name}="([^"]*)"`, "i"));
      if (quoted) return quoted[1].trim();
      const bare = info.match(new RegExp(`${name}=([^,\\s]+)`, "i"));
      return bare ? bare[1].trim() : null;
    };
    const num = (name) => {
      const m = info.match(new RegExp(`${name}=(\\d+(?:\\.\\d+)?)`, "i"));
      return m ? parseFloat(m[1]) : null;
    };
    const resMatch = info.match(/RESOLUTION=(\d+)x(\d+)/i);
    // Prefer AVERAGE-BANDWIDTH (more representative) over peak BANDWIDTH.
    const bandwidth = num("AVERAGE-BANDWIDTH") || num("BANDWIDTH");
    const fps = num("FRAME-RATE");
    variants.push({
      url: abs,
      width: resMatch ? parseInt(resMatch[1], 10) : null,
      height: resMatch ? parseInt(resMatch[2], 10) : null,
      bandwidth,
      fps: fps && fps > 0 ? fps : null,
      codec: parseVideoCodec(attr("CODECS")),
    });
    i++;
  }
  if (variants.length < 2) return null; // need >=2 variants for a menu
  variants.sort((a, b) => (b.bandwidth || 0) - (a.bandwidth || 0));

  // Build labels + detail lines. Label = "{height}p{fps}" (fps only when
  // >30, so 25/30fps variants stay clean) or "{kbps} kbps" without
  // resolution. Detail = "width×height · kbps · codec" — always shows
  // bandwidth, so same-resolution variants stay distinguishable (IDM
  // style). Exact label collisions (same height AND bandwidth) get an
  // index suffix.
  const out = variants.map((v, idx) => {
    const fpsSuffix = v.fps && Math.round(v.fps) > 30 ? String(Math.round(v.fps)) : "";
    const label = v.height
      ? `${v.height}p${fpsSuffix}`
      : v.bandwidth
        ? `${Math.round(v.bandwidth / 1000)} kbps`
        : `Variant ${idx + 1}`;
    const detailParts = [];
    if (v.width && v.height) detailParts.push(`${v.width}×${v.height}`);
    if (v.bandwidth) detailParts.push(`${Math.round(v.bandwidth / 1000)} kbps`);
    if (v.codec) detailParts.push(v.codec);
    return {
      url: v.url,
      label,
      detail: detailParts.join(" · ") || null,
      resolution: v.width && v.height ? `${v.width}×${v.height}` : null,
      bandwidth: v.bandwidth || null,
      fps: v.fps || null,
      codec: v.codec || null,
    };
  });
  const labelCount = new Map();
  for (const item of out) {
    const n = labelCount.get(item.label) || 0;
    labelCount.set(item.label, n + 1);
    if (n > 0) {
      item.label = item.bandwidth
        ? `${item.label} · ${Math.round(item.bandwidth / 1000)}k`
        : `${item.label} #${n + 1}`;
    }
  }
  return out;
}

async function fetchHlsVariants(url) {
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    const text = await res.text();
    if (!text.includes("#EXT-X-STREAM-INF")) return null; // media playlist, not master
    return parseHlsMaster(text, url);
  } catch (_) {
    return null;
  }
}

// Build the quality menu for a single video:
//   1. Try the video element's own currentSrc if it ends in .m3u8.
//   2. Otherwise scan the tab's sniffed URLs for a master playlist.
//   3. If we get ≥2 variants, return them (sorted, highest first).
//   4. Otherwise return a single-item list with the best sniff so the
//      caller can use the existing single-click path.
async function getQualitiesForTab(tabId, videoSrc) {
  const bucket = sniffByTab.get(tabId);
  const sniffed = bucket ? bucket.urls.map((h) => h.url) : [];
  // Candidate list: videoSrc first (highest priority — that's what the
  // page is actually playing), then sniffed URLs.
  const tried = new Set();
  const order = [];
  if (videoSrc) order.push(videoSrc);
  for (const u of sniffed) {
    if (/\.m3u8(\?|#|$)/i.test(u)) order.push(u);
  }
  for (const u of order) {
    if (tried.has(u)) continue;
    tried.add(u);
    const variants = await fetchHlsVariants(u);
    if (variants && variants.length >= 2) {
      return { sourceUrl: u, kind: "hls", variants };
    }
  }
  const best = pickBestSniff(bucket ? bucket.urls : [], videoSrc);
  if (best) {
    return {
      sourceUrl: best,
      kind: "single",
      variants: [{ url: best, label: "Download" }],
    };
  }
  return null;
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
  if (message.type === "velocita/toggleSitePause") {
    // payload: { host: "example.com" } — toggle that hostname in
    // `pausedSites`. Empty / missing host just returns the current list.
    (async () => {
      const cur = await getSettings();
      const host = (message.payload && message.payload.host) || null;
      const list = Array.isArray(cur.pausedSites)
        ? [...cur.pausedSites]
        : [];
      const idx = host ? list.indexOf(host) : -1;
      let paused = false;
      if (idx >= 0) {
        list.splice(idx, 1); // resume
      } else if (host) {
        list.push(host); // pause
        paused = true;
      }
      const next = { ...cur, pausedSites: list };
      await api.storage.local.set({ [SETTINGS_KEY]: next });
      sendResponse({ ok: true, host, paused, pausedSites: list });
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
  if (message.type === "velocita/getQualities") {
    // Returns the best URL + a list of quality variants parsed from
    // the HLS master playlist (if any). Single-item list when there's
    // only one URL — the content script can auto-send in that case.
    getQualitiesForTab(sender.tab?.id, message.payload?.src)
      .then((r) => {
        if (r) sendResponse({ ok: true, ...r });
        else sendResponse({ ok: false, error: "no candidates" });
      });
    return true;
  }
  if (message.type === "velocita/sendUrl") {
    // Explicit-URL send — used after the user picks a quality option
    // from the floating menu.
    const url = (message.payload && message.payload.url) || null;
    if (!url) {
      sendResponse({ ok: false, error: "missing url" });
      return false;
    }
    (async () => {
      const tabId = sender.tab?.id;
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
        dedupKey: `quality|${tabId || 0}|${url}`,
      });
      sendResponse(ack);
    })();
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
    // Register our real extension ID with the app so Native Messaging
    // works immediately (the host JSON's allowed_origins starts with a
    // placeholder that no real ID matches).
    registerWithApp();
    // Context-menu creation moved into ensureInitialized() so it also
    // runs on subsequent SW wakes that skip this listener (e.g. clicking
    // the reload button at chrome://extensions during dev).
  } catch (e) {
    console.error("Velocita extension: onInstalled failed", e);
  }
});

api.runtime.onStartup.addListener(() => {
  // Rehydrate on browser cold-launch (no onInstalled fires here).
  ensureInitialized();
  registerWithApp();
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

// ── kick off on every SW start ───────────────────────────────────────
// ensureInitialized() restores persisted state (sniff map, settings) and
// starts the periodic flush; ensureContextMenus() rebuilds the right-click
// entries even after a reload that skips `onInstalled` (the common dev
// workflow). NOTE: ensureContextMenus must NOT be awaited from inside
// ensureInitialized — it reads settings via getSettings() which awaits
// ensureInitialized(), and awaiting your own in-flight initPromise from
// inside it is a deadlock (the SW would hang forever and no menus /
// handlers would ever run).
ensureInitialized();
ensureContextMenus();