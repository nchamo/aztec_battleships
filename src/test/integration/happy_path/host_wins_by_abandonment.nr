use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_WON_BY_HOST, TURN_TIMEOUT};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

// Test where host wins because guest abandons (doesn't shoot within timeout)
#[test]
unconstrained fn test_host_wins_by_guest_abandonment() {
    std::println("=== TEST: Host Wins by Guest Abandonment ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100003);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game with initial shot");
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

    let host_shot_time = env.last_block_timestamp();
    std::println("Host shot at timestamp: ");
    std::println(host_shot_time);

    // Now it's guest's turn (turn 3), but guest doesn't shoot
    // Advance time by more than TURN_TIMEOUT (24 hours = 86400 seconds)
    std::println("\nAdvancing time beyond TURN_TIMEOUT...");
    std::println("TURN_TIMEOUT = ");
    std::println(TURN_TIMEOUT);
    std::println(" seconds");

    let timeout_timestamp = host_shot_time + TURN_TIMEOUT + 3600; // Add 1 hour buffer
    std::println("Mining block at timestamp: ");
    std::println(timeout_timestamp);

    env.mine_block_at(timeout_timestamp);

    // Host claims abandonment
    // After host shot (turn 2), it's guest's turn (turn 3), but guest didn't shoot
    // So host claims abandonment on turn 3
    std::println("\nHost claims abandonment (guest failed to shoot within 24h)");
    env.call_private(
        host,
        Battleships::at(contract_address).claim_abandonment(game_id, 3)
    );

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    std::println("\n=== SUCCESS: Host won by guest abandonment! ===");
}
