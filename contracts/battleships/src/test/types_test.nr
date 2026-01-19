use crate::types::{BoardNote, TOTAL_CELLS};
use dep::aztec::protocol_types::traits::Packable;

// ============================================================================
// BoardNote pack/unpack tests
// ============================================================================

#[test]
unconstrained fn test_board_note_pack_all_false() {
    let board = [false; TOTAL_CELLS];
    let note = BoardNote { board };

    let packed = note.pack();

    assert(packed[0] == 0);
}

#[test]
unconstrained fn test_board_note_pack_all_true() {
    let board = [true; TOTAL_CELLS];
    let note = BoardNote { board };

    let packed = note.pack();

    assert(packed[0] != 0);
}

#[test]
unconstrained fn test_board_note_pack_unpack_roundtrip() {
    // Create a specific pattern
    let mut board = [false; TOTAL_CELLS];
    board[0] = true;   // Cell (0,0)
    board[10] = true;  // Cell (1,0)
    board[99] = true;  // Cell (9,9)
    board[50] = true;  // Cell (5,0)

    let note = BoardNote { board };

    // Pack then unpack
    let packed = note.pack();
    let unpacked = BoardNote::unpack(packed);

    // Verify all cells match
    for i in 0..TOTAL_CELLS {
        assert(unpacked.board[i as u32] == board[i as u32]);
    }
}

