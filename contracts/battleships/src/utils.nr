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
