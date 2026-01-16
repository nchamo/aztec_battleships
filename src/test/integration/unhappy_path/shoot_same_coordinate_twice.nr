use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

// Test that a player cannot shoot the same coordinate twice
#[test(should_fail)]
unconstrained fn test_shoot_same_coordinate_twice_fails() {
    std::println("=== TEST: Shoot Same Coordinate Twice (Should Fail) ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200008);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game with shot at (0,0)");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }
        )
    );

    // Host shoots at (5,5)
    std::println("Host shoots at (5,5) - turn 2");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    // Guest shoots at (3,3)
    std::println("Guest shoots at (3,3) - turn 3");
    env.call_private(
        guest,
        Battleships::at(contract_address).shoot(game_id, 3, Shot { x: 3, y: 3 })
    );

    // Host tries to shoot at (5,5) again (same coordinate as before)
    std::println("Host attempts to shoot at (5,5) AGAIN - turn 4");

    // This should fail with "Already shot this position"
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 4, Shot { x: 5, y: 5 })
    );

    std::println("ERROR: Should not reach here!");
}

// Test that different players CAN shoot the same coordinate
// (each player tracks their own shots separately)
#[test]
unconstrained fn test_different_players_can_shoot_same_coordinate() {
    std::println("=== TEST: Different Players Can Shoot Same Coordinate ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(200009);

    // Setup game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    std::println("Guest joins game with shot at (5,5)");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 5, y: 5 }
        )
    );

    // Host shoots at (5,5) - same coordinate guest shot
    std::println("Host shoots at (5,5) - same coordinate - turn 2");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(game_id, 2, Shot { x: 5, y: 5 })
    );

    std::println("SUCCESS! Different players can shoot the same coordinate");
    std::println("(Each player attacks opponent's board independently)");
}
