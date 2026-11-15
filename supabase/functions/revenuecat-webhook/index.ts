import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { handleWebhook, type SubscriptionRow } from './handler.ts';

// POST /revenuecat-webhook — contracts/backend-api.md §6. Rules live in handler.ts (T109).
serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON body', 400, 'INVALID_REQUEST');
  }

  const db = getDb();
  try {
    const result = await handleWebhook(
      { authorization: req.headers.get('Authorization') ?? '', body, secret: Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ?? '' },
      {
        load: async (userId) => {
          const { data, error } = await db
            .from('subscriptions')
            .select('user_id, tier, is_trial, trial_ends_at, current_period_ends_at, cancelled_at, revenuecat_customer_id')
            .eq('user_id', userId)
            .maybeSingle();
          if (error) throw new Error(error.message);
          return data as SubscriptionRow | null;
        },
        save: async (row) => {
          const { error } = await db
            .from('subscriptions')
            .upsert({ ...row, updated_at: new Date().toISOString() }, { onConflict: 'user_id' });
          if (error) throw new Error(error.message);
        },
      },
    );
    return jsonResponse(result.body, result.status);
  } catch (err) {
    // 500 makes RevenueCat retry the event later.
    console.error(JSON.stringify({ event: 'revenuecat_webhook_error', error: String(err) }));
    return errorResponse('Internal server error', 500, 'WEBHOOK_FAILED');
  }
});
