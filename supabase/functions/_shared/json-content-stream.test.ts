// Streaming extractor for one top-level string field of a JSON object (coach replies).
import { assertEquals } from 'jsr:@std/assert@1';
import { JsonFieldStream } from './json-content-stream.ts';

/** Feeds [chunks] and returns everything emitted, joined. */
function run(chunks: string[], field = 'content'): string {
  const s = new JsonFieldStream(field);
  return chunks.map((c) => s.push(c)).join('');
}

/** Every possible split of [json] into chunks of [size] characters. */
function chunked(json: string, size: number): string[] {
  const out: string[] = [];
  for (let i = 0; i < json.length; i += size) out.push(json.slice(i, i + size));
  return out;
}

const reply = {
  content: 'Keep the bar "close" to your shins.\nBrace\\breathe — tempo 3‑1‑1. Été 💪 done',
  cacheable: false,
  plan_change: null,
};

Deno.test('emits exactly the decoded field value, whatever the chunk size', () => {
  const json = JSON.stringify(reply);
  for (const size of [1, 2, 3, 5, 7, 13, json.length]) {
    assertEquals(run(chunked(json, size)), reply.content, `chunk size ${size}`);
  }
});

Deno.test('the field may come after other fields, with whitespace', () => {
  const json = '{\n  "cacheable": true,\n  "plan_change": null,\n  "content" : "Rest 2 minutes."\n}';
  assertEquals(run(chunked(json, 4)), 'Rest 2 minutes.');
});

Deno.test('a nested "content" key or a value equal to "content" is ignored', () => {
  const json = JSON.stringify({
    note: 'content',
    plan_change: { content: 'nested — must not leak', reason_en: '"content": "fake"' },
    content: 'Real reply.',
  });
  assertEquals(run(chunked(json, 3)), 'Real reply.');
});

Deno.test('escapes split across chunks are decoded once complete', () => {
  assertEquals(run(['{"content":"a\\', 'nb"}']), 'a\nb');
  assertEquals(run(['{"content":"caf\\u00', 'e9"}']), 'café');
  assertEquals(run(['{"content":"\\ud83d', '\\udcaa!"}']), '💪!');
  assertEquals(run(['{"content":"q\\"', 'uote\\\\"}']), 'q"uote\\');
});

Deno.test('text is emitted as soon as it arrives, before the object is complete', () => {
  const s = new JsonFieldStream('content');
  assertEquals(s.push('{"content":"Hel'), 'Hel');
  assertEquals(s.push('lo wor'), 'lo wor');
  assertEquals(s.push('ld","cacheable":'), 'ld');
  assertEquals(s.push('true}'), '');
});

Deno.test('nothing is emitted when the field is missing or not a string', () => {
  assertEquals(run(['{"cacheable":true,"plan_change":null}']), '');
  assertEquals(run(['{"content":null}']), '');
});
