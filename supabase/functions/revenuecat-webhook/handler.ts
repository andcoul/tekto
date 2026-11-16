// T109 — RevenueCat webhook rules (contracts/backend-api.md §6). Pure: storage is injected.
//
// RevenueCat reports a trial start as INITIAL_PURCHASE with period_type = TRIAL and a trial
// conversion as RENEWAL with is_trial_conversion = true. TRIAL_STARTED / TRIAL_CONVERTED from
// the original contract are accepted as aliases. Every event computes the next row from the
// current one, so replaying an event gives the same row (idempotent).

export interface SubscriptionRow {
  user_id: string;
  tier: 'free' | 'pro';
  is_trial: boolean;
  trial_ends_at: string | null;
  current_period_ends_at: string | null;
  cancelled_at: string | null;
  revenuecat_customer_id: string | null;
  /** First trial start, kept forever (Gate 2 trial start rate, SC-006; migration 007). */
  trial_started_at: string | null;
  /** First trial conversion to paid, kept forever (trial-to-paid, SC-007). */
  trial_converted_at: string | null;
}

export interface WebhookDeps {
  load(userId: string): Promise<SubscriptionRow | null>;
  save(row: SubscriptionRow): Promise<void>;
}

export interface WebhookRequest {
  authorization: string;
  body: unknown;
  /** REVENUECAT_WEBHOOK_SECRET; empty means not configured → every request is rejected. */
  secret: string;
}

export interface WebhookResult {
  status: number;
  body: Record<string, unknown>;
}

interface RcEvent {
  type: string;
  app_user_id: string;
  original_app_user_id?: string;
  period_type?: string;
  is_trial_conversion?: boolean;
  expiration_at_ms?: number | null;
  event_timestamp_ms?: number;
}

const iso = (ms: number | null | undefined) => (ms == null ? null : new Date(ms).toISOString());

export async function handleWebhook(req: WebhookRequest, deps: WebhookDeps): Promise<WebhookResult> {
  if (!req.secret || req.authorization !== `Bearer ${req.secret}`) {
    return { status: 401, body: { error: 'Unauthorized', code: 'UNAUTHORIZED' } };
  }
  // deno-lint-ignore no-explicit-any -- untrusted JSON
  const event = (req.body as any)?.event as RcEvent | undefined;
  if (!event?.type || !event.app_user_id) {
    return { status: 400, body: { error: 'Missing event.type or event.app_user_id', code: 'INVALID_REQUEST' } };
  }

  const current = await deps.load(event.app_user_id);
  const next = nextRow(event, current);
  if (next === 'billing_issue') {
    console.warn(JSON.stringify({ event: 'revenuecat_billing_issue', user_id: event.app_user_id }));
  } else if (next === null) {
    console.log(JSON.stringify({ event: 'revenuecat_event_ignored', type: event.type, has_row: current !== null }));
  } else {
    await deps.save(next);
  }
  return { status: 200, body: { received: true } };
}

/** The row after [e], 'billing_issue' for log-only events, or null when nothing changes. */
function nextRow(e: RcEvent, current: SubscriptionRow | null): SubscriptionRow | 'billing_issue' | null {
  const periodEnd = iso(e.expiration_at_ms);
  const base: SubscriptionRow = current ?? {
    user_id: e.app_user_id, tier: 'free', is_trial: false, trial_ends_at: null,
    current_period_ends_at: null, cancelled_at: null, revenuecat_customer_id: null,
    trial_started_at: null, trial_converted_at: null,
  };
  const at = iso(e.event_timestamp_ms) ?? new Date().toISOString();
  const customer = e.original_app_user_id ?? base.revenuecat_customer_id;
  const isTrial = e.type === 'TRIAL_STARTED' || (e.type === 'INITIAL_PURCHASE' && e.period_type === 'TRIAL');
  const isConversion = e.type === 'TRIAL_CONVERTED' || (e.type === 'RENEWAL' && e.is_trial_conversion === true);

  switch (e.type) {
    case 'INITIAL_PURCHASE':
    case 'TRIAL_STARTED':
      return {
        ...base, tier: 'pro', is_trial: isTrial, trial_ends_at: isTrial ? periodEnd : null,
        current_period_ends_at: periodEnd, cancelled_at: null, revenuecat_customer_id: customer,
        trial_started_at: isTrial ? (base.trial_started_at ?? at) : base.trial_started_at,
      };
    case 'RENEWAL':
    case 'TRIAL_CONVERTED':
      if (!current) return null; // nothing to renew; INITIAL_PURCHASE creates the row
      return {
        ...base, tier: 'pro', current_period_ends_at: periodEnd, cancelled_at: null,
        ...(isConversion ? { is_trial: false, trial_ends_at: null, trial_converted_at: base.trial_converted_at ?? at } : {}),
        revenuecat_customer_id: customer,
      };
    case 'CANCELLATION':
      if (!current) return null;
      // Pro stays until EXPIRATION (FR-031 cancel anytime; access until the period ends).
      return { ...base, cancelled_at: at };
    case 'UNCANCELLATION':
      if (!current) return null;
      return { ...base, cancelled_at: null };
    case 'EXPIRATION':
      if (!current) return null;
      return { ...base, tier: 'free', is_trial: false, trial_ends_at: null, current_period_ends_at: null, cancelled_at: null };
    case 'BILLING_ISSUE':
      return 'billing_issue'; // grace period: no downgrade
    default:
      return null;
  }
}
