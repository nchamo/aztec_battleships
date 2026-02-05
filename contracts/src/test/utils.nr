use crate::types::{ShipData, ShipPlacement, SHIP_SIZES};
use crate::utils::expand_ship;

fn copy_ship_cells(cells: &mut [(u8, u8); 17], index: &mut u32, ship: ShipData, length: u8) {
    let expanded = expand_ship(ship, length);
    for i in 0..length {
        cells[*index] = expanded[i as u32];
        *index += 1;
    }
}

pub fn get_ship_cells(placement: ShipPlacement) -> [(u8, u8); 17] {
    let mut cells: [(u8, u8); 17] = [(0, 0); 17];
    let mut index: u32 = 0;

    copy_ship_cells(&mut cells, &mut index, placement.carrier, SHIP_SIZES[0]);
    copy_ship_cells(&mut cells, &mut index, placement.battleship, SHIP_SIZES[1]);
    copy_ship_cells(&mut cells, &mut index, placement.cruiser, SHIP_SIZES[2]);
    copy_ship_cells(&mut cells, &mut index, placement.submarine, SHIP_SIZES[3]);
    copy_ship_cells(&mut cells, &mut index, placement.destroyer, SHIP_SIZES[4]);

    cells
}

// Create valid non-overlapping ship placement
pub fn create_valid_ships() -> ShipPlacement {
    ShipPlacement {
        carrier: ShipData { x: 0, y: 0, orientation: 0 },     // (0,0)-(4,0) horizontal
        battleship: ShipData { x: 0, y: 1, orientation: 0 },  // (0,1)-(3,1) horizontal
        cruiser: ShipData { x: 0, y: 2, orientation: 0 },     // (0,2)-(2,2) horizontal
        submarine: ShipData { x: 0, y: 3, orientation: 0 },   // (0,3)-(2,3) horizontal
        destroyer: ShipData { x: 0, y: 4, orientation: 0 },   // (0,4)-(1,4) horizontal
    }
}

// Create second valid placement (different positions for player 2)
pub fn create_valid_ships_player2() -> ShipPlacement {
    ShipPlacement {
        carrier: ShipData { x: 5, y: 5, orientation: 1 },     // (5,5)-(5,9) vertical
        battleship: ShipData { x: 6, y: 5, orientation: 1 },  // (6,5)-(6,8) vertical
        cruiser: ShipData { x: 7, y: 5, orientation: 1 },     // (7,5)-(7,7) vertical
        submarine: ShipData { x: 8, y: 5, orientation: 1 },   // (8,5)-(8,7) vertical
        destroyer: ShipData { x: 9, y: 5, orientation: 1 },   // (9,5)-(9,6) vertical
    }
}

// Create overlapping ships (for negative tests)
pub fn create_overlapping_ships() -> ShipPlacement {
    ShipPlacement {
        carrier: ShipData { x: 0, y: 0, orientation: 0 },
        battleship: ShipData { x: 0, y: 0, orientation: 0 },  // Same position as carrier!
        cruiser: ShipData { x: 5, y: 5, orientation: 0 },
        submarine: ShipData { x: 6, y: 6, orientation: 0 },
        destroyer: ShipData { x: 7, y: 7, orientation: 0 },
    }
}
