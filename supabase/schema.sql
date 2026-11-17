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
    difficulty VARCHAR(16) NOT NULL DEFAULT 'hard',
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
    SELECT COUNT(*) INTO v_pool_count
    FROM public.daily_puzzle_pool
    WHERE difficulty = 'hard';
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
            WHERE difficulty = 'hard'
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

-- Server-side nickname profanity & link validator (mirrors client-side rules,
-- folding Vietnamese diacritics and checking restricted phrases/tokens).
CREATE OR REPLACE FUNCTION public.is_clean_player_name(p_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
    v_folded TEXT;
    v_collapsed TEXT;
    v_phrase TEXT;
    v_tokens TEXT[];
    v_blocked_phrases TEXT[] := ARRAY[
        'fuck', 'shit', 'bitch', 'asshole', 'nigger', 'faggot',
        'whore', 'slut', 'pussy', 'cunt',
        'du ma', 'duma', 'dit me', 'ditme', 'con cac', 'cai lon',
        'http://', 'https://', 'www.', '.com', '.net', '.org', '.vn'
    ];
    v_blocked_tokens TEXT[] := ARRAY[
        'dick', 'dkm', 'dmm', 'vcl', 'vkl', 'dit', 'lon', 'buoi', 'cac'
    ];
BEGIN
    IF p_name IS NULL OR char_length(trim(p_name)) = 0 THEN
        RETURN FALSE;
    END IF;

    v_folded := translate(
        lower(trim(p_name)),
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ',
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
    );
    v_collapsed := regexp_replace(v_folded, '\s+', ' ', 'g');

    FOREACH v_phrase IN ARRAY v_blocked_phrases LOOP
        IF strpos(v_collapsed, v_phrase) > 0 THEN
            RETURN FALSE;
        END IF;
    END LOOP;

    v_tokens := regexp_split_to_array(v_collapsed, '[\s_\-]+');
    IF v_tokens && v_blocked_tokens THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.is_clean_player_name(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_clean_player_name(TEXT) TO authenticated;

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

    IF NOT public.is_clean_player_name(v_clean_name) THEN
        RAISE EXCEPTION 'Please choose an appropriate nickname without restricted words.'
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
--    (Zero fake leaderboard rows; 1,575 shuffled Hard puzzles scheduled forever)
-- ============================================================================

DELETE FROM public.daily_puzzle_pool WHERE difficulty <> 'hard';

INSERT INTO public.daily_puzzle_pool (board_string, optimal_moves, difficulty)
VALUES
    ('BBBIKLooHIKLooHAAMCCoJoMGooJDDGEEFFF', 25, 'hard'),
    ('BBBIoLCCHIoLAAHoooGDDoooGEEJKMFFFJKM', 19, 'hard'),
    ('FoHBBoFoHCCCAAoIoKDDoIJKGooIJLGEEEoL', 25, 'hard'),
    ('GBBIKoGCCIKoAAHJoMDDHJoMEEEoLNoFFoLN', 22, 'hard'),
    ('BBBIKMoCCIKMAAHJLoDDHJLoGEEoooGFFooo', 22, 'hard'),
    ('GoBBooGCCoooAAHIJLDDHIJLEEEIKoFFFoKo', 23, 'hard'),
    ('BBBIKoCCCIKoAAHJKoDDHJooGEEoooGFFooo', 21, 'hard'),
    ('BBBCCMIDDKLMIAAKLNEEoooNooJFFNGGJHHH', 19, 'hard'),
    ('BBBIoLCCCIKLAAHoKLDDHoooGooJEEGooJFF', 25, 'hard'),
    ('ooBBBMooKCCMAAKLoMDDoLEEJFFoGGJHHHII', 24, 'hard'),
    ('ooBBBKooHCCKAAHooKooIJDDGoIJEEGooFFF', 24, 'hard'),
    ('BBBIKLoooIKLoooAAMCCHJoMGoHJDDGEEFFF', 24, 'hard'),
    ('BBBGIJooFGIJAAFoIJCCCoooEDDHooEooHoo', 24, 'hard'),
    ('BBBJoLCCoJoLAAIKoLDDIKooHEEoooHFFoGG', 21, 'hard'),
    ('IBBCCCIoDDDLAAoKoLooJKEEooJFFFGGGHHo', 19, 'hard'),
    ('GooIBBGCCIKLAAoJKLDDoJEEooHFFFooHooo', 25, 'hard'),
    ('BBoCCCoooKDDAAJKoLEEJooLIoJFFMIGGHHM', 25, 'hard'),
    ('BBBoKLoCCoKLAAHIKMDDHIoMGEEJooGFFJoo', 20, 'hard'),
    ('oooHJoBBBHJoAAGoJoCCGoooFooIDDFooIEE', 22, 'hard'),
    ('oGHIBBoGHIJLFoAAJLFoooKMFoCCKMDDEEEM', 21, 'hard'),
    ('HooJBBHCCJLMAAIKLMDDIKEEoooFFFoooGGG', 24, 'hard'),
    ('BBoCCCoooDDoAAoJoKEEIJoKHoIFFKHoIGGG', 22, 'hard'),
    ('BBCCJoFoooJoFoAAJKFoDDDKoGHIoKoGHIEE', 25, 'hard'),
    ('BBBCCoGHIooKGHIAAKGDDDoKoooJEEoooJFF', 20, 'hard'),
    ('oGHBBLoGHIKLAAHIKLFoooCCFooJDDEEEJoo', 24, 'hard'),
    ('BBCCCLooHJKLAAHJKLGDDEEoGoIoooooIoFF', 25, 'hard'),
    ('GooBBKGooIoKAAoIoKooHCCCooHJDDEEHJFF', 24, 'hard'),
    ('FGHBBBFGHooKoooAAKCCoDDKooIJEEooIJoo', 23, 'hard'),
    ('BBoICCoooIoKAAoooKDDHJoKGoHJEEGoHFFF', 19, 'hard'),
    ('FBBoooFoCCCoAAHIoJDDHIoJGooIoKGEEEoK', 21, 'hard'),
    ('ooooBBooooCCAAHIoJDDHIoJGoHIoKGEEFFK', 20, 'hard'),
    ('BBCCooHDDoLoHAAoLMHEEELMoIJKFFoIJKGG', 24, 'hard'),
    ('ooBBBMooKCCMAAKLoMJDDLEEJFFoGGHHHoII', 21, 'hard'),
    ('BBCCLMIoJoLMIoJAAMoDDKEEoooKFFoGGGHH', 21, 'hard'),
    ('BBoCCLDDIooLAAIooMHooEEMHoJKFFHoJKGG', 25, 'hard'),
    ('BBBCCMIDDKLMIAAKLNoooEENooJFFNGGJHHH', 20, 'hard'),
    ('FGHBBLFGHJKLFAAJKLoooCCCooIoDDEEIooo', 19, 'hard'),
    ('BBBoCCHoJooLHoJAALHDDEELoIoKFFoIoKGG', 19, 'hard'),
    ('GoHBBLGoHoKLGAAoKLooICCCooIJDDoEEJFF', 23, 'hard'),
    ('BBCCKoGoooKLGAAoKLGoDDDLoHIJEEoHIJFF', 25, 'hard'),
    ('BBoCCoGoooKoGAAoKoGDDDKooHIJEEoHIJFF', 20, 'hard'),
    ('ooBBBKCCIooKAAIoJLDDIoJLHooEEEHFFGGo', 21, 'hard'),
    ('BBBCCKGHIooKGHIAAKGDDDoooooJEEoooJFF', 19, 'hard'),
    ('oooHoJBBBHoJAAoooJooooCCFoGIDDFoGIEE', 24, 'hard'),
    ('GoIKBBGoIKLMGoAALMoHCCCMoHJDDoEEJFFo', 21, 'hard'),
    ('oooBBBCCooooAAHIoKDDHIoKGoHJoKGEEJFF', 21, 'hard'),
    ('oooHoJBBBHoJAAoooJCCooooFoGIDDFoGIEE', 23, 'hard'),
    ('BBBCCMDDoKLMAAoKLNIooEENIoJFFNGGJHHH', 23, 'hard'),
    ('FoGoBBFoGHJKAAGHJKCCCooKoooIDDoooIEE', 20, 'hard'),
    ('GBBIKoGCCIKoAAHJoMDDHJoMEEEoLMFFFoLo', 22, 'hard'),
    ('oBBCCooDDDKLAAooKLoEEoKMHIJFFMHIJGGG', 21, 'hard'),
    ('BBCCLMIoJoLMIoJAAMoDDKEEoooKFFoGGHHH', 21, 'hard'),
    ('oBBBLoCCJKLoAAJKLoooooDDHIEEooHIFFGG', 23, 'hard'),
    ('GooBBKGooCCKAAIooKHoIJDDHEEJooFFFJoo', 20, 'hard'),
    ('BBIJCCooIJoLAAIKoLDDoKEEHoooFFHooGGG', 23, 'hard'),
    ('BBooJLCCCoJLAAHIKMDDHIKMGooIEEGFFooo', 22, 'hard'),
    ('oBBCCoIDDKLMIAAKLMIEEELoooJoFFGGJoHH', 23, 'hard'),
    ('BBBoLMCCooLMAAIJLoDDIJooHEEKooHFFKGG', 21, 'hard'),
    ('GHIoBBGHIKLMGAAKLMooJCCNooJDDNEEFFFN', 23, 'hard'),
    ('BBIJooooIJCCAAIJoKDDoooKHooEELHFFGGL', 24, 'hard'),
    ('BBBoKoCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 20, 'hard'),
    ('BBBooJooGHoJAAGHoJoCCCooFDDIooFEEIoo', 20, 'hard'),
    ('oBBBCCIoKDDMIoKAAMIEEFFMoJoLGGoJoLHH', 19, 'hard'),
    ('oooHoKBBBHJKAAGoJKCCGoooFDDIooFEEIoo', 19, 'hard'),
    ('FoHBBBFoHooKooAAoKoGICCKoGIJDDEEEJoo', 20, 'hard'),
    ('oBBCCCoDDDKLAAooKLoEEoKMHIJFFMHIJGGG', 22, 'hard'),
    ('oHBBBLoHCCKLooAAKMGoIJKMGoIJDDGEEFFo', 21, 'hard'),
    ('oBBIoKCCCIoKAAHJoKDDHJooGoooEEGoooFF', 22, 'hard'),
    ('BBBCCLoDDoKLoAAoKMIooEEMIoJFFMGGJHHH', 20, 'hard'),
    ('BBBKCCDDJKLMAAJKLMEEooFFIooGGNIHHooN', 25, 'hard'),
    ('BBCCKoGoooKoGAAoKLGDDDoLoHIJEEoHIJFF', 24, 'hard'),
    ('oGBBBJoGoIoJAAoIoKooHCCKFoHDDKFoHEEE', 23, 'hard'),
    ('IBBCCMIDDKLMIAAKLMoEEELoooJoFFGGJoHH', 25, 'hard'),
    ('BBooJoCCCoJoAAoIKLoDDIKLGoHIEEGoHFFo', 23, 'hard'),
    ('BBBIoKCCHIoKAAHJoLGDDJoLGEEoooFFFooo', 21, 'hard'),
    ('BBooJLCCCoJLAAHIKMDDHIKMGooIEEGooFFo', 23, 'hard'),
    ('HBBCCKHoDDDKAAIJoLEEIJoLFFFooooooGGo', 25, 'hard'),
    ('oooBBBooGHJKAAGHJKoCCCJoFDDIooFEEIoo', 19, 'hard'),
    ('BBCCLoHDDoLoHAAoLoHEEEoooIJKFFoIJKGG', 23, 'hard'),
    ('ooBBBKCCoooKAAIJoLDDIJoLHoIEEEHFFGGo', 22, 'hard'),
    ('GoBBooGoooCCAAHIJLDDHIJLEEEIKLFFooKo', 25, 'hard'),
    ('FoBBIKFCCHIKAAGHJoDDGHJoEEEooLoooooL', 19, 'hard'),
    ('GoBBooGCCoooAAHIJoDDHIJoEEEIKoFFFoKo', 22, 'hard'),
    ('BBBooLCCoooLAAIJoLDDIJooHEEKooHFFKGG', 19, 'hard'),
    ('BBBIoKCCHIoKAAHJoLGDDJoLGEEooooooFFF', 22, 'hard'),
    ('BBCCooGoooKLGAAoKLGDDDKLoHIJEEoHIJFF', 23, 'hard'),
    ('BBoCCoHDDJKLHAAJKLHEEEKoooIoooFFIoGG', 21, 'hard'),
    ('BBBooLoCCooLAAHIoMDDHIKMGEEJKoGFFJKo', 19, 'hard'),
    ('HBBCCCHDDJKLHAAJKLEEoFFLoIoooooIGGoo', 25, 'hard'),
    ('GooBBoGooICCAAHIJLDDHIJLEEEoKoFFooKo', 25, 'hard'),
    ('BBBCCLDDIooLAAIoooEEEoooHFFJKMHGGJKM', 25, 'hard'),
    ('BBooooCCooooAAHIoJDDHIoJGoHIoKGEEFFK', 22, 'hard'),
    ('ooBBBLCCIJKLAAIJKoDDIooMHoEEEMHFFGGG', 19, 'hard'),
    ('oooHJoBBBHJoAAooJooooICCFoGIDDFoGoEE', 25, 'hard'),
    ('BBCCooHDDJKoHAAJKoHEEEKoooIoooFFIoGG', 19, 'hard'),
    ('GoJKBBGoJKCCHAAooLHIoooLHIDDDMEEEFFM', 19, 'hard'),
    ('ooBBBKCCIooKAAIoJLDDIoJLHoEEEoHFFGGo', 20, 'hard'),
    ('FoHBBBFoHoKLooAAKLoGICCLoGIJDDEEEJoo', 21, 'hard'),
    ('FHoBBLFHooKLooAAKLooICCCGoIJDDGoIJEE', 19, 'hard'),
    ('BBBCCMoDDKLMoAAKLNIooEENIoJFFNGGJHHH', 21, 'hard'),
    ('BBCCoLHooJKLHAAJKLHDDDKoooIoEEFFIGGo', 20, 'hard'),
    ('ooFBBBooFGIJoAAGIJECCCIJEooHooEooHDD', 23, 'hard'),
    ('HBBCCoHDDKLoHAAKLMEEEoLMoIJoFFoIJoGG', 19, 'hard'),
    ('HooJBBHCCJLMAAIKLMDDIKEEoooFFFoooGGo', 24, 'hard'),
    ('GBBBCCGHIooKGHIAAKDDDJoKoooJEEooooFF', 25, 'hard'),
    ('oBBCCoGDDoKoGAAoKoGEEEKooHIJoooHIJFF', 19, 'hard'),
    ('oooBBBoooCCMAAIJLMDDIJLNHEEKLNHFFKGG', 19, 'hard'),
    ('BBBooMCCCooMAAHIKoDDHIKoGEEJLNGFFJLN', 21, 'hard'),
    ('GBBIKoGCCIKoAAHJLMDDHJLMEEEooNFFFooN', 21, 'hard'),
    ('GoBBooGCCIooAAHIJLDDHIJLEEEoKLFFFoKo', 23, 'hard'),
    ('GHoBBBGHIooLAAIooLCCoDDLooJKEEooJKFF', 22, 'hard'),
    ('GBBCCoGDDoKLGAAoKLoEEEKooHIJoooHIJFF', 19, 'hard'),
    ('BBBCCLoDDJKLAAoJKMEEoJKMHoIFFMHoIGGG', 23, 'hard'),
    ('BBBCCLDDIJKLAAIJKooooEEEHFFooMHGGooM', 22, 'hard'),
    ('BBBHoKooGHJKAAGIJKCCCIooFoooDDFEEooo', 25, 'hard'),
    ('BBBJoMCCoJLMAAIoLMDDIoooHEEKooHFFKGG', 21, 'hard'),
    ('HooJBBHCCJLMAAIKLMDDIKEEFFFooooooGGG', 23, 'hard'),
    ('oGHBBooGHIJLFAAIJLFoooKMFoCCKMDDDEEM', 24, 'hard'),
    ('BBBoKMoCCoKMAAHILoDDHILoGEEJooGFFJoo', 20, 'hard'),
    ('HBBCCoHDDoKoHAAoKoEEEoKoooIJooFFIJGG', 24, 'hard'),
    ('EoHIBBEoHIKLooAAKLFGCCKMFGoJoMFooJDD', 23, 'hard'),
    ('IBBCCoIDDKLoIAAKLoEEEoLoooJoFFGGJoHH', 24, 'hard'),
    ('BBBCCoHoJooLHoJAALHDDEELoIoKFFoIoKGG', 20, 'hard'),
    ('GBBCCoGDDoKoGAAoKLEEEoKLoHIJFFoHIJoo', 19, 'hard'),
    ('FoGBBKFoGHJKAAGHJKoooCCCoooIDDoooIEE', 23, 'hard'),
    ('ooBBBMCCJooMAAJKLNDDoKLNIEEFFNIGGHHH', 25, 'hard'),
    ('HBBJooHCCJLMAAIoLMDDIKEEFFFKoooooGGG', 19, 'hard'),
    ('BBCCKoGDDoKoGAAoKoGEEEoooHIJoooHIJFF', 22, 'hard'),
    ('BBJoCCooJoDDAAJKoMEEoKoMIooLFFIGGLHH', 20, 'hard'),
    ('oHBBKLoHooKLoooAALCCIJDDGoIJEEGoIFFF', 23, 'hard'),
    ('BBCCoMIoooLMIAAoLMDDJKEEooJKFFoGGGHH', 25, 'hard'),
    ('FBBJLMFooJLMoooAAMGHIKCCGHIKDDGEEEoo', 23, 'hard'),
    ('HooBBMHoJCCMooJAANIDDLoNIoKLEEFFKGGo', 22, 'hard'),
    ('FoBBooFoooCCAAGHIoDDGHIoEEEHJoooooJo', 21, 'hard'),
    ('BBBKCCDDoKLMoAAKLMEEooFFIoJGGNIoJHHN', 22, 'hard'),
    ('BBBIKLCCCIKLAAHJKLDDHJooGEEoooGFFooo', 22, 'hard'),
    ('ooBBBJooGooJAAGooJoFHoCCoFHIDDEEEIoo', 25, 'hard'),
    ('BBBKCCDDoKLoAAoKLoEEooFFIoJGGMIoJHHM', 21, 'hard'),
    ('ooBBBKCCIooKAAIJoLDDIJoLHoEEEoHFFGGo', 20, 'hard'),
    ('GBBCCoGoooKoGAAoKLDDDoKLoHIJEEoHIJFF', 19, 'hard'),
    ('FoGBBJFoGHoJAAGHoJoooCCCoooIDDoooIEE', 22, 'hard'),
    ('ooBBBKCCIJoKAAIJoLDDIooLHoEEEoHFFGGo', 19, 'hard'),
    ('HooJBBHCCJLoAAIKLoDDIKEEFFFooooooGGo', 22, 'hard'),
    ('oGHoBBEGHJKLEAAJKLFoICCMFoIooMFoDDDM', 25, 'hard'),
    ('BBBCCLHoDDKLHAAJKMEEoJKMooIFFMooIGGG', 19, 'hard'),
    ('ooooIKBBBoIKAAoHJLoCCHJLFoGHDDFoGEEo', 23, 'hard'),
    ('ooBBBKCCIooKAAIJoLDDIJoLHooEEEHFFGGG', 21, 'hard'),
    ('oooBBMCCCooMAAHIKoDDHIKoGEEJLNGFFJLN', 20, 'hard'),
    ('oBBCCKooDDDKAAoJoLoEEJoLHoIFFFHoIGGG', 20, 'hard'),
    ('BBBooMCCooLMAAIJLNDDIJoNHEEKooHFFKGG', 20, 'hard'),
    ('GooBBKGooIoKoAAIoKooHCCCooHJDDEEHJFF', 25, 'hard'),
    ('oBBCCCHDDJKLHAAJKLHEEFFLoIoooooIooGG', 22, 'hard'),
    ('GoBBooGooICCAAHIJLDDHIJLEEEoKoFFFoKo', 25, 'hard'),
    ('BBBooKooHIoKAAHIoKoCCCooGDDJooGEEJFF', 22, 'hard'),
    ('BBoCCoGDDoKoGAAoKLGEEEKLoHIJoLoHIJFF', 22, 'hard'),
    ('ooBBLMooJoLMooJAAMHICCDDHIoKEEHFFKGG', 21, 'hard'),
    ('BBJooLGoJCCLGAAKoMDDDKoMHIooEEHIFFFo', 24, 'hard'),
    ('BBCCooHooJKLHAAJKLHDDDKoooIoEEFFIoGG', 20, 'hard'),
    ('FoBBooFooHCCAAGHIoDDGHIoEEEoJoooooJo', 22, 'hard'),
    ('ooHBBBooHIoKAAoIoKoCCCoKGDDJooGEEJFF', 19, 'hard'),
    ('BBJKooHoJKCCHoAALMHIDDLMoIEELNoFFGGN', 21, 'hard'),
    ('oFBBBooFGoIJAAGoIJooHCCKooHDDKooEEEK', 20, 'hard'),
    ('GoBBooGCCIooAAHIJLDDHIJLEEEoKMFFFoKM', 24, 'hard'),
    ('oBBBCCooIDDDAAIJoLEEoJoLHFFoKMHGGGKM', 24, 'hard'),
    ('HBBCCKHoDDDKoAAJoLoEEJoLooIFFFooIGGo', 21, 'hard'),
    ('BBJKooHoJKCCHooAAMHIDDLMoIEELNFFGGLN', 25, 'hard'),
    ('BBBCCLDDIJoLAAIJooEEEoooHFFoKMHGGoKM', 24, 'hard'),
    ('FGBBBoFGHooKAAHooKCCoDDKooIJEEooIJoo', 20, 'hard'),
    ('oBBCCLooDDDLoAAJKMoEEJKMHoIFFFHoIGGo', 21, 'hard'),
    ('BBBJLoCCoJLoAAIKLoDDIKooHoooEEHFFoGG', 23, 'hard'),
    ('IBBCCCIooLDDAAoLoMJooEEMJoKFFMGGKHHH', 24, 'hard'),
    ('FBBooMFooJLMAAoJLMGHIKCCGHIKDDGEEEoo', 20, 'hard'),
    ('BBooJoCCCoJLAAHIKLDDHIKLGooIEEGooFFo', 21, 'hard'),
    ('BBBoKoCCCoKoAAHIKoDDHIooGEEJooGFFJoo', 19, 'hard'),
    ('BBBoJLCCCoJLAAHoKMDDHIKMGEEIooGFFIoo', 19, 'hard'),
    ('BBICCCooIJDDAAIJoKEEoooKHooFFKHooGGG', 25, 'hard'),
    ('FooBBoFooHCCAAGHIKDDGHIKEEEoJKooooJo', 25, 'hard'),
    ('HooJBBHCCJLMAAIoLMDDIKEEFFFKoooooGGo', 22, 'hard'),
    ('HoooBBHCCJLMAAIJLMDDIKEEFFFKoooooGGG', 21, 'hard'),
    ('FBBooKFoCCCKAAHIooDDHIJLGooIJLGooEEE', 19, 'hard'),
    ('oooHoJBBBHoJAAGIoJCCGIooFoooDDFoooEE', 21, 'hard'),
    ('GBBKMNGooKMNAAoooNHIJLCCHIJLDDHEEEFF', 23, 'hard'),
    ('BBoCCoFoooJoFAAoJKFDDDJKoGHIEEoGHIoo', 21, 'hard'),
    ('GBBCCKGoDDDKAAHIJLEEHIJLoooFFFoooooo', 25, 'hard'),
    ('BBCCCJGooIoJGAAIoJDDHoEEooHoFFooHooo', 19, 'hard'),
    ('oGHBBooGHIJLFAAIJLFoooKMFoCCKMDDEEEM', 24, 'hard'),
    ('BBCCoooDDoKoHAAoKoHEEEKoHoIJFFGGIJoo', 24, 'hard'),
    ('BBoCCCooooDDAAJKoLEEJKoLHIJooLHIFFGG', 24, 'hard'),
    ('GBBCCKGooIJKGAAIJKDDDoJoooHoEEFFHooo', 19, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKLFFFoKo', 22, 'hard'),
    ('oooHoJBBBHoJAAGIoJCCGIooFDDoooFoooEE', 20, 'hard'),
    ('BBBoKMoCCoKMAAHILMDDHILoGEEJooGFFJoo', 20, 'hard'),
    ('GHIKBBGHIKLMGAAoLMooJCCNooJDDNEEFFFN', 22, 'hard'),
    ('ooBBBLCCIooLAAIJKMDDIJKMHooEEEHFFGGG', 23, 'hard'),
    ('BBBCCLHIJDDLHIJAALHEEEoooooKFFoooKGG', 20, 'hard'),
    ('GoBBBLGoJooLooJAALHCCDDoHIoKEEHIoKFF', 22, 'hard'),
    ('BBBIKMoCCIKMAAHoLoDDHoLoGEEJooGFFJoo', 21, 'hard'),
    ('HBBCCKHoDDDKAAIJoLEEIJoLoooFFFoooGGG', 25, 'hard'),
    ('FooBBoFooCCCAAHIoKDDHIJKGooIJLGEEEoL', 24, 'hard'),
    ('IBBCCoIDDKLoIAAKLooEEELoooJoFFGGJoHH', 23, 'hard'),
    ('BBoCCMIooDDMIoJAANIoJEENooKLFFGGKLHH', 23, 'hard'),
    ('FBBooJFoCCCJAAHIooDDHIooGooIoKGEEEoK', 20, 'hard'),
    ('GBBIoLGCCIKLAAHJKoDDHJKoEEEooMFFFooM', 21, 'hard'),
    ('GoJKBBGoJKCCHoAAoLHIoooLHIDDDMEEFFFM', 20, 'hard'),
    ('HBBCCLHDDJKLHAAJKLEEEoKoooIoFFGGIooo', 20, 'hard'),
    ('oooBBBooGooJAAGooJoFHCCJoFHIDDEEEIoo', 22, 'hard'),
    ('GBBCCoGooIJKGAAIJKDDDoJoooHoEEFFHooo', 19, 'hard'),
    ('oHIBBMoHIoLMGoAALNGoJCCNGoJKDDEEoKFF', 24, 'hard'),
    ('oBBIoKCCCIoKAAoooKooooDDGoHJEEGoHJFF', 25, 'hard'),
    ('BBBoJoCCCoJLAAoIKLDDoIKLGoHIEEGoHFFo', 22, 'hard'),
    ('oBBIoLCCCIKLAAHJKLDDHJooGoooEEGoooFF', 23, 'hard'),
    ('BBBCCLDDoJKLAAoJKoooIEEEHoIFFMHooGGM', 19, 'hard'),
    ('oBBBCCGHIooKGHIAAKGDDDoKoooJEEoooJFF', 22, 'hard'),
    ('GBBIKMGCCIKMAAHJLNDDHJLNEEEoooFFFooo', 19, 'hard'),
    ('HBBCCLHDDJKLHAAJKLoEEEKoooIoFFGGIooo', 19, 'hard'),
    ('oFGBBBoFGoJKooAAJKooHCCKooHIDDEEEIoo', 20, 'hard'),
    ('BBBCCLDDJoKLAAJoKMoooEEMIooFFMIGGHHH', 25, 'hard'),
    ('BBBJLMCCIJLMAAIoooDDEEooHFFKoNHGGKoN', 22, 'hard'),
    ('oBBBLoCCJKLoAAJKLoDDooooHIEEooHIFFGG', 24, 'hard'),
    ('BBoCCCoDDDKLAAooKLEEooKMHIJFFMHIJGGG', 20, 'hard'),
    ('GoooBBGCCIKLAAHIKLDDHJEEFFFJoooooooo', 21, 'hard'),
    ('BBBoJoCCCIJoAAHIKLDDHIKLGoooEEGFFooo', 19, 'hard'),
    ('ooBBBMooJCCMAAJKLNoDDKLNIEEFFNIGGHHH', 21, 'hard'),
    ('oBBCCoFoooJoFAAoJKFDDDJKoGHIoKoGHIEE', 20, 'hard'),
    ('oGHJBBEGHJKLEAAoKLFoICCMFoIooMFoDDDM', 24, 'hard'),
    ('FoBBKLFooJKLAAoJKMCCCooMGHIoDDGHIEEo', 21, 'hard'),
    ('FoHBBoFoHCCCAAoIoJoDDIoJGooIoKGEEEoK', 25, 'hard'),
    ('BBBJoMCCIJLMAAIoLNDDoooNHooKEEHFFKGG', 25, 'hard'),
    ('oBBIoLCCCIKLAAHoKLDDHoooGooJEEGooJFF', 24, 'hard'),
    ('EoFBBBEoFGIJEAAGIJoCCCIJoooHoooooHDD', 22, 'hard'),
    ('GBBCCoGoooKLGAAoKLDDDoKLoHIJEEoHIJFF', 19, 'hard'),
    ('oBBIKoCCCIKLAAHoKLDDHoooGooJEEGooJFF', 24, 'hard'),
    ('FooBBBFoGIoJAAGIoJooHCCKooHDDKooEEEK', 21, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKMFFFoKM', 23, 'hard'),
    ('ooBBBMooKCCMAAKooMJDDEEoJFFLGGHHHLII', 19, 'hard'),
    ('oBBCCKooDDDKoAAIJLoEEIJLGoHFFFGoHooo', 21, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEooLoooFFo', 20, 'hard'),
    ('FGHBBLFGHJKLFAAJKLCCCoooooIoDDEEIooo', 20, 'hard'),
    ('ooBBBJoooIoJFAAIooFGHIoKFGHCCKDDDoEE', 25, 'hard'),
    ('BBBIoKCCCIoKAAHJoKDDHJooGoooEEGoooFF', 23, 'hard'),
    ('BBJooLGoJCCLGAAKoMDDDKoMHIEEooHIFFFo', 25, 'hard'),
    ('GIJoBBGIJCCoHAAKLMHooKLMHoDDDNEEEFFN', 25, 'hard'),
    ('BBBIoLCCCIKLAAHJKLDDHJooGoooEEGoooFF', 24, 'hard'),
    ('FoGBBBFoGIJKAAoIJKooHCCLooHDDLooEEEL', 23, 'hard'),
    ('oBBIKoCCCIKoAAHoKoDDHoooGEEJooGFFJoo', 19, 'hard'),
    ('BBCCKoGDDoKoGAAoKLGoEEELoHIJoLoHIJFF', 25, 'hard'),
    ('oFoBBBoFGooJooGAAJCCoDDJooHIEEooHIoo', 24, 'hard'),
    ('BBCCCMDDJKoMAAJKoMEEFFooHIooLoHIGGLo', 20, 'hard'),
    ('HBBCCLHoDDDLoAAJKMoEEJKMooIFFFooIGGo', 22, 'hard'),
    ('HBBBCCHIJDDLHIJAALoEEEoLoooKFFoooKGG', 24, 'hard'),
    ('ooHIBBooHIJLFAAoJLFGooKMFGCCKMDDEEEM', 19, 'hard'),
    ('BBIJCCooIJoLAAIKoLHDDKEEHoooFFoooGGG', 25, 'hard'),
    ('BBBIoLooHIKLAAHoKLoCCCooGDDJooGEEJFF', 24, 'hard'),
    ('FoBBIoFCCHIoAAGHJKDDGHJKEEEooKoooooo', 19, 'hard'),
    ('BBCCKoHDDJKLHAAJKLHEEEooooIoooFFIoGG', 19, 'hard'),
    ('oBBJCCoDDJKLoAAoKLHoIEEEHoIFFMHGGooM', 22, 'hard'),
    ('GBBKMNGooKMNHooAANHIJLCCHIJLDDoEEEFF', 25, 'hard'),
    ('BBCCKoGoDDKLGAAoKLGoEEEooHIJoooHIJFF', 25, 'hard'),
    ('oBBBCCHIJDDLHIJAALHEEEoLoooKFFoooKGG', 23, 'hard'),
    ('BBBoKooCCIKoAAHILoDDHJLoGooJEEGooFFo', 25, 'hard'),
    ('BBBHJoooGHJKAAGIJKCCCIooFDDoooFEEooo', 24, 'hard'),
    ('BBoooLGoJCCLGoJAAMDDDKoMHIoKEEHIFFFo', 21, 'hard'),
    ('oBBBCCoooDDDAAIJoLEEIJoLHFFoKMHGGGKM', 23, 'hard'),
    ('BBCCCMDDJooMAAJooMEEoKFFHIoKLoHIGGLo', 22, 'hard'),
    ('oBBCCoGDDoKLGAAoKLGEEEKLoHIJFFoHIJoo', 21, 'hard'),
    ('oBBBLoCCJKLMAAJKLMHIooDDHIooEEooFFGG', 21, 'hard'),
    ('oooHJKBBBHJKAAGIJKCCGIooFoooDDFoooEE', 22, 'hard'),
    ('BBBCCLDDooKLAAooKMIooEEMIoJFFMGGJHHH', 22, 'hard'),
    ('FoBBBoFoGIJKAAGIJKooHCCLooHDDLooEEEL', 21, 'hard'),
    ('GBBCCoGooIJKGAAIJKDDDoJoooHoooEEHoFF', 23, 'hard'),
    ('BBCCLMIDDKLMIAAKLMIooEEEooJoFFGGJHHo', 19, 'hard'),
    ('HoooBBHCCJLoAAIJLoDDIKEEFFFKoooooGGo', 20, 'hard'),
    ('BBBJLMCCoJLMAAIKLoDDIKooHoooEEHFFoGG', 24, 'hard'),
    ('BBBCCLooDDKLAAIJKMEEIJKMHooFFMHooGGG', 24, 'hard'),
    ('HBBCCLHooJKLHAAJKLoDDDKoooIoEEFFIGGo', 23, 'hard'),
    ('BBCCJoFoooJoFAAoJKFDDDoKoGHIEEoGHIoo', 23, 'hard'),
    ('HBBCCKHoDDDKAAIJoLEEIJoLoooFFFoooGGo', 24, 'hard'),
    ('GIJoBBGIJoCCHAAKoLHooKoLHoDDDMEEEFFM', 23, 'hard'),
    ('GHIKBBGHIKLMGoAALMooJCCNooJDDNEEFFFN', 21, 'hard'),
    ('BBBoJLCCCIJLAAHIKMDDHIKMGoooEEGFFooo', 21, 'hard'),
    ('BBoCCoIDDKLoIAAKLoIEEELoooJoFFGGJoHH', 21, 'hard'),
    ('BBBooMCCoooMAAIJLMDDIJLoHEEKLoHFFKGG', 21, 'hard'),
    ('GBBIooGCCIooAAHoKLDDHoKLEEEJKMoFFJoM', 24, 'hard'),
    ('GoJKBBGoJKCCHAAoLMHIooLMHIDDDNEEEFFN', 20, 'hard'),
    ('GBBIKMGCCIKMAAHJLoDDHJLoEEEooNFFFooN', 20, 'hard'),
    ('BBBCCMIJKDDMIJKAAMIoEEFFoooLGGoooLHH', 25, 'hard'),
    ('BBBKCCDDoKLooAAKLMIooEEMIoJFFNGGJHHN', 20, 'hard'),
    ('GIJKBBGIJKCCHoAALMHoooLMHoDDDNEEEFFN', 22, 'hard'),
    ('oBBBLoCCJKLMAAJKLMooooDDHIooEEHIFFGG', 23, 'hard'),
    ('ooooBBooGIJKAAGIJKCCHIDDFoHooLFoEEEL', 19, 'hard'),
    ('GooBBNGooKMNAAoKMNHIJLCCHIJLDDHEEEFF', 20, 'hard'),
    ('BBoCCKooDDDKAAoJoLoEEJoLHoIFFFHoIGGG', 19, 'hard'),
    ('ooBBBJooGooJAAGooJoFHCCooFHIDDEEEIoo', 24, 'hard'),
    ('oFBBBJoFGoIJAAGoIoooHCCKooHDDKooEEEK', 19, 'hard'),
    ('GoJKBBGoJKCCHAAooLHIoooLHIDDDMEEFFFM', 19, 'hard'),
    ('BBBoooooHIoKAAHIoKoCCCoKGDDJooGEEJFF', 21, 'hard'),
    ('oooHJoBBBHJoAAGIJoCCGIooFDDoooFoooEE', 20, 'hard'),
    ('oHIBBMoHIoLMGAAKLNGCCKoNGoJDDoEEJoFF', 19, 'hard'),
    ('FooBBBFoHooKAAHooKoGICCKoGIJDDEEEJoo', 22, 'hard'),
    ('BBBoJoCCCIJLAAHIKLDDHIKLGoooEEGFFooo', 19, 'hard'),
    ('ooBBBLooCCKLAAIJKMGHIJKMGHooDDGEEFFo', 25, 'hard'),
    ('HBBCCoHDDoKLHAAoKLoEEEKoooIJFFGGIJoo', 22, 'hard'),
    ('HBBCCoHDDJKoHAAJKooEEEKoooIoooFFIoGG', 22, 'hard'),
    ('BBBCCLDDIJKLAAIJKoEEEoooHFFooMHGGooM', 23, 'hard'),
    ('FBBIKLFooIKLFooAALoGHJCCoGHJDDoEEEoo', 24, 'hard'),
    ('GoBBooGCCoooAAHIJLDDHIJLEEEIKLFFFoKo', 24, 'hard'),
    ('GBBoooGCCoooAAHIKMDDHIKMEEEJLNFFFJLN', 25, 'hard'),
    ('HBBJCCHDDJKLHAAoKLooIEEEooIFFMGGoooM', 24, 'hard'),
    ('HBBoooHCCJLoAAIJLoDDIKEEFFFKoooooGGG', 19, 'hard'),
    ('oooBBBoooCCLAAIJKLDDIJKLGHooKoGHEEFF', 23, 'hard'),
    ('GIJBBoGIJCCoHAAKoLHooKoLHoDDDMEEEFFM', 25, 'hard'),
    ('BBICCLooIDDLAAoooMHooEEMHoJKFFHoJKGG', 22, 'hard'),
    ('GBBCCoGooIJKGAAIJKoDDDJoooHoooEEHoFF', 22, 'hard'),
    ('HBBCCoHoooKLHAAoKLDDDoKoooIJEEFFIJGG', 25, 'hard'),
    ('GIJKBBGIJKCCHAAooLHooooLHoDDDMEEFFFM', 22, 'hard'),
    ('HBBCCoHDDoKLHAAoKLEEEoKoooIJFFGGIJoo', 21, 'hard'),
    ('BBBCCMDDEEEMAAKLoMJoKLFFJGGoooHHooII', 21, 'hard'),
    ('BBoCCCGooooJGAAooJDDHEEJooHIFFooHIoo', 23, 'hard'),
    ('GIJKBBGIJKCCHAAoLMHoooLMHoDDDNEEEFFN', 23, 'hard'),
    ('BBCCCoGooooJGAAooJDDHEEJooHIFFooHIoo', 22, 'hard'),
    ('oBBBLoCCJKLoAAJKLoHIooDDHIooEEooFFGG', 20, 'hard'),
    ('HBBCCoHDDDKLAAooKLEEooKMoIJFFMoIJGGG', 25, 'hard'),
    ('FGHBBLFGHoKLFoAAKLooICCCooIJDDEEoJoo', 24, 'hard'),
    ('BBCCKoGoDDKoGoAAKoGoEEEooHIJoooHIJFF', 25, 'hard'),
    ('BBBIKMoCCIKMAAHJLNDDHJLNGEEooNGFFooo', 24, 'hard'),
    ('oBBCCoGoooKoGAAoKoGDDDKooHIJEEoHIJFF', 19, 'hard'),
    ('HBBCCoHDDDKLoAAoKLEEooKMoIJFFMoIJGGG', 24, 'hard'),
    ('GBBIKoGCCIKoAAHJLMDDHJLMEEEooMoooFFF', 20, 'hard'),
    ('HBBCCLHooJKLHAAJKLDDDoKoooIoEEFFIoGG', 25, 'hard'),
    ('BBBoKooCCIKoAAHILoDDHJLoGooJEEGFFooo', 24, 'hard'),
    ('GBBIooGCCIooAAHoKLDDHoKLEEEJKMFFFJoM', 24, 'hard'),
    ('EoHIBBEoHIKLAAooKLFGCCKMFGoJoMFooJDD', 24, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKMFFooKM', 22, 'hard'),
    ('BBCCKoGoooKoGAAoKoGoDDDooHIJEEoHIJFF', 23, 'hard'),
    ('BBBIoLCCCIKLAAHJKLDDHJooGEEoooGFFooo', 22, 'hard'),
    ('ooHBBBCCHIooAAHIoKGooDDKGooJoKoEEJFF', 25, 'hard'),
    ('oHIBBMoHIoLMGAAoLNGoJCCNGoJKDDEEoKFF', 23, 'hard'),
    ('BBoCCMIDDKLMIAAKLMIEEELoooJoFFGGJHHo', 22, 'hard'),
    ('BBBJLMCCIJLMAAIKooDDoKEEHFFooNHGGooN', 24, 'hard'),
    ('HBBCCoHooJKLHAAJKLoDDDKoooIoEEFFIoGG', 23, 'hard'),
    ('BBBoJoCCCoJLAAoIKLoDDIKLGoHIEEGoHFFo', 23, 'hard'),
    ('BBBIKoCCCIKLAAHJKLDDHJooGoooEEGoooFF', 24, 'hard'),
    ('GBBIooGCCIooAAHJKLDDHJKLEEEoKMFFFooM', 23, 'hard'),
    ('BBBCCLHoDDKLHAAJKMoEEJKMooIFFMooIGGG', 20, 'hard'),
    ('oBBCCoFoooJKFAAoJKFDDDJKoGHIEEoGHIoo', 20, 'hard'),
    ('HBBJCCHDDJKLHAAoKLoooEEEooIFFMGGIooM', 25, 'hard'),
    ('BBBoJoooGHJoAAGHJooCCCooFDDIooFEEIoo', 20, 'hard'),
    ('GIJoBBGIJCCoHAAKoLHooKoLHoDDDMEEFFFM', 24, 'hard'),
    ('BBBIKoCCCIKoAAHoKoDDHoooGooJEEGooJFF', 24, 'hard'),
    ('BBJCCMIoJDDMIAAooNIooEENooKLFFGGKLHH', 21, 'hard'),
    ('BBHCCCGoHJKLGAAJKLDDoEELooIoooooIoFF', 19, 'hard'),
    ('GBBCCKGoooJKGAAoJKDDDoJoooHIooEEHIFF', 25, 'hard'),
    ('BBoCCKDDoooKAAHooLGoHEELGoIJFFGoIJoo', 23, 'hard'),
    ('IBBCCoIDDoLoIAAoLoEEEoLoooJKFFGGJKHH', 25, 'hard'),
    ('BBooCCoooIoKAAoIoKDDHJoKGoHJEEGoHFFF', 20, 'hard'),
    ('oBBCCoHooJKoHAAJKoHDDDKoooIoEEFFIoGG', 21, 'hard'),
    ('ooHoBBEoHJKLEAAJKLFoICCMFGIooMFGDDDM', 20, 'hard'),
    ('oBBCCoHooJKLHAAJKLHDDDKoooIoEEFFIoGG', 22, 'hard'),
    ('BBBKCCDDJKLoAAJKLoEEooFFIooGGMIooHHM', 22, 'hard'),
    ('GoHBBoGoHIoKAAHIoKCCCooKoooJDDEEoJFF', 21, 'hard'),
    ('oBBIKLCCCIKLAAooKLDDooooGoHJEEGoHJFF', 25, 'hard'),
    ('ooBBBKCCHJoKAAHJoKooooDDGoIoEEGoIFFF', 19, 'hard'),
    ('oooBBBooooCCAAHIoKDDHIoKGoHJoKGEEJFF', 20, 'hard'),
    ('BBooLMooJoLMooJAAMHICCDDHIoKEEHFFKGG', 20, 'hard'),
    ('HBBCCoHDDJKLHAAJKLoEEEKoooIoFFGGIooo', 19, 'hard'),
    ('BBBIKLoooIKLAAHooMCCHJoMGDDJooGEEFFF', 19, 'hard'),
    ('GBBCCoGoooJKGAAoJKoDDDJoooHIEEFFHIoo', 21, 'hard'),
    ('GBBIooGCCIooAAHJKMDDHJKMEEEoLNoFFoLN', 23, 'hard'),
    ('oGHoBBoGHIJLFAAIJLFoooKMFoCCKMDDEEEM', 23, 'hard'),
    ('BBoCCKDDoJoKoAAJoLEEIooLHoIFFoHoIGGG', 19, 'hard'),
    ('BBBoooCCooooAAIJLoDDIJLoHEEKLoHFFKGG', 19, 'hard'),
    ('oBBIKLoooIKLAAoooLFGHJCCFGHJDDFEEEoo', 22, 'hard'),
    ('BBBIKMoCCIKMAAHJLoDDHJLoGoooEEGFFooo', 23, 'hard'),
    ('oHIBBMoHIoLMGAAoLNGooCCNGoJKDDEEJKFF', 22, 'hard'),
    ('FoBBIoFCCHIoAAGHoKDDGHoKEEEoJKooooJo', 20, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEoooFFoooo', 19, 'hard'),
    ('FBBooJFoCCCJAAHIooDDHIoKGooIoKGEEEoo', 19, 'hard'),
    ('ooBBBMooKCCMAAKLoMJDDLEEJFFoGGoHHHII', 22, 'hard'),
    ('ooBBBKooICCKAAIJoLDDIJoLHEEEooHFFGGG', 25, 'hard'),
    ('oooHJoBBBHJKAAGIJKCCGIooFDDoooFoooEE', 21, 'hard'),
    ('BBBHoJooGHoJAAGooJCCCoooFDDIooFEEIoo', 22, 'hard'),
    ('oBBBLoCCJKLMAAJKLMHIooDDHIooEEFFooGG', 20, 'hard'),
    ('BBCCCMoooDDMoooAAMEEJKFFHIJKLoHIGGLo', 25, 'hard'),
    ('BBHCCKooHIoKAAHIoKGDDJooGooJEEoooFFF', 25, 'hard'),
    ('ooBBBMoooCCMAAJKLNDDJKLNIEEFFNIGGGHH', 23, 'hard'),
    ('BBIJooooIJCCAAIJoKoooDDKHooEELHFFGGL', 25, 'hard'),
    ('GoIBBKGoICCKoooAAKHooJDDHEEJooFFFJoo', 22, 'hard'),
    ('GHIBBoGHIKLMGAAKLMooJCCNooJDDNEEFFFN', 24, 'hard'),
    ('ooBBBKoooCCKAAIJoLDDIJoLHoIEEEHFFGGo', 23, 'hard'),
    ('oooHJoBBBHJKAAooJKooooCCFoGIDDFoGIEE', 25, 'hard'),
    ('GBBIooGCCIooAAHoKMDDHoKMEEEJLMFFFJLo', 24, 'hard'),
    ('HBBCCoHDDKLMHAAKLMEEEoLMoIJoFFoIJoGG', 19, 'hard'),
    ('ooBBBMCCoooMAAJKLNDDJKLNIEEFFNIGGGHH', 24, 'hard'),
    ('HBBCCoHDDJKLHAAJKLEEEoKoooIoooFFIoGG', 24, 'hard'),
    ('HBBCCKHoDDDKAAoJoLEEoJoLooIFFFooIGGG', 24, 'hard'),
    ('BBoCCoooooJKGAAoJKGDDDJoGoHIEEFFHIoo', 23, 'hard'),
    ('HBBCCLHoDDDLoAAJKMEEoJKMooIFFFooIGGG', 24, 'hard'),
    ('GoJKBBGoJKCCHoAALMHIooLMHIDDDNEEEFFN', 21, 'hard'),
    ('GoHBBLGoHIKLAAHIKLoooCCCoooJDDEEoJFF', 24, 'hard'),
    ('HBBCCoHDDoLoHAAoLMEEEoLMoIJKFFoIJKGG', 20, 'hard'),
    ('BBoCCoHooJKoHAAJKoHDDDKoooIoEEFFIoGG', 20, 'hard'),
    ('ooBBBLooJCCLAAJoKMDDJoKMHIoEEEHIFFGG', 25, 'hard'),
    ('GIJoBBGIJoCCHAAKLMHooKLMHoDDDNEEFFFN', 24, 'hard'),
    ('BBCCCoHooooKHAAooKDDIEEKooIJFFooIJGG', 23, 'hard'),
    ('FoBBIoFCCHIoAAGHJKDDGHJKEEEooLoooooL', 20, 'hard'),
    ('oBBCCoGDDoKoGAAoKLGEEEKLoHIJFFoHIJoo', 21, 'hard'),
    ('oBBCCLHooJKLHAAJKLHDDDKoooIoEEFFIGGo', 22, 'hard'),
    ('BBJoLMooJoLMoooAAMHICCDDHIoKEEHFFKGG', 19, 'hard'),
    ('BBBJoLCCIJoLAAIooMoooDDMHooKEEHFFKGG', 25, 'hard'),
    ('BBBooLCCIJoLAAIJoLDDooooHooKEEHFFKGG', 25, 'hard'),
    ('GBBIooGCCIooAAHJKMDDHJKMEEEoLNFFFoLN', 23, 'hard'),
    ('BBBIKooCCIKoAAHoLoDDHoLoGEEJooGFFJoo', 20, 'hard'),
    ('GoBBooGooICCAAHIJLDDHIJLEEEoKoFFooKo', 24, 'hard'),
    ('BBBIKoCCCIKLAAHoKLDDHoooGEEJooGFFJoo', 21, 'hard'),
    ('oBBBLoCCJKLoAAJKLoHoooDDHIooEEoIFFGG', 21, 'hard'),
    ('BBoCCCDDooooAAJKoLEEJKoLIoJFFMIGGHHM', 23, 'hard'),
    ('BBBCCMDDoEEMoAAKLNFFoKLNIoJGGNIoJHHH', 23, 'hard'),
    ('BBoCCoHDDoLMHAAoLMHEEELMoIJKFFoIJKGG', 23, 'hard'),
    ('BBCCJKooooJKGAAoJKGDDDooGoHIEEFFHIoo', 25, 'hard'),
    ('GHBBBLGHIooLAAIooLCCoDDoooJKEEooJKFF', 20, 'hard'),
    ('oGBBBKoGHooKAAHooKCCooDDooIJEEooIJFF', 19, 'hard'),
    ('GBBIKoGCCIKoAAHJLMDDHJLMEEEooMFFFooo', 21, 'hard'),
    ('FoBBBoFoHooKAAHooKoGICCKoGIJDDEEEJoo', 23, 'hard'),
    ('oBBIoKCCCIoKAAHooKDDHoooGEEJooGFFJoo', 19, 'hard'),
    ('BBBHJoooGHJoAAGIJoCCCIooFoooDDFEEooo', 24, 'hard'),
    ('BBBHJKooGHJKAAGoJKoCCCooFDDIooFEEIoo', 24, 'hard'),
    ('BBoCCCoDDDKLAAooKLoEEoKMHIJFFMHIJGGG', 21, 'hard'),
    ('BBICCLooIDDLAAoKoMHEEKoMHoJFFoHoJoGG', 19, 'hard'),
    ('GIJKBBGIJKCCHoAAoLHooooLHoDDDMEEEFFM', 21, 'hard'),
    ('GoBBooGoooCCAAHIJoDDHIJoEEEIKoFFooKo', 22, 'hard'),
    ('HooJBBHCCJLMAAIoLMDDIKEEFFFKoooooGGG', 22, 'hard'),
    ('BBBCCLHIJooLHIJAALHoDDEEoooKFFoooKGG', 24, 'hard'),
    ('FoBBBKFoHooKAAHooKoGIoCCoGIJDDEEEJoo', 25, 'hard'),
    ('oBBCCKooDDDKAAoJoLoEEJoLHoIFFFHoIGGo', 19, 'hard'),
    ('GoHoBBGoHIoKAAHIoKCCCooKoooJDDEEoJFF', 20, 'hard'),
    ('FGHBBBFGHoKLAAooKLooICCLooIJDDEEEJoo', 19, 'hard'),
    ('BBCCooFoooJoFAAoJKFDDDJKoGHIoooGHIEE', 22, 'hard'),
    ('ooBBBMooKCCMAAKooMJDDoEEJFFLGGHHHLII', 20, 'hard'),
    ('BBBIoLCCHIoLAAHJKMoDDJKMGoooEEGooFFF', 25, 'hard'),
    ('BBBJLMCCoJLMAAIoLoDDIoooHooKEEHFFKGG', 25, 'hard'),
    ('BBCCooIDDKLoIAAKLoIEEELoooJoFFGGJoHH', 20, 'hard'),
    ('BBBooMoCCooMAAHIKNDDHIKNGEEJLoGFFJLo', 20, 'hard'),
    ('BBCCooGDDoKoGAAoKoGEEEKooHIJoooHIJFF', 21, 'hard'),
    ('BBBoooooGHJoAAGHJooCCCJoFDDIooFEEIoo', 19, 'hard'),
    ('BBBCCLIDDoKLIAAoKMoooEEMooJFFMGGJHHH', 19, 'hard'),
    ('BBCCLMIoooLMIooAAMDDJKEEooJKFFoGGGHH', 23, 'hard'),
    ('BBBoJooCCCJoAAoIKLoDDIKLGoHIEEGoHFFo', 24, 'hard'),
    ('BBBKCCoDDKLMoAAKLMEEooFFIoJGGNIoJHHN', 21, 'hard'),
    ('BBCCoKooooJKGAAoJKGDDDJoGoHIEEFFHIoo', 24, 'hard'),
    ('oBBoKMCCCoKMAAHIoNDDHIoNGEEJLoGFFJLo', 23, 'hard'),
    ('IBBCCCIoKLDDAAKLoMEEoooMJooFFMJGGHHH', 20, 'hard'),
    ('FoGBBBFoGoIJAAooIJooHCCKooHDDKooEEEK', 22, 'hard'),
    ('EoHIBBEGHIKLoGAAKLFCCJKMFooJoMFoooDD', 20, 'hard'),
    ('oBBBCCooDDDoAAIJKLEEIJKLHFFooMHGGGoM', 21, 'hard'),
    ('GoBBBoGoJooLooJAALHCCDDLHIoKEEHIoKFF', 23, 'hard'),
    ('HBBCCLHDDJKLHAAJKLEEEoKoooIoooFFIoGG', 25, 'hard'),
    ('GoBBooGoooCCAAHIJLDDHIJLEEEIKoFFooKo', 23, 'hard'),
    ('FGBBBJFGoIoJAAHIoKooHCCKooHDDKoooEEE', 19, 'hard'),
    ('GoBBJLGCCIJLAAHIKMDDHIKMoooEEEFFFooo', 19, 'hard'),
    ('oBBBLoCCJKLoAAJKLoHIooDDHIooEEFFooGG', 19, 'hard'),
    ('ooBBBKoooCCKAAHooKooHJDDGoIJEEGoIFFF', 22, 'hard'),
    ('FoGBBoFoGHCCAAoHIoDDoHIooEEEJoooooJo', 25, 'hard'),
    ('FGBBBoFGHooKooHAAKCCoDDKooIJEEooIJoo', 25, 'hard'),
    ('BBBHoJooGHoJAAGIoJCCCIooFDDoooFEEooo', 23, 'hard'),
    ('GBBCCJGoDDDJAAHIoKEEHIoKoooFFFoooooo', 24, 'hard'),
    ('oooBBBooGHJKAAGHJKoCCCJKFDDIooFEEIoo', 20, 'hard'),
    ('IBBCCCIDDKLMoAAKLMoEEFFMooJGGoooJHHH', 22, 'hard'),
    ('ooHBBBooHoKLooAAKLFGICCLFGIJDDEEEJoo', 22, 'hard'),
    ('BBBIoKCCHIoKAAHJoLoDDJoLGoooEEGooFFF', 24, 'hard'),
    ('FGBBBKFGoIJKAAHIJLooHCCLooHDDLoooEEE', 20, 'hard'),
    ('GBBCCKGooIJKGAAIJKoDDDJoooHoooEEHFFo', 22, 'hard'),
    ('GooIBBGCCIKLAAHoKLDDHJEEFFFJoooooooo', 22, 'hard'),
    ('BBBIoKCCHIoKAAHoooGDDoooGEEJoLFFFJoL', 19, 'hard'),
    ('oGBBBKoGoIJKoAAIJLooHCCLFoHDDLFoHEEE', 23, 'hard'),
    ('oBBCCCIoDDKLIAAoKLEEJFFMooJGGMooHHHM', 25, 'hard'),
    ('oooBBBCCCoooAAHIKMDDHIKMGEEJLNGFFJLN', 19, 'hard'),
    ('BBCCLoHDDoLoHAAoLoHoEEEooIJKFFoIJKGG', 24, 'hard'),
    ('BBBCCMIoKDDMIoKAAMIoEEFFoJoLGGoJoLHH', 24, 'hard'),
    ('BBBIKoCCCIKLAAHoKLDDHoooGooJEEGooJFF', 25, 'hard'),
    ('ooGBBBooGoIJooAAIJooHCCKoFHDDKoFEEEK', 24, 'hard'),
    ('BBBIKLoCCIKLAAHJKMDDHJoMGoooEEGooFFo', 24, 'hard'),
    ('BBCCCMDDJKoMAAJKoMEEooFFHIooLoHIGGLo', 21, 'hard'),
    ('ooBBBLCCJoKLAAJoKoDDJooMHIEEEMHIFFGG', 19, 'hard'),
    ('GoBBooGoooCCAAHIJLDDHIJLEEEIKMFFooKM', 25, 'hard'),
    ('BBBoooCCCooLAAHIoLDDHIKoGEEJKoGFFJKo', 19, 'hard'),
    ('oGHBBLoGHIJLFAAIJoFoooKMFoCCKMDDDEEM', 25, 'hard'),
    ('BBBoCCIoKDDMIoKAAMIEEFFMoJoLGGoJoLHH', 20, 'hard'),
    ('oBBBKLCCIJKLAAIJKLooooDDoHEEoooHFFGG', 22, 'hard'),
    ('BBCCKoGoooKoGoAAKoGoDDDooHIJEEoHIJFF', 24, 'hard'),
    ('BBBIoLCCHIoLAAHJKMGDDJKMGEEoooFFFooo', 22, 'hard'),
    ('GoIBBKGoICCKHooAAKHooJDDEEoJooFFFJoo', 24, 'hard'),
    ('ooIJBBooIJCCAAIJoKDDoooKHooEELHFFGGL', 19, 'hard'),
    ('FGHBBLFGHoKLFAAoKLCCCoooooIJDDEEIJoo', 21, 'hard'),
    ('oooBBoCCCoooAAHIKMDDHIKMGEEJLNGFFJLN', 19, 'hard'),
    ('GBBCCoGDDoKLGAAoKLoEEEKLoHIJFFoHIJoo', 20, 'hard'),
    ('BBBooMoooCCMAAHIKNDDHIKNGEEJLNGFFJLo', 19, 'hard'),
    ('BBooJLCCCoJLAAoIKMDDoIKMGoHIEEGoHFFo', 24, 'hard'),
    ('BBoCCoGDDoKLGAAoKLGEEEKooHIJoooHIJFF', 21, 'hard'),
    ('oGHIBBoGHIJLFAAoJLFoooKMFoCCKMDDEEEM', 22, 'hard'),
    ('oBBCCLHDDJKLHAAJKLHEEEKoooIoooFFIGGo', 22, 'hard'),
    ('BBoCCoHooJKLHAAJKLHDDDKoooIoEEFFIoGG', 21, 'hard'),
    ('BBBIKooCCIKoAAHJLoDDHJLoGEEoooGFFooo', 21, 'hard'),
    ('BBCCLoIDDKLoIAAKLoIEEEooooJoFFGGJoHH', 19, 'hard'),
    ('oooBBBooFGIJAAFGIJECCCIJEooHooEooHDD', 25, 'hard'),
    ('HBBCCoHoooKoHAAoKoDDDoKoooIJEEFFIJGG', 24, 'hard'),
    ('BBCCJoFoooJoFAAoJKFDDDoKoGHIoooGHIEE', 23, 'hard'),
    ('ooHIBBooHIJLFAAoJLFGooKMFGCCKMDDDEEM', 19, 'hard'),
    ('BBBIoLooHIKLAAHoKLCCCoooGDDJooGEEJFF', 25, 'hard'),
    ('ooBBBKoooCCKAAIoJLDDIoJLHoIEEEHFFGGo', 23, 'hard'),
    ('GBBIooGCCIKoAAHJKLDDHJKLEEEooMoooFFM', 21, 'hard'),
    ('BBCCLoIDDKLMIAAKLMIEEEooooJoFFGGJoHH', 20, 'hard'),
    ('ooIBBMooIoLMGoAALNGHJCCNGHJKDDEEoKFF', 25, 'hard'),
    ('FoHBBoFoHCCCAAoIoJDDoIoJGooIoKGEEEoK', 24, 'hard'),
    ('BBCCLMIoJoLMIoJAAMDDoKEEoooKFFoGGGHH', 22, 'hard'),
    ('BBBIKLCCCIKLAAHJKLDDHJooGoooEEGoooFF', 24, 'hard'),
    ('BBBJLMCCoJLMAAIoLoDDIoooHEEKooHFFKGG', 22, 'hard'),
    ('GBBCCoGDDoKoGAAoKLoEEEKLoHIJoLoHIJFF', 20, 'hard'),
    ('GBBCCJGoDDDJAAoIoKEEoIoKooHFFFooHooo', 23, 'hard'),
    ('EoFoBBEoFGIJAAFGIJCCCooJoooHDDoooHoo', 19, 'hard'),
    ('GoBBooGCCoooAAHIJLDDHIJLEEEIKMFFFoKM', 25, 'hard'),
    ('ooBBBoooHoKLAAHoKLFGICCLFGIJDDEEEJoo', 25, 'hard'),
    ('oBBBKLCCIJKLAAIJKLoHooDDoHooEEFFooGG', 19, 'hard'),
    ('EoHoBBEoHIKLAAoIKLFGCCKMFGoJoMFooJDD', 25, 'hard'),
    ('BBBCCLooDDKLAAoJKMEEoJKMHoIFFMHoIGGG', 23, 'hard'),
    ('BBBoKMoCCoKMAAHIoNDDHIoNGEEJLoGFFJLo', 21, 'hard'),
    ('GBBCCoGoooJoGAAoJooDDDJoooHIooEEHIFF', 24, 'hard'),
    ('BBCCCKHooJoKHAAJoKDDIEEoooIoFFooIoGG', 19, 'hard'),
    ('FoHBBLFoHoKLFoAAKLoGICCCoGIJDDEEoJoo', 25, 'hard'),
    ('BBCCJoFoooJoFoAAJKFoDDDKoGHIoooGHIEE', 25, 'hard'),
    ('BBJCCCDDJKoLAAJKoLooooEEIooFFMIGGHHM', 19, 'hard'),
    ('oooHoJBBBHoJAAGooJCCGoooFooIDDFooIEE', 22, 'hard'),
    ('BBoCCLooDDDLAAoJKMoEEJKMHoIFFFHoIGGo', 19, 'hard'),
    ('BBoCCoGooIJKGAAIJKGDDDJoooHoooEEHoFF', 20, 'hard'),
    ('GHIBBBGHIooLoooAALCCoDDLooJKEEooJKFF', 24, 'hard'),
    ('BBoCCKooooJKGAAoJKGDDDJoGoHIEEFFHIoo', 23, 'hard'),
    ('GBBIKoGCCIKoAAHJLMDDHJLMEEEooNoooFFN', 20, 'hard'),
    ('BBICCLooIDDLAAoKoMHEEKoMHoJoFFHoJoGG', 20, 'hard'),
    ('ooBBBLoooCCLAAIJKMDDIJKMHoIEEEHFFGGG', 25, 'hard'),
    ('FoBBIoFCCHIoAAGHoKDDGHoKEEEoJLooooJL', 21, 'hard'),
    ('BBCCKoGoooKoGAAoKoGDDDoooHIJEEoHIJFF', 22, 'hard'),
    ('ooBBBMoooCCMAAKLoMDDKLEEJFFoGGJHHHII', 25, 'hard'),
    ('BBBHJoooGHJoAAGoJoCCCoooFooIDDFEEIoo', 25, 'hard'),
    ('HBBoooHCCJLMAAIJLMDDIKEEFFFKoooooGGo', 20, 'hard'),
    ('BBBCCLDDJoKLAAJoKMIooEEMIooFFMoGGHHH', 24, 'hard'),
    ('oBBoKLoooIKLAAoIoLFGHJCCFGHJDDFEEEoo', 21, 'hard'),
    ('oBBCCooDDoKoHAAoKoHEEEKoHoIJFFGGIJoo', 22, 'hard'),
    ('GoHIBBGoHIKLAAHoKLCCCooLoooJDDEEoJFF', 20, 'hard'),
    ('BBBJoLCCoJoLAAIooMDDIooMHEEKooHFFKGG', 20, 'hard'),
    ('oBBCCoooooJoGAAoJoGDDDJoGoHIooEEHIFF', 25, 'hard'),
    ('GBBIoLGCCIKLAAHJKoDDHJKoEEEooMoooFFM', 20, 'hard'),
    ('FBBCCoFoooJoFAAoJKoDDDJKoGHIEEoGHIoo', 19, 'hard'),
    ('oHBBBLoHCCKLAAIoKMGoIJKMGooJDDGEEFFo', 19, 'hard'),
    ('ooBBBLCCJoKLAAJoKMDDJooMHIEEEoHIFFGG', 20, 'hard'),
    ('BBBCCoHIJDDLHIJAALHEEEoLoooKFFoooKGG', 21, 'hard'),
    ('BBooJoCCCoJLAAoIKLDDoIKLGoHIEEGoHFFo', 22, 'hard'),
    ('ooBBBLCCJooLAAJoKMDDJoKMHIoEEEHIFFGG', 22, 'hard'),
    ('GBBIoLGCCIKLAAHJKMDDHJKMEEEooooooFFo', 19, 'hard'),
    ('BBCCKLHDDJKLHAAJKLHEEEooooIoooFFIGGo', 19, 'hard'),
    ('oooHJKBBBHJKAAGIJKCCGIooFDDoooFoooEE', 21, 'hard'),
    ('HBBCCoHDDoLoHAAoLMoEEELMoIJKFFoIJKGG', 21, 'hard'),
    ('GBBCCoGDDoKLGAAoKLEEEoKLoHIJFFoHIJoo', 19, 'hard'),
    ('BBoCCKoooIoKAAoIoKDDHJooGoHJEEGoHFFF', 22, 'hard'),
    ('oooHJoBBBHJKAAooJKCCooooFoGIDDFoGIEE', 24, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKoFFooKo', 20, 'hard'),
    ('oBBCCoooooJKGAAoJKGDDDJoGoHIEEFFHIoo', 22, 'hard'),
    ('BBBIKooCCIKoAAHoLoDDHJLoGooJEEGFFooo', 23, 'hard'),
    ('BBCCooFoooJoFAAoJKFDDDJKoGHIoKoGHIEE', 22, 'hard'),
    ('oBBBLMCCJKLMAAJKLMHoooDDHIooEEoIFFGG', 22, 'hard'),
    ('BBCCCMoooDDMAAoooMEEJKFFHIJKLoHIGGLo', 24, 'hard'),
    ('GBBIKMGCCIKMAAHJLoDDHJLoEEEooNoooFFN', 19, 'hard'),
    ('BBoCCooDDDKLAAooKLoEEoKMHIJFFMHIJGGG', 20, 'hard'),
    ('oooHoKBBBHJKAAGIJKCCGIooFDDoooFoooEE', 21, 'hard'),
    ('BBooJoCCCoJoAAHIKLDDHIKLGooIEEGFFooo', 20, 'hard'),
    ('oooBBBCCooooAAIJLMDDIJLMHEEKLMHFFKGG', 19, 'hard'),
    ('BBBIKMoCCIKMAAHJLNDDHJLNGEEooNGooFFo', 25, 'hard'),
    ('oBBCCoGooIJoGAAIJoGDDDJoooHoooEEHoFF', 20, 'hard'),
    ('BBBIKLCCCIKLAAHoKLDDHoooGEEJooGFFJoo', 21, 'hard'),
    ('ooooBBooHJoKAAHJoKCCIJDDGoIEELGoFFFL', 21, 'hard'),
    ('oGBBBKoGoooKFAAoJLFoHIJLFoHICCDDDIEE', 20, 'hard'),
    ('BBCCJoFoooJoFAAoJKFoDDDKoGHIEEoGHIoo', 24, 'hard'),
    ('ooBBBLCCIJKLAAIJKoDDIooMHoEEEMHFFGGo', 19, 'hard'),
    ('GBBCCKGoDDDKAAoIJLEEoIJLooHFFFooHooo', 24, 'hard'),
    ('BBoCCoGoooKoGAAoKLGDDDKLoHIJEEoHIJFF', 22, 'hard'),
    ('oooBBBCCoIooAAHIoKDDHooKGoHJoKGEEJFF', 22, 'hard'),
    ('BBBHJoooGHJKAAGIJKCCCIooFoooDDFEEooo', 25, 'hard'),
    ('GoBBooGCCIooAAHIJLDDHIJLEEEoKoFFFoKo', 22, 'hard'),
    ('BBoCCCoDDKLMAAoKLMoEEFFMIoJGGoIoJHHH', 19, 'hard'),
    ('BBooJooCCCJooAAIKLoDDIKLGoHIEEGoHFFo', 25, 'hard'),
    ('GBBCCoGooIJoGAAIJooDDDJoooHoooEEHoFF', 21, 'hard'),
    ('BBoCCCoooDDKAAoooKEEIJoKHoIJFFHoIGGG', 19, 'hard'),
    ('GoBBJLGCCIJLAAHIKoDDHIKoEEEooMFFoooM', 20, 'hard'),
    ('BBBIoKCCHIoKAAHJoLoDDJoLGEEoooGooFFF', 23, 'hard'),
    ('oGBBBJoGHIoJAAHIoKooHCCKFooDDKFoEEEo', 25, 'hard'),
    ('BBoCCKDDHooKAAHooLGEEooLGoIJFFGoIJoo', 25, 'hard'),
    ('ooHoBBooHoCCAAHIoJDDoIoJGooIoKGEEFFK', 19, 'hard'),
    ('ooBBBLooCCKLAAoJKMGHIJKMGHIoDDGEEFFo', 24, 'hard'),
    ('BBooJooCCCJLoAAIKLoDDIKLGoHIEEGoHFFo', 25, 'hard'),
    ('FBBoooFooCCCAAHIoJDDHIoJGooIoKGEEEoK', 22, 'hard'),
    ('BBBoLMCCooLMAAIJLNDDIJoNHEEKooHFFKGG', 24, 'hard'),
    ('BBBKCCDDoKLooAAKLoEEooFFIoJGGMIoJHHM', 20, 'hard'),
    ('BBBoJLCCCoJLAAHIKMDDHIKMGooIEEGooFFo', 23, 'hard'),
    ('BBBIKLCCCIKLAAHoKLDDHoooGooJEEGooJFF', 25, 'hard'),
    ('BBBIKMoCCIKMAAHJLMDDHJLoGEEoooGFFooo', 22, 'hard'),
    ('BBBIoLCCHIoLAAHooMGDDooMGEEJKoFFFJKo', 20, 'hard'),
    ('BBBCCLoDDJKLoAAJKMoEEJKMHoIFFMHoIGGG', 21, 'hard'),
    ('BBoCCLooDDDLAAoJKMEEoJKMHoIFFFHoIGGG', 19, 'hard'),
    ('IBBCCCIoKLDDAAKLoMJooEEMJooFFMGGoHHH', 23, 'hard'),
    ('BBCCKoGDDoKoGAAoKoGoEEEooHIJoooHIJFF', 23, 'hard'),
    ('ooGBBBooGoJKAAooJKoFHCCKoFHIDDEEEIoo', 22, 'hard'),
    ('BBBJLMCCoJLMAAIoLMDDIoooHEEKooHFFKGG', 23, 'hard'),
    ('FoGBBBFoGIoJAAoIoJooHCCKooHDDKooEEEK', 22, 'hard'),
    ('BBBooKooGHoKAAGHoKoCCCooFDDIJoFEEIJo', 20, 'hard'),
    ('BBBCCLHIJDDLHIJAALHooEEEoooKFFoooKGG', 19, 'hard'),
    ('BBCCoKGooIJKGAAIJKGDDDJoooHoooEEHFFo', 19, 'hard'),
    ('BBBJLMCCIJLMAAIoooDDooEEHFFKoNHGGKoN', 23, 'hard'),
    ('BBBIKoCCCIKoAAHJKoDDHJooGEEoooGoooFF', 22, 'hard'),
    ('BBoCCLooDDDLAAoJKMoEEJKMHoIFFFHoIGGG', 20, 'hard'),
    ('BBCCoLHDDJKLHAAJKLHEEEKoooIoooFFIGGo', 20, 'hard'),
    ('BBJKooHoJKCCHoAALMHIDDLMoIEELNFFGGoN', 23, 'hard'),
    ('BBBooMCCCooMAAHIKNDDHIKNGEEJLoGFFJLo', 22, 'hard'),
    ('BBoCCLHooJKLHAAJKLHDDDKoooIoEEFFIGGo', 21, 'hard'),
    ('ooBBBoooGoJKAAGoJKoFHCCKoFHIDDEEEIoo', 24, 'hard'),
    ('oGHBBLoGHIKLAAHIKLFooJCCFooJDDoooEEE', 22, 'hard'),
    ('GoBBBMGoCCLMAAoKLNDDoKLNHIJoEEHIJoFF', 22, 'hard'),
    ('oBBBLoCCoKLMAAoKLMHIooDDHIJoEEFFJoGG', 19, 'hard'),
    ('oBBCCoGoooKLGAAoKLGDDDKLoHIJEEoHIJFF', 21, 'hard'),
    ('BBBIKoCCCIKLAAHJKLDDHJooGEEoooGFFooo', 22, 'hard'),
    ('GoHBBLGoHJKLGAAJKLCCCoooooIoDDEEIoFF', 19, 'hard'),
    ('BBCCCKHooJoKHAAJoKDDIoEEooIoFFooIoGG', 20, 'hard'),
    ('IBBCCCIoKLDDAAKLoMoooEEMJooFFMJGGHHH', 21, 'hard'),
    ('BBBIoKCCCIoKAAHJoKDDHJooGEEoooGFFooo', 21, 'hard'),
    ('HBBJCCHDDJKLHAAoKLooIEEEooIFFMoGGooM', 23, 'hard'),
    ('BBBIKLoooIKLAAoooMCCHJoMGoHJDDGEEFFF', 23, 'hard'),
    ('oBBIoLCCCIKLAAHoKLDDHoooGEEJooGFFJoo', 20, 'hard'),
    ('BBCCooHDDoLMHAAoLMHEEELMoIJKFFoIJKGG', 24, 'hard'),
    ('BBBIKMoCCIKMAAHoLMDDHJLoGooJEEGFFooo', 24, 'hard'),
    ('BBBKCCDDJKLoAAJKLMIooEEMIooFFNoGGHHN', 23, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEooMFFoooM', 21, 'hard'),
    ('BBBIKoCCCIKoAAooKoDDooooGoHJEEGoHJFF', 25, 'hard'),
    ('oBBCCoIDDKLoIAAKLoIEEELoooJoFFGGJoHH', 22, 'hard'),
    ('BBBCCMIoKDDMIoKAAMIEEoFFoJoLGGoJoLHH', 23, 'hard'),
    ('oBBIKoCCCIKoAAHJKoDDHJooGoooEEGoooFF', 22, 'hard'),
    ('FoGBBJFoGHoJAAGHoJCCCooooooIDDoooIEE', 21, 'hard'),
    ('HBBBCCHIJDDLHIJAALEEEooLoooKFFoooKGG', 25, 'hard'),
    ('BBBIoLCCHIKLAAHoKMGDDooMGEEJooFFoJoo', 21, 'hard'),
    ('BBBJLMCCIJLMAAIKooDDoKEEHFFooNHooGGN', 25, 'hard'),
    ('GIJBBoGIJCCoHAAKoLHooKoLHoDDDMEEFFFM', 25, 'hard'),
    ('BBBKCCDDJKLoAAJKLMoooEEMIFFooNIGGHHN', 25, 'hard'),
    ('oBBIoKCCCIoKAAHJoKDDHJooGEEoooGFFooo', 20, 'hard'),
    ('BBCCLMooJoLMooJAAMDDoKEEIooKFFIGGGHH', 19, 'hard'),
    ('oBBBLoCCJKLMAAJKLMDDooooHIEEooHIFFGG', 25, 'hard'),
    ('GoJoBBGoJoCCHAAKLMHIoKLMHIDDDNEEFFFN', 19, 'hard'),
    ('HBBCCCHDDJKLHAAJKLoEEFFLoIoooooIGGoo', 24, 'hard'),
    ('GooBBoGooICCAAHIJoDDHIJoEEEoKoFFooKo', 24, 'hard'),
    ('FoGBBBFoGoIJoAAoIJooHCCKooHDDKooEEEK', 23, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEooMFFFooM', 22, 'hard'),
    ('BBoCCooDDoKLHAAoKLHEEEKoHoIJFFGGIJoo', 24, 'hard'),
    ('IBBCCCIoDDDoAAJooLooJEELFFFKooGGGKHH', 25, 'hard'),
    ('oBBBLoCCJKLMAAJKLMDDoooMHIooEEHIFFGG', 25, 'hard'),
    ('BBBoKMoCCoKMAAHIoMDDHIooGEEJLoGFFJLo', 19, 'hard'),
    ('GBBoooGCCoooAAHIKMDDHIKMEEEJLMFFFJLo', 25, 'hard'),
    ('EoBBooECCGooAAFGHJooFGHJDDDoIKooooIK', 19, 'hard'),
    ('GIJKBBGIJKCCHAAoLMHoooLMHoDDDNEEFFFN', 23, 'hard'),
    ('FGBBBKFGoIJKAAoIJLooHCCLooHDDLooHEEE', 21, 'hard'),
    ('BBBIKLoCCIKLAAoJKMDDoJoMGoHoEEGoHFFo', 25, 'hard'),
    ('FBBJLMFooJLMGooAAMGHIKCCGHIKDDEEEooo', 25, 'hard'),
    ('oBBBKLCCIJKLAAIJKLoHooDDoHooEEooFFGG', 20, 'hard'),
    ('ooGBBBooGooJooAAoJoFHCCJoFHIDDEEEIoo', 20, 'hard'),
    ('oooIBBooGIJKAAGIJKCCHDDoFoHooLFoEEEL', 21, 'hard'),
    ('HooJBBHCCJLoAAIoLoDDIKEEFFFKoooooGGo', 21, 'hard'),
    ('ooGBBBooGHJKAAoHJKoCCCJKFDDIooFEEIoo', 19, 'hard'),
    ('BBBJoLCCoJoLAAIooLDDIoooHEEKooHFFKGG', 20, 'hard'),
    ('IBBCCMIDDKLMIAAKLMoEEELoooJoFFGGJHHo', 24, 'hard'),
    ('FGBBBoFGHoJKAAHoJKooICCLooIDDLooEEEL', 20, 'hard'),
    ('GBBIooGCCIooAAHoKMDDHoKMEEEJLNFFFJLN', 24, 'hard'),
    ('ooBBBoooGooJAAGooJoFHCCJoFHIDDEEEIoo', 23, 'hard'),
    ('FoBBBoFoGIoJAAGIoJooHCCKooHDDKooEEEK', 20, 'hard'),
    ('BBBooLCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 20, 'hard'),
    ('ooBBBJoooIoJFAAIoKFGHIoKFGHoCCDDDoEE', 23, 'hard'),
    ('GBBoooGCCIKLAAHIKLDDHJEEFFFJoooooooo', 20, 'hard'),
    ('ooIBBBooICCLAAoJKLoDDJKLGHooKoGHEEFF', 25, 'hard'),
    ('BBCCLoIDDKLMIAAKLMIooEEEooJoFFGGJoHH', 19, 'hard'),
    ('BBHCCKooHDDKAAoooLGEEooLGoIJFFGoIJoo', 20, 'hard'),
    ('BBoCCCIoDDKLIAAoKLEEJFFMooJGGMooHHHM', 24, 'hard'),
    ('BBCCJoFoooJoFoAAJKFoDDDKoGHIEEoGHIoo', 25, 'hard'),
    ('BBHCCKooHDDKAAoooLGooEELGoIJFFGoIJoo', 21, 'hard'),
    ('FoBBooFoooCCAAGHIKDDGHIKEEEHJKooooJo', 23, 'hard'),
    ('oBBCCLooDDDLAAoJKMoEEJKMHoIFFFHoIGGG', 21, 'hard'),
    ('EoHIBBEGHIKLoGAAKLFCCJKMFooJoMFDDooo', 19, 'hard'),
    ('EoFBBBEoFGIJEAAGIJCCCoIJoooHoooooHDD', 21, 'hard'),
    ('FGoBBBFGHooKAAHooKCCoDDKooIJEEooIJoo', 21, 'hard'),
    ('BBCCooooooJKGAAoJKGDDDJoGoHIEEFFHIoo', 24, 'hard'),
    ('oooHJKBBBHJKAAGoJKCCGoooFooIDDFooIEE', 23, 'hard'),
    ('BBJCCCDDJKooAAJKoLEEoooLIooFFMIGGHHM', 21, 'hard'),
    ('oBBIKLCCCIKLAAHJKLDDHJooGoooEEGoooFF', 23, 'hard'),
    ('BBBoooCCooooAAIJLoDDIJLMHEEKLMHFFKGG', 19, 'hard'),
    ('oBBJCCoDDJKLAAooKLHoIEEEHoIFFMHGGooM', 21, 'hard'),
    ('FGBBBKFGHoJKAAHoJoooICCLooIDDLooEEEL', 19, 'hard'),
    ('oooHoKBBBHJKAAGoJKCCGoooFooIDDFooIEE', 23, 'hard'),
    ('BBBooMCCoJLMAAIJLMDDIoooHooKEEHFFKGG', 25, 'hard'),
    ('BBBooLCCoooLAAIJoMDDIJoMHEEKooHFFKGG', 19, 'hard'),
    ('ooHBBBCCHIooAAHIoKDDoooKGooJoKGEEJFF', 23, 'hard'),
    ('oBBBooCCIJooAAIJKLDDooKLoHEEKLoHFFGG', 25, 'hard'),
    ('GBBCCoGoooJKGAAoJKDDDoJoooHIooEEHIFF', 24, 'hard'),
    ('oBBCCKooDDDKoAAJoLoEEJoLHoIFFFHoIGGo', 20, 'hard'),
    ('BBBJLoCCoJLoAAIKLoDDIKooHEEoooHFFoGG', 22, 'hard'),
    ('EoFBBJEoFGIJAAFGIJoooCCCoooHDDoooHoo', 22, 'hard'),
    ('BBCCKoGDDoKLGAAoKLGoEEEooHIJoooHIJFF', 24, 'hard'),
    ('EoBBooEoooCCAAFGHJooFGHJDDDGIKooooIK', 21, 'hard'),
    ('HooJBBHCCJLoAAoKLoDDoKEEooIFFFooIGGo', 24, 'hard'),
    ('EoFBBBEoFGIJEAAGIJCCCHIJoooHooooooDD', 20, 'hard'),
    ('BBoCCCDDooooAAJKoLEEJKoLHIJooLHIFFGG', 23, 'hard'),
    ('BBBooMCCoooMAAIJLNDDIJLNHEEKLoHFFKGG', 23, 'hard'),
    ('BBBoCCGHIooKGHIAAKGDDDoKoooJEEoooJFF', 21, 'hard'),
    ('BBoCCCooHJKLAAHJKLGDDEELGoIoooooIoFF', 23, 'hard'),
    ('BBHCCCooHJKLoAAJKLGDDEELGoIoooooIoFF', 21, 'hard'),
    ('HoJBBMHoJCCMIooAANIDDLoNooKLEEFFKGGo', 20, 'hard'),
    ('BBBIKooCCIKoAAHJLoDDHJLoGoooEEGFFooo', 22, 'hard'),
    ('ooBBBMooKCCMAAKLoMoDDLEEJFFoGGJHHHII', 23, 'hard'),
    ('HIBBLMHIJoLMHoJAAMooCCDDoooKEEoFFKGG', 23, 'hard'),
    ('FGBBBKFGHooKAAHooKCCoDDoooIJEEooIJoo', 19, 'hard'),
    ('BBHCCCGoHJKLGAAJKLoDDEELooIoooooIoFF', 20, 'hard'),
    ('FGHBBLFGHoKLFAAoKLooICCCooIJDDEEoJoo', 23, 'hard'),
    ('ooBBBMooJCCMAAJKLNoDDKLNIEEFFNIGGGHH', 21, 'hard'),
    ('BBBKCCoDDKLMoAAKLMoEEoFFIoJGGNIoJHHN', 20, 'hard'),
    ('BBBooKooGHJKAAGHJKoCCCJoFDDIooFEEIoo', 22, 'hard'),
    ('BBCCCKHooooKHAAooKDDIoEEooIJFFooIJGG', 21, 'hard'),
    ('EoFBBoEoFGCCAAoGHJoooGHJDDDoIKooooIK', 24, 'hard'),
    ('BBooJooCCCJLAAoIKLoDDIKLGoHIEEGoHFFo', 24, 'hard'),
    ('BBCCooIDDKLMIAAKLMIEEELoooJoFFGGJoHH', 21, 'hard'),
    ('GoIBBKGoICCKAAoooKHooJDDHEEJooFFFJoo', 21, 'hard'),
    ('EoBBooEooGCCAAFGHJooFGHJDDDoIKooooIK', 22, 'hard'),
    ('BBBooooooCCMAAIJLMDDIJLNHEEKLNHFFKGG', 20, 'hard'),
    ('GIBBBLGIJooLooJAALHoCCDDHooKEEHooKFF', 19, 'hard'),
    ('BBBIoKCCHIoKAAHooLGDDooLGEEJooFFFJoo', 20, 'hard'),
    ('GBBCCJGoDDDJoAAIoKoEEIoKooHFFFooHooo', 21, 'hard'),
    ('BBoCCLoooDDLAAIooMHoIEEMHoJKFFHoJKGG', 23, 'hard'),
    ('FoBBKLFoooKLAAooKMCCCooMGHIJDDGHIJEE', 19, 'hard'),
    ('BBBoLMCCooLMAAIJLMDDIJooHEEKooHFFKGG', 22, 'hard'),
    ('BBBooMCCoooMAAIJLoDDIJLoHEEKLoHFFKGG', 20, 'hard'),
    ('oBBBoooooCCLAAIJKLDDIJKLGHooKoGHEEFF', 22, 'hard'),
    ('oGoBBLoGoIKLAAoIKLFoHJCCFoHJDDooHEEE', 21, 'hard'),
    ('BBBJoLCCoJoLAAIKoMDDIKoMHoooEEHFFoGG', 22, 'hard'),
    ('BBoCCCGooooJGooAAJDDHEEJooHIFFooHIoo', 24, 'hard'),
    ('GBBIooGCCIooAAHJKMDDHJKMEEEoLMFFFoLo', 23, 'hard'),
    ('GBBCCoGoooKoGAAoKLoDDDKLoHIJEEoHIJFF', 20, 'hard'),
    ('HooJBBHCCJLoAAoKLooDDKEEooIFFFooIGGG', 25, 'hard'),
    ('BBBCCoDDEEEoAAKooMJoKFFMJGGLoMHHoLII', 24, 'hard'),
    ('BBIJCCooIJoLAAIKoLoDDKEEHoooFFHooGGG', 24, 'hard'),
    ('ooGBBBooGoIJAAooIJooHCCKoFHDDKoFEEEK', 25, 'hard'),
    ('oooHoKBBBHJKAAGIJKCCGIooFoooDDFoooEE', 22, 'hard'),
    ('BBBIKMoCCIKMAAHJLNDDHJLNGoooEEGFFooo', 25, 'hard'),
    ('FBBoooFooCCCAAHIoKDDHIJKGooIJLGEEEoL', 23, 'hard'),
    ('oGBBBKoGoIJKAAoIJLooHCCLFoHDDLFoHEEE', 24, 'hard'),
    ('GoBBJLGCCIJLAAHIKoDDHIKoEEEooMFFFooM', 21, 'hard'),
    ('BBCCKoGDDoKoGAAoKLGoEEELoHIJFFoHIJoo', 25, 'hard'),
    ('GBBCCoGDDoKoGAAoKLEEEoKLoHIJoLoHIJFF', 19, 'hard'),
    ('BBBooMCCooLMAAIJLMDDIJooHEEKooHFFKGG', 20, 'hard'),
    ('FoBBBJFoGoIJAAGoIoooHCCKooHDDKooEEEK', 19, 'hard'),
    ('oooBBMHoJCCMHoJAANIDDLoNIoKLEEFFKGGo', 23, 'hard'),
    ('oFGBBBoFGooJoooAAJCCoDDJooHIEEooHIoo', 23, 'hard'),
    ('GoBBBLGoJooLooJAALHCCoDDHIoKEEHIoKFF', 21, 'hard'),
    ('FooBBoFooHCCAAGHIoDDGHIoEEEoJoooooJo', 23, 'hard'),
    ('oBBBCCooDDDoAAIJoLEEIJoLHFFoKMHGGGKM', 22, 'hard'),
    ('GoBBooGoooCCAAHIJLDDHIJLEEEIKLFFFoKo', 25, 'hard'),
    ('BBooJoCCCoJoAAoIKLDDoIKLGoHIEEGoHFFo', 22, 'hard'),
    ('HBBCCKHoDDDKoAAJoLEEoJoLooIFFFooIGGo', 22, 'hard'),
    ('oGHJBBEGHJKLEoAAKLFoICCMFoIooMFoDDDM', 23, 'hard'),
    ('BBoooJCCoooJAAHIoKDDHIoKGoHIooGEEFFo', 24, 'hard'),
    ('BBJCCMIoJDDMIooAANIooEENooKLFFGGKLHH', 22, 'hard'),
    ('oBBCCoFoooJoFAAoJKFDDDJKoGHIEEoGHIoo', 20, 'hard'),
    ('GIJoBBGIJCCoHAAKLMHooKLMHoDDDNEEFFFN', 25, 'hard'),
    ('ooBBBLooCCKLAAooKMGHIJKMGHIJDDGEEFFo', 23, 'hard'),
    ('BBBHoKooGHJKAAGIJKCCCIooFDDoooFEEooo', 24, 'hard'),
    ('oBBCCCoDDKLMoAAKLMoEEFFMIoJGGoIoJHHH', 21, 'hard'),
    ('oBBCCoHDDJKLHAAJKLHEEEKoooIoooFFIoGG', 22, 'hard'),
    ('FoBBKLFooJKLAAoJKoCCCoooGHIDDMGHIEEM', 23, 'hard'),
    ('BBBoooooFGIJAAFGIJoCCCIJEDDHooEooHoo', 20, 'hard'),
    ('BBBJoMCCoJLMAAIKLNDDIKoNHEEoooHFFoGG', 22, 'hard'),
    ('oooHJKBBBHJKAAGIJKCCGIooFDDoooFEEooo', 20, 'hard'),
    ('oooBBBooHIoKAAHIoKoCCCoKGDDJooGEEJFF', 20, 'hard'),
    ('oBBIKLCCCIKLAAHJKLDDHJooGEEoooGFFooo', 21, 'hard'),
    ('BBBIoLCCHIoLAAHJKMoDDJKMGEEoooGooFFF', 24, 'hard'),
    ('HBBoooHCCJLoAAIJLoDDIKEEFFFKoooooGGo', 19, 'hard'),
    ('GHIKBBGHIKLMGoAALMooCCCMooJoDDEEJoFF', 24, 'hard'),
    ('BBBooLCCCooLAAHIoLDDHIKoGEEJKoGFFJoo', 19, 'hard'),
    ('oFGBBBoFGooJooAAoJooHCCJooHIDDEEEIoo', 19, 'hard'),
    ('GoIKBBGoIKLMGAAoLMoHCCCMoHJDDoEEJFFo', 20, 'hard'),
    ('FoBBooFooHCCAAGHIKDDGHIKEEEoJKooooJo', 24, 'hard'),
    ('BBJCCCDDJKooAAJKoLEEoooLHIoooLHIFFGG', 21, 'hard'),
    ('BBBHJoooGHJoAAGIJoCCCIooFDDoooFEEooo', 23, 'hard'),
    ('BBBCCMoDDEEMoAAKLNFFoKLNIoJGGNIoJHHH', 22, 'hard'),
    ('BBoCCLHDDJKLHAAJKLHEEEKoooIoooFFIGGo', 21, 'hard'),
    ('oooHJoBBBHJKAAGoJKCCGoooFDDIooFEEIoo', 19, 'hard'),
    ('GoBBJoGCCIJoAAHIooDDHIooEEEoKoFFooKo', 19, 'hard'),
    ('ooBBBKooGoJKAAGoJKoFHCCooFHIDDEEEIoo', 25, 'hard'),
    ('BBCCLMooJoLMooJAAMoDDKEEIooKFFIGGGHH', 20, 'hard'),
    ('FoBBooFCCoooAAGHIKDDGHIKEEEHJoooooJo', 21, 'hard'),
    ('GBBoooGCCoooAAHIKMDDHIKMEEEJLNoFFJLN', 25, 'hard'),
    ('GooIBBGCCIKoAAHoKoDDHJEEFFFJoooooooo', 21, 'hard'),
    ('BBBHoJooGHoJAAGooJCCCoooFooIDDFEEIoo', 25, 'hard'),
    ('BBoCCoGDDoKoGAAoKLGEEEKLoHIJFFoHIJoo', 22, 'hard'),
    ('EoFBBBEoFGIJEAAGIJCCCHIJoooHoooDDooo', 19, 'hard'),
    ('BBoCCoGoooKLGAAoKLGDDDKLoHIJEEoHIJFF', 22, 'hard'),
    ('ooooIKoBBBIKoAAHJLoCCHJLFoGHDDFoGEEo', 25, 'hard'),
    ('FoGBBoFoGHCCAAoHIoDDoHIoEEEoJoooooJo', 24, 'hard'),
    ('GBBCCKGoooJKGAAoJKoDDDJoooHIEEFFHIoo', 21, 'hard'),
    ('FBBooKFoCCCKAAHIooDDHIJoGooIJLGEEEoL', 21, 'hard'),
    ('EoFBBoEoFGCCAAoGHJoooGHJoDDDIKooooIK', 25, 'hard'),
    ('EoBBooECCoooAAFGHJooFGHJDDDGIKooooIK', 20, 'hard'),
    ('oFBBBooFGooJAAGooJCCoDDJooHIEEooHIoo', 20, 'hard'),
    ('BBooJLCCCIJLAAHIKMDDHIKMGoooEEGFFooo', 21, 'hard'),
    ('BBoJooooHJoKAAHJoKCCIoDDGoIEELGoFFFL', 23, 'hard'),
    ('HBBCCoHDDoLMHAAoLMEEEoLMoIJKFFoIJKGG', 20, 'hard'),
    ('BBBIoKooHIoKAAHJoKCCCJooGDDoooGEEoFF', 25, 'hard'),
    ('GBBCCoGoooKLGAAoKLoDDDKLoHIJEEoHIJFF', 20, 'hard'),
    ('BBCCooGDDoKoGAAoKLGEEEKLoHIJoLoHIJFF', 23, 'hard'),
    ('BBoCCoFoooJoFAAoJKFDDDJKoGHIoKoGHIEE', 21, 'hard'),
    ('BBooJoCCCIJLAAHIKLDDHIKLGoooEEGFFooo', 19, 'hard'),
    ('IBBCCoIDDKLMIAAKLMoEEELoooJoFFGGJoHH', 24, 'hard'),
    ('BBCCoMIoooLMIAAoLMDDJKEEooJKFFoGGHHH', 25, 'hard'),
    ('GoHBBKGoHIoKAAHIoKoooCCCoooJDDEEoJFF', 23, 'hard'),
    ('ooHJBBEoHJKLEoAAKLFoICCMFGIooMFGDDDM', 22, 'hard'),
    ('oBBBLMCCJKLMAAJKLMooooDDHIooEEHIFFGG', 23, 'hard'),
    ('BBCCJoFoooJKFAAoJKFoDDDKoGHIEEoGHIoo', 24, 'hard'),
    ('BBBCCLDDJoKLAAJoKMIooEEMIooFFMGGoHHH', 23, 'hard'),
    ('BBoJooooHJoKAAHJoKCCIDDLGoIEELGoFFFo', 25, 'hard'),
    ('GooIBBGCCIKoAAoJKoDDoJEEooHFFFooHooo', 24, 'hard'),
    ('oBBBooCCoooLAAIJKLDDIJKLGHooKoGHEEFF', 21, 'hard'),
    ('HBBCCoHDDoKLHAAoKLEEEoKoooIJooFFIJGG', 25, 'hard'),
    ('HBBJooHCCJLMAAIoLMDDIKEEFFFKoooooGGo', 19, 'hard'),
    ('BBBIKLoooIKLAAHJoMCCHJoMGDDoooGEEFFF', 20, 'hard'),
    ('IBBCCCIoDDDLAAJKoLooJKEEFFFoooGGGoHH', 22, 'hard'),
    ('ooHoBBooHJoKoAAJoKCCIJDDGoIEELGoFFFL', 19, 'hard'),
    ('BBooCCooooDDAAJKoMEEJKoMIoJLFFIGGLHH', 21, 'hard'),
    ('BBoCCKoooDDKAAHooLGoHEELGoIJFFGoIJoo', 22, 'hard'),
    ('ooBBBKoooooKFAAoJLFGHIJLFGHICCDDDIEE', 23, 'hard'),
    ('oGoBBBoGHooKAAHooKCCoDDKooIJEEooIJFF', 22, 'hard'),
    ('BBCCLMIoooLMIooAAMDDJKEEooJKFFoGGHHH', 23, 'hard'),
    ('BBoCCMoooDDMIoJAANIoJEENIoKLFFGGKLHH', 24, 'hard'),
    ('BBBoKMoCCoKMAAHILNDDHILNGEEJoNGFFJoo', 22, 'hard'),
    ('BBBoKMoCCoKMAAHIoNDDHIoNGEEJLNGFFJLo', 21, 'hard'),
    ('BBooCCDDoJoKoAAJoKEEIooLHoIFFLHoIGGG', 22, 'hard'),
    ('BBBCCoDDoEEEAAKooMJoKFFMJGGLoMHHoLII', 25, 'hard'),
    ('BBoCCCoooJDDAAoJoKEEIooKHoIFFKHoIGGG', 24, 'hard'),
    ('GoBBBMGoCCLMooAALNooDDLNHIJKEEHIJKFF', 19, 'hard'),
    ('BBBIoKooHIoKAAHooKCCCoooGDDJooGEEJFF', 24, 'hard'),
    ('HBBCCLHDDoKLHAAoKLoEEEKoooIJFFGGIJoo', 22, 'hard'),
    ('GoIKBBGoIKLMGoAALMoHJCCNoHJDDNEEFFFN', 20, 'hard'),
    ('FBBoooFoCCCoAAHIoKDDHIJKGooIJLGEEEoL', 22, 'hard'),
    ('HBBCCoHDDoKoHAAoKooEEEKoooIJooFFIJGG', 25, 'hard'),
    ('BBCCLMIoooLMIAAooMDDJKEEooJKFFoGGHHH', 24, 'hard'),
    ('GoJKBBGoJKCCHAAoLMHIooLMHIDDDNEEFFFN', 20, 'hard'),
    ('oBBIoKCCCIoKAAHJoKDDHJooGEEoooGoooFF', 21, 'hard'),
    ('BBCCCMDDJKLMAAJKLMEEFFooHIooooHIGGoo', 19, 'hard'),
    ('BBBooLCCCooLAAHIoLDDHIKoGEEJKoGFFJKo', 19, 'hard'),
    ('BBBCCMDDEEEMAAKLoMJoKLFFJoooGGHHooII', 20, 'hard'),
    ('BBoCCCoooDDKAAoJoKEEIJoKHoIFFoHoIGGG', 21, 'hard'),
    ('FoBBKLFoIJKLAAIJKooooCCCGHoDDMGHoEEM', 25, 'hard'),
    ('BBBCCLHDDJKLHAAJKMEEoJKMooIFFMooIGGG', 19, 'hard'),
    ('ooBBBKoooooKFoAAJLFGHIJLFGHICCDDDIEE', 22, 'hard'),
    ('oooIBBooGIJKAAGIJKCCHoDDFoHooLFoEEEL', 20, 'hard'),
    ('FoBBBKFoGIJKAAGIJoooHCCLooHDDLooEEEL', 20, 'hard'),
    ('ooBBBLCCoooLAAJoKMDDJoKMHIJEEEHIFFGG', 23, 'hard'),
    ('BBBKCCDDJKLMAAJKLMEEooFFIooGGNIooHHN', 24, 'hard'),
    ('GoBBBMGoCCLMAAJKLNDDJKLNHIooEEHIooFF', 23, 'hard'),
    ('BBCCCJGooooJGAAooJDDHEEoooHIFFooHIoo', 21, 'hard'),
    ('BBoCCLoDDoKLHAAoKLHEEEKoHoIJFFGGIJoo', 24, 'hard'),
    ('BBBGIJooFGIJAAFHIJCCCHooEDDoooEooooo', 25, 'hard'),
    ('BBBCCMDDJKLMAAJKLNIooEENIooFFNGGoHHH', 24, 'hard'),
    ('oBBCCooDDoKLHAAoKLHEEEKoHoIJFFGGIJoo', 23, 'hard'),
    ('IBBCCCIoDDDLAAJooLooJoEEFFFKooGGGKHH', 23, 'hard'),
    ('BBBKCCDDJKLoAAJKLoEEooFFIooGGMIHHooM', 23, 'hard'),
    ('oBBIKoCCCIKoAAHoKoDDHoooGooJEEGooJFF', 23, 'hard'),
    ('BBBJLoCCoJLoAAIoLoDDIoooHooKEEHFFKGG', 24, 'hard'),
    ('GoBBooGCCIooAAHIJLDDHIJLEEEoKoFFooKo', 21, 'hard'),
    ('ooBBBLCCJooLAAJoKMDDJoKMHIEEEoHIFFGG', 21, 'hard'),
    ('GHBBBLGHIooLAAIooLCCooDDooJKEEooJKFF', 19, 'hard'),
    ('oGBBBJoGoooJFAAooKFoHIoKFoHICCDDDIEE', 19, 'hard'),
    ('ooooIKBBBHIKAAGHJLCCGHJLFoooDDFEEooo', 19, 'hard'),
    ('ooooBBCCooooAAHIoJDDHIoJGoHIoKGEEFFK', 21, 'hard'),
    ('GoBBBMGoCCLMAAJKLNDDJKLNHIEEooHIFFoo', 25, 'hard'),
    ('oooHJoBBBHJKAAGIJKCCGIooFDDoooFEEooo', 20, 'hard'),
    ('BBBKCCDDJKLoAAJKLMIooEEMIooFFNGGoHHN', 22, 'hard'),
    ('GoIKBBGoIKLMGAAoLMoHJCCNoHJDDNEEFFFN', 19, 'hard'),
    ('BBooJLCCCoJLAAHoKMDDHIKMGEEIooGFFIoo', 19, 'hard'),
    ('oFGBBBoFGoIJAAooIJooHCCKooHDDKooEEEK', 22, 'hard'),
    ('BBBJLMCCoJLMAAIKLoDDIKooHEEoooHFFoGG', 23, 'hard'),
    ('FGHBBBFGHoKLooAAKLooICCLooIJDDEEEJoo', 20, 'hard'),
    ('BBoKCCDDoKoMAAJooMEEJoooIoJLFFIGGLHH', 24, 'hard'),
    ('oGoBBLoGoIKLoAAIKLFoHJCCFoHJDDooHEEE', 20, 'hard'),
    ('BBBCCMDDEEEMAAKooMJoKoFFJGGLooHHoLII', 22, 'hard'),
    ('oBBBLMCCoKLMAAoKLMHIooDDHIJoEEFFJoGG', 19, 'hard'),
    ('BBooJoCCCIJoAAHIKLDDHIKLGoooEEGFFooo', 19, 'hard'),
    ('BBBoooCCooooAAIJLMDDIJLMHEEKLMHFFKGG', 20, 'hard'),
    ('GoBBooGCCIooAAHIJoDDHIJoEEEoKoFFFoKo', 21, 'hard'),
    ('BBCCCLIoDDKLIAAoKMEEJFFMooJGGMooHHHo', 21, 'hard'),
    ('BBBCCLooDDKLoAAJKMEEoJKMHoIFFMHoIGGG', 22, 'hard'),
    ('EoFBBJEoFGIJAAFGIJCCCooooooHDDoooHoo', 21, 'hard'),
    ('oBBBLoCCJKLMAAJKLMHoooDDHIooEEoIFFGG', 22, 'hard'),
    ('oGBBBKoGHIJKAAHIJLooHCCLFooDDLFooEEE', 25, 'hard'),
    ('ooGBBBooGoIJAAooIJooHCCKFoHDDKFoEEEK', 25, 'hard'),
    ('BBBJoLCCoJoLAAIooMDDIooMHooKEEHFFKGG', 23, 'hard'),
    ('FBBIKLFooIKLFooAALoGHJCCoGHJDDEEEooo', 25, 'hard'),
    ('GBBoooGCCoooAAHIKLDDHIKLEEEJKMFFFJoM', 25, 'hard'),
    ('BBCCooHDDoLoHAAoLoHEEELooIJKFFoIJKGG', 22, 'hard'),
    ('ooBBBLCCoooLAAIJKMDDIJKMHoIEEEHFFGGG', 24, 'hard'),
    ('oBBCCJooDDDJoAAIoKoEEIoKGoHFFFGoHooo', 20, 'hard'),
    ('HBBCCoHDDJKoHAAJKoEEEoKoooIoFFGGIooo', 19, 'hard'),
    ('FooBBBFoGoIJAAGoIJooHCCKooHDDKooEEEK', 21, 'hard'),
    ('oGBBBJoGoooJFoAAoKFoHIoKFoHICCDDDIEE', 20, 'hard'),
    ('oBBIKoCCCIKoAAooKoooooDDGoHJEEGoHJFF', 25, 'hard'),
    ('oBBBLoCCJKLoAAJKLoooooDDHIooEEHIFFGG', 22, 'hard'),
    ('oBBIKLoooIKLoooAALFGHJCCFGHJDDFEEEoo', 23, 'hard'),
    ('FoBBooFCCoooAAGHIKDDGHIKEEEHJLooooJL', 23, 'hard'),
    ('BBCCCLIoDDKLIAAoKMEEoFFMooJGGMooJHHH', 19, 'hard'),
    ('BBJooLGoJCCLGAAooMDDDKoMHIoKEEHIFFFo', 23, 'hard'),
    ('FBBJLMFooJLMGooAAMGHIKCCGHIKDDoEEEoo', 24, 'hard'),
    ('BBCCCLIoDDKLIAAoKoEEJFFMooJGGMooHHHM', 22, 'hard'),
    ('BBBoIJooFGIJAAFGIJoCCCooEDDHooEooHoo', 22, 'hard'),
    ('BBBKCCDDoKLoAAoKLMIooEEMIoJFFNGGJHHN', 21, 'hard'),
    ('BBoCCKDDoJoKoAAJooEEIooLHoIFFLHoIGGG', 20, 'hard'),
    ('BBBIKMoCCIKMAAHJLMDDHJLoGoooEEGFFooo', 23, 'hard'),
    ('oooHoKBBBHJKAAooJKCCooooFoGIDDFoGIEE', 24, 'hard'),
    ('FoGBBoFoGHJKAAGHJKCCCooKoooIDDoooIEE', 21, 'hard'),
    ('BBBCCMDDEEEMAAoLoMJooLFFJoKoGGHHKoII', 19, 'hard'),
    ('HooJBBHCCJLMAAIKLMDDIKEEFFFooooooGGo', 23, 'hard'),
    ('BBooJooCCCJoAAoIKLoDDIKLGoHIEEGoHFFo', 24, 'hard'),
    ('FooBBKFooHJKoAAHJKooGCCCooGIDDooGIEE', 25, 'hard'),
    ('BBCCCJGooooJGAAooJDDHoEEooHIFFooHIoo', 20, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEoooFFFooo', 20, 'hard'),
    ('GBBKMNGooKMNoooAANHIJLCCHIJLDDHEEEFF', 24, 'hard'),
    ('oGHIBBoGHIJLFAAoJLFoooKMFoCCKMDDDEEM', 22, 'hard'),
    ('BBHCCCGoHooJGoHAAJDDoEEJoooIFFoooIoo', 25, 'hard'),
    ('oBBBLMCCJKLMAAJKLMHIooDDHIooEEooFFGG', 21, 'hard'),
    ('BBBooJooFGIJAAFGIJoCCCIoEDDHooEooHoo', 21, 'hard'),
    ('BBBIKMCCCIKMAAHoLNDDHoLNGEEJooGFFJoo', 25, 'hard'),
    ('BBHCCKooHIoKAAHIoKoDDJooGooJEEGooFFF', 24, 'hard'),
    ('BBoJCCoooJoLoooAALDDIKEEHoIKFFHoIGGG', 20, 'hard'),
    ('EooBBJEooGIJAAoGIJooFCCCooFHDDooFHoo', 23, 'hard'),
    ('oooIBBooGIJKAAGIJKCCHDDLFoHooLFooEEE', 23, 'hard'),
    ('ooBBBLCCIooLAAIJKMDDIJKMHoEEEoHFFGGG', 22, 'hard'),
    ('FoGBBBFoGIoJoAAIoJooHCCKooHDDKooEEEK', 23, 'hard'),
    ('ooHJBBEoHJKLEAAoKLFoICCMFGIooMFGDDDM', 21, 'hard'),
    ('ooooIKBBBoIKAAGHJLCCGHJLFooHDDFooEEo', 21, 'hard'),
    ('BBBoKMoCCoKMAAHIooDDHIooGEEJLoGFFJLo', 19, 'hard'),
    ('BBBJoMCCIJoMAAIoooDDooEEHFFKLNHGGKLN', 20, 'hard'),
    ('HoooBBHCCJLMAAIJLMDDIKEEFFFKoooooGGo', 21, 'hard'),
    ('BBoCCoIDDKLMIAAKLMIEEELoooJoFFGGJoHH', 22, 'hard'),
    ('BBBoCCoDDKLMoAAKLMoEEKFFIoJGGNIoJHHN', 19, 'hard'),
    ('oBBIKoCCCIKLAAooKLDDooooGoHJEEGoHJFF', 25, 'hard'),
    ('IBBCCCIoDDDLAAJKoLooJKEEoooFFFGGGHHo', 20, 'hard'),
    ('GoBBooGCCoooAAHIJLDDHIJLEEEIKoFFooKo', 22, 'hard'),
    ('BBBoKMCCCoKMAAHIoNDDHIoNGEEJLoGFFJLo', 23, 'hard'),
    ('BBBJLoCCoJLoAAIoLoDDIoooHEEKooHFFKGG', 21, 'hard'),
    ('FHIBBLFHIoKLAAIoKLCCCoooGooJDDGEEJoo', 25, 'hard'),
    ('BBBoJooCCCJLAAoIKLoDDIKLGoHIEEGoHFFo', 24, 'hard'),
    ('FoGBBBFoGIJKoAAIJKooHCCLooHDDLooEEEL', 24, 'hard'),
    ('BBBGIJooFGIJAAFoIJoCCCooEDDHooEooHoo', 23, 'hard'),
    ('oBBBLMCCJKLMAAJKLMHIooDDHIooEEFFooGG', 20, 'hard'),
    ('oBBCCKGooIJKGAAIJKGDDDJoooHoooEEHFFo', 21, 'hard'),
    ('BBCCooGDDoKoGAAoKLGEEEKLoHIJFFoHIJoo', 23, 'hard'),
    ('ooHBBBooHoJKooAAJKooICCLFGIDDLFGEEEL', 25, 'hard'),
    ('oBBCCoGoooKoGAAoKLGDDDKLoHIJEEoHIJFF', 21, 'hard'),
    ('GHBBBoGHIooLAAIooLCCoDDLooJKEEooJKFF', 21, 'hard'),
    ('BBBCCLHIJooLHIJAALHDDoEEoooKFFoooKGG', 25, 'hard'),
    ('FGoBBLFGoIKLoAAIKLooHJCCooHJDDooHEEE', 19, 'hard'),
    ('FoBBIoFCCHIoAAGHoKDDGHoKEEEoJoooooJo', 19, 'hard'),
    ('GBBoMNGooKMNAAoKoNHIJLCCHIJLDDHEEEFF', 22, 'hard'),
    ('GBBIooGCCIKoAAHJKLDDHJKLEEEooMFFFooM', 22, 'hard'),
    ('FoBBooFoooCCAAGHIKDDGHIKEEEHJLooooJL', 24, 'hard'),
    ('FHIBBLFHIoKLAAIoKLCCCJooGooJDDGEEooo', 24, 'hard'),
    ('BBCCooFoooJoFAAoJKFDDDJKoGHIEEoGHIoo', 22, 'hard'),
    ('GBBIooGCCIooAAHoKMDDHoKMEEEJLNoFFJLN', 24, 'hard'),
    ('BBCCooGoooKoGAAoKoGDDDKooHIJEEoHIJFF', 21, 'hard'),
    ('IBBCCCIoKLDDAAKLoMJooEEMJooFFMoGGHHH', 22, 'hard'),
    ('BBBoLoCCoJLoAAIJLoDDIoooHooKEEHFFKGG', 25, 'hard'),
    ('ooGBBBooGIoJAAoIoJooHCCKFoHDDKFoEEEK', 25, 'hard'),
    ('BBCCLoHoDDLoHAAoLoHoEEEooIJKFFoIJKGG', 25, 'hard'),
    ('oooHJoBBBHJKAAGoJKCCGoooFooIDDFooIEE', 23, 'hard'),
    ('ooBBBKCCoooKAAIJoLDDIJoLHoIEEEHFFGGG', 22, 'hard'),
    ('BBICCLooIDDLAAoooMHEEooMHoJKFFHoJKGG', 21, 'hard'),
    ('FoHBBBFoHooKAAoooKoGICCKoGIJDDEEEJoo', 21, 'hard'),
    ('HBBCCoHDDoKoHAAoKooEEEKoooIJFFGGIJoo', 21, 'hard'),
    ('HBBCCLHooJKLHAAJKLoDDDKoooIoEEFFIoGG', 24, 'hard'),
    ('ooHBBBooHIKLAAoIKLoCCCoLGDDJooGEEJFF', 20, 'hard'),
    ('ooBBBLCCoooLAAIJKMDDIJKMHoIEEEHFFGGo', 24, 'hard'),
    ('GoBBJoGCCIJLAAHIKLDDHIKLEEEooooooFFo', 19, 'hard'),
    ('BBCCCKHooooKHAAooKDDIEEoooIJFFooIJGG', 22, 'hard'),
    ('BBJKooooJKCCooAALMHIDDLMHIEELNHFFGGN', 20, 'hard'),
    ('BBBoooooGHoJAAGHoJoCCCoJFDDIooFEEIoo', 19, 'hard'),
    ('ooHBBBooHoCCAAHIoKDDoIoKGooJoKGEEJFF', 19, 'hard'),
    ('BBBHJoooGHJKAAGoJKoCCCooFDDIooFEEIoo', 22, 'hard'),
    ('oBBBooCCJKooAAJKLoDDooLoHIEELoHIFFGG', 25, 'hard'),
    ('BBBoCCHIJDDLHIJAALHEEEoLoooKFFoooKGG', 22, 'hard'),
    ('ooBBBLooCCKLooAAKMGHIJKMGHIJDDGEEFFo', 22, 'hard'),
    ('oBBooLCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 19, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLoooEEEFFFooo', 19, 'hard'),
    ('GBBIKoGCCIKoAAHJoMDDHJoMEEEoLNFFFoLN', 22, 'hard'),
    ('ooooIKBBBoIKAAoHJLCCoHJLFoGHDDFoGEEo', 22, 'hard'),
    ('BBBoJoCCCoJoAAHIKLDDHIKLGooIEEGFFooo', 20, 'hard'),
    ('GBBCCKGoooJKGAAoJKDDDoJoooHIEEFFHIoo', 20, 'hard'),
    ('BBBoKMCCCoKMAAHILNDDHILNGEEJooGFFJoo', 24, 'hard'),
    ('BBCCCLHDDJKLHAAJKLHEEFFooIoooooIooGG', 19, 'hard'),
    ('BBCCKoGDDoKLGAAoKLGEEEoLoHIJFFoHIJoo', 24, 'hard'),
    ('BBIJCCDDIJoKooIAAKEEoooLHooFFLHooGGG', 25, 'hard'),
    ('BBBIoLCCHIKLAAHoKMGDDooMGooJEEFFoJoo', 24, 'hard'),
    ('BBoJCCDDoJKLAAooKLHoIEEEHoIFFMHGGooM', 19, 'hard'),
    ('BBJooLGoJCCLGooAAMDDDKoMHIoKEEHIFFFo', 22, 'hard'),
    ('HBBCCKHoDDDKAAoJoLEEoJoLooIFFFooIGGo', 23, 'hard'),
    ('BBIoKLoHIoKLoHIAALoCCJDDGooJEEGooFFF', 19, 'hard'),
    ('BBooKLoHooKLoHoAALCCIJDDGoIJEEGoIFFF', 21, 'hard'),
    ('FoBBKLFooJKLAAoJKooooCCCGHIDDMGHIEEM', 24, 'hard'),
    ('BBCCCoooHJKLAAHJKLGDDEELGoIoooooIoFF', 24, 'hard'),
    ('HBBCCLHDDJKLHAAJKLoEEEKoooIoooFFIoGG', 24, 'hard'),
    ('BBBoKMoCCoKMAAHILNDDHILNGEEJooGFFJoo', 22, 'hard'),
    ('HBBCCLHoDDDLoAAJKMoEEJKMooIFFFooIGGG', 23, 'hard'),
    ('BBBoJoooGHJKAAGHJKoCCCooFDDIooFEEIoo', 21, 'hard'),
    ('HIBBLMHIJoLMHoJAAMooCCDDoooKEEFFoKGG', 24, 'hard'),
    ('BBBJoLCCoJoLAAIooLDDIoooHooKEEHFFKGG', 23, 'hard'),
    ('ooBBBKooHCCKAAHooKGoIJDDGoIJEEoooFFF', 25, 'hard'),
    ('oBBCCCoDDKLMAAoKLMoEEFFMIoJGGoIoJHHH', 20, 'hard'),
    ('FBBJLMFooJLMAAoooMGHIKCCGHIKDDGEEEoo', 22, 'hard'),
    ('ooBBBMCCJooMAAJKLNDDoKLNIEEFFNIGGGHH', 25, 'hard'),
    ('BBoCCooDDoKoHAAoKoHEEEKoHoIJFFGGIJoo', 23, 'hard'),
    ('oooHJoBBBHJoAAGIJoCCGIooFDDoooFEEooo', 19, 'hard'),
    ('ooJBBLGoJCCLGooAAMDDDKoMHIoKEEHIFFFo', 19, 'hard'),
    ('oBBCCCoDDDKLoAAoKLoEEoKMHIJFFMHIJGGG', 23, 'hard'),
    ('ooBBBKooHCCKAAHooKoooJDDGoIJEEGoIFFF', 23, 'hard'),
    ('FGBBBJFGoIoJAAoIoKooHCCKooHDDKooHEEE', 20, 'hard'),
    ('FGHBBBFGHooKAAoooKCCoDDKooIJEEooIJoo', 22, 'hard'),
    ('ooHBBBooHIKLoAAIKLoCCCoLGDDJooGEEJFF', 19, 'hard'),
    ('BBCCoLoDDoKLHAAoKLHEEEKoHoIJFFGGIJoo', 25, 'hard'),
    ('oBBIKoCCCIKLAAHJKLDDHJooGEEoooGoooFF', 22, 'hard'),
    ('ooIoBBooIJCCAAIJoKDDoJoKHooEELHFFGGL', 20, 'hard'),
    ('BBCCJoFoooJKFoAAJKFoDDDKoGHIEEoGHIoo', 25, 'hard'),
    ('BBoCCoFoooJKFAAoJKFDDDJKoGHIEEoGHIoo', 21, 'hard'),
    ('BBBCCMDDoKLMoAAKLNIooEENIoJFFNGGJHHH', 22, 'hard'),
    ('BBCCCMDDoooMAAoooMEEJKFFHIJKLoHIGGLo', 23, 'hard'),
    ('GIJoBBGIJoCCHAAKoLHooKoLHoDDDMEEFFFM', 23, 'hard'),
    ('BBBIKoCCCIKoAAHJKoDDHJooGoooEEGoooFF', 23, 'hard'),
    ('BBBooMCCoooMAAIJoNDDIJLNHEEKLoHFFKGG', 19, 'hard'),
    ('ooBBBLCCIooLAAIJKMDDIJKMHooEEEHFFGGo', 23, 'hard'),
    ('BBBJLMCCoJLMAAIKLMDDIKooHoooEEHFFoGG', 25, 'hard'),
    ('BBBIKLoCCIKLAAHJKMDDHJoMGEEoooGooFFo', 23, 'hard'),
    ('ooGBBBooGoIJoAAoIJooHCCKFoHDDKFoEEEK', 24, 'hard'),
    ('GoHBBoGoHICCAAoIJoDDoIJoEEEoKoFFooKo', 25, 'hard'),
    ('BBBHJoooGHJoAAGoJoCCCoooFDDIooFEEIoo', 22, 'hard'),
    ('ooHIBBooHIJLFoAAJLFGooKMFGCCKMDDEEEM', 20, 'hard'),
    ('FoGBBKFoGHJKAAGHJKCCCooooooIDDoooIEE', 22, 'hard'),
    ('BBCCJoFoooJoFAAoJKFDDDoKoGHIoKoGHIEE', 23, 'hard'),
    ('BBoCCKGooIJKGAAIJKGDDDJoooHoooEEHFFo', 20, 'hard'),
    ('BBJCCCDDJoooAAJKoLEEoKoLIooFFMIGGHHM', 22, 'hard'),
    ('FoGBBoFoGHCCAAoHIKDDoHIKEEEoJoooooJo', 25, 'hard'),
    ('BBBooLCCoJoLAAIJoLDDIoooHooKEEHFFKGG', 24, 'hard'),
    ('oFBBBJoFGooJAAGooJCCoDDoooHIEEooHIoo', 19, 'hard'),
    ('BBBIoKCCCIoKAAoooKDDooooGoHJEEGoHJFF', 25, 'hard'),
    ('BBCCKoGDDoKLGAAoKLGEEEoooHIJoooHIJFF', 23, 'hard'),
    ('BBCCooGDDoKLGAAoKLGEEEKooHIJoooHIJFF', 22, 'hard'),
    ('oBBIKoCCCIKoAAooKoDDooooGoHJEEGoHJFF', 24, 'hard'),
    ('BBBIoKooHIoKAAHooKoCCCooGDDJooGEEJFF', 23, 'hard'),
    ('BBoCCooDDDKLAAooKLEEooKMHIJFFMHIJGGG', 19, 'hard'),
    ('BBBoJLCCCIJLAAHIKMDDHIKMGEEoooGFFooo', 20, 'hard'),
    ('oHIBBMoHIoLMGAAKLNGCCKoNGoJoDDEEJoFF', 20, 'hard'),
    ('BBBoJooCCCJooAAIKLoDDIKLGoHIEEGoHFFo', 25, 'hard'),
    ('HoJBBMHoJCCMIAAooNIDDLoNooKLEEFFKGGo', 19, 'hard'),
    ('GoIBBKGoICCKHooAAKHooJDDoEEJooFFFJoo', 23, 'hard'),
    ('GoBBJLGCCIJLAAHIKMDDHIKMEEEoooFFFooo', 20, 'hard'),
    ('BBBHoJooGHoJAAGIoJCCCIooFoooDDFEEooo', 24, 'hard'),
    ('GBBCCKGoDDDKoAAIJLEEoIJLooHFFFooHooo', 23, 'hard'),
    ('ooooBBooIJCCAAIJoKDDIJoKHooEELHFFGGL', 21, 'hard'),
    ('BBBCCoIoKDDMIoKAAMIEEFFMoJoLGGoJoLHH', 21, 'hard'),
    ('BBCCLMIoJoLMIoJAAMDDoKEEoooKFFoGGHHH', 22, 'hard'),
    ('BBoCCoGooIJoGAAIJoGDDDJoooHoooEEHoFF', 19, 'hard'),
    ('GoJBBBGoJooLoooAALHCCDDLHIoKEEHIoKFF', 25, 'hard'),
    ('GHIKBBGHIKLMGoAALMooCCCMooJDDoEEJFFo', 22, 'hard'),
    ('GoBBBMGoCCLMAAJKLNDDJKLNHIooEEHIFFoo', 24, 'hard'),
    ('oooBBBooHoKLAAHoKLFGICCLFGIJDDEEEJoo', 24, 'hard'),
    ('GBBBCCGHIooKGHIAAKoDDDoKoooJEEoooJFF', 23, 'hard'),
    ('GBBCCoGoooJKGAAoJKoDDDJoooHIooEEHIFF', 25, 'hard'),
    ('BBoJCCDDoJoKoAAooKEEIooLHoIFFLHoIGGG', 23, 'hard'),
    ('ooFBBBooFGIJAAoGIJECCCIJEooHooEooHDD', 24, 'hard'),
    ('GoBBooGCCIooAAHIJLDDHIJLEEEoKMFFooKM', 23, 'hard'),
    ('GBBCCKGoDDDKoAAIJLoEEIJLooHFFFooHooo', 22, 'hard'),
    ('HoooBBHCCJLoAAIJLoDDIKEEFFFKoooooGGG', 20, 'hard'),
    ('HIBBLMHIJoLMHoJAAMCCooDDoooKEEFFoKGG', 25, 'hard'),
    ('GBBCCKGooIJKGAAIJKDDDoJoooHoooEEHoFF', 24, 'hard'),
    ('BBCCKoHooJKLHAAJKLHDDDooooIoEEFFIoGG', 19, 'hard'),
    ('BBBIoKCCCIoKAAHooKDDHoooGooJEEGooJFF', 24, 'hard'),
    ('oBBCCKooooJKGAAoJKGDDDJoGoHIEEFFHIoo', 22, 'hard'),
    ('GBBooKGooCCKAAIooKHoIJDDHEEJooFFFJoo', 19, 'hard'),
    ('HooJBBHCCJLoAAIKLoDDIKEEFFFooooooGGG', 22, 'hard'),
    ('GBBIKoGCCIKMAAHJLMDDHJLMEEEooooooFFF', 19, 'hard'),
    ('oooBBMCCCooMAAHIKNDDHIKNGEEJLoGFFJLo', 21, 'hard'),
    ('GHIBBBGHIooLAAoooLCCoDDLooJKEEooJKFF', 23, 'hard'),
    ('BBBoooCCCoooAAHIKMDDHIKMGEEJLNGFFJLN', 20, 'hard'),
    ('BBBoJoCCCoJLAAHIKLDDHIKLGooIEEGooFFo', 21, 'hard'),
    ('HooJBBHCCJLoAAIKLoDDIKEEoooFFFoooGGG', 23, 'hard'),
    ('GBBoooGCCoooAAHIKLDDHIKLEEEJKMoFFJoM', 25, 'hard'),
    ('oGHBBLoGHIKLAAHIKLFooJCCFooJDDEEEooo', 23, 'hard'),
    ('BBoJooooIJCCAAIJoKDDIooKHooEELHFFGGL', 23, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEooLFFoooo', 21, 'hard'),
    ('BBJKCCooJKDDAAJooMEEoooMIooLFFIGGLHH', 19, 'hard'),
    ('BBooJoCCCoJoAAHIKLDDHIKLGooIEEGooFFo', 21, 'hard'),
    ('oooBBLGoJCCLGoJAAMDDDKoMHIoKEEHIFFFo', 20, 'hard'),
    ('GoBBBLGoJooLooJAALHoCCDDHIoKEEHIoKFF', 20, 'hard'),
    ('IBBCCCIoDDDLAAJKoLooJKEEoooFFFGGGoHH', 21, 'hard'),
    ('BBoCCCoooKDDAAJKoLEEJooLHIJooLHIFFGG', 25, 'hard'),
    ('BBoJCCoooJoLAAoooLDDIKEEHoIKFFHoIGGG', 21, 'hard'),
    ('BBBCCLHoJooLHoJAALHoDDEEoIoKFFoIoKGG', 23, 'hard'),
    ('GooIBBGCCIKLAAHJKLDDHJEEoooFFFoooooo', 24, 'hard'),
    ('oIBBLMoIJoLMooJAAMHoCCDDHooKEEHFFKGG', 22, 'hard'),
    ('GoBBooGCCoooAAHIJLDDHIJLEEEIKLFFooKo', 24, 'hard'),
    ('GooIBBGCCIKoAAoJKooDDJEEooHFFFooHooo', 25, 'hard'),
    ('oBBIoKCCCIoKAAoooKDDooooGoHJEEGoHJFF', 24, 'hard'),
    ('ooBBBKCCIJoKAAIJoLDDIooLHoEEEoHFFGGG', 19, 'hard'),
    ('ooBBBKooICCKAAIJoLDDIJoLHooEEEHFFGGG', 24, 'hard'),
    ('GooIBBGCCIKoAAHJKoDDHJEEoooFFFoooooo', 23, 'hard'),
    ('BBCCooGDDoKLGAAoKLGEEEKLoHIJFFoHIJoo', 23, 'hard'),
    ('FGHBBBFGHoJKooAAJKooICCLooIDDLooEEEL', 23, 'hard'),
    ('GHIBBMGHIKLMGAAKLoooJCCNooJDDNEEFFFN', 25, 'hard'),
    ('ooBBBKoooCCKAAIJoLDDIJoLHoIEEEHFFGGG', 23, 'hard'),
    ('BBBIoKCCCIoKAAHooKDDHoooGEEJooGFFJoo', 20, 'hard'),
    ('BBBoLoCCooLoAAIJLoDDIJooHEEKooHFFKGG', 20, 'hard'),
    ('BBCCKoGDDoKoGAAoKLGEEEoLoHIJoLoHIJFF', 24, 'hard'),
    ('BBBoKooCCoKoAAHILoDDHILoGEEJooGFFJoo', 19, 'hard'),
    ('ooBBBJoooIoJFAAIoKFGHIoKFGHCCoDDDoEE', 24, 'hard'),
    ('oBBCCoGooIJKGAAIJKGDDDJoooHoooEEHoFF', 21, 'hard'),
    ('GBBCCoGooIJoGAAIJoDDDoJoooHoooEEHoFF', 22, 'hard'),
    ('FGHBBBFGHoJKAAooJKooICCLooIDDLooEEEL', 22, 'hard'),
    ('HBBCCLHoDDDLoAAJKMEEoJKMooIFFFooIGGo', 23, 'hard'),
    ('oooHJoBBBHJKAAGIJKCCGIooFoooDDFoooEE', 22, 'hard'),
    ('oBBooLoooIKLAAoIKLFGHJCCFGHJDDFEEEoo', 20, 'hard'),
    ('BBJKooHoJKCCHoAAoMHIDDLMoIEELNFFGGLN', 24, 'hard'),
    ('BBBJoMCCoJLMAAIoLNDDIooNHEEKooHFFKGG', 21, 'hard'),
    ('FBBCCoFoooJoFAAoJKoDDDJKoGHIoKoGHIEE', 19, 'hard'),
    ('BBBooMoooCCMAAIJLNDDIJLNHEEKLoHFFKGG', 22, 'hard'),
    ('BBCCooFoooJKFAAoJKFDDDJKoGHIEEoGHIoo', 22, 'hard'),
    ('HooBBMHoJCCMIoJAANIDDLoNooKLEEFFKGGo', 21, 'hard'),
    ('BBoCCoFoooJoFAAoJKFDDDJKoGHIoooGHIEE', 21, 'hard'),
    ('oGHoBBoGHIJLFAAIJLFoooKMFoCCKMDDDEEM', 23, 'hard'),
    ('oFGBBBoFGoJKAAooJKooHCCKooHIDDEEEIoo', 19, 'hard'),
    ('GoHBBLGoHoKLGAAoKLoooCCCooIJDDEEIJFF', 21, 'hard'),
    ('oBBCCoHDDoLMHAAoLMHEEELMoIJKFFoIJKGG', 22, 'hard'),
    ('oooHoKBBBHJKAAGIJKCCGIooFDDoooFEEooo', 20, 'hard'),
    ('BBBooMoCCooMAAHIKNDDHIKNGEEJLNGFFJLo', 20, 'hard'),
    ('BBoCCoHDDoLoHAAoLoHEEELooIJKFFoIJKGG', 21, 'hard'),
    ('oBBCCoHDDoLoHAAoLMHEEELMoIJKFFoIJKGG', 22, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKoFFFoKo', 21, 'hard'),
    ('BBBoooooGHJKAAGHJKoCCCJoFDDIooFEEIoo', 20, 'hard'),
    ('FoHBBBFoHoJKooAAJKooICCLoGIDDLoGEEEL', 24, 'hard'),
    ('GBBCCoGoooJKGAAoJKDDDoJoooHIEEFFHIoo', 20, 'hard'),
    ('BBBooLooHIKLAAHIKLoCCCooGDDJooGEEJFF', 23, 'hard'),
    ('FHIBBLFHIoKLAAIoKLoooCCCGooJDDGooJEE', 21, 'hard'),
    ('FooBBKFooHJKAAoHJKooGCCCooGIDDooGIEE', 24, 'hard'),
    ('GBBooNGooKMNAAoKMNHIJLCCHIJLDDHEEEFF', 21, 'hard'),
    ('ooBBBKooICCKAAIJoLDDIJoLHooEEEHFFGGo', 24, 'hard'),
    ('HooJBBHCCJLMAAoKLMDDoKEEooIFFFooIGGo', 25, 'hard'),
    ('BBBCCMoDDEEMoAAKLNoFFKLNIoJGGNIoJHHH', 21, 'hard'),
    ('FBBCCoFoooJKFAAoJKoDDDJKoGHIEEoGHIoo', 19, 'hard'),
    ('oooBBBooGoJKAAGoJKoFHCCKoFHIDDEEEIoo', 23, 'hard'),
    ('BBBHoKooGHJKAAGoJKCCCoooFDDIooFEEIoo', 23, 'hard'),
    ('BBJKooHoJKCCHoAALMHIDDLMoIEELNFFoGGN', 22, 'hard'),
    ('oBBIKMCCCIKMAAHoLNDDHoLNGEEJooGFFJoo', 25, 'hard'),
    ('BBJCCCDDJKooAAJKoLHooEELHIoooLoIFFGG', 19, 'hard'),
    ('HBBCCoHDDoLoHAAoLooEEELooIJKFFoIJKGG', 19, 'hard'),
    ('BBoJCCoDDJKLAAooKLHoIEEEHoIFFMHGGooM', 20, 'hard'),
    ('FHIBBLFHIoKLAAIoKLCCCoooGooJDDGooJEE', 22, 'hard'),
    ('ooBBBKCCoooKAAIoJLDDIoJLHoIEEEHFFGGo', 22, 'hard'),
    ('BBBooMCCoooMAAIJoMDDIJLoHEEKLoHFFKGG', 19, 'hard'),
    ('ooBBBLoooCCLAAJoKMDDJoKMHIJEEEHIFFGG', 24, 'hard'),
    ('HBBCCLHoDDDLAAoJKMEEoJKMooIFFFooIGGG', 25, 'hard'),
    ('IBBCCoIDDKLMIAAKLMEEEoLoooJoFFGGJoHH', 25, 'hard'),
    ('BBBIoLCCHIoLAAHoKMGDDoKMGEEJooFFFJoo', 21, 'hard'),
    ('BBBooMoooCCMAAHIKNDDHIKNGEEJLoGFFJLo', 19, 'hard'),
    ('oooBBJoooGIJoAAGIJooFCCCEoFHDDEoFHoo', 25, 'hard'),
    ('BBoCCoHDDJKoHAAJKoHEEEKoooIoooFFIoGG', 20, 'hard'),
    ('GoHIBBGoHIoKAAHooKCCCooKoooJDDEEoJFF', 19, 'hard'),
    ('ooHIBBooHIJLFoAAJLFGooKMFGCCKMDDDEEM', 20, 'hard'),
    ('BBooCCDDooooAAJKoMEEJKoMIoJLFFIGGLHH', 22, 'hard'),
    ('oooHoJBBBHoJAAoooJoooICCFoGIDDFoGoEE', 25, 'hard'),
    ('GIJoBBGIJoCCHAAKLMHooKLMHoDDDNEEEFFN', 24, 'hard'),
    ('FoBBKLFooJKLAAoJKMCCCooMGHIoDDGHIoEE', 20, 'hard'),
    ('oBBCCKooDDDKoAAJoLoEEJoLHoIFFFHoIGGG', 21, 'hard'),
    ('BBoCCCoDDDKLAAJoKLEEJoKMHIoFFMHIoGGG', 19, 'hard'),
    ('oBBIKLCCCIKLAAHoKLDDHoooGEEJooGFFJoo', 20, 'hard'),
    ('HBBCCCHDDDKLoAAoKLoEEoKMoIJFFMoIJGGG', 24, 'hard'),
    ('BBoooJCCoooJAAHIooDDHIooGoHIoKGEEFFK', 23, 'hard'),
    ('FBBooKFoCCCKAAHIooDDHIJLGooIJLGEEEoo', 20, 'hard'),
    ('BBBIKMoCCIKMAAHoLNDDHoLNGEEJooGFFJoo', 23, 'hard'),
    ('BBBJoMCCoJLMAAIoLNDDIooNHooKEEHFFKGG', 24, 'hard'),
    ('EoHIBBEGHIKLoGAAKLFCCoKMFooJoMFooJDD', 21, 'hard'),
    ('GBBIooGCCIooAAHJKLDDHJKLEEEoKMoooFFM', 22, 'hard'),
    ('BBBoJoCCCoJoAAoIKLDDoIKLGoHIEEGoHFFo', 22, 'hard'),
    ('BBBHoJooGHoJAAGooJoCCCooFDDIooFEEIoo', 21, 'hard'),
    ('BBoCCCHDDJKLHAAJKLHEEFFLoIoooooIooGG', 21, 'hard'),
    ('FoBBooFooHCCAAGHIKDDGHIKEEEoJoooooJo', 23, 'hard'),
    ('FoBBBKFoGIJKAAGIJLooHCCLooHDDLooEEEo', 19, 'hard'),
    ('HBBCCCHDDJKLHAAJKLoEEFFLoIoooooIooGG', 23, 'hard'),
    ('GBBoooGCCIKoAAHIKoDDHJEEFFFJoooooooo', 19, 'hard'),
    ('oooHJoBBBHJoAAGIJoCCGIooFoooDDFoooEE', 21, 'hard'),
    ('BBBCCMDDoEEMAAoKLNFFoKLNIoJGGNIoJHHH', 24, 'hard'),
    ('FHIBBLFHIoKLAAIoKLCCCJooGooJDDGoooEE', 23, 'hard'),
    ('IBBCCCIooLDDAAoLoMEEKooMJoKFFMJGGHHH', 19, 'hard'),
    ('oooIBBooGIJKAAGIJKCCoDDLFoHooLFoHEEE', 24, 'hard'),
    ('BBBIKLoooIKLAAHooMCCHJoMGooJDDGEEFFF', 22, 'hard'),
    ('BBoCCCHooooKHAAooKDDIEEKooIJFFooIJGG', 24, 'hard'),
    ('BBBCCLooDDKLAAIJKMEEIJKMHooFFMHGGGoo', 25, 'hard'),
    ('oBBCCoHDDoLoHAAoLoHEEELooIJKFFoIJKGG', 20, 'hard'),
    ('BBCCLMIDDKLMIAAKLMIEEEooooJoFFGGJHHo', 20, 'hard'),
    ('BBCCooHDDJKLHAAJKLHEEEKoooIoooFFIoGG', 20, 'hard'),
    ('FoBBooFoooCCAAGHIKDDGHIKEEEHJoooooJo', 22, 'hard'),
    ('GoBBJoGCCIJoAAHIKoDDHIKoEEEoooFFFooo', 19, 'hard'),
    ('FooBBJFooHoJoAAHoJooGCCCooGIDDooGIEE', 24, 'hard'),
    ('BBCCJoFoooJKFAAoJKFDDDoKoGHIEEoGHIoo', 23, 'hard'),
    ('FGBBBJFGoIoJoAAIoKooHCCKooHDDKooHEEE', 21, 'hard'),
    ('GoBBooGCCoooAAHIJoDDHIJoEEEIKoFFooKo', 21, 'hard'),
    ('BBBoJooCCCJLoAAIKLoDDIKLGoHIEEGoHFFo', 25, 'hard'),
    ('GoBBJoGCCIJLAAHIKLDDHIKLEEEooooooFFF', 19, 'hard'),
    ('BBCCJoFoooJoFAAoJKFoDDDKoGHIoooGHIEE', 24, 'hard'),
    ('oBBIoKCCCIoKAAHooKDDHoooGooJEEGooJFF', 23, 'hard'),
    ('FoBBBJFoGIoJAAGIooooHCCKooHDDKooEEEK', 19, 'hard'),
    ('BBBCCMDDJKLMAAJKLNIooEENIooFFNoGGHHH', 25, 'hard'),
    ('BBooooooHJoKAAHJoKCCIJDDGoIEELGoFFFL', 22, 'hard'),
    ('HBBoooHCCJLMAAIJLMDDIKEEFFFKoooooGGG', 20, 'hard'),
    ('ooBBBLCCIJoLAAIJKMDDIoKMHoEEEoHFFGGG', 21, 'hard'),
    ('BBBIoLCCCIKLAAHJKLDDHJooGEEoooGoooFF', 23, 'hard'),
    ('IBBCCCIDDKLMAAJKLMEEJFFMoooGGooooHHH', 25, 'hard'),
    ('BBBJoMCCoJLMAAIoLMDDIoooHooKEEHFFKGG', 24, 'hard'),
    ('ooBBBKoooIoKFAAIJLFGHIJLFGHCCoDDDoEE', 25, 'hard'),
    ('BBJCCCDDJoooAAJKoLEEoKoLHIoooLHIFFGG', 22, 'hard'),
    ('oGHBBLoGHIKLAAHIKLFCCoooFooJDDEEEJoo', 25, 'hard'),
    ('ooBBBKCCIooKAAIJoLDDIJoLHooEEEHFFGGo', 21, 'hard'),
    ('oGHBBBoGHooKAAoooKCCoDDKooIJEEooIJFF', 23, 'hard'),
    ('ooIBBBooICCLAAoJKLDDoJKLGHooKoGHEEFF', 24, 'hard'),
    ('BBBCCMDDEEEMAAKooMJoKFFoJGGLooHHoLII', 23, 'hard'),
    ('BBBCCLDDIJKLAAIJKooooEEEHooFFMHGGooM', 21, 'hard'),
    ('HooJBBHCCJLoAAoKLooDDKEEooIFFFooIGGo', 25, 'hard'),
    ('oHBBBLoHCCKLAAooKMGoIJKMGoIJDDGEEFFo', 20, 'hard'),
    ('ooBBBLCCIJKLAAIJKMDDIooMHoEEEoHFFGGG', 20, 'hard'),
    ('BBBCCMIoKDDMIoKAAMIEEFFooJoLGGoJoLHH', 22, 'hard'),
    ('IBBCCCIooLDDAAoLoMJEEooMJoKFFMGGKHHH', 25, 'hard'),
    ('BBBJoLCCoJoLAAIKoMDDIKoMHEEoooHFFoGG', 21, 'hard'),
    ('FGHBBBFGHooKooAAoKooICCKooIJDDEEEJoo', 19, 'hard'),
    ('oBBCCoFoooJoFAAoJKFDDDJKoGHIoooGHIEE', 20, 'hard'),
    ('oBBBKLCCIJKLAAIJKLDDoooooHEEoooHFFGG', 23, 'hard'),
    ('oBBIoLCCCIKLAAooKLDDooooGoHJEEGoHJFF', 25, 'hard'),
    ('FoBBooFCCHooAAGHIKDDGHIKEEEoJLooooJL', 22, 'hard'),
    ('oBBIKoCCCIKLAAHJKLDDHJooGoooEEGoooFF', 23, 'hard'),
    ('oGBBBooGHooKAAHooKCCoDDKooIJEEooIJFF', 21, 'hard'),
    ('oGBBBKoGoIoKFAAIJLFoHIJLFoHoCCDDDoEE', 19, 'hard'),
    ('BBBCCLDDIJKLAAIJKooooEEEHooFFMHooGGM', 20, 'hard'),
    ('BBooJoCCCoJLAAoIKLoDDIKLGoHIEEGoHFFo', 23, 'hard'),
    ('GoHBBLGoHoKLGAAoKLooICCCooIJDDEEoJFF', 22, 'hard'),
    ('HBBCCCHDDDKLoAAoKLEEooKMoIJFFMoIJGGG', 25, 'hard'),
    ('oBBCCLooDDDLAAoJKMoEEJKMHoIFFFHoIGGo', 20, 'hard'),
    ('oBBIoLCCCIKLAAHJKLDDHJooGEEoooGoooFF', 22, 'hard'),
    ('oBBIKLCCCIKLAAHJKLDDHJooGEEoooGoooFF', 22, 'hard'),
    ('BBBJLMCCoJLMAAIoLNDDIooNHEEKooHFFKGG', 25, 'hard'),
    ('FBBCCoFoooJoFAAoJKoDDDJKoGHIoooGHIEE', 19, 'hard'),
    ('FooBBoFooHCCAAGHIKDDGHIKEEEoJoooooJo', 24, 'hard'),
    ('GBBCCKGooIJKGAAIJKoDDDJoooHoooEEHoFF', 23, 'hard'),
    ('HBBCCoHDDoLMHAAoLMoEEELMoIJKFFoIJKGG', 21, 'hard'),
    ('oBBBLoCCJKLMAAJKLMooooDDHIEEooHIFFGG', 24, 'hard'),
    ('BBoCCooooIoKAAoIoKDDHJoKGoHJEEGoHFFF', 21, 'hard'),
    ('ooBBBKCCoooKAAHooKooHJDDGoIJEEGoIFFF', 21, 'hard'),
    ('HBBCCLHDDJKLHAAJKLoEEEKoooIoooFFIGGo', 23, 'hard'),
    ('oooHJoBBBHJoAAooJoooooCCFoGIDDFoGIEE', 24, 'hard'),
    ('BBBJoLCCIJoLAAIooMDDoooMHooKEEHFFKGG', 24, 'hard'),
    ('GooIBBGCCIKoAAHJKoDDHJEEFFFooooooooo', 22, 'hard'),
    ('ooGIBBooGIJKAAoIJKCCoDDLFoHooLFoHEEE', 25, 'hard'),
    ('HBBCCKHoDDDKoAAJoLoEEJoLooIFFFooIGGG', 22, 'hard'),
    ('BBBHJoooGHJoAAGoJooCCCooFDDIooFEEIoo', 21, 'hard'),
    ('GBBIoLGCCIKLAAHJKMDDHJKMoooEEEFFFooo', 19, 'hard'),
    ('BBooCCDDoooMAAJKoMEEJKooIoJLFFIGGLHH', 23, 'hard'),
    ('BBoIoJCCoIoJAAHIoKDDHooKGoHoooGEEFFo', 25, 'hard'),
    ('BBoJCCoooJoLAAoKoLDDIKEEHoIoFFHoIGGG', 22, 'hard'),
    ('BBBoKMoCCIKMAAHILMDDHJLoGooJEEGFFooo', 25, 'hard'),
    ('BBBIKMoCCIKMAAHoLNDDHoLNGEEJoNGFFJoo', 23, 'hard'),
    ('GoBBooGCCoooAAHIJLDDHIJLEEEIKMFFooKM', 24, 'hard'),
    ('GooBBKGooCCKHooAAKHoIJDDEEIJooFFFJoo', 25, 'hard'),
    ('GoBBooGCCIooAAHIJoDDHIJoEEEoKoFFooKo', 20, 'hard'),
    ('BBBoJoCCCoJoAAoIKLoDDIKLGoHIEEGoHFFo', 23, 'hard'),
    ('BBBCCLHoJooLHoJAALHDDoEEoIoKFFoIoKGG', 22, 'hard'),
    ('BBoooMHoJCCMHoJAANIDDLoNIoKLEEFFKGGo', 24, 'hard'),
    ('FooBBBFoGIJKAAGIJKooHCCLooHDDLooEEEL', 22, 'hard'),
    ('BBoCCCooooDDAAJKoLEEJKoLIoJFFMIGGHHM', 24, 'hard'),
    ('BBBoKLCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 20, 'hard'),
    ('BBBKCCoDDKLooAAKLoEEooFFIoJGGMIoJHHM', 19, 'hard'),
    ('ooGBBBooGIJKoAAIJKooHCCLFoHDDLFoEEEL', 25, 'hard'),
    ('BBCCLoHDDoLMHAAoLMHEEEoMoIJKFFoIJKGG', 25, 'hard'),
    ('ooBBBMooJCCMAAJKLNDDoKLNIEEFFNIGGGHH', 22, 'hard'),
    ('GoHIBBGoHIKLAAHJKLCCCJoLooooDDEEooFF', 19, 'hard'),
    ('ooBBBLCCIooLAAIJKMDDIJKMHoEEEoHFFGGo', 22, 'hard'),
    ('oHBBoLoHooKLAAooKLCCIJDDGoIJEEGoIFFF', 25, 'hard'),
    ('BBCCCoHDDJKLHAAJKLHEEFFLoIoooooIooGG', 20, 'hard'),
    ('BBCCKoGDDoKoGAAoKLGEEEoLoHIJFFoHIJoo', 24, 'hard'),
    ('BBBoKMoCCIKMAAHILoDDHJLoGooJEEGFFooo', 25, 'hard'),
    ('GoHBBoGoHIKLAAHIKLCCCooLoooJDDEEoJFF', 22, 'hard'),
    ('BBBJoMCCoJLMAAIKLNDDIKoNHoooEEHFFoGG', 23, 'hard'),
    ('BBCCLoHDDoLoHAAoLMHEEEoMoIJKFFoIJKGG', 25, 'hard'),
    ('ooBBBKoooIoKFAAIJLFGHIJLFGHoCCDDDoEE', 24, 'hard'),
    ('GBBIKoGCCIKoAAHJLMDDHJLMEEEooNoFFooN', 21, 'hard'),
    ('BBBKCCoDDKLooAAKLMIooEEMIoJFFNGGJHHN', 19, 'hard'),
    ('BBBoooooHIKLAAHIKLoCCCoLGDDJooGEEJFF', 22, 'hard'),
    ('HBBCCoHooJKoHAAJKoDDDoKoooIoEEFFIoGG', 23, 'hard'),
    ('BBoCCoGDDoKoGAAoKoGEEEKooHIJoooHIJFF', 20, 'hard'),
    ('oooHJKBBBHJKAAGoJKCCGoooFDDIooFEEIoo', 19, 'hard'),
    ('FoBBooFCCoooAAGHIoDDGHIoEEEHJoooooJo', 20, 'hard'),
    ('oooHoJBBBHoJAAGIoJCCGIooFDDoooFEEooo', 19, 'hard'),
    ('FoGBBoFoGHoJAAGHoJCCCooJoooIDDoooIEE', 20, 'hard'),
    ('HooJBBHCCJLoAAIoLoDDIKEEFFFKoooooGGG', 21, 'hard'),
    ('BBBIKoCCCIKLAAHJKLDDHJooGEEoooGoooFF', 23, 'hard'),
    ('GoBBooGoooCCAAHIJLDDHIJLEEEIKoFFFoKo', 24, 'hard'),
    ('BBCCooGooIJKGAAIJKGDDDJoooHoooEEHoFF', 19, 'hard'),
    ('oBBCCLooDDDLoAAJKMoEEJKMHoIFFFHoIGGG', 22, 'hard'),
    ('GoHBBLGoHIKLAAHIKLCCCooooooJDDEEoJFF', 23, 'hard'),
    ('FoBBooFooHCCAAGHIKDDGHIKEEEoJLooooJL', 25, 'hard'),
    ('ooooIKoBBBIKAAoHJLoCCHJLFoGHDDFoGEEo', 24, 'hard'),
    ('ooGBBBooGIoJoAAIoJooHCCKFoHDDKFoEEEK', 24, 'hard'),
    ('GooBBoGooICCAAHIJoDDHIJoEEEoKoFFFoKo', 25, 'hard'),
    ('BBCCJoooooJKGAAoJKGDDDooGoHIEEFFHIoo', 25, 'hard'),
    ('BBHCCKooHIoKAAHIoKDDoJooGooJEEGooFFF', 23, 'hard'),
    ('BBBoJoCCCoJLAAHIKLDDHIKLGooIEEGFFooo', 20, 'hard'),
    ('BBBoooooGHoKAAGHoKoCCCoKFDDIJoFEEIJo', 19, 'hard'),
    ('BBJCCMIoJDDMIAALoNIEELoNooKoFFGGKoHH', 19, 'hard'),
    ('ooBBBMooJCCMAAJKLNDDoKLNIEEFFNIGGHHH', 22, 'hard'),
    ('BBCCKoGoooKLGAAoKLGDDDoLoHIJEEoHIJFF', 24, 'hard'),
    ('BBooJLCCCIJLAAHIKMDDHIKMGEEoooGFFooo', 20, 'hard'),
    ('BBCCJoFoooJoFAAoJKFoDDDKoGHIoKoGHIEE', 24, 'hard'),
    ('GoBBJLGCCIJLAAHIKMDDHIKMEEEoooFFoooo', 19, 'hard'),
    ('oBBBCCooDDDoAAIJKLEEIJKLHooFFMHGGGoM', 20, 'hard'),
    ('HBBCCLHDDoKLHAAoKLEEEoKoooIJFFGGIJoo', 21, 'hard'),
    ('BBCCKoGoDDKoGAAoKoGoEEEooHIJoooHIJFF', 24, 'hard'),
    ('BBBoooooGHJKAAGHJKoCCCJKFDDIooFEEIoo', 21, 'hard'),
    ('BBJCCCDDJKooAAJKoLoooEELHIoooLHIFFGG', 20, 'hard'),
    ('BBBKCCDDoKLMAAoKLMEEooFFIoJGGNIoJHHN', 23, 'hard'),
    ('BBBJoMCCoJLMAAIKLMDDIKooHEEoooHFFoGG', 22, 'hard'),
    ('HBBCCoHoooKoHAAoKooDDDKoooIJEEFFIJGG', 25, 'hard'),
    ('FooBBJFooHoJAAoHoJooGCCCooGIDDooGIEE', 23, 'hard'),
    ('ooBBBMooJCCMAAJKLNIDDKLNIEEFFNGGGoHH', 19, 'hard'),
    ('BBBooMoooCCMAAIJLoDDIJLNHEEKLNHFFKGG', 21, 'hard'),
    ('ooooIKBBBoIKAAGHJLCCGHJLFooHDDFEEooo', 20, 'hard'),
    ('IBBCCCIDDKLMoAAKLMEEoFFMooJGGoooJHHH', 23, 'hard'),
    ('GoIoBBGoIKLMGAAKLMoHCCCMoHJDDoEEJFFo', 19, 'hard'),
    ('oBBoKLCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 19, 'hard'),
    ('BBBCCLHDDJKLHAAJKMoEEJKMooIFFMooIGGG', 20, 'hard'),
    ('oBBBLMCCJKLMAAJKLMDDooooHIooEEHIFFGG', 24, 'hard'),
    ('ooBBBMoooCCMAAJKLNDDJKLNIEEFFNIGGHHH', 23, 'hard'),
    ('BBBIKLCCCIKLAAHJKLDDHJooGEEoooGoooFF', 23, 'hard'),
    ('BBBKCCDDJKLoAAJKLMoooEEMIooFFNIGGHHN', 24, 'hard'),
    ('GoBBooGooICCAAHIJoDDHIJoEEEoKoFFooKo', 23, 'hard'),
    ('HBBCCLHoDDDLAAIJKMEEIJKMoooFFFoooGGo', 25, 'hard'),
    ('BBoCCKDDHooKAAHooLGooEELGoIJFFGoIJoo', 24, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEooLoooFFF', 20, 'hard'),
    ('FGoBBBFGHooKooHAAKCCoDDKooIJEEooIJoo', 24, 'hard'),
    ('oBBBCCooDDDLAAIJKLEEIJKoHooFFMHGGGoM', 19, 'hard'),
    ('BBBJoLCCoJoLAAIKoLDDIKooHoooEEHFFoGG', 22, 'hard'),
    ('BBoCCLDDoooLAAIooMHoIEEMHoJKFFHoJKGG', 24, 'hard'),
    ('BBBIKMoCCIKMAAHoLoDDHJLoGooJEEGFFooo', 24, 'hard'),
    ('GHoBBBGHIooLooIAALCCoDDLooJKEEooJKFF', 25, 'hard'),
    ('ooGBBBooGoJKooAAJKoFHCCKoFHIDDEEEIoo', 21, 'hard'),
    ('FoBBooFCCHooAAGHIKDDGHIKEEEoJoooooJo', 20, 'hard'),
    ('EooBBJEooGIJoAAGIJooFCCCooFHDDooFHoo', 24, 'hard'),
    ('GIJKBBGIJKCCHAAooLHooooLHoDDDMEEEFFM', 22, 'hard'),
    ('ooBBBKCCIooKAAIJoLDDIJoLHoEEEoHFFGGG', 20, 'hard'),
    ('BBBIoLCCHIoLAAHoooGDDoooGEEJKMFFoJKM', 19, 'hard'),
    ('GoBBJoGCCIJoAAHIooDDHIooEEEoKoFFFoKo', 20, 'hard'),
    ('FoGHBBFoGHJKAAGoJKCCCooKoooIDDoooIEE', 19, 'hard'),
    ('GooBBLGooIKLAAoIKLooHCCCooHJDDEEHJFF', 25, 'hard'),
    ('FoBBBKFoHooKAAHooKoGICCooGIJDDEEEJoo', 24, 'hard'),
    ('BBBJoMCCoJoMAAIoooDDIoEEHFFKLNHGGKLN', 19, 'hard'),
    ('oooBBBooFGIJAAFGIJoCCCIJEDDHooEooHoo', 19, 'hard'),
    ('ooBBBKCCHooKAAHooKoooJDDGoIJEEGoIFFF', 20, 'hard'),
    ('ooHoBBooHJoKAAoJoKCCIJDDGoIEELGoFFFL', 20, 'hard'),
    ('BBHCCCooHJKLAAoJKLGDDEELGoIoooooIoFF', 22, 'hard'),
    ('ooBBBMooJCCMAAJKLNIDDKLNIEEFFNGGoHHH', 19, 'hard'),
    ('ooHBBBCCHIooAAHIoKoooDDKGooJoKGEEJFF', 24, 'hard'),
    ('ooBBBJoooooJFAAooKFGHIoKFGHICCDDDIEE', 22, 'hard'),
    ('BBBCCLDDooKLoAAoKMIooEEMIoJFFMGGJHHH', 21, 'hard'),
    ('GoBBJoGCCIJoAAHIoLDDHIoLEEEoKLFFooKo', 22, 'hard'),
    ('ooBBBMooJCCMAAJKLNIDDKLNIEEFFNoGGGHH', 20, 'hard'),
    ('oFoBBBoFGooJAAGooJCCoDDJooHIEEooHIoo', 21, 'hard'),
    ('BBooJoCCCoJLAAHIKLDDHIKLGooIEEGFFooo', 20, 'hard'),
    ('ooBBBLoooCCLAAIJKMDDIJKMHoIEEEHFFGGo', 25, 'hard'),
    ('BBBIKLoCCIKLAAHJKMDDHJoMGEEoooGFFooo', 22, 'hard'),
    ('oFBBBooFGooJooGAAJCCoDDJooHIEEooHIoo', 25, 'hard'),
    ('BBooJLCCCoJLAAoIKMoDDIKMGoHIEEGoHFFo', 25, 'hard'),
    ('BBBCCLHoJooLHoJAALHDDEEooIoKFFoIoKGG', 21, 'hard'),
    ('BBBCCLoDDJKLoAAJKMEEoJKMHoIFFMHoIGGG', 22, 'hard'),
    ('oooBBLoooIKLAAoIKLFGHJCCFGHJDDFEEEoo', 19, 'hard'),
    ('IBBCCCIDDKLMAAoKLMEEoFFMooJGGoooJHHH', 24, 'hard'),
    ('FoBBooFCCoooAAGHIKDDGHIKEEEHJKooooJo', 22, 'hard'),
    ('BBBIKoCCCIKoAAHoKoDDHoooGEEJooGFFJoo', 20, 'hard'),
    ('BBJKooooJKCCAAooLMHIDDLMHIEELNHFFGGN', 19, 'hard'),
    ('BBBJLMCCoJLMAAIKLMDDIKooHEEoooHFFoGG', 24, 'hard'),
    ('GoHBBLGoHoKLGAAoKLCCCoooooIJDDEEIJFF', 20, 'hard'),
    ('BBIoKLoHIoKLoHIAALCCoJDDGooJEEGooFFF', 20, 'hard'),
    ('BBoCCCHooooKHooAAKDDIEEKooIJFFooIJGG', 25, 'hard'),
    ('EoHIBBEGHIKLoGAAKLFoCCKMFooJoMFooJDD', 22, 'hard'),
    ('oBBCCMIDDKLMIAAKLMIEEELoooJoFFGGJHHo', 23, 'hard'),
    ('GoJKBBGoJKCCHoAALMHIooLMHIDDDNEEFFFN', 21, 'hard'),
    ('GBBCCoGDDoKoGAAoKLoEEEKLoHIJFFoHIJoo', 20, 'hard'),
    ('oBBBooCCIooLAAIJKLDDoJKLGHooKoGHEEFF', 20, 'hard'),
    ('BBCCLMooJoLMooJAAMDDoKEEIooKFFIGGHHH', 19, 'hard'),
    ('HBBCCoHDDDKLoAAoKLoEEoKMoIJFFMoIJGGG', 23, 'hard'),
    ('GIJKBBGIJKCCHoAALMHoooLMHoDDDNEEFFFN', 22, 'hard'),
    ('BBBCCMIDDEEMIAAKLNoFFKLNooJGGNooJHHH', 20, 'hard'),
    ('ooHBBoEoHJKLEAAJKLFoICCMFGIooMFGDDDM', 19, 'hard'),
    ('BBJCCMIoJDDMIAAooNIEEooNooKLFFGGKLHH', 20, 'hard'),
    ('BBJooMHoJCCMHooAANIDDLoNIoKLEEFFKGGo', 25, 'hard'),
    ('BBBCCMIDDEEMIAAKLNFFoKLNooJGGNooJHHH', 19, 'hard'),
    ('oBBBKoCCIJKoAAIJKLDDoooLoHEEoLoHFFGG', 24, 'hard'),
    ('oGBBBKoGoooKFoAAJLFoHIJLFoHICCDDDIEE', 21, 'hard'),
    ('oGBBBKoGHooKAAHooKCCoDDoooIJEEooIJFF', 20, 'hard'),
    ('ooBBKLoHooKLoHoAALCCIJDDGoIJEEGoIFFF', 22, 'hard'),
    ('ooBBBMCCoooMAAJKLNDDJKLNIEEFFNIGGHHH', 24, 'hard'),
    ('HBBCCoHDDJKoHAAJKoEEEoKoooIoooFFIoGG', 23, 'hard'),
    ('FGHBBLFGHoKLFAAoKLoooCCCooIJDDEEIJoo', 22, 'hard'),
    ('GHIKBBGHIKLMGoAALMooCCCMooJDDoEEJoFF', 23, 'hard'),
    ('BBCCLMIoooLMIAAooMDDJKEEooJKFFoGGGHH', 24, 'hard'),
    ('BBoCCCoooDDKAAoJoKEEIJoKHoIoFFHoIGGG', 20, 'hard'),
    ('BBBCCMDDJEEMAAJKLNFFoKLNIooGGNIooHHH', 25, 'hard'),
    ('oBBIKoCCCIKLAAHJKLDDHJooGEEoooGFFooo', 21, 'hard'),
    ('GooIBBGCCIKLAAHJKLDDHJEEFFFooooooooo', 23, 'hard'),
    ('BBBCCLooDDKLoAAJKMoEEJKMHoIFFMHoIGGG', 21, 'hard'),
    ('EooBBoEooGCCAAFGHJooFGHJDDDoIKooooIK', 23, 'hard'),
    ('ooBBBLCCIJoLAAIJKMDDIoKMHoEEEoHFFGGo', 21, 'hard'),
    ('oBBIKoCCCIKoAAHJKoDDHJooGEEoooGoooFF', 21, 'hard'),
    ('oGHIBBoGHIJLFoAAJLFoooKMFoCCKMDDDEEM', 21, 'hard'),
    ('HBBCCoHDDJKLHAAJKLoEEEKoooIoooFFIoGG', 23, 'hard'),
    ('oooBBJoooHoJoAAHoJooGCCCFoGIDDFoGIEE', 25, 'hard'),
    ('ooHBBBooHoKLAAooKLFGICCLFGIJDDEEEJoo', 23, 'hard'),
    ('GBBBCCGHIooKGHIAAKDDDooKoooJEEoooJFF', 24, 'hard'),
    ('BBCCKoGoooKoGAAoKLGoDDDLoHIJEEoHIJFF', 25, 'hard'),
    ('oBBIKLCCCIKLAAHoKLDDHoooGooJEEGooJFF', 24, 'hard'),
    ('FooBBoFooCCCAAHIoJDDHIoJGooIoKGEEEoK', 23, 'hard'),
    ('BBBIoLCCHIoLAAHooMGDDooMGEEJKoFFoJKo', 20, 'hard'),
    ('BBBooKCCCooKAAHIoKDDHIooGEEJooGFFJoo', 19, 'hard'),
    ('BBBIKMoCCIKMAAHoLMDDHoLoGEEJooGFFJoo', 21, 'hard'),
    ('oBBBKLCCIJKLAAIJKLooooDDoHooEEoHFFGG', 21, 'hard'),
    ('BBBIoLCCCIKLAAHoKLDDHoooGEEJooGFFJoo', 21, 'hard'),
    ('BBBIKMoCCIKMAAHJLNDDHJLNGEEoooGFFooo', 24, 'hard'),
    ('GoHBBKGoHIoKAAHIoKCCCooooooJDDEEoJFF', 22, 'hard'),
    ('IBBCCCIoDDDLAAJooLooJEEoFFFKooGGGKHH', 24, 'hard'),
    ('GoHoBBGoHIKLAAHIKLCCCooLoooJDDEEoJFF', 21, 'hard'),
    ('FGBBBKFGoIJKAAHIJLooHCCLooHDDLooEEEo', 19, 'hard'),
    ('BBCCKLHooJKLHAAJKLHDDDooooIoEEFFIGGo', 19, 'hard'),
    ('EoFBBoEoFGIJAAFGIJCCCooJoooHDDoooHoo', 20, 'hard'),
    ('BBoCCCooooDDAAoJoKEEIJoKHoIFFKHoIGGG', 23, 'hard'),
    ('oFGBBBoFGoIJooAAIJooHCCKooHDDKooEEEK', 23, 'hard'),
    ('BBBKCCDDJKLoAAJKLoEEooFFIGGooMIHHooM', 24, 'hard'),
    ('oooIBBooGIJKAAGIJKCCHDDLFoHooLFoEEEo', 22, 'hard'),
    ('BBCCooHooJKoHAAJKoHDDDKoooIoEEFFIoGG', 19, 'hard'),
    ('BBBIoLCCHIKLAAHJKMGDDJoMGEEoooFFoooo', 22, 'hard'),
    ('oFoBBBoFGoIJAAGoIJooHCCKooHDDKooEEEK', 21, 'hard'),
    ('BBBJoMCCIJoMAAIoooDDEEooHFFKLNHGGKLN', 21, 'hard'),
    ('BBCCCoIoDDKLIAAoKLEEJFFMooJGGMooHHHM', 23, 'hard'),
    ('BBCCKooDDoKoHAAoKoHEEEooHoIJFFGGIJoo', 25, 'hard'),
    ('BBBHJKooGHJKAAGoJKCCCoooFDDIooFEEIoo', 25, 'hard'),
    ('BBJKCCDDJKoMAAJooMEEooooIooLFFIGGLHH', 25, 'hard'),
    ('oBBCCLoDDoKLHAAoKLHEEEKoHoIJFFGGIJoo', 23, 'hard'),
    ('BBBoJLCCCoJLAAoIKMoDDIKMGoHIEEGoHFFo', 25, 'hard'),
    ('GoJoBBGoJoCCHAAKLMHIoKLMHIDDDNEEEFFN', 19, 'hard'),
    ('oBBoKMCCCoKMAAHILNDDHILNGEEJooGFFJoo', 24, 'hard'),
    ('BBoCCKooDDDKAAoIJLoEEIJLGoHFFFGoHooo', 19, 'hard'),
    ('BBBoJLCCCoJLAAHIKMDDHIKMGooIEEGFFooo', 22, 'hard'),
    ('BBBooKooGHJKAAGHJKoCCCooFDDIooFEEIoo', 21, 'hard'),
    ('ooHBBLooHoKLoAAoKLGoICCCGoIJDDGEEJFF', 24, 'hard'),
    ('HooJBBHCCJLoAAoKLoDDoKEEooIFFFooIGGG', 24, 'hard'),
    ('BBBHJoooGHJKAAGoJKCCCoooFDDIooFEEIoo', 23, 'hard'),
    ('oooHJKBBBHJKAAooJKCCooooFoGIDDFoGIEE', 24, 'hard'),
    ('HBBCCLHoDDDLAAoJKMEEoJKMooIFFFooIGGo', 24, 'hard'),
    ('BBCCoooDDoKLHAAoKLHEEEKoHoIJFFGGIJoo', 25, 'hard'),
    ('BBBoJLCCCoJLAAoIKMDDoIKMGoHIEEGoHFFo', 24, 'hard'),
    ('BBoJooooHJoKAAHJoKCCIDDoGoIEELGoFFFL', 24, 'hard'),
    ('FoBBBoFoGoIJAAGoIJooHCCKooHDDKooEEEK', 20, 'hard'),
    ('GBBCCJGoDDDJAAHIoKEEHIoKFFFooooooooo', 25, 'hard'),
    ('GBBCCoGoooJoGAAoJoDDDoJoooHIooEEHIFF', 23, 'hard'),
    ('FoBBKLFooJKLAAoJKMCCCooMGHIDDoGHIEEo', 22, 'hard'),
    ('ooBBBKooICCKAAIoJLDDIoJLHooEEEHFFGGo', 24, 'hard'),
    ('HBBCCoHDDJKLHAAJKLEEEoKoooIoFFGGIooo', 20, 'hard'),
    ('BBBIoLCCHIKLAAHJKMGDDJoMGoooEEFFoooo', 23, 'hard'),
    ('HBBCCoHDDoKoHAAoKoEEEoKoooIJFFGGIJoo', 20, 'hard'),
    ('BBBKCCDDJKLoAAJKLoEEFFooIGGooMIHHooM', 25, 'hard'),
    ('BBCCKoGHooKoGHAAKoGoDDDoooIJEEooIJFF', 25, 'hard'),
    ('GHIKBBGHIKLMGoAALMCCCooMooJoDDEEJoFF', 25, 'hard'),
    ('BBBIKLoooIKLAAHJoMCCHJoMGoooDDGEEFFF', 21, 'hard'),
    ('FBBoLMFooJLMAAoJoMGHIKCCGHIKDDGEEEoo', 21, 'hard'),
    ('oBBCCoGDDoKoGAAoKLGEEEKLoHIJoLoHIJFF', 21, 'hard'),
    ('GIJKBBGIJKCCHoAAoLHooooLHoDDDMEEFFFM', 21, 'hard'),
    ('oFGBBBoFGooJAAoooJCCoDDJooHIEEooHIoo', 22, 'hard'),
    ('oBBCCoGDDoKLGAAoKLGEEEKooHIJoooHIJFF', 20, 'hard'),
    ('oBBCCKooDDDKAAoIJLoEEIJLGoHFFFGoHooo', 20, 'hard'),
    ('oBBoKoCCCoKLAAHIKLDDHIooGEEJooGFFJoo', 19, 'hard'),
    ('FoBBooFCCHooAAGHIKDDGHIKEEEoJKooooJo', 21, 'hard'),
    ('oGHBBBoGHooKoooAAKCCoDDKooIJEEooIJFF', 24, 'hard'),
    ('GBBIoLGCCIKLAAHJKMDDHJKMEEEoooFFFooo', 20, 'hard'),
    ('GBBIooGCCIKLAAHoKLDDHJEEFFFJoooooooo', 19, 'hard'),
    ('HBBCCKHoDDDKoAAJoLEEoJoLooIFFFooIGGG', 23, 'hard'),
    ('GoBBBMGoCCLMAAooLNDDooLNHIJKEEHIJKFF', 21, 'hard'),
    ('BBCCCLIoDDKLIAAoKMEEJFFMooJGGMoooHHH', 20, 'hard'),
    ('FGBBBKFGoIJKoAAIJLooHCCLooHDDLooHEEE', 22, 'hard'),
    ('FoGoBBFoGHoJAAGHoJCCCooJoooIDDoooIEE', 19, 'hard'),
    ('ooHBBLooHoKLAAooKLGoICCCGoIJDDGEEJFF', 25, 'hard'),
    ('GoBBooGoooCCAAHIJoDDHIJoEEEIKoFFFoKo', 23, 'hard'),
    ('ooBBBMooJCCMAAJKLNIDDKLNIEEFFNoGGHHH', 20, 'hard'),
    ('oBBIoLCCCIKLAAHJKLDDHJooGEEoooGFFooo', 21, 'hard'),
    ('GoBBooGCCIooAAHIJLDDHIJLEEEoKLFFooKo', 23, 'hard'),
    ('GIJoBBGIJCCoHAAKoLHooKoLHoDDDMEEEFFM', 24, 'hard'),
    ('GooBBBGoJooLooJAALHCCDDLHIoKEEHIoKFF', 24, 'hard'),
    ('BBBHoKooGHJKAAGoJKoCCCooFDDIooFEEIoo', 22, 'hard'),
    ('BBBIoKCCHIoKAAHJoLDDoJoLGoooEEGooFFF', 25, 'hard'),
    ('HooJBBHCCJLMAAoKLMDDoKEEooIFFFooIGGG', 25, 'hard'),
    ('GoJBBNGoJKMNAAoKMNHIoLCCHIoLDDHEEEFF', 19, 'hard'),
    ('oBBBooCCIJoLAAIJKLDDooKLGHooKoGHEEFF', 19, 'hard'),
    ('GoJKBBGoJKCCHoAAoLHIoooLHIDDDMEEEFFM', 20, 'hard'),
    ('GoBBooGooICCAAHIJoDDHIJoEEEoKoFFFoKo', 24, 'hard'),
    ('BBJCCCDDJKoLAAJKoLEEooooIooFFMIGGHHM', 20, 'hard'),
    ('oBBCCJooDDDJAAoIoKoEEIoKGoHFFFGoHooo', 19, 'hard'),
    ('BBBIoLCCHIKLAAHoKMGooDDMGooJEEFFoJoo', 25, 'hard'),
    ('BBoCCoDDoJoKoAAJoKEEIooLHoIFFLHoIGGG', 21, 'hard'),
    ('FooBBMFooJLMAAoJLMGHIKCCGHIKDDGEEEoo', 19, 'hard'),
    ('ooBBBLCCIJKLAAIJKMDDIooMHoEEEoHFFGGo', 20, 'hard'),
    ('oBBIKoCCCIKLAAHoKLDDHoooGEEJooGFFJoo', 20, 'hard'),
    ('oooHoKBBBHJKAAooJKooooCCFoGIDDFoGIEE', 25, 'hard'),
    ('GoooBBGCCIKoAAHIKoDDHJEEFFFJoooooooo', 20, 'hard'),
    ('oGBBBJoGHIoJAAHIoKooHCCKFooDDKFooEEE', 24, 'hard'),
    ('BBHCCKooHDDKAAoJoLGEEJoLGoIoFFGoIooo', 19, 'hard'),
    ('BBoCCoHDDoLoHAAoLMHEEELMoIJKFFoIJKGG', 23, 'hard'),
    ('ooBBBKCCIoJKAAIoJLDDIooLHoEEEoHFFGGo', 19, 'hard'),
    ('oBBIKoCCCIKoAAHJKoDDHJooGEEoooGFFooo', 20, 'hard'),
    ('BBBoJKooGHJKAAGHJKoCCCooFDDIooFEEIoo', 23, 'hard'),
    ('BBBCCLoDDJKLAAIJKMEEIJKMHooFFMHGGGoo', 25, 'hard'),
    ('FHoBBLFHooKLAAooKLooICCCGoIJDDGoIJEE', 20, 'hard'),
    ('oHBBKLoHooKLAAoooLCCIJDDGoIJEEGoIFFF', 24, 'hard'),
    ('BBBIoLCCHIoLAAHJKMGDDJKMGEEooooooFFF', 23, 'hard'),
    ('oBBooMCCCooMAAHIKNDDHIKNGEEJLoGFFJLo', 22, 'hard'),
    ('oooBBBooHIKLAAHIKLoCCCoLGDDJooGEEJFF', 21, 'hard'),
    ('HBBCCoHooJKoHAAJKooDDDKoooIoEEFFIoGG', 22, 'hard'),
    ('ooGBBBooGooJAAoooJoFHCCJoFHIDDEEEIoo', 21, 'hard'),
    ('BBBIKLoCCIKLAAHoKMDDHooMGEEJooGFFJoo', 21, 'hard'),
    ('oGoBBBoGHooKooHAAKCCoDDKooIJEEooIJFF', 25, 'hard'),
    ('GBBIooGCCIooAAHJKLDDHJKLEEEoKMoFFooM', 23, 'hard'),
    ('HooJBBHCCJLoAAIKLoDDIKEEoooFFFoooGGo', 23, 'hard'),
    ('oGBBBJoGoIoJoAAIoKooHCCKFoHDDKFoHEEE', 22, 'hard'),
    ('BBoCCMDDoooMIoJAANIoJEENIoKLFFGGKLHH', 25, 'hard'),
    ('BBCCoMIDDKLMIAAKLMIEEELoooJoFFGGJHHo', 21, 'hard'),
    ('BBCCooGoooKoGAAoKLGDDDKLoHIJEEoHIJFF', 23, 'hard'),
    ('BBIJCCooIJoLooIAALDDoKEEHooKFFHooGGG', 19, 'hard'),
    ('BBooooooIJCCAAIJoKDDIJoKHooEELHFFGGL', 22, 'hard'),
    ('BBCCKoGDDoKLGAAoKLGoEEELoHIJFFoHIJoo', 25, 'hard'),
    ('BBoJCCDDoJoKoooAAKEEIooLHoIFFLHoIGGG', 24, 'hard'),
    ('FGoBBBFGHoJKAAHoJKooICCLooIDDLooEEEL', 21, 'hard'),
    ('oooHJKBBBHJKAAooJKooooCCFoGIDDFoGIEE', 25, 'hard'),
    ('GBBCCJGoDDDJoAAIoKEEoIoKooHFFFooHooo', 22, 'hard'),
    ('ooBBBJoooooJFoAAoKFGHIoKFGHICCDDDIEE', 21, 'hard'),
    ('oBBCCooDDDKLoAAoKLoEEoKMHIJFFMHIJGGG', 22, 'hard'),
    ('GoBBJoGCCIJoAAHIKLDDHIKLEEEooLFFFooo', 21, 'hard'),
    ('BBBCCLoDDJKLAAIJKMEEIJKMHooFFMHooGGG', 24, 'hard'),
    ('BBBoJoCCCoJoAAHIKLDDHIKLGooIEEGooFFo', 21, 'hard'),
    ('oGHBBLoGHIJLFAAIJoFoooKMFoCCKMDDEEEM', 25, 'hard'),
    ('ooBBBKooICCKAAIJoLDDIJoLHEEEooHFFGGo', 25, 'hard'),
    ('HBBCCoHooJKLHAAJKLDDDoKoooIoEEFFIoGG', 24, 'hard'),
    ('ooBBBKooICCKAAIoJLDDIoJLHEEEooHFFGGo', 25, 'hard'),
    ('oBBBCCooIDDDAAIJoLoEEJoLHFFoKMHGGGKM', 25, 'hard'),
    ('BBBJoMCCoJLMAAIKLMDDIKooHoooEEHFFoGG', 23, 'hard'),
    ('GoBBBMGoCCLMooAALNDDooLNHIJKEEHIJKFF', 20, 'hard'),
    ('BBCCLMooJoLMooJAAMoDDKEEIooKFFIGGHHH', 20, 'hard'),
    ('oBBCCoHDDJKoHAAJKoHEEEKoooIoooFFIoGG', 21, 'hard'),
    ('oooHJoBBBHJoAAooJoCCooooFoGIDDFoGIEE', 23, 'hard'),
    ('FoBBooFCCHooAAGHIoDDGHIoEEEoJoooooJo', 19, 'hard'),
    ('BBBIoKCCCIoKAAHJoKDDHJooGEEoooGoooFF', 22, 'hard'),
    ('BBoCCoGDDoKLGAAoKLGEEEKLoHIJFFoHIJoo', 22, 'hard'),
    ('oHIBBMoHIoLMGAAoLNGCCooNGoJKDDEEJKFF', 21, 'hard')
ON CONFLICT (board_string) DO NOTHING;

-- Replace any non-hard challenges from today onward, then populate 365 days ahead
DELETE FROM public.daily_challenges
WHERE challenge_date >= CURRENT_DATE AND difficulty <> 'hard';

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
        AND public.is_clean_player_name(username)
    );

CREATE OR REPLACE FUNCTION public.enforce_player_profile_username()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW.username IS NULL OR NOT public.is_clean_player_name(NEW.username) THEN
        RAISE EXCEPTION 'Please choose an appropriate nickname without restricted words.'
            USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_player_profile_username ON public.player_profiles;
CREATE TRIGGER trg_enforce_player_profile_username
    BEFORE INSERT OR UPDATE OF username ON public.player_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_player_profile_username();

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

-- 7.3 RPC: delete_my_account (App Store / Google Play cloud account deletion)
-- Permanently deletes all cloud records for the authenticated non-anonymous
-- caller and removes their auth.users record.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_is_anonymous BOOLEAN := COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required to delete account.'
            USING ERRCODE = '42501';
    END IF;

    IF v_is_anonymous THEN
        RAISE EXCEPTION 'Only recoverable non-anonymous accounts can be deleted.'
            USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.player_level_progress WHERE user_id = v_uid;
    DELETE FROM public.player_profiles WHERE user_id = v_uid;
    DELETE FROM public.leaderboard_scores WHERE user_id = v_uid;
    DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
