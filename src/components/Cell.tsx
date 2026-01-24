import type { CellState } from '../lib/types';

interface CellProps {
  state: CellState;
  isShip?: boolean;
  isPreview?: boolean;
  isInvalid?: boolean;
  onClick?: () => void;
  onMouseEnter?: () => void;
  disabled?: boolean;
  showCoords?: boolean;
  x?: number;
  y?: number;
}

export function Cell({
  state,
  isShip = false,
  isPreview = false,
  isInvalid = false,
  onClick,
  onMouseEnter,
  disabled = false,
  showCoords = false,
  x,
  y,
}: CellProps) {
  const getBackgroundColor = () => {
    if (isInvalid) return 'bg-red-500/50';
    if (isPreview) return 'bg-blue-400/50';
    if (state === 'hit') return 'bg-red-600';
    if (state === 'miss') return 'bg-gray-500';
    if (state === 'sunk') return 'bg-red-800';
    if (state === 'pending') return 'bg-yellow-600 animate-pulse';
    if (isShip) return 'bg-blue-600';
    return 'bg-gray-700';
  };

  const getCursor = () => {
    if (disabled) return 'cursor-default';
    if (onClick) return 'cursor-pointer';
    return 'cursor-default';
  };

  const getHoverEffect = () => {
    if (disabled || !onClick) return '';
    return 'hover:brightness-125';
  };

  return (
    <button
      type="button"
      onClick={onClick}
      onMouseEnter={onMouseEnter}
      disabled={disabled}
      className={`
        w-8 h-8 md:w-10 md:h-10
        rounded-sm
        border border-gray-600
        transition-all duration-150
        flex items-center justify-center
        text-xs font-mono
        ${getBackgroundColor()}
        ${getCursor()}
        ${getHoverEffect()}
      `}
      title={showCoords && x !== undefined && y !== undefined ? `(${x}, ${y})` : undefined}
    >
      {state === 'hit' && <span className="text-white">X</span>}
      {state === 'miss' && <span className="text-gray-300">•</span>}
      {state === 'pending' && <span className="text-white">?</span>}
    </button>
  );
}
