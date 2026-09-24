import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const source = readFileSync(resolve(root, 'LumaLex/Services/Assessment/VocabularyAssessmentEngine.swift'), 'utf8');
const words = [...source.matchAll(/\.init\(word: "([^"]+)", level: \.(a1|a2|b1|b2|c1|c2)\)/g)]
  .map(([, word, level]) => ({ word, level }));
const levels = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'];
const sizes = [500, 1200, 2500, 4500, 8000, 12000];

export function estimate(knownWords) {
  const known = new Set(knownWords.map(word => word.toLowerCase().trim()));
  let reached = 0;
  for (const [index, level] of levels.entries()) {
    if (words.filter(item => item.level === level && known.has(item.word)).length >= 1) reached = index;
    else break;
  }
  const knownCount = words.filter(item => known.has(item.word)).length;
  const withinBand = knownCount === 0 ? 0 : Math.min(knownCount * 50, 500);
  return { vocabularySize: sizes[reached] + withinBand };
}

function selfTest() {
  assert.equal(words.length, 12, 'The Swift question bank changed; review this harness');
  for (const level of levels) assert.equal(words.filter(item => item.level === level).length, 2);
  assert.deepEqual(estimate([]), { vocabularySize: 500 });
  assert.deepEqual(estimate(words.map(item => item.word)), { vocabularySize: 12500 });
  assert.deepEqual(estimate(['house', 'journey', 'benefit']), { vocabularySize: 2650 });
  console.log('Virtual assessment parity checks passed.');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.includes('--self-test')) selfTest();
  else if (process.argv.includes('--questions')) console.log(JSON.stringify(words, null, 2));
  else {
    const answers = process.argv.find(argument => argument.startsWith('--known='));
    if (!answers) throw new Error('Use --questions, --self-test, or --known=word,word');
    console.log(JSON.stringify(estimate(answers.slice('--known='.length).split(',').filter(Boolean)), null, 2));
  }
}
