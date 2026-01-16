// Full Aztec.nr implementation of Battleships
use dep::aztec::macros::aztec;

mod types;
mod utils;

#[aztec]
contract Battleships {    
    use aztec::{
        macros::{functions::{external, only_self, internal}, storage::storage},
        protocol_types::{traits::ToField, address::AztecAddress, hash::poseidon2_hash_with_separator},
        messages::message_delivery::MessageDelivery,
        state_vars::{Map, PrivateImmutable, PrivateMutable, PublicImmutable, PublicMutable, Owned, SingleUseClaim},
    };

    use crate::types::{
        ShipPlacement, GameId, Shot, BoardNote, Turn,
        PlayedTurnNote, Coordinate,
        TOTAL_SHIP_CELLS, TURN_TIMEOUT,
        STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST
    };
    use uint_note::uint_note::UintNote;
    use address_note::address_note::AddressNote;    

    pub global DOM_SEP__NOTE_HASH: u32 = 1;

    #[storage]
    struct Storage<Context> {
        // PUBLIC
        // Note: we'll make this immutable so that we can read it privately
        public_game_hosts: Map<GameId, PublicImmutable<AztecAddress, Context>, Context>,
        public_game_status: Map<GameId, PublicMutable<u8, Context>, Context>,

        // PRIVATE        
        private_board: Map<GameId, Owned<PrivateImmutable<BoardNote, Context>, Context>, Context>,
        private_opponent: Map<GameId, Owned<PrivateImmutable<AddressNote, Context>, Context>, Context>,
        private_turns: Map<GameId, Map<Turn, Owned<PrivateImmutable<PlayedTurnNote, Context>, Context>, Context>, Context>,
        private_my_shots: Map<GameId, Map<Coordinate, Map<Coordinate, Owned<SingleUseClaim<Context>, Context>, Context>, Context>, Context>,
        private_hit_counter: Map<GameId, Owned<PrivateMutable<UintNote, Context>, Context>, Context>,
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
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Validate ships and build board
        let board = crate::utils::validate_and_build_board(ships);
        self.storage.private_board
            .at(game_id)
            .at(host)
            .initialize(BoardNote { board })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Call public function to update game status
        Battleships::at(self.context.this_address())
            .on_game_created(game_id, host)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_created(game_id: GameId, host: AztecAddress) {
        // Initialize game state
        self.storage.public_game_hosts
            .at(game_id)
            .initialize(host);
        self.storage.public_game_status
            .at(game_id)
            .write(STATUS_CREATED);
    }

    #[external("private")]
    fn join_game(
        game_id: GameId,
        ships: ShipPlacement,
        initial_shot: Shot
    ) {
        // Validate shot
        crate::utils::validate_shot(initial_shot);

        let guest = self.context.msg_sender().unwrap();
        let host = self.storage.public_game_hosts
            .at(game_id)
            .read();

        // Initialize counter
        self.storage.private_hit_counter
            .at(game_id)
            .at(guest)
            .initialize(UintNote { value: 0 })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Validate ships and build board
        let board = crate::utils::validate_and_build_board(ships);
        self.storage.private_board
            .at(game_id)
            .at(guest)
            .initialize(BoardNote { board })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Store opponent address
        self.storage.private_opponent
            .at(game_id)
            .at(guest)
            .initialize(AddressNote{ address: host })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Set opponent's opponent to be me (guest)
        self.storage.private_opponent
            .at(game_id)
            .at(host)
            .initialize(AddressNote{ address: guest })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Apply my shot
        self.internal.apply_my_shot(game_id, host, initial_shot, 1);

        // Enqueue public function to start game
        Battleships::at(self.context.this_address())
            .on_game_joined(game_id)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_joined(game_id: GameId) {
        let mut game_status = self.storage.public_game_status
            .at(game_id)
            .read();

        // Validate game is in created state
        assert(game_status == STATUS_CREATED, "Game not in created state");

        // Activate game
        self.storage.public_game_status.at(game_id).write(STATUS_ACTIVE);
    }

    // ============================================================================
    // SHOOTING
    // ============================================================================
    #[external("private")]
    fn shoot(
        game_id: GameId,
        turn: Turn,
        shot: Shot
    ) {
        // Validate new shot
        crate::utils::validate_shot(shot);

        let player = self.context.msg_sender().unwrap();
        let opponent = self.storage.private_opponent
            .at(game_id)
            .at(player)
            .get_note()
            .address;

        // Read opponent's turn 
        // Note: fetching the note would fail if it didn't exist
        let opponents_turn = self.storage.private_turns
            .at(game_id)
            .at(turn - 1)
            .at(opponent)
            .get_note();

        // Verify opponent's last shot
        let did_i_lose = self.internal.verify_opponents_shot(game_id, opponents_turn.shot);

        if (did_i_lose) {
            let status = if (turn % 2 == 0) { STATUS_WON_BY_GUEST } else { STATUS_WON_BY_HOST };
            // Call public function to process loss
            Battleships::at(self.context.this_address())
                .on_finished(game_id, status)
                .enqueue(self.context);
        } else {
            // Apply our new shot with turn number
            self.internal.apply_my_shot(game_id, opponent, shot, turn);

            // Call public function to increment turn
            Battleships::at(self.context.this_address())
                .on_shoot(game_id)
                .enqueue(self.context);
        }
    }
    

    #[external("public")]
    #[only_self]
    fn on_shoot(game_id: GameId) {
        let mut game_status = self.storage.public_game_status
            .at(game_id)
            .read();

       // Check game is active
        assert(game_status == STATUS_ACTIVE, "Game not active");
    }

    #[external("public")]
    #[only_self]
    fn on_finished(game_id: GameId, end_status: u8) {
        let mut game_status = self.storage.public_game_status
            .at(game_id)
            .read();

        // Check game is active
        assert(game_status == STATUS_ACTIVE, "Game not active");

        // Mark game as completed with the correct status
        self.storage.public_game_status
            .at(game_id)
            .write(end_status);
    }

    #[internal("private")]
    fn verify_opponents_shot(game_id: GameId, opponent_shot: Shot) -> bool {
        let player = self.context.msg_sender().unwrap();

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
            let counter_message = self.storage.private_hit_counter
                .at(game_id)
                .at(player)
                .get_note();

            let counter = counter_message
                .get_note()
                .value;
            
            counter_message.deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

            aztec::oracle::debug_log::debug_log_format("Counter: {}", [counter as Field]);

            if (counter == (TOTAL_SHIP_CELLS as u128) - 1) {
                lost = true;
            } else {
                self.storage.private_hit_counter
                .at(game_id)
                .at(player)
                .replace(|current| UintNote { value: current.value + 1 })
                .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);
            }
        }

        lost
    }    

    #[internal("private")]
    fn apply_my_shot(
        game_id: GameId,
        opponent: AztecAddress,
        shot: Shot,
        turn: u32
    ) {
        let player = self.context.msg_sender().unwrap();
        let timestamp = self.context.get_anchor_block_header().global_variables.timestamp;

        // Check we haven't shot this position before
        self.storage.private_my_shots
            .at(game_id)
            .at(shot.x)
            .at(shot.y)
            .at(player)
            .claim();

        // Store my turn and send it to my opponent
        // Note: this would fail if we had already played this turn before
        self.storage.private_turns
            .at(game_id)
            .at(turn)
            .at(player)
            .initialize(PlayedTurnNote { shot, timestamp })
            .deliver_to(opponent, MessageDelivery.CONSTRAINED_ONCHAIN);

        // Emit nullifier so that I can prove that this turn as been played
        let nullifier = self.internal.build_nullifier(game_id, turn);
        self.context.push_nullifier(nullifier);
    }
   
    // ============================================================================
    // CLAIM ABANDONMENT
    // ============================================================================

    #[external("private")]
    fn claim_abandonment(game_id: GameId, current_turn: Turn) {
        let player = self.context.msg_sender().unwrap();
        let block_header = self.context.get_anchor_block_header();
        let current_timestamp = block_header.global_variables.timestamp as u128;

        // Read my own last turn to get timestamp
        // Note: will fail if I haven't played this turn
        let my_last_turn = self.storage.private_turns
            .at(game_id)
            .at(current_turn - 1)
            .at(player)
            .get_note();

       // Make sure enough time has passed
        let last_timestamp = my_last_turn.timestamp as u128;
        assert(current_timestamp - last_timestamp > (TURN_TIMEOUT as u128), "Opponent still has time to play");

        // Make sure opponent hasnt played by emitting the turn's nullifier
        let nullifier = self.internal.build_nullifier(game_id, current_turn);
        self.context.push_nullifier(nullifier);

        let status = if (current_turn % 2 == 0) { STATUS_WON_BY_GUEST } else { STATUS_WON_BY_HOST };

        // Call public function to mark abandonment
        Battleships::at(self.context.this_address())
            .on_finished(game_id, status)
            .enqueue(self.context);
    }


    #[internal("private")]
    fn build_nullifier(game_id: GameId, turn: Turn) -> Field {
        let hash = poseidon2_hash_with_separator(
            [game_id.to_field(), turn as Field],
            DOM_SEP__NOTE_HASH as Field,
        );

        hash
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    #[external("utility")]
    unconstrained fn get_game_status(game_id: GameId) -> u8 {
        self.storage.public_game_status
            .at(game_id)
            .read()
    }

    #[external("utility")]
    unconstrained fn get_hit_counter(game_id: GameId, player: AztecAddress) -> u128 {
        self.storage.private_hit_counter
            .at(game_id)
            .at(player)
            .view_note()
            .value
    }

}

mod test;
