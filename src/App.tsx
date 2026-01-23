import { useEffect } from 'react';
import { WalletConnect } from './components/WalletConnect';
import { ShipPlacement } from './components/ShipPlacement';
import { GameLobby } from './components/GameLobby';
import { GameBoard } from './components/GameBoard';
import { useWallet } from './hooks/useWallet';
import { useGameStore } from './store/game';
import { useContract } from './hooks/useContract';
import { getPXE } from './services/pxe';
import { STATUS_ACTIVE } from './lib/types';

export default function App() {
  const { isConnected } = useWallet();
  const phase = useGameStore((state) => state.phase);

  // Not connected - show wallet connect
  if (!isConnected) {
    return <WalletConnect />;
  }

  // Connected - render based on game phase
  return (
    <div className="min-h-screen p-4 md:p-8">
      <div className="max-w-6xl mx-auto">
        {/* Header with wallet info */}
        <WalletConnect />

        {/* Game content based on phase */}
        {phase === 'idle' && <ShipPlacement />}
        {phase === 'placing' && <ShipPlacement />}
        {phase === 'lobby' && <GameLobby />}
        {phase === 'waiting' && <WaitingForOpponent />}
        {phase === 'playing' && <GameBoard />}
        {phase === 'finished' && <GameBoard />}
      </div>
    </div>
  );
}

function WaitingForOpponent() {
  const gameId = useGameStore((state) => state.gameId);
  const setPhase = useGameStore((state) => state.setPhase);
  const setContractStatus = useGameStore((state) => state.setContractStatus);
  const setCurrentTurn = useGameStore((state) => state.setCurrentTurn);
  const setIsMyTurn = useGameStore((state) => state.setIsMyTurn);
  const recordOpponentShot = useGameStore((state) => state.recordOpponentShot);
  const { getGameStatus, getGameGuest, getTurn } = useContract();

  // Poll for game status changes
  useEffect(() => {
    if (!gameId) return;

    let isMounted = true;
    let isPolling = false;

    const pollStatus = async () => {
      // Prevent overlapping polls
      if (isPolling || !isMounted) return;
      isPolling = true;

      try {
        const status = await getGameStatus(gameId);
        console.log('[Waiting] Polling game status:', status);

        if (!isMounted) return;

        if (status === STATUS_ACTIVE) {
          console.log('[Waiting] Opponent joined! Transitioning to playing phase');

          // Register guest as sender so host can receive their notes
          try {
            const guest = await getGameGuest(gameId);
            if (guest && isMounted) {
              const { pxe } = await getPXE();
              console.log('[Waiting] Registering guest as sender:', guest.toString());
              await pxe.registerSender(guest);
              console.log('[Waiting] Guest registered as sender');
            }
          } catch (err) {
            console.error('[Waiting] Failed to register guest as sender:', err);
          }

          // Get the guest's initial shot (turn 1)
          if (isMounted) {
            try {
              console.log('[Waiting] Fetching guest initial shot (turn 1)...');
              const turn1Shot = await getTurn(gameId, 1);
              if (turn1Shot && isMounted) {
                console.log(`[Waiting] Guest initial shot: (${turn1Shot.x}, ${turn1Shot.y})`);
                recordOpponentShot(turn1Shot);
              }
            } catch (err) {
              console.error('[Waiting] Failed to get guest initial shot:', err);
            }
          }

          if (isMounted) {
            setContractStatus(STATUS_ACTIVE);
            setPhase('playing');
            setCurrentTurn(2); // Turn 2 for host (guest made turn 1 with initial shot)
            setIsMyTurn(true); // Host goes first after guest joins
          }
        }
      } catch (err) {
        console.error('[Waiting] Error polling status:', err);
      } finally {
        isPolling = false;
      }
    };

    // Poll immediately and then every 3 seconds
    pollStatus();
    const interval = setInterval(pollStatus, 3000);

    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, [gameId]);

  return (
    <div className="flex flex-col items-center justify-center py-12">
      <div className="bg-gray-800 rounded-lg p-8 text-center max-w-md">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-6" />
        <h2 className="text-xl font-semibold mb-2">Waiting for Opponent</h2>
        <p className="text-gray-400 mb-4">
          Share this game ID with another player:
        </p>
        <div className="bg-gray-900 rounded-lg p-3 font-mono text-lg mb-4">
          {gameId}
        </div>
        <p className="text-sm text-gray-500">
          They should select "Player 2" and join with this ID
        </p>
      </div>
    </div>
  );
}
