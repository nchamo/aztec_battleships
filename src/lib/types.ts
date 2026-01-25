// Game types matching the contract definitions

export const BOARD_SIZE = 10;
export const TOTAL_SHIP_CELLS = 17;
export const SHIP_SIZES = [5, 4, 3, 3, 2] as const; // carrier, battleship, cruiser, submarine, destroyer

// Game status constants matching contract (from types.nr)
export const STATUS_NONE = 0;        // No game exists
export const STATUS_CREATED = 1;     // Game created, waiting for guest
export const STATUS_ACTIVE = 2;      // Both players joined, game in progress
export const STATUS_WON_BY_HOST = 3; // Host won
export const STATUS_WON_BY_GUEST = 4; // Guest won

export type GameStatus =
  | typeof STATUS_NONE
  | typeof STATUS_CREATED
  | typeof STATUS_ACTIVE
  | typeof STATUS_WON_BY_HOST
  | typeof STATUS_WON_BY_GUEST;

export type Orientation = 0 | 1; // 0 = horizontal, 1 = vertical

export interface ShipData {
  x: number;
  y: number;
  orientation: Orientation;
}

export interface ShipPlacement {
  carrier: ShipData;     // 5 cells
  battleship: ShipData;  // 4 cells
  cruiser: ShipData;     // 3 cells
  submarine: ShipData;   // 3 cells
  destroyer: ShipData;   // 2 cells
}

export interface Shot {
  x: number;
  y: number;
}

// Turn data returned from contract's get_turn
export interface PlayedTurn {
  shot: Shot;
  timestamp: bigint;
  opponent_shot_hit: boolean; // Whether the opponent's previous shot was a hit
}

export type CellState = 'empty' | 'ship' | 'hit' | 'miss' | 'sunk' | 'pending';

export type PlayerSlot = 'host' | 'guest';

export interface GameState {
  gameId: string | null;
  isHost: boolean;
  currentTurn: number;
  status: GameStatus;
  myShips: ShipPlacement | null;
  myBoard: boolean[]; // 100 cells, true = ship
  trackingBoard: CellState[]; // 100 cells showing shots fired at opponent
  opponentShots: Shot[]; // shots opponent has fired at me
  myHits: number; // how many times I've hit opponent
  opponentHits: number; // how many times opponent has hit me
}

export const SHIP_NAMES = ['carrier', 'battleship', 'cruiser', 'submarine', 'destroyer'] as const;
export type ShipName = typeof SHIP_NAMES[number];

export const SHIP_LENGTHS: Record<ShipName, number> = {
  carrier: 5,
  battleship: 4,
  cruiser: 3,
  submarine: 3,
  destroyer: 2,
};
