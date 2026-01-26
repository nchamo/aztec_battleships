import type { CellState } from '../lib/types';
import { coordToString } from '../lib/types';
import { ExplosionIcon, SplashIcon, RadarIcon, ShipCell, WaterCell, CrosshairIcon } from './Icons';

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
  isOpponentBoard?: boolean;
  isSelected?: boolean;
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
  isOpponentBoard = false,
  isSelected = false,
}: CellProps) {
  const getCursor = () => {
    if (disabled) return 'cursor-default';
    if (onClick) return 'cursor-crosshair';
    return 'cursor-default';
  };

  const getHoverEffect = () => {
    if (disabled || !onClick) return '';
    return 'hover:brightness-125 hover:scale-105';
  };

  const getBorderStyle = () => {
    if (isSelected) return 'ring-2 ring-red-500 ring-offset-1 ring-offset-gray-900';
    if (isInvalid) return 'ring-2 ring-red-500';
    if (isPreview) return 'ring-2 ring-blue-400';
    return '';
  };

  // Get tooltip text based on cell state
  const getTooltip = () => {
    const coord = x !== undefined && y !== undefined
      ? coordToString(x, y)
      : '';

    if (state === 'hit') {
      return isOpponentBoard
        ? `${coord} - Hit! Your shot hit an enemy ship`
        : `${coord} - Hit! Enemy hit your ship`;
    }
    if (state === 'miss') {
      return isOpponentBoard
        ? `${coord} - Miss. No ship at this location`
        : `${coord} - Miss. Enemy shot missed`;
    }
    if (state === 'pending') {
      return `${coord} - Pending... Waiting for result`;
    }
    if (isShip) {
      return `${coord} - Your ship`;
    }
    if (isPreview) {
      return isInvalid ? `${coord} - Invalid placement` : `${coord} - Ship preview`;
    }
    return coord ? `${coord} - Water` : undefined;
  };

  // Render the cell content based on state
  const renderContent = () => {
    // Invalid preview
    if (isInvalid && isPreview) {
      return (
        <div className="w-full h-full bg-red-500/50 flex items-center justify-center">
          <span className="text-white text-lg font-bold">×</span>
        </div>
      );
    }

    // Valid preview
    if (isPreview) {
      return (
        <div className="w-full h-full bg-blue-400/50 flex items-center justify-center">
          <ShipCell size={28} className="opacity-70" />
        </div>
      );
    }

    // Hit state - explosion
    if (state === 'hit') {
      return (
        <div className="w-full h-full bg-gradient-to-br from-red-600 to-red-800 flex items-center justify-center relative overflow-hidden">
          <div className="absolute inset-0 bg-red-500/30 animate-pulse" />
          <ExplosionIcon size={28} className="relative z-10" />
        </div>
      );
    }

    // Miss state - splash
    if (state === 'miss') {
      return (
        <div className="w-full h-full bg-gradient-to-br from-slate-600 to-slate-800 flex items-center justify-center">
          <SplashIcon size={24} />
        </div>
      );
    }

    // Pending state - radar animation
    if (state === 'pending') {
      return (
        <div className="w-full h-full bg-gradient-to-br from-yellow-600/80 to-amber-700/80 flex items-center justify-center">
          <div className="animate-spin-slow">
            <RadarIcon size={28} />
          </div>
        </div>
      );
    }

    // Ship cell (on my board)
    if (isShip) {
      return (
        <div className="w-full h-full flex items-center justify-center">
          <ShipCell size={30} />
        </div>
      );
    }

    // Empty cell - water with grid
    return (
      <div className="w-full h-full bg-gradient-to-br from-slate-700 to-slate-800 flex items-center justify-center relative group">
        <WaterCell size={32} className="absolute inset-0 opacity-50" />
        {/* Show crosshair on hover for opponent board */}
        {isOpponentBoard && !disabled && (
          <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
            <CrosshairIcon size={24} />
          </div>
        )}
      </div>
    );
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
        border border-gray-600/50
        transition-all duration-150
        overflow-hidden
        ${getCursor()}
        ${getHoverEffect()}
        ${getBorderStyle()}
      `}
      title={getTooltip()}
    >
      {renderContent()}
    </button>
  );
}
