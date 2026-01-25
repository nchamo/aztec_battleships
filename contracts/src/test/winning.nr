use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST, TURN_TIMEOUT};
use crate::test::utils::{create_valid_ships, create_valid_ships_player2, get_ship_cells};

// ============================================================================
// Combat Win Tests
// ============================================================================

// Test where host wins by destroying all of guest's ships
#[test]
unconstrained fn test_host_wins_by_sinking_all_ships() {
    std::println("=== TEST: Host Wins by Combat ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100001);

    // Create ship placements
    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    // Setup: Host creates game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    // Verify game status is CREATED
    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    // Guest joins with initial shot
    std::println("Guest joins game");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: 0, y: 0 }  // Hits host's carrier
        )
    );

    // Verify game status is ACTIVE after guest joins
    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    // Guest's ships are at specific locations based on create_valid_ships_player2()
    // We need to hit all 17 cells: carrier(5), battleship(4), cruiser(3), submarine(3), destroyer(2)
    // Calculate all guest ship cells from the placement
    let guest_ship_cells = get_ship_cells(guest_ships);

    let mut turn = 2;

    // Coordinates where guest can miss (away from host ships)
    // Host ships are at: carrier(0,0)-(4,0), battleship(0,1)-(3,1), cruiser(0,2)-(2,2),
    //                    submarine(0,3)-(2,3), destroyer(0,4)-(1,4)
    let guest_miss_coords: [(u8, u8); 17] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9), (8, 8),
    ];

    // Host and guest alternate shots
    // Host hits, guest misses
    for i in 0..17 {
        std::println("Turn: ");
        std::println(turn);

        // Host shoots at guest's ship
        std::println("  Host shoots at guest ship cell");
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_ship_cells[i].0, y: guest_ship_cells[i].1 }
            )
        );

        turn += 1;

        // Guest shoots somewhere that misses (away from host ships)
        std::println("  Guest shoots and misses");
        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_miss_coords[i].0, y: guest_miss_coords[i].1 }
            )
        );

        turn += 1;

        // Verify game is still ACTIVE (unless this was the last hit)
        if i < 16 {
            let mid_game_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
            assert(mid_game_status == STATUS_ACTIVE, "Game should remain ACTIVE during play");
        }
    }

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    std::println("\n=== SUCCESS: Host won by combat! ===");
}

// Test where guest wins by destroying all of host's ships
#[test]
unconstrained fn test_guest_wins_by_sinking_all_ships() {
    std::println("=== TEST: Guest Wins by Combat ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100002);

    // Create ship placements
    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    // Setup
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    // Verify game status is CREATED
    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    // Host's ships are at specific locations based on create_valid_ships()
    // Calculate all host ship cells from the placement
    let host_ship_cells = get_ship_cells(host_ships);

    // Guest joins with initial shot hitting first host ship cell
    std::println("Guest joins and hits host's first ship cell");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: host_ship_cells[0].0, y: host_ship_cells[0].1 }
        )
    );

    // Verify game status is ACTIVE after guest joins
    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    // Coordinates where host can miss (away from guest ships)
    // Guest ships are at: carrier(5,5)-(5,9), battleship(6,5)-(6,8), cruiser(7,5)-(7,7),
    //                     submarine(8,5)-(8,7), destroyer(9,5)-(9,6)
    let host_miss_coords: [(u8, u8); 16] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9),
    ];

    let mut turn = 2;

    // Now guest needs to hit the remaining 16 cells
    // Host shoots and misses, guest hits
    for i in 1..17 {
        std::println("Turn: ");
        std::println(turn);

        // Host shoots somewhere that misses
        std::println("  Host shoots and misses");
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: host_miss_coords[i - 1].0, y: host_miss_coords[i - 1].1 }
            )
        );

        turn += 1;

        // Guest shoots at host's ship
        std::println("  Guest shoots at host ship cell");
        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: host_ship_cells[i].0, y: host_ship_cells[i].1 }
            )
        );

        turn += 1;

        // Verify game is still ACTIVE during play
        if i < 15 {
            let mid_game_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
            assert(mid_game_status == STATUS_ACTIVE, "Game should remain ACTIVE during play");
        }
    }

    // Host needs to take one more turn to verify the last guest shot and realize they lost
    std::println("\nTurn: ");
    std::println(turn);
    std::println("  Host takes final turn and realizes all ships are sunk");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(
            game_id,
            turn,
            Shot { x: 7, y: 9 }  // Any miss location
        )
    );

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_GUEST, "Game should be won by guest");

    std::println("\n=== SUCCESS: Guest won by combat! ===");
}

// ============================================================================
// Abandonment Win Tests
// ============================================================================

// Test where host wins because guest abandons (doesn't shoot within timeout)
#[test]
unconstrained fn test_host_wins_by_guest_abandonment() {
    std::println("=== TEST: Host Wins by Guest Abandonment ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100003);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Verify game status is CREATED
    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    std::println("Guest joins game with initial shot");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // Verify game status is ACTIVE after guest joins
    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    // Host takes their turn
    std::println("Host shoots (turn 2)");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    let host_shot_time = env.last_block_timestamp();
    std::println("Host shot at timestamp: ");
    std::println(host_shot_time);

    // Now it's guest's turn (turn 3), but guest doesn't shoot
    // Advance time by more than TURN_TIMEOUT (24 hours = 86400 seconds)
    std::println("\nAdvancing time beyond TURN_TIMEOUT...");
    std::println("TURN_TIMEOUT = ");
    std::println(TURN_TIMEOUT);
    std::println(" seconds");

    let timeout_timestamp = host_shot_time + TURN_TIMEOUT + 3600; // Add 1 hour buffer
    std::println("Mining block at timestamp: ");
    std::println(timeout_timestamp);

    env.mine_block_at(timeout_timestamp);

    // Host claims abandonment
    // After host shot (turn 2), it's guest's turn (turn 3), but guest didn't shoot
    // So host claims abandonment on turn 3
    std::println("\nHost claims abandonment (guest failed to shoot within 24h)");
    env.call_private(
        host,
        Battleships::at(contract_address).claim_abandonment(game_id, 3)
    );

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    std::println("\n=== SUCCESS: Host won by guest abandonment! ===");
}

// Test where guest wins because host abandons (doesn't shoot within timeout)
#[test]
unconstrained fn test_guest_wins_by_host_abandonment() {
    std::println("=== TEST: Guest Wins by Host Abandonment ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100004);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Verify game status is CREATED
    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    std::println("Guest joins game with initial shot");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // Verify game status is ACTIVE after guest joins
    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    let guest_shot_time = env.last_block_timestamp();
    std::println("Guest joined at timestamp: ");
    std::println(guest_shot_time);

    // Now it's host's turn (turn 2), but host doesn't shoot
    // Advance time by more than TURN_TIMEOUT (24 hours = 86400 seconds)
    std::println("\nAdvancing time beyond TURN_TIMEOUT...");
    std::println("TURN_TIMEOUT = ");
    std::println(TURN_TIMEOUT);
    std::println(" seconds");

    let timeout_timestamp = guest_shot_time + TURN_TIMEOUT + 3600; // Add 1 hour buffer
    std::println("Mining block at timestamp: ");
    std::println(timeout_timestamp);

    env.mine_block_at(timeout_timestamp);

    // Guest claims abandonment
    // After guest joined (turn 1), it's host's turn (turn 2), but host didn't shoot
    // So guest claims abandonment on turn 2
    std::println("\nGuest claims abandonment (host failed to shoot within 24h)");
    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 2)
    );

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_GUEST, "Game should be won by guest");

    std::println("\n=== SUCCESS: Guest won by host abandonment! ===");
}

// ============================================================================
// Abandonment Failure Tests
// ============================================================================

// Test that a player cannot claim abandonment before the timeout period
#[test(should_fail_with = "Opponent still has time to play")]
unconstrained fn test_claim_abandonment_too_early_fails() {
    std::println("=== TEST: Claim Abandonment Too Early (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200004);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    let join_time = env.last_block_timestamp();

    // After guest joins, it's host's turn
    // Host doesn't shoot, guest tries to claim abandonment too early

    // Advance time, but NOT enough (only 12 hours instead of 24)
    std::println("\nAdvancing time by 12 hours (TURN_TIMEOUT requires 24h)");
    let early_timestamp = join_time + (TURN_TIMEOUT / 2); // Only half the timeout
    std::println("Timestamp: ");
    std::println(early_timestamp);

    env.mine_block_at(early_timestamp);

    std::println("Guest attempts to claim abandonment after only 12h (needs 24h)");

    // This should fail with "Opponent did not abandon"
    // because not enough time has passed
    // After guest joined (turn 1), it's host's turn (turn 2)
    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 2)
    );

    std::println("ERROR: Should not reach here!");
}

// Test that a player cannot claim abandonment when the opponent just acted
// The timeout check should fail because the opponent's action is recent
#[test(should_fail)]
unconstrained fn test_claim_abandonment_when_opponent_just_acted_fails() {
    std::println("=== TEST: Claim Abandonment When Opponent Just Acted (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200005);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // After guest joins with turn 1, it's host's turn (turn 2)
    // Host shoots
    std::println("Host shoots (turn 2)");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    // Now it's guest's turn (turn 3), but guest tries to claim abandonment
    // This should fail because host just acted, so the timeout hasn't been reached
    std::println("Guest tries to claim abandonment immediately after host's turn");

    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 3)
    );

    std::println("ERROR: Should not reach here!");
}
