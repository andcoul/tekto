-- 016 — friends, feed reactions, weekly score, focus muscles and support chat (2026-11-21;
-- spec FR-049, FR-050, FR-052, FR-054; data-model "Social, recovery, focus and support").

-- ── users: public identity, sharing and focus ─────────────────────────────────────────────
ALTER TABLE public.users
  ADD COLUMN display_name   text CHECK (char_length(display_name) BETWEEN 1 AND 40),
  ADD COLUMN username       text UNIQUE CHECK (username ~ '^[a-z0-9_.]{3,20}$'),
  ADD COLUMN invite_code    text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(6), 'hex'),
  -- Off until the user turns it on (Constitution II: workout logs are health data).
  ADD COLUMN share_workouts bool NOT NULL DEFAULT false,
  ADD COLUMN focus_muscles  text[] NOT NULL DEFAULT '{}' CHECK (
    cardinality(focus_muscles) <= 2 AND focus_muscles <@ ARRAY['chest', 'shoulders', 'triceps', 'back', 'biceps',
      'traps', 'forearms', 'quads', 'hamstrings', 'glutes', 'abductors', 'adductors', 'calves', 'abs', 'lower_back']
  );

ALTER TABLE public.workout_logs ADD COLUMN hidden_from_feed bool NOT NULL DEFAULT false;

-- ── friendships ───────────────────────────────────────────────────────────────────────────
CREATE TYPE friendship_status AS ENUM ('pending', 'accepted', 'blocked');
CREATE TABLE public.friendships (
  id            uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id  uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  addressee_id  uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status        friendship_status NOT NULL DEFAULT 'pending',
  -- who blocked, when status = blocked
  blocked_by    uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (requester_id <> addressee_id)
);
CREATE UNIQUE INDEX friendships_pair ON public.friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
CREATE POLICY friendships_read ON public.friendships FOR SELECT TO authenticated
  USING (auth.uid() IN (requester_id, addressee_id));
CREATE POLICY friendships_request ON public.friendships FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = requester_id AND status = 'pending');
-- The addressee accepts; either side may block (and only the blocker may change it back).
CREATE POLICY friendships_update ON public.friendships FOR UPDATE TO authenticated
  USING (auth.uid() IN (requester_id, addressee_id))
  WITH CHECK (
    (status = 'accepted' AND auth.uid() = addressee_id)
    OR (status = 'blocked' AND blocked_by = auth.uid())
  );
CREATE POLICY friendships_delete ON public.friendships FOR DELETE TO authenticated
  USING (auth.uid() IN (requester_id, addressee_id) AND (status <> 'blocked' OR blocked_by = auth.uid()));

CREATE FUNCTION public.are_friends(a uuid, b uuid) RETURNS bool
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM friendships
     WHERE status = 'accepted'
       AND LEAST(requester_id, addressee_id) = LEAST(a, b)
       AND GREATEST(requester_id, addressee_id) = GREATEST(a, b)
  );
$$;

-- Friend requests by username or invite link.
CREATE FUNCTION public.add_friend_by_username(p_username text) RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE target uuid; fid uuid;
BEGIN
  SELECT id INTO target FROM users WHERE username = lower(p_username);
  IF target IS NULL OR target = auth.uid() THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  INSERT INTO friendships (requester_id, addressee_id) VALUES (auth.uid(), target)
    ON CONFLICT DO NOTHING RETURNING id INTO fid;
  RETURN fid;
END $$;

-- Opening someone's invite link makes you friends at once: sharing the link is the consent.
CREATE FUNCTION public.accept_invite(p_code text) RETURNS uuid
  LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE target uuid; fid uuid;
BEGIN
  SELECT id INTO target FROM users WHERE invite_code = p_code;
  IF target IS NULL OR target = auth.uid() THEN RAISE EXCEPTION 'INVITE_NOT_FOUND'; END IF;
  SELECT id INTO fid FROM friendships
   WHERE LEAST(requester_id, addressee_id) = LEAST(target, auth.uid())
     AND GREATEST(requester_id, addressee_id) = GREATEST(target, auth.uid());
  IF fid IS NULL THEN
    INSERT INTO friendships (requester_id, addressee_id, status) VALUES (target, auth.uid(), 'accepted') RETURNING id INTO fid;
  ELSE
    UPDATE friendships SET status = 'accepted' WHERE id = fid AND status = 'pending';
  END IF;
  RETURN fid;
END $$;

-- Incoming friend requests with the requester's public name (users rows are private under RLS).
CREATE FUNCTION public.friend_requests()
  RETURNS TABLE (friendship_id uuid, user_id uuid, display_name text, username text, created_at timestamptz)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT f.id, u.id, u.display_name, u.username, f.created_at
    FROM friendships f JOIN users u ON u.id = f.requester_id
   WHERE f.addressee_id = auth.uid() AND f.status = 'pending'
   ORDER BY f.created_at DESC;
$$;

-- ── reactions ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE public.workout_reactions (
  workout_log_id uuid NOT NULL REFERENCES public.workout_logs(id) ON DELETE CASCADE,
  user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  emoji          text NOT NULL CHECK (emoji IN ('💪', '🔥', '👏')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workout_log_id, user_id)
);
ALTER TABLE public.workout_reactions ENABLE ROW LEVEL SECURITY;
-- Workout rows are private to their owner (RLS), so visibility is decided by a definer function.
CREATE FUNCTION public.feed_visible(p_log uuid) RETURNS bool
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM workout_logs w JOIN users u ON u.id = w.user_id
     WHERE w.id = p_log AND w.finished_at IS NOT NULL
       AND (w.user_id = auth.uid() OR (are_friends(w.user_id, auth.uid()) AND u.share_workouts AND NOT w.hidden_from_feed))
  );
$$;
CREATE POLICY reactions_read ON public.workout_reactions FOR SELECT TO authenticated USING (feed_visible(workout_log_id));
CREATE POLICY reactions_write ON public.workout_reactions FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() AND feed_visible(workout_log_id));

-- ── weekly training score (FR-050) ────────────────────────────────────────────────────────
-- 20 per finished session (at most 7), 1 per logged set, 10 per record (one per exercise per
-- workout, however many record sets); weeks start on Monday
-- in the user's time zone. Same formula as mobile/lib/features/social/domain/weekly_score.dart.
CREATE FUNCTION public.weekly_score(p_user uuid, p_week_start date) RETURNS int
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH tz AS (SELECT coalesce(timezone, 'UTC') AS z FROM users WHERE id = p_user),
  logs AS (
    SELECT w.id FROM workout_logs w, tz
     WHERE w.user_id = p_user AND w.finished_at IS NOT NULL
       AND (w.finished_at AT TIME ZONE tz.z)::date >= p_week_start
       AND (w.finished_at AT TIME ZONE tz.z)::date < p_week_start + 7
  )
  SELECT (LEAST((SELECT count(*) FROM logs), 7) * 20
          + (SELECT count(*) FROM set_logs s WHERE s.workout_log_id IN (SELECT id FROM logs))
          + (SELECT count(DISTINCT (s.workout_log_id, pe.exercise_slug)) FROM set_logs s
               JOIN plan_exercises pe ON pe.id = s.plan_exercise_id
              WHERE s.workout_log_id IN (SELECT id FROM logs) AND s.is_pr) * 10)::int;
$$;

CREATE FUNCTION public.week_start_for(p_user uuid, p_at timestamptz DEFAULT now()) RETURNS date
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT date_trunc('week', (p_at AT TIME ZONE coalesce((SELECT timezone FROM users WHERE id = p_user), 'UTC')))::date;
$$;

-- The caller and accepted friends: this week, last week, last trained (FR-050).
CREATE FUNCTION public.friend_leaderboard()
  RETURNS TABLE (user_id uuid, display_name text, username text, score int, last_week int, last_trained_at timestamptz)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH people AS (
    SELECT auth.uid() AS id
    UNION SELECT CASE WHEN requester_id = auth.uid() THEN addressee_id ELSE requester_id END
      FROM friendships WHERE status = 'accepted' AND auth.uid() IN (requester_id, addressee_id)
  )
  SELECT u.id, u.display_name, u.username,
         weekly_score(u.id, week_start_for(u.id)),
         weekly_score(u.id, week_start_for(u.id) - 7),
         (SELECT max(finished_at) FROM workout_logs w WHERE w.user_id = u.id)
    FROM people p JOIN users u ON u.id = p.id
   ORDER BY 4 DESC, 2;
$$;

-- Weekly scores for the comparison chart: the caller and friends only.
CREATE FUNCTION public.weekly_scores(p_users uuid[], p_weeks int DEFAULT 8)
  RETURNS TABLE (user_id uuid, week_start date, score int)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u, week_start_for(u) - 7 * g, weekly_score(u, week_start_for(u) - 7 * g)
    FROM unnest(p_users) AS u, generate_series(0, LEAST(p_weeks, 26) - 1) AS g
   WHERE u = auth.uid() OR are_friends(u, auth.uid())
   ORDER BY 1, 2;
$$;

-- Friends' shared workouts, newest first (FR-049): summary, muscles and reactions only.
CREATE FUNCTION public.friend_feed(p_before timestamptz DEFAULT now(), p_limit int DEFAULT 20)
  RETURNS TABLE (workout_log_id uuid, user_id uuid, display_name text, session_name_en text, session_name_fr text,
                 finished_at timestamptz, duration_min int, volume_kg numeric, set_count int, records jsonb,
                 muscles jsonb, reactions jsonb, my_reaction text)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT w.id, w.user_id, u.display_name, s.name_en, s.name_fr, w.finished_at,
         GREATEST(1, round(extract(epoch FROM w.finished_at - w.started_at) / 60))::int,
         w.total_volume_kg,
         (SELECT count(*)::int FROM set_logs sl WHERE sl.workout_log_id = w.id),
         coalesce((SELECT jsonb_agg(jsonb_build_object('exercise_slug', b.exercise_slug, 'weight_kg', b.weight_kg, 'reps', b.reps))
                     FROM (SELECT DISTINCT ON (pe.exercise_slug) pe.exercise_slug, sl.weight_kg, sl.reps
                             FROM set_logs sl JOIN plan_exercises pe ON pe.id = sl.plan_exercise_id
                            WHERE sl.workout_log_id = w.id AND sl.is_pr
                            ORDER BY pe.exercise_slug, sl.weight_kg * (1 + sl.reps / 30.0) DESC) b), '[]'),
         coalesce((SELECT jsonb_object_agg(m, n) FROM (
                     SELECT m, count(*) AS n FROM set_logs sl
                       JOIN plan_exercises pe ON pe.id = sl.plan_exercise_id
                       JOIN exercises e ON e.slug = pe.exercise_slug, unnest(e.muscle_primary) AS m
                      WHERE sl.workout_log_id = w.id GROUP BY m) x), '{}'),
         coalesce((SELECT jsonb_object_agg(emoji, n) FROM (
                     SELECT emoji, count(*) AS n FROM workout_reactions r WHERE r.workout_log_id = w.id GROUP BY emoji) y), '{}'),
         (SELECT emoji FROM workout_reactions r WHERE r.workout_log_id = w.id AND r.user_id = auth.uid())
    FROM workout_logs w
    JOIN users u ON u.id = w.user_id
    JOIN sessions s ON s.id = w.session_id
   WHERE w.finished_at IS NOT NULL AND w.finished_at < p_before
     AND (w.user_id = auth.uid() OR (are_friends(w.user_id, auth.uid()) AND u.share_workouts AND NOT w.hidden_from_feed))
   ORDER BY w.finished_at DESC
   LIMIT LEAST(p_limit, 50);
$$;

-- ── support chat (FR-054) ─────────────────────────────────────────────────────────────────
CREATE TYPE support_status AS ENUM ('open', 'waiting_agent', 'closed');
CREATE TYPE support_sender AS ENUM ('user', 'ai', 'agent');
CREATE TABLE public.support_threads (
  id         uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status     support_status NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX support_one_open_thread ON public.support_threads (user_id) WHERE status <> 'closed';
CREATE TABLE public.support_messages (
  id         uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id  uuid NOT NULL REFERENCES public.support_threads(id) ON DELETE CASCADE,
  sender     support_sender NOT NULL,
  body       text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX support_messages_thread ON public.support_messages (thread_id, created_at);
ALTER TABLE public.support_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;
-- Users read their own threads; every write goes through support-message or staff (service role).
CREATE POLICY support_threads_read ON public.support_threads FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY support_messages_read ON public.support_messages FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM support_threads t WHERE t.id = thread_id AND t.user_id = auth.uid()));

ALTER PUBLICATION supabase_realtime ADD TABLE public.support_messages;

GRANT EXECUTE ON FUNCTION public.are_friends(uuid, uuid), public.feed_visible(uuid), public.add_friend_by_username(text), public.accept_invite(text), public.friend_requests(),
  public.friend_leaderboard(), public.weekly_scores(uuid[], int), public.friend_feed(timestamptz, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.weekly_score(uuid, date) FROM PUBLIC, anon, authenticated;
