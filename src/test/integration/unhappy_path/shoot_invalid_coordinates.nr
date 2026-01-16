use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

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
