use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

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
