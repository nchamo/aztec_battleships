import { useState, useEffect, useRef } from 'react';
import { Grid } from './Grid';
import { TurnBanner } from './TurnBanner';
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
          <div className="space-y-4">
            <div
              className={`text-4xl font-black uppercase tracking-wider ${
                didIWin ? 'text-green-400' : 'text-red-400'
              }`}
            >
              {didIWin ? '🎉 Victory!' : '💀 Defeat'}
            </div>
            <p className="text-gray-400">
              {didIWin ? 'You sunk the enemy fleet!' : 'Your fleet has been destroyed'}
            </p>
          </div>
        ) : (
          <>
            <h2 className="text-2xl font-bold mb-2">
              {isMyTurn ? 'Your Turn' : "Opponent's Turn"}
            </h2>
            <p className="text-gray-500 text-sm font-mono">
              Turn {currentTurn} • Game: {gameId?.slice(0, 8)}...
            </p>
          </>
        )}
      </div>

      {/* Score display */}
      <div className="flex gap-12 mb-8">
        <div className="text-center">
          <div className="text-3xl font-bold text-green-500">{myHits}</div>
          <div className="text-sm text-gray-400 font-medium">Your Hits</div>
          <div className="text-xs text-gray-600">{TOTAL_SHIP_CELLS - myHits} to victory</div>
        </div>
        <div className="w-px bg-gray-700" />
        <div className="text-center">
          <div className="text-3xl font-bold text-red-500">{opponentHits}</div>
          <div className="text-sm text-gray-400 font-medium">Enemy Hits</div>
          <div className="text-xs text-gray-600">{TOTAL_SHIP_CELLS - opponentHits} until defeat</div>
        </div>
      </div>

      {/* Turn status banner */}
      {!isGameOver && (
        <div className="mb-6">
          <TurnBanner isMyTurn={isMyTurn} isGameOver={isGameOver} />
        </div>
      )}

      {/* Game boards */}
      <div className="flex flex-col lg:flex-row gap-8 items-start">
        {/* My board */}
        <div className="bg-gray-800/50 rounded-xl p-5 backdrop-blur">
          <Grid
            board={myBoard}
            opponentShots={opponentShots}
            disabled
            title="Your Fleet"
            boardType="myBoard"
          />
        </div>

        {/* Divider */}
        <div className="hidden lg:flex flex-col items-center justify-center h-full py-8">
          <div className="w-px h-full bg-gradient-to-b from-transparent via-gray-600 to-transparent" />
        </div>

        {/* Tracking board (opponent) */}
        <div className="bg-gray-800/50 rounded-xl p-5 backdrop-blur">
          <Grid
            trackingBoard={trackingBoard}
            onCellClick={handleCellClick}
            disabled={!isMyTurn || isGameOver || isLoading}
            title="Enemy Waters"
            boardType="opponentBoard"
            isMyTurn={isMyTurn && !isGameOver && !isLoading}
            selectedCell={selectedShot}
          />
        </div>
      </div>

      {/* Action buttons */}
      <div className="mt-8 flex flex-col items-center gap-4">
        {error && (
          <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 text-sm text-red-300 max-w-md">
            {error}
          </div>
        )}

        {!isGameOver && isMyTurn && (
          <>
            {selectedShot && (
              <p className="text-sm text-gray-300 font-mono">
                Target: <span className="text-red-400 font-bold">{String.fromCharCode(65 + selectedShot.x)}{selectedShot.y + 1}</span>
              </p>
            )}

            <button
              onClick={handleShoot}
              disabled={!selectedShot || isLoading}
              className={`px-10 py-4 rounded-xl font-bold text-lg uppercase tracking-wide transition-all ${
                !selectedShot || isLoading
                  ? 'bg-gray-700 cursor-not-allowed text-gray-500'
                  : 'bg-gradient-to-r from-red-600 to-red-700 hover:from-red-500 hover:to-red-600 shadow-lg shadow-red-900/50 hover:shadow-red-800/50 transform hover:scale-105'
              }`}
            >
              {isLoading ? (
                <span className="flex items-center gap-3">
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                  Firing...
                </span>
              ) : (
                '🎯 Fire!'
              )}
            </button>
          </>
        )}

        {!isGameOver && !isMyTurn && (
          <div className="flex items-center gap-3 text-gray-400 bg-gray-800/50 px-6 py-3 rounded-lg">
            <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-gray-400" />
            <span className="font-medium">Awaiting enemy move...</span>
          </div>
        )}

        {isGameOver && (
          <button
            onClick={handleNewGame}
            className="px-10 py-4 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-500 hover:to-blue-600 rounded-xl font-bold text-lg uppercase tracking-wide transition-all shadow-lg shadow-blue-900/50 hover:shadow-blue-800/50 transform hover:scale-105"
          >
            🚢 Play Again
          </button>
        )}
      </div>

      {/* Player info */}
      <div className="mt-8 text-xs text-gray-600 font-mono">
        Playing as: {playerSlot === 'host' ? 'Host' : 'Guest'}
      </div>
    </div>
  );
}
