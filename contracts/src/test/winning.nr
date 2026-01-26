use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST, TURN_TIMEOUT};
use crate::test::utils::{create_valid_ships, create_valid_ships_player2, get_ship_cells};

// ============================================================================
// Combat Win Tests
// ============================================================================

#[test]
unconstrained fn test_host_wins_by_sinking_all_ships() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100001);

    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: 0, y: 0 }
        )
    );

    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    let guest_ship_cells = get_ship_cells(guest_ships);

    let mut turn = 2;

    let guest_miss_coords: [(u8, u8); 17] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9), (8, 8),
    ];

    for i in 0..17 {
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_ship_cells[i].0, y: guest_ship_cells[i].1 }
            )
        );

        turn += 1;

        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_miss_coords[i].0, y: guest_miss_coords[i].1 }
            )
        );

        turn += 1;

        if i < 16 {
            let mid_game_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
            assert(mid_game_status == STATUS_ACTIVE, "Game should remain ACTIVE during play");
        }
    }

    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");
}

#[test]
unconstrained fn test_guest_wins_by_sinking_all_ships() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100002);

    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    let host_ship_cells = get_ship_cells(host_ships);

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: host_ship_cells[0].0, y: host_ship_cells[0].1 }
        )
    );

    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    let host_miss_coords: [(u8, u8); 16] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9),
    ];

    let mut turn = 2;

    for i in 1..17 {
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: host_miss_coords[i - 1].0, y: host_miss_coords[i - 1].1 }
            )
        );

        turn += 1;

        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: host_ship_cells[i].0, y: host_ship_cells[i].1 }
            )
        );

        turn += 1;

        if i < 15 {
            let mid_game_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
            assert(mid_game_status == STATUS_ACTIVE, "Game should remain ACTIVE during play");
        }
    }

    // Host takes final turn to verify they lost
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(
            game_id,
            turn,
            Shot { x: 7, y: 9 }
        )
    );

    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(final_status == STATUS_WON_BY_GUEST, "Game should be won by guest");
}

// ============================================================================
// Abandonment Win Tests
// ============================================================================

#[test]
unconstrained fn test_host_wins_by_guest_abandonment() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100003);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

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
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");
}

#[test]
unconstrained fn test_guest_wins_by_host_abandonment() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100004);

    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    let guest_shot_time = env.last_block_timestamp();
    let timeout_timestamp = guest_shot_time + TURN_TIMEOUT + 3600;
    env.mine_block_at(timeout_timestamp);

    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 2)
    );

    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(final_status == STATUS_WON_BY_GUEST, "Game should be won by guest");
}

// ============================================================================
// Abandonment Failure Tests
// ============================================================================

#[test(should_fail_with = "Opponent still has time to play")]
unconstrained fn test_claim_abandonment_too_early_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200004);

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

    let join_time = env.last_block_timestamp();
    let early_timestamp = join_time + (TURN_TIMEOUT / 2);
    env.mine_block_at(early_timestamp);

    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 2)
    );
}

#[test(should_fail)]
unconstrained fn test_claim_abandonment_when_opponent_just_acted_fails() {
    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200005);

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

    // Guest tries to claim abandonment immediately after host's turn
    env.call_private(
        guest,
        Battleships::at(contract_address).claim_abandonment(game_id, 3)
    );
}
