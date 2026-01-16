use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

// Test that a third player cannot join a game that's already active
#[test(should_fail)]
unconstrained fn test_join_active_game_fails() {
    std::println("=== TEST: Join Active Game (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let third_player = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200001);

    // Host creates game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Guest joins game (this activates it)
    std::println("Guest joins game (game becomes ACTIVE)");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // Third player tries to join the same game
    std::println("Third player attempts to join already-active game");

    // This should fail with "Game not in created state"
    env.call_private(
        third_player,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 1, y: 1 }
        )
    );

    std::println("ERROR: Should not reach here!");
}
