-- Migration 004: Personal Records trigger
-- Fires AFTER INSERT on set_logs; upserts personal_records when a new PR is set.

CREATE OR REPLACE FUNCTION public.update_personal_record()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id      uuid;
  v_exercise_slug text;
  v_new_e1rm     numeric(8,2);
  v_existing_e1rm numeric(8,2);
BEGIN
  -- Resolve user_id from the workout log
  SELECT wl.user_id, pe.exercise_slug
    INTO v_user_id, v_exercise_slug
    FROM public.workout_logs wl
    JOIN public.plan_exercises pe ON pe.id = NEW.plan_exercise_id
    WHERE wl.id = NEW.workout_log_id;

  IF v_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- e1RM formula: weight * (1 + reps / 30.0)
  v_new_e1rm := NEW.weight_kg * (1.0 + NEW.reps / 30.0);

  -- Retrieve current best e1RM (NULL if no record yet)
  SELECT best_e1rm INTO v_existing_e1rm
    FROM public.personal_records
    WHERE user_id = v_user_id AND exercise_slug = v_exercise_slug;

  IF v_existing_e1rm IS NULL OR v_new_e1rm > v_existing_e1rm THEN
    -- New PR — upsert the record
    INSERT INTO public.personal_records (
      user_id, exercise_slug, best_weight_kg, best_reps, best_e1rm, achieved_at
    )
    VALUES (
      v_user_id, v_exercise_slug, NEW.weight_kg, NEW.reps, v_new_e1rm, NEW.logged_at
    )
    ON CONFLICT (user_id, exercise_slug)
    DO UPDATE SET
      best_weight_kg = EXCLUDED.best_weight_kg,
      best_reps      = EXCLUDED.best_reps,
      best_e1rm      = EXCLUDED.best_e1rm,
      achieved_at    = EXCLUDED.achieved_at;

    -- Flag the triggering set as a PR
    UPDATE public.set_logs SET is_pr = true WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_personal_record
  AFTER INSERT ON public.set_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_personal_record();
