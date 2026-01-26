import { Cell } from './Cell';
import type { CellState } from '../lib/types';
import { BOARD_SIZE } from '../lib/types';
import { ShieldIcon, TargetIcon } from './Icons';

type BoardType = 'myBoard' | 'opponentBoard';

interface GridProps {
  // For placement view
  board?: boolean[];  // true = ship cell

  // For tracking view
  trackingBoard?: CellState[];

  // For showing opponent shots on my board
  opponentShots?: { x: number; y: number }[];

  // Preview cells during placement
  previewCells?: { x: number; y: number }[];
  isPreviewInvalid?: boolean;

  // Callbacks
  onCellClick?: (x: number, y: number) => void;
  onCellHover?: (x: number, y: number) => void;

  // Options
  disabled?: boolean;
  title?: string;
  boardType?: BoardType;
  isMyTurn?: boolean;
  selectedCell?: { x: number; y: number } | null;
}

export function Grid({
  board,
  trackingBoard,
  opponentShots,
  previewCells = [],
  isPreviewInvalid = false,
  onCellClick,
  onCellHover,
  disabled = false,
  title,
  boardType = 'myBoard',
  isMyTurn = false,
  selectedCell = null,
}: GridProps) {
  const columnLabels = 'ABCDEFGHIJ'.split('');
  const rowLabels = Array.from({ length: BOARD_SIZE }, (_, i) => (i + 1).toString());

  const isOpponentBoard = boardType === 'opponentBoard';

  // Helper to check if cell is in preview
  const isPreviewCell = (x: number, y: number) =>
    previewCells.some((c) => c.x === x && c.y === y);

  // Helper to check if cell is selected
  const isSelectedCell = (x: number, y: number) =>
    selectedCell?.x === x && selectedCell?.y === y;

  // Helper to get cell state for tracking board
  const getCellState = (x: number, y: number): CellState => {
    if (trackingBoard) {
      const idx = y * BOARD_SIZE + x;
      return trackingBoard[idx];
    }

    // For my board with opponent shots
    if (board && opponentShots) {
      const idx = y * BOARD_SIZE + x;
      const wasShot = opponentShots.some((s) => s.x === x && s.y === y);
      if (wasShot) {
        return board[idx] ? 'hit' : 'miss';
      }
    }

    return 'empty';
  };

  // Helper to check if cell has ship
  const hasShip = (x: number, y: number): boolean => {
    if (!board) return false;
    const idx = y * BOARD_SIZE + x;
    return board[idx];
  };

  // Get board styling based on type and turn
  const getBoardContainerStyle = () => {
    if (isOpponentBoard) {
      if (isMyTurn && !disabled) {
        return 'ring-2 ring-green-500/50 shadow-lg shadow-green-500/20';
      }
      return 'opacity-80';
    }
    return 'opacity-90';
  };

  // Get header styling based on board type
  const getHeaderStyle = () => {
    if (isOpponentBoard) {
      return 'text-red-400';
    }
    return 'text-blue-400';
  };

  return (
    <div className={`inline-block transition-all duration-300 ${getBoardContainerStyle()}`}>
      {title && (
        <div className={`flex items-center justify-center gap-2 mb-3 ${getHeaderStyle()}`}>
          {isOpponentBoard ? (
            <TargetIcon size={20} />
          ) : (
            <ShieldIcon size={20} />
          )}
          <h3 className="text-sm font-bold uppercase tracking-wider">
            {title}
          </h3>
          {isOpponentBoard ? (
            <TargetIcon size={20} />
          ) : (
            <ShieldIcon size={20} />
          )}
        </div>
      )}

      <div className="flex">
        {/* Row labels */}
        <div className="flex flex-col mr-1">
          <div className="w-6 h-8 md:h-10" /> {/* Empty corner */}
          {rowLabels.map((label) => (
            <div
              key={label}
              className="w-6 h-8 md:h-10 flex items-center justify-center text-xs text-gray-500 font-mono"
            >
              {label}
            </div>
          ))}
        </div>

        <div>
          {/* Column labels */}
          <div className="flex mb-1">
            {columnLabels.map((label) => (
              <div
                key={label}
                className="w-8 h-6 md:w-10 flex items-center justify-center text-xs text-gray-500 font-mono"
              >
                {label}
              </div>
            ))}
          </div>

          {/* Grid cells */}
          <div
            className="grid gap-0.5 p-1 rounded-lg bg-gray-900/50"
            style={{ gridTemplateColumns: `repeat(${BOARD_SIZE}, 1fr)` }}
          >
            {Array.from({ length: BOARD_SIZE * BOARD_SIZE }, (_, idx) => {
              const x = idx % BOARD_SIZE;
              const y = Math.floor(idx / BOARD_SIZE);
              const preview = isPreviewCell(x, y);
              const selected = isSelectedCell(x, y);

              return (
                <Cell
                  key={idx}
                  state={getCellState(x, y)}
                  isShip={hasShip(x, y)}
                  isPreview={preview}
                  isInvalid={preview && isPreviewInvalid}
                  onClick={onCellClick ? () => onCellClick(x, y) : undefined}
                  onMouseEnter={onCellHover ? () => onCellHover(x, y) : undefined}
                  disabled={disabled}
                  showCoords
                  x={x}
                  y={y}
                  isOpponentBoard={isOpponentBoard}
                  isSelected={selected}
                />
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
