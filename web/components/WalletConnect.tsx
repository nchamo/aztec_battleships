import { useState, useEffect } from 'react';
import { useWallet } from '../hooks/useWallet';
import { useWalletStore } from '../store/wallet';
import { useGameStore } from '../store/game';
import { useContract } from '../hooks/useContract';

type GameAction = 'create' | 'join' | 'reconnect';

export function WalletConnect() {
  const {
    pxeStatus,
    pxeError,
    isPXEConnected,
    seed,
    playerSlot,
    getStoredSeed,
    address,
    isConnected,
    isConnecting,
    connectionStatus,
    connectionError,
    connect,
    switchRole,
    disconnect,
  } = useWallet();

  const {
    isReconnecting: isReconnectingStore,
    reconnectGameId,
    reconnectError: reconnectErrorStore,
    gameAction,
    setReconnecting,
    setReconnectError,
    setGameAction,
  } = useWalletStore();
  const { reconnectToGame } = useContract();
  const phase = useGameStore((state) => state.phase);

  const [reconnectMode, setReconnectMode] = useState(false); // Local state for reconnect UI
  const [gameIdInput, setGameIdInput] = useState('');
  const [seedInput, setSeedInput] = useState('');
  const [localError, setLocalError] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<GameAction | null>(null); // Track which action is in progress

  // Load stored seed on mount
  useEffect(() => {
    const storedSeed = getStoredSeed();
    if (storedSeed) {
      setSeedInput(storedSeed);
    }
  }, [getStoredSeed]);

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

  // Handle action selection (create/join/reconnect) - this triggers wallet connection with appropriate role
  const handleActionSelect = async (action: GameAction) => {
    setLocalError(null);
    setPendingAction(action);

    if (action === 'reconnect') {
      // For reconnect, we'll start with host and try guest if that fails
      if (!isConnected) {
        try {
          await connect(seedInput, 'host');
        } catch (err) {
          setLocalError('Failed to connect wallet');
          setPendingAction(null);
          return;
        }
      }
      setReconnectMode(true);
      setPendingAction(null);
    } else {
      // For create/join, determine role and connect
      const role = action === 'create' ? 'host' : 'guest';

      if (!isConnected || playerSlot !== role) {
        try {
          await connect(seedInput, role);
        } catch (err) {
          setLocalError('Failed to connect wallet');
          setPendingAction(null);
          return;
        }
      }

      setGameAction(action);
      setPendingAction(null);
    }
  };

  // Handle reconnection flow
  const handleReconnect = async () => {
    if (!gameIdInput.trim()) {
      setLocalError('Please enter a game ID');
      return;
    }

    setLocalError(null);
    setReconnecting(true, gameIdInput.trim());

    try {
      console.log(`[Reconnect] Trying reconnection with ${playerSlot}...`);
      await reconnectToGame(gameIdInput.trim());
      setReconnecting(false);
      setReconnectMode(false);
      // Success - hook will set phase to 'playing'
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reconnect';

      // If not a participant with current slot, try the other slot
      if (message.includes('not a participant')) {
        const otherRole = playerSlot === 'host' ? 'guest' : 'host';
        console.log(`[Reconnect] Not a participant as ${playerSlot}, trying ${otherRole}...`);

        try {
          await switchRole(otherRole);
          // The useEffect will retry reconnection after connection
        } catch {
          setReconnectError(`Failed to connect as ${otherRole}`);
        }
      } else {
        setReconnectError(message);
      }
    }
  };

  // Effect to handle reconnection after wallet connects (for auto-detect)
  useEffect(() => {
    const tryReconnect = async () => {
      if (!isReconnectingStore || !isConnected || !reconnectGameId || isConnecting) return;
      // Only auto-retry if we don't already have an error
      if (reconnectErrorStore) return;

      try {
        console.log(`[Reconnect] Trying reconnection with ${playerSlot}...`);
        await reconnectToGame(reconnectGameId);
        setReconnecting(false);
        setReconnectMode(false);
        // Success - hook will set phase to 'playing'
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to reconnect';

        // If not a participant with current slot, try the other slot
        if (message.includes('not a participant')) {
          const otherRole = playerSlot === 'host' ? 'guest' : 'host';
          console.log(`[Reconnect] Not a participant as ${playerSlot}, trying ${otherRole}...`);

          try {
            await switchRole(otherRole);
          } catch {
            setReconnectError(`Failed to connect as ${otherRole}`);
          }
        } else {
          setReconnectError(message);
        }
      }
    };

    tryReconnect();
  }, [isReconnectingStore, isConnected, isConnecting, playerSlot, reconnectGameId, reconnectErrorStore, reconnectToGame, switchRole, setReconnecting, setReconnectError]);

  // Handle back from reconnect mode
  const handleBackFromReconnect = () => {
    setReconnectMode(false);
    setGameIdInput('');
    setLocalError(null);
    setReconnecting(false);
  };

  // Handle full disconnect and return to action selection
  const handleDisconnectAndBack = () => {
    disconnect();
    setReconnectMode(false);
    setGameIdInput('');
    setLocalError(null);
    setReconnecting(false);
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

  // Show reconnection progress if in reconnect flow
  if (isConnected && isReconnectingStore) {
    const hasError = reconnectErrorStore || localError;

    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8">
        <div className="max-w-md w-full">
          <h1 className="text-3xl font-bold text-center mb-2 game-title">Battleships</h1>
          <p className="text-gray-400 text-center mb-8">Private Naval Combat on Aztec</p>

          <div className="bg-gray-800 rounded-lg p-6">
            <h2 className="text-lg font-semibold mb-4">
              {hasError ? 'Reconnection Failed' : 'Reconnecting...'}
            </h2>

            {!hasError && (
              <div className="bg-blue-900/30 border border-blue-700 rounded-lg p-3 mb-4 text-sm text-blue-300">
                <div className="flex items-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-300" />
                  <span>Reconnecting to game {reconnectGameId}...</span>
                </div>
              </div>
            )}

            {hasError && (
              <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
                <div className="flex items-center gap-2 mb-2">
                  <span className="text-red-400 text-lg">X</span>
                  <span className="font-medium">Unable to reconnect</span>
                </div>
                <p>{reconnectErrorStore || localError}</p>
              </div>
            )}

            <button
              onClick={() => {
                setReconnecting(false);
                setReconnectMode(false);
                setLocalError(null);
              }}
              className={`w-full py-2 rounded-lg text-sm transition-colors ${
                hasError
                  ? 'bg-blue-600 hover:bg-blue-700 font-medium'
                  : 'bg-gray-600 hover:bg-gray-500'
              }`}
            >
              {hasError ? 'Back to Menu' : 'Cancel'}
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Connected - show reconnect game ID input
  if (isConnected && address && reconnectMode) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-8">
        <div className="max-w-md w-full">
          <h1 className="text-3xl font-bold text-center mb-2 game-title">Battleships</h1>
          <p className="text-gray-400 text-center mb-8">Private Naval Combat on Aztec</p>

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
              />
            </div>

            {localError && (
              <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-red-400">X</span>
                  <span className="font-medium">Error</span>
                </div>
                <p>{localError}</p>
              </div>
            )}

            <div className="space-y-3">
              <button
                onClick={handleReconnect}
                disabled={!gameIdInput.trim()}
                className={`w-full py-3 rounded-lg font-semibold transition-colors ${
                  !gameIdInput.trim()
                    ? 'bg-gray-600 cursor-not-allowed'
                    : 'bg-blue-600 hover:bg-blue-700'
                }`}
              >
                Reconnect
              </button>

              <button
                onClick={handleBackFromReconnect}
                className="w-full py-2 bg-gray-600 hover:bg-gray-500 rounded-lg text-sm transition-colors"
              >
                Back
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Connected and action selected (create/join) OR playing a game - show header bar for game flow
  if (isConnected && address && (gameAction || phase === 'playing')) {
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
            onClick={handleDisconnectAndBack}
            className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-sm transition-colors"
          >
            Disconnect
          </button>
        </div>
      </div>
    );
  }

  // Not connected or no action selected - show connection form with action selection
  return (
    <div className="flex flex-col items-center justify-center min-h-screen p-8">
      <div className="max-w-md w-full">
        <h1 className="text-3xl font-bold text-center mb-2 game-title">Battleships</h1>
        <p className="text-gray-400 text-center mb-8">Private Naval Combat on Aztec</p>

        <div className="bg-gray-800 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-2">Connect & Play</h2>
          <p className="text-sm text-gray-400 mb-6">
            Enter an optional seed phrase to derive your wallet identity, then choose an action.
          </p>

          {/* Seed input */}
          <div className="mb-6">
            <label className="block text-sm text-gray-400 mb-2">Wallet Seed (optional)</label>
            <input
              type="text"
              value={seedInput}
              onChange={(e) => setSeedInput(e.target.value)}
              placeholder="Leave empty to use default seed"
              className="w-full px-4 py-2 bg-gray-700 border border-gray-600 rounded-lg focus:outline-none focus:border-blue-500 text-sm"
              disabled={pendingAction !== null}
            />
            <p className="text-xs text-gray-500 mt-1">
              Same seed = same wallet. Different seeds = different wallets.
            </p>
          </div>

          {(connectionError || localError) && (
            <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
              {connectionError || localError}
            </div>
          )}

          {/* Action selection buttons */}
          <div className="space-y-3">
            <button
              onClick={() => handleActionSelect('create')}
              disabled={!isPXEConnected || pendingAction !== null}
              className={`w-full py-4 rounded-lg font-semibold transition-colors text-left px-4 ${
                !isPXEConnected || pendingAction !== null
                  ? 'bg-gray-600 cursor-not-allowed opacity-75'
                  : 'bg-blue-600 hover:bg-blue-700'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-base">
                    {pendingAction === 'create' ? 'Creating Game...' : 'Create Game'}
                  </div>
                  <div className="text-xs opacity-70 font-normal">
                    {pendingAction === 'create' ? getLoadingMessage() : 'Start a new game and wait for an opponent'}
                  </div>
                </div>
                {pendingAction === 'create' && (
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                )}
              </div>
            </button>

            <button
              onClick={() => handleActionSelect('join')}
              disabled={!isPXEConnected || pendingAction !== null}
              className={`w-full py-4 rounded-lg font-semibold transition-colors text-left px-4 ${
                !isPXEConnected || pendingAction !== null
                  ? 'bg-gray-600 cursor-not-allowed opacity-75'
                  : 'bg-green-600 hover:bg-green-700'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-base">
                    {pendingAction === 'join' ? 'Joining Game...' : 'Join Game'}
                  </div>
                  <div className="text-xs opacity-70 font-normal">
                    {pendingAction === 'join' ? getLoadingMessage() : 'Join an existing game with a game ID'}
                  </div>
                </div>
                {pendingAction === 'join' && (
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                )}
              </div>
            </button>

            <button
              onClick={() => handleActionSelect('reconnect')}
              disabled={!isPXEConnected || pendingAction !== null}
              className={`w-full py-4 rounded-lg font-semibold transition-colors text-left px-4 ${
                !isPXEConnected || pendingAction !== null
                  ? 'bg-gray-600 cursor-not-allowed opacity-75'
                  : 'bg-yellow-600 hover:bg-yellow-700'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-base">
                    {pendingAction === 'reconnect' ? 'Connecting...' : 'Reconnect to Game'}
                  </div>
                  <div className="text-xs opacity-70 font-normal">
                    {pendingAction === 'reconnect' ? getLoadingMessage() : 'Reconnect to an active game you were playing'}
                  </div>
                </div>
                {pendingAction === 'reconnect' && (
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                )}
              </div>
            </button>
          </div>

          {/* Show current seed info if connected */}
          {isConnected && seed && (
            <div className="mt-4 pt-4 border-t border-gray-700">
              <div className="text-xs text-gray-500">
                Connected with seed: <span className="font-mono">{seed.length > 25 ? seed.slice(0, 22) + '...' : seed}</span>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
