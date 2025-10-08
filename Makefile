.DEFAULT_TARGET: help

# Import the .env files and export their values
include .env

SHELL:=/bin/bash

# CONSTANTS

SOLC_VERSION := $(shell cat foundry.toml | grep solc | cut -d= -f2 | xargs echo || echo "0.8.23")
TEST_TREE_MARKDOWN=TESTS.md
MAKEFILE=Makefile
DEPLOYMENT_SCRIPT=Deploy
DEPLOY_SCRIPT:=script/$(DEPLOYMENT_SCRIPT).s.sol:$(DEPLOYMENT_SCRIPT)
CREATE_SCRIPT:=script/Create.s.sol:Create
VERIFY_CONTRACTS_SCRIPT := script/verify-contracts.sh
SUPPORTED_VERIFIERS := etherscan blockscout sourcify zksync routescan-mainnet routescan-testnet
MAKE_TEST_TREE_CMD=deno run ./test/script/make-test-tree.ts
LOGS_FOLDER := ./logs
VERBOSITY:=-vvv

TEST_COVERAGE_SRC_FILES:=$(wildcard test/*.sol test/**/*.sol src/*.sol src/**/*.sol src/libs/ProxyLib.sol)
TEST_SOURCE_FILES = $(wildcard test/*.t.yaml test/integration/*.t.yaml)
TEST_TREE_FILES = $(TEST_SOURCE_FILES:.t.yaml=.tree)
DEPLOYMENT_ADDRESS = $(shell cast wallet address --private-key $(DEPLOYMENT_PRIVATE_KEY))

# Strip the quotes
NETWORK_NAME:=$(strip $(subst ',, $(subst ",,$(NETWORK_NAME))))
CHAIN_ID:=$(strip $(subst ',, $(subst ",,$(CHAIN_ID))))
VERIFIER:=$(strip $(subst ',, $(subst ",,$(VERIFIER))))
BLOCKSCOUT_HOST_NAME:=$(strip $(subst ',, $(subst ",,$(BLOCKSCOUT_HOST_NAME))))

DEPLOYMENT_LOG_FILE=deployment-$(NETWORK_NAME)-$(shell date +"%y-%m-%d-%H-%M").log
CREATION_LOG_FILE=creation-$(NETWORK_NAME)-$(shell date +"%y-%m-%d-%H-%M").log

# Check values

ifeq ($(filter $(VERIFIER),$(SUPPORTED_VERIFIERS)),)
  $(error Unknown verifier: $(VERIFIER). It must be one of: $(SUPPORTED_VERIFIERS))
endif

# Conditional assignments

ifeq ($(VERIFIER), etherscan)
	VERIFIER_URL := https://api.etherscan.io/api
	VERIFIER_API_KEY := $(ETHERSCAN_API_KEY)
	VERIFIER_PARAMS := --verifier $(VERIFIER) --etherscan-api-key $(ETHERSCAN_API_KEY)
else ifeq ($(VERIFIER), blockscout)
	VERIFIER_URL := https://$(BLOCKSCOUT_HOST_NAME)/api\?
	VERIFIER_API_KEY := ""
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url "$(VERIFIER_URL)"
else ifeq ($(VERIFIER), sourcify)
else ifeq ($(VERIFIER), zksync)
	ifeq ($(CHAIN_ID),300)
		VERIFIER_URL := https://explorer.sepolia.era.zksync.dev/contract_verification
	else ifeq ($(CHAIN_ID),324)
	    VERIFIER_URL := https://zksync2-mainnet-explorer.zksync.io/contract_verification
	endif
	VERIFIER_API_KEY := ""
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url "$(VERIFIER_URL)"
else ifneq ($(filter $(VERIFIER), routescan-mainnet routescan-testnet),)
	ifeq ($(VERIFIER), routescan-mainnet)
		VERIFIER_URL := https://api.routescan.io/v2/network/mainnet/evm/$(CHAIN_ID)/etherscan
	else
		VERIFIER_URL := https://api.routescan.io/v2/network/testnet/evm/$(CHAIN_ID)/etherscan
	endif

	VERIFIER := custom
	VERIFIER_API_KEY := "verifyContract"
	VERIFIER_PARAMS = --verifier $(VERIFIER) --verifier-url '$(VERIFIER_URL)' --etherscan-api-key $(VERIFIER_API_KEY)
endif

# Additional chain-dependent params (Foundry)
ifeq ($(CHAIN_ID),88888)
	FORGE_SCRIPT_CUSTOM_PARAMS := --priority-gas-price 1000000000 --gas-price 5200000000000
else ifeq ($(CHAIN_ID),300)
	FORGE_SCRIPT_CUSTOM_PARAMS := --slow
	FORGE_BUILD_CUSTOM_PARAMS := --zksync
else ifeq ($(CHAIN_ID),324)
	FORGE_SCRIPT_CUSTOM_PARAMS := --slow
	FORGE_BUILD_CUSTOM_PARAMS := --zksync
endif

# TARGETS

.PHONY: help
help: ## Display the available targets
	@echo -e "Available targets:\n"
	@cat Makefile | while IFS= read -r line; do \
	   if [[ "$$line" == "##" ]]; then \
			echo "" ; \
		elif [[ "$$line" =~ ^##\ (.*)$$ ]]; then \
			printf "\n$${BASH_REMATCH[1]}\n\n" ; \
		elif [[ "$$line" =~ ^([^:]+):(.*)##\ (.*)$$ ]]; then \
			printf "%s %-*s %s\n" "- make" 18 "$${BASH_REMATCH[1]}" "$${BASH_REMATCH[3]}" ; \
		fi ; \
	done

##

.PHONY: init
init: .env ## Check the dependencies and prompt to install if needed
	@which deno > /dev/null && echo "Deno is available" || echo "Install Deno:  curl -fsSL https://deno.land/install.sh | sh"
	@which bulloak > /dev/null && echo "bulloak is available" || echo "Install bulloak:  cargo install bulloak"

	@which forge > /dev/null || curl -L https://foundry.paradigm.xyz | bash
	@forge build
	@which lcov > /dev/null || echo "Note: lcov can be installed by running 'sudo apt install lcov'"

.PHONY: clean
clean: ## Clean the build artifacts
	rm -f $(TEST_TREE_FILES)
	rm -f $(TEST_TREE_MARKDOWN)
	rm -Rf ./out/* lcov.info* ./report/*

##

# Run tests faster, locally
test: export RPC_URL=""
test: export ETHERSCAN_API_KEY=
test-coverage: export RPC_URL=""
test-coverage: export ETHERSCAN_API_KEY=

.PHONY: test
test: ## Run unit tests, locally
	forge test $(VERBOSITY)
# forge test --no-match-path $(FORK_TEST_WILDCARD) $(VERBOSITY)

test-coverage: report/index.html ## Generate an HTML coverage report under ./report
	@which open > /dev/null && open report/index.html || echo -n
	@which xdg-open > /dev/null && xdg-open report/index.html || echo -n

report/index.html: lcov.info.pruned
	genhtml $^ -o report --branch-coverage

lcov.info.pruned: lcov.info
	lcov --remove $< -o ./$@ $^

lcov.info: $(TEST_COVERAGE_SRC_FILES)
	forge coverage --report lcov

##

sync-tests: $(TEST_TREE_FILES) ## Scaffold or sync tree files into solidity tests
	@for file in $^; do \
		if [ ! -f $${file%.tree}.t.sol ]; then \
			echo "[Scaffold]   $${file%.tree}.t.sol" ; \
			bulloak scaffold -s $(SOLC_VERSION) --vm-skip -w $$file ; \
		else \
			echo "[Sync file]  $${file%.tree}.t.sol" ; \
			bulloak check --fix $$file ; \
		fi \
	done

check-tests: $(TEST_TREE_FILES) ## Checks if solidity files are out of sync
	bulloak check $^

markdown-tests: $(TEST_TREE_MARKDOWN) ## Generates a markdown file with the test definitions rendered as a tree

# Internal targets

# Generate a markdown file with the test trees
$(TEST_TREE_MARKDOWN): $(TEST_TREE_FILES)
	@echo "[Markdown]   TEST_TREE.md"
	@echo "# Test tree definitions" > $@
	@echo "" >> $@
	@echo "Below is the graphical definition of the contract tests implemented on [the test folder](./test)" >> $@
	@echo "" >> $@

	@for file in $^; do \
		echo "\`\`\`" >> $@ ; \
		cat $$file >> $@ ; \
		echo "\`\`\`" >> $@ ; \
		echo "" >> $@ ; \
	done

# Internal dependencies and transformations

$(TEST_TREE_FILES): $(TEST_SOURCE_FILES)

%.tree: %.t.yaml
	@for file in $^; do \
	  echo "[Convert]    $$file -> $${file%.t.yaml}.tree" ; \
		cat $$file | $(MAKE_TEST_TREE_CMD) > $${file%.t.yaml}.tree ; \
	done

## Deployment targets:

.PHONY: predeploy
predeploy:  ## Simulate a factory deployment
	@echo "Simulating the deployment"
	forge script $(DEPLOY_SCRIPT) \
		--rpc-url $(RPC_URL) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(VERBOSITY)

.PHONY: deploy
deploy: test  ## Deploy the factory and verify the source code
	@echo "Starting the deployment"
	@mkdir -p $(LOGS_FOLDER)/
	forge script $(DEPLOY_SCRIPT) \
		--rpc-url $(RPC_URL) \
		--retries 10 \
		--delay 8 \
		--broadcast \
		--verify \
		$(VERIFIER_PARAMS) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(VERBOSITY) 2>&1 | tee -a $(LOGS_FOLDER)/$(DEPLOYMENT_LOG_FILE)

##

.PHONY: precreate
precreate: ## Simulate running Create.s.sol
	@echo "Simulating condition creation"
	forge script $(CREATE_SCRIPT) \
		--rpc-url $(RPC_URL) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(VERBOSITY)

.PHONY: create
create: test ## Run Create.s.sol to create new condition instances
	@echo "Creating condition(s)"
	@mkdir -p $(LOGS_FOLDER)/
	forge script $(CREATE_SCRIPT) \
		--rpc-url $(RPC_URL) \
		--retries 10 \
		--delay 8 \
		--broadcast \
		--verify \
		$(VERIFIER_PARAMS) \
		$(FORGE_BUILD_CUSTOM_PARAMS) \
		$(FORGE_SCRIPT_CUSTOM_PARAMS) \
		$(VERBOSITY) 2>&1 | tee -a $(LOGS_FOLDER)/$(CREATION_LOG_FILE)

## Verification:

.PHONY: verify-etherscan
verify-etherscan: broadcast/$(DEPLOYMENT_SCRIPT).s.sol/$(CHAIN_ID)/run-latest.json ## Verify the last deployment on an Etherscan (compatible) explorer
	forge build $(FORGE_BUILD_CUSTOM_PARAMS)
	bash $(VERIFY_CONTRACTS_SCRIPT) $(CHAIN_ID) $(VERIFIER) $(VERIFIER_URL) $(VERIFIER_API_KEY)

.PHONY: verify-blockscout
verify-blockscout: broadcast/$(DEPLOYMENT_SCRIPT).s.sol/$(CHAIN_ID)/run-latest.json ## Verify the last deployment on BlockScout
	forge build $(FORGE_BUILD_CUSTOM_PARAMS)
	bash $(VERIFY_CONTRACTS_SCRIPT) $(CHAIN_ID) $(VERIFIER) https://$(BLOCKSCOUT_HOST_NAME)/api $(VERIFIER_API_KEY)

.PHONY: verify-sourcify
verify-sourcify: broadcast/$(DEPLOYMENT_SCRIPT).s.sol/$(CHAIN_ID)/run-latest.json ## Verify the last deployment on Sourcify
	forge build $(FORGE_BUILD_CUSTOM_PARAMS)
	bash $(VERIFY_CONTRACTS_SCRIPT) $(CHAIN_ID) $(VERIFIER) "" ""

##

.PHONY: refund
refund: ## Refund the remaining balance left on the deployment account
	@echo "Refunding the remaining balance on $(DEPLOYMENT_ADDRESS)"
	@if [ -z $(REFUND_ADDRESS) -o $(REFUND_ADDRESS) = "0x0000000000000000000000000000000000000000" ]; then \
		echo "- The refund address is empty" ; \
		exit 1; \
	fi
	@BALANCE=$(shell cast balance $(DEPLOYMENT_ADDRESS) --rpc-url $(PRODNET_RPC_URL)) && \
		GAS_PRICE=$(shell cast gas-price --rpc-url $(PRODNET_RPC_URL)) && \
		REMAINING=$$(echo "$$BALANCE - $$GAS_PRICE * 21000" | bc) && \
		\
		ENOUGH_BALANCE=$$(echo "$$REMAINING > 0" | bc) && \
		if [ "$$ENOUGH_BALANCE" = "0" ]; then \
			echo -e "- No balance can be refunded: $$BALANCE wei\n- Minimum balance: $${REMAINING:1} wei" ; \
			exit 1; \
		fi ; \
		echo -n -e "Summary:\n- Refunding: $$REMAINING (wei)\n- Recipient: $(REFUND_ADDRESS)\n\nContinue? (y/N) " && \
		\
		read CONFIRM && \
		if [ "$$CONFIRM" != "y" ]; then echo "Aborting" ; exit 1; fi ; \
		\
		cast send --private-key $(DEPLOYMENT_PRIVATE_KEY) \
			--rpc-url $(PRODNET_RPC_URL) \
			--value $$REMAINING \
			$(REFUND_ADDRESS)

.PHONY: gas-price
gas-price:
	@echo "Gas price ($(NETWORK_NAME)):"
	@cast gas-price --rpc-url $(RPC_URL)

.PHONY: balance
balance:
	@echo "Balance of $(DEPLOYMENT_ADDRESS) ($(NETWORK_NAME)):"
	@BALANCE=$$(cast balance $(DEPLOYMENT_ADDRESS) --rpc-url $(RPC_URL)) && \
		cast --to-unit $$BALANCE ether

# In the case we need to whipe stuck transactions, by submiting a 0 value transaction with a specific nonce and higher gas
.PHONY: clean-nonces
clean-nonces:
	for nonce in $(nonces); do \
	  make clean-nonce nonce=$$nonce ; \
	done

.PHONY: clean-nonce
clean-nonce:
	cast send --private-key $(DEPLOYMENT_PRIVATE_KEY) \
 			--rpc-url $(RPC_URL) \
 			--value 0 \
            --nonce $(nonce) \
 			$(DEPLOYMENT_ADDRESS)
