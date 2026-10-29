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
| `MAILER_FROM` | `Chain Ops <team@mcritchie.studio>` (also when blank) | Sender for `ApplicationMailer` mail. Every app sends from team@mcritchie.studio; a client's own sending domain is a tier upgrade. No transport is wired yet, so nothing is sent |

## Asset Pipeline

Chain Ops serves assets through **Propshaft** (moved off Sprockets 2026-10-25,
task `chain-ops-moves-to-propshaft`, after rolio's recipe). Every file under
`app/assets/*` is served raw at a fingerprinted `/assets/<name>-<digest>.<ext>`
URL. There is no `manifest.js` and no `*= require` directive: link a new
stylesheet from `app/views/layouts/application.html.erb`.

- Precompile: `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile`.
  Clean up with `git clean -fdX public/assets` (nothing under it is tracked). While a
  `public/assets/.manifest.json` sits there, development serves the precompiled copies,
  not your edits.
- Guards: `test/lib/asset_pipeline_test.rb` (Sprockets gem, manifest, directives or
  Sprockets-only `config.assets.*` coming back) and `test/integration/asset_urls_test.rb`
  (every `/assets` URL on the layout's pages, and every importmap pin, resolves
  fingerprinted with a 200).

## Safety

- Localnet is disposable and app-local.
- QA should use a persistent devnet program and `SOLANA_REALM=qa`.
- Production should use mainnet and `SOLANA_REALM=production`.
- Do not point this app at mainnet as part of localnet work.
