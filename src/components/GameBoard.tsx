import { useState, useEffect, useRef } from 'react';
import { Grid } from './Grid';
import { useContract } from '../hooks/useContract';
import { useGameStore } from '../store/game';
import { useWalletStore } from '../store/wallet';
import type { Shot } from '../lib/types';
import {
  BOARD_SIZE,
  TOTAL_SHIP_CELLS,
  STATUS_WON_BY_HOST,
  STATUS_WON_BY_GUEST,
} from '../lib/types';

export function GameBoard() {
  const playerSlot = useWalletStore((state) => state.playerSlot);
  const {
    gameId,
    isHost,
    phase,
    myBoard,
    trackingBoard,
    opponentShots,
    currentTurn,
    isMyTurn,
    myHits,
    opponentHits,
    contractStatus,
    recordPendingShot,
    verifyPendingShot,
    recordOpponentShot,
    setIsMyTurn,
    setCurrentTurn,
    setContractStatus,
    setPhase,
    resetGame,
  } = useGameStore();

  const { shoot, wasTurnPlayed, getTurn, getGameStatus, isLoading, error } = useContract();
  const [selectedShot, setSelectedShot] = useState<Shot | null>(null);
  const [isPolling, setIsPolling] = useState(false);
  const lastProcessedTurn = useRef<number>(0);

  // Poll for opponent's turn when it's not my turn
  useEffect(() => {
    if (!gameId || isMyTurn || phase !== 'playing' || isPolling) return;

    const pollOpponentTurn = async () => {
      setIsPolling(true);
      try {
        // The opponent's turn number we're waiting for
        // If I'm host (even turns), opponent plays odd turns
        // If I'm guest (odd turns), opponent plays even turns
        const opponentTurn = currentTurn + 1;

        console.log(`[GameBoard] Polling for opponent turn ${opponentTurn}...`);

        // First check if game is already over (my previous shot may have won)
        const statusCheck = await getGameStatus(gameId);
        if (statusCheck === STATUS_WON_BY_HOST || statusCheck === STATUS_WON_BY_GUEST) {
          console.log(`[GameBoard] Game already over! Status: ${statusCheck}`);
          setContractStatus(statusCheck);
          setPhase('finished');
          return;
        }

        // Check if opponent's turn was played
        const played = await wasTurnPlayed(gameId, opponentTurn);
        if (!played) {
          console.log(`[GameBoard] Turn ${opponentTurn} not yet played`);
          return;
        }

        console.log(`[GameBoard] Turn ${opponentTurn} was played! Fetching shot...`);

        // Get the shot details
        const shot = await getTurn(gameId, opponentTurn);
        if (!shot) {
          console.error(`[GameBoard] Failed to get turn ${opponentTurn} details`);
          return;
        }

        console.log(`[GameBoard] Opponent shot at (${shot.x}, ${shot.y}), our previous shot was ${shot.opponentShotHit ? 'a HIT' : 'a MISS'}`);

        // Only process if we haven't processed this turn yet
        if (lastProcessedTurn.current >= opponentTurn) {
          console.log(`[GameBoard] Turn ${opponentTurn} already processed`);
          return;
        }
        lastProcessedTurn.current = opponentTurn;

        // Verify our previous pending shot with the result from opponent's turn
        // The opponent_shot_hit field tells us if OUR previous shot was a hit
        verifyPendingShot(shot.opponentShotHit);

        // Record opponent's shot
        recordOpponentShot(shot);

        // Check game status for win/loss
        const status = await getGameStatus(gameId);
        if (status === STATUS_WON_BY_HOST || status === STATUS_WON_BY_GUEST) {
          setContractStatus(status);
          setPhase('finished');
          console.log(`[GameBoard] Game over! Status: ${status}`);
        } else {
          // It's now my turn
          setCurrentTurn(opponentTurn + 1);
          setIsMyTurn(true);
          console.log(`[GameBoard] My turn now (turn ${opponentTurn + 1})`);
        }
      } catch (err) {
        console.error('[GameBoard] Error polling opponent turn:', err);
      } finally {
        setIsPolling(false);
      }
    };

    // Poll immediately and every 3 seconds
    pollOpponentTurn();
    const interval = setInterval(pollOpponentTurn, 3000);

    return () => clearInterval(interval);
  }, [gameId, isMyTurn, phase, currentTurn, isHost, wasTurnPlayed, getTurn, getGameStatus, recordOpponentShot, verifyPendingShot, setCurrentTurn, setIsMyTurn, setContractStatus, setPhase, isPolling]);

  // Check win conditions
  const isGameOver = phase === 'finished';
  const didIWin =
    (isHost && contractStatus === STATUS_WON_BY_HOST) ||
    (!isHost && contractStatus === STATUS_WON_BY_GUEST);

  // Handle shooting
  const handleShoot = async () => {
    if (!selectedShot || !gameId || !isMyTurn || isLoading) return;

    // Check if cell was already shot
    const idx = selectedShot.y * BOARD_SIZE + selectedShot.x;
    if (trackingBoard[idx] !== 'empty') {
      alert("You've already shot at this cell");
      return;
    }

    try {
      // currentTurn is the turn we're about to play
      await shoot(gameId, currentTurn, selectedShot);

      // Record as pending - we don't know if it's a hit until opponent responds
      // The result will be revealed in the opponent's next turn via opponent_shot_hit
      recordPendingShot(selectedShot);

      setSelectedShot(null);
      // After shooting, we wait for opponent's next turn (currentTurn + 1)
      // But currentTurn stays the same - polling will look for currentTurn + 1
      setIsMyTurn(false);
    } catch (err) {
      console.error('Failed to shoot:', err);
    }
  };

  // Handle selecting a shot target
  const handleCellClick = (x: number, y: number) => {
    if (!isMyTurn || isGameOver || isLoading) return;

    // Check if cell was already shot
    const idx = y * BOARD_SIZE + x;
    if (trackingBoard[idx] !== 'empty') return;

    setSelectedShot({ x, y });
  };

  // Handle new game
  const handleNewGame = () => {
    resetGame();
  };

  return (
    <div className="flex flex-col items-center py-8">
      {/* Game status header */}
      <div className="text-center mb-6">
        {isGameOver ? (
          <div
            className={`text-3xl font-bold mb-2 ${
              didIWin ? 'text-green-500' : 'text-red-500'
            }`}
          >
            {didIWin ? 'Victory!' : 'Defeat'}
          </div>
        ) : (
          <>
            <h2 className="text-2xl font-bold mb-2">
              {isMyTurn ? 'Your Turn' : "Opponent's Turn"}
            </h2>
            <p className="text-gray-400">
              Turn {currentTurn} • Game: {gameId}
            </p>
          </>
        )}
      </div>

      {/* Score display */}
      <div className="flex gap-8 mb-6">
        <div className="text-center">
          <div className="text-2xl font-bold text-blue-500">{myHits}</div>
          <div className="text-sm text-gray-400">Your Hits</div>
          <div className="text-xs text-gray-500">{TOTAL_SHIP_CELLS - myHits} to win</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold text-red-500">{opponentHits}</div>
          <div className="text-sm text-gray-400">Opponent Hits</div>
          <div className="text-xs text-gray-500">{TOTAL_SHIP_CELLS - opponentHits} until loss</div>
        </div>
      </div>

      {/* Game boards */}
      <div className="flex flex-col lg:flex-row gap-8">
        {/* My board */}
        <div className="bg-gray-800 rounded-lg p-4">
          <Grid
            board={myBoard}
            opponentShots={opponentShots}
            disabled
            title="Your Board"
          />
        </div>

        {/* Tracking board (opponent) */}
        <div className="bg-gray-800 rounded-lg p-4">
          <Grid
            trackingBoard={trackingBoard.map((state, idx) => {
              // Highlight selected cell
              if (selectedShot) {
                const x = idx % BOARD_SIZE;
                const y = Math.floor(idx / BOARD_SIZE);
                if (selectedShot.x === x && selectedShot.y === y) {
                  return 'hit'; // Use hit style for selection
                }
              }
              return state;
            })}
            onCellClick={handleCellClick}
            disabled={!isMyTurn || isGameOver || isLoading}
            title="Opponent's Board"
          />
        </div>
      </div>

      {/* Action buttons */}
      <div className="mt-6 flex flex-col items-center gap-4">
        {error && (
          <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 text-sm text-red-300 max-w-md">
            {error}
          </div>
        )}

        {!isGameOver && isMyTurn && (
          <>
            {selectedShot && (
              <p className="text-sm text-gray-400">
                Target: ({String.fromCharCode(65 + selectedShot.x)}, {selectedShot.y + 1})
              </p>
            )}

            <button
              onClick={handleShoot}
              disabled={!selectedShot || isLoading}
              className={`px-8 py-3 rounded-lg font-semibold transition-colors ${
                !selectedShot || isLoading
                  ? 'bg-gray-600 cursor-not-allowed'
                  : 'bg-red-600 hover:bg-red-700'
              }`}
            >
              {isLoading ? (
                <span className="flex items-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                  Firing...
                </span>
              ) : (
                'Fire!'
              )}
            </button>
          </>
        )}

        {!isGameOver && !isMyTurn && (
          <div className="flex items-center gap-2 text-gray-400">
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-gray-400" />
            Waiting for opponent...
          </div>
        )}

        {isGameOver && (
          <button
            onClick={handleNewGame}
            className="px-8 py-3 bg-blue-600 hover:bg-blue-700 rounded-lg font-semibold transition-colors"
          >
            Play Again
          </button>
        )}
      </div>

      {/* Player info */}
      <div className="mt-6 text-sm text-gray-500">
        Playing as: {playerSlot} ({isHost ? 'Host' : 'Guest'})
      </div>
    </div>
  );
}
