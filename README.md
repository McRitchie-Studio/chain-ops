# Chain Ops

Chain Ops is the McRitchie control plane for Solana developer operations.

The first utility manages a local `solana-test-validator` so Turf Monster and
future on-chain apps can run against a disposable localnet without touching QA or
production contracts.

Agent sessions should start with `/Users/alex/projects/AGENTS.md`, then use this
README for Chain Ops-specific context.

## Current Scope

- Local Rails dashboard at `http://localhost:3300`
- Start, stop, reset, and inspect one local Solana validator
- App-owned local ledger under `tmp/solana-ledger`
- PID tracking under `tmp/pids/solana-test-validator.pid`
- Validator logs under `log/localnet.log`
- Turf Monster localnet env snippet for `SOLANA_NETWORK=localnet`

This app does not yet manage QA devnet programs, IDL hashes, wallet funding, or
production Solana nodes. Those are future Chain Ops tracks.

## Run It

```bash
cd /Users/alex/projects/chain-ops
bundle install
bin/rails db:prepare
bin/rails server
```

Open:

```text
http://localhost:3300
```

## Localnet CLI

The browser and CLI use the same service:

```bash
bin/localnet status
bin/localnet start
bin/localnet stop
bin/localnet reset
```

`reset` stops the validator, deletes `tmp/solana-ledger`, and starts a fresh
validator.

## Turf Monster Localnet Env

When Chain Ops localnet is running, use:

```env
SOLANA_NETWORK=localnet
SOLANA_RPC_URL=http://127.0.0.1:8899
SOLANA_REALM=local
ANCHOR_PROVIDER_URL=http://127.0.0.1:8899
ANCHOR_WALLET=~/.config/solana/id.json
SOLANA_PROGRAM_ID=<local deployed turf-vault program id>
```

DB reseeds are cheap and frequent. Local contract deploys are separate release
actions and should update `SOLANA_PROGRAM_ID` deliberately.

## Configuration

Optional environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CHAIN_OPS_LOCALNET_RPC_PORT` | `8899` | Local validator RPC port |
| `CHAIN_OPS_LOCALNET_FAUCET_PORT` | `9900` | Local validator faucet port |
| `CHAIN_OPS_LOCALNET_BIND_ADDRESS` | `127.0.0.1` | Local validator bind address |
| `CHAIN_OPS_LOCALNET_RPC_URL` | derived | URL shown to apps |
| `CHAIN_OPS_LOCALNET_LEDGER` | `tmp/solana-ledger` | Local validator ledger path |
| `SOLANA_REALM` | `local` | On-chain namespace/realm |

## Safety

- Localnet is disposable and app-local.
- QA should use a persistent devnet program and `SOLANA_REALM=qa`.
- Production should use mainnet and `SOLANA_REALM=production`.
- Do not point this app at mainnet as part of localnet work.
