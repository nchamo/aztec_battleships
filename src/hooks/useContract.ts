import { useState, useCallback } from 'react';
import { AztecAddress } from '@aztec/aztec.js/addresses';
import { Fr } from '@aztec/aztec.js/fields';
import { Contract, getContractInstanceFromInstantiationParams } from '@aztec/aztec.js/contracts';
import { useWalletStore } from '../store/wallet';
import { useGameStore } from '../store/game';
import { getPXE } from '../services/pxe';
import { loadDeploymentConfig } from '../config';
import type { ShipPlacement, Shot } from '../lib/types';
import { STATUS_CREATED, STATUS_ACTIVE } from '../lib/types';

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
    setGameId,
    setIsHost,
    setPhase,
    setContractStatus,
    setCurrentTurn,
    setIsMyTurn,
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
    [myShips, walletInstance, getContract, getGameHost, setGameId, setIsHost, setPhase, setContractStatus, setCurrentTurn, setIsMyTurn]
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

  // Get turn details (shot coordinates)
  const getTurn = useCallback(
    async (gameId: string, turn: number): Promise<{ x: number; y: number } | null> => {
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

        // turnData should have { shot: { x, y }, timestamp }
        if (turnData && turnData.shot) {
          return {
            x: Number(turnData.shot.x),
            y: Number(turnData.shot.y),
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

  return {
    createGame,
    joinGame,
    shoot,
    getGameStatus,
    getGameGuest,
    wasTurnPlayed,
    getTurn,
    claimAbandonment,
    isLoading,
    error,
  };
}
