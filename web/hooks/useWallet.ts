import { useCallback, useEffect, useRef } from 'react';
import { flushSync } from 'react-dom';
import { useWalletStore } from '../store/wallet';
import { useGameStore } from '../store/game';
import { getPXE } from '../services/pxe';
import { createOrLoadWallet, WALLET_SEED_STORAGE_KEY, generateRandomSeed } from '../services/wallet';
import type { PlayerSlot } from '../lib/types';

export function useWallet() {
  const {
    pxeStatus,
    pxeError,
    seed,
    playerSlot,
    walletInstance,
    address,
    isConnecting,
    connectionStatus,
    connectionError,
    setPXEStatus,
    setSeed,
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

  // Get stored seed from localStorage
  const getStoredSeed = useCallback((): string | null => {
    return localStorage.getItem(WALLET_SEED_STORAGE_KEY);
  }, []);

  // Save seed to localStorage
  const saveSeed = useCallback((seedValue: string) => {
    localStorage.setItem(WALLET_SEED_STORAGE_KEY, seedValue);
  }, []);

  // Connect wallet with a seed - role will be determined by action selection
  const connect = useCallback(async (seedInput: string, role: PlayerSlot) => {
    // Use provided seed or generate a random readable one
    const seedToUse = seedInput.trim() || generateRandomSeed();

    if (pxeStatus !== 'connected') {
      setConnectionError('PXE not connected');
      return;
    }

    // Save seed to localStorage
    saveSeed(seedToUse);

    // Use flushSync to ensure React renders the loading state immediately
    flushSync(() => {
      setConnecting(true);
      setConnectionError(null);
      setConnectionStatus('loading_wallet');
      setSeed(seedToUse);
    });

    try {
      const instance = await createOrLoadWallet(seedToUse, role, (status) => {
        flushSync(() => {
          setConnectionStatus(status);
        });
      });

      setWalletInstance(instance);
      setConnecting(false);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to connect wallet';
      setConnectionError(message);
      setConnecting(false);
    }
  }, [pxeStatus, saveSeed, setConnecting, setConnectionError, setConnectionStatus, setSeed, setWalletInstance]);

  // Switch role (reconnect with same seed but different role)
  const switchRole = useCallback(async (newRole: PlayerSlot) => {
    if (!seed) {
      setConnectionError('No seed available');
      return;
    }

    // Disconnect current wallet
    disconnectStore();
    resetGame();

    // Reconnect with the new role
    await connect(seed, newRole);
  }, [seed, connect, disconnectStore, resetGame, setConnectionError]);

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

    // Seed
    seed,
    getStoredSeed,

    // Slot/role selection
    playerSlot,
    setPlayerSlot,

    // Wallet state
    walletInstance,
    address,
    isConnected: walletInstance !== null,
    isConnecting,
    connectionStatus,
    connectionError,

    // Actions
    connect,
    switchRole,
    disconnect,
  };
}
