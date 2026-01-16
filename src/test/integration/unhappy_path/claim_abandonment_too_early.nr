use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, TURN_TIMEOUT};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

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
