// T088 — health probe logic (SC-013; contracts/backend-api.md §9). No user data.
// The DB is checked on every request; Anthropic reachability is cached for 5 minutes so the
// uptime monitor (one call a minute) costs at most one Models API call per 5 minutes.

export const AI_PROBE_TTL_MS = 5 * 60_000;

export interface ProbeDeps {
  now(): number;
  checkDb(): Promise<void>;
  checkAi(): Promise<void>;
}

export interface HealthResponse {
  status: number;
  body: { status: 'ok' | 'down' | 'degraded'; db: 'ok' | 'down'; ai: 'ok' | 'degraded'; checked_at: string };
}

export class HealthProbe {
  constructor(private readonly deps: ProbeDeps) {}

  private ai: { ok: boolean; at: number } | null = null;

  async check(): Promise<HealthResponse> {
    const now = this.deps.now();
    const [dbOk, aiOk] = await Promise.all([
      this.deps.checkDb().then(() => true, () => false),
      this.aiStatus(now),
    ]);
    const status = !dbOk ? 'down' : !aiOk ? 'degraded' : 'ok';
    return {
      status: status === 'ok' ? 200 : 503,
      body: { status, db: dbOk ? 'ok' : 'down', ai: aiOk ? 'ok' : 'degraded', checked_at: new Date(now).toISOString() },
    };
  }

  private async aiStatus(now: number): Promise<boolean> {
    if (this.ai && now - this.ai.at < AI_PROBE_TTL_MS) return this.ai.ok;
    const ok = await this.deps.checkAi().then(() => true, () => false);
    this.ai = { ok, at: now };
    return ok;
  }
}
