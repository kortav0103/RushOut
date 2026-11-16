-- ============================================================================
-- RUSHOUT - SUPABASE POSTGRESQL SCHEMA, RLS POLICIES & AUTHORITATIVE RPC
-- Run this script in the Supabase SQL Editor (https://app.supabase.com)
-- Prerequisite: Enable "Anonymous Sign-Ins" in Supabase Dashboard:
--   Authentication -> Providers -> Anonymous Sign-Ins -> Enable
-- ============================================================================

-- 1. Table: daily_puzzle_pool (curated, solver-verified 6x6 puzzle pool)
CREATE TABLE IF NOT EXISTS public.daily_puzzle_pool (
    id BIGSERIAL PRIMARY KEY,
    board_string VARCHAR(36) NOT NULL UNIQUE CHECK (char_length(board_string) = 36),
    optimal_moves INTEGER NOT NULL CHECK (optimal_moves > 0),
    difficulty VARCHAR(16) NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Table: daily_challenges (scheduled daily puzzles, never expires after 7 days)
CREATE TABLE IF NOT EXISTS public.daily_challenges (
    id BIGSERIAL PRIMARY KEY,
    challenge_date DATE NOT NULL UNIQUE,
    board_string VARCHAR(36) NOT NULL CHECK (char_length(board_string) = 36),
    optimal_moves INTEGER NOT NULL CHECK (optimal_moves > 0),
    difficulty VARCHAR(16) NOT NULL DEFAULT 'medium',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Table: leaderboard_scores
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
-- 4. ROW LEVEL SECURITY (RLS) FOR DAILY & LEADERBOARD
-- ============================================================================

ALTER TABLE public.daily_puzzle_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_scores ENABLE ROW LEVEL SECURITY;

-- Puzzle pool is backend-only (no direct client reads so future puzzles stay hidden)
REVOKE ALL ON public.daily_puzzle_pool FROM anon, authenticated;

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

-- ============================================================================
-- 5. LONG-TERM DAILY CHALLENGE SCHEDULER & ANTI-CHEAT MOVE VERIFIER RPC
-- ============================================================================

-- Schedules Daily Challenges from `daily_puzzle_pool` for [p_start_date, p_start_date + p_days_ahead].
-- Deterministic date-modulo rotation ensures no 7-day cliff and no duplicate dates.
CREATE OR REPLACE FUNCTION public.schedule_daily_challenges(
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_days_ahead INTEGER DEFAULT 365
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pool_count INTEGER;
    v_inserted_count INTEGER := 0;
    v_day_offset INTEGER;
    v_target_date DATE;
    v_pool_row RECORD;
    v_epoch DATE := DATE '2025-01-01';
    v_slot BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_pool_count FROM public.daily_puzzle_pool;
    IF v_pool_count = 0 OR p_days_ahead IS NULL OR p_days_ahead < 0 THEN
        RETURN 0;
    END IF;

    FOR v_day_offset IN 0 .. p_days_ahead LOOP
        v_target_date := p_start_date + v_day_offset;

        IF NOT EXISTS (
            SELECT 1
            FROM public.daily_challenges
            WHERE challenge_date = v_target_date
        ) THEN
            v_slot := MOD(ABS(v_target_date - v_epoch), v_pool_count);
            SELECT board_string, optimal_moves, difficulty
            INTO v_pool_row
            FROM public.daily_puzzle_pool
            ORDER BY id ASC
            OFFSET v_slot
            LIMIT 1;

            INSERT INTO public.daily_challenges (
                challenge_date,
                board_string,
                optimal_moves,
                difficulty
            )
            VALUES (
                v_target_date,
                v_pool_row.board_string,
                v_pool_row.optimal_moves,
                v_pool_row.difficulty
            )
            ON CONFLICT (challenge_date) DO NOTHING;

            v_inserted_count := v_inserted_count + 1;
        END IF;
    END LOOP;

    RETURN v_inserted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.schedule_daily_challenges(DATE, INTEGER) FROM PUBLIC;

-- Drop legacy unverified RPC overload that trusted client-supplied p_moves_count
DROP FUNCTION IF EXISTS public.submit_daily_score(TEXT, DATE, INTEGER);
DROP FUNCTION IF EXISTS public.submit_daily_score(TEXT, DATE, JSONB);

-- Server-authoritative Anti-Cheat RPC:
-- Replays `p_moves` (JSONB array of {vehicle_id, steps/delta, [axis]}) step-by-step
-- on today's 6x6 board_string, enforces axis lock, 0..5 bounds, and collision checks,
-- confirms target car 'A' reaches (row=2, col=4), and computes moves_count server-side.
CREATE OR REPLACE FUNCTION public.submit_daily_score(
    p_player_name TEXT,
    p_challenge_date DATE,
    p_moves JSONB
)
RETURNS public.leaderboard_scores
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_clean_name TEXT := trim(COALESCE(p_player_name, ''));
    v_board_string TEXT;
    v_optimal_moves INTEGER;
    v_moves_count INTEGER;

    v_grid TEXT[] := array_fill('o'::TEXT, ARRAY[36]);
    v_exists BOOLEAN[] := array_fill(FALSE, ARRAY[26]);
    v_horiz BOOLEAN[] := array_fill(FALSE, ARRAY[26]);
    v_row INTEGER[] := array_fill(0, ARRAY[26]);
    v_col INTEGER[] := array_fill(0, ARRAY[26]);
    v_len INTEGER[] := array_fill(0, ARRAY[26]);

    v_i INTEGER;
    v_ch TEXT;
    v_vcode INTEGER;
    v_r INTEGER;
    v_c INTEGER;

    v_idx INTEGER;
    v_move JSONB;
    v_vid TEXT;
    v_axis TEXT;
    v_steps_text TEXT;
    v_steps INTEGER;
    v_cur_r INTEGER;
    v_cur_c INTEGER;
    v_cur_len INTEGER;
    v_new_r INTEGER;
    v_new_c INTEGER;
    v_step_pos INTEGER;

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

    IF v_clean_name !~ '^[a-zA-Z0-9_\- \u00C0-\u00D6\u00D8-\u00F6\u00F8-\u024F\u1E00-\u1EFF]+$' THEN
        RAISE EXCEPTION 'Nickname contains invalid characters.'
            USING ERRCODE = '22023';
    END IF;

    SELECT board_string, optimal_moves
    INTO v_board_string, v_optimal_moves
    FROM public.daily_challenges
    WHERE challenge_date = p_challenge_date;

    IF v_board_string IS NULL OR v_optimal_moves IS NULL THEN
        RAISE EXCEPTION 'No Daily Challenge found for %.', p_challenge_date
            USING ERRCODE = 'P0002';
    END IF;

    IF p_moves IS NULL OR jsonb_typeof(p_moves) <> 'array' THEN
        RAISE EXCEPTION 'Move history must be a valid JSON array.'
            USING ERRCODE = '22023';
    END IF;

    v_moves_count := jsonb_array_length(p_moves);
    IF v_moves_count < 1 OR v_moves_count > 999 THEN
        RAISE EXCEPTION 'Invalid move history length: must be between 1 and 999.'
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

    -- Parse 6x6 board_string (row-major 1..36) into grid & vehicle geometry
    FOR v_i IN 1 .. 36 LOOP
        v_ch := substr(v_board_string, v_i, 1);
        IF v_ch = '.' THEN
            v_ch := 'o';
        END IF;
        v_grid[v_i] := v_ch;

        IF v_ch <> 'o' THEN
            IF v_ch !~ '^[A-Z]$' THEN
                RAISE EXCEPTION 'Corrupted board character % at index %.', v_ch, v_i
                    USING ERRCODE = 'XX000';
            END IF;

            v_vcode := ascii(v_ch) - 64;
            v_r := (v_i - 1) / 6;
            v_c := (v_i - 1) % 6;

            IF NOT v_exists[v_vcode] THEN
                v_exists[v_vcode] := TRUE;
                v_row[v_vcode] := v_r;
                v_col[v_vcode] := v_c;
                v_len[v_vcode] := 1;
            ELSE
                v_len[v_vcode] := v_len[v_vcode] + 1;
                IF v_len[v_vcode] = 2 THEN
                    IF v_r = v_row[v_vcode] AND v_c = v_col[v_vcode] + 1 THEN
                        v_horiz[v_vcode] := TRUE;
                    ELSIF v_c = v_col[v_vcode] AND v_r = v_row[v_vcode] + 1 THEN
                        v_horiz[v_vcode] := FALSE;
                    ELSE
                        RAISE EXCEPTION 'Corrupted board layout for vehicle %.', v_ch
                            USING ERRCODE = 'XX000';
                    END IF;
                ELSIF v_len[v_vcode] = 3 THEN
                    IF NOT (
                        (v_horiz[v_vcode] AND v_r = v_row[v_vcode] AND v_c = v_col[v_vcode] + 2)
                        OR (NOT v_horiz[v_vcode] AND v_c = v_col[v_vcode] AND v_r = v_row[v_vcode] + 2)
                    ) THEN
                        RAISE EXCEPTION 'Corrupted board layout for vehicle %.', v_ch
                            USING ERRCODE = 'XX000';
                    END IF;
                ELSE
                    RAISE EXCEPTION 'Invalid vehicle length for %.', v_ch
                        USING ERRCODE = 'XX000';
                END IF;
            END IF;
        END IF;
    END LOOP;

    IF NOT (v_exists[1] AND v_horiz[1] AND v_row[1] = 2 AND v_len[1] = 2) THEN
        RAISE EXCEPTION 'Daily Challenge board has an invalid target vehicle A.'
            USING ERRCODE = 'XX000';
    END IF;

    FOR v_i IN 1 .. 26 LOOP
        IF v_exists[v_i] AND v_len[v_i] NOT IN (2, 3) THEN
            RAISE EXCEPTION 'Daily Challenge board has a vehicle with invalid length.'
                USING ERRCODE = 'XX000';
        END IF;
    END LOOP;

    -- Replay every move in p_moves and enforce physics (axis lock, 0..5 bounds, collisions)
    FOR v_idx IN 0 .. v_moves_count - 1 LOOP
        v_move := p_moves -> v_idx;
        IF jsonb_typeof(v_move) <> 'object' THEN
            RAISE EXCEPTION 'Move % is not a valid object.', v_idx + 1
                USING ERRCODE = '22023';
        END IF;

        v_vid := COALESCE(v_move ->> 'vehicle_id', v_move ->> 'id');
        IF v_vid IS NULL OR v_vid !~ '^[A-Z]$' THEN
            RAISE EXCEPTION 'Invalid vehicle_id at move %.', v_idx + 1
                USING ERRCODE = '22023';
        END IF;

        v_vcode := ascii(v_vid) - 64;
        IF NOT v_exists[v_vcode] THEN
            RAISE EXCEPTION 'Unknown vehicle "%" at move %.', v_vid, v_idx + 1
                USING ERRCODE = '22023';
        END IF;

        IF v_move ? 'axis' THEN
            v_axis := lower(trim(COALESCE(v_move ->> 'axis', '')));
            IF (v_horiz[v_vcode] AND v_axis <> 'h')
               OR (NOT v_horiz[v_vcode] AND v_axis <> 'v') THEN
                RAISE EXCEPTION 'Axis lock violation for vehicle "%" at move %.', v_vid, v_idx + 1
                    USING ERRCODE = '22023';
            END IF;
        END IF;

        v_steps_text := COALESCE(v_move ->> 'steps', v_move ->> 'delta');
        IF v_steps_text IS NULL OR v_steps_text !~ '^-?[1-4]$' THEN
            RAISE EXCEPTION 'Invalid step delta at move %.', v_idx + 1
                USING ERRCODE = '22023';
        END IF;
        v_steps := v_steps_text::INTEGER;

        v_cur_r := v_row[v_vcode];
        v_cur_c := v_col[v_vcode];
        v_cur_len := v_len[v_vcode];

        IF v_horiz[v_vcode] THEN
            v_new_c := v_cur_c + v_steps;
            IF v_new_c < 0 OR v_new_c + v_cur_len - 1 > 5 THEN
                RAISE EXCEPTION 'Move % pushes vehicle "%" out of 0..5 bounds.', v_idx + 1, v_vid
                    USING ERRCODE = '22023';
            END IF;

            IF v_steps > 0 THEN
                FOR v_step_pos IN (v_cur_c + v_cur_len) .. (v_new_c + v_cur_len - 1) LOOP
                    IF v_grid[v_cur_r * 6 + v_step_pos + 1] <> 'o' THEN
                        RAISE EXCEPTION 'Collision at move % for vehicle "%".', v_idx + 1, v_vid
                            USING ERRCODE = '22023';
                    END IF;
                END LOOP;
            ELSE
                FOR v_step_pos IN v_new_c .. (v_cur_c - 1) LOOP
                    IF v_grid[v_cur_r * 6 + v_step_pos + 1] <> 'o' THEN
                        RAISE EXCEPTION 'Collision at move % for vehicle "%".', v_idx + 1, v_vid
                            USING ERRCODE = '22023';
                    END IF;
                END LOOP;
            END IF;

            FOR v_step_pos IN v_cur_c .. (v_cur_c + v_cur_len - 1) LOOP
                v_grid[v_cur_r * 6 + v_step_pos + 1] := 'o';
            END LOOP;
            FOR v_step_pos IN v_new_c .. (v_new_c + v_cur_len - 1) LOOP
                v_grid[v_cur_r * 6 + v_step_pos + 1] := v_vid;
            END LOOP;
            v_col[v_vcode] := v_new_c;
        ELSE
            v_new_r := v_cur_r + v_steps;
            IF v_new_r < 0 OR v_new_r + v_cur_len - 1 > 5 THEN
                RAISE EXCEPTION 'Move % pushes vehicle "%" out of 0..5 bounds.', v_idx + 1, v_vid
                    USING ERRCODE = '22023';
            END IF;

            IF v_steps > 0 THEN
                FOR v_step_pos IN (v_cur_r + v_cur_len) .. (v_new_r + v_cur_len - 1) LOOP
                    IF v_grid[v_step_pos * 6 + v_cur_c + 1] <> 'o' THEN
                        RAISE EXCEPTION 'Collision at move % for vehicle "%".', v_idx + 1, v_vid
                            USING ERRCODE = '22023';
                    END IF;
                END LOOP;
            ELSE
                FOR v_step_pos IN v_new_r .. (v_cur_r - 1) LOOP
                    IF v_grid[v_step_pos * 6 + v_cur_c + 1] <> 'o' THEN
                        RAISE EXCEPTION 'Collision at move % for vehicle "%".', v_idx + 1, v_vid
                            USING ERRCODE = '22023';
                    END IF;
                END LOOP;
            END IF;

            FOR v_step_pos IN v_cur_r .. (v_cur_r + v_cur_len - 1) LOOP
                v_grid[v_step_pos * 6 + v_cur_c + 1] := 'o';
            END LOOP;
            FOR v_step_pos IN v_new_r .. (v_new_r + v_cur_len - 1) LOOP
                v_grid[v_step_pos * 6 + v_cur_c + 1] := v_vid;
            END LOOP;
            v_row[v_vcode] := v_new_r;
        END IF;
    END LOOP;

    -- Confirm target car 'A' reached the exit position (row=2, col=4)
    IF NOT (v_horiz[1] AND v_row[1] = 2 AND v_col[1] = 4) THEN
        RAISE EXCEPTION 'Move history does not reach winning state (vehicle A at row 2, col 4).'
            USING ERRCODE = '22023';
    END IF;

    IF v_moves_count < v_optimal_moves THEN
        RAISE EXCEPTION 'Submitted solution (%) is shorter than puzzle optimal moves (%).',
            v_moves_count, v_optimal_moves
            USING ERRCODE = '22023';
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
        v_moves_count
    )
    RETURNING * INTO v_inserted;

    RETURN v_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_daily_score(TEXT, DATE, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_daily_score(TEXT, DATE, JSONB) TO authenticated;

-- ============================================================================
-- 6. VERIFIED DAILY PUZZLE POOL & LONG-TERM SCHEDULE INITIALIZATION
--    (Zero fake leaderboard rows; 36 solver-verified puzzles scheduled 365+ days)
-- ============================================================================

INSERT INTO public.daily_puzzle_pool (board_string, optimal_moves, difficulty)
VALUES
    ('BBoooMooIKLMAAIKLMGHJCCCGHJDDoGEEFFo', 10, 'easy'),
    ('BBoJooCCoJLMAAoKLMDDoKEEHoIFFFHoIGGo', 9,  'easy'),
    ('HIBBBoHICCLMAAJoLMDDJoLooooKEEFFoKGG', 8,  'easy'),
    ('BBCCoMDDJKLMAAJKLMIEEELoIoFFooIGGHHo', 10, 'easy'),
    ('HIBBBoHICCLoAAooLoooDDLoooJKEEFFJKGG', 9,  'easy'),
    ('BBJCCMIoJKLMIAAKLMDDooEEooFFoooGGHHH', 8,  'easy'),
    ('BBBCCoIDDooMIAAooMIEEFFMoJKLGGoJKLHH', 10, 'easy'),
    ('GoHBBBGoHCCCAAoIooDDoIKLEEoJKLoFFJoL', 9,  'easy'),
    ('BBIoCCDDIJKLAAoJKLHEEEKoHoooooHFFoGG', 8,  'easy'),
    ('GoHoBBGoHCCCAAoIoooDDIKLoEEJKLoFFJoL', 10, 'easy'),
    ('BBHoJoCCHIJLAAoIKLDDoIKLGooEEEGooFFo', 9,  'easy'),
    ('BBHoJoCCHIJLoAAIKLDDoIKLGooEEEGooFFF', 8,  'easy'),
    ('GoIBBoGoIKLMGAAKLMoHCCCMoHJDDoEEJFFo', 18, 'medium'),
    ('HBBBLMHoCCLMooAALMoIDDoooIJKEEFFJKGG', 14, 'medium'),
    ('oGBBBKoGHJoKAAHJoKCCooDDooIoEEooIoFF', 18, 'medium'),
    ('ooBBBooooCCKAAHJoKDDHJoKGoIoEEGoIFFF', 14, 'medium'),
    ('BBCCLMIDDKLMIAAKLMIoJEEEooJoFFGGoHHo', 18, 'medium'),
    ('oFoBBBoFGIoJAAGIoJCCoDDJooHoEEooHooo', 14, 'medium'),
    ('ooIBBBooICCMAAoJLMDDoJLNHEEKLNHFFKGG', 18, 'medium'),
    ('BBCCLoDDoKLMAAoKLMIoJEEEIoJoFFIGGoHH', 14, 'medium'),
    ('IBBBCCIoKDDMIoKAAMoEEFFMoJoLGGoJoLHH', 18, 'medium'),
    ('GoBBJLGCCIJLoAAIKMoDDIKMooHEEEooHoFF', 14, 'medium'),
    ('BBBoooCCCoooAAHIooDDHIKLGEEJKLGFFJKL', 18, 'medium'),
    ('BBCCKLoooJKLAAoJKLHoIDDDHoIoEEHFFGGo', 14, 'medium'),
    ('GHIKBBGHIKLMGoAALMCCCooMooJoDDEEJoFF', 25, 'hard'),
    ('oBBBLMCCoKLMAAoKLMHIooDDHIJoEEFFJoGG', 19, 'hard'),
    ('oGBBBKoGHooKAAHooKCCoDDoooIJEEooIJFF', 20, 'hard'),
    ('FGoBBBFGHooKAAHooKCCoDDKooIJEEooIJoo', 21, 'hard'),
    ('GooIBBGCCIKLAAHoKLDDHJEEFFFJoooooooo', 22, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKMFFFoKM', 23, 'hard'),
    ('IBBCCoIDDKLMIAAKLMoEEELoooJoFFGGJoHH', 24, 'hard'),
    ('BBBCCMIJKDDMIJKAAMIoEEFFoooLGGoooLHH', 25, 'hard'),
    ('GoBBJLGCCIJLAAHIKMDDHIKMEEEoooFFoooo', 19, 'hard'),
    ('BBBoKLCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 20, 'hard'),
    ('GoHoBBGoHIKLAAHIKLCCCooLoooJDDEEoJFF', 21, 'hard'),
    ('oHIBBMoHIoLMGAAoLNGooCCNGoJKDDEEJKFF', 22, 'hard')
ON CONFLICT (board_string) DO NOTHING;

-- Immediately populate the next 365 days of Daily Challenges
SELECT public.schedule_daily_challenges(CURRENT_DATE, 365);

-- Register nightly pg_cron job when pg_cron extension is enabled in Supabase
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'rushout_schedule_daily_challenges') THEN
            PERFORM cron.unschedule('rushout_schedule_daily_challenges');
        END IF;
        PERFORM cron.schedule(
            'rushout_schedule_daily_challenges',
            '5 0 * * *',
            'SELECT public.schedule_daily_challenges(CURRENT_DATE, 365);'
        );
    END IF;
EXCEPTION
    WHEN undefined_table OR insufficient_privilege THEN
        NULL;
END $$;

-- ============================================================================
-- 7. RECOVERABLE PLAYER PROFILE & CLOUD PROGRESS SYNC (NON-ANONYMOUS AUTH)
-- Requires verified account auth (e.g. Email OTP / OAuth) so progress can be
-- safely restored across reinstalls and multiple devices via auth.uid().
-- Anonymous sessions cannot read or write cloud backup tables.
-- ============================================================================

-- 7.1 Table: player_profiles (scoped strictly to recoverable auth.uid())
CREATE TABLE IF NOT EXISTS public.player_profiles (
    user_id UUID PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(24) NOT NULL CHECK (char_length(trim(username)) BETWEEN 2 AND 24),
    tutorial_completed BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7.2 Table: player_level_progress (scoped strictly to recoverable auth.uid())
CREATE TABLE IF NOT EXISTS public.player_level_progress (
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES public.player_profiles(user_id) ON DELETE CASCADE,
    level_id INTEGER NOT NULL CHECK (level_id >= 1),
    difficulty VARCHAR(16) NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')),
    best_moves INTEGER CHECK (best_moves IS NULL OR best_moves >= 1),
    stars INTEGER NOT NULL DEFAULT 0 CHECK (stars BETWEEN 0 AND 3),
    is_unlocked BOOLEAN NOT NULL DEFAULT true,
    is_skipped BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, level_id)
);

CREATE INDEX IF NOT EXISTS idx_player_level_progress_user
    ON public.player_level_progress (user_id, level_id);

ALTER TABLE public.player_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_level_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "player_profiles_owner_recoverable_all" ON public.player_profiles;
DROP POLICY IF EXISTS "player_level_progress_owner_recoverable_all" ON public.player_level_progress;

REVOKE ALL ON public.player_profiles FROM anon;
REVOKE ALL ON public.player_level_progress FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.player_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.player_level_progress TO authenticated;

CREATE POLICY "player_profiles_owner_recoverable_all"
    ON public.player_profiles
    FOR ALL
    TO authenticated
    USING (
        auth.uid() = user_id
        AND COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    )
    WITH CHECK (
        auth.uid() = user_id
        AND COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
        AND char_length(trim(username)) BETWEEN 2 AND 24
        AND username ~ '^[a-zA-Z0-9_\- \u00C0-\u00D6\u00D8-\u00F6\u00F8-\u024F\u1E00-\u1EFF]+$'
    );

CREATE POLICY "player_level_progress_owner_recoverable_all"
    ON public.player_level_progress
    FOR ALL
    TO authenticated
    USING (
        auth.uid() = user_id
        AND COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
    )
    WITH CHECK (
        auth.uid() = user_id
        AND COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
        AND level_id >= 1
        AND difficulty IN ('easy', 'medium', 'hard')
        AND (best_moves IS NULL OR best_moves >= 1)
        AND stars BETWEEN 0 AND 3
    );
