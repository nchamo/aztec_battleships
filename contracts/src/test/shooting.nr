use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_WON_BY_HOST};
use crate::test::utils::{create_valid_ships, create_valid_ships_player2, get_ship_cells};

// ============================================================================
// Turn Order Tests
// ============================================================================

#[test(should_fail_with = "Invalid player")]
unconstrained fn test_shoot_out_of_turn_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200002);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // After guest joins, it's host's turn (turn 2) - guest tries to shoot again
    env.call_private(
        guest,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 1, y: 1 })
    );
}

#[test(should_fail_with = "Invalid player")]
unconstrained fn test_shoot_twice_in_row_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200003);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    // Host tries to shoot again (turn 3 is guest's turn)
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 3, Shot { x: 6, y: 6 })
    );
}

// ============================================================================
// Coordinate Validation Tests
// ============================================================================

#[test(should_fail_with = "Shot x out of bounds")]
unconstrained fn test_shoot_invalid_x_coordinate_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200006);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // x=10 is out of bounds (valid range is 0-9)
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 10, y: 5 })
    );
}

#[test(should_fail_with = "Shot y out of bounds")]
unconstrained fn test_shoot_invalid_y_coordinate_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200007);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // y=15 is out of bounds (valid range is 0-9)
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 15 })
    );
}

// ============================================================================
// Duplicate Shot Tests
// ============================================================================

#[test(should_fail)]
unconstrained fn test_shoot_same_coordinate_twice_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200008);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).shoot(game_id, 3, Shot { x: 3, y: 3 })
    );

    // Host tries to shoot at (5,5) again
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 4, Shot { x: 5, y: 5 })
    );
}

#[test]
unconstrained fn test_different_players_can_shoot_same_coordinate() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200009);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 5, y: 5 }
        )
    );

    // Host shoots at (5,5) - same coordinate guest shot (each player attacks opponent's board)
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );
}

// ============================================================================
// Post-Game Tests
// ============================================================================

#[test(should_fail_with = "Failed to get a note")]
unconstrained fn test_shoot_after_host_wins() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200001);

    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: 0, y: 0 }
        )
    );

    let guest_ship_cells = get_ship_cells(guest_ships);

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

    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    // Try to shoot after game is over
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(
            game_id,
            turn,
            Shot { x: 5, y: 5 }
        )
    );
}
