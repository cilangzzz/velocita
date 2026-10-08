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

### Fallback

If Native Messaging fails (Velocita not running or NM not installed), the
extension opens `velocita://add?url=…` in a new tab. The OS launches
Velocita, which parses the URL via `app_links` and feeds it into the same
`AddRequest` pipeline.

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