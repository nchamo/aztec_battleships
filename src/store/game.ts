import { create } from 'zustand';
import type { ShipPlacement, Shot, CellState, GameStatus } from '../lib/types';
import { STATUS_CREATED, BOARD_SIZE } from '../lib/types';

export type GamePhase =
  | 'idle'           // Not in a game
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

  // Pending shot (for opponent to process)
  pendingShot: Shot | null;

  // Actions
  setPhase: (phase: GamePhase) => void;
  setGameId: (gameId: string | null) => void;
  setIsHost: (isHost: boolean) => void;
  setMyShips: (ships: ShipPlacement | null) => void;
  setMyBoard: (board: boolean[]) => void;
  recordMyShot: (shot: Shot, isHit: boolean) => void;
  recordOpponentShot: (shot: Shot) => void;
  setCurrentTurn: (turn: number) => void;
  setIsMyTurn: (isMyTurn: boolean) => void;
  setContractStatus: (status: GameStatus) => void;
  setPendingShot: (shot: Shot | null) => void;
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
  pendingShot: null,

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

  setPendingShot: (shot) => set({ pendingShot: shot }),

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
      pendingShot: null,
    }),
}));
