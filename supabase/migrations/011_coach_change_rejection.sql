-- 011 — record a rejected coach plan change (T074; contracts/backend-api.md §3:
-- "`confirmed: false` records the rejection"). A change is pending while neither
-- plan_change_applied nor plan_change_rejected_at is set; it can never be both.

ALTER TABLE public.coach_messages
  ADD COLUMN plan_change_rejected_at timestamptz;

ALTER TABLE public.coach_messages
  ADD CONSTRAINT plan_change_applied_or_rejected
    CHECK (NOT (plan_change_applied AND plan_change_rejected_at IS NOT NULL)),
  ADD CONSTRAINT plan_change_rejected_requires_proposed
    CHECK (plan_change_rejected_at IS NULL OR plan_change_proposed IS NOT NULL);
