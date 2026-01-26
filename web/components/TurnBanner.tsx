interface TurnBannerProps {
  isMyTurn: boolean;
  isGameOver?: boolean;
}

export function TurnBanner({ isMyTurn, isGameOver = false }: TurnBannerProps) {
  if (isGameOver) return null;

  return (
    <div
      className={`
        w-full py-2 px-4 rounded-lg text-center font-bold text-sm uppercase tracking-wide
        ${isMyTurn
          ? 'bg-green-600/20 border border-green-500 text-green-400 animate-pulse'
          : 'bg-gray-700/50 border border-gray-600 text-gray-400'
        }
      `}
    >
      {isMyTurn ? (
        <span className="flex items-center justify-center gap-2">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
          </span>
          Select Target
        </span>
      ) : (
        <span className="flex items-center justify-center gap-2">
          <div className="animate-spin rounded-full h-3 w-3 border-b-2 border-gray-400" />
          Waiting for Opponent
        </span>
      )}
    </div>
  );
}
