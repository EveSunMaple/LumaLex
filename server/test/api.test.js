import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createServer } from '../src/api.js';

const explanation = {
  word: 'price in', lemma: 'price in', ipa: '', part_of_speech: 'phrasal verb',
  chinese: '计入价格', definition: 'to reflect an expected event in a current price',
  context_explanation: 'The cut is expected.', example: 'Markets priced in the news.',
  collocations: ['price in a cut'], difficulty_cefr: 'B2', note: 'finance'
};
const server = createServer({ apiKey: 'test', appToken: 'token', geminiFetch: async () => ({
  ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: JSON.stringify(explanation) }] } }] })
}) });
let base;

before(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

test('health responds without a token', async () => {
  const response = await fetch(`${base}/health`);
  assert.equal(response.status, 200);
});

test('rejects unauthenticated requests', async () => {
  const response = await fetch(`${base}/v1/vocabulary/explain`, { method: 'POST' });
  assert.equal(response.status, 401);
});

test('validates input before calling Gemini', async () => {
  const response = await fetch(`${base}/v1/vocabulary/explain`, {
    method: 'POST', headers: { authorization: 'Bearer token' },
    body: JSON.stringify({ word: 'test', sentence: 'Test', cefrLevel: 'invalid' })
  });
  assert.equal(response.status, 400);
});

test('rejects JSON null instead of crashing', async () => {
  const response = await fetch(`${base}/v1/translate`, {
    method: 'POST', headers: { authorization: 'Bearer token' }, body: 'null'
  });
  assert.equal(response.status, 400);
});

test('returns validated structured explanation', async () => {
  const response = await fetch(`${base}/v1/vocabulary/explain`, {
    method: 'POST', headers: { authorization: 'Bearer token' },
    body: JSON.stringify({ word: 'price in', sentence: 'They priced in the cut.', cefrLevel: 'B2' })
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), explanation);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('rejects malformed model output', async () => {
  const broken = createServer({ apiKey: 'test', geminiFetch: async () => ({
    ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] })
  }) });
  await new Promise(resolve => broken.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${broken.address().port}/v1/vocabulary/explain`, {
      method: 'POST', body: JSON.stringify({ word: 'test', sentence: 'A test.', cefrLevel: 'B1' })
    });
    assert.equal(response.status, 502);
  } finally { broken.close(); }
});

test('translation preserves sentence count', async () => {
  const translating = createServer({ apiKey: 'test', geminiFetch: async () => ({
    ok: true, json: async () => ({ candidates: [{ content: { parts: [
      { text: JSON.stringify({ translations: ['你好', '再见'] }) }
    ] } }] })
  }) });
  await new Promise(resolve => translating.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${translating.address().port}/v1/translate`, {
      method: 'POST', body: JSON.stringify({ sentences: ['Hello', 'Goodbye'] })
    });
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).translations, ['你好', '再见']);
  } finally { translating.close(); }
});

test('transcription validates timing', async () => {
  const transcribing = createServer({ apiKey: 'test', geminiFetch: async () => ({
    ok: true, json: async () => ({ candidates: [{ content: { parts: [
      { text: JSON.stringify({ segments: [{ start: 2, end: 1, english: 'bad' }] }) }
    ] } }] })
  }) });
  await new Promise(resolve => transcribing.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${transcribing.address().port}/v1/transcribe`, {
      method: 'POST', body: JSON.stringify({ mimeType: 'audio/mpeg', audioBase64: 'YQ==' })
    });
    assert.equal(response.status, 502);
  } finally { transcribing.close(); }
});
