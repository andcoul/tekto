-- 014 — equipment vocabulary and clip length (T150; spec FR-001, FR-013, FR-014, clarified 2026-11-20).
--
-- 1. Exercise clips may be 4–15 s (each shows at least one complete rep; the library records the
--    real length). 005 allowed 5–15 s.
-- 2. Equipment uses one vocabulary everywhere: barbell, dumbbell (kettlebells count as dumbbells),
--    cable, machine, bands, pull_up_bar, dip_station, bench, bodyweight.
-- 3. Existing profiles are remapped so their current plans stay valid: before this change `cable`
--    also meant machines, and benches, bars and dip stations were never asked about.

-- 1. Clip length ------------------------------------------------------------------------------
ALTER TABLE public.exercises DROP CONSTRAINT IF EXISTS exercises_video_duration_sec_check;
ALTER TABLE public.exercises
  ADD CONSTRAINT exercises_video_duration_sec_check CHECK (video_duration_sec BETWEEN 4 AND 15);

-- 3. Remap existing profiles (before the CHECKs below, which the old values already satisfy) ----
UPDATE public.users u
   SET equipment = (
         SELECT array_agg(DISTINCT item ORDER BY item)
           FROM unnest(
                  u.equipment
                  || ARRAY['bodyweight']
                  || CASE WHEN 'cable' = ANY (u.equipment) THEN ARRAY['machine'] ELSE ARRAY[]::text[] END
                  || CASE WHEN u.equipment && ARRAY['barbell', 'dumbbell'] THEN ARRAY['bench'] ELSE ARRAY[]::text[] END
                  || CASE WHEN u.equipment @> ARRAY['barbell', 'cable'] THEN ARRAY['pull_up_bar', 'dip_station']
                          ELSE ARRAY[]::text[] END
                ) AS item
       );

-- 2. Vocabulary -------------------------------------------------------------------------------
ALTER TABLE public.exercises ADD CONSTRAINT exercises_equipment_vocabulary CHECK (
  equipment <@ ARRAY['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench', 'bodyweight']
);
ALTER TABLE public.users ADD CONSTRAINT users_equipment_vocabulary CHECK (
  equipment <@ ARRAY['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench', 'bodyweight']
);
ALTER TABLE public.plan_templates ADD CONSTRAINT plan_templates_equipment_vocabulary CHECK (
  equipment_required <@ ARRAY['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench', 'bodyweight']
);
