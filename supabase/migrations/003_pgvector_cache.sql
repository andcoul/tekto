-- Migration 003: pgvector semantic cache for AI coach responses
-- Reduces LLM calls by ~40% for common questions.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE public.coach_response_cache (
  id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  question_hash   text UNIQUE NOT NULL,          -- SHA-256 of normalized question text
  embedding       vector(1536) NOT NULL,          -- text-embedding-ada-002 or equivalent
  response_content text NOT NULL,
  hit_count       int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL DEFAULT now() + INTERVAL '30 days'
);

-- IVFFlat index for approximate nearest-neighbor search
-- lists=100 is appropriate for a cache table expected to hold < 100k entries
CREATE INDEX coach_cache_embedding_idx
  ON public.coach_response_cache
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- Auto-delete expired cache entries (called by a Supabase pg_cron job)
CREATE OR REPLACE FUNCTION public.purge_expired_cache_entries()
RETURNS void
LANGUAGE sql
AS $$
  DELETE FROM public.coach_response_cache WHERE expires_at < now();
$$;

-- No RLS on cache — accessed only by service role in Edge Functions
