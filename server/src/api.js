import http from 'node:http';
import { timingSafeEqual } from 'node:crypto';

const vocabularyKeys = [
  'word', 'lemma', 'ipa', 'part_of_speech', 'chinese', 'definition',
  'context_explanation', 'example', 'collocations', 'difficulty_cefr', 'note'
];

const prompt = `You are the vocabulary explanation engine for an English-learning application.
Explain the target expression only in its provided context. Give the most appropriate Simplified Chinese meaning, a concise English definition suitable for the user's CEFR level, IPA when applicable, part of speech, why this meaning applies, one natural example, up to three collocations, and any relevant register or domain note. Do not list irrelevant meanings. Return JSON only.`;

export function createServer({ apiKey = process.env.GEMINI_API_KEY,
  model = process.env.GEMINI_MODEL || 'gemini-2.5-flash',
  appToken = process.env.LUMALEX_APP_TOKEN,
  geminiFetch = fetch } = {}) {
  const requestCounts = new Map();
  return http.createServer(async (request, response) => {
    try {
      if (request.method === 'GET' && request.url === '/health') {
        return json(response, 200, { ok: true });
      }
      if (request.method !== 'POST' || ![
        '/v1/vocabulary/explain', '/v1/translate', '/v1/transcribe'
      ].includes(request.url)) {
        return json(response, 404, { error: 'Not found' });
      }
      if (appToken && !tokensMatch(request.headers.authorization, `Bearer ${appToken}`)) {
        return json(response, 401, { error: 'Unauthorized' });
      }
      const key = request.socket.remoteAddress || 'unknown';
      const now = Date.now();
      const previous = requestCounts.get(key);
      const count = previous && now - previous.since < 60_000 ? previous.count + 1 : 1;
      requestCounts.set(key, { since: count === 1 ? now : previous.since, count });
      if (requestCounts.size > 1000) {
        for (const [address, entry] of requestCounts) {
          if (now - entry.since >= 60_000) requestCounts.delete(address);
        }
      }
      if (count > 30) return json(response, 429, { error: 'Rate limit exceeded' });
      if (!apiKey) return json(response, 503, { error: 'Gemini is not configured' });
      const body = await readJSON(request, request.url === '/v1/transcribe' ? 18_000_000 : 32_000);
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new BadRequest();
      let result;
      if (request.url === '/v1/vocabulary/explain') {
        validateString(body.word, 120);
        validateString(body.sentence, 2000);
        if (!['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].includes(body.cefrLevel)) throw new BadRequest();
        result = await generate(geminiFetch, apiKey, model, [
          { text: `${prompt}\nUSER LEVEL: ${body.cefrLevel}\nTARGET: ${body.word}\nCONTEXT: ${body.sentence}\nJSON KEYS: ${vocabularyKeys.join(', ')}` }
        ]);
        if (!validVocabulary(result)) throw new UpstreamError();
        result.collocations = result.collocations.slice(0, 3);
      } else if (request.url === '/v1/translate') {
        if (!Array.isArray(body.sentences) || body.sentences.length < 1 || body.sentences.length > 30) throw new BadRequest();
        body.sentences.forEach(value => validateString(value, 500));
        result = await generate(geminiFetch, apiKey, model, [
          { text: `Translate each English sentence to natural Simplified Chinese. Return JSON as {"translations":["..."]} with exactly ${body.sentences.length} strings in the same order. Do not include commentary.\n${JSON.stringify(body.sentences)}` }
        ]);
        if (!Array.isArray(result.translations) || result.translations.length !== body.sentences.length ||
            result.translations.some(value => typeof value !== 'string')) throw new UpstreamError();
      } else {
        validateString(body.mimeType, 100);
        if (!/^audio\/(mpeg|mp4|x-m4a|wav|x-wav)$/.test(body.mimeType) ||
            typeof body.audioBase64 !== 'string' || body.audioBase64.length > 16_000_000 ||
            !/^[A-Za-z0-9+/]+={0,2}$/.test(body.audioBase64)) throw new BadRequest();
        result = await generate(geminiFetch, apiKey, model, [
          { text: 'Transcribe the English speech. Return JSON {"segments":[{"start":0.0,"end":1.0,"english":"..."}]} with accurate times in seconds. No translation or commentary.' },
          { inlineData: { mimeType: body.mimeType, data: body.audioBase64 } }
        ]);
        if (!Array.isArray(result.segments) || result.segments.length > 5000 ||
            result.segments.some(segment => !Number.isFinite(segment.start) ||
              !Number.isFinite(segment.end) || segment.start < 0 || segment.end <= segment.start ||
              typeof segment.english !== 'string' || !segment.english.trim())) throw new UpstreamError();
      }
      return json(response, 200, result);
    } catch (error) {
      const code = error instanceof BadRequest ? 400 : error instanceof UpstreamError ? 502 : 500;
      return json(response, code, { error: code === 400 ? 'Invalid request' : 'Service unavailable' });
    }
  });
}

async function generate(geminiFetch, apiKey, model, parts) {
  let response;
  try {
    response = await geminiFetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({ contents: [{ role: 'user', parts }],
        generationConfig: { responseMimeType: 'application/json' } }),
      signal: AbortSignal.timeout(60_000)
    });
    if (!response.ok) throw new UpstreamError();
    const data = await response.json();
    const content = data.candidates?.[0]?.content?.parts?.find(part => typeof part.text === 'string')?.text;
    if (!content) throw new UpstreamError();
    return JSON.parse(content);
  } catch { throw new UpstreamError(); }
}

function validVocabulary(value) {
  return value && vocabularyKeys.every(key => key === 'collocations' ?
    Array.isArray(value[key]) && value[key].every(item => typeof item === 'string') :
    typeof value[key] === 'string') && value.word && value.chinese && value.definition;
}

function validateString(value, max) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw new BadRequest();
}

async function readJSON(request, limit) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > limit) throw new BadRequest();
    chunks.push(chunk);
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new BadRequest(); }
}

function tokensMatch(actual, expected) {
  if (typeof actual !== 'string') return false;
  const a = Buffer.from(actual);
  const b = Buffer.from(expected);
  if (a.length !== b.length) {
    // Burn the comparison cost before revealing a length mismatch.
    timingSafeEqual(b, b);
    return false;
  }
  return timingSafeEqual(a, b);
}

function json(response, status, value) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store' });
  response.end(JSON.stringify(value));
}

class BadRequest extends Error {}
class UpstreamError extends Error {}
