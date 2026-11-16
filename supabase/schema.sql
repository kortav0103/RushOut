-- ============================================================================
-- RUSHOUT - SUPABASE POSTGRESQL SCHEMA, RLS POLICIES & AUTHORITATIVE RPC
-- Run this script in the Supabase SQL Editor (https://app.supabase.com)
-- Prerequisite: Enable "Anonymous Sign-Ins" in Supabase Dashboard:
--   Authentication -> Providers -> Anonymous Sign-Ins -> Enable
-- ============================================================================

-- 1. Table: daily_challenges
CREATE TABLE IF NOT EXISTS public.daily_challenges (
    id BIGSERIAL PRIMARY KEY,
    challenge_date DATE NOT NULL UNIQUE,
    board_string VARCHAR(36) NOT NULL CHECK (char_length(board_string) = 36),
    optimal_moves INTEGER NOT NULL CHECK (optimal_moves > 0),
    difficulty VARCHAR(16) NOT NULL DEFAULT 'medium',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Table: leaderboard_scores
CREATE TABLE IF NOT EXISTS public.leaderboard_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    player_name VARCHAR(50) NOT NULL CHECK (char_length(trim(player_name)) >= 1),
    challenge_date DATE NOT NULL,
    moves_count INTEGER NOT NULL CHECK (moves_count > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.leaderboard_scores
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Indexes for fast leaderboard queries and 1-score-per-user-per-day enforcement
CREATE INDEX IF NOT EXISTS idx_daily_challenges_date
    ON public.daily_challenges (challenge_date);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_date_moves
    ON public.leaderboard_scores (challenge_date, moves_count ASC, created_at ASC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_leaderboard_scores_user_date
    ON public.leaderboard_scores (user_id, challenge_date)
    WHERE user_id IS NOT NULL;

-- Compatibility view `leaderboard` (read-only projection of `leaderboard_scores`)
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT id, player_name, challenge_date, moves_count, created_at
FROM public.leaderboard_scores;

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS) FOR DAILY & LEADERBOARD
-- ============================================================================

ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_scores ENABLE ROW LEVEL SECURITY;

-- Allow anyone (anon / authenticated) to read current and past daily challenges only
DROP POLICY IF EXISTS "Allow public read access on daily_challenges" ON public.daily_challenges;
CREATE POLICY "Allow public read access on daily_challenges"
    ON public.daily_challenges
    FOR SELECT
    TO anon, authenticated
    USING (challenge_date <= CURRENT_DATE);

-- Allow anyone (anon / authenticated) to read leaderboard scores
DROP POLICY IF EXISTS "Allow public read access on leaderboard_scores" ON public.leaderboard_scores;
CREATE POLICY "Allow public read access on leaderboard_scores"
    ON public.leaderboard_scores
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Block direct REST INSERT/UPDATE/DELETE on leaderboard_scores; submissions MUST go through submit_daily_score RPC
DROP POLICY IF EXISTS "Allow public insert access on leaderboard_scores" ON public.leaderboard_scores;
REVOKE INSERT, UPDATE, DELETE ON public.leaderboard_scores FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.leaderboard FROM anon, authenticated;
GRANT SELECT ON public.leaderboard_scores TO anon, authenticated;
GRANT SELECT ON public.leaderboard TO anon, authenticated;

-- Server-authoritative RPC for submitting a Daily Challenge score
CREATE OR REPLACE FUNCTION public.submit_daily_score(
    p_player_name TEXT,
    p_challenge_date DATE,
    p_moves_count INTEGER
)
RETURNS public.leaderboard_scores
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_clean_name TEXT := trim(COALESCE(p_player_name, ''));
    v_optimal_moves INTEGER;
    v_inserted public.leaderboard_scores;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required to submit a score.'
            USING ERRCODE = '42501';
    END IF;

    IF p_challenge_date IS NULL OR p_challenge_date <> CURRENT_DATE THEN
        RAISE EXCEPTION 'Scores can only be submitted for today''s Daily Challenge.'
            USING ERRCODE = '22023';
    END IF;

    IF char_length(v_clean_name) < 2 OR char_length(v_clean_name) > 24 THEN
        RAISE EXCEPTION 'Nickname must be between 2 and 24 characters.'
            USING ERRCODE = '22023';
    END IF;

    IF v_clean_name !~ '^[a-zA-Z0-9_\-\sÀ-ỹ]+$' THEN
        RAISE EXCEPTION 'Nickname contains invalid characters.'
            USING ERRCODE = '22023';
    END IF;

    SELECT optimal_moves
    INTO v_optimal_moves
    FROM public.daily_challenges
    WHERE challenge_date = p_challenge_date;

    IF v_optimal_moves IS NULL THEN
        RAISE EXCEPTION 'No Daily Challenge found for %.', p_challenge_date
            USING ERRCODE = 'P0002';
    END IF;

    IF p_moves_count IS NULL OR p_moves_count < v_optimal_moves OR p_moves_count > 999 THEN
        RAISE EXCEPTION 'Invalid move count: must be between % and 999.', v_optimal_moves
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.leaderboard_scores
        WHERE user_id = v_uid
          AND challenge_date = p_challenge_date
    ) THEN
        RAISE EXCEPTION 'You have already submitted a score for today''s Daily Challenge.'
            USING ERRCODE = '23505';
    END IF;

    INSERT INTO public.leaderboard_scores (
        user_id,
        player_name,
        challenge_date,
        moves_count
    )
    VALUES (
        v_uid,
        v_clean_name,
        p_challenge_date,
        p_moves_count
    )
    RETURNING * INTO v_inserted;

    RETURN v_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_daily_score(TEXT, DATE, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_daily_score(TEXT, DATE, INTEGER) TO authenticated;

-- ============================================================================
-- 4. SEED DATA (Today + Upcoming Daily Challenges & Sample Leaderboard Scores)
-- ============================================================================

INSERT INTO public.daily_challenges (challenge_date, board_string, optimal_moves, difficulty)
VALUES
    (CURRENT_DATE,     'oBBCoDoooCoDEAAooDEoHGGGooHFIIJJoFKK', 12, 'medium'),
    (CURRENT_DATE + 1, 'oBBooDoooCoDEAACoDEoHGGGooHFIIJJoFKK', 13, 'medium'),
    (CURRENT_DATE + 2, 'oBBooDoooCoDEAACoDEGGGooooHFIIJJHFKK', 14, 'medium'),
    (CURRENT_DATE + 3, 'oBBooooooCoDEAACoDEGGGoDooHFIIJJHFKK', 15, 'medium'),
    (CURRENT_DATE + 4, 'oooCBBoooCoDEAAooDEGGGoDooHFIIJJHFKK', 16, 'medium'),
    (CURRENT_DATE + 5, 'EoooBBELLCoDAAoCoDGGGooDooHFIIJJHFKK', 19, 'hard'),
    (CURRENT_DATE + 6, 'EooCBBELLCoDAAoooDGGGooDooHFIIJJHFKK', 20, 'hard')
ON CONFLICT (challenge_date) DO NOTHING;

INSERT INTO public.leaderboard_scores (player_name, challenge_date, moves_count)
SELECT v.player_name, v.challenge_date, v.moves_count
FROM (
    VALUES
        ('SpeedRacer_VN', CURRENT_DATE, 12),
        ('PuzzleMaster',  CURRENT_DATE, 14),
        ('RushHourPro',   CURRENT_DATE, 15)
) AS v(player_name, challenge_date, moves_count)
WHERE NOT EXISTS (
    SELECT 1
    FROM public.leaderboard_scores s
    WHERE s.challenge_date = v.challenge_date
      AND s.player_name = v.player_name
);

-- ============================================================================
-- 5. AUTHENTICATED PLAYER PROFILE & CLOUD PROGRESS SYNC (ANONYMOUS AUTH)
-- ============================================================================

-- 5.1 Table: device_profiles (scoped strictly to auth.uid())
CREATE TABLE IF NOT EXISTS public.device_profiles (
    user_id UUID PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL DEFAULT '',
    username VARCHAR(24) NOT NULL CHECK (char_length(trim(username)) BETWEEN 2 AND 24),
    tutorial_completed BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5.2 Table: device_level_progress (scoped strictly to auth.uid())
CREATE TABLE IF NOT EXISTS public.device_level_progress (
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES public.device_profiles(user_id) ON DELETE CASCADE,
    device_id TEXT NOT NULL DEFAULT '',
    level_id INTEGER NOT NULL CHECK (level_id >= 1),
    difficulty VARCHAR(16) NOT NULL,
    best_moves INTEGER,
    stars INTEGER NOT NULL DEFAULT 0 CHECK (stars BETWEEN 0 AND 3),
    is_unlocked BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, level_id)
);

-- Safe idempotent migration if upgrading from legacy unauthenticated device_id-only schema
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'device_profiles'
          AND column_name = 'user_id'
    ) THEN
        -- Legacy rows had no authenticated owner and cannot be safely bound to auth.users
        TRUNCATE TABLE public.device_level_progress, public.device_profiles;
        ALTER TABLE public.device_level_progress
            DROP CONSTRAINT IF EXISTS device_level_progress_pkey,
            DROP CONSTRAINT IF EXISTS device_level_progress_device_id_fkey;
        ALTER TABLE public.device_profiles
            DROP CONSTRAINT IF EXISTS device_profiles_pkey;
        ALTER TABLE public.device_profiles
            ADD COLUMN user_id UUID PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE;
        ALTER TABLE public.device_level_progress
            ADD COLUMN user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES public.device_profiles(user_id) ON DELETE CASCADE;
        ALTER TABLE public.device_level_progress
            ADD PRIMARY KEY (user_id, level_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_device_level_progress_user
    ON public.device_level_progress (user_id, level_id);

ALTER TABLE public.device_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_level_progress ENABLE ROW LEVEL SECURITY;

-- Drop any legacy public/anon policies
DROP POLICY IF EXISTS "Allow device profile read" ON public.device_profiles;
DROP POLICY IF EXISTS "Allow device profile insert" ON public.device_profiles;
DROP POLICY IF EXISTS "Allow device profile update" ON public.device_profiles;
DROP POLICY IF EXISTS "Allow device progress read" ON public.device_level_progress;
DROP POLICY IF EXISTS "Allow device progress insert" ON public.device_level_progress;
DROP POLICY IF EXISTS "Allow device progress update" ON public.device_level_progress;
DROP POLICY IF EXISTS "device_profiles_owner_all" ON public.device_profiles;
DROP POLICY IF EXISTS "device_level_progress_owner_all" ON public.device_level_progress;

REVOKE ALL ON public.device_profiles FROM anon;
REVOKE ALL ON public.device_level_progress FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_level_progress TO authenticated;

CREATE POLICY "device_profiles_owner_all"
    ON public.device_profiles
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id
        AND char_length(trim(username)) BETWEEN 2 AND 24
        AND username ~ '^[a-zA-Z0-9_\-\sÀ-ỹ]+$'
    );

CREATE POLICY "device_level_progress_owner_all"
    ON public.device_level_progress
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (
        auth.uid() = user_id
        AND level_id >= 1
        AND stars BETWEEN 0 AND 3
    );
