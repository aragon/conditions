# OSx Condition Library

This reposity contains a library of OSx conditions, meant to be used by any DAO wishing to guard contract functions by using common permission patterns.

## Audit

### September 2025

**Halborn**: [Safe owner condition](./audits/halborn-safe-owner.pdf)

- Commit ID: [12bfb3b3](https://github.com/aragon/conditions/commit/12bfb3b3b60f91b99322248f6946090ab747b4b9)

### July 2025

**Halborn**: [audit report](./audits/halborn-audit.pdf)

- Commit ID: [df9320ab](https://github.com/aragon/conditions/commit/df9320ab843a5e4e41c4d7476c22d01b54ca4504)
- Started: July 15th, 2025
- Finished: July 15th, 2025

## Overview

- Execute Selector Condition: only allows a predefined set of function selectors to be invoked via `execute()`
- Selector Condition: only allows a predefined set of function selectors to be invoked directly
- Safe Owner condition: restricts the permission to only be available to the owners of a given Safe

[Learn more about Aragon OSx](#osx-protocol-overview).

## Get Started

See the deployments available on each network on [DEPLOYMENTS.md](./DEPLOYMENTS.md)

## Build

Requirements: [Foundry](https://getfoundry.sh/) and [just](https://github.com/casey/just).

The project uses [just-foundry](https://github.com/aragon/just-foundry), a thin task runner that resolves per-network config (RPC, chain ID, verifier, etc.) automatically. Initialize the submodules and pick a network:

```sh
git submodule update --init --recursive
just init sepolia
cp .env.example .env   # then fill in DEPLOYER_KEY, ETHERSCAN_API_KEY, …
```

Run `just` (or `just help`) to list available recipes:

```
[setup]
init network="mainnet"     Initialize for a given network
switch network override="" Select active network (pass "override" to fork the config locally)
setup                      Install Foundry

[script]
predeploy                  Simulate a factory deployment
deploy *args               Run tests, deploy the factory, verify, log
precreate                  Simulate Create.s.sol
create *args               Run tests, instantiate conditions via Create.s.sol, verify, log

[test]
test *args                 Run unit tests
test-fork *args            Run fork tests (requires RPC_URL)
test-coverage              HTML coverage report under ./report

[helpers]
env                        Show resolved environment + sources
balance                    Deployer wallet balance

[develop]
clean                      Clean compiler artifacts and reports
anvil                      Local fork of the active network

[verification]
verify type="" script=""   Verify all contracts from the latest broadcast
```

Hidden helpers (run directly): `gas-price`, `nonce`, `clean-nonce <n>`, `clean-nonces "n1 n2 …"`, `refund`. See [`lib/just-foundry/README.md`](./lib/just-foundry/README.md).

### Secrets

Two options:

1. Plain `.env` at the repo root (gitignored). Start from `.env.example`.
2. **Recommended**: [`vars`](https://github.com/vars-cli/vars) — an age-encrypted local store that supplies secrets to every project automatically. Install with `just install-vars`. The required keys are listed in [`.vars.yaml`](./.vars.yaml).

Network-level config (RPC URL, chain ID, verifier) lives in `lib/just-foundry/networks/<network>.env`. To customize a network locally without editing the submodule, run `just switch <network> override` and edit the resulting `.env.<network>` at the repo root.

## Deployment

```sh
just predeploy   # simulate
just deploy      # run tests, broadcast, verify, write logs/Deploy-<network>-<ts>.log

just precreate   # simulate the Create script
just create      # run Create.s.sol to instantiate conditions
```

### Deployment Checklist

- [ ] I have cloned the official repository on my computer and I have checked out the corresponding branch
- [ ] I am using the latest official docker engine, running a Debian Linux (stable) image
  - [ ] I have run `docker run --rm -it -v .:/deployment debian:trixie-slim` (Debian 13 or newer)
  - [ ] I have run `apt update && apt install -y curl git just vim neovim bc jq`
  - On **standard EVM networks**:
    - [ ] I have run `just setup` (installs Foundry)
  - On **ZkSync networks**:
    - [ ] I have run `just setup-zksync`
  - [ ] I have run `cd /deployment`
  - [ ] I have run `git submodule update --init --recursive`
  - [ ] I have run `just init <network>` (e.g. `just init sepolia`)
  - [ ] I have run `cp .env.example .env` and filled in the secrets
- [ ] I am opening an editor on the `/deployment` folder, within the Docker container
- [ ] The `.env` file contains the correct parameters for the deployment
  - [ ] I have created a brand new burner wallet with `cast wallet new` and copied the private key to `DEPLOYER_KEY` within `.env`
  - [ ] `just env` shows the expected network, verifier, and resolved secrets
- [ ] All the tests run clean (`just test`)
- [ ] My deployment wallet is a newly created account, ready for safe production deploys.
- My computer:
  - [ ] Is running in a safe location and using a trusted network
  - [ ] It exposes no services or ports
  - [ ] The wifi or wired network in use does not expose any ports to a WAN
- [ ] I have previewed my deploy without any errors
  - `just predeploy`
- [ ] The deployment wallet has sufficient native token for gas
  - At least, 15% more than the estimated simulation
- [ ] `just test` still runs clean
- [ ] I have run `git status` and it reports no local changes
- [ ] The current local git branch (`main`) corresponds to its counterpart on `origin`
  - [ ] I confirm that the rest of members of the ceremony pulled the last commit of my branch and reported the same commit hash as my output for `git log -n 1`
- [ ] I have initiated the production deployment with `just deploy`

### Post deployment checklist

- [ ] The deployment process completed with no errors
- [ ] The output of the latest `logs/Deploy-*.log` file corresponds to the console output
- [ ] I have copied the `== Logs ==` section into [DEPLOYMENTS.md](./DEPLOYMENTS.md)
- [ ] I have uploaded the log file to a remote place
- [ ] The factory contract was deployed by the deployment address
- [ ] All the project's smart contracts are correctly verified on the reference block explorer of the target network.
  -  [ ] This also includes contracts that aren't explicitly deployed (deployed on demand)
- [ ] I have transferred the remaining funds of the deployment wallet to the address that originally funded it
  - `just refund`

## OSx protocol overview

OSx [DAO's](https://github.com/aragon/osx/blob/develop/packages/contracts/src/core/dao/DAO.sol) are designed to hold all the assets and rights by themselves. On the other hand, plugins are custom opt-in pieces of logic that can implement any type of governance. They are meant to eventually make the DAO execute a certain set of actions.

The whole ecosystem is governed by the DAO's permission database, which is used to restrict actions to only the role holding the appropriate permission.

### How permissions work

An Aragon DAO is a set of permissions that are used to define who can do what, and where.

A permission looks like:

- An address `who` holds `MY_PERMISSION_ID` on a target contract `where`

Brand new DAO's are deployed with a `ROOT_PERMISSION` assigned to its creator, but the DAO will typically deployed by the DAO factory, which will install all the requested plugins and drop the ROOT permission after the set up is done.

Managing permissions is made via two functions that are called on the DAO:

```solidity
function grant(address _where, address _who, bytes32 _permissionId);

function revoke(address _where, address _who, bytes32 _permissionId);
```

### Permission Conditions

For the cases where an unrestricted permission is not derisable, a [Permission Condition](https://devs.aragon.org/osx/how-it-works/core/permissions/conditions) can be used.

Conditional permissions look like this:

- An address `who` holds `MY_PERMISSION_ID` on a target contract `where`, only `when` the condition contract approves it

Conditional permissions are granted like this:

```solidity
function grantWithCondition(
  address _where,
  address _who,
  bytes32 _permissionId,
  IPermissionCondition _condition
);
```

See the condition contract boilerplate. It provides the plumbing to easily restrict what the different multisig plugins can propose on the OptimisticVotingPlugin.

[Learn more about OSx permissions](https://devs.aragon.org/osx/how-it-works/core/permissions/#permissions)

## Testing

```sh
just test               # unit tests
just test-fork          # fork tests (requires RPC_URL)
just test-coverage      # HTML coverage report under ./report
```

Test files live in [`./test`](./test). Add new test contracts directly in Solidity.
