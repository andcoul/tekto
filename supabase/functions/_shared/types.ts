// Shared TypeScript interfaces mirroring the 14 DB entities.
// Keep in sync with supabase/migrations/001_initial_schema.sql

export type TrainingGoal = 'muscle' | 'strength' | 'fat_loss' | 'general_fitness';
export type TrainingLevel = 'beginner' | 'intermediate' | 'advanced';
export type AppLanguage = 'en' | 'fr';
export type UnitPref = 'kg' | 'lb';
export type PlanStatus = 'active' | 'completed' | 'archived';
export type SubscriptionTier = 'free' | 'pro';
export type CoachMessageRole = 'user' | 'assistant' | 'system';

export interface User {
  id: string;
  goal: TrainingGoal;
  level: TrainingLevel;
  days_per_week: number;
  session_length_min: number;
  equipment: string[];
  limitations?: string[];
  language: AppLanguage;
  unit: UnitPref;
  health_sync_enabled: boolean;
  onboarding_completed_at?: string;
  created_at: string;
  updated_at: string;
}

export interface Exercise {
  slug: string;
  name_en: string;
  name_fr: string;
  equipment: string[];
  muscle_primary: string[];
  muscle_secondary: string[];
  cues_en: string[];
  cues_fr: string[];
  common_mistakes_en: string[];
  common_mistakes_fr: string[];
  video_front_url?: string;
  video_side_url?: string;
  variation_easier_slug?: string;
  variation_harder_slug?: string;
  form_check_supported: boolean;
  form_check_lift_key?: string;
  created_at: string;
}

export interface Plan {
  id: string;
  user_id: string;
  name: string;
  status: PlanStatus;
  weeks_total: number;
  current_week: number;
  generated_by: string;
  rationale_en?: string;
  rationale_fr?: string;
  adaptation_log: AdaptationLogEntry[];
  created_at: string;
  updated_at: string;
}

export interface AdaptationLogEntry {
  week: number;
  adapted_at: string;
  changes: AdaptationEvent[];
}

export interface AdaptationEvent {
  plan_exercise_id: string;
  exercise_slug: string;
  field: 'suggested_weight_kg' | 'reps_max';
  old_value: number;
  new_value: number;
  reason_en: string;
  reason_fr: string;
}

export interface Session {
  id: string;
  plan_id: string;
  week_number: number;
  day_of_week: number;
  name_en: string;
  name_fr: string;
  muscle_groups: string[];
  estimated_min?: number;
  created_at: string;
}

export interface PlanExercise {
  id: string;
  session_id: string;
  exercise_slug: string;
  sort_order: number;
  sets: number;
  reps_min: number;
  reps_max: number;
  rpe_target?: number;
  rest_sec: number;
  suggested_weight_kg?: number;
}

export interface WorkoutLog {
  id: string;
  user_id: string;
  session_id: string;
  started_at: string;
  finished_at?: string;
  effort_rating?: number;
  total_volume_kg?: number;
  synced_to_health: boolean;
  created_at: string;
}

export interface SetLog {
  id: string;
  workout_log_id: string;
  plan_exercise_id: string;
  set_number: number;
  weight_kg: number;
  reps: number;
  rpe_actual?: number;
  is_pr: boolean;
  logged_at: string;
}

export interface PersonalRecord {
  id: string;
  user_id: string;
  exercise_slug: string;
  best_weight_kg: number;
  best_reps: number;
  best_e1rm: number;
  achieved_at: string;
}

export interface CoachConversation {
  id: string;
  user_id: string;
  plan_id?: string;
  created_at: string;
  updated_at: string;
}

export interface CoachMessage {
  id: string;
  conversation_id: string;
  role: CoachMessageRole;
  content: string;
  context_screen?: string;
  context_exercise_slug?: string;
  plan_change_proposed?: PlanChangeProposal;
  plan_change_applied: boolean;
  satisfaction_rating?: boolean;
  created_at: string;
}

export interface PlanChangeProposal {
  type: 'swap_exercise';
  plan_exercise_id: string;
  old_exercise_slug: string;
  new_exercise_slug: string;
  reason_en: string;
  reason_fr: string;
}

export interface CoachQuotaUsage {
  user_id: string;
  iso_week: string;
  questions_used: number;
  updated_at: string;
}

export interface FormCheckSession {
  id: string;
  user_id: string;
  exercise_slug: string;
  workout_log_id?: string;
  rep_count: number;
  form_score?: number;
  cues_shown: string[];
  top_tip_en?: string;
  top_tip_fr?: string;
  user_shared: boolean;
  created_at: string;
}

export interface Subscription {
  id: string;
  user_id: string;
  tier: SubscriptionTier;
  is_trial: boolean;
  trial_ends_at?: string;
  current_period_ends_at?: string;
  cancelled_at?: string;
  revenuecat_customer_id?: string;
  created_at: string;
  updated_at: string;
}

export interface ExerciseVideoDownload {
  id: string;
  user_id: string;
  exercise_slug: string;
  plan_id: string;
  local_path?: string;
  file_size_bytes?: number;
  downloaded_at: string;
}

// ── API payloads ───────────────────────────────────────────────────────────

export interface GeneratePlanRequest {
  /** User profile is read from DB; this field allows overriding for reruns */
  force_regenerate?: boolean;
}

export interface GeneratePlanResponse {
  plan: Plan;
  sessions: Session[];
  plan_exercises: PlanExercise[];
}

export interface CoachMessageRequest {
  message: string;
  context_screen?: string;
  context_exercise_slug?: string;
  context_session_id?: string;
}

export interface CoachMessageResponse {
  message: CoachMessage;
  quota_remaining?: number; // null for Pro users
}

export interface SwapExerciseRequest {
  plan_exercise_id: string;
  new_exercise_slug: string;
}

export interface VideoDownloadUrlsRequest {
  plan_id: string;
}

export interface VideoDownloadUrlsResponse {
  downloads: Array<{
    exercise_slug: string;
    signed_url: string;
    expires_at: string;
  }>;
}
