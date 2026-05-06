// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ConditionFactory} from "../src/factory/ConditionFactory.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IOwnerManager} from "../src/SafeOwnerCondition.sol";

contract Deploy is Script {
    using stdJson for string;

    ConditionFactory factory;

    modifier broadcast() {
        uint256 privKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(privKey);
        console.log("Deploying from:", vm.addr(privKey));

        _;

        vm.stopBroadcast();
    }

    function run() public broadcast {
        console.log("Chain ID:", block.chainid);
        console.log("");

        factory = new ConditionFactory();

        // Deploy dummy instances to force verifying the source
        ExecuteSelectorCondition.SelectorTarget[] memory initialEntries =
            new ExecuteSelectorCondition.SelectorTarget[](0);
        bytes4[] memory selectors = new bytes4[](0);

        factory.deployExecuteSelectorCondition(IDAO(address(0)), initialEntries);
        factory.deploySelectorCondition(IDAO(address(0)), selectors);

        address safeAddress = vm.envOr("SAFE_ADDRESS", address(0));
        if (safeAddress == address(0)) {
            safeAddress = address(new IsOwnerMock());
        }
        factory.deploySafeOwnerCondition(safeAddress);

        // Result
        console.log("Condition Factory:", address(factory));
        console.log("");

        if (!vm.envOr("SIMULATION", false)) {
            writeJsonArtifacts();
        }
    }

    function writeJsonArtifacts() internal {
        string memory json = "deployment";
        json.serialize("chainId", vm.toString(block.chainid));
        json.serialize("deployer", vm.addr(vm.envUint("DEPLOYER_KEY")));
        json = json.serialize("conditionFactory", address(factory));

        // Idempotent, recursive
        vm.createDir("./deployments", true);
        string memory networkName = vm.envOr("NETWORK_NAME", string("local"));
        string memory filePath = string.concat(
            vm.projectRoot(), "/deployments/Deploy-", networkName, "-", vm.toString(block.timestamp), ".json"
        );
        json.write(filePath);

        console.log("Artifacts written to", filePath);
    }
}

contract IsOwnerMock {
    function isOwner(address _owner) external view returns (bool) {}
}
