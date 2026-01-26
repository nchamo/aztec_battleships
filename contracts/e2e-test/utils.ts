import { BattleshipsContract, BattleshipsContractArtifact } from "../../web/artifacts/Battleships.js";
import { Contract } from "@aztec/aztec.js/contracts";
import type { Wallet } from "@aztec/aztec.js/wallet";

// Game status constants matching the contract
export const STATUS_NONE = 0;
export const STATUS_CREATED = 1;
export const STATUS_ACTIVE = 2;
export const STATUS_WON_BY_HOST = 3;
export const STATUS_WON_BY_GUEST = 4;

// Ship placement types
export interface ShipData {
  x: number;
  y: number;
  orientation: number; // 0 = horizontal, 1 = vertical
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

export interface GameId {
  id: bigint;
}

/**
 * Helper to create a GameId struct for the contract
 */
export function createGameId(id: number | bigint): GameId {
  return { id: BigInt(id) };
}

/**
 * Create valid non-overlapping ship placement for player 1 (host)
 * Ships are placed horizontally in rows 0-4
 */
export function createValidShipsHost(): ShipPlacement {
  return {
    carrier: { x: 0, y: 0, orientation: 0 },     // (0,0)-(4,0) horizontal
    battleship: { x: 0, y: 1, orientation: 0 },  // (0,1)-(3,1) horizontal
    cruiser: { x: 0, y: 2, orientation: 0 },     // (0,2)-(2,2) horizontal
    submarine: { x: 0, y: 3, orientation: 0 },   // (0,3)-(2,3) horizontal
    destroyer: { x: 0, y: 4, orientation: 0 },   // (0,4)-(1,4) horizontal
  };
}

/**
 * Create valid ship placement for player 2 (guest) - different positions
 * Ships are placed vertically in columns 5-9
 */
export function createValidShipsGuest(): ShipPlacement {
  return {
    carrier: { x: 5, y: 5, orientation: 1 },     // (5,5)-(5,9) vertical
    battleship: { x: 6, y: 5, orientation: 1 },  // (6,5)-(6,8) vertical
    cruiser: { x: 7, y: 5, orientation: 1 },     // (7,5)-(7,7) vertical
    submarine: { x: 8, y: 5, orientation: 1 },   // (8,5)-(8,7) vertical
    destroyer: { x: 9, y: 5, orientation: 1 },   // (9,5)-(9,6) vertical
  };
}

/**
 * Calculate all cells occupied by a ship placement (17 total cells)
 * Returns array of {x, y} coordinates
 */
export function getShipCells(placement: ShipPlacement): { x: number; y: number }[] {
  const cells: { x: number; y: number }[] = [];

  const ships: { data: ShipData; length: number }[] = [
    { data: placement.carrier, length: 5 },
    { data: placement.battleship, length: 4 },
    { data: placement.cruiser, length: 3 },
    { data: placement.submarine, length: 3 },
    { data: placement.destroyer, length: 2 },
  ];

  for (const ship of ships) {
    for (let i = 0; i < ship.length; i++) {
      if (ship.data.orientation === 0) {
        // Horizontal
        cells.push({ x: ship.data.x + i, y: ship.data.y });
      } else {
        // Vertical
        cells.push({ x: ship.data.x, y: ship.data.y + i });
      }
    }
  }

  return cells;
}

/**
 * Get coordinates that will miss all ships in a placement
 * Useful for testing scenarios where a player needs to miss
 */
export function getMissCoordinates(placement: ShipPlacement, count: number): Shot[] {
  const shipCells = getShipCells(placement);
  const shipSet = new Set(shipCells.map(c => `${c.x},${c.y}`));

  const misses: Shot[] = [];
  for (let y = 0; y < 10 && misses.length < count; y++) {
    for (let x = 0; x < 10 && misses.length < count; x++) {
      if (!shipSet.has(`${x},${y}`)) {
        misses.push({ x, y });
      }
    }
  }

  return misses;
}

/**
 * Deploys the Battleships contract.
 * @param deployer - The wallet to deploy the contract with.
 * @returns A deployed contract instance.
 */
export async function deployBattleships(
  deployer: Wallet
): Promise<BattleshipsContract> {
  const deployerAddress = (await deployer.getAccounts())[0]!.item;
  const deployMethod = await Contract.deploy(
    deployer,
    BattleshipsContractArtifact,
    [], // No constructor arguments - contract has no initializer
    undefined, // Use default constructor
  );
  const tx = await deployMethod.send({
    from: deployerAddress,
  });
  const contract = await tx.deployed();
  return contract as BattleshipsContract;
}
