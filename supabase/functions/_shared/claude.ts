import Anthropic from 'https://esm.sh/@anthropic-ai/sdk@0.27.0';

// Model constants (from research.md)
export const PLAN_MODEL = 'claude-sonnet-4-6';    // plan generation — called once per plan lifecycle
export const COACH_MODEL = 'claude-haiku-4-5-20251001'; // chat coach — real-time, cost-sensitive

let _client: Anthropic | null = null;

export function getAnthropicClient(): Anthropic {
  if (!_client) {
    _client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')! });
  }
  return _client;
}

/** Prompt caching config for coach conversations.
 *  The system prompt + user profile + plan (~2k tokens) is static per session.
 *  With caching, cached input tokens cost ~0.1× base price.
 */
export const CACHE_CONTROL = { type: 'ephemeral' as const };
