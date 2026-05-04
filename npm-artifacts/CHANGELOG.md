# Aragon OSx Condition Library artifacts

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0

Initial release of `@aragon/condition-library-artifacts`.

### Added

- ABI exports for the public surface of the Condition Library:
  - `ConditionFactoryABI` — the singleton factory used to deploy condition instances.
  - `ExecuteSelectorConditionABI` — restricts which selectors can be invoked via `execute()`.
  - `SelectorConditionABI` — restricts which selectors can be invoked directly.
  - `SafeOwnerConditionABI` — restricts a permission to the owners of a Safe.
  - `IOwnerManagerABI` — the Safe owner-manager interface consumed by `SafeOwnerCondition`.
- `addresses.conditionFactory.<network>` for the 12 networks where the factory is currently deployed: `arbitrum`, `avalanche`, `base`, `chiliz`, `corn`, `mainnet`, `optimism`, `peaq`, `polygon`, `sepolia`, `zksync`, `zksyncSepolia`.
- Build pipeline based on `just` + `bun` + `forge`. Run `just abi` to regenerate `src/abi.ts` from forge artifacts at the repo root; `just build` chains that with `tsc` to produce `dist/`.

### Notes

- Only `ConditionFactory` addresses are published. Condition instances (`ExecuteSelectorCondition`, `SelectorCondition`, `SafeOwnerCondition`) are deployed per-use-case via the factory and are not aggregated here.
- `src/addresses.json` is hand-curated. To add a chain or update an address, edit the JSON directly in your PR and document the rationale in the commit/PR message.
- Bytecode is intentionally not shipped. If you need it, build the contracts from source (this repo) — `forge build` produces it under `out/`.
