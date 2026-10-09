#!/usr/bin/env node
// Velocita — Native Messaging frame dumper / debug host.
//
// Chrome / Edge / Firefox Native Messaging wire format:
//   each frame = 4-byte little-endian uint32 length + UTF-8 JSON body.
//
// This script stands in for `velocita.exe` as the Native Messaging host
// so you can see EXACTLY what the extension sends and test the protocol
// in isolation, without touching the real app:
//
//   1. `node native-messaging-dump.js` (run once to sanity-check)
//   2. Temporarily point the host registry keys at this script (see the
//      DEBUG-NATIVE-MESSAGING.md notes in the repo root README):
//        HKCU\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.velocita.host
//          →  node "C:\…\native-messaging-dump.js"
//      ...with allowed_origins matching your loaded extension ID.
//   3. Reload the extension, trigger a download / context-menu action.
//   4. Watch VELOCITA_NM_LOG (default: %TEMP%\velocita-nm-dump.log).
//   5. Restore the registry key to the real velocita.exe JSON.
//
// Env vars:
//   VELOCITA_NM_LOG       log file path (default %TEMP%\velocita-nm-dump.log)
//   VELOCITA_NM_FORWARD   "1" = also POST each frame to the real app's
//                         http://127.0.0.1:16800/api/host (mimics the real
//                         host_bridge) — handy for end-to-end checks.

'use strict';

const fs = require('fs');
const path = require('path');

const LOG =
  process.env.VELOCITA_NM_LOG ||
  path.join(
    process.env.TEMP || process.env.TMPDIR || '.',
    'velocita-nm-dump.log',
  );

function log(prefix, obj) {
  const line =
    `[${new Date().toISOString()}] ${prefix} ` +
    JSON.stringify(obj, null, 2) +
    '\n';
  fs.appendFileSync(LOG, line, 'utf8');
  process.stderr.write(line);
}

function readFrame(input) {
  return new Promise((resolve, reject) => {
    const header = Buffer.alloc(4);
    let headerRead = 0;
    let body = null;
    let bodyRead = 0;
    let bodyLen = 0;

    input.on('data', (chunk) => {
      try {
        if (body === null) {
          const need = 4 - headerRead;
          const take = Math.min(need, chunk.length);
          chunk.copy(header, headerRead, 0, take);
          headerRead += take;
          chunk = chunk.subarray(take);
          if (headerRead === 4) {
            bodyLen = header.readUInt32LE(0);
            if (bodyLen === 0) throw new Error('zero-length frame');
            if (bodyLen > 1024 * 1024) throw new Error(`frame too large: ${bodyLen}`);
            body = Buffer.alloc(bodyLen);
          }
        }
        if (body !== null) {
          const need = bodyLen - bodyRead;
          const take = Math.min(need, chunk.length);
          chunk.copy(body, bodyRead, 0, take);
          bodyRead += take;
          if (bodyRead === bodyLen) {
            input.pause();
            resolve(body.toString('utf8'));
          }
        }
      } catch (e) {
        reject(e);
      }
    });
    input.on('end', () => {
      if (body === null || bodyRead < bodyLen) {
        reject(new Error('stream ended mid-frame'));
      }
    });
    input.on('error', reject);
  });
}

function writeFrame(output, obj) {
  const body = Buffer.from(JSON.stringify(obj), 'utf8');
  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);
  output.write(header);
  output.write(body);
}

async function forwardToApp(payload) {
  try {
    const res = await fetch('http://127.0.0.1:16800/api/host', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    log('FORWARD', { status: res.status, payload });
    return res.ok;
  } catch (e) {
    log('FORWARD-ERR', { error: String(e) });
    return false;
  }
}

async function main() {
  fs.appendFileSync(
    LOG,
    `\n===== velocita NM dump host started ${new Date().toISOString()} =====\n`,
  );
  process.stderr.write(`[velocita-nm] logging to ${LOG}\n`);

  // The host process is torn down when stdin closes, so loop forever.
  for (;;) {
    let frameText;
    try {
      frameText = await readFrame(process.stdin);
    } catch (e) {
      log('READ-ERR', { error: String(e) });
      break;
    }
    let parsed;
    try {
      parsed = JSON.parse(frameText);
    } catch (e) {
      log('PARSE-ERR', { error: String(e), raw: frameText });
      writeFrame(process.stdout, { ok: false, error: 'invalid json' });
      continue;
    }
    log('RX', parsed);

    // Mirror the real host_bridge response shape so the extension's
    // `sendNativeMessage` resolves like it would against velocita.exe.
    const url = parsed && typeof parsed.url === 'string' ? parsed.url.trim() : '';
    if (!url) {
      writeFrame(process.stdout, { ok: false, error: 'missing url' });
      continue;
    }
    if (process.env.VELOCITA_NM_FORWARD === '1') {
      await forwardToApp(parsed);
    }
    writeFrame(process.stdout, { ok: true, debug: true });
    process.stdout.flush && process.stdout.flush();
  }
}

main().catch((e) => {
  process.stderr.write(`[velocita-nm] fatal: ${e.stack}\n`);
  process.exit(1);
});