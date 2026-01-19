use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

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
