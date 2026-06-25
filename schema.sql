-- 1. Create Tables

CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code VARCHAR(6) UNIQUE NOT NULL,
    admin_id UUID NOT NULL,
    total_rounds INT NOT NULL DEFAULT 5,
    current_round INT NOT NULL DEFAULT 1,
    game_state VARCHAR(20) NOT NULL DEFAULT 'LOBBY', -- 'LOBBY', 'PLAYING', 'ROUND_END', 'FINISHED'
    searcher_card VARCHAR(30) DEFAULT 'KING',
    target_card VARCHAR(30) DEFAULT 'QUEEN',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    name VARCHAR(50) NOT NULL,
    gender VARCHAR(10) NOT NULL, -- 'MALE' or 'FEMALE'
    points INT DEFAULT 0,
    current_card VARCHAR(30),
    is_revealed BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,
    join_order SERIAL,
    joined_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Disable Row Level Security (RLS) for simple guest access
ALTER TABLE rooms DISABLE ROW LEVEL SECURITY;
ALTER TABLE players DISABLE ROW LEVEL SECURITY;

-- 3. Enable real-time sync for rooms and players
DO $$
BEGIN
    -- Check if rooms is already in supabase_realtime publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'rooms'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE rooms;
    END IF;

    -- Check if players is already in supabase_realtime publication
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'players'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE players;
    END IF;
END;
$$;

-- 4. Card Hierarchy Helper Function
CREATE OR REPLACE FUNCTION get_next_card(p_card VARCHAR, p_player_count INT)
RETURNS VARCHAR AS $$
DECLARE
    v_deck VARCHAR[];
    v_idx INT;
BEGIN
    IF p_card = 'KING' THEN
        RETURN 'QUEEN';
    END IF;

    -- Build the active deck array dynamically based on player count
    -- Base deck starts with QUEEN
    v_deck := ARRAY['QUEEN'];
    
    -- Add intermediate cards based on player count
    IF p_player_count >= 5 THEN
        v_deck := array_append(v_deck, 'PRINCE');
    END IF;
    IF p_player_count >= 6 THEN
        v_deck := array_append(v_deck, 'COMMANDER');
    END IF;
    IF p_player_count >= 7 THEN
        v_deck := array_append(v_deck, 'MINISTER');
    END IF;
    IF p_player_count >= 8 THEN
        v_deck := array_append(v_deck, 'SOLDIER');
    END IF;
    IF p_player_count >= 9 THEN
        v_deck := array_append(v_deck, 'MERCHANT');
    END IF;
    IF p_player_count >= 10 THEN
        v_deck := array_append(v_deck, 'CITIZEN');
    END IF;

    -- Deck always ends with POLICE and THIEF
    v_deck := array_append(v_deck, 'POLICE');
    v_deck := array_append(v_deck, 'THIEF');

    -- Find index of p_card in v_deck
    FOR i IN 1..array_length(v_deck, 1) LOOP
        IF v_deck[i] = p_card THEN
            v_idx := i;
            EXIT;
        END IF;
    END LOOP;

    -- If found and has a next card, return it
    IF v_idx IS NOT NULL AND v_idx < array_length(v_deck, 1) THEN
        RETURN v_deck[v_idx + 1];
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. Cleanup Old Rooms Function (> 24 hours old)
CREATE OR REPLACE FUNCTION cleanup_old_rooms()
RETURNS void AS $$
BEGIN
    DELETE FROM rooms WHERE created_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Try to schedule with pg_cron if extension is available
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('cleanup-rooms-job', '0 * * * *', 'SELECT cleanup_old_rooms();');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
$$;

-- 6. Start Round function (Admin triggers this)
CREATE OR REPLACE FUNCTION start_round(p_room_id UUID)
RETURNS void AS $$
DECLARE
    v_player_count INT;
    v_cards VARCHAR[];
    v_temp_record RECORD;
    v_shuffled_cards VARCHAR[];
    v_card VARCHAR;
BEGIN
    -- 1. Delete rooms older than 24 hours as a fallback cleanup
    PERFORM cleanup_old_rooms();

    -- 2. Count players in the room
    SELECT COUNT(*) INTO v_player_count FROM players WHERE room_id = p_room_id;

    IF v_player_count < 4 THEN
        RAISE EXCEPTION 'At least 4 players are required to start the game';
    END IF;

    -- 3. Define cards deck based on player count
    IF v_player_count = 4 THEN
        v_cards := ARRAY['KING', 'QUEEN', 'POLICE', 'THIEF'];
    ELSIF v_player_count = 5 THEN
        v_cards := ARRAY['KING', 'QUEEN', 'PRINCE', 'POLICE', 'THIEF'];
    ELSIF v_player_count = 6 THEN
        v_cards := ARRAY['KING', 'QUEEN', 'PRINCE', 'COMMANDER', 'POLICE', 'THIEF'];
    ELSIF v_player_count = 7 THEN
        v_cards := ARRAY['KING', 'QUEEN', 'PRINCE', 'COMMANDER', 'MINISTER', 'POLICE', 'THIEF'];
    ELSIF v_player_count = 8 THEN
        v_cards := ARRAY['KING', 'QUEEN', 'PRINCE', 'COMMANDER', 'MINISTER', 'SOLDIER', 'POLICE', 'THIEF'];
    ELSIF v_player_count = 9 THEN
        v_cards := ARRAY['KING', 'QUEEN', 'PRINCE', 'COMMANDER', 'MINISTER', 'SOLDIER', 'MERCHANT', 'POLICE', 'THIEF'];
    ELSE -- 10 or more players (capped at 10 in UI)
        v_cards := ARRAY['KING', 'QUEEN', 'PRINCE', 'COMMANDER', 'MINISTER', 'SOLDIER', 'MERCHANT', 'CITIZEN', 'POLICE', 'THIEF'];
    END IF;

    -- 4. Shuffle the deck using postgres random order
    SELECT array_agg(c ORDER BY random())
    INTO v_shuffled_cards
    FROM unnest(v_cards) AS c;

    -- 5. Assign cards to players sequentially by join_order
    FOR v_temp_record IN 
        SELECT id, row_number() OVER (ORDER BY join_order) as rn 
        FROM players 
        WHERE room_id = p_room_id
    LOOP
        v_card := v_shuffled_cards[v_temp_record.rn];
        
        -- The player holding KING is revealed by default, but no one is locked initially
        UPDATE players
        SET current_card = v_card,
            is_revealed = (v_card = 'KING'),
            is_locked = FALSE
        WHERE id = v_temp_record.id;
    END LOOP;

    -- 6. Initialize Room Game State
    UPDATE rooms
    SET game_state = 'PLAYING',
        searcher_card = 'KING',
        target_card = 'QUEEN',
        current_round = CASE WHEN game_state = 'LOBBY' THEN 1 ELSE current_round + 1 END
    WHERE id = p_room_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Guess Card function (Active searcher triggers this)
CREATE OR REPLACE FUNCTION guess_card(
    p_room_id UUID,
    p_searcher_player_id UUID,
    p_suspect_player_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_player_count INT;
    v_searcher_card VARCHAR;
    v_suspect_card VARCHAR;
    v_expected_target VARCHAR;
    v_next_target VARCHAR;
    v_is_correct BOOLEAN;
    v_searcher_name VARCHAR;
    v_suspect_name VARCHAR;
    v_current_round INT;
    v_total_rounds INT;
    v_next_round_state VARCHAR;
    v_new_king_name VARCHAR;
    v_unlocked_player_ids UUID[];
    v_shuffled_unlocked_cards VARCHAR[];
BEGIN
    -- Get player count and room details
    SELECT COUNT(*), MAX(r.target_card), MAX(r.searcher_card), MAX(r.current_round), MAX(r.total_rounds)
    INTO v_player_count, v_expected_target, v_searcher_card, v_current_round, v_total_rounds
    FROM players p
    JOIN rooms r ON p.room_id = r.id
    WHERE r.id = p_room_id;

    -- Get searcher and suspect details
    SELECT current_card, name INTO v_searcher_card, v_searcher_name FROM players WHERE id = p_searcher_player_id;
    SELECT current_card, name INTO v_suspect_card, v_suspect_name FROM players WHERE id = p_suspect_player_id;

    -- Check if suspect's card is correct
    IF v_suspect_card = v_expected_target THEN
        v_is_correct := TRUE;
    ELSE
        v_is_correct := FALSE;
    END IF;

    IF v_is_correct THEN
        -- 1. CORRECT GUESS
        -- Lock the searcher player (they found the correct card!)
        UPDATE players
        SET is_locked = TRUE,
            is_revealed = TRUE
        WHERE id = p_searcher_player_id;

        -- Reveal the suspect player (they are found, but not locked)
        UPDATE players
        SET is_revealed = TRUE,
            is_locked = FALSE
        WHERE id = p_suspect_player_id;

        -- Check if we just caught the Thief
        IF v_expected_target = 'THIEF' THEN
            -- Update points for all players based on their current cards
            UPDATE players
            SET points = points + CASE current_card
                WHEN 'KING' THEN 1000
                WHEN 'QUEEN' THEN 900
                WHEN 'PRINCE' THEN 800
                WHEN 'COMMANDER' THEN 700
                WHEN 'MINISTER' THEN 600
                WHEN 'SOLDIER' THEN 500
                WHEN 'MERCHANT' THEN 300
                WHEN 'CITIZEN' THEN 200
                WHEN 'POLICE' THEN 100
                ELSE 0 -- Thief gets 0
            END
            WHERE room_id = p_room_id;

            -- Check if it was the final round
            IF v_current_round >= v_total_rounds THEN
                v_next_round_state := 'FINISHED';
            ELSE
                v_next_round_state := 'ROUND_END';
            END IF;

            -- Update Room State
            UPDATE rooms
            SET game_state = v_next_round_state
            WHERE id = p_room_id;

            RETURN json_build_object(
                'success', TRUE,
                'correct', TRUE,
                'message', 'Thief caught! Round ends.',
                'round_ended', TRUE,
                'next_state', v_next_round_state
            );
        ELSE
            -- Move the searcher role to the newly locked card, and set the next target card
            v_next_target := get_next_card(v_expected_target, v_player_count);
            
            UPDATE rooms
            SET searcher_card = v_expected_target,
                target_card = v_next_target
            WHERE id = p_room_id;

            RETURN json_build_object(
                'success', TRUE,
                'correct', TRUE,
                'message', concat(v_suspect_name, ' is indeed the ', v_expected_target, '! Now ', v_suspect_name, ' searches for the ', v_next_target),
                'round_ended', FALSE
            );
        END IF;
    ELSE
        -- 2. INCORRECT GUESS

        -- GUARD: Reject guess if suspect is already correctly identified (locked).
        -- The UI already prevents this, but enforce it server-side as well.
        IF EXISTS (SELECT 1 FROM players WHERE id = p_suspect_player_id AND is_locked = TRUE) THEN
            RETURN json_build_object(
                'success', FALSE,
                'correct', FALSE,
                'message', 'That player has already been identified and cannot be suspected.'
            );
        END IF;

        -- Swap current_card between searcher and suspect
        UPDATE players
        SET current_card = v_suspect_card,
            is_revealed = (v_suspect_card = 'KING'),
            is_locked = FALSE
        WHERE id = p_searcher_player_id;

        UPDATE players
        SET current_card = v_searcher_card,
            is_revealed = (v_searcher_card = 'KING'),
            is_locked = FALSE
        WHERE id = p_suspect_player_id;

        -- Make sure the player holding the KING card is revealed
        UPDATE players
        SET is_revealed = TRUE
        WHERE room_id = p_room_id AND current_card = 'KING';

        RETURN json_build_object(
            'success', TRUE,
            'correct', FALSE,
            'message', concat('Incorrect! ', v_suspect_name, ' was not the ', v_expected_target, '. ', v_searcher_name, ' and ', v_suspect_name, ' swapped cards! Now ', v_suspect_name, ' continues searching.'),
            'round_ended', FALSE
        );
    END IF;
END;
$$ LANGUAGE plpgsql;
