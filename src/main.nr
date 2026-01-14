// Full Aztec.nr implementation of Battleships
use dep::aztec::macros::aztec;

mod types;
mod utils;

/*
    TODOs:
    - Check that all players must be part of the game
    - Use nullifiers (or single claims) to avoid shooting twice the same coordinate
    - Optimize storage variables

    Questions:
    - If I'm using anchor block, can I use a very old block to try to cause abandonment?

*/

#[aztec]
contract Battleships {
    use aztec::{
        macros::{functions::{external, only_self, internal}, storage::storage},
        protocol_types::{address::AztecAddress, traits::{ToField}},
        messages::message_delivery::MessageDelivery,
        state_vars::{Map, PrivateImmutable, PrivateMutable, PublicMutable, Owned},
    };

    use crate::types::{
        ShipPlacement, PublicGameState, GameId, Shot, ShotNote, BoardNote,
        TOTAL_SHIP_CELLS, TURN_TIMEOUT,
        STATUS_CREATED, STATUS_ACTIVE, STATUS_COMPLETED,
    };
    use uint_note::uint_note::UintNote;
    use address_note::address_note::AddressNote;

    #[storage]
    struct Storage<Context> {
        // Public storage - game coordination
        public_games: Map<GameId, PublicMutable<PublicGameState, Context>, Context>,

        // PRIVATE
        // Immutable
        private_board: Map<GameId, Owned<PrivateImmutable<BoardNote, Context>, Context>, Context>,
        private_opponent: Map<GameId, Owned<PrivateImmutable<AddressNote, Context>, Context>, Context>,
        // Mutable
        private_last_action_timestamp: Map<GameId, Owned<PrivateMutable<UintNote, Context>, Context>, Context>,
        private_hit_counter: Map<GameId, Owned<PrivateMutable<UintNote, Context>, Context>, Context>,
        private_last_opponent_shot: Map<GameId, Owned<PrivateMutable<ShotNote, Context>, Context>, Context>,
    }

    // ============================================================================
    // GAME CREATION & JOINING
    // ============================================================================    

    #[external("private")]
    fn create_game(
        game_id: GameId,
        ships: ShipPlacement
    ) {
        let host = self.context.msg_sender().unwrap();

        // Initialize my counter
        self.storage.private_hit_counter
            .at(game_id)
            .at(host)
            .initialize(UintNote { value: 0 })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // Validate ships and build board
        let board = crate::utils::validate_and_build_board(ships);
        self.storage.private_board
            .at(game_id)
            .at(host)
            .initialize(BoardNote { board })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // Call public function to update game status
        Battleships::at(self.context.this_address())
            .on_game_created(game_id, host)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_created(game_id: GameId, host: AztecAddress) {
        // Initialize game state
        let game_state = PublicGameState::new(host.to_field());

        self.storage.public_games
            .at(game_id)
            .write(game_state);
    }

    #[external("private")]
    fn join_game(
        game_id: GameId,
        opponent: AztecAddress,
        ships: ShipPlacement,
        initial_shot: Shot
    ) {
        // Validate shot
        crate::utils::validate_shot(initial_shot);

        let guest = self.context.msg_sender().unwrap();
        let timestamp = self.context.get_anchor_block_header().global_variables.timestamp;

        // Initialize counter
        self.storage.private_hit_counter
            .at(game_id)
            .at(guest)
            .initialize(UintNote { value: 0 })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // Validate ships and build board
        let board = crate::utils::validate_and_build_board(ships);
        self.storage.private_board
            .at(game_id)
            .at(guest)
            .initialize(BoardNote { board })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // Store opponent address
        self.storage.private_opponent
            .at(game_id)
            .at(guest)
            .initialize(AddressNote{ address: opponent })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // Update last action timestamp for opponent
        // We do this so that they can't declare abandonment immediately after joined
        self.storage.private_last_action_timestamp
            .at(game_id)
            .at(opponent)
            .initialize(UintNote{ value: timestamp as u128 })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Set opponent's opponent to be me (guest)
        self.storage.private_opponent
            .at(game_id)
            .at(opponent)
            .initialize(AddressNote{ address: guest })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Apply shot
        self.internal.apply_my_shot(game_id, initial_shot);

        // Enqueue public function to start game
        Battleships::at(self.context.this_address())
            .on_game_joined(game_id, opponent)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_joined(game_id: GameId, opponent: AztecAddress) {
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Validate game is in created state
        assert(game_state.status == STATUS_CREATED, "Game not in created state");

        // Validate opponent is correct
        assert(game_state.host == opponent.to_field(), "Invalid opponent");

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
        crate::utils::validate_shot(shot);

        // Verify opponent's last shot
        let did_i_lose = self.internal.verify_opponents_shot(game_id);

        if (did_i_lose) {
            // Call public function to process loss
            Battleships::at(self.context.this_address())
                .on_lost(game_id)
                .enqueue(self.context);
        } else {
            // Apply our new shot
            self.internal.apply_my_shot(game_id, shot);

            // Call public function to increment turn
            Battleships::at(self.context.this_address())
                .on_shoot(game_id)
                .enqueue(self.context);
        }
    }
    

    #[external("public")]
    #[only_self]
    fn on_shoot(game_id: GameId) {
        let mut game_state = self.storage.public_games.at(game_id).read();

       // Check game is active and it's my turn
        self.internal.check_correct_turn(game_state, true);

        // Increment turn
        game_state.turn += 1;
        self.storage.public_games.at(game_id).write(game_state);
    }

    #[external("public")]
    #[only_self]
    fn on_lost(game_id: GameId) {
        let mut game_state: PublicGameState = self.storage.public_games.at(game_id).read();

        // Check game is active and it's my correct turn
        self.internal.check_correct_turn(game_state, true);

        // Mark game as completed
        game_state.status = STATUS_COMPLETED;
        self.storage.public_games.at(game_id).write(game_state);
    }

    #[internal("private")]
    fn verify_opponents_shot(game_id: GameId) -> bool {
        let player = self.context.msg_sender().unwrap();

        // Read my opponent's last shot from my storage
        let opponent_shot = self.storage.private_last_opponent_shot
            .at(game_id)
            .at(player)
            .get_note()
            .get_note()
            .shot;

        let mut lost = false;

        // Check if opponent hit any of my ships
        let my_board = self.storage.private_board
            .at(game_id)
            .at(player)
            .get_note()
            .board;

        let idx = (opponent_shot.y as u32) * 10 + (opponent_shot.x as u32);
        let is_hit = my_board[idx];

        if is_hit {
            // Read counter
            let counter: u128 = self.storage.private_hit_counter
                .at(game_id)
                .at(player)
                .get_note()
                .get_note()
                .value;

            if (counter == (TOTAL_SHIP_CELLS as u128) - 1) {
                lost = true;
            } else {
                self.storage.private_hit_counter
                .at(game_id)
                .at(player)
                .replace(|current| UintNote { value: current.value + 1 })
                .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);
            }
        }

        lost
    }    

    #[internal("private")]
    fn apply_my_shot(
        game_id: GameId,
        shot: Shot,
    ) {
        let player = self.context.msg_sender().unwrap();
        let timestamp = self.context.get_anchor_block_header().global_variables.timestamp;
        let opponent = self.storage.private_opponent
            .at(game_id)
            .at(player)
            .get_note()
            .address;

        // TODO: Check we haven't shot this position before

        // Update my last action timestamp
        self.storage.private_last_action_timestamp
            .at(game_id)
            .at(player)
            .initialize_or_replace(|_| UintNote{ value: timestamp as u128 })
            .deliver(MessageDelivery.UNCONSTRAINED_OFFCHAIN);

        // "Send" shot to opponent
        self.storage.private_last_opponent_shot
            .at(game_id)
            .at(opponent)
            .initialize_or_replace(|_| ShotNote { shot })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);                
    }
   
    // ============================================================================
    // CLAIM ABANDONMENT
    // ============================================================================

    #[external("private")]
    fn claim_abandonment(game_id: GameId) {
        let player = self.context.msg_sender().unwrap();

        let current_timestamp = self.context.get_anchor_block_header().global_variables.timestamp as u128;
        let last_timestamp = self.storage.private_last_action_timestamp
            .at(game_id)
            .at(player)
            .get_note()
            .get_note()
            .value;

        assert(current_timestamp - last_timestamp > (TURN_TIMEOUT as u128), "Opponent did not abandon");

        // Call public function to mark abandonment
        Battleships::at(self.context.this_address())
            .on_claim_abandonment(game_id)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_claim_abandonment(game_id: GameId) {
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Check game is active and it's not my turn
        self.internal.check_correct_turn(game_state, false);

        // Mark game as completed (abandoned)
        game_state.status = STATUS_COMPLETED;
        self.storage.public_games.at(game_id).write(game_state);
    }

    // ============================================================================
    // HELPERS
    // ============================================================================

    #[internal("public")]
    fn check_correct_turn(game_state: PublicGameState, should_be_my_turn: bool) {
        let sender = self.context.msg_sender().unwrap();

        // Validate game is active
        assert(game_state.status == STATUS_ACTIVE, "Game not active");

        // Validate it was sender's turn
        let is_host_turn = (game_state.turn % 2) == 1;  // Turn 1, 3, 5... = host
        let is_sender_host = sender.to_field() == game_state.host;
        let is_my_turn = is_host_turn == is_sender_host;
        assert(should_be_my_turn == is_my_turn, "Incorrect");
    }
}

mod test;
