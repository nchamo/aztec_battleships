use crate::types::BoardNote;
use dep::aztec::protocol_types::traits::Packable;

// ============================================================================
// BoardNote pack/unpack tests
// ============================================================================

#[test]
unconstrained fn test_board_note_pack_all_false() {
    let board: [bool; 100] = [false; 100];
    let note = BoardNote { board };

    let packed = note.pack();

    // All false should pack to 0
    assert(packed[0] == 0, "All false board should pack to 0");
}

#[test]
unconstrained fn test_board_note_pack_all_true() {
    let board: [bool; 100] = [true; 100];
    let note = BoardNote { board };

    let packed = note.pack();

    // All true should pack to maximum value
    // 100 bits all set would be (2^100 - 1), but we're using Field
    assert(packed[0] != 0, "All true board should not pack to 0");
}

#[test]
unconstrained fn test_board_note_pack_unpack_roundtrip() {
    // Create a specific pattern
    let mut board: [bool; 100] = [false; 100];
    board[0] = true;   // Cell (0,0)
    board[10] = true;  // Cell (1,0)
    board[99] = true;  // Cell (9,9)
    board[50] = true;  // Cell (5,0)

    let note = BoardNote { board };

    // Pack then unpack
    let packed = note.pack();
    let unpacked = BoardNote::unpack(packed);

    // Verify all cells match
    for i in 0..100 {
        assert(unpacked.board[i as u32] == board[i as u32], "Roundtrip failed for cell");
    }
}

#[test]
unconstrained fn test_board_note_specific_pattern() {
    // Test pattern matching standard ship placement (17 cells)
    let mut board: [bool; 100] = [false; 100];

    // Carrier at (0,0)-(4,0): indices 0,1,2,3,4
    board[0] = true;
    board[1] = true;
    board[2] = true;
    board[3] = true;
    board[4] = true;

    // Battleship at (0,1)-(3,1): indices 10,11,12,13
    board[10] = true;
    board[11] = true;
    board[12] = true;
    board[13] = true;

    // Cruiser at (0,2)-(2,2): indices 20,21,22
    board[20] = true;
    board[21] = true;
    board[22] = true;

    // Submarine at (0,3)-(2,3): indices 30,31,32
    board[30] = true;
    board[31] = true;
    board[32] = true;

    // Destroyer at (0,4)-(1,4): indices 40,41
    board[40] = true;
    board[41] = true;

    let note = BoardNote { board };
    let packed = note.pack();
    let unpacked = BoardNote::unpack(packed);

    // Verify all ship cells are set
    assert(unpacked.board[0], "Carrier cell 0 not set");
    assert(unpacked.board[4], "Carrier cell 4 not set");
    assert(unpacked.board[10], "Battleship cell 0 not set");
    assert(unpacked.board[13], "Battleship cell 3 not set");
    assert(unpacked.board[20], "Cruiser cell 0 not set");
    assert(unpacked.board[22], "Cruiser cell 2 not set");
    assert(unpacked.board[30], "Submarine cell 0 not set");
    assert(unpacked.board[32], "Submarine cell 2 not set");
    assert(unpacked.board[40], "Destroyer cell 0 not set");
    assert(unpacked.board[41], "Destroyer cell 1 not set");

    // Verify some empty cells
    assert(!unpacked.board[5], "Empty cell 5 should be false");
    assert(!unpacked.board[99], "Empty cell 99 should be false");
}

#[test]
unconstrained fn test_board_note_edge_cells() {
    let mut board: [bool; 100] = [false; 100];

    // Set edge cells
    board[0] = true;   // Top-left (0,0)
    board[9] = true;   // Top-right (9,0)
    board[90] = true;  // Bottom-left (0,9)
    board[99] = true;  // Bottom-right (9,9)
    board[50] = true;  // Middle (0,5)

    let note = BoardNote { board };
    let packed = note.pack();
    let unpacked = BoardNote::unpack(packed);

    assert(unpacked.board[0], "Top-left cell not preserved");
    assert(unpacked.board[9], "Top-right cell not preserved");
    assert(unpacked.board[90], "Bottom-left cell not preserved");
    assert(unpacked.board[99], "Bottom-right cell not preserved");
    assert(unpacked.board[50], "Middle cell not preserved");

    // Verify adjacent cells are false
    assert(!unpacked.board[1], "Cell 1 should be false");
    assert(!unpacked.board[89], "Cell 89 should be false");
    assert(!unpacked.board[98], "Cell 98 should be false");
}

#[test]
unconstrained fn test_board_note_alternating_pattern() {
    let mut board: [bool; 100] = [false; 100];

    // Set alternating cells
    for i in 0..50 {
        board[(i * 2) as u32] = true;  // Even indices
    }

    let note = BoardNote { board };
    let packed = note.pack();
    let unpacked = BoardNote::unpack(packed);

    // Verify pattern preserved
    for i in 0..100 {
        let expected = (i % 2) == 0;
        assert(unpacked.board[i as u32] == expected, "Alternating pattern not preserved");
    }
}

#[test]
unconstrained fn test_board_note_single_cell_set() {
    // Test each individual cell can be set correctly
    for test_idx in 0..10 {  // Test first 10 cells as sample
        let mut board: [bool; 100] = [false; 100];
        board[test_idx as u32] = true;

        let note = BoardNote { board };
        let packed = note.pack();
        let unpacked = BoardNote::unpack(packed);

        assert(unpacked.board[test_idx as u32], "Cell should be set");

        // Verify all other cells are false
        for i in 0..100 {
            if i != test_idx {
                assert(!unpacked.board[i as u32], "Other cells should be false");
            }
        }
    }
}
