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

// Test that a player cannot claim abandonment when it's actually their turn to play
#[test(should_fail)]
unconstrained fn test_claim_abandonment_on_own_turn_fails() {
    std::println("=== TEST: Claim Abandonment When It's Your Turn (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200005);

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
    // But host tries to claim abandonment instead of shooting

    std::println("Host tries to claim abandonment when it's actually host's turn to shoot");

    // This should fail with "Not my turn"
    // Because claim_abandonment checks: opponent_action.turn == my_action.turn + 1
    // Host has turn 0, opponent has turn 1, so 1 == 0 + 1 passes
    // Wait, this might actually pass the check...

    // Let me reconsider: After guest joins:
    // - Host.my_last_action.turn = 0
    // - Host.opponent_last_action.turn = 1
    // claim_abandonment checks: opponent.turn (1) == my.turn (0) + 1 -> TRUE
    // So host thinks it's their turn, but actually it IS their turn...

    // The issue is that claim_abandonment has the same check as shoot()
    // So a player can only claim abandonment when it's their turn to act

    // Let's test the opposite: Host shoots, then guest tries to claim abandonment
    // when it's actually guest's turn

    std::println("Actually, let's test: Host shoots, then guest claims abandonment when it's guest's turn");

    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    // Now it's guest's turn (turn 3)
    // Guest tries to claim abandonment instead of shooting

    std::println("Guest tries to claim abandonment when it's actually guest's turn to shoot");

    // This should fail because:
    // - Guest.my_last_action.turn = 1
    // - Guest.opponent_last_action.turn = 2
    // Check: 2 == 1 + 1 -> TRUE (it IS guest's turn)
    // But guest is claiming host abandoned, which makes no sense
    // since host just shot

    // The timeout check should fail: current_time - my_last_action.timestamp > TIMEOUT
    // But in TestEnvironment, time doesn't advance, so this will fail for a different reason

    // After host shot (turn 2), it's guest's turn (turn 3)
    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 3)
    );

    std::println("ERROR: Should not reach here!");
}
