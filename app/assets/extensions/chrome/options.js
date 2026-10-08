// Velocita browser extension — options page script.

const api = (typeof browser !== "undefined") ? browser : chrome;

const $host = document.getElementById("host");
const $port = document.getElementById("port");
const $auto = document.getElementById("autoAdd");
const $save = document.getElementById("save");
const $status = document.getElementById("status");

(async function init() {
  const stored = await api.storage.local.get({
    host: "127.0.0.1",
    port: 16800,
    autoAdd: false,
  });
  $host.value = stored.host;
  $port.value = stored.port;
  $auto.checked = stored.autoAdd;
})();

$save.addEventListener("click", async () => {
  await api.storage.local.set({
    host: $host.value || "127.0.0.1",
    port: parseInt($port.value, 10) || 16800,
    autoAdd: $auto.checked,
  });
  $status.textContent = "Saved.";
  setTimeout(() => { $status.textContent = ""; }, 2000);
});
