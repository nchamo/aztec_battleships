// Full Aztec.nr implementation of Battleships
use dep::aztec::macros::aztec;

mod types;
mod utils;

#[aztec]
contract Battleships {
    use aztec::{
        macros::{functions::external, storage::storage},
        protocol_types::{address::AztecAddress, traits::ToField},
        state_vars::{Map, PrivateMutable, PublicMutable, Owned, PrivateImmutable},
    };

    use crate::types::{
        ShipData, ShipPlacement, GameState, GameId, Coordinate,
        BOARD_SIZE, TOTAL_SHIP_CELLS, SETUP_TIMEOUT, TURN_TIMEOUT,
        STATUS_CREATED, STATUS_ACTIVE, STATUS_COMPLETED,
        WIN_VICTORY, WIN_ABANDONMENT
    };
    use crate::utils::{validate_ships, check_hit};

    struct PrivateGameState {
        role: host | guest
        my_ships: ShipPlacement,
        opponent: AztecAddress,
        last_action_timestamp: Timestamp,
        hit_counter: u8;
        last_opponent_shot: Shot
    }

    #[storage]
    struct Storage<Context> {
        // Public storage - game coordination
        public_games: Map<GameId, PublicMutable<GameState, Context>, Context>,

        // Private storage
        private_my_ships: Map<GameId, Owned<PrivateImmutable<ShipPlacement, Context>, Context>, Context>,
        private_game: Map<GameId, Owned<PrivateGameState, Context>, Context>,
        // X, Y => 0 = not shot, 1 = miss, 2 = hit, 3 = pending verification
        private_my_shots: Map<GameId, Map<Coordinate, Map<Coordinate, Owned<PrivateMutable<ShotStatus>, Context>, Context>, Context>,
    }

    // ============================================================================
    // GAME CREATION & JOINING
    // ============================================================================

    #[external("private")]
    fn create_game(
        game_id: GameId,
        ships: ShipPlacement
    ) {

        // Validate ships
        validate_placement(ships);

        // TODO: Set private storage (role and ships)
        self.storage.private_my_ships.at(game_id).write(ships);

        // Call public function to update game status
        Battleships::at(self.context.this_address())
            .on_game_created(game_id)
            .enqueue(self.context);
    }

    #[external("public")]
    #[only_self]
    fn on_game_created(game: GameId) {
        let sender = self.msg_sender().unwrap();

        // Initialize game state
        let game_state = GameState::new(
            sender.to_field(),
            0  // No guest yet
        );

        self.storage.public_games.at(game_id).write(game_state);
    }

    #[external("private")]
    fn join_game(
        game_id: GameId, 
        opponent: AztecAddress, 
        ships: ShipPlacement, 
        initial_shot: Shot
    ) {
        // TODO: validate ships
        // TODO: validate shot

        // TODO: Set my private storage (role (guest), ships, opponent and last_action_timestamp)
        // TODO: Remember by shot
        // TODO: Update's my opponent's storage (set myself as opponent and update last_opponent_shot)
        // TODO: Call on_game_joined
    }

    #[external("public")]
    #[only_self]
    fn on_game_joined(game: GameId, opponent: AztecAddress) {
        // TODO: validate opponent == host
        // TODO: validate status == created
        // TODO: Update public data(status: created => active, turn++)
    }

    // ============================================================================
    // SHOOTING
    // ============================================================================

   

    #[external("private")]
    fn shoot(
        game_id: GameId, 
        shot: Shot
    ) {

        // TODO: validate new shot

        verify_opponents_shot(game_id);
        
        apply_shot(game_id: shot)


   
    }

    #[external("private")]
    fn verify_opponents_shot(
        game_id: GameId, 
    ) {
        // TODO: read last shot
        // TODO: check if anything was hit
        // TODO: if anything was hit, then we should check counter. If all ships where hit, then game is over. If thats not che case, then simply increase counter
        // TODO: update public status accordingly

    }

    #[internal("private")]
    fn apply_shot(
        game_id: GameId, 
        shot: Shot,
    ) {
        // TODO: Update last_action_timestamp
        // TODO: Remember by shot
        // TODO: Update's my opponent's storage (update last_opponent_shot)

    }

    #[external("public")]
    #[only_self]
    fn on_shoot(game: GameId, shot: Shot) {
        // TODO: it was callers turn
        // TODO: validate status == active
        // TODO: Update public data(turn++)
    }

    #[external("public")]
    #[only_self]
    fn on_won(game: GameId) {
        // TODO: validate status == active
        // TODO: Update public data(status = won)
    }

    // ============================================================================
    // CLAIM ABANDONMENT
    // ============================================================================

    #[external("private")]
    fn claim_abandonment(game_id: Field) {
       
    }

    
}
