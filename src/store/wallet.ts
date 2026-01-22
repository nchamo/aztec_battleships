import { create } from 'zustand';
import type { AztecAddress } from '@aztec/aztec.js/addresses';
import type { PlayerSlot } from '../lib/types';
import type { WalletInstance } from '../services/wallet';

export type PXEStatus = 'disconnected' | 'connecting' | 'connected' | 'error';

export type ConnectionStatus = 'idle' | 'loading_wallet' | 'deploying_account' | 'done';

interface WalletState {
  // PXE state
  pxeStatus: PXEStatus;
  pxeError: string | null;

  // Player slot selection
  playerSlot: PlayerSlot | null;

  // Wallet state
  walletInstance: WalletInstance | null;
  address: AztecAddress | null;
  isConnecting: boolean;
  connectionStatus: ConnectionStatus;
  connectionError: string | null;

  // Actions
  setPXEStatus: (status: PXEStatus, error?: string) => void;
  setPlayerSlot: (slot: PlayerSlot | null) => void;
  setWalletInstance: (instance: WalletInstance | null) => void;
  setConnecting: (isConnecting: boolean) => void;
  setConnectionStatus: (status: ConnectionStatus) => void;
  setConnectionError: (error: string | null) => void;
  disconnect: () => void;
}

export const useWalletStore = create<WalletState>((set) => ({
  // Initial state
  pxeStatus: 'disconnected',
  pxeError: null,
  playerSlot: null,
  walletInstance: null,
  address: null,
  isConnecting: false,
  connectionStatus: 'idle',
  connectionError: null,

  // Actions
  setPXEStatus: (status, error) =>
    set({
      pxeStatus: status,
      pxeError: error ?? null,
    }),

  setPlayerSlot: (slot) => set({ playerSlot: slot }),

  setWalletInstance: (instance) =>
    set({
      walletInstance: instance,
      address: instance?.address ?? null,
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

  disconnect: () =>
    set({
      walletInstance: null,
      address: null,
      playerSlot: null,
      connectionStatus: 'idle',
      connectionError: null,
    }),
}));
