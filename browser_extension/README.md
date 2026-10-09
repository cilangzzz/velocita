# Velocita Browser Extension

Cross-browser MV3 extension (Chrome, Edge, Firefox). Captures downloads from
the browser, sniffs video/audio on the page, and forwards everything to the
Velocita desktop app via Native Messaging.

## Layout

```
src/
├── manifest.chrome.json        Manifest for Chrome / Edge / Opera
├── manifest.edge.json          Manifest for Edge (Chromium 120+)
├── manifest.firefox.json       Manifest for Firefox 121+
├── background.js               Service worker / event page (cross-browser)
├── content/
│   ├── main.js                 Isolated-world content script
│   └── sniffer.js              MAIN-world hook for media sniffing
├── popup.html / popup.js        Toolbar popup
├── options.html / options.js   Options page
└── icons/
    ├── 16.png … 128.png        Toolbar icons
    ├── floating.svg            Light-mode floating button overlay
    └── floating-dark.svg        Dark-mode floating button overlay
```

## Build

From the `velocita/` monorepo root:

```bash
dart run tools/build_extensions.dart
```

This stages the source into `app/assets/extensions/{chrome,edge,firefox}/`
for the Flutter app to bundle. The staging step renames
`manifest.<browser>.json` → `manifest.json` and recursively copies
everything else (including `content/` and `icons/`).

After the build, the loaded extension's manifest references files at:

```
app/assets/extensions/<browser>/manifest.json
app/assets/extensions/<browser>/background.js
app/assets/extensions/<browser>/content/{main,sniffer}.js
…
```

`app/pubspec.yaml` lists every staged asset.

## Local development (load unpacked)

### Chrome / Edge

1. Run `dart run tools/build_extensions.dart` so the staged folder is current.
2. Open `chrome://extensions` (or `edge://extensions`).
3. Enable **Developer mode** (top-right toggle).
4. Click **Load unpacked** and pick `velocita/app/assets/extensions/chrome/`.
5. Note the extension ID printed under the card — copy it for the next step.
6. Register the Native Messaging host:
   - Windows: `HKCU\Software\Google\Chrome\NativeMessagingHosts\com.velocita.host`
     (REG_SZ) → absolute path of `com.velocita.host.json`.
   - macOS: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.velocita.host.json`
   - Linux: `~/.config/google-chrome/NativeMessagingHosts/com.velocita.host.json`
   The `com.velocita.host.json` example:

   ```json
   {
     "name": "com.velocita.host",
     "description": "Velocita download manager",
     "path": "C:\\path\\to\\velocita.exe",
     "type": "stdio",
     "allowed_origins": ["chrome-extension://<your-id>/"]
   }
   ```

7. Launch `velocita.exe` — the app self-heals its registry keys on startup
   (`main.dart:64-69`), so once it boots the NM bridge is live.
8. Reload the extension card to pick up the host.

For Edge, replace `Google\Chrome\…` with `Microsoft\Edge\…` and
`chrome-extension://` with `edge-extension://` in the registry /
manifest.

### Firefox

1. Run `dart run tools/build_extensions.dart`.
2. Open `about:debugging#/runtime/this-firefox`.
3. Click **Load Temporary Add-on…** and pick
   `velocita/app/assets/extensions/firefox/manifest.json`.
4. Register the Native Messaging host at
   `HKCU\Software\Mozilla\NativeMessagingHosts\com.velocita.host`
   (Windows) or the platform equivalent. `allowed_extensions`
   (not `allowed_origins`):
   `["velocita@velocita.app"]`.

## Features

### Download interception

`background.js` listens to `chrome.downloads.onCreated` at module top level.
For each download that passes `shouldIntercept()`:

- Collect cookies via `chrome.cookies.getAll({ url })`.
- Build a payload `{ url, referer, tabTitle, dedupKey, cookieHeader, headers }`.
- Hand off to `velocita.exe` (`com.velocita.host`).
- On success, `chrome.downloads.erase({id})` + `chrome.downloads.cancel(id)`
  to remove the browser row.

Settings (`chrome.storage.local["velocita"]`):

```jsonc
{
  "enabled": true,            // master intercept switch
  "minFileSizeMB": 0,         // ignore small files; 0 = disable
  "blacklist": [],            // URL substrings to skip
  "showContextMenu": true
}
```

Toggle `enabled` from the toolbar popup without reloading the extension.

### Sniffing + floating button

- `content/main.js` runs at `document_start` in every frame, finds every
  `<video>` / `<audio>` element, and renders a small download button at the
  top-right corner.
- `content/sniffer.js` is injected by the SW into the page's **main world**
  via `chrome.scripting.executeScript({ world: "MAIN" })`. It hooks
  `window.fetch`, `XMLHttpRequest`, `MediaSource.addSourceBuffer`,
  `SourceBuffer.appendBuffer`, and `URL.createObjectURL`. Each hit is
  forwarded to the SW via `window.postMessage`.
- On click, the SW picks the best URL by extension priority
  (`.mp4` > `.m3u8` > `.mpd` > `.ts` > `.webm`/`.mkv` > other) and sends it
  to the host. If the video element's own `currentSrc` matches a sniffed
  URL exactly, the picker uses that.
- HLS (`.m3u8`) is shipped to aria2 verbatim — aria2 ≥ 1.36 fetches all
  segments. DASH (`.mpd`) follows the same rule.

### Fallback (no browser prompts)

`sendToHost` never opens a `velocita://` URL in a tab — Chrome would show
an external-protocol confirmation dialog for it, which is exactly what
IDM / FDM-style extensions avoid. Instead it walks three channels, in
order:

1. **Native Messaging** — bounded by a 3.5 s timeout (a spawned host that
   has become the primary app never ACKs, so an unbounded wait hangs).
2. **Loopback HTTP** — `POST http://127.0.0.1:<port>/api/add` works
   whenever Velocita is running, regardless of NM registration. Before
   this, the extension self-registers its real `chrome.runtime.id` via
   `POST /api/register-extension` so the *next* NM attempt also works.
3. **Wake + retry** — if the app was closed, the NM attempt in (1) already
   spawned `velocita.exe` (the host *is* the app), so the extension waits
   ~2.5 s for the loopback port to come up and retries HTTP once.

If all three fail, the extension returns a failure and the UI shows an
in-extension error (floating button red-flashes, popup status line) —
**no browser protocol dialog**.

The `velocita://` scheme remains registered on the OS for non-extension
sources (bookmarks, other apps launching Velocita), but the extension
does not use it as a delivery channel.

## Inspecting the service worker

- Chrome / Edge: `chrome://extensions` → Velocita card → **Service worker**
  → **Inspect views**.
- Firefox: `about:debugging#/runtime/this-firefox` → Velocita card →
  **Inspect**.

Look for log entries like:

- `[velocita] sniffer installed` — `content/sniffer.js` is alive in the
  page world.
- `[velocita] content script installed` — `content/main.js` is alive in
  the isolated world.
- `Velocita: intercept success for …` — the SW cancelled a browser
  download and handed it to Velocita.

To force-kill the SW for the lifecycle test:
`chrome://serviceworker-internals` → find Velocita → **Stop**. Trigger any
download afterwards and verify the listener still fires (proves listeners
are registered at module top level, not inside `onInstalled`).

## Debugging Native Messaging

Four layers, from cheapest to most detailed:

### 1. Extension service-worker console (start here)

`chrome://extensions` → Velocita card → **Service worker** → **Inspect views**.

`background.js` now logs every NM outcome:

- `Velocita: NM send failed, falling back to HTTP: <reason>` — the reason
  string is Chrome's own. The classic one for this project:
  - **`Specified native messaging host not found.`** → the host JSON's
    `allowed_origins` doesn't list this extension (the placeholder bug),
    or the registry doesn't point at a readable JSON. Fix: let the
    extension self-register (`/api/register-extension`) or edit
    `com.velocita.host.json` manually.
  - `Native host has exited.` → the host (velocita.exe) started but
    crashed/exited before answering.
- `Velocita: NM host did not ACK (app was closed?)` → the host spawned but
  became the primary app without reading stdin; the extension moved on to
  HTTP after `NM_TIMEOUT_MS`.
- `Velocita: register-extension failed …` → loopback `/api/register-extension`
  unreachable (app not running, or browser integration disabled).

### 2. Chrome's own host-spawn trace (`--v=1`)

Chrome does **not** log native-messaging host lifecycle at the default
`--enable-logging` verbosity — the `chrome_debug.log` you may already have
only holds crash-pad / policy noise. To capture spawn + manifest decisions:

1. Fully quit Chrome.
2. Launch it with verbose logging (add to the shortcut or a console):
   ```
   "C:\Program Files\Google\Chrome\Application\chrome.exe" --enable-logging --v=1
   ```
3. Exercise the extension, then read:
   `%LOCALAPPDATA%\Google\Chrome\User Data\chrome_debug.log`

You'll see lines like `native_message_process_launcher_win` / manifest
resolution errors. The verbose log is noisy — grep for `native`/`messag`.

### 3. Frame dumper (see exactly what the extension sends)

`debug/native-messaging-dump.js` (Node ≥ 18) is a drop-in fake host that
records every frame Chrome delivers:

```
node browser_extension/debug/native-messaging-dump.js
# → [velocita-nm] logging to %TEMP%\velocita-nm-dump.log
```

To route the real extension into it, temporarily point the host registry
keys at the script (keep `allowed_origins` = your extension ID), reload
the extension, trigger a download, then restore:

```
HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.velocita.host
  →  node "C:\path\to\native-messaging-dump.js"
```

The log shows the exact JSON payload (`RX { … }`) and the ack sent back.
Set `VELOCITA_NM_FORWARD=1` to also forward each frame to the real app's
`/api/host` for end-to-end checks.

### 4. Host side (velocita.exe as NM host)

When Chrome spawns `velocita.exe` as the host, the app's `Logger` output
(stderr) is only surfaced through the Chrome `--v=1` debug log (layer 2).
The relevant lines come from `Velocita.HostBridge`:
`stdin probe: …`, `POST /api/host failed: …`, and `Velocita.Main: argv: …`.
The app also writes `aria2.log` under its app-support dir if you need to
confirm the task actually reached aria2.

## Known cross-browser deltas

| API | Chrome / Edge | Firefox |
|-----|---------------|---------|
| `chrome.downloads.onDeterminingFilename` | yes | no — rely on `waitForFilename` |
| `chrome.downloads.setShelfEnabled` | yes | no — no-op |
| `chrome.scripting.executeScript({ world: "MAIN" })` | yes (≥ 110) | yes (≥ 121, hence the bumped `strict_min_version`) |
| `contextMenus` `contexts: ["video"]` | yes | no — context menu item silently absent |
| MV3 `type: "module"` background | yes | no — `background.js` must stay plain script (no `import`) |

## Reference implementation

The download-interception pipeline (listener registration, `waitForFilename`,
`processingDownloads` / `redirectedToAria` dedupe, MV3 service-worker
lifecycle handling) is lifted from
`velocita/_reference/motrix-webextension/app/scripts/background.js` and
`app/scripts/core/interceptor.js`. The Motrix frame-by-frame logic is
adapted to Velocita's Native-Messaging + loopback HTTP wire instead of
aria2 JSON-RPC. The sniffer + floating button are new for Velocita.