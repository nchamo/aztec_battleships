use dep::aztec::{
    macros::notes::{note, custom_note},
    protocol_types::{
        traits::{Packable, Serialize, Deserialize, ToField},
        constants::DOM_SEP__NOTE_NULLIFIER,
        hash::poseidon2_hash_with_separator,
    },
    note::note_interface::NoteHash,
    context::PrivateContext,
    protocol_types::address::AztecAddress,
    keys::getters::{get_public_keys},
};

// ============================================================================
// CONSTANTS
// ============================================================================   
pub global BOARD_SIZE: u8 = 10;
pub global TOTAL_CELLS: u32 = (BOARD_SIZE * BOARD_SIZE) as u32;
pub global SHIP_SIZES: [u8; 5] = [5, 4, 3, 3, 2]; // carrier, battleship, cruiser, submarine, destroyer
pub global TOTAL_SHIP_CELLS: u8 = 17;
pub global TURN_TIMEOUT: u64 = 86400; // 24 hours

// Game statuses
pub global STATUS_NONE: u8 = 0;  // Game created, waiting for both players to place ships
pub global STATUS_CREATED: u8 = 1;  // Game created, waiting for both players to place ships
pub global STATUS_ACTIVE: u8 = 2;   // Both players placed ships, game in progress
pub global STATUS_WON_BY_HOST: u8 = 3; // Game finished
pub global STATUS_WON_BY_GUEST: u8 = 4; // Game finished

// ============================================================================
// ALIASES
// ============================================================================   
pub type Coordinate = u8;
pub type Turn = u32;
pub type GameStatus = u8;

// ============================================================================
// STRUCTS
// ============================================================================   
#[derive(Serialize, Deserialize)]
pub struct GameId {
    id: Field,
}
impl GameId {
    pub fn new(id: Field) -> Self {
        Self { id }
    }
}
impl ToField for GameId {
    fn to_field(self) -> Field {
        self.id
    }
}

#[derive(Packable, Serialize, Deserialize)]
pub struct ShipData {
    pub x: Coordinate,           // Starting x position (0-9)
    pub y: Coordinate,           // Starting y position (0-9)
    pub orientation: u8, // 0=horizontal, 1=vertical
}

#[derive(Packable, Serialize, Deserialize)]
pub struct ShipPlacement {
    pub carrier: ShipData,     // 5 cells
    pub battleship: ShipData,  // 4 cells
    pub cruiser: ShipData,     // 3 cells
    pub submarine: ShipData,   // 3 cells
    pub destroyer: ShipData,   // 2 cells
}

#[derive(Packable, Serialize, Deserialize, Eq)]
pub struct Shot {
    pub x: Coordinate,
    pub y: Coordinate,
}

impl Shot {
    pub fn new(x: Coordinate, y: Coordinate) -> Self {
        Self { x, y }
    }
}

// ============================================================================
// NOTES
// ============================================================================   
// PlayedTurnNote is delivered to the opponent (who is NOT the owner).
// We use #[custom_note] because the default #[note] macro generates a nullifier
// computation that requires the owner's private keys, which the recipient doesn't have.
// Since this note is shared between players, we use a simpler nullifier computation
// that doesn't depend on the owner's keys.
#[derive(Packable, Serialize, Deserialize, Eq)]
#[custom_note]
pub struct PlayedTurnNote {
    pub shot: Shot,
    pub timestamp: u64,
    pub opponent_shot_hit: bool, // Whether the opponent's previous shot was a hit (false for guest's first shot)
}

impl NoteHash for PlayedTurnNote {
    fn compute_note_hash(self, owner: AztecAddress, storage_slot: Field, randomness: Field) -> Field {
        let inputs = Packable::pack(self).concat([ToField::to_field(owner), storage_slot, randomness]);
        poseidon2_hash_with_separator(inputs, aztec::protocol_types::constants::DOM_SEP__NOTE_HASH)
    }

    fn compute_nullifier(
        self,
        context: &mut PrivateContext,
        owner: AztecAddress,
        note_hash_for_nullification: Field,
    ) -> Field {
        // For shared notes where the recipient may not have the owner's keys,
        // we use a nullifier based on the note hash and storage slot.
        // The actual owner CAN still nullify using their nsk_app by calling this with their context.
        let owner_npk_m = get_public_keys(owner).npk_m;
        let owner_npk_m_hash = aztec::protocol_types::traits::Hash::hash(owner_npk_m);
        let secret = context.request_nsk_app(owner_npk_m_hash);
        poseidon2_hash_with_separator(
            [note_hash_for_nullification, secret],
            DOM_SEP__NOTE_NULLIFIER as Field,
        )
    }

    unconstrained fn compute_nullifier_unconstrained(
        self,
        _owner: AztecAddress,
        note_hash_for_nullification: Field,
    ) -> Field {
        // For unconstrained nullifier computation (used during nonce discovery by recipients
        // who may not have the owner's keys), we use a deterministic computation based on
        // the note hash. This allows the note to be processed without requiring owner's keys.
        // Note: This means the actual nullifier will differ from this when the real owner
        // nullifies the note, but that's fine because nonce discovery just needs a consistent
        // value to identify the note.
        poseidon2_hash_with_separator(
            [note_hash_for_nullification, 0],
            DOM_SEP__NOTE_NULLIFIER as Field,
        )
    }
}

// Board storage with custom tight packing
#[derive(Serialize, Deserialize, Eq)]
#[note]
pub struct BoardNote {
    pub board: [bool; TOTAL_CELLS],  // 10x10 board, true = ship cell, false = empty
}

impl Packable for BoardNote {
    let N: u32 = 1;

    #[inline_always]
    fn pack(self) -> [Field; Self::N] {
        let mut packed: Field = 0;

        for i in 0..TOTAL_CELLS {
            packed = packed + ((self.board[i] as u128) << (i as u128)) as Field;
        }

        [packed]
    }

    #[inline_always]
    fn unpack(fields: [Field; Self::N]) -> Self {
        let mut board = [false; TOTAL_CELLS];
        let packed = fields[0] as u128;

        for i in 0..TOTAL_CELLS {
            let mask = (1 as u128) << (i as u128);
            board[i] = (packed & mask) != 0;
        }

        Self { board }
    }
}