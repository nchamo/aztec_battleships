# Battleships Smart Contract - Aztec.nr Implementation Guide

## Overview

This is a fully-private battleships game implemented in Noir for Aztec. The current version includes all game logic and validates correctly. To add full Aztec privacy features, follow this guide.

## Current Status

✅ **Completed:**
- Ship data structures and validation
- Hit detection logic
- Game flow functions (create, join, place ships, shoot, verify, claim victory)
- All game logic compiles and works correctly

🚧 **To Add (Aztec Features):**
- Private storage using `PrivateMutable<>` and `Map<>`
- Public storage using `PublicMutable<>` and `Map<>`
- Note-based messaging between players
- Aztec function attributes (`#[aztec(private)]`, `#[aztec(public)]`)

---

## Architecture

### Game Flow

1. **Player A creates game**: `createGame(game_id)` - game_id is just a number (1, 2, 3...)
2. **Player B joins**: `joinGame(game_id)` - anyone can join using the game_id
3. **Both place ships**: `placeShips(game_id, ships...)` - ships stored privately
4. **Take turns shooting**:
   - Player A: `shoot(game_id, opponent, x, y)` → sends note to B
   - Player B: `verifyShot(game_id, shooter, x, y)` → checks hit/miss, sends result note back
   - Player A: `processResult(game_id, x, y, is_hit)` → updates tracking board
5. **Victory**: `claimVictory(game_id)` when 17 hits achieved

---

## Adding Aztec Privacy Features

### Step 1: Add Aztec Dependencies

Update `Nargo.toml` (when compatible version is available):
```toml
[dependencies]
aztec = { git="https://github.com/AztecProtocol/aztec-packages/", tag="<compatible-tag>", directory="noir-projects/aztec-nr/aztec" }
```

### Step 2: Define Storage

Add to contract:

```noir
use dep::aztec::prelude::{AztecAddress, Map, PrivateMutable, PublicMutable};

#[aztec(storage)]
struct Storage {
    // Public storage - visible to everyone
    games: Map<Field, PublicMutable<PublicGameState>>,

    // Private storage - per player, encrypted
    my_games: Map<Field, PrivateMutable<ShipPlacement>>,
    my_boards: Map<Field, PrivateMutable<BoardState>>,
}
```

### Step 3: Define Notes for Messaging

Create custom notes for inter-player communication:

```noir
// Shot message note - sent from shooter to target
struct ShotMessageNote {
    game_id: Field,
    from: AztecAddress,
    to: AztecAddress,
    x: u8,
    y: u8,
    header: NoteHeader,
}

// Result message note - sent from verifier back to shooter
struct ResultMessageNote {
    game_id: Field,
    from: AztecAddress,
    to: AztecAddress,
    x: u8,
    y: u8,
    is_hit: bool,
    header: NoteHeader,
}
```

Implement `NoteInterface` trait for both notes.

### Step 4: Update Functions with Aztec Attributes

#### Create Game (Public)

```noir
#[aztec(public)]
fn create_game(game_id: Field) {
    let sender = context.msg_sender();
    let timestamp = context.timestamp();

    let game_state = PublicGameState::new(sender, AztecAddress::zero(), sender, timestamp);
    storage.games.at(game_id).write(game_state);
}
```

#### Join Game (Public)

```noir
#[aztec(public)]
fn join_game(game_id: Field) {
    let sender = context.msg_sender();
    let mut game_state = storage.games.at(game_id).read();

    assert(game_state.status == STATUS_CREATED, "Game not available");
    assert(game_state.challenger.is_zero(), "Game already has challenger");

    game_state.challenger = sender;
    storage.games.at(game_id).write(game_state);
}
```

#### Place Ships (Private → Public)

```noir
#[aztec(private)]
fn place_ships(game_id: Field, ships: ShipPlacement) {
    // Validate ships
    validate_ships(ships);

    // Store in private storage
    storage.my_games.at(game_id).write(ships);
    storage.my_boards.at(game_id).write(BoardState::new());

    // Calculate commitment
    let commitment = compute_ships_commitment(ships);

    // Enqueue public function to update status
    context.call_public_function(
        context.this_address(),
        FunctionSelector::from_signature("_place_ships_public(Field,Field)"),
        [game_id, commitment]
    );
}

#[aztec(public)]
#[aztec(internal)]
fn _place_ships_public(game_id: Field, commitment: Field) {
    let sender = context.msg_sender();
    let mut game_state = storage.games.at(game_id).read();

    // Update status based on who placed
    if sender == game_state.host {
        game_state.status = STATUS_HOST_PLACED;
    } else if sender == game_state.challenger && game_state.status == STATUS_HOST_PLACED {
        game_state.status = STATUS_ACTIVE;
        game_state.whose_turn = game_state.host;
    }

    game_state.last_action_timestamp = context.timestamp();
    storage.games.at(game_id).write(game_state);
}
```

#### Shoot (Private → Public with Note)

```noir
#[aztec(private)]
fn shoot(game_id: Field, opponent: AztecAddress, x: u8, y: u8) {
    // Validate coordinates
    assert(x < BOARD_SIZE && y < BOARD_SIZE, "Out of bounds");

    // Load and update tracking board
    let mut board = storage.my_boards.at(game_id).read();
    let position = (y as u32) * (BOARD_SIZE as u32) + (x as u32);
    assert(!board.shots_made[position], "Already shot here");

    board.shots_made[position] = true;
    storage.my_boards.at(game_id).write(board);

    // Send shot note to opponent
    let shot_note = ShotMessageNote {
        game_id,
        from: context.msg_sender(),
        to: opponent,
        x,
        y,
        header: NoteHeader::empty(),
    };

    // Use Aztec's note system to send to opponent
    // The note will be encrypted and only opponent can decrypt it
    storage.shot_messages.at(opponent).insert(&mut shot_note).emit(
        encode_and_encrypt_note(&mut context, opponent, context.msg_sender())
    );

    // Update public turn state
    context.call_public_function(
        context.this_address(),
        FunctionSelector::from_signature("_shoot_public(Field,AztecAddress)"),
        [game_id, opponent.to_field()]
    );
}

#[aztec(public)]
#[aztec(internal)]
fn _shoot_public(game_id: Field, opponent: AztecAddress) {
    let sender = context.msg_sender();
    let mut game_state = storage.games.at(game_id).read();

    assert(game_state.whose_turn == sender, "Not your turn");
    assert(game_state.status == STATUS_ACTIVE, "Game not active");

    game_state.whose_turn = opponent;
    game_state.current_turn += 1;
    game_state.last_action_timestamp = context.timestamp();

    storage.games.at(game_id).write(game_state);
}
```

#### Verify Shot (Private - reads note, sends result note)

```noir
#[aztec(private)]
fn verify_shot(game_id: Field, shot_note_hash: Field) {
    // Get the shot note that was sent to me
    let shot_note = storage.shot_messages.at(context.msg_sender()).get_note(shot_note_hash);

    // Verify it's for this game
    assert(shot_note.game_id == game_id, "Wrong game");

    // Load my ships from private storage
    let ships = storage.my_games.at(game_id).read();

    // Check if hit
    let is_hit = check_hit(shot_note.x, shot_note.y, ships);

    // Update my board
    let mut board = storage.my_boards.at(game_id).read();
    let position = (shot_note.y as u32) * (BOARD_SIZE as u32) + (shot_note.x as u32);

    if is_hit {
        board.hits_received[position] = true;
        board.total_hits_received += 1;
    }

    storage.my_boards.at(game_id).write(board);

    // Send result note back to shooter
    let result_note = ResultMessageNote {
        game_id,
        from: context.msg_sender(),
        to: shot_note.from,
        x: shot_note.x,
        y: shot_note.y,
        is_hit,
        header: NoteHeader::empty(),
    };

    storage.result_messages.at(shot_note.from).insert(&mut result_note).emit(
        encode_and_encrypt_note(&mut context, shot_note.from, context.msg_sender())
    );

    // Nullify the consumed shot note
    storage.shot_messages.at(context.msg_sender()).remove(shot_note);
}
```

#### Process Result (Private - reads result note)

```noir
#[aztec(private)]
fn process_result(game_id: Field, result_note_hash: Field) {
    // Get the result note sent to me
    let result_note = storage.result_messages.at(context.msg_sender()).get_note(result_note_hash);

    // Verify it's for this game
    assert(result_note.game_id == game_id, "Wrong game");

    // Update tracking board
    let mut board = storage.my_boards.at(game_id).read();
    let position = (result_note.y as u32) * (BOARD_SIZE as u32) + (result_note.x as u32);

    if result_note.is_hit {
        board.shot_results[position] = true;
        board.total_hits_dealt += 1;
    }

    storage.my_boards.at(game_id).write(board);

    // Nullify the consumed result note
    storage.result_messages.at(context.msg_sender()).remove(result_note);
}
```

#### Claim Victory (Private → Public)

```noir
#[aztec(private)]
fn claim_victory(game_id: Field) {
    // Check private board state
    let board = storage.my_boards.at(game_id).read();
    assert(board.total_hits_dealt >= TOTAL_SHIP_CELLS, "Not all ships sunk");

    // Enqueue public function
    context.call_public_function(
        context.this_address(),
        FunctionSelector::from_signature("_claim_victory_public(Field)"),
        [game_id]
    );
}

#[aztec(public)]
#[aztec(internal)]
fn _claim_victory_public(game_id: Field) {
    let sender = context.msg_sender();
    let mut game_state = storage.games.at(game_id).read();

    assert(game_state.status == STATUS_ACTIVE, "Game not active");

    game_state.status = STATUS_COMPLETED;
    game_state.winner = sender;
    game_state.win_type = WIN_VICTORY;

    storage.games.at(game_id).write(game_state);
}
```

---

## Key Concepts

### 1. Automatic Proof Generation

You don't need to manually create proofs. When you mark a function as `#[aztec(private)]`, Aztec automatically:
- Executes the function client-side
- Generates a zero-knowledge proof of correct execution
- Submits the proof to the network

### 2. Note-Based Messaging

Instead of events, use Aztec's note system:
- Create a note with recipient's address
- Use `storage.notes.at(recipient).insert(&mut note)`
- Encrypt with `encode_and_encrypt_note()`
- Recipient queries their notes and decrypts
- Consume notes with `.remove(note)` after reading

### 3. Private → Public Pattern

Private functions can enqueue public functions:
```noir
context.call_public_function(
    context.this_address(),
    FunctionSelector::from_signature("function_name(types)"),
    [args]
);
```

This allows:
- Private computation with proof
- Public state updates
- Coordination between players

### 4. Storage Access

- **Private storage**: `storage.my_games.at(game_id).read()` / `.write(value)`
- **Public storage**: Same API, but data is visible to all
- **Notes**: Use `.insert()`, `.get_note()`, `.remove()` methods

---

## Privacy Guarantees

With full Aztec implementation:

### Private (Encrypted):
- Ship positions - nobody knows where your ships are
- Shot coordinates - only you and opponent know where shots were fired
- Hit/miss results - only you and opponent know results
- Board state - only you see your own board and tracking board

### Public (Visible to All):
- Game exists between two addresses
- Current turn number
- Whose turn it is
- Game status (created, active, completed)
- Winner (after game ends)
- Timestamps (for abandonment claims)

---

## Testing

Once Aztec features are added, test with:

```bash
# Compile
nargo compile

# Run tests (create tests in tests/ directory)
nargo test

# Deploy to Aztec devnet
aztec-cli deploy

# Interact with contract
aztec-cli send create_game --args 1
aztec-cli send join_game --args 1
```

---

## Next Steps

1. Wait for compatible Aztec.nr version or use Aztec sandbox
2. Add storage declarations
3. Implement custom notes (ShotMessageNote, ResultMessageNote)
4. Update functions with Aztec attributes
5. Test game flow end-to-end
6. Deploy to Aztec testnet

The current implementation provides all the core logic. Adding Aztec features is primarily about:
- Adding storage declarations
- Adding function attributes (`#[aztec(private)]`, `#[aztec(public)]`)
- Using notes for messaging instead of passing data as parameters
- Using `context` for addresses and timestamps
