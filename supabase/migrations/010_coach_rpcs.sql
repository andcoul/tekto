-- 010 — coach-message helpers (T073; contracts/ai-services.md §2, backend-api.md §3).
-- Called only by the coach-message Edge Function with the service role.

-- Adds one answered question for the ISO week and returns the new count, in one statement so
-- two parallel requests cannot both read the old value (the old handler counted twice).
CREATE OR REPLACE FUNCTION public.increment_coach_quota(p_user_id uuid, p_iso_week text)
RETURNS int
LANGUAGE sql
AS $$
  INSERT INTO public.coach_quota_usage AS q (user_id, iso_week, questions_used, updated_at)
  VALUES (p_user_id, p_iso_week, 1, now())
  ON CONFLICT (user_id, iso_week)
  DO UPDATE SET questions_used = q.questions_used + 1, updated_at = now()
  RETURNING q.questions_used;
$$;

-- Closest unexpired cached reply for this language and prompt version, if it is similar
-- enough (cosine similarity = 1 - cosine distance). NULL when nothing qualifies.
CREATE OR REPLACE FUNCTION public.match_coach_cache(
  p_embedding vector(384),
  p_language app_language,
  p_prompt_version text,
  p_min_similarity float
)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT c.response_content
  FROM public.coach_response_cache c
  WHERE c.language = p_language
    AND c.prompt_version = p_prompt_version
    AND c.expires_at > now()
    AND 1 - (c.embedding <=> p_embedding) >= p_min_similarity
  ORDER BY c.embedding <=> p_embedding
  LIMIT 1;
$$;

-- Service role only: clients must never read the shared cache or move a quota counter.
REVOKE ALL ON FUNCTION public.increment_coach_quota(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.match_coach_cache(vector, app_language, text, float) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_coach_quota(uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.match_coach_cache(vector, app_language, text, float) TO service_role;
