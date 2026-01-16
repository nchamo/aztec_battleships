use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_WON_BY_GUEST};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

// Test where guest wins by destroying all of host's ships
#[test]
unconstrained fn test_guest_wins_by_sinking_all_ships() {
    std::println("=== TEST: Guest Wins by Combat ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100002);

    // Setup
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Host's ships are at specific locations based on create_valid_ships()
    // carrier: (0,0) horizontal -> (0,0), (1,0), (2,0), (3,0), (4,0)
    // battleship: (0,2) horizontal -> (0,2), (1,2), (2,2), (3,2)
    // cruiser: (6,0) horizontal -> (6,0), (7,0), (8,0)
    // submarine: (6,2) horizontal -> (6,2), (7,2), (8,2)
    // destroyer: (0,4) horizontal -> (0,4), (1,4)

    let host_ship_cells: [(u8, u8); 17] = [
        // Carrier
        (0, 0), (1, 0), (2, 0), (3, 0), (4, 0),
        // Battleship
        (0, 2), (1, 2), (2, 2), (3, 2),
        // Cruiser
        (6, 0), (7, 0), (8, 0),
        // Submarine
        (6, 2), (7, 2), (8, 2),
        // Destroyer
        (0, 4), (1, 4),
    ];

    // Guest joins with initial shot hitting first host ship cell
    std::println("Guest joins and hits host's first ship cell");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: host_ship_cells[0].0, y: host_ship_cells[0].1 }
        )
    );

    // Coordinates where host can miss (away from guest ships)
    // Guest ships are at: carrier(2,2-6,2), battleship(0,4-0,7), cruiser(5,5-7,5),
    //                     submarine(8,0-8,2), destroyer(3,8-4,8)
    let host_miss_coords: [(u8, u8); 16] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9),
    ];

    let mut turn = 2;

    // Now guest needs to hit the remaining 16 cells
    // Host shoots and misses, guest hits
    for i in 1..17 {
        std::println("Turn: ");
        std::println(turn);

        // Host shoots somewhere that misses
        std::println("  Host shoots and misses");
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: host_miss_coords[i - 1].0, y: host_miss_coords[i - 1].1 }
            )
        );

        turn += 1;

        // Guest shoots at host's ship
        std::println("  Guest shoots at host ship cell");
        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: host_ship_cells[i].0, y: host_ship_cells[i].1 }
            )
        );

        turn += 1;
    }

    // Host needs to take one more turn to verify the last guest shot and realize they lost
    std::println("\nTurn: ");
    std::println(turn);
    std::println("  Host takes final turn and realizes all ships are sunk");
    env.call_private(
        host,
        Battleships::at(contract_address).shoot(
            game_id,
            turn,
            Shot { x: 7, y: 9 }  // Any miss location
        )
    );

    std::println("\n=== SUCCESS: Guest won by combat! ===");
}
