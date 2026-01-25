import { useState, useMemo, useEffect, useCallback } from 'react';
import { Grid } from './Grid';
import { useGameStore } from '../store/game';
import type { ShipPlacement as ShipPlacementType, ShipData, ShipName, Orientation } from '../lib/types';
import { SHIP_NAMES, SHIP_LENGTHS } from '../lib/types';
import {
  generateRandomPlacement,
  placementToBoard,
  validateShipPlacement,
  getShipCells,
  isValidPlacement,
  shipsOverlap,
} from '../lib/ships';

export function ShipPlacement() {
  const { setMyShips, setMyBoard, setPhase } = useGameStore();

  // Current placement state
  const [placement, setPlacement] = useState<Partial<ShipPlacementType>>({});
  const [currentShip, setCurrentShip] = useState<ShipName>('carrier');
  const [orientation, setOrientation] = useState<Orientation>(0);
  const [hoverCell, setHoverCell] = useState<{ x: number; y: number } | null>(null);

  // Check if all ships are placed
  const allPlaced = SHIP_NAMES.every((name) => placement[name]);

  // Handle keyboard events for rotation
  const handleKeyDown = useCallback((e: KeyboardEvent) => {
    if (allPlaced) return;
    if (e.key === 'r' || e.key === 'R') {
      setOrientation((prev) => (prev === 0 ? 1 : 0) as Orientation);
    }
  }, [allPlaced]);

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  // Calculate preview cells
  const previewCells = useMemo(() => {
    if (!hoverCell) return [];

    const length = SHIP_LENGTHS[currentShip];
    const shipData: ShipData = {
      x: hoverCell.x,
      y: hoverCell.y,
      orientation,
    };

    if (!isValidPlacement(shipData, length)) return [];

    return getShipCells(shipData, length);
  }, [hoverCell, currentShip, orientation]);

  // Check if preview is valid (no overlap with placed ships)
  const isPreviewValid = useMemo(() => {
    if (previewCells.length === 0) return false;

    const length = SHIP_LENGTHS[currentShip];
    const shipData: ShipData = {
      x: previewCells[0].x,
      y: previewCells[0].y,
      orientation,
    };

    // Check overlap with already placed ships
    for (const name of SHIP_NAMES) {
      if (name === currentShip) continue;
      const placed = placement[name];
      if (placed) {
        if (shipsOverlap(shipData, length, placed, SHIP_LENGTHS[name])) {
          return false;
        }
      }
    }

    return true;
  }, [previewCells, currentShip, orientation, placement]);

  // Current board based on placement
  const board = useMemo(() => {
    if (Object.keys(placement).length === 0) {
      return Array(100).fill(false);
    }

    // Create partial placement for board calculation
    const partialPlacement = {
      carrier: placement.carrier ?? { x: -1, y: -1, orientation: 0 as Orientation },
      battleship: placement.battleship ?? { x: -1, y: -1, orientation: 0 as Orientation },
      cruiser: placement.cruiser ?? { x: -1, y: -1, orientation: 0 as Orientation },
      submarine: placement.submarine ?? { x: -1, y: -1, orientation: 0 as Orientation },
      destroyer: placement.destroyer ?? { x: -1, y: -1, orientation: 0 as Orientation },
    };

    const board = Array(100).fill(false);

    for (const name of SHIP_NAMES) {
      const ship = placement[name];
      if (ship && ship.x >= 0) {
        const cells = getShipCells(ship, SHIP_LENGTHS[name]);
        for (const cell of cells) {
          const idx = cell.y * 10 + cell.x;
          board[idx] = true;
        }
      }
    }

    return board;
  }, [placement]);

  // Handle cell click to place ship
  const handleCellClick = (x: number, y: number) => {
    if (!isPreviewValid) return;

    const shipData: ShipData = { x, y, orientation };
    setPlacement((prev) => ({ ...prev, [currentShip]: shipData }));

    // Move to next unplaced ship
    const nextShip = SHIP_NAMES.find((name) => !placement[name] && name !== currentShip);
    if (nextShip) {
      setCurrentShip(nextShip);
    }
  };

  // Handle random placement
  const handleRandomize = () => {
    try {
      const randomPlacement = generateRandomPlacement();
      setPlacement(randomPlacement);
    } catch (error) {
      console.error('Failed to generate random placement:', error);
    }
  };

  // Handle clear all
  const handleClear = () => {
    setPlacement({});
    setCurrentShip('carrier');
  };

  // Handle confirm placement
  const handleConfirm = () => {
    const fullPlacement = placement as ShipPlacementType;
    const validation = validateShipPlacement(fullPlacement);

    if (!validation.valid) {
      alert(validation.error);
      return;
    }

    const board = placementToBoard(fullPlacement);
    setMyShips(fullPlacement);
    setMyBoard(board);
    setPhase('lobby');
  };

  return (
    <div className="flex flex-col items-center py-8">
      <h2 className="text-2xl font-bold mb-2 game-title">Place Your Ships</h2>
      <p className="text-gray-400 mb-6">Click on the grid to position your fleet</p>

      <div className="flex flex-col md:flex-row gap-8 items-start">
        {/* Grid */}
        <div
          className="bg-gray-800/50 rounded-xl p-5 backdrop-blur"
          onMouseLeave={() => setHoverCell(null)}
        >
          <Grid
            board={board}
            previewCells={previewCells}
            isPreviewInvalid={!isPreviewValid && previewCells.length > 0}
            onCellClick={handleCellClick}
            onCellHover={(x, y) => setHoverCell({ x, y })}
            disabled={allPlaced}
            title="Your Fleet"
            boardType="myBoard"
          />
        </div>

        {/* Ship list and controls */}
        <div className="bg-gray-800/50 rounded-xl p-5 backdrop-blur min-w-64">
          <h3 className="font-semibold mb-4 text-blue-400 uppercase tracking-wider text-sm">Fleet Status</h3>

          <div className="space-y-2 mb-6">
            {SHIP_NAMES.map((name) => {
              const isPlaced = !!placement[name];
              const isCurrent = currentShip === name && !allPlaced;

              return (
                <div
                  key={name}
                  className={`flex items-center justify-between p-2 rounded ${
                    isCurrent
                      ? 'bg-blue-600'
                      : isPlaced
                      ? 'bg-green-900/50'
                      : 'bg-gray-700'
                  }`}
                >
                  <span className="capitalize">{name}</span>
                  <div className="flex gap-1">
                    {Array.from({ length: SHIP_LENGTHS[name] }, (_, i) => (
                      <div
                        key={i}
                        className={`w-4 h-4 rounded-sm ${
                          isPlaced ? 'bg-green-500' : 'bg-gray-500'
                        }`}
                      />
                    ))}
                  </div>
                </div>
              );
            })}
          </div>

          {/* Orientation toggle */}
          {!allPlaced && (
            <div className="mb-4">
              <label className="text-sm text-gray-400 block mb-2">Orientation</label>
              <div className="flex gap-2">
                <button
                  onClick={() => setOrientation(0)}
                  className={`flex-1 py-2 rounded ${
                    orientation === 0 ? 'bg-blue-600' : 'bg-gray-700'
                  }`}
                >
                  Horizontal
                </button>
                <button
                  onClick={() => setOrientation(1)}
                  className={`flex-1 py-2 rounded ${
                    orientation === 1 ? 'bg-blue-600' : 'bg-gray-700'
                  }`}
                >
                  Vertical
                </button>
              </div>
            </div>
          )}

          {/* Action buttons */}
          <div className="space-y-2">
            <button
              onClick={handleRandomize}
              className="w-full py-2 bg-purple-600 hover:bg-purple-700 rounded-lg transition-colors font-medium"
            >
              🎲 Randomize
            </button>

            <button
              onClick={handleClear}
              className="w-full py-2 bg-gray-600 hover:bg-gray-500 rounded-lg transition-colors font-medium"
            >
              ↺ Clear All
            </button>

            <button
              onClick={handleConfirm}
              disabled={!allPlaced}
              className={`w-full py-3 rounded-lg font-bold uppercase tracking-wide transition-all ${
                allPlaced
                  ? 'bg-gradient-to-r from-green-600 to-green-700 hover:from-green-500 hover:to-green-600 shadow-lg shadow-green-900/50'
                  : 'bg-gray-600 cursor-not-allowed text-gray-400'
              }`}
            >
              {allPlaced ? '✓ Deploy Fleet' : 'Place All Ships'}
            </button>
          </div>
        </div>
      </div>

      {/* Hover hint */}
      {!allPlaced && (
        <p className="text-sm text-gray-500 mt-4">
          Placing: <span className="capitalize text-blue-400">{currentShip}</span>
          {' '}({SHIP_LENGTHS[currentShip]} cells)
          {' '}- Press R to rotate
        </p>
      )}
    </div>
  );
}
