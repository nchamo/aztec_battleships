use dep::aztec::{macros::notes::note, protocol_types::traits::{Packable, Serialize, Deserialize, ToField}};

// Constants
pub global BOARD_SIZE: u8 = 10;
pub global SHIP_SIZES: [u8; 5] = [5, 4, 3, 3, 2]; // carrier, battleship, cruiser, submarine, destroyer
pub global TOTAL_SHIP_CELLS: u8 = 17;
pub global TURN_TIMEOUT: u64 = 86400; // 24 hours

// Game statuses
pub global STATUS_CREATED: u8 = 0;  // Game created, waiting for both players to place ships
pub global STATUS_ACTIVE: u8 = 1;   // Both players placed ships, game in progress
pub global STATUS_WON_BY_HOST: u8 = 2; // Game finished
pub global STATUS_WON_BY_GUEST: u8 = 3; // Game finished

// Game identifier struct
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

// Type alias for coordinates (cleaner map keys)
pub type Coordinate = Field;

// Shot coordinates
#[derive(Packable, Serialize, Deserialize)]
pub struct Shot {
    pub x: u8,
    pub y: u8,
}

#[derive(Packable, Serialize, Deserialize)]
#[note]
pub struct ShotNote {
    pub shot: Shot,
}

impl Shot {
    pub fn new(x: u8, y: u8) -> Self {
        Self { x, y }
    }
}

// Player's own last action - used to track when they last acted
#[derive(Packable, Serialize, Deserialize)]
#[note]
pub struct PlayerActionNote {
    pub turn: u8,        // Which turn this action was taken
    pub timestamp: u64,     // When this action was taken
}

// Opponent's last action - includes their shot
#[derive(Packable, Serialize, Deserialize)]
#[note]
pub struct OpponentActionNote {
    pub turn: u8,        // Which turn the opponent took this action
    pub shot: Shot,         // The shot the opponent took
}

// Ship data - position and orientation
#[derive(Packable, Serialize, Deserialize)]
pub struct ShipData {
    pub x: u8,           // Starting x position (0-9)
    pub y: u8,           // Starting y position (0-9)
    pub orientation: u8, // 0=horizontal, 1=vertical
}

// Ship placement for a player - all 5 ships
#[derive(Packable, Serialize, Deserialize)]
pub struct ShipPlacement {
    pub carrier: ShipData,     // 5 cells
    pub battleship: ShipData,  // 4 cells
    pub cruiser: ShipData,     // 3 cells
    pub submarine: ShipData,   // 3 cells
    pub destroyer: ShipData,   // 2 cells
}

// Public game state - visible to all
#[derive(Serialize, Deserialize, Packable)]
pub struct PublicGameState {
    pub host: Field,     // Host player address
    pub status: u8,      // Current game status
}

impl PublicGameState {
    pub fn new(host: Field) -> Self {
        Self {
            host,
            status: STATUS_CREATED,
        }
    }
}

// Board storage with custom tight packing (100 bools -> 1 Field)
#[derive(Serialize, Deserialize)]
#[note]
pub struct BoardNote {
    pub board: [bool; 100],  // 10x10 board, true = ship cell, false = empty
}

impl Packable for BoardNote {
    let N: u32 = 1;  // Only 1 Field needed

    #[inline_always]
    fn pack(self) -> [Field; Self::N] {
        let mut packed: u128 = 0;

        // Pack all 100 bools into single u128
        for i in 0..100 {
            if self.board[i as u32] {
                packed = packed | ((1 as u128) << (i as u128));
            }
        }

        [packed as Field]
    }

    #[inline_always]
    fn unpack(fields: [Field; Self::N]) -> Self {
        let mut board: [bool; 100] = [false; 100];
        let packed: u128 = fields[0] as u128;

        // Unpack all 100 bools from single u128
        for i in 0..100 {
            let mask = (1 as u128) << (i as u128);
            board[i as u32] = (packed & mask) != 0;
        }

        Self { board }
    }
}