use crate::types::{ShipData, ShipPlacement, BOARD_SIZE, SHIP_SIZES};

// Expand a ship to its cell coordinates
pub fn expand_ship(ship: ShipData, length: u8) -> [(u8, u8); 5] {
    let mut cells: [(u8, u8); 5] = [(0, 0); 5];

    for i in 0..5 {
        if (i as u8) < length {
            if ship.orientation == 0 {
                // Horizontal
                cells[i] = (ship.x + (i as u8), ship.y);
            } else {
                // Vertical
                cells[i] = (ship.x, ship.y + (i as u8));
            }
        }
    }

    cells
}

// Check if two cell arrays intersect
pub fn cells_intersect(cells_a: [(u8, u8); 5], len_a: u8, cells_b: [(u8, u8); 5], len_b: u8) -> bool {
    let mut intersect = false;
    for i in 0..5 {
        if (i as u8) < len_a {
            for j in 0..5 {
                if (j as u8) < len_b {
                    if (cells_a[i].0 == cells_b[j].0) & (cells_a[i].1 == cells_b[j].1) {
                        intersect = true;
                    }
                }
            }
        }
    }
    intersect
}

// Validate a single ship
pub fn validate_single_ship(ship: ShipData, length: u8) {
    // Check in bounds
    assert(ship.x < BOARD_SIZE, "Ship x out of bounds");
    assert(ship.y < BOARD_SIZE, "Ship y out of bounds");

    // Check orientation valid
    assert((ship.orientation == 0) | (ship.orientation == 1), "Invalid orientation");

    // Check ship fits on board
    if ship.orientation == 0 {
        // Horizontal
        assert(ship.x + length <= BOARD_SIZE, "Ship extends past right edge");
    } else {
        // Vertical
        assert(ship.y + length <= BOARD_SIZE, "Ship extends past bottom edge");
    }
}

// Validate all ships in a placement
pub fn validate_ships(ships: ShipPlacement) {
    // Validate each ship individually
    validate_single_ship(ships.carrier, SHIP_SIZES[0]);
    validate_single_ship(ships.battleship, SHIP_SIZES[1]);
    validate_single_ship(ships.cruiser, SHIP_SIZES[2]);
    validate_single_ship(ships.submarine, SHIP_SIZES[3]);
    validate_single_ship(ships.destroyer, SHIP_SIZES[4]);

    // Expand all ships to cells
    let carrier_cells = expand_ship(ships.carrier, SHIP_SIZES[0]);
    let battleship_cells = expand_ship(ships.battleship, SHIP_SIZES[1]);
    let cruiser_cells = expand_ship(ships.cruiser, SHIP_SIZES[2]);
    let submarine_cells = expand_ship(ships.submarine, SHIP_SIZES[3]);
    let destroyer_cells = expand_ship(ships.destroyer, SHIP_SIZES[4]);

    // Check all pairs for overlap (10 pairs total: 5 choose 2)
    assert(!cells_intersect(carrier_cells, SHIP_SIZES[0], battleship_cells, SHIP_SIZES[1]), "Carrier and battleship overlap");
    assert(!cells_intersect(carrier_cells, SHIP_SIZES[0], cruiser_cells, SHIP_SIZES[2]), "Carrier and cruiser overlap");
    assert(!cells_intersect(carrier_cells, SHIP_SIZES[0], submarine_cells, SHIP_SIZES[3]), "Carrier and submarine overlap");
    assert(!cells_intersect(carrier_cells, SHIP_SIZES[0], destroyer_cells, SHIP_SIZES[4]), "Carrier and destroyer overlap");
    assert(!cells_intersect(battleship_cells, SHIP_SIZES[1], cruiser_cells, SHIP_SIZES[2]), "Battleship and cruiser overlap");
    assert(!cells_intersect(battleship_cells, SHIP_SIZES[1], submarine_cells, SHIP_SIZES[3]), "Battleship and submarine overlap");
    assert(!cells_intersect(battleship_cells, SHIP_SIZES[1], destroyer_cells, SHIP_SIZES[4]), "Battleship and destroyer overlap");
    assert(!cells_intersect(cruiser_cells, SHIP_SIZES[2], submarine_cells, SHIP_SIZES[3]), "Cruiser and submarine overlap");
    assert(!cells_intersect(cruiser_cells, SHIP_SIZES[2], destroyer_cells, SHIP_SIZES[4]), "Cruiser and destroyer overlap");
    assert(!cells_intersect(submarine_cells, SHIP_SIZES[3], destroyer_cells, SHIP_SIZES[4]), "Submarine and destroyer overlap");
}

// Check if a shot hits any ship
pub fn check_hit(x: u8, y: u8, ships: ShipPlacement) -> bool {
    // Expand all ships
    let carrier_cells = expand_ship(ships.carrier, SHIP_SIZES[0]);
    let battleship_cells = expand_ship(ships.battleship, SHIP_SIZES[1]);
    let cruiser_cells = expand_ship(ships.cruiser, SHIP_SIZES[2]);
    let submarine_cells = expand_ship(ships.submarine, SHIP_SIZES[3]);
    let destroyer_cells = expand_ship(ships.destroyer, SHIP_SIZES[4]);

    // Check if (x,y) matches any cell in any ship
    let mut hit = false;

    for i in 0..5 {
        if (i as u8) < SHIP_SIZES[0] {
            if (carrier_cells[i].0 == x) & (carrier_cells[i].1 == y) {
                hit = true;
            }
        }
        if (i as u8) < SHIP_SIZES[1] {
            if (battleship_cells[i].0 == x) & (battleship_cells[i].1 == y) {
                hit = true;
            }
        }
        if (i as u8) < SHIP_SIZES[2] {
            if (cruiser_cells[i].0 == x) & (cruiser_cells[i].1 == y) {
                hit = true;
            }
        }
        if (i as u8) < SHIP_SIZES[3] {
            if (submarine_cells[i].0 == x) & (submarine_cells[i].1 == y) {
                hit = true;
            }
        }
        if (i as u8) < SHIP_SIZES[4] {
            if (destroyer_cells[i].0 == x) & (destroyer_cells[i].1 == y) {
                hit = true;
            }
        }
    }

    hit
}
