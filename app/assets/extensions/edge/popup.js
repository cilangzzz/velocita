// Velocita browser extension — popup script.
//
// Shows a connected/disconnected indicator (polls /api/ping with a
// 1.5s timeout), a "Download current page" button, and two pause
// toggles:
//   * "Pause this site"  — adds the active tab's hostname to
//     `velocita.pausedSites` (content script hides the floating button,
//     sniff bridge stops forwarding, interception + context menu skip it).
//   * "Pause all sites"  — flips `velocita.enabled` (global master switch).
// Both react live: already-open pages pick up the change via
// `chrome.storage.onChanged` in content/main.js.

const api = (typeof browser !== "undefined") ? browser : chrome;

const $dot = document.getElementById("dot");
const $status = document.getElementById("status");
const $dl = document.getElementById("dl-page");
const $options = document.getElementById("options");
const $pauseSite = document.getElementById("pause-site");
const $pauseAll = document.getElementById("pause-all");

let settings = { enabled: true, pausedSites: [] };
let tabHost = null;

function hostOf(u) {
  try {
    return new URL(u).hostname || null;
  } catch (_) {
    return null;
  }
}

async function refresh() {
  const ping = await api.runtime.sendMessage({ type: "ping" });
  if (ping && ping.ok) {
    $dot.className = "dot on";
    $status.textContent = "Connected to Velocita";
  } else {
    $dot.className = "dot off";
    $status.textContent = "Velocita not running — will launch on click";
  }
}

async function loadState() {
  try {
    const res = await api.runtime.sendMessage({ type: "velocita/getSettings" });
    if (res && res.settings) settings = res.settings;
  } catch (_) {}
  try {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    tabHost = tab && tab.url ? hostOf(tab.url) : null;
  } catch (_) {}
  updatePauseButtons();
}

function updatePauseButtons() {
  const enabled = settings.enabled !== false;
  $pauseAll.textContent = enabled ? "Pause all sites" : "Resume all sites";
  $pauseAll.classList.toggle("danger", enabled);
  const paused = tabHost && (settings.pausedSites || []).includes(tabHost);
  if (tabHost) {
    $pauseSite.disabled = false;
    $pauseSite.textContent = paused ? `Resume ${tabHost}` : `Pause ${tabHost}`;
  } else {
    $pauseSite.disabled = true;
    $pauseSite.textContent = "No active page";
  }
}

$dl.addEventListener("click", async () => {
  $dl.disabled = true;
  $dl.textContent = "Sending…";
  try {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    if (!tab || !tab.url) {
      $status.textContent = "No active URL";
      return;
    }
    const result = await api.runtime.sendMessage({
      type: "sendToHost",
      payload: { type: "add", url: tab.url, referer: null, tabTitle: tab.title },
    });
    if (result && result.ok) {
      $status.textContent = result.via === "host"
        ? "Sent to Velocita"
        : "Sent to Velocita (via local service)";
    } else if (result && result.via === "fallback") {
      $status.textContent = "Velocita was not running — opened wake-up tab";
    } else {
      $status.textContent = "Velocita is not running — start it and retry";
    }
  } finally {
    $dl.disabled = false;
    $dl.textContent = "Download current page";
  }
});

$pauseAll.addEventListener("click", async () => {
  try {
    const res = await api.runtime.sendMessage({ type: "velocita/toggleEnabled" });
    if (res && res.ok) {
      settings = { ...settings, enabled: res.enabled };
      updatePauseButtons();
    }
  } catch (_) {}
});

$pauseSite.addEventListener("click", async () => {
  if (!tabHost) return;
  try {
    const res = await api.runtime.sendMessage({
      type: "velocita/toggleSitePause",
      payload: { host: tabHost },
    });
    if (res && res.ok) {
      settings = { ...settings, pausedSites: res.pausedSites || [] };
      updatePauseButtons();
    }
  } catch (_) {}
});

$options.addEventListener("click", (e) => {
  e.preventDefault();
  api.runtime.openOptionsPage();
});

refresh();
loadState();