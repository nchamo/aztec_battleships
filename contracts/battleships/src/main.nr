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
        ShipPlacement, GameId, Shot, BoardNote, Turn, GameStatus,
        PlayedTurnNote, Coordinate,
        BOARD_SIZE, TOTAL_SHIP_CELLS, TURN_TIMEOUT,
        STATUS_CREATED, STATUS_ACTIVE, STATUS_WON_BY_HOST, STATUS_WON_BY_GUEST
    };
    use uint_note::uint_note::UintNote;
    use address_note::address_note::AddressNote;    

    /*
    The battleships workflow is quite simple:
    First, a host will provide their ship placement and create a game with an id. We'll consider this to be turn 0.
    Then, a guest will join said game with the id, also providing their own ship placement. When they join, they will also indicate their first shot. This 
    means that in all games, the guest starts. We'll consider this first guest shot as turn 1
    From then on, each player will take turns by shooting the other. Since the board is private to each player, when the host performs a shot, we'll check
    the guests previous shot (and viceversa).
    When a player has been hit 17 times, we'll know that the opponent has won
    At the same time, a player will be able to claim abandonment if the other player hasn't made a move in 24hs
    */

    #[storage]
    struct Storage<Context> {
        // PUBLIC
        // We'll store the status (created, active, finished) for each game
        public_game_status: Map<GameId, PublicMutable<GameStatus, Context>, Context>,
        // We'll store each game host's address so that guests can communicate with them privately
        // Note: we'll make this immutable so that we can read it privately
        public_game_hosts: Map<GameId, PublicImmutable<AztecAddress, Context>, Context>,

        // PRIVATE
        // Each player will store their own board
        private_board: Map<GameId, Owned<PrivateImmutable<BoardNote, Context>, Context>, Context>,
        // We'll store each player's opponent so that we can send notes between them
        private_opponent: Map<GameId, Owned<PrivateImmutable<AddressNote, Context>, Context>, Context>,
        // Each player will store their own turn (shot, timestamp), and then they will send the note to their opponent. By doing so, 
        // each player will learn the other's shot
        private_turns: Map<GameId, Map<Turn, Owned<PrivateImmutable<PlayedTurnNote, Context>, Context>, Context>, Context>,
        // Each player will remember their own shots, to avoid shooting the same coordinate twice 
        // This would be game_id => x => y => cell
        private_my_shots: Map<GameId, Map<Coordinate, Map<Coordinate, Owned<SingleUseClaim<Context>, Context>, Context>, Context>, Context>,
        // We will remember how many times each player was hit. When they reach 17, we'll know they have lost
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
        let host = self.msg_sender().unwrap();

        // Initialize my counter
        self.storage.private_hit_counter
            .at(game_id)
            .at(host)
            .initialize(UintNote { value: 0 })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Validate ships, build and store board
        let board = crate::utils::validate_and_build_board(ships);
        self.storage.private_board
            .at(game_id)
            .at(host)
            .initialize(BoardNote { board })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Call public function to mark game status as created
        Battleships::at(self.address)
            ._on_game_created(game_id, host)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn _on_game_created(game_id: GameId, host: AztecAddress) {
        // Initialize game state
        // Note: would fail if the game id was already used and host was already set
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
        crate::utils::validate_shot(initial_shot);

        let guest = self.msg_sender().unwrap();
        let host = self.storage.public_game_hosts
            .at(game_id)
            .read();

        // Initialize counter
        self.storage.private_hit_counter
            .at(game_id)
            .at(guest)
            .initialize(UintNote { value: 0 })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Validate ships, build and store board
        let board = crate::utils::validate_and_build_board(ships);
        self.storage.private_board
            .at(game_id)
            .at(guest)
            .initialize(BoardNote { board })
            .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);

        // Store opponent address for myself
        // Note: we could avoid this and simply read the public host variable, but we are storing it so that
        //       both host and guest can be used the same
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

        self.internal.apply_my_shot(game_id, host, initial_shot, 1);

        // Enqueue public function to start game        
        Battleships::at(self.address)
            ._on_game_joined(game_id)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn _on_game_joined(game_id: GameId) {
        let game_status = self.storage.public_game_status
            .at(game_id)
            .read();

        assert(game_status == STATUS_CREATED, "Game not in created state");

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
        crate::utils::validate_shot(shot);

        let player = self.msg_sender().unwrap();
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

        let did_i_lose = self.internal.verify_opponents_shot(game_id, opponents_turn.shot);

        if did_i_lose {
            let status = if turn % 2 == 0 { STATUS_WON_BY_GUEST } else { STATUS_WON_BY_HOST };
            Battleships::at(self.address)
                ._on_finished(game_id, status)
                .enqueue(self.context);
        } else {
            self.internal.apply_my_shot(game_id, opponent, shot, turn);

            // Note: this leaks privacy. Other will know this transaction is for battleship playing
            Battleships::at(self.address)
                ._on_shoot(game_id)
                .enqueue(self.context);
        }
    }
    

    #[external("public")]
    #[only_self]
    fn _on_shoot(game_id: GameId) {
        let game_status = self.storage.public_game_status
            .at(game_id)
            .read();

        assert(game_status == STATUS_ACTIVE, "Game not active");
    }

    #[external("public")]
    #[only_self]
    fn _on_finished(game_id: GameId, end_status: GameStatus) {
        let game_status = self.storage.public_game_status
            .at(game_id)
            .read();

        assert(game_status == STATUS_ACTIVE, "Game not active");
        
        self.storage.public_game_status
            .at(game_id)
            .write(end_status);
    }

    #[internal("private")]
    fn verify_opponents_shot(game_id: GameId, opponent_shot: Shot) -> bool {
        let player = self.msg_sender().unwrap();

        // Check if opponent hit any of my ships
        let my_board = self.storage.private_board
            .at(game_id)
            .at(player)
            .get_note()
            .board;
        let idx = opponent_shot.y * BOARD_SIZE + opponent_shot.x;
        let is_hit = my_board[idx as u32];

        let lost = &mut false; 
        if is_hit {
            // Read & update counter
            self.storage.private_hit_counter
                .at(game_id)
                .at(player)
                .replace(|current| {
                    *lost = current.value == (TOTAL_SHIP_CELLS as u128) - 1;
                    
                    UintNote { value: current.value + 1 }                    
                })
                .deliver(MessageDelivery.CONSTRAINED_ONCHAIN);
        }

        *lost
    }    

    #[internal("private")]
    fn apply_my_shot(
        game_id: GameId,
        opponent: AztecAddress,
        shot: Shot,
        turn: u32
    ) {
        let player = self.msg_sender().unwrap();
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
        
        // We are setting the include_by_timestamp property to force players to choose anchors close to the present.
        // If we didn't do this, then a player might wait up until their timeout is almost completed, and then
        // select an anchor block that is way in the past. By doing this, they would be able to force their opponent
        // to react quickly and play their turn or then they might loose to abandonment
        let one_hour = 60 * 60;
        self.context.set_include_by_timestamp(timestamp + one_hour);

        // Emit nullifier so that I can later prove that this turn has been played
        let nullifier = self.internal.build_nullifier(game_id, turn);
        self.context.push_nullifier(nullifier);
    }
   
    // ============================================================================
    // CLAIM ABANDONMENT
    // ============================================================================
    #[external("private")]
    fn claim_abandonment(game_id: GameId, current_turn: Turn) {
        let player = self.msg_sender().unwrap();
        let block_header = self.context.get_anchor_block_header();
        let current_timestamp = block_header.global_variables.timestamp;

        // Read my own last turn to get timestamp
        // Note: will fail if I haven't played that turn
        let my_last_turn = self.storage.private_turns
            .at(game_id)
            .at(current_turn - 1)
            .at(player)
            .get_note();

       // Make sure enough time has passed
        let last_timestamp = my_last_turn.timestamp;
        assert(current_timestamp - last_timestamp > TURN_TIMEOUT, "Opponent still has time to play");

        // Make sure opponent hasnt played by emitting the turn's nullifier
        let nullifier = self.internal.build_nullifier(game_id, current_turn);
        self.context.push_nullifier(nullifier);

        // Call public function to mark abandonment
        let status = if current_turn % 2 == 0 { STATUS_WON_BY_GUEST } else { STATUS_WON_BY_HOST };
        Battleships::at(self.address)
            ._on_finished(game_id, status)
            .enqueue(self.context);
    }


    #[internal("private")]
    fn build_nullifier(game_id: GameId, turn: Turn) -> Field {
        // Note: this leaks privacy. We should introduce a shared secret or randomness between players so that third parties 
        //       can't check which turns have been played
        poseidon2_hash_with_separator(
            [game_id.to_field(), turn as Field],
            1,
        )
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================
    #[external("utility")]
    unconstrained fn get_game_status(game_id: GameId) -> GameStatus {
        self.storage.public_game_status
            .at(game_id)
            .read()
    }
}

mod test;
