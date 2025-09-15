// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ConditionFactory} from "../src/factory/ConditionFactory.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IOwnerManager} from "../src/SafeOwnerCondition.sol";
import {SafeMock} from "../test/mocks/SafeMock.sol";

contract Deploy is Script {
    modifier broadcast() {
        uint256 privKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        vm.startBroadcast(privKey);
        console.log("Deploying from:", vm.addr(privKey));

        _;

        vm.stopBroadcast();
    }

    function run() public broadcast {
        console.log("Chain ID:", block.chainid);
        console.log("");

        ConditionFactory factory = new ConditionFactory();

        // Deploy dummy instances to force verifying the source
        ExecuteSelectorCondition.SelectorTarget[] memory initialEntries =
            new ExecuteSelectorCondition.SelectorTarget[](0);
        bytes4[] memory selectors = new bytes4[](0);

        factory.deployExecuteSelectorCondition(IDAO(address(0)), initialEntries);
        factory.deploySelectorCondition(IDAO(address(0)), selectors);

        address safeAddress = vm.envOr("SAFE_ADDRESS", address(0));
        if (safeAddress == address(0)) {
            safeAddress = address(new SafeMock());
        }
        factory.deploySafeOwnerCondition(IDAO(address(0)), safeAddress);

        // Result
        console.log("Condition Factory:", address(factory));
        console.log("");
    }
}
