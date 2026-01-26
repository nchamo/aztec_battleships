import { create } from 'zustand';
import type { ShipPlacement, Shot, CellState, GameStatus } from '../lib/types';
import { STATUS_CREATED, BOARD_SIZE } from '../lib/types';

export type GamePhase =
  | 'idle'           // Initial state - show mode selection
  | 'placing'        // Placing ships
  | 'lobby'          // Ships placed, ready to create/join
  | 'waiting'        // Host waiting for guest to join
  | 'playing'        // Game in progress
  | 'finished';      // Game over

interface GameState {
  // Game identification
  gameId: string | null;
  isHost: boolean;

  // Game phase
  phase: GamePhase;

  // Ship placement
  myShips: ShipPlacement | null;
  myBoard: boolean[]; // 100 cells, true = ship

  // Tracking my shots against opponent
  trackingBoard: CellState[]; // 100 cells
  myShots: Shot[]; // All shots I've fired

  // Tracking opponent's shots against me
  opponentShots: Shot[]; // All shots opponent has fired

  // Turn tracking
  currentTurn: number;
  isMyTurn: boolean;

  // Game status from contract
  contractStatus: GameStatus;

  // Hit counters
  myHits: number;
  opponentHits: number;

  // Last shot we made that needs verification
  lastUnverifiedShot: Shot | null;

  // Actions
  setPhase: (phase: GamePhase) => void;
  setGameId: (gameId: string | null) => void;
  setIsHost: (isHost: boolean) => void;
  setMyShips: (ships: ShipPlacement | null) => void;
  setMyBoard: (board: boolean[]) => void;
  recordMyShot: (shot: Shot, isHit: boolean) => void;
  recordPendingShot: (shot: Shot) => void; // Record a shot as pending (unverified)
  verifyPendingShot: (wasHit: boolean) => void; // Verify the pending shot as hit or miss
  recordOpponentShot: (shot: Shot) => void;
  setCurrentTurn: (turn: number) => void;
  setIsMyTurn: (isMyTurn: boolean) => void;
  setContractStatus: (status: GameStatus) => void;
  // For reconnection - set multiple pieces of state at once
  setReconnectionState: (state: {
    gameId: string;
    isHost: boolean;
    currentTurn: number;
    isMyTurn: boolean;
    myHits: number;
    opponentHits: number;
    myShots: Shot[];
    opponentShots: Shot[];
    trackingBoard: CellState[];
    lastUnverifiedShot: Shot | null;
  }) => void;
  resetGame: () => void;
}

const createEmptyBoard = (): boolean[] => Array(BOARD_SIZE * BOARD_SIZE).fill(false);
const createEmptyTrackingBoard = (): CellState[] => Array(BOARD_SIZE * BOARD_SIZE).fill('empty');

export const useGameStore = create<GameState>((set, get) => ({
  // Initial state
  gameId: null,
  isHost: false,
  phase: 'idle',
  myShips: null,
  myBoard: createEmptyBoard(),
  trackingBoard: createEmptyTrackingBoard(),
  myShots: [],
  opponentShots: [],
  currentTurn: 0,
  isMyTurn: false,
  contractStatus: STATUS_CREATED,
  myHits: 0,
  opponentHits: 0,
  lastUnverifiedShot: null,

  // Actions
  setPhase: (phase) => set({ phase }),

  setGameId: (gameId) => set({ gameId }),

  setIsHost: (isHost) => set({ isHost }),

  setMyShips: (ships) => set({ myShips: ships }),

  setMyBoard: (board) => set({ myBoard: board }),

  recordMyShot: (shot, isHit) => {
    const { trackingBoard, myShots, myHits } = get();
    const idx = shot.y * BOARD_SIZE + shot.x;

    const newTrackingBoard = [...trackingBoard];
    newTrackingBoard[idx] = isHit ? 'hit' : 'miss';

    set({
      trackingBoard: newTrackingBoard,
      myShots: [...myShots, shot],
      myHits: isHit ? myHits + 1 : myHits,
    });
  },

  // Record a shot as pending (unverified) - shown with a different visual state
  recordPendingShot: (shot) => {
    const { trackingBoard, myShots } = get();
    const idx = shot.y * BOARD_SIZE + shot.x;

    const newTrackingBoard = [...trackingBoard];
    newTrackingBoard[idx] = 'pending';

    set({
      trackingBoard: newTrackingBoard,
      myShots: [...myShots, shot],
      lastUnverifiedShot: shot,
    });
  },

  // Verify the pending shot as hit or miss when opponent's turn reveals the result
  verifyPendingShot: (wasHit) => {
    const { lastUnverifiedShot, trackingBoard, myHits } = get();
    if (!lastUnverifiedShot) return;

    const idx = lastUnverifiedShot.y * BOARD_SIZE + lastUnverifiedShot.x;
    const newTrackingBoard = [...trackingBoard];
    newTrackingBoard[idx] = wasHit ? 'hit' : 'miss';

    set({
      trackingBoard: newTrackingBoard,
      myHits: wasHit ? myHits + 1 : myHits,
      lastUnverifiedShot: null,
    });
  },

  recordOpponentShot: (shot) => {
    const { myBoard, opponentShots, opponentHits } = get();
    const idx = shot.y * BOARD_SIZE + shot.x;
    const isHit = myBoard[idx];

    set({
      opponentShots: [...opponentShots, shot],
      opponentHits: isHit ? opponentHits + 1 : opponentHits,
    });
  },

  setCurrentTurn: (turn) => set({ currentTurn: turn }),

  setIsMyTurn: (isMyTurn) => set({ isMyTurn }),

  setContractStatus: (status) => set({ contractStatus: status }),

  // Set multiple pieces of state at once for reconnection
  setReconnectionState: (state) =>
    set({
      gameId: state.gameId,
      isHost: state.isHost,
      currentTurn: state.currentTurn,
      isMyTurn: state.isMyTurn,
      myHits: state.myHits,
      opponentHits: state.opponentHits,
      myShots: state.myShots,
      opponentShots: state.opponentShots,
      trackingBoard: state.trackingBoard,
      phase: 'playing',
      contractStatus: 2, // STATUS_ACTIVE
      lastUnverifiedShot: state.lastUnverifiedShot,
    }),

  resetGame: () =>
    set({
      gameId: null,
      isHost: false,
      phase: 'idle',
      myShips: null,
      myBoard: createEmptyBoard(),
      trackingBoard: createEmptyTrackingBoard(),
      myShots: [],
      opponentShots: [],
      currentTurn: 0,
      isMyTurn: false,
      contractStatus: STATUS_CREATED,
      myHits: 0,
      opponentHits: 0,
      lastUnverifiedShot: null,
    }),
}));
