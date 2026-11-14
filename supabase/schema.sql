-- ============================================================================
-- RUSHOUT - SUPABASE POSTGRESQL SCHEMA & RLS POLICIES
-- Run this script in the Supabase SQL Editor (https://app.supabase.com)
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
    player_name VARCHAR(50) NOT NULL CHECK (char_length(trim(player_name)) >= 1),
    challenge_date DATE NOT NULL,
    moves_count INTEGER NOT NULL CHECK (moves_count > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast leaderboard queries by date and moves_count ascending
CREATE INDEX IF NOT EXISTS idx_daily_challenges_date
    ON public.daily_challenges (challenge_date);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_date_moves
    ON public.leaderboard_scores (challenge_date, moves_count ASC, created_at ASC);

-- Compatibility view `leaderboard` (maps directly to `leaderboard_scores` so both REST endpoints work)
CREATE OR REPLACE VIEW public.leaderboard AS
SELECT id, player_name, challenge_date, moves_count, created_at
FROM public.leaderboard_scores;

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_scores ENABLE ROW LEVEL SECURITY;

-- Allow anyone (anon / authenticated) to read daily challenges
DROP POLICY IF EXISTS "Allow public read access on daily_challenges" ON public.daily_challenges;
CREATE POLICY "Allow public read access on daily_challenges"
    ON public.daily_challenges
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Allow anyone (anon / authenticated) to read leaderboard scores
DROP POLICY IF EXISTS "Allow public read access on leaderboard_scores" ON public.leaderboard_scores;
CREATE POLICY "Allow public read access on leaderboard_scores"
    ON public.leaderboard_scores
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Allow anyone (anon / authenticated) to submit a score to leaderboard_scores
DROP POLICY IF EXISTS "Allow public insert access on leaderboard_scores" ON public.leaderboard_scores;
CREATE POLICY "Allow public insert access on leaderboard_scores"
    ON public.leaderboard_scores
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (
        char_length(trim(player_name)) BETWEEN 1 AND 50
        AND moves_count > 0
        AND moves_count <= 999
    );

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
VALUES
    ('SpeedRacer_VN', CURRENT_DATE, 12),
    ('PuzzleMaster',  CURRENT_DATE, 14),
    ('RushHourPro',   CURRENT_DATE, 15);
