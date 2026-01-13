use dep::aztec::{macros::notes::note, protocol_types::traits::{Packable, Serialize, Deserialize, ToField}};

// Constants
pub global BOARD_SIZE: u8 = 10;
pub global SHIP_SIZES: [u8; 5] = [5, 4, 3, 3, 2]; // carrier, battleship, cruiser, submarine, destroyer
pub global TOTAL_SHIP_CELLS: u8 = 17;
pub global TURN_TIMEOUT: u64 = 86400; // 24 hours

// Game statuses
pub global STATUS_CREATED: u8 = 0;  // Game created, waiting for both players to place ships
pub global STATUS_ACTIVE: u8 = 1;   // Both players placed ships, game in progress
pub global STATUS_COMPLETED: u8 = 2; // Game finished

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

#[derive(Packable, Serialize, Deserialize)]
#[note]
pub struct ShotNote {
    pub shot: Shot,
}

// Shot coordinates
#[derive(Packable, Serialize, Deserialize)]
pub struct Shot {
    pub x: u8,
    pub y: u8,
}

impl Shot {
    pub fn new(x: u8, y: u8) -> Self {
        Self { x, y }
    }
}

// Ship data - position and orientation
#[derive(Packable, Serialize, Deserialize)]
pub struct ShipData {
    pub x: u8,           // Starting x position (0-9)
    pub y: u8,           // Starting y position (0-9)
    pub orientation: u8, // 0=horizontal, 1=vertical
}

// impl ShipData {
//     pub fn new(x: u8, y: u8, orientation: u8) -> Self {
//         Self { x, y, orientation }
//     }

//     pub fn pack(self) -> Field {
//         (self.x as Field) + (self.y as Field) * 256 + (self.orientation as Field) * 65536
//     }

//     pub fn unpack(packed: Field) -> Self {
//         let packed_u32 = packed as u32;
//         let x = (packed_u32 % 256) as u8;
//         let y = ((packed_u32 / 256) % 256) as u8;
//         let orientation = ((packed_u32 / 65536) % 256) as u8;
//         Self { x, y, orientation }
//     }
// }

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
    pub turn: u8,        // Turn number (0 = host's turn, 1 = guest's turn, etc.)
    pub status: u8,      // Current game status
}

impl PublicGameState {
    pub fn new(host: Field) -> Self {
        Self {
            host,
            turn: 0,
            status: STATUS_CREATED,
        }
    }
}