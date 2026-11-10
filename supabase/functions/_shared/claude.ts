// Anthropic client wrapper for Edge Functions (research §2, §13; contracts/ai-services.md).
// - Current-generation models; effort always explicit (Haiku 5.5 defaults to `medium`).
// - JSON via structured outputs (`output_config.format`) — no prefill, no forced tool_choice.
// - Streaming + finalMessage(); stop_reason checked before content is read.
// - One structured log line per call for the Performance Standards (ttft / total latency).
import Anthropic from 'npm:@anthropic-ai/sdk@1.6.0';
import { zodOutputFormat } from 'npm:@anthropic-ai/sdk@1.6.0/helpers/zod';
import type { z } from 'npm:zod@4.6.7';

export const PLAN_MODEL = 'claude-sonnet-5-5';  // Pro plan generation
export const COACH_MODEL = 'claude-haiku-5-5';  // chat coach, adaptation explanations, guardrail judge

/** Server-side refusal fallback (plan generation only; Haiku 5.5 has none). */
export const FALLBACK_BETA = 'server-side-fallback-2026-07-01';

export type Effort = 'low' | 'medium' | 'high' | 'xhigh' | 'max';

let _client: Anthropic | null = null;

export function getAnthropicClient(): Anthropic {
  if (!_client) {
    _client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY')! });
  }
  return _client;
}

/** Prompt caching marker for stable prefixes (system prompt + user context). */
export const CACHE_CONTROL = { type: 'ephemeral' as const };

export type ClaudeFailureReason = 'refusal' | 'max_tokens' | 'api_error' | 'timeout' | 'invalid_output';

/** Any reason the model could not produce a usable answer. Callers map this to their fallback. */
export class ClaudeUnavailableError extends Error {
  constructor(readonly reason: ClaudeFailureReason, message: string, cause?: unknown) {
    super(message, { cause });
    this.name = 'ClaudeUnavailableError';
  }
}

export interface ClaudeCallLog {
  fn: string;
  model: string;
  ttft_ms: number | null;
  total_ms: number;
  input_tokens: number;
  output_tokens: number;
  cache_read_tokens: number;
  stop_reason: string | null;
}

export interface StructuredCallOptions<T> {
  /** Calling function name, for logs (e.g. 'generate-plan'). */
  fn: string;
  model: typeof PLAN_MODEL | typeof COACH_MODEL;
  system: Anthropic.TextBlockParam[];
  messages: Anthropic.MessageParam[];
  schema: z.ZodType<T>;
  effort: Effort;
  maxTokens: number;
  timeoutMs: number;
  /** Enable `fallbacks: "default"` (Sonnet 5.5 plan generation). */
  refusalFallback?: boolean;
  /** Receives text deltas as they stream (coach UI). */
  onText?: (delta: string) => void;
}

export interface StructuredCallResult<T> {
  output: T;
  log: ClaudeCallLog;
}

/**
 * Streams one structured-output request and returns the schema-validated result.
 * Throws ClaudeUnavailableError on refusal, truncation, API errors, timeout or invalid output.
 */
export async function callStructured<T>(opts: StructuredCallOptions<T>): Promise<StructuredCallResult<T>> {
  const client = getAnthropicClient();
  const started = performance.now();
  let firstTokenAt: number | null = null;

  const params = {
    model: opts.model,
    max_tokens: opts.maxTokens,
    system: opts.system,
    messages: opts.messages,
    output_config: { effort: opts.effort, format: zodOutputFormat(opts.schema) },
    ...(opts.refusalFallback ? { betas: [FALLBACK_BETA], fallbacks: 'default' as const } : {}),
  };

  let message: Anthropic.Message;
  try {
    // deno-lint-ignore no-explicit-any -- beta params (fallbacks) are not on the stable type
    const stream = (client.beta.messages.stream as any)(params, { timeout: opts.timeoutMs });
    stream.on('text', (delta: string) => {
      if (firstTokenAt === null) firstTokenAt = performance.now();
      opts.onText?.(delta);
    });
    message = await stream.finalMessage();
  } catch (err) {
    logCall(opts, started, firstTokenAt, null);
    if (err instanceof Anthropic.APIConnectionTimeoutError) {
      throw new ClaudeUnavailableError('timeout', `Claude timed out after ${opts.timeoutMs} ms`, err);
    }
    if (err instanceof Anthropic.APIError) {
      throw new ClaudeUnavailableError('api_error', `Claude API error ${err.status}: ${err.message}`, err);
    }
    throw new ClaudeUnavailableError('api_error', `Claude request failed: ${String(err)}`, err);
  }

  const log = logCall(opts, started, firstTokenAt, message);

  if (message.stop_reason === 'refusal') {
    throw new ClaudeUnavailableError('refusal', 'Claude declined the request');
  }
  if (message.stop_reason === 'max_tokens') {
    throw new ClaudeUnavailableError('max_tokens', 'Claude output was truncated at max_tokens');
  }

  const text = message.content
    .filter((b): b is Anthropic.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('');

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    throw new ClaudeUnavailableError('invalid_output', 'Claude output was not valid JSON', err);
  }
  const result = opts.schema.safeParse(parsed);
  if (!result.success) {
    throw new ClaudeUnavailableError('invalid_output', `Claude output failed schema: ${result.error.message}`);
  }
  return { output: result.data, log };
}

function logCall<T>(
  opts: StructuredCallOptions<T>,
  started: number,
  firstTokenAt: number | null,
  message: Anthropic.Message | null,
): ClaudeCallLog {
  const log: ClaudeCallLog = {
    fn: opts.fn,
    model: message?.model ?? opts.model,
    ttft_ms: firstTokenAt === null ? null : Math.round(firstTokenAt - started),
    total_ms: Math.round(performance.now() - started),
    input_tokens: message?.usage.input_tokens ?? 0,
    output_tokens: message?.usage.output_tokens ?? 0,
    cache_read_tokens: message?.usage.cache_read_input_tokens ?? 0,
    stop_reason: message?.stop_reason ?? null,
  };
  console.log(JSON.stringify({ event: 'claude_call', ...log }));
  return log;
}
