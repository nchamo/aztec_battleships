import { useWallet } from '../hooks/useWallet';
import type { PlayerSlot } from '../lib/types';

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

  // Show connected state
  if (isConnected && address) {
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

  // Show slot selection and connect
  return (
    <div className="flex flex-col items-center justify-center min-h-screen p-8">
      <div className="max-w-md w-full">
        <h1 className="text-3xl font-bold text-center mb-2">Battleships</h1>
        <p className="text-gray-400 text-center mb-8">Private Aztec Game</p>

        <div className="bg-gray-800 rounded-lg p-6">
          <h2 className="text-lg font-semibold mb-4">Select Player</h2>
          <p className="text-sm text-gray-400 mb-4">
            Choose a player slot. Each slot uses a separate wallet, allowing two players
            in different browser tabs.
          </p>

          <div className="grid grid-cols-2 gap-4 mb-6">
            {(['player1', 'player2'] as PlayerSlot[]).map((slot) => (
              <button
                key={slot}
                onClick={() => selectSlot(slot)}
                className={`p-4 rounded-lg border-2 transition-colors ${
                  playerSlot === slot
                    ? 'border-blue-500 bg-blue-500/10'
                    : 'border-gray-600 hover:border-gray-500'
                }`}
              >
                <div className="font-semibold capitalize">
                  {slot.replace('player', 'Player ')}
                </div>
                <div className="text-sm text-gray-400">
                  {slot === 'player1' ? 'Creates games' : 'Joins games'}
                </div>
              </button>
            ))}
          </div>

          {connectionError && (
            <div className="bg-red-900/30 border border-red-700 rounded-lg p-3 mb-4 text-sm text-red-300">
              {connectionError}
            </div>
          )}

          <button
            onClick={connect}
            disabled={!playerSlot || !isPXEConnected || isConnecting}
            className={`w-full py-3 rounded-lg font-semibold transition-colors ${
              !playerSlot || !isPXEConnected || isConnecting
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
        </div>
      </div>
    </div>
  );
}
