use crate::types::{GameId, Turn, ShipData, ShipPlacement, Shot, BOARD_SIZE, SHIP_SIZES, TOTAL_CELLS, Coordinate};
use aztec::{
        protocol_types::{traits::ToField, hash::poseidon2_hash_with_separator},
    };


pub fn build_nullifier(game_id: GameId, turn: Turn) -> Field {
    // Note: this leaks privacy. We should introduce a shared secret or randomness between players so that third parties 
    //       can't check which turns have been played
    poseidon2_hash_with_separator(
        [game_id.to_field(), turn as Field],
        1,
    )
}

// Expand a ship to its cell coordinates
pub fn expand_ship(ship: ShipData, length: u8) -> [(Coordinate, Coordinate); 5] {
    assert((ship.orientation == 0) | (ship.orientation == 1), "Invalid orientation");

    let mut cells = [(0, 0); 5];

    for i in 0..length {
        let cell = if ship.orientation == 0 {
            // Horizontal
            (ship.x + i, ship.y)
        } else {
            // Vertical
            (ship.x, ship.y + i)
        };

        assert(cell.0 < BOARD_SIZE, "Ship out of bounds");
        assert(cell.1 < BOARD_SIZE, "Ship out of bounds");

        cells[i as u32] = cell;
    }

    cells
}

// Validate a shot is within board bounds
pub fn validate_shot(shot: Shot) {
    assert(shot.x < BOARD_SIZE, "Shot x out of bounds");
    assert(shot.y < BOARD_SIZE, "Shot y out of bounds");
}

// Helper function to mark ship cells on a board. It will return if there was a collision
fn mark_cells(board: &mut [bool; TOTAL_CELLS], cells: [(u8, u8); 5], length: u8) -> bool {
    let mut collision = false;
    for i in 0..length {
        let idx = (cells[i as u32].1 * BOARD_SIZE + cells[i as u32].0) as u32;
        collision = collision | board[idx];
        board[idx] = true;
    }
    collision
}

pub fn validate_and_build_board(ships: ShipPlacement) -> [bool; TOTAL_CELLS] {
    let carrier_cells = expand_ship(ships.carrier, SHIP_SIZES[0]);
    let battleship_cells = expand_ship(ships.battleship, SHIP_SIZES[1]);
    let cruiser_cells = expand_ship(ships.cruiser, SHIP_SIZES[2]);
    let submarine_cells = expand_ship(ships.submarine, SHIP_SIZES[3]);
    let destroyer_cells = expand_ship(ships.destroyer, SHIP_SIZES[4]);

    let mut board = [false; TOTAL_CELLS];
    let mut collision = mark_cells(&mut board, carrier_cells, SHIP_SIZES[0]);
    collision = collision | mark_cells(&mut board, battleship_cells, SHIP_SIZES[1]);
    collision = collision | mark_cells(&mut board, cruiser_cells, SHIP_SIZES[2]);
    collision = collision | mark_cells(&mut board, submarine_cells, SHIP_SIZES[3]);
    collision = collision | mark_cells(&mut board, destroyer_cells, SHIP_SIZES[4]);

    assert(!collision, "Ships overlap");

    board
}

// ============================================================================
// UNIT TESTS
// ============================================================================

// Helper functions for unit tests
fn create_valid_ships_for_test() -> ShipPlacement {
    ShipPlacement {
        carrier: ShipData { x: 0, y: 0, orientation: 0 },     // (0,0)-(4,0) horizontal
        battleship: ShipData { x: 0, y: 1, orientation: 0 },  // (0,1)-(3,1) horizontal
        cruiser: ShipData { x: 0, y: 2, orientation: 0 },     // (0,2)-(2,2) horizontal
        submarine: ShipData { x: 0, y: 3, orientation: 0 },   // (0,3)-(2,3) horizontal
        destroyer: ShipData { x: 0, y: 4, orientation: 0 },   // (0,4)-(1,4) horizontal
    }
}

fn create_valid_ships_player2_for_test() -> ShipPlacement {
    ShipPlacement {
        carrier: ShipData { x: 5, y: 5, orientation: 1 },     // (5,5)-(5,9) vertical
        battleship: ShipData { x: 6, y: 5, orientation: 1 },  // (6,5)-(6,8) vertical
        cruiser: ShipData { x: 7, y: 5, orientation: 1 },     // (7,5)-(7,7) vertical
        submarine: ShipData { x: 8, y: 5, orientation: 1 },   // (8,5)-(8,7) vertical
        destroyer: ShipData { x: 9, y: 5, orientation: 1 },   // (9,5)-(9,6) vertical
    }
}

fn create_overlapping_ships_for_test() -> ShipPlacement {
    ShipPlacement {
        carrier: ShipData { x: 0, y: 0, orientation: 0 },
        battleship: ShipData { x: 0, y: 0, orientation: 0 },  // Same position as carrier!
        cruiser: ShipData { x: 5, y: 5, orientation: 0 },
        submarine: ShipData { x: 6, y: 6, orientation: 0 },
        destroyer: ShipData { x: 7, y: 7, orientation: 0 },
    }
}

// expand_ship() tests

#[test]
unconstrained fn test_expand_ship_horizontal() {
    let ship = ShipData { x: 2, y: 3, orientation: 0 };
    let cells = expand_ship(ship, 3);

    // Expected: [(2,3), (3,3), (4,3), (0,0), (0,0)]
    assert((cells[0].0 == 2) & (cells[0].1 == 3), "Cell 0 incorrect");
    assert((cells[1].0 == 3) & (cells[1].1 == 3), "Cell 1 incorrect");
    assert((cells[2].0 == 4) & (cells[2].1 == 3), "Cell 2 incorrect");
    assert((cells[3].0 == 0) & (cells[3].1 == 0), "Padding cell 3 incorrect");
    assert((cells[4].0 == 0) & (cells[4].1 == 0), "Padding cell 4 incorrect");
}

#[test]
unconstrained fn test_expand_ship_vertical() {
    let ship = ShipData { x: 5, y: 1, orientation: 1 };
    let cells = expand_ship(ship, 4);

    // Expected: [(5,1), (5,2), (5,3), (5,4), (0,0)]
    assert((cells[0].0 == 5) & (cells[0].1 == 1), "Cell 0 incorrect");
    assert((cells[1].0 == 5) & (cells[1].1 == 2), "Cell 1 incorrect");
    assert((cells[2].0 == 5) & (cells[2].1 == 3), "Cell 2 incorrect");
    assert((cells[3].0 == 5) & (cells[3].1 == 4), "Cell 3 incorrect");
    assert((cells[4].0 == 0) & (cells[4].1 == 0), "Padding cell 4 incorrect");
}

#[test]
unconstrained fn test_expand_ship_at_origin() {
    let ship = ShipData { x: 0, y: 0, orientation: 0 };
    let cells = expand_ship(ship, 5);

    // Carrier at origin: [(0,0), (1,0), (2,0), (3,0), (4,0)]
    assert((cells[0].0 == 0) & (cells[0].1 == 0), "Cell 0 incorrect");
    assert((cells[1].0 == 1) & (cells[1].1 == 0), "Cell 1 incorrect");
    assert((cells[2].0 == 2) & (cells[2].1 == 0), "Cell 2 incorrect");
    assert((cells[3].0 == 3) & (cells[3].1 == 0), "Cell 3 incorrect");
    assert((cells[4].0 == 4) & (cells[4].1 == 0), "Cell 4 incorrect");
}

#[test]
unconstrained fn test_expand_ship_at_edge() {
    let ship = ShipData { x: 8, y: 9, orientation: 0 };
    let cells = expand_ship(ship, 2);

    // Destroyer at edge: [(8,9), (9,9), (0,0), (0,0), (0,0)]
    assert((cells[0].0 == 8) & (cells[0].1 == 9), "Cell 0 incorrect");
    assert((cells[1].0 == 9) & (cells[1].1 == 9), "Cell 1 incorrect");
}

// validate_shot() tests

#[test]
unconstrained fn test_validate_shot_valid() {
    let shot1 = Shot { x: 0, y: 0 };
    validate_shot(shot1);

    let shot2 = Shot { x: 9, y: 9 };
    validate_shot(shot2);

    let shot3 = Shot { x: 5, y: 5 };
    validate_shot(shot3);
}

#[test(should_fail_with = "Shot x out of bounds")]
unconstrained fn test_validate_shot_x_out_of_bounds() {
    let shot = Shot { x: 10, y: 5 };
    validate_shot(shot);
}

#[test(should_fail_with = "Shot y out of bounds")]
unconstrained fn test_validate_shot_y_out_of_bounds() {
    let shot = Shot { x: 5, y: 15 };
    validate_shot(shot);
}

#[test(should_fail_with = "Shot x out of bounds")]
unconstrained fn test_validate_shot_both_out_of_bounds() {
    let shot = Shot { x: 20, y: 20 };
    validate_shot(shot);
}

// validate_and_build_board() tests

#[test]
unconstrained fn test_validate_and_build_board_valid_ships() {
    let ships = create_valid_ships_for_test();
    let board = validate_and_build_board(ships);

    // Verify carrier cells (0,0)-(4,0) are marked
    assert(board[0], "Carrier cell (0,0) should be set");
    assert(board[1], "Carrier cell (1,0) should be set");
    assert(board[2], "Carrier cell (2,0) should be set");
    assert(board[3], "Carrier cell (3,0) should be set");
    assert(board[4], "Carrier cell (4,0) should be set");

    // Verify battleship cells (0,1)-(3,1) are marked
    assert(board[10], "Battleship cell (0,1) should be set");
    assert(board[11], "Battleship cell (1,1) should be set");
    assert(board[12], "Battleship cell (2,1) should be set");
    assert(board[13], "Battleship cell (3,1) should be set");

    // Verify destroyer cells (0,4)-(1,4) are marked
    assert(board[40], "Destroyer cell (0,4) should be set");
    assert(board[41], "Destroyer cell (1,4) should be set");

    // Verify some empty cells
    assert(!board[99], "Empty cell (9,9) should not be set");
}

#[test(should_fail_with = "Ships overlap")]
unconstrained fn test_validate_and_build_board_overlapping() {
    let ships = create_overlapping_ships_for_test();
    let _ = validate_and_build_board(ships);
}

#[test]
unconstrained fn test_validate_and_build_board_vertical_ships() {
    let ships = create_valid_ships_player2_for_test();
    let board = validate_and_build_board(ships);

    // Carrier is vertical at (5,5)-(5,9): indices 55,65,75,85,95
    assert(board[55], "Carrier cell (5,5) should be set");
    assert(board[65], "Carrier cell (5,6) should be set");
    assert(board[75], "Carrier cell (5,7) should be set");
    assert(board[85], "Carrier cell (5,8) should be set");
    assert(board[95], "Carrier cell (5,9) should be set");

    // Verify empty cells
    assert(!board[0], "Empty cell (0,0) should not be set");
}

#[test(should_fail_with = "Ship out of bounds")]
unconstrained fn test_validate_and_build_board_extends_past_edge() {
    let ships = ShipPlacement {
        carrier: ShipData { x: 8, y: 5, orientation: 0 },  // x=8 + length=5 = 13 > 10
        battleship: ShipData { x: 0, y: 5, orientation: 0 },
        cruiser: ShipData { x: 0, y: 6, orientation: 0 },
        submarine: ShipData { x: 0, y: 7, orientation: 0 },
        destroyer: ShipData { x: 0, y: 8, orientation: 0 },
    };
    let _ = validate_and_build_board(ships);  // Should fail
}

#[test]
unconstrained fn test_validate_and_build_board_count_cells() {
    let ships = create_valid_ships_for_test();
    let board = validate_and_build_board(ships);

    // Count total marked cells (should be 17)
    let mut count: u32 = 0;
    for i in 0..100 {
        if board[i as u32] {
            count += 1;
        }
    }

    assert(count == 17, "Should have exactly 17 cells marked");
}
