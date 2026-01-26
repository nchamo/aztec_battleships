import { create } from 'zustand';
import type { AztecAddress } from '@aztec/aztec.js/addresses';
import type { PlayerSlot } from '../lib/types';
import type { WalletInstance } from '../services/wallet';

export type PXEStatus = 'disconnected' | 'connecting' | 'connected' | 'error';

export type ConnectionStatus = 'idle' | 'loading_wallet' | 'deploying_account' | 'done';

export type GameAction = 'create' | 'join' | null;

interface WalletState {
  // PXE state
  pxeStatus: PXEStatus;
  pxeError: string | null;

  // Seed for wallet derivation
  seed: string | null;

  // Player slot/role (host or guest) - determined by action (create=host, join=guest)
  playerSlot: PlayerSlot | null;

  // Wallet state
  walletInstance: WalletInstance | null;
  address: AztecAddress | null;
  isConnecting: boolean;
  connectionStatus: ConnectionStatus;
  connectionError: string | null;

  // Reconnection state (persisted across component remounts)
  isReconnecting: boolean;
  reconnectGameId: string | null;
  reconnectError: string | null;

  // Game action (what the user wants to do after connecting)
  gameAction: GameAction;

  // Actions
  setPXEStatus: (status: PXEStatus, error?: string) => void;
  setSeed: (seed: string | null) => void;
  setPlayerSlot: (slot: PlayerSlot | null) => void;
  setWalletInstance: (instance: WalletInstance | null) => void;
  setConnecting: (isConnecting: boolean) => void;
  setConnectionStatus: (status: ConnectionStatus) => void;
  setConnectionError: (error: string | null) => void;
  setReconnecting: (isReconnecting: boolean, gameId?: string | null) => void;
  setReconnectError: (error: string | null) => void;
  setGameAction: (action: GameAction) => void;
  disconnect: () => void;
}

export const useWalletStore = create<WalletState>((set) => ({
  // Initial state
  pxeStatus: 'disconnected',
  pxeError: null,
  seed: null,
  playerSlot: null,
  walletInstance: null,
  address: null,
  isConnecting: false,
  connectionStatus: 'idle',
  connectionError: null,
  isReconnecting: false,
  reconnectGameId: null,
  reconnectError: null,
  gameAction: null,

  // Actions
  setPXEStatus: (status, error) =>
    set({
      pxeStatus: status,
      pxeError: error ?? null,
    }),

  setSeed: (seed) => set({ seed }),

  setPlayerSlot: (slot) => set({ playerSlot: slot }),

  setWalletInstance: (instance) =>
    set({
      walletInstance: instance,
      address: instance?.address ?? null,
      seed: instance?.seed ?? null,
      playerSlot: instance?.role ?? null,
      isConnecting: false,
      connectionStatus: 'done',
      connectionError: null,
    }),

  setConnecting: (isConnecting) => set({ isConnecting }),

  setConnectionStatus: (status) => set({ connectionStatus: status }),

  setConnectionError: (error) =>
    set({
      connectionError: error,
      isConnecting: false,
      connectionStatus: 'idle',
    }),

  setReconnecting: (isReconnecting, gameId) =>
    set({
      isReconnecting,
      reconnectGameId: gameId ?? null,
      reconnectError: isReconnecting ? null : null,
    }),

  setReconnectError: (error) =>
    set({
      reconnectError: error,
      // Keep isReconnecting true so the reconnect UI stays visible with the error
    }),

  setGameAction: (action) => set({ gameAction: action }),

  disconnect: () =>
    set({
      walletInstance: null,
      address: null,
      seed: null,
      playerSlot: null,
      connectionStatus: 'idle',
      connectionError: null,
      isReconnecting: false,
      reconnectGameId: null,
      reconnectError: null,
      gameAction: null,
    }),
}));
