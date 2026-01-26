use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_CREATED, STATUS_ACTIVE};
use crate::test::utils::{create_valid_ships, create_valid_ships_player2};

#[test]
unconstrained fn test_concurrent_games_with_different_ids() {
    let mut env = TestEnvironment::new();
    let host1 = env.create_light_account();
    let host2 = env.create_light_account();
    let guest1 = env.create_light_account();
    let guest2 = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id_1 = GameId::new(300002);
    let game_id_2 = GameId::new(300003);

    env.call_private(
        host1,
        Battleships::at(contract_address).create_game(game_id_1, create_valid_ships())
    );

    let status_game1_created = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_1));
    assert(status_game1_created == STATUS_CREATED, "Game 1 should be CREATED");

    env.call_private(
        host2,
        Battleships::at(contract_address).create_game(game_id_2, create_valid_ships())
    );

    let status_game2_created = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_2));
    assert(status_game2_created == STATUS_CREATED, "Game 2 should be CREATED");

    env.call_private(
        guest1,
        Battleships::at(contract_address).join_game(
            game_id_1,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    let status_game1_active = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_1));
    assert(status_game1_active == STATUS_ACTIVE, "Game 1 should be ACTIVE");

    let status_game2_still_created = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_2));
    assert(status_game2_still_created == STATUS_CREATED, "Game 2 should still be CREATED");

    env.call_private(
        guest2,
        Battleships::at(contract_address).join_game(
            game_id_2,
            create_valid_ships_player2(),
            Shot { x: 1, y: 1 }
        )
    );

    let status_game2_active = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_2));
    assert(status_game2_active == STATUS_ACTIVE, "Game 2 should be ACTIVE");

    env.call_private(
        host1,
        Battleships::at(contract_address).shoot(game_id_1, 2, Shot { x: 5, y: 5 })
    );

    env.call_private(
        host2,
        Battleships::at(contract_address).shoot(game_id_2, 2, Shot { x: 6, y: 6 })
    );

    let final_status_game1 = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_1));
    let final_status_game2 = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id_2));

    assert(final_status_game1 == STATUS_ACTIVE, "Game 1 should still be ACTIVE");
    assert(final_status_game2 == STATUS_ACTIVE, "Game 2 should still be ACTIVE");
}
