// Velocita browser extension — options page script.

const api = (typeof browser !== "undefined") ? browser : chrome;

const $host     = document.getElementById("host");
const $port     = document.getElementById("port");
const $auto     = document.getElementById("autoAdd");
const $injCk    = document.getElementById("injCookies");
const $injUA    = document.getElementById("injUA");
const $injRef   = document.getElementById("injReferer");
const $save     = document.getElementById("save");
const $status   = document.getElementById("status");

(async function init() {
  const stored = await api.storage.local.get({
    host: "127.0.0.1",
    port: 16800,
    autoAdd: false,
    // Mirror background.js DEFAULT_SETTINGS — these are merged with
    // those defaults server-side, so unspecified values here are
    // simply absent and treated as "use default" on the next read.
    injectCookies: true,
    injectUserAgent: true,
    injectReferer: true,
  });
  $host.value = stored.host;
  $port.value = stored.port;
  $auto.checked = stored.autoAdd;
  $injCk.checked  = stored.injectCookies !== false;
  $injUA.checked  = stored.injectUserAgent !== false;
  $injRef.checked = stored.injectReferer !== false;
})();

$save.addEventListener("click", async () => {
  await api.storage.local.set({
    host: $host.value || "127.0.0.1",
    port: parseInt($port.value, 10) || 16800,
    autoAdd: $auto.checked,
    injectCookies: $injCk.checked,
    injectUserAgent: $injUA.checked,
    injectReferer: $injRef.checked,
  });
  $status.textContent = "Saved.";
  setTimeout(() => { $status.textContent = ""; }, 2000);
});