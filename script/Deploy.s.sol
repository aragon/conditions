// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ConditionFactory} from "../src/factory/ConditionFactory.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";

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

        // The factory
        ConditionFactory factory = new ConditionFactory();

        // Deploy dummy instances to force verifying the source
        ExecuteSelectorCondition.InitialTarget[]
            memory initialTargets = new ExecuteSelectorCondition.InitialTarget[](
                0
            );
        bytes4[] memory selectors = new bytes4[](0);

        factory.deployExecuteSelectorCondition(
            IDAO(address(0)),
            initialTargets
        );
        factory.deploySelectorCondition(IDAO(address(0)), selectors);

        // Result
        console.log("Condition Factory:", address(factory));
        console.log("");
    }
}
