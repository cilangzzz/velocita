// Velocita sniffer — MAIN world.
//
// This script runs in the page's own JS context (not the isolated
// world), so the page's fetch / XMLHttpRequest / MediaSource /
// SourceBuffer / URL.createObjectURL calls hit OUR wrappers. Each
// candidate URL is forwarded to the isolated-world content script via
// window.postMessage, which forwards it to the background SW.
//
// IMPORTANT: there is no `import` syntax in this file — Firefox MV3
// content scripts run as classic scripts even when the manifest
// declares `type: "module"` for the SW.
//
// Cross-browser: the hooks below are standard and identical across
// Chromium / WebKit / Gecko. No `chrome.*` APIs used here.

(() => {
  // ── helpers ────────────────────────────────────────────────

  const SEEN = new Set();

  const MEDIA_RE =
    /\.(m3u8|m3u8\?|\?m3u8|mpd|mp4|m4s|m4a|webm|mkv|mov|ts|aac|flac|mp3|ogg|wav)(\?|$|#)/i;

  function looksMedia(url, accept) {
    if (!url || typeof url !== "string") return false;
    if (
      url.startsWith("blob:") ||
      url.startsWith("data:") ||
      url.startsWith("javascript:")
    ) {
      return false;
    }
    if (MEDIA_RE.test(url)) return true;
    if (typeof accept === "string" && /(video|audio)\//i.test(accept)) {
      return true;
    }
    return false;
  }

  function guessMime(url) {
    const u = String(url).toLowerCase();
    if (/\.m3u8(\?|#|$)/i.test(u)) return "application/x-mpegURL";
    if (/\.mpd(\?|#|$)/i.test(u)) return "application/dash+xml";
    if (/\.ts(\?|#|$)/i.test(u)) return "video/mp2t";
    const m = u.match(/\.([a-z0-9]{2,4})(?:\?|#|$)/i);
    return m ? `${u.includes("audio") ? "audio" : "video"}/${m[1]}` : null;
  }

  function post(url, mime) {
    if (SEEN.has(url)) return;
    SEEN.add(url);
    try {
      window.postMessage(
        {
          kind: "velocita/sniff",
          url,
          mime: mime || null,
          ts: Date.now(),
        },
        "*",
      );
    } catch (_) {}
  }

  // ── fetch ──────────────────────────────────────────────────

  try {
    const _fetch = window.fetch;
    if (typeof _fetch === "function") {
      window.fetch = function (input, init) {
        let p;
        try {
          let url = null;
          let accept = null;
          if (typeof input === "string") {
            url = input;
          } else if (input && typeof input === "object") {
            url = input.url || null;
            if (input.headers && typeof input.headers.get === "function") {
              accept = input.headers.get("accept");
            } else if (init && init.headers) {
              accept = String(init.headers);
            }
          }
          if (url && looksMedia(url, accept)) post(url, guessMime(url));
        } catch (_) {}
        p = _fetch.apply(this, arguments);
        // Swallow the page's unhandled-rejection console noise WITHOUT
        // changing the promise the page receives. Attaching a no-op catch
        // marks the rejection as handled at the engine level, while the
        // page still gets the SAME promise object to .then/.catch on.
        // Without this, every page fetch the page itself leaves unhandled
        // (e.g. a blocked request) surfaces as
        //   Uncaught (in promise) TypeError: Failed to fetch
        // attributed to this injected sniffer.
        if (p && typeof p.catch === "function") p.catch(() => {});
        return p;
      };
    }
  } catch (_) {}

  // ── XMLHttpRequest ────────────────────────────────────────

  try {
    const _open = XMLHttpRequest.prototype.open;
    const _send = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (method, url) {
      try {
        this.__velocitaUrl = url == null ? null : String(url);
      } catch (_) {}
      return _open.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function () {
      try {
        const u = this.__velocitaUrl;
        if (u && looksMedia(u, null)) post(u, guessMime(u));
      } catch (_) {}
      return _send.apply(this, arguments);
    };
  } catch (_) {}

  // ── MediaSource.addSourceBuffer + SourceBuffer.appendBuffer ─
  // MSE-driven players (hls.js, dash.js, Shaka) call addSourceBuffer
  // with the manifest's mime type. We surface that as a candidate so
  // the floating button still has a hit even when fetch is wrapped by
  // the player itself.

  try {
    if (typeof MediaSource !== "undefined" && MediaSource.prototype.addSourceBuffer) {
      const _addSB = MediaSource.prototype.addSourceBuffer;
      MediaSource.prototype.addSourceBuffer = function (mime) {
        try {
          post(String(location.href), mime || null);
        } catch (_) {}
        return _addSB.call(this, mime);
      };
    }
    if (typeof SourceBuffer !== "undefined" && SourceBuffer.prototype.appendBuffer) {
      const _append = SourceBuffer.prototype.appendBuffer;
      SourceBuffer.prototype.appendBuffer = function (buf) {
        try {
          if (this.mimeType && !this.__velocitaReportedMime) {
            this.__velocitaReportedMime = true;
            post(String(location.href), this.mimeType);
          }
        } catch (_) {}
        return _append.call(this, buf);
      };
    }
  } catch (_) {}

  // ── URL.createObjectURL ───────────────────────────────────
  // Catches blob: URLs that the player feeds to <video src=...>.
  // We post the *page URL* since the blob itself is opaque, but flag
  // the candidate with the blob's MIME so the picker prefers it when
  // the video has no other source.

  try {
    if (typeof URL !== "undefined" && URL.createObjectURL) {
      const _create = URL.createObjectURL;
      URL.createObjectURL = function (blob) {
        try {
          if (
            blob &&
            typeof blob === "object" &&
            typeof blob.type === "string" &&
            /^(video|audio)\//.test(blob.type)
          ) {
            post(String(location.href), blob.type);
          }
        } catch (_) {}
        return _create.apply(this, arguments);
      };
    }
  } catch (_) {}

  // ── marker ────────────────────────────────────────────────
  // The isolated-world script reads its own console for `[velocita]
  // content script installed`; this one writes here too for parity
  // when manually inspecting the page world.
  try { console.info("[velocita] sniffer installed"); } catch (_) {}
})();