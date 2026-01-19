use dep::aztec::{macros::notes::note, protocol_types::traits::{Packable, Serialize, Deserialize, ToField}};

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
#[derive(Packable, Serialize, Deserialize)]
#[note]
pub struct PlayedTurnNote {
    pub shot: Shot,
    pub timestamp: u64
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