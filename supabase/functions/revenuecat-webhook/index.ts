import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getDb } from '../_shared/db.ts';
import { jsonResponse, errorResponse } from '../_shared/auth.ts';

// ---------------------------------------------------------------------------
// RevenueCat Webhook Handler
// ---------------------------------------------------------------------------
// Validates the REVENUECAT_WEBHOOK_SECRET Bearer token and processes
// subscription lifecycle events, upserting the `subscriptions` table.
//
// Supported event types:
//   INITIAL_PURCHASE    → tier='pro', is_trial=false
//   RENEWAL             → update current_period_ends_at
//   TRIAL_STARTED       → is_trial=true, trial_ends_at set
//   TRIAL_CONVERTED     → is_trial=false, tier='pro'
//   CANCELLATION        → cancelled_at set; keep tier until period ends
//   EXPIRATION          → tier='free', clear period fields
//   BILLING_ISSUE       → log only, no immediate downgrade

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  // ---- Authenticate ----
  const authHeader = req.headers.get('Authorization') ?? '';
  const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (!webhookSecret || authHeader !== `Bearer ${webhookSecret}`) {
    return errorResponse('Unauthorized', 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400);
  }

  const event = body.event as Record<string, unknown> | undefined;
  if (!event) {
    return errorResponse('Missing event object', 400);
  }

  const eventType = event.type as string | undefined;
  const appUserId = event.app_user_id as string | undefined;

  if (!eventType || !appUserId) {
    return errorResponse('Missing event.type or event.app_user_id', 400);
  }

  const db = getDb();

  try {
    await handleEvent(db, eventType, appUserId, event);
  } catch (err) {
    console.error('RevenueCat webhook error:', err);
    return errorResponse('Internal server error', 500);
  }

  return jsonResponse({ received: true });
});

// ---------------------------------------------------------------------------
// Event handler
// ---------------------------------------------------------------------------

async function handleEvent(
  // deno-lint-ignore no-explicit-any
  db: any,
  eventType: string,
  userId: string,
  event: Record<string, unknown>,
): Promise<void> {
  const periodEndsAt = toIso(event.expiration_at_ms as number | undefined);
  const trialEndsAt = toIso(event.trial_end_time_ms as number | undefined);
  const purchasedAt = toIso(event.purchased_at_ms as number | undefined);

  switch (eventType) {
    case 'INITIAL_PURCHASE':
      await upsertSubscription(db, userId, {
        tier: 'pro',
        is_trial: false,
        current_period_ends_at: periodEndsAt,
        trial_ends_at: null,
        cancelled_at: null,
        revenuecat_customer_id: event.id as string,
        updated_at: new Date().toISOString(),
      });
      break;

    case 'RENEWAL':
      await db
        .from('subscriptions')
        .update({
          current_period_ends_at: periodEndsAt,
          cancelled_at: null,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);
      break;

    case 'TRIAL_STARTED':
      await upsertSubscription(db, userId, {
        tier: 'pro',
        is_trial: true,
        trial_ends_at: trialEndsAt,
        current_period_ends_at: periodEndsAt,
        cancelled_at: null,
        revenuecat_customer_id: event.id as string,
        updated_at: new Date().toISOString(),
      });
      break;

    case 'TRIAL_CONVERTED':
      await db
        .from('subscriptions')
        .update({
          is_trial: false,
          tier: 'pro',
          trial_ends_at: null,
          current_period_ends_at: periodEndsAt,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);
      break;

    case 'CANCELLATION':
      await db
        .from('subscriptions')
        .update({
          cancelled_at: purchasedAt ?? new Date().toISOString(),
          updated_at: new Date().toISOString(),
          // Keep tier='pro' until expiration event fires
        })
        .eq('user_id', userId);
      break;

    case 'EXPIRATION':
      await db
        .from('subscriptions')
        .update({
          tier: 'free',
          is_trial: false,
          current_period_ends_at: null,
          trial_ends_at: null,
          cancelled_at: null,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);
      break;

    case 'BILLING_ISSUE':
      // Log only — no immediate downgrade per spec
      console.warn(`Billing issue for user ${userId}:`, event);
      break;

    default:
      console.log(`Unhandled RevenueCat event type: ${eventType}`);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// deno-lint-ignore no-explicit-any
async function upsertSubscription(db: any, userId: string, fields: Record<string, unknown>) {
  await db
    .from('subscriptions')
    .upsert({ user_id: userId, ...fields }, { onConflict: 'user_id' });
}

function toIso(epochMs: number | undefined): string | null {
  if (epochMs == null) return null;
  return new Date(epochMs).toISOString();
}
