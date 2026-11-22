-- 015 — three more equipment items (2026-11-21; spec FR-001, FR-013): `smith_machine`, `trap_bar`
-- (hexagonal bar) and `suspension` (suspension trainer straps). Plate-loaded machines stay `machine`, landmine
-- moves stay `barbell`, kettlebells stay `dumbbell`. Existing profiles keep their equipment: these
-- items were never asked about, so nobody has them until they pick them (or pick "Gym").

ALTER TABLE public.exercises DROP CONSTRAINT exercises_equipment_vocabulary;
ALTER TABLE public.exercises ADD CONSTRAINT exercises_equipment_vocabulary CHECK (
  equipment <@ ARRAY['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench',
                     'smith_machine', 'smith_machine', 'trap_bar', 'suspension', 'bodyweight']
);
ALTER TABLE public.users DROP CONSTRAINT users_equipment_vocabulary;
ALTER TABLE public.users ADD CONSTRAINT users_equipment_vocabulary CHECK (
  equipment <@ ARRAY['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench',
                     'smith_machine', 'smith_machine', 'trap_bar', 'suspension', 'bodyweight']
);
ALTER TABLE public.plan_templates DROP CONSTRAINT plan_templates_equipment_vocabulary;
ALTER TABLE public.plan_templates ADD CONSTRAINT plan_templates_equipment_vocabulary CHECK (
  equipment_required <@ ARRAY['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench',
                              'smith_machine', 'smith_machine', 'trap_bar', 'suspension', 'bodyweight']
);
