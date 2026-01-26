use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::GameId;
use crate::test::utils::create_valid_ships;

// Test that creating a game with an existing GameId should fail
#[test(should_fail_with = "duplicate siloed nullifier")]
unconstrained fn test_cannot_create_duplicate_game_id() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(300001);

    // Create first game
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Try to create second game with same GameId - this should fail
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );
}
