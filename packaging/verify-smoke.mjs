import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';

const app = process.argv[2];
assert(app, 'Pass the smoke-enabled desktop executable path.');
const artifacts = resolve('artifacts');
mkdirSync(artifacts, { recursive: true });
const output = mkdtempSync(resolve(artifacts, 'smoke-'));
const executable = resolve(app);
const sandbox = process.platform === 'darwin' && process.argv.includes('--deny-network');
const run = spawnSync(
  sandbox ? '/usr/bin/sandbox-exec' : executable,
  sandbox ? ['-p', '(version 1) (allow default) (deny network-outbound)', executable] : [],
  { stdio: 'inherit', timeout: 240_000, env: { ...process.env, SANCTUARY_SMOKE_DIR: output } },
);
assert.equal(run.status, 0, `Smoke app failed. Results directory: ${output}. ${run.error ?? ''}`);
assert.equal(JSON.parse(readFileSync(resolve(output, 'smoke-result.json'), 'utf8')).ok, true);

function probe(file) {
  const { streams } = JSON.parse(execFileSync('ffprobe', [
    '-v', 'error', '-show_entries', 'stream=codec_name,width,height,r_frame_rate,nb_frames',
    '-of', 'json', resolve(output, file),
  ], { encoding: 'utf8' }));
  assert.equal(streams.length, 1);
  return streams[0];
}

for (const [name, width, height, frames] of [
  ['landscape.mp4', 1920, 1080, '30'], ['ultrawide.mp4', 3840, 960, '30'],
  ['portrait.mp4', 1080, 1920, '30'], ['default-loop.mp4', 1920, 1080, '450'],
]) {
  const data = probe(name);
  assert.deepEqual([data.codec_name, data.width, data.height, data.r_frame_rate, data.nb_frames],
    ['h264', width, height, '30/1', frames]);
}
const still = probe('odd.png');
assert.deepEqual([still.codec_name, still.width, still.height], ['png', 721, 1281]);
assert(!readdirSync(output).some(name => name === 'cancelled.mp4' || name.startsWith('.sanctuary-')),
  'A cancelled export left an incomplete file.');

const sampleWidth = 96;
const sampleHeight = 54;
const frameSize = sampleWidth * sampleHeight;
const decoded = execFileSync('ffmpeg', [
  '-v', 'error', '-i', resolve(output, 'default-loop.mp4'),
  '-vf', `scale=${sampleWidth}:${sampleHeight},format=gray`, '-f', 'rawvideo', 'pipe:1',
], { maxBuffer: 4 * 1024 * 1024 });
assert.equal(decoded.length, frameSize * 450);
function frameDistance(a, b) {
  let sum = 0;
  for (let pixel = 0; pixel < frameSize; pixel++) {
    sum += Math.abs(decoded[a * frameSize + pixel] - decoded[b * frameSize + pixel]);
  }
  return sum / frameSize;
}
const adjacent = Array.from({ length: 449 }, (_, i) => frameDistance(i, i + 1)).sort((a, b) => a - b);
const seam = frameDistance(449, 0);
const p95 = adjacent[Math.floor(adjacent.length * .95)];
assert(seam <= Math.max(1, p95 * 2), `Encoded seam delta ${seam} exceeds the motion tolerance.`);
console.log(`Decoded seam delta ${seam.toFixed(3)} grayscale levels (in-loop adjacent p95 ${p95.toFixed(3)}).`);
console.log(`Verified output files in ${output}`);
