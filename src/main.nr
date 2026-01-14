// Full Aztec.nr implementation of Battleships
use dep::aztec::macros::aztec;

mod types;
mod utils;

/*
    TODOs:
    - Use nullifiers (or single claims) to avoid shooting twice the same coordinate
    - Optimize storage variables

    Questions:
    - If I'm using anchor block, can I use a very old block to try to cause abandonment?
    - If I dont use CONSTRAINED_ONCHAIN for stuff I only need to store for myself, it doesnt find the note

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
        ShipPlacement, PublicGameState, GameId, Shot, BoardNote,
        PlayerActionNote, OpponentActionNote,
        TOTAL_SHIP_CELLS, TURN_TIMEOUT,
        STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST
    };
    use uint_note::uint_note::UintNote;
    use address_note::address_note::AddressNote;

    #[storage]
    struct Storage<Context> {
        // PUBLIC
        public_games: Map<GameId, PublicMutable<PublicGameState, Context>, Context>,

        // PRIVATE
        // Immutable
        private_board: Map<GameId, Owned<PrivateImmutable<BoardNote, Context>, Context>, Context>,
        private_opponent: Map<GameId, Owned<PrivateImmutable<AddressNote, Context>, Context>, Context>,
        // Mutable
        private_my_last_action: Map<GameId, Owned<PrivateMutable<PlayerActionNote, Context>, Context>, Context>,
        private_opponent_last_action: Map<GameId, Owned<PrivateMutable<OpponentActionNote, Context>, Context>, Context>,
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
        let timestamp = self.context.get_anchor_block_header().global_variables.timestamp;

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

        // Initialize last action
        self.storage.private_my_last_action
            .at(game_id)
            .at(host)
            .initialize(PlayerActionNote{ turn: 0, timestamp })
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
        let game_state = PublicGameState::new(host.to_field());

        self.storage.public_games
            .at(game_id)
            .write(game_state);
    }

    #[external("private")]
    fn join_game(
        game_id: GameId,
        host: AztecAddress,
        ships: ShipPlacement,
        initial_shot: Shot
    ) {
        // Validate shot
        crate::utils::validate_shot(initial_shot);

        let guest = self.context.msg_sender().unwrap();

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
            .on_game_joined(game_id, host)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_joined(game_id: GameId, host: AztecAddress) {
        let mut game_state = self.storage.public_games.at(game_id).read();

        // Validate game is in created state
        assert(game_state.status == STATUS_CREATED, "Game not in created state");

        // Validate host is correct
        assert(game_state.host == host.to_field(), "Invalid host");

        // Activate game
        game_state.status = STATUS_ACTIVE;

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

        let player = self.context.msg_sender().unwrap();

        // Read my last action from storage
        let my_action = self.storage.private_my_last_action
            .at(game_id)
            .at(player)
            .get_note()
            .get_note();

        // Read my opponent's last action from my storage
        let opponent_action = self.storage.private_opponent_last_action
            .at(game_id)
            .at(player)
            .get_note()
            .get_note();
        
        assert(opponent_action.turn == my_action.turn + 1, "Not my turn");

        // Verify opponent's last shot
        // let did_i_lose = self.internal.verify_opponents_shot(game_id, opponent_action.shot);
        let did_i_lose = false;

        if (did_i_lose) {
            let status = if (my_action.turn % 2 == 0) { STATUS_WON_BY_GUEST } else { STATUS_WON_BY_HOST };
            // Call public function to process loss
            Battleships::at(self.context.this_address())
                .on_finished(game_id, status)
                .enqueue(self.context);
        } else {
             let opponent = self.storage.private_opponent
                .at(game_id)
                .at(player)
                .get_note()
                .address;

            // Apply our new shot with turn number
            self.internal.apply_my_shot(game_id, opponent, shot, my_action.turn + 2);

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

       // Check game is active
        assert(game_state.status == STATUS_ACTIVE, "Game not active");
    }

    #[external("public")]
    #[only_self]
    fn on_finished(game_id: GameId, end_status: u8) {
        let mut game_state: PublicGameState = self.storage.public_games.at(game_id).read();

        // Check game is active
        assert(game_state.status == STATUS_ACTIVE, "Game not active");

        // Mark game as completed
        game_state.status = end_status;
        self.storage.public_games.at(game_id).write(game_state);
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
        turn: u8
    ) {
        let player = self.context.msg_sender().unwrap();
        let timestamp = self.context.get_anchor_block_header().global_variables.timestamp;

        // TODO: Check we haven't shot this position before

        // Update my last action with turn and timestamp
        self.storage.private_my_last_action
            .at(game_id)
            .at(player)
            .initialize_or_replace(|_| PlayerActionNote{ turn, timestamp } )
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // "Send" shot to opponent (they will read this when they shoot next)
        self.storage.private_opponent_last_action
            .at(game_id)
            .at(opponent)
            .initialize_or_replace(|_| OpponentActionNote { turn, shot })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);
    }
   
    // ============================================================================
    // CLAIM ABANDONMENT
    // ============================================================================

    #[external("private")]
    fn claim_abandonment(game_id: GameId) {
        let player = self.context.msg_sender().unwrap();

        // Read my own last action to get when I last acted
        let my_last_action = self.storage.private_my_last_action
            .at(game_id)
            .at(player)
            .get_note()
            .get_note();

        // Read my opponent's last action from my storage
        let opponent_action = self.storage.private_opponent_last_action
            .at(game_id)
            .at(player)
            .get_note()
            .get_note();
        
        assert(opponent_action.turn == my_last_action.turn + 1, "Not my turn");

        let current_timestamp = self.context.get_anchor_block_header().global_variables.timestamp as u128;
        let last_timestamp = my_last_action.timestamp as u128;
        assert(current_timestamp - last_timestamp > (TURN_TIMEOUT as u128), "Opponent did not abandon");

        let status = if (my_last_action.turn % 2 == 0) { STATUS_WON_BY_HOST } else { STATUS_WON_BY_GUEST };

        // Call public function to mark abandonment
        Battleships::at(self.context.this_address())
            .on_finished(game_id, status)
            .enqueue(self.context);
    }
}

mod test;
