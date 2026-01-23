# Battleships - Zero-Knowledge Game on Aztec

A fully-private implementation of Battleships using Aztec.nr and Noir.

## Features

✅ **Complete Game Logic**
- Ship placement validation (5 ships: carrier, battleship, cruiser, submarine, destroyer)
- Hit detection
- Victory conditions (sink all 17 enemy ship cells)
- Abandonment timeout mechanism

✅ **Privacy-First Design**
- Ship positions stay private (encrypted)
- Shot coordinates private (only players know)
- Results private (hit/miss known only to players)
- Zero-knowledge proofs ensure honesty without revealing secrets

✅ **Fair & Trustless**
- No central authority needed
- Cryptographic validation prevents cheating
- Time-based abandonment protection
- Multi-game support (unlimited concurrent games)

## Game Flow

1. **Create Game**: Player A creates game with ID (e.g., `createGame(1)`)
2. **Join Game**: Player B joins using same ID (`joinGame(1)`)
3. **Place Ships**: Both players place their 5 ships privately
4. **Battle**:
   - Take turns shooting at coordinates
   - Opponent verifies hit/miss privately
   - Results sent back via encrypted notes
5. **Victory**: First to sink all 17 opponent cells wins
6. **Abandonment**: Claim victory if opponent inactive >24 hours

## Project Structure

```
battleships/
├── src/
│   ├── main.nr          # Main contract with game functions
│   ├── types.nr         # Data structures and constants
│   ├── utils.nr         # Ship validation and hit detection
│   └── test/            # Test suite
│       ├── helpers.nr   # Test helper functions
│       ├── types_test.nr        # Unit tests for types
│       ├── utils_test.nr        # Unit tests for utils
│       └── integration/ # Integration tests
│           ├── success/         # Successful game scenarios (5 tests)
│           └── failures/        # Error & validation tests (13 tests)
├── Nargo.toml           # Noir project configuration
├── README.md            # This file
```

## Installation

### Prerequisites
- Aztec development environment

### Setup
1. Install Aztec CLI (if not already installed):
```bash
bash -i <(curl -s https://install.aztec.network)
```

2. Run `aztec-up` to install/update Aztec binaries:
```bash
# Currently we use 4.0.0-nightly.20260122 version, make sure you have the right one
aztec-up 4.0.0-nightly.20260122
```

3. Clone this repository:
```bash
git clone <repository-url>
cd battleships
```

## Building & Testing

### Compile the Contract
```bash
aztec compile
```

This generates the contract ABI and bytecode in the `target/` directory.

### Run All Tests
```bash
aztec test
```

### Run Specific Test
```bash
aztec test test_name
```
## Ship Configuration

Standard battleships:
- Carrier: 5 cells
- Battleship: 4 cells
- Cruiser: 3 cells
- Submarine: 3 cells
- Destroyer: 2 cells
- **Total: 17 cells** (victory condition)

Board: 10×10 grid (coordinates 0-9)

## License

MIT
