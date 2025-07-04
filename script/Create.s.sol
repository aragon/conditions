// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";

/// @dev This is a development script used for internal testing purposes
contract Create is Script {
    IDAO constant dao =
        IDAO(address(0xce4d73496f0Cf54399b56545292cd8C362Cb866E));

    modifier broadcast() {
        uint256 privKey = vm.envUint("DEPLOYMENT_PRIVATE_KEY");
        vm.startBroadcast(privKey);
        console.log("Running from:", vm.addr(privKey));

        _;

        vm.stopBroadcast();
    }

    function run() public broadcast {
        console.log("Chain ID:", block.chainid);
        console.log("");

        ExecuteSelectorCondition.SelectorTarget[]
            memory initialEntries = new ExecuteSelectorCondition.SelectorTarget[](
                0
            );
        bytes4[] memory selectors = new bytes4[](0);

        ExecuteSelectorCondition esc = new ExecuteSelectorCondition(
            dao,
            initialEntries
        );
        SelectorCondition sc = new SelectorCondition(dao, selectors);

        // Result
        console.log("ExecuteSelectorCondition:", address(esc));
        console.log("SelectorCondition:", address(sc));
        console.log("");
    }
}
