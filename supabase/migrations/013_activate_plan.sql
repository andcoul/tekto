-- 013 — switch a user's active plan in one transaction (T137; FR-046, FR-003b).
-- generate-plan inserts a new plan as 'archived', saves its sessions, then calls this: the
-- previous active plan is archived and the new one activated together, so a failed save
-- never leaves the user without an active plan. Service role only (SECURITY INVOKER; the
-- function is called by the Edge Function with the service-role key).

CREATE OR REPLACE FUNCTION public.activate_plan(p_plan_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  SELECT user_id INTO v_user_id FROM public.plans WHERE id = p_plan_id FOR UPDATE;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'plan % not found', p_plan_id;
  END IF;

  UPDATE public.plans SET status = 'archived', updated_at = now()
   WHERE user_id = v_user_id AND status = 'active' AND id <> p_plan_id;

  UPDATE public.plans SET status = 'active', updated_at = now()
   WHERE id = p_plan_id;
END;
$$;

REVOKE ALL ON FUNCTION public.activate_plan(uuid) FROM PUBLIC, anon, authenticated;
