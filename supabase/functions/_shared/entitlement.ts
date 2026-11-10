// Server-side Pro check (subscription gate, Constitution V). The `subscriptions` row is
// authoritative; data-model.md entity 13:
//   tier = 'pro' AND (current_period_ends_at > now() OR (is_trial AND trial_ends_at > now()))

export interface SubscriptionRow {
  tier: string;
  is_trial: boolean;
  trial_ends_at: string | null;
  current_period_ends_at: string | null;
}

export function isPro(sub: SubscriptionRow | null | undefined, now: Date = new Date()): boolean {
  if (!sub || sub.tier !== 'pro') return false;
  const after = (iso: string | null) => iso !== null && new Date(iso).getTime() > now.getTime();
  return after(sub.current_period_ends_at) || (sub.is_trial && after(sub.trial_ends_at));
}
