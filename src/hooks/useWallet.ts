import { useCallback, useEffect, useRef } from 'react';
import { useWalletStore } from '../store/wallet';
import { useGameStore } from '../store/game';
import { getPXE } from '../services/pxe';
import { createOrLoadWallet } from '../services/wallet';
import type { PlayerSlot } from '../lib/types';

export function useWallet() {
  const {
    pxeStatus,
    pxeError,
    playerSlot,
    walletInstance,
    address,
    isConnecting,
    connectionStatus,
    connectionError,
    setPXEStatus,
    setPlayerSlot,
    setWalletInstance,
    setConnecting,
    setConnectionStatus,
    setConnectionError,
    disconnect: disconnectStore,
  } = useWalletStore();

  const resetGame = useGameStore((state) => state.resetGame);

  // Use ref to track initialization state to avoid race conditions
  const initializingRef = useRef(false);

  // Initialize PXE on mount
  useEffect(() => {
    // Prevent multiple concurrent initializations
    if (initializingRef.current || pxeStatus !== 'disconnected') return;
    initializingRef.current = true;

    async function initPXE() {
      setPXEStatus('connecting');

      try {
        await getPXE();
        setPXEStatus('connected');
      } catch (error) {
        const message = error instanceof Error ? error.message : 'Failed to connect to PXE';
        setPXEStatus('error', message);
      }
    }

    initPXE();
  }, [pxeStatus, setPXEStatus]);

  // Select player slot
  const selectSlot = useCallback(
    (slot: PlayerSlot) => {
      setPlayerSlot(slot);
    },
    [setPlayerSlot]
  );

  // Connect wallet for selected slot
  const connect = useCallback(async () => {
    if (!playerSlot) {
      setConnectionError('Please select a player slot first');
      return;
    }

    if (pxeStatus !== 'connected') {
      setConnectionError('PXE not connected');
      return;
    }

    setConnecting(true);
    setConnectionError(null);
    setConnectionStatus('loading_wallet');

    try {
      const instance = await createOrLoadWallet(playerSlot, (status) => {
        setConnectionStatus(status);
      });
      setWalletInstance(instance);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to connect wallet';
      setConnectionError(message);
    }
  }, [playerSlot, pxeStatus, setConnecting, setConnectionError, setConnectionStatus, setWalletInstance]);

  // Disconnect wallet
  const disconnect = useCallback(() => {
    disconnectStore();
    resetGame();
  }, [disconnectStore, resetGame]);

  return {
    // PXE state
    pxeStatus,
    pxeError,
    isPXEConnected: pxeStatus === 'connected',

    // Slot selection
    playerSlot,
    selectSlot,

    // Wallet state
    walletInstance,
    address,
    isConnected: walletInstance !== null,
    isConnecting,
    connectionStatus,
    connectionError,

    // Actions
    connect,
    disconnect,
  };
}
