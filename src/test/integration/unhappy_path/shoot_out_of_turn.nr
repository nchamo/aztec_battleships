use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

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
