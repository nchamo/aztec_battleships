use crate::types::{ShipData, ShipPlacement};

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

// Create ship that extends past right edge
pub fn create_ship_past_right_edge() -> ShipData {
    ShipData { x: 8, y: 5, orientation: 0 }  // x=8 + length=5 = 13 > 10
}

// Create ship that extends past bottom edge
pub fn create_ship_past_bottom_edge() -> ShipData {
    ShipData { x: 5, y: 7, orientation: 1 }  // y=7 + length=4 = 11 > 10
}

// Create ship with x out of bounds
pub fn create_ship_x_out_of_bounds() -> ShipData {
    ShipData { x: 10, y: 5, orientation: 0 }
}

// Create ship with y out of bounds
pub fn create_ship_y_out_of_bounds() -> ShipData {
    ShipData { x: 5, y: 11, orientation: 1 }
}

// Create ship with invalid orientation
pub fn create_ship_invalid_orientation() -> ShipData {
    ShipData { x: 5, y: 5, orientation: 2 }
}
