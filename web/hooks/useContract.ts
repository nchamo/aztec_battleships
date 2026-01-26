import { useState, useCallback } from 'react';
import { AztecAddress } from '@aztec/aztec.js/addresses';
import { Fr } from '@aztec/aztec.js/fields';
import { Contract, getContractInstanceFromInstantiationParams } from '@aztec/aztec.js/contracts';
import { useWalletStore } from '../store/wallet';
import { useGameStore } from '../store/game';
import { getPXE } from '../services/pxe';
import { loadDeploymentConfig } from '../config';
import type { ShipPlacement, Shot, CellState } from '../lib/types';
import { STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST, BOARD_SIZE } from '../lib/types';

// Import the generated contract artifact
// @ts-ignore - artifact generated at build time
import { BattleshipsContractArtifact } from '../artifacts/Battleships';

// Track registered contracts per wallet address to survive HMR
const registeredContracts = new Map<string, boolean>();

// Convert ShipPlacement to contract format
function toContractShipPlacement(placement: ShipPlacement) {
  return {
    carrier: { x: placement.carrier.x, y: placement.carrier.y, orientation: placement.carrier.orientation },
    battleship: { x: placement.battleship.x, y: placement.battleship.y, orientation: placement.battleship.orientation },
    cruiser: { x: placement.cruiser.x, y: placement.cruiser.y, orientation: placement.cruiser.orientation },
    submarine: { x: placement.submarine.x, y: placement.submarine.y, orientation: placement.submarine.orientation },
    destroyer: { x: placement.destroyer.x, y: placement.destroyer.y, orientation: placement.destroyer.orientation },
  };
}

// Convert Shot to contract format
function toContractShot(shot: Shot) {
  return { x: shot.x, y: shot.y };
}

export function useContract() {
  const walletInstance = useWalletStore((state) => state.walletInstance);
  const {
    myShips,
    myBoard,
    setGameId,
    setIsHost,
    setPhase,
    setContractStatus,
    setCurrentTurn,
    setIsMyTurn,
    setMyBoard,
    recordPendingShot,
    setReconnectionState,
  } = useGameStore();

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Get or create contract instance - always create fresh to avoid HMR issues
  const getContract = useCallback(async () => {
    if (!walletInstance) {
      throw new Error('Wallet not connected');
    }

    const walletKey = walletInstance.address.toString();
    const config = await loadDeploymentConfig();
    const contractAddress = AztecAddress.fromString(config.battleshipsContract.address);

    // Register the contract with the wallet if not already registered for this wallet
    if (!registeredContracts.get(walletKey)) {
      const salt = Fr.fromString(config.battleshipsContract.salt);
      const instance = await getContractInstanceFromInstantiationParams(
        BattleshipsContractArtifact,
        { salt }
      );
      await walletInstance.wallet.registerContract(instance, BattleshipsContractArtifact);
      registeredContracts.set(walletKey, true);
      console.log('[Contract] Registered Battleships contract for', walletKey);
    }

    // Always create fresh contract instance to ensure wallet context is correct
    const contract = Contract.at(
      contractAddress,
      BattleshipsContractArtifact,
      walletInstance.wallet
    );

    return contract;
  }, [walletInstance]);

  // Create a new game
  const createGame = useCallback(
    async (gameId: string) => {
      if (!myShips) {
        throw new Error('Ships not placed');
      }
      if (!walletInstance) {
        throw new Error('Wallet not connected');
      }

      setIsLoading(true);
      setError(null);

      try {
        const contract = await getContract();
        const { getSponsoredFeePaymentMethod } = await getPXE();
        const paymentMethod = await getSponsoredFeePaymentMethod();

        // Convert gameId to Field - handle both numeric strings and hex strings
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        console.log('[Contract] Creating game:', gameId);

        await contract.methods
          .create_game(
            { id: gameIdField },
            toContractShipPlacement(myShips)
          )
          .send({
            from: walletInstance.address,
            fee: { paymentMethod },
          })
          .wait({ timeout: 300 });

        console.log('[Contract] Game created successfully');

        setGameId(gameId);
        setIsHost(true);
        setPhase('waiting');
        setContractStatus(STATUS_CREATED);
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to create game';
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [myShips, walletInstance, getContract, setGameId, setIsHost, setPhase, setContractStatus]
  );

  // Get the host address for a game
  const getGameHost = useCallback(
    async (gameId: string): Promise<AztecAddress | null> => {
      if (!walletInstance) {
        console.error('[Contract] Cannot get game host: wallet not connected');
        return null;
      }

      try {
        const contract = await getContract();
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        const host = await contract.methods
          .get_game_host({ id: gameIdField })
          .simulate({ from: walletInstance.address });

        return host as AztecAddress;
      } catch (err) {
        console.error('[Contract] Failed to get game host:', err);
        return null;
      }
    },
    [walletInstance, getContract]
  );

  // Get the guest address for a game
  const getGameGuest = useCallback(
    async (gameId: string): Promise<AztecAddress | null> => {
      if (!walletInstance) {
        return null;
      }
      try {
        const contract = await getContract();
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));
        const guest = await contract.methods
          .get_game_guest({ id: gameIdField })
          .simulate({ from: walletInstance.address });
        return guest as AztecAddress;
      } catch (err) {
        console.error('[Contract] Failed to get game guest:', err);
        return null;
      }
    },
    [walletInstance, getContract]
  );

  // Join an existing game
  const joinGame = useCallback(
    async (gameId: string, initialShot: Shot) => {
      if (!myShips) {
        throw new Error('Ships not placed');
      }
      if (!walletInstance) {
        throw new Error('Wallet not connected');
      }

      setIsLoading(true);
      setError(null);

      try {
        const contract = await getContract();
        const { pxe, getSponsoredFeePaymentMethod } = await getPXE();
        const paymentMethod = await getSponsoredFeePaymentMethod();

        // Convert gameId to Field - handle both numeric strings and hex strings
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        // Get the host address and register them as a sender
        console.log('[Contract] Getting game host for:', gameId);
        const host = await getGameHost(gameId);
        if (host) {
          console.log('[Contract] Registering host as sender:', host.toString());
          await pxe.registerSender(host);
          console.log('[Contract] Host registered as sender');
        }

        console.log('[Contract] Joining game:', gameId);
        console.log('Address is', walletInstance.address.toString());

        await contract.methods
          .join_game(
            { id: gameIdField },
            toContractShipPlacement(myShips),
            toContractShot(initialShot)
          )
          .send({
            from: walletInstance.address,
            fee: { paymentMethod },
          })
          .wait({ timeout: 300 });

        console.log('[Contract] Game joined successfully');

        // Record the initial shot as pending - will be verified when host plays turn 2
        recordPendingShot(initialShot);

        setGameId(gameId);
        setIsHost(false);
        setPhase('playing');
        setContractStatus(STATUS_ACTIVE);
        setCurrentTurn(1);
        setIsMyTurn(false); // Host's turn after guest joins
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to join game';
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [myShips, walletInstance, getContract, getGameHost, setGameId, setIsHost, setPhase, setContractStatus, setCurrentTurn, setIsMyTurn, recordPendingShot]
  );

  // Shoot at opponent
  const shoot = useCallback(
    async (gameId: string, turn: number, shot: Shot) => {
      if (!walletInstance) {
        throw new Error('Wallet not connected');
      }

      setIsLoading(true);
      setError(null);

      try {
        const contract = await getContract();
        const { getSponsoredFeePaymentMethod } = await getPXE();
        const paymentMethod = await getSponsoredFeePaymentMethod();

        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        console.log('[Contract] Shooting at:', shot, 'turn:', turn, 'My address is', walletInstance.address.toString());

        await contract.methods
          .shoot(
            { id: gameIdField },
            turn,
            toContractShot(shot)
          )
          .send({
            from: walletInstance.address,
            fee: { paymentMethod },
          })
          .wait({ timeout: 300 });

        console.log('[Contract] Shot successful');

        setCurrentTurn(turn);
        setIsMyTurn(false); // Now opponent's turn
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to shoot';
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [walletInstance, getContract, setCurrentTurn, setIsMyTurn]
  );

  // Get game status
  const getGameStatus = useCallback(
    async (gameId: string): Promise<number> => {
      if (!walletInstance) {
        console.error('[Contract] Cannot get game status: wallet not connected');
        return 0;
      }

      try {
        const contract = await getContract();
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        const status = await contract.methods
          .get_game_status({ id: gameIdField })
          .simulate({ from: walletInstance.address });

        return Number(status);
      } catch (err) {
        console.error('[Contract] Failed to get game status:', err);
        return 0;
      }
    },
    [walletInstance, getContract]
  );

  // Check if a turn was played (nullifier exists)
  const wasTurnPlayed = useCallback(
    async (gameId: string, turn: number): Promise<boolean> => {
      if (!walletInstance) {
        console.error('[Contract] Cannot check turn: wallet not connected');
        return false;
      }

      try {
        const contract = await getContract();
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        const played = await contract.methods
          .was_turn_played({ id: gameIdField }, turn)
          .simulate({ from: walletInstance.address });

        return Boolean(played);
      } catch (err) {
        console.error('[Contract] Failed to check if turn was played:', err);
        return false;
      }
    },
    [walletInstance, getContract]
  );

  // Get turn details (shot coordinates and hit result)
  const getTurn = useCallback(
    async (gameId: string, turn: number): Promise<{ x: number; y: number; opponentShotHit: boolean } | null> => {
      if (!walletInstance) {
        console.error('[Contract] Cannot get turn: wallet not connected');
        return null;
      }

      try {
        const contract = await getContract();
        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        const turnData = await contract.methods
          .get_turn({ id: gameIdField }, turn)
          .simulate({ from: walletInstance.address });

        // turnData should have { shot: { x, y }, timestamp, opponent_shot_hit }
        if (turnData && turnData.shot) {
          return {
            x: Number(turnData.shot.x),
            y: Number(turnData.shot.y),
            opponentShotHit: Boolean(turnData.opponent_shot_hit),
          };
        }
        return null;
      } catch (err) {
        console.error('[Contract] Failed to get turn:', err);
        return null;
      }
    },
    [walletInstance, getContract]
  );

  // Claim abandonment
  const claimAbandonment = useCallback(
    async (gameId: string, currentTurn: number) => {
      if (!walletInstance) {
        throw new Error('Wallet not connected');
      }

      setIsLoading(true);
      setError(null);

      try {
        const contract = await getContract();
        const { getSponsoredFeePaymentMethod } = await getPXE();
        const paymentMethod = await getSponsoredFeePaymentMethod();

        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        console.log('[Contract] Claiming abandonment');

        await contract.methods
          .claim_abandonment({ id: gameIdField }, currentTurn)
          .send({
            from: walletInstance.address,
            fee: { paymentMethod },
          })
          .wait({ timeout: 300 });

        console.log('[Contract] Abandonment claimed');
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to claim abandonment';
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [walletInstance, getContract]
  );

  // Reconnect to an existing game
  const reconnectToGame = useCallback(
    async (gameId: string) => {
      if (!walletInstance) {
        throw new Error('Wallet not connected');
      }

      setIsLoading(true);
      setError(null);

      try {
        const contract = await getContract();
        const { pxe } = await getPXE();

        const gameIdField = gameId.startsWith('0x')
          ? Fr.fromString(gameId)
          : new Fr(BigInt(gameId));

        console.log('[Contract] Reconnecting to game:', gameId);

        // 1. Get game status
        const status = await contract.methods
          .get_game_status({ id: gameIdField })
          .simulate({ from: walletInstance.address });

        const statusNum = Number(status);
        console.log('[Contract] Game status:', statusNum);

        if (statusNum === 0) {
          throw new Error('Game does not exist');
        }
        if (statusNum === STATUS_CREATED) {
          throw new Error('Game is waiting for a guest to join');
        }
        if (statusNum === STATUS_WON_BY_HOST || statusNum === STATUS_WON_BY_GUEST) {
          throw new Error('Game has already ended');
        }
        if (statusNum !== STATUS_ACTIVE) {
          throw new Error('Game is not active');
        }

        // 2. Get host and guest addresses
        const host = await contract.methods
          .get_game_host({ id: gameIdField })
          .simulate({ from: walletInstance.address }) as AztecAddress;

        const guest = await contract.methods
          .get_game_guest({ id: gameIdField })
          .simulate({ from: walletInstance.address }) as AztecAddress;

        console.log('[Contract] Host:', host.toString());
        console.log('[Contract] Guest:', guest.toString());
        console.log('[Contract] My address:', walletInstance.address.toString());

        // 3. Verify user is host or guest
        const isHost = walletInstance.address.equals(host);
        const isGuest = walletInstance.address.equals(guest);

        if (!isHost && !isGuest) {
          throw new Error('You are not a participant in this game');
        }

        // Register the other player as sender to receive their notes
        const opponent = isHost ? guest : host;
        console.log('[Contract] Registering opponent as sender:', opponent.toString());
        await pxe.registerSender(opponent);

        // 4. Fetch my board from the contract
        console.log('[Contract] Fetching my board...');
        const boardNote = await contract.methods
          .get_my_board({ id: gameIdField }, walletInstance.address)
          .simulate({ from: walletInstance.address });

        // Convert the board array to boolean[]
        const fetchedBoard: boolean[] = [];
        for (let i = 0; i < BOARD_SIZE * BOARD_SIZE; i++) {
          fetchedBoard.push(Boolean(boardNote.board[i]));
        }
        console.log('[Contract] Board fetched, ship cells:', fetchedBoard.filter(c => c).length);

        // Set the board in the store
        setMyBoard(fetchedBoard);

        // 5. Find the latest turn by checking nullifiers
        let latestTurn = 0;
        for (let turn = 1; turn <= 200; turn++) {
          const played = await contract.methods
            .was_turn_played({ id: gameIdField }, turn)
            .simulate({ from: walletInstance.address });

          if (!played) {
            latestTurn = turn - 1;
            break;
          }
        }

        console.log('[Contract] Latest turn:', latestTurn);

        // 6. Replay all turns to reconstruct state
        const myShots: Shot[] = [];
        const opponentShots: Shot[] = [];
        const trackingBoard: CellState[] = Array(BOARD_SIZE * BOARD_SIZE).fill('empty');
        let myHits = 0;
        let opponentHits = 0;

        // Determine which turns are mine vs opponent's
        // Host plays even turns (2, 4, 6...), Guest plays odd turns (1, 3, 5...)
        const myTurnsAreEven = isHost;

        for (let turn = 1; turn <= latestTurn; turn++) {
          try {
            const turnData = await contract.methods
              .get_turn({ id: gameIdField }, turn)
              .simulate({ from: walletInstance.address });

            if (!turnData || !turnData.shot) continue;

            const shot: Shot = {
              x: Number(turnData.shot.x),
              y: Number(turnData.shot.y),
            };
            const opponentShotHit = Boolean(turnData.opponent_shot_hit);
            const isMyTurnFlag = (turn % 2 === 0) === myTurnsAreEven;

            console.log(`[Contract] Turn ${turn}: shot=(${shot.x}, ${shot.y}), opponent_shot_hit=${opponentShotHit}, isMyTurn=${isMyTurnFlag}`);

            if (isMyTurnFlag) {
              // This was my shot
              myShots.push(shot);

              // We don't know yet if this shot was a hit until we see the next turn
              // For now, mark as pending if it's the latest turn, otherwise we can infer from next turn
            } else {
              // This was opponent's shot
              opponentShots.push(shot);

              // Check if it hit my board
              const idx = shot.y * BOARD_SIZE + shot.x;
              if (fetchedBoard[idx]) {
                opponentHits++;
              }

              // The opponent_shot_hit field tells us if MY previous shot was a hit
              if (turn > 1 && myShots.length > 0) {
                const myPrevShot = myShots[myShots.length - 1];
                const prevIdx = myPrevShot.y * BOARD_SIZE + myPrevShot.x;
                trackingBoard[prevIdx] = opponentShotHit ? 'hit' : 'miss';
                if (opponentShotHit) {
                  myHits++;
                }
              }
            }
          } catch (err) {
            console.error(`[Contract] Failed to get turn ${turn}:`, err);
          }
        }

        // If my last shot is still unverified (opponent hasn't played yet), mark as pending
        let lastUnverifiedShot: Shot | null = null;
        if (myShots.length > 0) {
          const lastMyShot = myShots[myShots.length - 1];
          const lastIdx = lastMyShot.y * BOARD_SIZE + lastMyShot.x;
          if (trackingBoard[lastIdx] === 'empty') {
            trackingBoard[lastIdx] = 'pending';
            lastUnverifiedShot = lastMyShot;
          }
        }

        // 7. Determine current turn and if it's my turn
        const nextTurn = latestTurn + 1;
        const isMyTurnNext = (nextTurn % 2 === 0) === myTurnsAreEven;

        console.log('[Contract] Next turn:', nextTurn, 'Is my turn:', isMyTurnNext);
        console.log('[Contract] My shots:', myShots.length, 'Opponent shots:', opponentShots.length);
        console.log('[Contract] My hits:', myHits, 'Opponent hits:', opponentHits);
        console.log('[Contract] Tracking board hits:', trackingBoard.filter(c => c === 'hit').length);
        console.log('[Contract] Tracking board misses:', trackingBoard.filter(c => c === 'miss').length);
        console.log('[Contract] Tracking board pending:', trackingBoard.filter(c => c === 'pending').length);
        console.log('[Contract] Opponent shots on my board:', opponentShots.length);

        // 8. Set the reconnection state
        setReconnectionState({
          gameId,
          isHost,
          currentTurn: nextTurn,
          isMyTurn: isMyTurnNext,
          myHits,
          opponentHits,
          myShots,
          opponentShots,
          trackingBoard,
          lastUnverifiedShot,
        });

        console.log('[Contract] Reconnection complete!');
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to reconnect';
        setError(message);
        throw err;
      } finally {
        setIsLoading(false);
      }
    },
    [walletInstance, getContract, setMyBoard, setReconnectionState, setError]
  );

  return {
    createGame,
    joinGame,
    shoot,
    getGameStatus,
    getGameGuest,
    wasTurnPlayed,
    getTurn,
    claimAbandonment,
    reconnectToGame,
    isLoading,
    error,
  };
}
