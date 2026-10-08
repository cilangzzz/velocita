// Velocita browser extension — popup script.
//
// Shows a connected/disconnected indicator (polls /api/ping with a
// 1.5s timeout) and a "Download current page" button that asks the
// background service worker to send the active tab's URL to the
// Native Messaging host.

const api = (typeof browser !== "undefined") ? browser : chrome;

const $dot = document.getElementById("dot");
const $status = document.getElementById("status");
const $dl = document.getElementById("dl-page");
const $options = document.getElementById("options");

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
        : "Velocita was not running — opened in new tab";
    } else {
      $status.textContent = "Failed: " + (result && result.error);
    }
  } finally {
    $dl.disabled = false;
    $dl.textContent = "Download current page";
  }
});

$options.addEventListener("click", (e) => {
  e.preventDefault();
  api.runtime.openOptionsPage();
});

refresh();
