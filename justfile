default: help
import 'lib/just-foundry/justfile'

# Override: this project's deploy entrypoint is `Deploy` (not `DeployScript`)
DEPLOY_SCRIPT := "script/Deploy.s.sol:Deploy"

CREATE_SCRIPT := "script/Create.s.sol:Create"

# Dry-run the create script (no broadcast)
[group('script')]
precreate:
    just dry-run {{ CREATE_SCRIPT }}

# Run Create.s.sol: tests then broadcast (logs to logs/Create-<network>-<timestamp>.log)
[group('script')]
create *args:
    just test
    just run {{ CREATE_SCRIPT }} {{ args }}
