-- 009 — plan_exercises.rir_target (data-model.md plan_exercises; FR-007, T126).
-- Documented in the data model but never created; the app shows "RIR n (≈ RPE 10−n)" when set.
ALTER TABLE public.plan_exercises
  ADD COLUMN rir_target int CHECK (rir_target BETWEEN 0 AND 5);
