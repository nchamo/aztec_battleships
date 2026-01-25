use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::GameId;
use crate::test::utils::create_valid_ships;

// Test that creating a game with an existing GameId should fail
#[test(should_fail_with = "duplicate siloed nullifier")]
unconstrained fn test_cannot_create_duplicate_game_id() {
    std::println("=== TEST: Cannot Create Game with Duplicate GameId ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(300001);

    // Create first game
    std::println("Creating first game with GameId 300001");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Try to create second game with same GameId - this should fail
    std::println("Attempting to create second game with same GameId...");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );
}
