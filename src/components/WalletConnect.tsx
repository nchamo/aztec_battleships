import { useState, useEffect } from 'react';
import { useWallet } from '../hooks/useWallet';
import { useGameStore } from '../store/game';
import { useContract } from '../hooks/useContract';
import type { PlayerSlot } from '../lib/types';

type GameMode = 'create' | 'join' | 'reconnect';

export function WalletConnect() {
  const {
    pxeStatus,
    pxeError,
    isPXEConnected,
    playerSlot,
    selectSlot,
    address,
    isConnected,
    isConnecting,
    connectionStatus,
    connectionError,
    connect,
    disconnect,
  } = useWallet();

  const { setPhase } = useGameStore();
  const { reconnectToGame, isLoading: isReconnecting, error: reconnectError } = useContract();

  const [selectedMode, setSelectedMode] = useState<GameMode | null>(null);
  const [gameIdInput, setGameIdInput] = useState('');
  const [reconnectPlayerSlot, setReconnectPlayerSlot] = useState<PlayerSlot | null>(null);
  const [localError, setLocalError] = useState<string | null>(null);
  const [isAutoDetecting, setIsAutoDetecting] = useState(false);

  // Get the loading message based on connection status
  const getLoadingMessage = () => {
    switch (connectionStatus) {
      case 'deploying_account':
        return 'Deploying account contract...';
      case 'loading_wallet':
        return 'Loading wallet...';
      default:
        return 'Connecting...';
    }
  };

  // Handle mode selection
  const handleModeSelect = (mode: GameMode) => {
    setSelectedMode(mode);
    setLocalError(null);
  };

  // Handle connect and proceed based on mode
  const handleConnect = async () => {
    let slotToUse: PlayerSlot;

    if (selectedMode === 'create') {
      slotToUse = 'player1';
    } else if (selectedMode === 'join') {
      slotToUse = 'player2';
    } else if (selectedMode === 'reconnect') {
      // For reconnect, we use auto-detect via handleAutoReconnect instead
      // But if we get here, use player1 as default (will be auto-detected)
      slotToUse = reconnectPlayerSlot || 'player1';
    } else {
      setLocalError('Please select a game mode');
      return;
    }

    // Pass the slot directly to connect to avoid stale closure issues
    await connect(slotToUse);
  };

  // Handle reconnection after wallet is connected
  const handleReconnect = async () => {
    if (!gameIdInput.trim()) {
      setLocalError('Please enter a game ID');
      return;
    }

    setLocalError(null);

    try {
      await reconnectToGame(gameIdInput.trim());
      // If successful, the hook will set the phase to 'playing'
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reconnect';
      setLocalError(message);
    }
  };

  // Handle auto-detect reconnection - tries both player slots
  const handleAutoReconnect = async () => {
    if (!gameIdInput.trim()) {
      setLocalError('Please enter a game ID');
      return;
    }

    setLocalError(null);
    setIsAutoDetecting(true);

    try {
      // Try player1 first
      console.log('[Reconnect] Trying player1...');
      await connect('player1');
    } catch (err) {
      setLocalError('Failed to connect wallet');
      setIsAutoDetecting(false);
      return;
    }
  };

  // Effect to handle reconnection after wallet connects (for auto-detect)
  useEffect(() => {
    const tryReconnect = async () => {
      if (!isAutoDetecting || !isConnected || !gameIdInput.trim() || isConnecting) return;

      try {
        console.log(`[Reconnect] Trying reconnection with ${playerSlot}...`);
        await reconnectToGame(gameIdInput.trim());
        setIsAutoDetecting(false);
        // Success - hook will set phase to 'playing'
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to reconnect';

        // If not a participant with player1, try player2
        if (message.includes('not a participant') && playerSlot === 'player1') {
          console.log('[Reconnect] Player1 not a participant, trying player2...');
          disconnect();
          // Small delay to ensure disconnect completes, then try player2
          setTimeout(async () => {
            try {
              await connect('player2');
            } catch {
              setLocalError('Failed to connect as player2');
              setIsAutoDetecting(false);
            }
          }, 100);
        } else {
          // Either player2 also failed, or a different error
          setLocalError(message);
          setIsAutoDetecting(false);
        }
      }
    };

    tryReconnect();
  }, [isAutoDetecting, isConnected, isConnecting, playerSlot, gameIdInput, reconnectToGame, disconnect, connect]);

  // Handle back button
  const handleBack = () => {
    setSelectedMode(null);
    setReconnectPlayerSlot(null);
    setGameIdInput('');
    setLocalError(null);
    selectSlot(null as any); // Reset player slot
  };

  // Show PXE connection status
  if (pxeStatus === 'connecting') {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4" />
          <h2 className="text-xl font-semibold mb-2">Connecting to Aztec Network</h2>
          <p className="text-gray-400">Initializing PXE...</p>
        </div>
      </div>
    );
  }

  if (pxeStatus === 'error') {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8">
        <div className="text-center max-w-md">
          <div className="text-red-500 text-4xl mb-4">!</div>
          <h2 className="text-xl font-semibold mb-2">Connection Failed</h2>
          <p className="text-gray-400 mb-4">{pxeError}</p>
          <p className="text-sm text-gray-500">
            Make sure the Aztec sandbox is running: <code className="bg-gray-800 px-2 py-1 rounded">aztec start --local-network</code>
          </p>
        </div>
      </div>
    );
  }

  // Show connected state (header bar when in game)
  if (isConnected && address) {
    // If we're in reconnect mode with auto-detecting, show progress
    if (selectedMode === 'reconnect' && isAutoDetecting) {
      return (
        <div className="flex flex-col items-center justify-center min-h-screen p-8">
          <div className="max-w-md w-full">
            <h1 className="text-3xl font-bold text-center mb-2">Battleships</h1>
            <p className="text-gray-400 text-center mb-8">Private Aztec Game</p>

            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-lg font-semibold mb-4">Reconnecting...</h2>

              <div className="bg-blue-900/30 border border-blue-700 rounded-lg p-3 mb-4 text-sm text-blue-300">
                <div className="flex items-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-300" />
                  <span>Checking game {gameIdInput} as {playerSlot}...</span>
                </div>
              </div>

              {localError && (
                <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
                  {localError}
                </div>
              )}

              <button
                onClick={() => {
                  setIsAutoDetecting(false);
                  disconnect();
                  handleBack();
                }}
                className="w-full py-2 bg-gray-600 hover:bg-gray-500 rounded-lg text-sm transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      );
    }

    // If we're in reconnect mode but not auto-detecting (manual mode fallback)
    if (selectedMode === 'reconnect') {
      return (
        <div className="flex flex-col items-center justify-center min-h-screen p-8">
          <div className="max-w-md w-full">
            <h1 className="text-3xl font-bold text-center mb-2">Battleships</h1>
            <p className="text-gray-400 text-center mb-8">Private Aztec Game</p>

            <div className="bg-gray-800 rounded-lg p-6">
              <h2 className="text-lg font-semibold mb-4">Reconnect to Game</h2>
              <p className="text-sm text-gray-400 mb-4">
                Enter the game ID to reconnect to your active game.
              </p>

              <div className="mb-4">
                <label className="block text-sm text-gray-400 mb-2">Game ID</label>
                <input
                  type="text"
                  value={gameIdInput}
                  onChange={(e) => setGameIdInput(e.target.value)}
                  placeholder="Enter game ID"
                  className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500"
                  disabled={isReconnecting}
                />
              </div>

              {(localError || reconnectError) && (
                <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
                  {localError || reconnectError}
                </div>
              )}

              {isReconnecting && (
                <div className="bg-blue-900/30 border border-blue-700 rounded-lg p-3 mb-4 text-sm text-blue-300">
                  Reconnecting... This may take a moment as we fetch your game state.
                </div>
              )}

              <div className="space-y-3">
                <button
                  onClick={handleReconnect}
                  disabled={isReconnecting || !gameIdInput.trim()}
                  className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                    isReconnecting || !gameIdInput.trim()
                      ? 'bg-gray-600 cursor-not-allowed'
                      : 'bg-blue-600 hover:bg-blue-700'
                  }`}
                >
                  {isReconnecting ? (
                    <span className="flex items-center justify-center gap-2">
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                      Reconnecting...
                    </span>
                  ) : (
                    'Reconnect'
                  )}
                </button>

                <button
                  onClick={() => {
                    disconnect();
                    handleBack();
                  }}
                  disabled={isReconnecting}
                  className="w-full py-2 bg-gray-600 hover:bg-gray-500 rounded-lg text-sm transition-colors disabled:opacity-50"
                >
                  Back
                </button>
              </div>
            </div>
          </div>
        </div>
      );
    }

    // Normal connected state - show header bar
    return (
      <div className="bg-gray-800 rounded-lg p-4 mb-6">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-sm text-gray-400">Connected as {playerSlot}</div>
            <div className="font-mono text-sm truncate max-w-xs">
              {address.toString().slice(0, 10)}...{address.toString().slice(-8)}
            </div>
          </div>
          <button
            onClick={disconnect}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-sm transition-colors"
          >
            Disconnect
          </button>
        </div>
      </div>
    );
  }

  // Show mode selection (Create, Join, Reconnect)
  if (!selectedMode) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8">
        <div className="max-w-md w-full">
          <h1 className="text-3xl font-bold text-center mb-2">Battleships</h1>
          <p className="text-gray-400 text-center mb-8">Private Aztec Game</p>

          <div className="space-y-4">
            <button
              onClick={() => handleModeSelect('create')}
              className="w-full bg-gray-800 hover:bg-gray-700 rounded-lg p-6 text-left transition-colors border-2 border-transparent hover:border-blue-500"
            >
              <h3 className="text-xl font-semibold mb-2">Create Game</h3>
              <p className="text-gray-400 text-sm">
                Start a new game and wait for an opponent to join
              </p>
            </button>

            <button
              onClick={() => handleModeSelect('join')}
              className="w-full bg-gray-800 hover:bg-gray-700 rounded-lg p-6 text-left transition-colors border-2 border-transparent hover:border-green-500"
            >
              <h3 className="text-xl font-semibold mb-2">Join Game</h3>
              <p className="text-gray-400 text-sm">
                Join an existing game with a game ID
              </p>
            </button>

            <button
              onClick={() => handleModeSelect('reconnect')}
              className="w-full bg-gray-800 hover:bg-gray-700 rounded-lg p-6 text-left transition-colors border-2 border-transparent hover:border-yellow-500"
            >
              <h3 className="text-xl font-semibold mb-2">Reconnect to Game</h3>
              <p className="text-gray-400 text-sm">
                Reconnect to an active game you were playing
              </p>
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Show reconnect game ID input (no player selection needed - auto-detect)
  if (selectedMode === 'reconnect' && !isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8">
        <div className="max-w-md w-full">
          <h1 className="text-3xl font-bold text-center mb-2">Battleships</h1>
          <p className="text-gray-400 text-center mb-8">Private Aztec Game</p>

          <div className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold mb-4">Reconnect to Game</h2>
            <p className="text-sm text-gray-400 mb-4">
              Enter the game ID to reconnect. We'll automatically detect which player you are.
            </p>

            <div className="mb-4">
              <label className="block text-sm text-gray-400 mb-2">Game ID</label>
              <input
                type="text"
                value={gameIdInput}
                onChange={(e) => setGameIdInput(e.target.value)}
                placeholder="Enter game ID"
                className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500"
                disabled={isAutoDetecting || isConnecting}
              />
            </div>

            {(localError || connectionError) && (
              <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
                {localError || connectionError}
              </div>
            )}

            {(isAutoDetecting || isConnecting) && (
              <div className="bg-blue-900/30 border border-blue-700 rounded-lg p-3 mb-4 text-sm text-blue-300">
                {isConnecting ? 'Connecting wallet...' : 'Detecting your player role...'}
              </div>
            )}

            <div className="space-y-3">
              <button
                onClick={handleAutoReconnect}
                disabled={!isPXEConnected || isAutoDetecting || isConnecting || !gameIdInput.trim()}
                className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                  !isPXEConnected || isAutoDetecting || isConnecting || !gameIdInput.trim()
                    ? 'bg-gray-600 cursor-not-allowed'
                    : 'bg-blue-600 hover:bg-blue-700'
                }`}
              >
                {isAutoDetecting || isConnecting ? (
                  <span className="flex items-center justify-center gap-2">
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                    {isConnecting ? 'Connecting...' : 'Reconnecting...'}
                  </span>
                ) : (
                  'Reconnect'
                )}
              </button>

              <button
                onClick={handleBack}
                disabled={isAutoDetecting || isConnecting}
                className="w-full py-2 bg-gray-600 hover:bg-gray-500 rounded-lg text-sm transition-colors disabled:opacity-50"
              >
                Back
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Show connect wallet button (after mode is selected)
  return (
    <div className="flex flex-col items-center justify-center min-h-screen p-8">
      <div className="max-w-md w-full">
        <h1 className="text-3xl font-bold text-center mb-2">Battleships</h1>
        <p className="text-gray-400 text-center mb-8">Private Aztec Game</p>

        <div className="bg-gray-800 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-4">
            {selectedMode === 'create' && 'Create Game'}
            {selectedMode === 'join' && 'Join Game'}
            {selectedMode === 'reconnect' && 'Reconnect to Game'}
          </h2>
          <p className="text-sm text-gray-400 mb-4">
            {selectedMode === 'create' && 'Connect your wallet to create a new game.'}
            {selectedMode === 'join' && 'Connect your wallet to join an existing game.'}
            {selectedMode === 'reconnect' && 'Connect your wallet to reconnect to your game.'}
          </p>

          {(connectionError || localError) && (
            <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
              {connectionError || localError}
            </div>
          )}

          <div className="space-y-3">
            <button
              onClick={handleConnect}
              disabled={!isPXEConnected || isConnecting}
              className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                !isPXEConnected || isConnecting
                  ? 'bg-gray-600 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700'
              }`}
            >
              {isConnecting ? (
                <span className="flex items-center justify-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                  {getLoadingMessage()}
                </span>
              ) : (
                'Connect Wallet'
              )}
            </button>

            <button
              onClick={handleBack}
              disabled={isConnecting}
              className="w-full py-2 bg-gray-600 hover:bg-gray-500 rounded-lg text-sm transition-colors disabled:opacity-50"
            >
              Back
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
