// Coach-cache embeddings via the Edge Runtime's built-in gte-small model (research §8).
// No third-party vendor or API key. 384-dimensional, mean-pooled, normalized.
// If the runtime lacks `Supabase.ai`, callers should skip the cache (fallback: Voyage AI, research §8).

export const EMBEDDING_DIMENSIONS = 384;

export class EmbeddingUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EmbeddingUnavailableError';
  }
}

interface AiSession {
  run(input: string, opts: { mean_pool: boolean; normalize: boolean }): Promise<unknown>;
}

let _session: AiSession | null = null;

function getSession(): AiSession {
  if (_session) return _session;
  // deno-lint-ignore no-explicit-any -- `Supabase` is a global injected by the Edge Runtime
  const ai = (globalThis as any).Supabase?.ai;
  if (!ai?.Session) {
    throw new EmbeddingUnavailableError('Supabase.ai is not available in this runtime');
  }
  _session = new ai.Session('gte-small') as AiSession;
  return _session;
}

/** Embeds `text` into a 384-length vector. Throws EmbeddingUnavailableError on any failure. */
export async function embed(text: string): Promise<number[]> {
  const output = await getSession().run(text, { mean_pool: true, normalize: true });
  const vector = Array.isArray(output) ? output as number[] : Array.from(output as ArrayLike<number>);
  if (vector.length !== EMBEDDING_DIMENSIONS) {
    throw new EmbeddingUnavailableError(`Expected ${EMBEDDING_DIMENSIONS} dimensions, got ${vector.length}`);
  }
  return vector;
}
