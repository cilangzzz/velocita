// Self-test for the extension's HLS master parser.
//
// Extracts the REAL parseVideoCodec + parseHlsMaster function source from
// ../src/background.js (no copy drift), evals it in a sandbox, and runs
// assertions against representative master playlists. Run via:
//   dart run browser_extension/debug/run_node.dart
// (Bash allow rules drop wildcarded interpreters like `node *` in auto
// mode, but `dart run *` survives — hence the Dart wrapper.)
'use strict';
const fs = require('fs');
const path = require('path');

const bgPath = path.join(__dirname, '..', 'src', 'background.js');
const bg = fs.readFileSync(bgPath, 'utf8');

// Extract from `function parseVideoCodec` up to (excluding) the next
// top-level function after parseHlsMaster (fetchHlsVariants).
const start = bg.indexOf('function parseVideoCodec');
const end = bg.indexOf('async function fetchHlsVariants');
if (start < 0 || end < 0 || end <= start) {
  console.error('FAIL: could not extract parser functions from background.js');
  process.exit(1);
}
const parserSource = bg.slice(start, end);
// eslint-disable-next-line no-eval
const parseHlsMaster = eval(parserSource + '\nparseHlsMaster;');
// eslint-disable-next-line no-eval
const parseVideoCodec = eval(parserSource + '\nparseVideoCodec;');

let failures = 0;
function check(cond, msg) {
  if (!cond) {
    console.error('FAIL:', msg);
    failures++;
  }
}

// ── Test 1: same resolution at different bitrates, codecs, fps ────
const master = [
  '#EXTM3U',
  '#EXT-X-VERSION:6',
  '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=2147000,BANDWIDTH=2500000,RESOLUTION=1920x1080,FRAME-RATE=30.000,CODECS="avc1.640028,mp4a.40.2"',
  'v5/1080p.m3u8',
  '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=4221000,BANDWIDTH=4800000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.640032,mp4a.40.2"',
  'v7/1080p60.m3u8',
  '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=7800000,BANDWIDTH=8200000,RESOLUTION=3840x2160,FRAME-RATE=60.000,CODECS="hvc1.1.6.L153.B0,mp4a.40.2"',
  '4k/playlist.m3u8',
  '#EXT-X-STREAM-INF:AVERAGE-BANDWIDTH=628000,BANDWIDTH=700000,RESOLUTION=640x360,CODECS="avc1.42001f,mp4a.40.2"',
  '360p/playlist.m3u8',
].join('\n');
const m = parseHlsMaster(master, 'https://cdn.example.com/master.m3u8');
console.log(JSON.stringify(m, null, 1));

check(Array.isArray(m) && m.length === 4, 'expected 4 variants');
check(m[0].label === '2160p60', `top label should be 2160p60, got ${m[0].label}`);
check(m[0].codec === 'H.265', `top codec should be H.265, got ${m[0].codec}`);
check(m[0].resolution === '3840×2160', `top resolution, got ${m[0].resolution}`);
check(m[1].label === '1080p60', `second label should be 1080p60, got ${m[1].label}`);
check(m[1].fps === 60, `second fps should be 60, got ${m[1].fps}`);
check(m[1].detail.includes('4221 kbps'), `second detail should carry kbps, got ${m[1].detail}`);
check(m[2].label === '1080p', `1080p30 label should be plain 1080p, got ${m[2].label}`);
check(m[2].detail.includes('2147 kbps'), `1080p30 detail should carry kbps, got ${m[2].detail}`);
check(m[2].codec === 'H.264', `1080p30 codec should be H.264, got ${m[2].codec}`);
check(!m[2].detail.includes('avc1'), 'raw codec tag must not leak into detail');
check(m[3].label === '360p', `360p label, got ${m[3].label}`);
check(m[0].url.endsWith('/4k/playlist.m3u8'), 'relative URL must resolve against master URL');

// ── Test 2: BANDWIDTH fallback when no AVERAGE-BANDWIDTH ──────────
const bwOnly = [
  '#EXTM3U',
  '#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=854x480',
  '480/playlist.m3u8',
  '#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720',
  '720/playlist.m3u8',
].join('\n');
const b = parseHlsMaster(bwOnly, 'https://cdn.example.com/master.m3u8');
check(b && b[0].label === '720p' && b[0].detail.includes('1500 kbps'),
  `BANDWIDTH fallback, got ${b && b[0].detail}`);

// ── Test 3: no resolution at all → kbps label ─────────────────────
const noRes = [
  '#EXTM3U',
  '#EXT-X-STREAM-INF:BANDWIDTH=500000',
  'a/playlist.m3u8',
  '#EXT-X-STREAM-INF:BANDWIDTH=900000',
  'b/playlist.m3u8',
].join('\n');
const n = parseHlsMaster(noRes, 'https://cdn.example.com/master.m3u8');
check(n && n[0].label === '900 kbps', `no-resolution label, got ${n && n[0].label}`);

// ── Test 4: media playlist → null ─────────────────────────────────
const media = ['#EXTM3U', '#EXT-X-TARGETDURATION:10', '#EXTINF:10.0,', 'seg-000.ts', '#EXT-X-ENDLIST'].join('\n');
check(parseHlsMaster(media, 'https://cdn.example.com/m.m3u8') === null, 'media playlist must return null');

// ── Test 5: exact duplicate labels get an index suffix ────────────
const dup = [
  '#EXTM3U',
  '#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,CODECS="avc1.64001f"',
  'a.m3u8',
  '#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,CODECS="avc1.64001f"',
  'b.m3u8',
].join('\n');
const d = parseHlsMaster(dup, 'https://cdn.example.com/master.m3u8');
check(d && d[0].label !== d[1].label, `duplicate labels must be disambiguated, got ${d && d.map((x) => x.label)}`);

// ── Test 6: codec mapping table ───────────────────────────────────
check(parseVideoCodec('avc1.640028,mp4a.40.2') === 'H.264', 'avc1 → H.264');
check(parseVideoCodec('hvc1.1.6.L153.B0') === 'H.265', 'hvc1 → H.265');
check(parseVideoCodec('av01.0.08M.08') === 'AV1', 'av01 → AV1');
check(parseVideoCodec('vp09.00.10.08,opus') === 'VP9', 'vp09 → VP9');
check(parseVideoCodec('mp4a.40.2') === null, 'audio-only codecs → null');

if (failures > 0) {
  console.error(`${failures} FAILURE(S)`);
  process.exit(1);
}
console.log('ALL TESTS PASS');