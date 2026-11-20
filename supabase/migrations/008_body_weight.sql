-- 008 — body weight log (FR-041, data-model.md entity 17, T118).
-- Health data: covered by RLS (owner only), the export and the account-deletion cascade.
-- 007 is reserved for the metrics views (T115).

CREATE TABLE public.body_weight_entries (
  id           uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  weight_kg    numeric(5,2) NOT NULL CHECK (weight_kg > 0),
  measured_on  date NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, measured_on) -- one entry per day; a new entry for the same day replaces it
);

CREATE INDEX body_weight_entries_user_date ON public.body_weight_entries (user_id, measured_on DESC);

ALTER TABLE public.body_weight_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "body_weight_entries_own" ON public.body_weight_entries
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
