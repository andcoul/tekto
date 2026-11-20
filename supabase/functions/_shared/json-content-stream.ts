// Pulls one top-level string field (the coach's `content`) out of a JSON object while it is
// still being streamed, so the app can show the reply as Claude writes it (contracts/
// backend-api.md `POST /coach-message`). The final object is still parsed and validated in
// full by callStructured; this only decides what to show early.

export class JsonFieldStream {
  #depth = 0;
  #inString = false;
  #escape = false;
  #unicode: string | null = null; // hex digits of a pending \uXXXX
  #highSurrogate: number | null = null;
  #expectKey = false; // next top-level string is a key
  #lastKey = '';
  #keyBuffer = '';
  #capturing = false; // inside the target field's string value
  #readingKey = false;

  constructor(private readonly field: string) {}

  /** Feeds one chunk of JSON text; returns the newly decoded characters of the field. */
  push(chunk: string): string {
    let out = '';
    for (const ch of chunk) {
      if (this.#inString) {
        out += this.#stringChar(ch);
        continue;
      }
      switch (ch) {
        case '{':
        case '[':
          this.#depth++;
          if (this.#depth === 1 && ch === '{') this.#expectKey = true;
          break;
        case '}':
        case ']':
          this.#depth--;
          break;
        case ',':
          if (this.#depth === 1) this.#expectKey = true;
          break;
        case ':':
          if (this.#depth === 1) this.#expectKey = false;
          break;
        case '"':
          this.#inString = true;
          if (this.#depth === 1 && this.#expectKey) {
            this.#readingKey = true;
            this.#keyBuffer = '';
          } else if (this.#depth === 1 && this.#lastKey === this.field) {
            this.#capturing = true;
          }
          break;
      }
    }
    return out;
  }

  /** Handles one character inside a string; returns what to emit for the target field. */
  #stringChar(ch: string): string {
    let decoded: string | null = null;

    if (this.#unicode !== null) {
      this.#unicode += ch;
      if (this.#unicode.length < 4) return '';
      const code = parseInt(this.#unicode, 16);
      this.#unicode = null;
      decoded = this.#fromCodeUnit(code);
    } else if (this.#escape) {
      this.#escape = false;
      if (ch === 'u') {
        this.#unicode = '';
        return '';
      }
      decoded = ESCAPES[ch] ?? ch;
    } else if (ch === '\\') {
      this.#escape = true;
      return '';
    } else if (ch === '"') {
      this.#inString = false;
      if (this.#readingKey) {
        this.#readingKey = false;
        this.#lastKey = this.#keyBuffer;
      } else if (this.#depth === 1) {
        this.#lastKey = ''; // a value ends; the next key decides again
      }
      this.#capturing = false;
      return '';
    } else {
      decoded = ch;
    }

    if (this.#readingKey) {
      this.#keyBuffer += decoded;
      return '';
    }
    return this.#capturing ? decoded : '';
  }

  /** Joins UTF-16 surrogate pairs so a split emoji is never emitted half-way. */
  #fromCodeUnit(code: number): string {
    if (code >= 0xd800 && code <= 0xdbff) {
      this.#highSurrogate = code;
      return '';
    }
    if (code >= 0xdc00 && code <= 0xdfff && this.#highSurrogate !== null) {
      const pair = String.fromCharCode(this.#highSurrogate, code);
      this.#highSurrogate = null;
      return pair;
    }
    return String.fromCharCode(code);
  }
}

const ESCAPES: Record<string, string> = { '"': '"', '\\': '\\', '/': '/', b: '\b', f: '\f', n: '\n', r: '\r', t: '\t' };
