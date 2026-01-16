use crate::types::{ShipData, ShipPlacement, Shot};
use crate::utils::{expand_ship, cells_intersect, validate_single_ship, validate_shot, validate_and_build_board};
use crate::test::helpers::{
    create_valid_ships, create_valid_ships_player2, create_overlapping_ships,
    create_ship_past_right_edge, create_ship_past_bottom_edge,
    create_ship_x_out_of_bounds, create_ship_y_out_of_bounds, create_ship_invalid_orientation
};

// ============================================================================
// expand_ship() tests
// ============================================================================

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

// ============================================================================
// validate_single_ship() tests
// ============================================================================

#[test]
unconstrained fn test_validate_ship_valid() {
    let ship = ShipData { x: 5, y: 5, orientation: 0 };
    validate_single_ship(ship, 3);  // Should not fail
}

#[test(should_fail_with = "Ship x out of bounds")]
unconstrained fn test_validate_ship_x_out_of_bounds() {
    let ship = create_ship_x_out_of_bounds();
    validate_single_ship(ship, 3);
}

#[test(should_fail_with = "Ship y out of bounds")]
unconstrained fn test_validate_ship_y_out_of_bounds() {
    let ship = create_ship_y_out_of_bounds();
    validate_single_ship(ship, 3);
}

#[test(should_fail_with = "Invalid orientation")]
unconstrained fn test_validate_ship_invalid_orientation() {
    let ship = create_ship_invalid_orientation();
    validate_single_ship(ship, 3);
}

#[test(should_fail_with = "Ship extends past right edge")]
unconstrained fn test_validate_ship_extends_past_right() {
    let ship = create_ship_past_right_edge();
    validate_single_ship(ship, 5);  // Length 5 at x=8 -> extends to x=13
}

#[test(should_fail_with = "Ship extends past bottom edge")]
unconstrained fn test_validate_ship_extends_past_bottom() {
    let ship = create_ship_past_bottom_edge();
    validate_single_ship(ship, 4);  // Length 4 at y=7 -> extends to y=11
}

// ============================================================================
// cells_intersect() tests
// ============================================================================

#[test]
unconstrained fn test_cells_no_intersection() {
    let ship1 = ShipData { x: 0, y: 0, orientation: 0 };
    let ship2 = ShipData { x: 5, y: 5, orientation: 0 };

    let cells1 = expand_ship(ship1, 3);
    let cells2 = expand_ship(ship2, 3);

    let intersects = cells_intersect(cells1, 3, cells2, 3);
    assert(!intersects, "Ships should not intersect");
}

#[test]
unconstrained fn test_cells_intersection() {
    let ship1 = ShipData { x: 0, y: 0, orientation: 0 };
    let ship2 = ShipData { x: 0, y: 0, orientation: 1 };

    let cells1 = expand_ship(ship1, 3);
    let cells2 = expand_ship(ship2, 3);

    let intersects = cells_intersect(cells1, 3, cells2, 3);
    assert(intersects, "Ships should intersect at (0,0)");
}

#[test]
unconstrained fn test_cells_adjacent_no_intersection() {
    let ship1 = ShipData { x: 0, y: 0, orientation: 0 };  // (0,0)-(2,0)
    let ship2 = ShipData { x: 0, y: 1, orientation: 0 };  // (0,1)-(2,1)

    let cells1 = expand_ship(ship1, 3);
    let cells2 = expand_ship(ship2, 3);

    let intersects = cells_intersect(cells1, 3, cells2, 3);
    assert(!intersects, "Adjacent ships should not intersect");
}

#[test]
unconstrained fn test_cells_exact_overlap() {
    let ship1 = ShipData { x: 5, y: 5, orientation: 0 };
    let ship2 = ShipData { x: 5, y: 5, orientation: 0 };

    let cells1 = expand_ship(ship1, 3);
    let cells2 = expand_ship(ship2, 3);

    let intersects = cells_intersect(cells1, 3, cells2, 3);
    assert(intersects, "Exact same position should intersect");
}

// ============================================================================
// validate_shot() tests
// ============================================================================

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

// ============================================================================
// validate_and_build_board() tests - Optimized unified function
// ============================================================================

#[test]
unconstrained fn test_validate_and_build_board_valid_ships() {
    let ships = create_valid_ships();
    let board = validate_and_build_board(ships);

    // Should not fail validation
    // Should produce correct board with all 17 cells marked

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

#[test(should_fail_with = "Carrier and battleship overlap")]
unconstrained fn test_validate_and_build_board_overlapping() {
    let ships = create_overlapping_ships();
    let _ = validate_and_build_board(ships);  // Should fail with overlap error
}

#[test]
unconstrained fn test_validate_and_build_board_vertical_ships() {
    let ships = create_valid_ships_player2();
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

#[test(should_fail_with = "Ship extends past right edge")]
unconstrained fn test_validate_and_build_board_extends_past_edge() {
    let ships = ShipPlacement {
        carrier: create_ship_past_right_edge(),  // x=8, length=5 -> extends to 13
        battleship: ShipData { x: 0, y: 5, orientation: 0 },
        cruiser: ShipData { x: 0, y: 6, orientation: 0 },
        submarine: ShipData { x: 0, y: 7, orientation: 0 },
        destroyer: ShipData { x: 0, y: 8, orientation: 0 },
    };
    let _ = validate_and_build_board(ships);  // Should fail
}

#[test]
unconstrained fn test_validate_and_build_board_count_cells() {
    let ships = create_valid_ships();
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
