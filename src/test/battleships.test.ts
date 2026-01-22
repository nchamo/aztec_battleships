import { BattleshipsContract } from "../artifacts/Battleships.js";
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { TestWallet } from "@aztec/test-wallet/server";
import { AztecNode, createAztecNodeClient } from "@aztec/aztec.js/node";
import { AztecAddress } from "@aztec/stdlib/aztec-address";
import {
  STATUS_CREATED,
  STATUS_ACTIVE,
  STATUS_WON_BY_HOST,
  STATUS_WON_BY_GUEST,
  createGameId,
  createValidShipsHost,
  createValidShipsGuest,
  getShipCells,
  deployBattleships,
} from "./utils.js";
import { getInitialTestAccountsData } from "@aztec/accounts/testing";

describe("Battleships Contract", () => {
  let aztecNode: AztecNode
  let host: AztecAddress;
  let guest: AztecAddress;
  let walletHost: TestWallet
  let walletGuest: TestWallet
  let contractHost: BattleshipsContract;
  let contractGuest: BattleshipsContract;

  beforeAll(async () => {
    // Connect to local Aztec node
    aztecNode = createAztecNodeClient("http://localhost:8080", {});
    walletHost = await TestWallet.create(
      aztecNode,
      {
        dataDirectory: "pxe-store/battleships-host",
        proverEnabled: false,
      },
      {}
    );
    walletGuest = await TestWallet.create(
      aztecNode,
      {
        dataDirectory: "pxe-store/battleships-guest",
        proverEnabled: false,
      },
      {}
    );

    // Register pre-funded accounts from local network
    // Both wallets need both accounts registered to share complete addresses (including public keys)
    // This is required for note delivery between players
    const testAccounts = await getInitialTestAccountsData();

    // Register both accounts in walletHost
    host = (await walletHost.createSchnorrAccount(testAccounts[0].secret, testAccounts[0].salt, testAccounts[0].signingKey)).address;

    // Register both accounts in walletGuest
    guest = (await walletGuest.createSchnorrAccount(testAccounts[1].secret, testAccounts[1].salt, testAccounts[1].signingKey)).address;

    await walletGuest.registerSender(host);                                                                                                                                           
    await walletHost.registerSender(guest);  
  });

  beforeEach(async () => {
    // Deploy a fresh contract for each test
    contractHost = await deployBattleships(walletHost);
    contractGuest = await BattleshipsContract.at(contractHost.address, walletGuest);
    const contract = await aztecNode.getContract(contractHost.address)
    await walletGuest.registerContract(contract!, BattleshipsContract.artifact)
    // Note: registerSender not needed since both accounts are fully registered in both wallets
  });

  describe("Full Game Flow", () => {
    it("should play a full game where host wins", async () => {
      const gameId = createGameId(100);
      const hostShips = createValidShipsHost();
      const guestShips = createValidShipsGuest();

      // Get all cells of guest's ships (these will be targeted by host)
      const guestShipCells = getShipCells(guestShips);
      expect(guestShipCells.length).toBe(17);

      // Host creates game (turn 0)
      await contractHost.methods
        .create_game(gameId, hostShips)
        .send({ from: host })
        .wait();

      let status = await contractHost.methods
        .get_game_status(gameId)
        .simulate({ from: host });
      expect(status).toBe(BigInt(STATUS_CREATED));

      // Guest joins game with initial shot that misses (turn 1)
      await contractGuest.methods
        .join_game(gameId, guestShips, { x: 9, y: 9 })
        .send({ from: guest })
        .wait();

      status = await contractHost.methods
        .get_game_status(gameId)
        .simulate({ from: host });
      expect(status).toBe(BigInt(STATUS_ACTIVE));

      // Coordinates where guest can miss (away from host ships)
      const guestMissCoords = [
        { x: 9, y: 0 }, { x: 9, y: 1 }, { x: 9, y: 2 }, { x: 9, y: 3 },
        { x: 9, y: 4 }, { x: 9, y: 5 }, { x: 9, y: 6 }, { x: 9, y: 7 },
        { x: 9, y: 8 }, { x: 8, y: 9 }, { x: 7, y: 9 }, { x: 6, y: 9 },
        { x: 5, y: 9 }, { x: 4, y: 9 }, { x: 3, y: 9 }, { x: 2, y: 9 }, { x: 1, y: 9 },
      ];

      let turn = 2;

      // Verify turn 1 (guest's initial shot) was recorded
      const turn1Played = await contractHost.methods
        .was_turn_played(gameId, 1)
        .simulate({ from: host });
      expect(turn1Played).toBe(true);

      // Host and guest alternate shots
      // Host hits guest's ships, guest misses
      for (let i = 0; i < 17; i++) {
        // Host shoots at guest's ship cell (even turns)
        await contractHost.methods
          .shoot(gameId, turn, { x: guestShipCells[i].x, y: guestShipCells[i].y })
          .send({ from: host })
          .wait();

        // Verify host's turn was recorded
        const hostTurnPlayed = await contractHost.methods
          .was_turn_played(gameId, turn)
          .simulate({ from: host });
        expect(hostTurnPlayed).toBe(true);

        turn += 1;

        // Guest shoots and misses (odd turns)
        await contractGuest.methods
          .shoot(gameId, turn, { x: guestMissCoords[i].x, y: guestMissCoords[i].y })
          .send({ from: guest })
          .wait();

        // Verify guest's turn was recorded
        // Note: On the last iteration (i=16), guest realizes they lost and doesn't
        // store their turn note (they call _on_finished instead of apply_my_shot)
        if (i < 16) {
          const guestTurnPlayed = await contractHost.methods
            .was_turn_played(gameId, turn)
            .simulate({ from: host });
          expect(guestTurnPlayed).toBe(true);
        }

        turn += 1;
      }

      // Final status should be WON_BY_HOST
      status = await contractHost.methods
        .get_game_status(gameId)
        .simulate({ from: host });
      expect(status).toBe(BigInt(STATUS_WON_BY_HOST));
    });

    it("should play a full game where guest wins", async () => {
      const gameId = createGameId(200);
      const hostShips = createValidShipsHost();
      const guestShips = createValidShipsGuest();

      const hostShipCells = getShipCells(hostShips);

      await contractHost.methods
        .create_game(gameId, hostShips)
        .send({ from: host })
        .wait();

      let status = await contractHost.methods
        .get_game_status(gameId)
        .simulate({ from: host });
      expect(status).toBe(BigInt(STATUS_CREATED));

      // Guest joins with initial shot hitting host's first cell (turn 1)
      await contractGuest.methods
        .join_game(gameId, guestShips, { x: hostShipCells[0].x, y: hostShipCells[0].y })
        .send({ from: guest })
        .wait();

      status = await contractHost.methods
        .get_game_status(gameId)
        .simulate({ from: host });
      expect(status).toBe(BigInt(STATUS_ACTIVE));

      const hostMissCoords = [
        { x: 0, y: 6 }, { x: 0, y: 7 }, { x: 0, y: 8 }, { x: 0, y: 9 },
        { x: 1, y: 6 }, { x: 1, y: 7 }, { x: 1, y: 8 }, { x: 1, y: 9 },
        { x: 2, y: 6 }, { x: 2, y: 7 }, { x: 2, y: 8 }, { x: 2, y: 9 },
        { x: 3, y: 6 }, { x: 3, y: 7 }, { x: 3, y: 8 }, { x: 3, y: 9 },
      ];

      let turn = 2;

      // Verify turn 1 (guest's initial shot) was recorded
      const turn1Played = await contractHost.methods
        .was_turn_played(gameId, 1)
        .simulate({ from: host });
      expect(turn1Played).toBe(true);

      // Guest needs to hit remaining 16 cells (already hit 1 in join_game)
      for (let i = 1; i < 17; i++) {
        // Host shoots and misses (even turns)
        await contractHost.methods
          .shoot(gameId, turn, { x: hostMissCoords[i - 1].x, y: hostMissCoords[i - 1].y })
          .send({ from: host })
          .wait();

        // Verify host's turn was recorded
        const hostTurnPlayed = await contractGuest.methods
          .was_turn_played(gameId, turn)
          .simulate({ from: guest });
        expect(hostTurnPlayed).toBe(true);

        turn += 1;

        // Guest shoots at host's ship cell (odd turns)
        await contractGuest.methods
          .shoot(gameId, turn, { x: hostShipCells[i].x, y: hostShipCells[i].y })
          .send({ from: guest })
          .wait();

        // Verify guest's turn was recorded
        const guestTurnPlayed = await contractGuest.methods
          .was_turn_played(gameId, turn)
          .simulate({ from: guest });
        expect(guestTurnPlayed).toBe(true);

        turn += 1;
      }

      // Host takes one more turn to verify the last guest shot
      // Note: This turn causes host to realize they lost, so the turn note
      // is NOT stored (the contract ends the game instead of storing the shot)
      await contractHost.methods
        .shoot(gameId, turn, { x: 4, y: 9 })
        .send({ from: host })
        .wait();

      status = await contractGuest.methods
        .get_game_status(gameId)
        .simulate({ from: guest });
      expect(status).toBe(BigInt(STATUS_WON_BY_GUEST));
    });
  });
});
