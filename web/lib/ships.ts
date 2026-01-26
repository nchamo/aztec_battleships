import type { ShipPlacement, ShipData, Orientation, ShipName } from './types';
import { BOARD_SIZE, SHIP_NAMES, SHIP_LENGTHS } from './types';

// Get all cells occupied by a ship
export function getShipCells(ship: ShipData, length: number): { x: number; y: number }[] {
  const cells: { x: number; y: number }[] = [];

  for (let i = 0; i < length; i++) {
    if (ship.orientation === 0) {
      // Horizontal
      cells.push({ x: ship.x + i, y: ship.y });
    } else {
      // Vertical
      cells.push({ x: ship.x, y: ship.y + i });
    }
  }

  return cells;
}

// Check if a ship placement is valid (within bounds)
export function isValidPlacement(ship: ShipData, length: number): boolean {
  if (ship.x < 0 || ship.y < 0) return false;

  if (ship.orientation === 0) {
    // Horizontal
    return ship.x + length <= BOARD_SIZE && ship.y < BOARD_SIZE;
  } else {
    // Vertical
    return ship.x < BOARD_SIZE && ship.y + length <= BOARD_SIZE;
  }
}

// Check if two ships overlap
export function shipsOverlap(
  ship1: ShipData,
  length1: number,
  ship2: ShipData,
  length2: number
): boolean {
  const cells1 = getShipCells(ship1, length1);
  const cells2 = getShipCells(ship2, length2);

  for (const c1 of cells1) {
    for (const c2 of cells2) {
      if (c1.x === c2.x && c1.y === c2.y) {
        return true;
      }
    }
  }

  return false;
}

// Validate an entire ship placement
export function validateShipPlacement(placement: ShipPlacement): { valid: boolean; error?: string } {
  const ships: { name: ShipName; data: ShipData }[] = [
    { name: 'carrier', data: placement.carrier },
    { name: 'battleship', data: placement.battleship },
    { name: 'cruiser', data: placement.cruiser },
    { name: 'submarine', data: placement.submarine },
    { name: 'destroyer', data: placement.destroyer },
  ];

  // Check each ship is valid
  for (const ship of ships) {
    const length = SHIP_LENGTHS[ship.name];
    if (!isValidPlacement(ship.data, length)) {
      return { valid: false, error: `${ship.name} is out of bounds` };
    }
  }

  // Check no ships overlap
  for (let i = 0; i < ships.length; i++) {
    for (let j = i + 1; j < ships.length; j++) {
      const ship1 = ships[i];
      const ship2 = ships[j];
      if (
        shipsOverlap(
          ship1.data,
          SHIP_LENGTHS[ship1.name],
          ship2.data,
          SHIP_LENGTHS[ship2.name]
        )
      ) {
        return { valid: false, error: `${ship1.name} overlaps with ${ship2.name}` };
      }
    }
  }

  return { valid: true };
}

// Convert ship placement to 100-cell board
export function placementToBoard(placement: ShipPlacement): boolean[] {
  const board = Array(BOARD_SIZE * BOARD_SIZE).fill(false);

  const ships: { data: ShipData; length: number }[] = [
    { data: placement.carrier, length: 5 },
    { data: placement.battleship, length: 4 },
    { data: placement.cruiser, length: 3 },
    { data: placement.submarine, length: 3 },
    { data: placement.destroyer, length: 2 },
  ];

  for (const ship of ships) {
    const cells = getShipCells(ship.data, ship.length);
    for (const cell of cells) {
      const idx = cell.y * BOARD_SIZE + cell.x;
      board[idx] = true;
    }
  }

  return board;
}

// Generate random ship placement
export function generateRandomPlacement(): ShipPlacement {
  const board = Array(BOARD_SIZE * BOARD_SIZE).fill(false);
  const ships: Partial<ShipPlacement> = {};

  for (const name of SHIP_NAMES) {
    const length = SHIP_LENGTHS[name];
    let placed = false;
    let attempts = 0;

    while (!placed && attempts < 1000) {
      attempts++;

      const orientation: Orientation = Math.random() < 0.5 ? 0 : 1;
      let x: number, y: number;

      if (orientation === 0) {
        // Horizontal
        x = Math.floor(Math.random() * (BOARD_SIZE - length + 1));
        y = Math.floor(Math.random() * BOARD_SIZE);
      } else {
        // Vertical
        x = Math.floor(Math.random() * BOARD_SIZE);
        y = Math.floor(Math.random() * (BOARD_SIZE - length + 1));
      }

      const shipData: ShipData = { x, y, orientation };
      const cells = getShipCells(shipData, length);

      // Check if all cells are free
      const allFree = cells.every((cell) => {
        const idx = cell.y * BOARD_SIZE + cell.x;
        return !board[idx];
      });

      if (allFree) {
        // Place the ship
        for (const cell of cells) {
          const idx = cell.y * BOARD_SIZE + cell.x;
          board[idx] = true;
        }
        ships[name] = shipData;
        placed = true;
      }
    }

    if (!placed) {
      throw new Error(`Failed to place ${name} after 1000 attempts`);
    }
  }

  return ships as ShipPlacement;
}

// Check if a cell is part of a ship
export function getCellShip(
  placement: ShipPlacement,
  x: number,
  y: number
): ShipName | null {
  for (const name of SHIP_NAMES) {
    const ship = placement[name];
    const length = SHIP_LENGTHS[name];
    const cells = getShipCells(ship, length);

    for (const cell of cells) {
      if (cell.x === x && cell.y === y) {
        return name;
      }
    }
  }

  return null;
}
