use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_WON_BY_HOST};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2};

// Test where host wins by destroying all of guest's ships
#[test]
unconstrained fn test_host_wins_by_sinking_all_ships() {
    std::println("=== TEST: Host Wins by Combat ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100001);

    // Setup: Host creates game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, create_valid_ships())
    );

    // Guest joins with initial shot
    std::println("Guest joins game");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            create_valid_ships_player2(),
            Shot { x: 0, y: 0 }  // Miss (host ships are elsewhere)
        )
    );

    // Guest's ships are at specific locations based on create_valid_ships_player2()
    // We need to hit all 17 cells: carrier(5), battleship(4), cruiser(3), submarine(3), destroyer(2)
    // Let's systematically hit all guest ships

    let mut turn = 2;

    // According to helpers.nr, guest ships are:
    // carrier: (2,2) horizontal -> (2,2), (3,2), (4,2), (5,2), (6,2)
    // battleship: (0,4) vertical -> (0,4), (0,5), (0,6), (0,7)
    // cruiser: (5,5) horizontal -> (5,5), (6,5), (7,5)
    // submarine: (8,0) vertical -> (8,0), (8,1), (8,2)
    // destroyer: (3,8) horizontal -> (3,8), (4,8)

    let guest_ship_cells: [(u8, u8); 17] = [
        // Carrier
        (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
        // Battleship
        (0, 4), (0, 5), (0, 6), (0, 7),
        // Cruiser
        (5, 5), (6, 5), (7, 5),
        // Submarine
        (8, 0), (8, 1), (8, 2),
        // Destroyer
        (3, 8), (4, 8),
    ];

    // Coordinates where guest can miss (away from host ships)
    // Host ships are at: carrier(0,0-4,0), battleship(0,2-3,2), cruiser(6,0-8,0),
    //                    submarine(6,2-8,2), destroyer(0,4-1,4)
    let guest_miss_coords: [(u8, u8); 16] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9),
    ];

    // Host and guest alternate shots
    // Host hits, guest misses
    for i in 0..17 {
        std::println("Turn: ");
        std::println(turn);

        // Host shoots at guest's ship
        std::println("  Host shoots at guest ship cell");
        env.call_private(
            host,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_ship_cells[i].0, y: guest_ship_cells[i].1 }
            )
        );

        turn += 1;

        // If this was the last hit (17th), host wins - game ends
        if i == 16 {
            std::println("  Host hit the 17th cell - HOST WINS!");
            break;
        }

        // Guest shoots somewhere that misses (away from host ships)
        std::println("  Guest shoots and misses");
        env.call_private(
            guest,
            Battleships::at(contract_address).shoot(
                game_id,
                turn,
                Shot { x: guest_miss_coords[i].0, y: guest_miss_coords[i].1 }
            )
        );

        turn += 1;
    }

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    std::println("\n=== SUCCESS: Host won by combat! ===");
}
