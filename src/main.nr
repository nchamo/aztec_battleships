// Full Aztec.nr implementation of Battleships
use dep::aztec::macros::aztec;

mod types;
mod utils;

#[aztec]
contract Battleships {
    use aztec::{
        macros::{functions::{external, only_self, internal}, storage::storage},
        protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize, ToField}},
        messages::message_delivery::MessageDelivery,
        state_vars::{Map, PrivateImmutable, PrivateMutable, PublicMutable, Owned},
    };

    use crate::types::{
        ShipData, ShipPlacement, PublicGameState, GameId, Coordinate, Shot, Timestamp, ShotStatus,
        BOARD_SIZE, TOTAL_SHIP_CELLS, SETUP_TIMEOUT, TURN_TIMEOUT,
        STATUS_CREATED, STATUS_ACTIVE, STATUS_COMPLETED,
        WIN_VICTORY, WIN_ABANDONMENT,
        ROLE_HOST, ROLE_GUEST,
        SHOT_STATUS_NONE, SHOT_STATUS_MISS, SHOT_STATUS_HIT
    };
    use crate::utils::{validate_ships, check_hit};
    use uint_note::uint_note::UintNote;

    #[storage]
    struct Storage<Context> {
        // Public storage - game coordination
        
        public_games: Map<GameId, PublicMutable<PublicGameState, Context>, Context>,

        // PRIVATE
        // Immutable
        private_role: Map<GameId, Owned<PrivateImmutable<UintNote, Context>, Context>, Context>,
        private_my_ships_placement: Map<GameId, Map<Coordinate, Map<Coordinate, Owned<PrivateImmutable<UintNote, Context>, Context>, Context>, Context>, Context>, 
        private_opponent: Map<GameId, Owned<PrivateImmutable<AztecAddress, Context>, Context>, Context>, 
        // Mutable
        private_last_action_timestamp: Map<GameId, Owned<PrivateMutable<Timestamp, Context>, Context>, Context>,
        private_hit_counter: Map<GameId, Owned<PrivateMutable<u8, Context>, Context>, Context>,
        private_last_opponent_shot: Map<GameId, Owned<PrivateMutable<Shot, Context>, Context>, Context>,
        // X, Y => 0 = not shot, 1 = miss, 2 = hit
        private_my_shots: Map<GameId, Map<Coordinate, Map<Coordinate, Owned<PrivateMutable<ShotStatus, Context>, Context>, Context>, Context>, Context>,
    }

    ============================================================================
    GAME CREATION & JOINING
    ============================================================================    

    #[external("private")]
    fn create_game(
        game_id: GameId,
        ships: ShipPlacement
    ) {
        validate_ships(ships);

        let host = self.context.msg_sender().unwrap();

        // Mark myself as host
        self.storage.private_role
            .at(game_id)
            .at(host)
            .initialize(UintNote {value: ROLE_HOST as u128 })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // Store ship placement coordinates
        self.internal.store_ship_placement(game_id, ships, host);

        // Call public function to update game status
        Battleships::at(self.context.this_address())
            .on_game_created(game_id)
            .enqueue(self.context);
    }

    #[internal("private")]
    fn store_ship_placement(
        game_id: GameId,
        ships: ShipPlacement,
        owner: AztecAddress
    ) {
        // Expand all ships to their cell coordinates and mark them in storage
        let carrier_cells = crate::utils::expand_ship(ships.carrier, crate::types::SHIP_SIZES[0]);
        let battleship_cells = crate::utils::expand_ship(ships.battleship, crate::types::SHIP_SIZES[1]);
        let cruiser_cells = crate::utils::expand_ship(ships.cruiser, crate::types::SHIP_SIZES[2]);
        let submarine_cells = crate::utils::expand_ship(ships.submarine, crate::types::SHIP_SIZES[3]);
        let destroyer_cells = crate::utils::expand_ship(ships.destroyer, crate::types::SHIP_SIZES[4]);

        // Mark carrier cells
        for i in 0..5 {
            if (i as u8) < crate::types::SHIP_SIZES[0] {
                let x = carrier_cells[i].0 as Field;
                let y = carrier_cells[i].1 as Field;
                self.storage.private_my_ships_placement
                    .at(game_id)
                    .at(x)
                    .at(y)
                    .at(owner)
                    .initialize(UintNote{value: 1})
                    .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);
            }
        }

        // Mark battleship cells
        for i in 0..5 {
            if (i as u8) < crate::types::SHIP_SIZES[1] {
                let x = battleship_cells[i].0 as Field;
                let y = battleship_cells[i].1 as Field;
                self.storage.private_my_ships_placement
                    .at(game_id)
                    .at(x)
                    .at(y)
                    .at(owner)
                    .initialize(UintNote{value: 1})
                    .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);
            }
        }

        // Mark cruiser cells
        for i in 0..5 {
            if (i as u8) < crate::types::SHIP_SIZES[2] {
                let x = cruiser_cells[i].0 as Field;
                let y = cruiser_cells[i].1 as Field;
                self.storage.private_my_ships_placement
                    .at(game_id)
                    .at(x)
                    .at(y)
                    .at(owner)
                    .initialize(UintNote{value: 1})
                    .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);
            }
        }

        // Mark submarine cells
        for i in 0..5 {
            if (i as u8) < crate::types::SHIP_SIZES[3] {
                let x = submarine_cells[i].0 as Field;
                let y = submarine_cells[i].1 as Field;
                self.storage.private_my_ships_placement
                    .at(game_id)
                    .at(x)
                    .at(y)
                    .at(owner)
                    .initialize(UintNote{value: 1})
                    .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);
            }
        }

        // Mark destroyer cells
        for i in 0..5 {
            if (i as u8) < crate::types::SHIP_SIZES[4] {
                let x = destroyer_cells[i].0 as Field;
                let y = destroyer_cells[i].1 as Field;
                self.storage.private_my_ships_placement
                    .at(game_id)
                    .at(x)
                    .at(y)
                    .at(owner)
                    .initialize(UintNote{value: 1})
                    .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);
            }
        }
    }

    

    #[external("public")]
    #[only_self]
    fn on_game_created(game_id: GameId) {
        let host = self.context.msg_sender().unwrap();

        // Initialize game state
        let game_state = PublicGameState::new(host.to_field());

        self.storage.public_games
            .at(game_id)
            .write(game_state);
    }

    #[external("private")]
    fn join_game(
        game_id: Field,
        opponent: AztecAddress,
        packed_ships: [Field; 5],  // Packed ship data (carrier, battleship, cruiser, submarine, destroyer)
        initial_shot: Shot
    ) {
        // Unpack and validate ships
        let ships = ShipPlacement::new(
            ShipData::unpack(packed_ships[0]),
            ShipData::unpack(packed_ships[1]),
            ShipData::unpack(packed_ships[2]),
            ShipData::unpack(packed_ships[3]),
            ShipData::unpack(packed_ships[4]),
        );
        validate_ships(ships);

        // Validate shot
        assert(initial_shot.x < BOARD_SIZE, "Shot x out of bounds");
        assert(initial_shot.y < BOARD_SIZE, "Shot y out of bounds");

        let sender = self.context.msg_sender();
        let game_id_struct = GameId::new(game_id);

        // Initialize my private game state fields as GUEST
        self.storage.private_role.at(game_id_struct).write(ROLE_GUEST);
        self.storage.private_ship_0.at(game_id_struct).write(packed_ships[0]);
        self.storage.private_ship_1.at(game_id_struct).write(packed_ships[1]);
        self.storage.private_ship_2.at(game_id_struct).write(packed_ships[2]);
        self.storage.private_ship_3.at(game_id_struct).write(packed_ships[3]);
        self.storage.private_ship_4.at(game_id_struct).write(packed_ships[4]);
        self.storage.private_opponent.at(game_id_struct).write(opponent.to_field());
        self.storage.private_last_action_timestamp.at(game_id_struct).write(0);
        self.storage.private_hit_counter.at(game_id_struct).write(0);
        self.storage.private_last_opponent_shot_x.at(game_id_struct).write(0);
        self.storage.private_last_opponent_shot_y.at(game_id_struct).write(0);

        // Remember my shot in my private tracking
        let shot_x = initial_shot.x as Field;
        let shot_y = initial_shot.y as Field;
        self.storage.private_my_shots
            .at(game_id_struct)
            .at(shot_x)
            .at(shot_y)
            .write(SHOT_STATUS_NONE);

        // TODO: Cross-user storage updates - need to implement via notes or public storage
        // For now, skipping the update of opponent's last_opponent_shot
        // This will need to be redesigned to use notes or public storage for cross-user communication

        // Call public function to activate game
        Battleships::at(self.context.this_address())
            .on_game_joined(game_id_struct, opponent)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_joined(game_id: GameId, opponent: AztecAddress) {
        let sender = self.context.msg_sender();
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Validate game is in created state
        assert(game_state.status == STATUS_CREATED, "Game not in created state");

        // Validate opponent is the host
        assert(opponent.to_field() == game_state.host, "Opponent is not host");

        // Activate game and set turn to 1 (guest shot at turn 0, now host's turn)
        game_state.status = STATUS_ACTIVE;
        game_state.turn = 1;

        self.storage.public_games.at(game_id).write(game_state);
    }

    // ============================================================================
    // SHOOTING
    // ============================================================================

   

    #[external("private")]
    fn shoot(
        game_id: GameId,
        shot: Shot
    ) {
        // Validate new shot
        assert(shot.x < BOARD_SIZE, "Shot x out of bounds");
        assert(shot.y < BOARD_SIZE, "Shot y out of bounds");

        // Check we haven't shot this position before
        let shot_x = shot.x as Field;
        let shot_y = shot.y as Field;
        let existing_shot = self.storage.private_my_shots
            .at(game_id)
            .at(shot_x)
            .at(shot_y)
            .read();

        assert(existing_shot == SHOT_STATUS_NONE, "Already shot at this position");

        // First, verify opponent's last shot (combined flow)
        self.verify_opponents_shot(game_id);

        // Then apply our new shot
        self.apply_shot(game_id, shot);
    }

    #[external("private")]
    fn verify_opponents_shot(game_id: GameId) {
        // Read my private game state to get opponent's last shot
        let mut my_state = self.storage.private_game.at(game_id).read();
        let opponent_shot = my_state.last_opponent_shot;

        // Only process if there is a shot (not the default 0,0)
        let has_shot = (opponent_shot.x != 0) | (opponent_shot.y != 0);

        if has_shot {
            // Unpack my ships from storage
            let packed_ships = my_state.my_ships;
            let my_ships = ShipPlacement::new(
                ShipData::unpack(packed_ships[0]),
                ShipData::unpack(packed_ships[1]),
                ShipData::unpack(packed_ships[2]),
                ShipData::unpack(packed_ships[3]),
                ShipData::unpack(packed_ships[4]),
            );

            // Check if opponent hit anything
            let is_hit = check_hit(opponent_shot.x, opponent_shot.y, my_ships);

            if is_hit {
                // Increment opponent's hit counter
                let opponent_address = my_state.opponent;
                let mut opponent_state = self.storage.private_game.at(game_id).read();
                opponent_state.hit_counter += 1;
                self.storage.private_game.at(game_id).write(opponent_state);

                // Check if opponent won (hit all ships)
                if opponent_state.hit_counter >= TOTAL_SHIP_CELLS {
                    Battleships::at(self.context.this_address())
                        .on_won(game_id)
                        .enqueue(self.context);
                }
            }

            // Clear the last opponent shot (processed)
            my_state.last_opponent_shot = Shot::new(0, 0);
            self.storage.private_game.at(game_id).write(my_state);
        }
    }

    #[external("private")]
    fn apply_shot(
        game_id: GameId,
        shot: Shot,
    ) {
        let sender = self.context.msg_sender();

        // Update my last action timestamp
        let mut my_state = self.storage.private_game.at(game_id).read();
        my_state.last_action_timestamp = 0;  // TODO: Implement proper timestamp tracking
        self.storage.private_game.at(game_id).write(my_state);

        // Remember my shot (mark as pending verification)
        let shot_x = shot.x as Field;
        let shot_y = shot.y as Field;
        self.storage.private_my_shots
            .at(game_id)
            .at(shot_x)
            .at(shot_y)
            .write(SHOT_STATUS_NONE);

        // Update opponent's storage (set last_opponent_shot)
        let opponent_address = my_state.opponent;
        let mut opponent_state = self.storage.private_game.at(game_id).read();
        opponent_state.last_opponent_shot = shot;
        self.storage.private_game.at(game_id).write(opponent_state);

        // Call public function to increment turn
        Battleships::at(self.context.this_address())
            .on_shoot(game_id, shot)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_shoot(game_id: GameId, shot: Shot) {
        let sender = self.context.msg_sender();
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Validate game is active
        assert(game_state.status == STATUS_ACTIVE, "Game not active");

        // Validate it was sender's turn
        let is_host_turn = (game_state.turn % 2) == 1;  // Turn 1, 3, 5... = host
        let is_sender_host = sender.to_field() == game_state.host;
        assert(is_host_turn == is_sender_host, "Not your turn");

        // Increment turn
        game_state.turn += 1;

        self.storage.public_games.at(game_id).write(game_state);
    }

    #[external("public")]
    #[only_self]
    fn on_won(game_id: GameId) {
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Validate game is active
        assert(game_state.status == STATUS_ACTIVE, "Game not active");

        // Mark game as completed
        game_state.status = STATUS_COMPLETED;

        self.storage.public_games.at(game_id).write(game_state);
    }

    // ============================================================================
    // CLAIM ABANDONMENT
    // ============================================================================

    #[external("private")]
    fn claim_abandonment(game_id: GameId) {
        let sender = self.context.msg_sender();
        let current_timestamp = 0;  // TODO: Implement proper timestamp tracking

        // Read game state
        let my_state = self.storage.private_game.at(game_id).read();
        let opponent_address = my_state.opponent;

        // Read opponent's last action timestamp
        let opponent_state = self.storage.private_game.at(game_id).read();
        let opponent_last_action = opponent_state.last_action_timestamp;

        // Calculate timeout period based on game status
        let game_state = self.storage.public_games.at(game_id).read();
        let timeout_period = if game_state.status == STATUS_CREATED {
            SETUP_TIMEOUT
        } else {
            TURN_TIMEOUT
        };

        // Verify timeout has elapsed
        let time_elapsed = current_timestamp - opponent_last_action;
        assert(time_elapsed >= timeout_period, "Timeout not elapsed");

        // For active games, verify it's opponent's turn (not our turn)
        if game_state.status == STATUS_ACTIVE {
            let is_host_turn = (game_state.turn % 2) == 1;
            let is_sender_host = sender.to_field() == game_state.host;
            assert(is_host_turn != is_sender_host, "Cannot claim on your turn");
        }

        // Call public function to mark abandonment
        Battleships::at(self.context.this_address())
            .on_claim_abandonment(game_id)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_claim_abandonment(game_id: GameId) {
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Validate game is not already completed
        assert(game_state.status != STATUS_COMPLETED, "Game already completed");

        // Mark game as completed (abandoned)
        game_state.status = STATUS_COMPLETED;

        self.storage.public_games.at(game_id).write(game_state);
    }


}
