import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const audio = readFileSync(fileURLToPath(new URL('../LumaLex/Resources/Demo.wav', import.meta.url)));
assert.equal(audio.toString('ascii', 0, 4), 'RIFF');
assert.equal(audio.toString('ascii', 8, 12), 'WAVE');
assert.equal(audio.toString('ascii', 36, 40), 'data');
const sampleRate = audio.readUInt32LE(24);
const bytesPerSecond = audio.readUInt32LE(28);
const duration = audio.readUInt32LE(40) / bytesPerSecond;
assert.equal(sampleRate, 16000);
assert.ok(duration > 10 && duration < 15);

const source = readFileSync(fileURLToPath(new URL('../LumaLex/Services/Audio/DemoContentSeeder.swift', import.meta.url)), 'utf8');
const timestamps = [...source.matchAll(/\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?), "/g)]
  .map(([, start, end]) => ({ start: Number(start), end: Number(end) }));
assert.equal(timestamps.length, 3);
for (const [index, segment] of timestamps.entries()) {
  assert.ok(segment.end > segment.start);
  assert.ok(segment.end <= duration);
  if (index > 0) assert.ok(segment.start >= timestamps[index - 1].end);
}
console.log(`Bundled demo WAV and ${timestamps.length} timed subtitles validated (${duration.toFixed(2)}s).`);
