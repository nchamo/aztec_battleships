use dep::aztec::{
    test::helpers::test_environment::TestEnvironment,
};
use crate::Battleships;
use crate::types::{Shot, GameId, STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST};
use crate::test::helpers::{create_valid_ships, create_valid_ships_player2, get_ship_cells};

// Test where host wins by destroying all of guest's ships
#[test]
unconstrained fn test_host_wins_by_sinking_all_ships() {
    std::println("=== TEST: Host Wins by Combat ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100001);

    // Create ship placements
    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    // Setup: Host creates game
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    // Verify game status is CREATED
    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    // Guest joins with initial shot
    std::println("Guest joins game");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: 0, y: 0 }  // Hits host's carrier
        )
    );

    // Verify game status is ACTIVE after guest joins
    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    // Guest's ships are at specific locations based on create_valid_ships_player2()
    // We need to hit all 17 cells: carrier(5), battleship(4), cruiser(3), submarine(3), destroyer(2)
    // Calculate all guest ship cells from the placement
    let guest_ship_cells = get_ship_cells(guest_ships);

    let mut turn = 2;

    // Coordinates where guest can miss (away from host ships)
    // Host ships are at: carrier(0,0)-(4,0), battleship(0,1)-(3,1), cruiser(0,2)-(2,2),
    //                    submarine(0,3)-(2,3), destroyer(0,4)-(1,4)
    let guest_miss_coords: [(u8, u8); 17] = [
        (9, 0), (9, 1), (9, 2), (9, 3),
        (9, 4), (9, 5), (9, 6), (9, 7),
        (9, 8), (9, 9), (1, 9), (2, 9),
        (3, 9), (4, 9), (5, 9), (6, 9), (8, 8),
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

        // Verify game is still ACTIVE (unless this was the last hit)
        if i < 16 {
            let mid_game_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
            assert(mid_game_status == STATUS_ACTIVE, "Game should remain ACTIVE during play");
        }
    }

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_HOST, "Game should be won by host");

    std::println("\n=== SUCCESS: Host won by combat! ===");
}

// Test where guest wins by destroying all of host's ships
#[test]
unconstrained fn test_guest_wins_by_sinking_all_ships() {
    std::println("=== TEST: Guest Wins by Combat ===");

    let mut env = TestEnvironment::new();
    let host = env.create_light_account();
    let guest = env.create_light_account();
    let contract_address = env.deploy("Battleships").without_initializer();

    let game_id = GameId::new(100002);

    // Create ship placements
    let host_ships = create_valid_ships();
    let guest_ships = create_valid_ships_player2();

    // Setup
    std::println("Host creates game");
    env.call_private(
        host,
        Battleships::at(contract_address).create_game(game_id, host_ships)
    );

    // Verify game status is CREATED
    let status_after_create = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_create == STATUS_CREATED, "Game should be CREATED after host creates");

    // Host's ships are at specific locations based on create_valid_ships()
    // Calculate all host ship cells from the placement
    let host_ship_cells = get_ship_cells(host_ships);

    // Guest joins with initial shot hitting first host ship cell
    std::println("Guest joins and hits host's first ship cell");
    env.call_private(
        guest,
        Battleships::at(contract_address).join_game(
            game_id,
            guest_ships,
            Shot { x: host_ship_cells[0].0, y: host_ship_cells[0].1 }
        )
    );

    // Verify game status is ACTIVE after guest joins
    let status_after_join = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    assert(status_after_join == STATUS_ACTIVE, "Game should be ACTIVE after guest joins");

    // Coordinates where host can miss (away from guest ships)
    // Guest ships are at: carrier(5,5)-(5,9), battleship(6,5)-(6,8), cruiser(7,5)-(7,7),
    //                     submarine(8,5)-(8,7), destroyer(9,5)-(9,6)
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

        // Verify game is still ACTIVE during play
        if i < 15 {
            let mid_game_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
            assert(mid_game_status == STATUS_ACTIVE, "Game should remain ACTIVE during play");
        }
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

    std::println("\n=== Verifying game status ===");
    let final_status = env.simulate_utility(Battleships::at(contract_address).get_game_status(game_id));
    std::println("Final status: ");
    std::println(final_status);
    assert(final_status == STATUS_WON_BY_GUEST, "Game should be won by guest");

    std::println("\n=== SUCCESS: Guest won by combat! ===");
}
