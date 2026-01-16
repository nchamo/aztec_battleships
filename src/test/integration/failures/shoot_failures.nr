use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_WON_BY_HOST};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2, get_ship_cells};

// Test that a player cannot shoot when it's not their turn
#[test(should_fail)]
unconstrained fn test_shoot_out_of_turn_fails() {
    std::println("=== TEST: Shoot Out of Turn (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200002);

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

    // After guest joins, it's host's turn (turn 2)
    // But guest tries to shoot again immediately

    std::println("Guest attempts to shoot again (but it's host's turn)");

    // This should fail with "Not my turn"
    env.call_private(
        guest,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 1, y: 1 })
    );

    std::println("ERROR: Should not reach here!");
}

// Test that a player cannot shoot twice in a row
#[test(should_fail)]
unconstrained fn test_shoot_twice_in_row_fails() {
    std::println("=== TEST: Shoot Twice in a Row (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200003);

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

    // Host takes their turn
    std::println("Host shoots (turn 2)");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    // Host tries to shoot again immediately
    std::println("Host attempts to shoot twice in a row (turn 3 is guest's turn)");

    // This should fail with "Not my turn"
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 3, Shot { x: 6, y: 6 })
    );

    std::println("ERROR: Should not reach here!");
}

// Test that shooting at invalid coordinates (out of bounds) fails
#[test(should_fail_with = "Shot x out of bounds")]
unconstrained fn test_shoot_invalid_x_coordinate_fails() {
    std::println("=== TEST: Shoot Invalid X Coordinate (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200006);

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

    // Host tries to shoot at x=10 (out of bounds, valid range is 0-9)
    std::println("Host attempts to shoot at x=10 (out of bounds)");

    // This should fail with "Shot x out of bounds"
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 10, y: 5 })
    );

    std::println("ERROR: Should not reach here!");
}

#[test(should_fail_with = "Shot y out of bounds")]
unconstrained fn test_shoot_invalid_y_coordinate_fails() {
    std::println("=== TEST: Shoot Invalid Y Coordinate (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200007);

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

    // Host tries to shoot at y=15 (out of bounds, valid range is 0-9)
    std::println("Host attempts to shoot at y=15 (out of bounds)");

    // This should fail with "Shot y out of bounds"
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 15 })
    );

    std::println("ERROR: Should not reach here!");
}

// Test that a player cannot shoot the same coordinate twice
#[test(should_fail)]
unconstrained fn test_shoot_same_coordinate_twice_fails() {
    std::println("=== TEST: Shoot Same Coordinate Twice (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200008);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game with shot at (0,0)");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // Host shoots at (5,5)
    std::println("Host shoots at (5,5) - turn 2");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    // Guest shoots at (3,3)
    std::println("Guest shoots at (3,3) - turn 3");
    env.call_private(
        guest,
        Battleships::at(contract_address).shoot(game_id, 3, Shot { x: 3, y: 3 })
    );

    // Host tries to shoot at (5,5) again (same coordinate as before)
    std::println("Host attempts to shoot at (5,5) AGAIN - turn 4");

    // This should fail with "Already shot this position"
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 4, Shot { x: 5, y: 5 })
    );

    std::println("ERROR: Should not reach here!");
}

// Test that different players CAN shoot the same coordinate
// (each player tracks their own shots separately)
#[test]
unconstrained fn test_different_players_can_shoot_same_coordinate() {
    std::println("=== TEST: Different Players Can Shoot Same Coordinate ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200009);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game with shot at (5,5)");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 5, y: 5 }
        )
    );

    // Host shoots at (5,5) - same coordinate guest shot
    std::println("Host shoots at (5,5) - same coordinate - turn 2");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    std::println("SUCCESS! Different players can shoot the same coordinate");
    std::println("(Each player attacks opponent's board independently)");
}

// Test that shooting after game is won should fail
#[test(should_fail_with = "Failed to get a note")]
unconstrained fn test_shoot_after_host_wins() {
    std::println("=== TEST: Cannot Shoot After Host Wins ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200001);

    // Create ship placements
    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    // Setup: Host creates game
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    // Guest joins
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: 0, y: 0 }
        )
    );

    // Calculate guest ship cells
    let guest_ship_cells = get_ship_cells(guest_ships);

    // Guest miss coordinates
    let guest_miss_coords: [(u8, u8); 17] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9), (8, 8),
    ];

    let mut turn = 2;

    // Host sinks all guest ships
    for i in 0..17 {
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_ship_cells[i].0, y: guest_ship_cells[i].1 }
            )
        );
        turn += 1;

        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_miss_coords[i].0, y: guest_miss_coords[i].1 }
            )
        );
        turn += 1;
    }

    // Verify host won
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    // Try to shoot after game is over - this should fail
    std::println("Attempting to shoot after game ended...");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(
            game_id,
            turn,
            Shot { x: 5, y: 5 }
        )
    );
}
