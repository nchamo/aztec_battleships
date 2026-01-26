use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_WON_BY_HOST, TURN_TIMEOUT};
use crate::test::utils::{create_valid_ships, create_valid_ships_player2};

// Test that joining a non-existent game fails
#[test(should_fail)]
unconstrained fn test_join_nonexistent_game_fails() {
    let mut env = TestEnvironment::new();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let fake_game_id = GameId::new(999999);

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            fake_game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );
}

// Test that a third player cannot join a game that's already active
#[test(should_fail)]
unconstrained fn test_join_active_game_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let third_player = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200001);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    env.call_private(
        third_player,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 1, y: 1 }
        )
    );
}

// Test that joining a finished game should fail
#[test(should_fail_with = "duplicate siloed nullifier")]
unconstrained fn test_join_finished_game_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let third_player = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200002);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    let host_shot_time = env.last_block_timestamp();
    let timeout_timestamp = host_shot_time + TURN_TIMEOUT + 3600;
    env.mine_block_at(timeout_timestamp);

    env.call_private(
        host,
        Battleships::at(contract_address).claim_abandonment(game_id, 3)
    );

    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(final_status == STATUS_WON_BY_HOST, "Game should be finished");

    env.call_private(
        third_player,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships(),
            Shot { x: 1, y: 1 }
        )
    );
}
