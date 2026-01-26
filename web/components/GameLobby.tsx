import { useState } from 'react';
import { useContract } from '../hooks/useContract';
import { useWalletStore } from '../store/wallet';
import { useGameStore } from '../store/game';
import { Grid } from './Grid';
import type { Shot } from '../lib/types';
import { BOARD_SIZE } from '../lib/types';

export function GameLobby() {
  const playerSlot = useWalletStore((state) => state.playerSlot);
  const { myBoard, myShips, setPhase } = useGameStore();
  const { createGame, joinGame, isLoading, error } = useContract();

  const [gameId, setGameIdInput] = useState('');
  const [initialShot, setInitialShot] = useState<Shot | null>(null);
  const [showShotSelector, setShowShotSelector] = useState(false);

  const isHost = playerSlot === 'host';

  // Handle create game (host)
  const handleCreateGame = async () => {
    if (!gameId.trim()) {
      alert('Please enter a game ID');
      return;
    }

    try {
      await createGame(gameId.trim());
    } catch (err) {
      console.error('Failed to create game:', err);
    }
  };

  // Handle join game (guest) - first show shot selector
  const handlePrepareJoin = () => {
    if (!gameId.trim()) {
      alert('Please enter a game ID');
      return;
    }
    setShowShotSelector(true);
  };

  // Handle joining with initial shot
  const handleJoinWithShot = async () => {
    if (!initialShot) {
      alert('Please select your initial shot');
      return;
    }

    try {
      await joinGame(gameId.trim(), initialShot);
    } catch (err) {
      console.error('Failed to join game:', err);
    }
  };

  // Shot selector for guest
  if (showShotSelector) {
    return (
      <div className="flex flex-col items-center py-8">
        <h2 className="text-2xl font-bold mb-2">Select Initial Shot</h2>
        <p className="text-gray-400 mb-6">
          Click where you want your first shot to land on the opponent's board
        </p>

        <div className="bg-gray-800/50 rounded-xl p-5 backdrop-blur">
          <Grid
            trackingBoard={Array(BOARD_SIZE * BOARD_SIZE).fill('empty')}
            onCellClick={(x, y) => setInitialShot({ x, y })}
            title="Enemy Waters"
            boardType="opponentBoard"
            isMyTurn={true}
            selectedCell={initialShot}
          />
        </div>

        {initialShot && (
          <p className="text-sm text-gray-400 mb-4">
            Selected: {String.fromCharCode(65 + initialShot.x)}{initialShot.y + 1}
          </p>
        )}

        {error && (
          <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300 max-w-md">
            {error}
          </div>
        )}

        <div className="flex gap-4">
          <button
            onClick={() => setShowShotSelector(false)}
            className="px-6 py-2 bg-gray-600 hover:bg-gray-500 rounded-lg transition-colors"
          >
            Back
          </button>
          <button
            onClick={handleJoinWithShot}
            disabled={!initialShot || isLoading}
            className={`px-6 py-2 rounded-lg font-semibold transition-colors ${
              !initialShot || isLoading
                ? 'bg-gray-600 cursor-not-allowed'
                : 'bg-green-600 hover:bg-green-700'
            }`}
          >
            {isLoading ? 'Joining...' : 'Join Game'}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center py-8">
      <h2 className="text-2xl font-bold mb-2">Game Lobby</h2>
      <p className="text-gray-400 mb-6">
        {isHost ? 'Create a new game' : 'Join an existing game'}
      </p>

      <div className="flex flex-col md:flex-row gap-8 items-start">
        {/* My board preview */}
        <div className="bg-gray-800/50 rounded-xl p-5 backdrop-blur">
          <Grid board={myBoard} disabled title="Your Fleet" boardType="myBoard" />
        </div>

        {/* Game ID form */}
        <div className="bg-gray-800/50 rounded-xl p-6 backdrop-blur min-w-80">
          <h3 className="font-bold mb-4 text-lg text-blue-400">
            {isHost ? '🚀 Create Game' : '🎯 Join Game'}
          </h3>

          <div className="mb-4">
            <label className="block text-sm text-gray-400 mb-2">Game ID</label>
            <input
              type="text"
              value={gameId}
              onChange={(e) => setGameIdInput(e.target.value)}
              placeholder="Enter a unique game ID"
              className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500"
            />
          </div>

          {error && (
            <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
              {error}
            </div>
          )}

          {isHost ? (
            <button
              onClick={handleCreateGame}
              disabled={isLoading || !gameId.trim()}
              className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                isLoading || !gameId.trim()
                  ? 'bg-gray-600 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700'
              }`}
            >
              {isLoading ? (
                <span className="flex items-center justify-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                  Creating...
                </span>
              ) : (
                'Create Game'
              )}
            </button>
          ) : (
            <button
              onClick={handlePrepareJoin}
              disabled={isLoading || !gameId.trim()}
              className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                isLoading || !gameId.trim()
                  ? 'bg-gray-600 cursor-not-allowed'
                  : 'bg-green-600 hover:bg-green-700'
              }`}
            >
              Continue to Shot Selection
            </button>
          )}

          <button
            onClick={() => setPhase('placing')}
            className="w-full mt-3 py-2 bg-gray-600 hover:bg-gray-500 rounded-lg text-sm transition-colors"
          >
            Back to Ship Placement
          </button>
        </div>
      </div>
    </div>
  );
}
