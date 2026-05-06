# Aragon OSx Condition Library artifacts

This package contains the ABI definitions of the OSx Condition Library contracts, as well as the address of the `ConditionFactory` deployed on each network.

Install it with:

```sh
bun add @aragon/condition-library-artifacts
# or: pnpm add @aragon/condition-library-artifacts
```

## Usage

```typescript
// ABI definitions
import {
    ConditionFactoryABI,
    ExecuteSelectorConditionABI,
    SelectorConditionABI,
    SafeOwnerConditionABI,
    IOwnerManagerABI
} from "@aragon/condition-library-artifacts";

console.log("ConditionFactory ABI", ConditionFactoryABI);

// Factory addresses per-network
import { addresses } from "@aragon/condition-library-artifacts";

console.log(addresses.conditionFactory.mainnet);
```

You can also open [addresses.json](./src/addresses.json) directly.

## Development

This package is built with [`just`](https://github.com/casey/just) and [`bun`](https://bun.sh).

### Refresh ABIs

```sh
just abi   # regenerate src/abi.ts from forge build artifacts at the repo root
```

`src/abi.ts` is populated by `bash prepare-abi.sh`, which runs `forge build` at the repo root and emits one `export const <Contract>ABI = [...] as const` per `src/` contract with a non-empty ABI. Bytecode is not emitted — use the ABI const + the address from `addresses.json` directly.

### Address curation

`src/addresses.json` is **hand-curated**. This package is the source of truth for `ConditionFactory` addresses across networks. Only the factory is published — condition instances (`ExecuteSelectorCondition`, `SelectorCondition`, `SafeOwnerCondition`) are deployed per-use-case via the factory and are not aggregated here.

To add a chain or update an address, edit the JSON directly in your PR and document the rationale in the commit/PR message.

### Build for publishing

```sh
just build   # regenerates abi.ts, installs deps, compiles TS to dist/
```

## Releasing

Releases are PR-driven. Tag creation and NPM publishing are handled exclusively by CI — there is no manual release flow.

1. Open a PR that bumps `version` in [`package.json`](./package.json).
2. (If contracts changed) update [`CHANGELOG.md`](./CHANGELOG.md) in the same PR.
3. After review and merge to `main`, [`.github/workflows/release.yml`](../.github/workflows/release.yml) detects the new version, creates the `vX.Y.Z` tag, and runs `bun publish`.

If the merged version already has a tag (e.g. unrelated edit to `package.json`), the workflow exits cleanly without releasing.
