# Battleships - Zero-Knowledge Game on Aztec

A fully-private implementation of Battleships using Aztec.nr and Noir.

## Features

**Complete Game Logic**
- Ship placement validation (5 ships: carrier, battleship, cruiser, submarine, destroyer)
- Hit detection
- Victory conditions (sink all 17 enemy ship cells)
- Abandonment timeout mechanism

**Privacy-First Design**
- Ship positions stay private (encrypted)
- Shot coordinates private (only players know)
- Results private (hit/miss known only to players)
- Zero-knowledge proofs ensure honesty without revealing secrets

**Fair & Trustless**
- No central authority needed
- Cryptographic validation prevents cheating
- Time-based abandonment protection
- Multi-game support (unlimited concurrent games)

## Project Structure

```
battleships/
├── contracts/                # Smart contracts (Noir)
│   ├── package.json
│   ├── Nargo.toml
│   ├── vitest.config.ts
│   ├── tsconfig.json
│   ├── src/                  # Noir source
│   │   ├── main.nr
│   │   ├── types.nr
│   │   └── utils.nr
│   ├── e2e-test/             # E2E tests (TypeScript)
│   └── scripts/              # Build and deploy scripts
├── web/                      # Frontend (React + Vite)
│   ├── package.json
│   ├── vite.config.ts
│   ├── tsconfig.json
│   ├── index.html
│   ├── main.tsx
│   ├── App.tsx
│   ├── components/
│   ├── hooks/
│   ├── store/
│   ├── services/
│   ├── config/
│   └── artifacts/            # Generated TypeScript wrappers
├── package.json              # Workspace root
├── README.md
└── LICENSE
```

## Prerequisites

- Node.js >= 22.0.0
- Yarn
- Aztec development environment

## Installation

1. Install Aztec CLI:
```bash
bash -i <(curl -s https://install.aztec.network)
```

2. Install/update Aztec binaries:
```bash
# Currently we use 4.0.0-nightly.20260122 version, make sure you have the right one
aztec-up 4.0.0-nightly.20260122
```

3. Clone and install dependencies:
```bash
git clone <repository-url>
cd battleships
yarn install
```

## Contract Development

All contract commands are run from the `contracts/` directory.

### Compile Contract
```bash
yarn compile
```

### Run Noir Tests
```bash
yarn test:nr
```

### Run E2E Tests
```bash
# You'll need to run a sandbox first, more on that below
yarn test
```

### Generate TypeScript Artifacts
```bash
yarn codegen
```
This compiles the contract and generates TypeScript wrappers in `web/artifacts/`.

### Deploy to Sandbox
```bash
yarn deploy
```
Saves deployment info to `web/config/deployments/sandbox.json`.


## Web Development

All web commands are run from the `web/` directory.

### Start Dev Server
```bash
yarn dev
```
App runs at http://localhost:3000

### Build for Production
```bash
cd web
yarn build
```

### Preview Production Build
```bash
cd web
yarn serve
```

## Quick Start (Full Workflow)

```bash
# Terminal 1: Start Aztec sandbox
aztec start --local-network

# Terminal 2: Build and run
cd contracts
yarn codegen          # Compile contracts + generate TS artifacts
yarn deploy           # Deploy to sandbox

cd ../web
yarn dev              # Start dev server
```

## Root Workspace Commands

From the project root:

| Command | Description |
|---------|-------------|
| `yarn dev` | Start web dev server |
| `yarn build` | Generate artifacts + build web app |
| `yarn test` | Run contract E2E tests |
| `yarn clean` | Clean all build artifacts |

## Game Flow

1. **Create Game**: Player A creates game with a unique ID
2. **Join Game**: Player B joins using the same ID
3. **Place Ships**: Both players place their 5 ships privately
4. **Battle**: Take turns shooting, opponent verifies hit/miss privately
5. **Victory**: First to sink all 17 opponent cells wins
6. **Abandonment**: Claim victory if opponent inactive >24 hours

## Ship Configuration

| Ship | Size |
|------|------|
| Carrier | 5 cells |
| Battleship | 4 cells |
| Cruiser | 3 cells |
| Submarine | 3 cells |
| Destroyer | 2 cells |
| **Total** | **17 cells** |

Board: 10x10 grid (coordinates 0-9)

## License

MIT
