// Velocita browser extension — background service worker / event page.
//
// Cross-browser MV3 code. Runs in Chrome / Edge as a service worker
// (Chrome MV3), in Firefox as a background scripts array (Firefox
// accepts the MV3 background shape but treats it as an event page).
//
// Responsibilities:
//   1. On install, create a context-menu entry "Download with Velocita"
//      that appears when the user right-clicks a link.
//   2. On context-menu click, build an AddRequest payload and try to
//      send it to the Native Messaging host. If the host isn't
//      reachable (Velocita isn't running or the host isn't installed
//      yet), fall back to opening a `velocita://add?url=…` URL so the
//      OS can wake / launch Velocita.
//   3. Same path for messages from the popup ("Download current page").
//
// All shared JS files (popup, options) live next to this one in the
// built extension directory.

const HOST_NAME = "com.velocita.host";

// ── lifecycle ──────────────────────────────────────────────────

// `chrome` and `browser` are both available in Chrome, Edge, and
// Firefox — Firefox supports `chrome.*` aliases, but we use `browser`
// to follow Mozilla's docs.
const api = (typeof browser !== "undefined") ? browser : chrome;

api.runtime.onInstalled.addListener(async () => {
  try {
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
  } catch (e) {
    console.error("Velocita extension: context menu setup failed", e);
  }
});

// ── context menu ───────────────────────────────────────────────

api.contextMenus.onClicked.addListener(async (info) => {
  let url = null;
  if (info.menuItemId === "velocita-download-link" && info.linkUrl) {
    url = info.linkUrl;
  } else if (info.menuItemId === "velocita-download-page" && info.pageUrl) {
    url = info.pageUrl;
  }
  if (!url) return;
  await sendToHost({
    type: "add",
    url,
    referer: info.pageUrl || null,
    tabTitle: null,
  });
});

// ── popup messages ─────────────────────────────────────────────

api.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message && message.type === "sendToHost") {
    sendToHost(message.payload).then(sendResponse);
    return true; // keep channel open for async response
  }
  if (message && message.type === "ping") {
    pingHost().then(sendResponse);
    return false;
  }
  return false;
});

// ── core send / fall back ──────────────────────────────────────

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
