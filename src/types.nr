use dep::aztec::protocol_types::traits::{Serialize, Deserialize, Packable};

// Constants
pub global BOARD_SIZE: u8 = 10;
pub global SHIP_SIZES: [u8; 5] = [5, 4, 3, 3, 2]; // carrier, battleship, cruiser, submarine, destroyer
pub global TOTAL_SHIP_CELLS: u8 = 17;
pub global SETUP_TIMEOUT: u64 = 3600; // 1 hour
pub global TURN_TIMEOUT: u64 = 86400; // 24 hours

// Game statuses
pub global STATUS_CREATED: u8 = 0;  // Game created, waiting for both players to place ships
pub global STATUS_ACTIVE: u8 = 1;   // Both players placed ships, game in progress
pub global STATUS_COMPLETED: u8 = 2; // Game finished

// Win types
pub global WIN_NONE: u8 = 0;
pub global WIN_VICTORY: u8 = 1;
pub global WIN_ABANDONMENT: u8 = 2;

// Type alias for game identifiers
pub type GameId = Field;

// Type alias for coordinates (cleaner map keys)
pub type Coordinate = Field;

// Ship data - position and orientation
pub struct ShipData {
    pub x: u8,           // Starting x position (0-9)
    pub y: u8,           // Starting y position (0-9)
    pub orientation: u8, // 0=horizontal, 1=vertical
}

impl ShipData {
    pub fn new(x: u8, y: u8, orientation: u8) -> Self {
        Self { x, y, orientation }
    }

    pub fn pack(self) -> Field {
        (self.x as Field) + (self.y as Field) * 256 + (self.orientation as Field) * 65536
    }

    pub fn unpack(packed: Field) -> Self {
        let packed_u32 = packed as u32;
        let x = (packed_u32 % 256) as u8;
        let y = ((packed_u32 / 256) % 256) as u8;
        let orientation = ((packed_u32 / 65536) % 256) as u8;
        Self { x, y, orientation }
    }
}

// Ship placement for a player - all 5 ships
pub struct ShipPlacement {
    pub carrier: ShipData,     // 5 cells
    pub battleship: ShipData,  // 4 cells
    pub cruiser: ShipData,     // 3 cells
    pub submarine: ShipData,   // 3 cells
    pub destroyer: ShipData,   // 2 cells
}

impl ShipPlacement {
    pub fn new(
        carrier: ShipData,
        battleship: ShipData,
        cruiser: ShipData,
        submarine: ShipData,
        destroyer: ShipData
    ) -> Self {
        Self {
            carrier,
            battleship,
            cruiser,
            submarine,
            destroyer
        }
    }
}

impl Serialize for ShipPlacement {
    fn serialize(self) -> [Field; 5] {
        [
            self.carrier.pack(),
            self.battleship.pack(),
            self.cruiser.pack(),
            self.submarine.pack(),
            self.destroyer.pack(),
        ]
    }
}

impl Deserialize for ShipPlacement {
    fn deserialize(fields: [Field; 5]) -> Self {
        Self {
            carrier: ShipData::unpack(fields[0]),
            battleship: ShipData::unpack(fields[1]),
            cruiser: ShipData::unpack(fields[2]),
            submarine: ShipData::unpack(fields[3]),
            destroyer: ShipData::unpack(fields[4]),
        }
    }
}

impl Packable for ShipPlacement {
    fn pack(self) -> [Field; 5] {
        self.serialize()
    }

    fn unpack(fields: [Field; 5]) -> Self {
        Self::deserialize(fields)
    }
}


// Public game state - visible to all
pub struct PublicGameState {
    pub host: Field,     // Host player address
    pub turn: u8,        // Turn number (0 = host's turn, 1 = guest's turn, etc.)
    pub status: u8,      // Current game status
}

impl GameState {
    pub fn new(
        host: Field,
        guest: Field
    ) -> Self {
        Self {
            host,
            guest,
            turn: 0,  // Turn 0 is always the host
            status: STATUS_CREATED,
        }
    }
}

impl Serialize for GameState {
    fn serialize(self) -> [Field; 4] {
        [self.host, self.guest, self.turn as Field, self.status as Field]
    }
}

impl Deserialize for GameState {
    fn deserialize(fields: [Field; 4]) -> Self {
        Self {
            host: fields[0],
            guest: fields[1],
            turn: fields[2] as u8,
            status: fields[3] as u8,
        }
    }
}

impl Packable for GameState {
    fn pack(self) -> [Field; 4] {
        self.serialize()
    }

    fn unpack(fields: [Field; 4]) -> Self {
        Self::deserialize(fields)
    }
}
