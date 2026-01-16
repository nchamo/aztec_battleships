use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::create_valid_ships_player2;

// Test that joining a non-existent game fails
#[test(should_fail)]
unconstrained fn test_join_nonexistent_game_fails() {
    std::println("=== TEST: Join Non-Existent Game (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    // Make up a game ID that was never created
    let fake_game_id = GameId::new(999999);

    std::println("Guest attempts to join non-existent game");

    // This should fail because the game doesn't exist
    // The public game state won't exist, so on_game_joined will fail
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            fake_game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    std::println("ERROR: Should not reach here!");
}
