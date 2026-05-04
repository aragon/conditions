// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";
import {SafeOwnerCondition, IOwnerManager} from "../src/SafeOwnerCondition.sol";

/// @dev This is a development script used for internal testing purposes
contract Create is Script {
    using stdJson for string;

    IDAO dao;
    address safe;
    ExecuteSelectorCondition esc;
    SelectorCondition sc;
    SafeOwnerCondition soc;

    modifier broadcast() {
        uint256 privKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(privKey);
        console.log("Running from:", vm.addr(privKey));

        _;

        vm.stopBroadcast();
    }

    function run() public broadcast {
        console.log("Chain ID:", block.chainid);
        console.log("");

        dao = IDAO(vm.envOr("DAO_ADDRESS", address(0xce4d73496f0Cf54399b56545292cd8C362Cb866E)));
        safe = vm.envOr("SAFE_ADDRESS", address(0));

        /// @dev Dummy deployments to force explicit contract verification

        ExecuteSelectorCondition.SelectorTarget[] memory initialEntries =
            new ExecuteSelectorCondition.SelectorTarget[](0);
        bytes4[] memory selectors = new bytes4[](0);

        esc = new ExecuteSelectorCondition(dao, initialEntries);
        sc = new SelectorCondition(dao, selectors);

        if (safe == address(0)) {
            safe = address(new IsOwnerMock());
        }
        soc = new SafeOwnerCondition(IOwnerManager(safe));

        // Result
        console.log("ExecuteSelectorCondition:", address(esc));
        console.log("SelectorCondition:", address(sc));
        console.log("SafeOwnerCondition:", address(soc));
        console.log("");

        if (!vm.envOr("SIMULATION", false)) {
            writeJsonArtifacts();
        }
    }

    function writeJsonArtifacts() internal {
        string memory json = "creation";
        json.serialize("chainId", vm.toString(block.chainid));
        json.serialize("deployer", vm.addr(vm.envUint("DEPLOYER_KEY")));
        json.serialize("dao", address(dao));
        json.serialize("safe", safe);
        json.serialize("executeSelectorCondition", address(esc));
        json.serialize("selectorCondition", address(sc));
        json = json.serialize("safeOwnerCondition", address(soc));

        vm.createDir("./deployments", true);
        string memory networkName = vm.envOr("NETWORK_NAME", string("local"));
        string memory filePath = string.concat(
            vm.projectRoot(),
            "/deployments/Create-",
            networkName,
            "-",
            vm.toString(block.timestamp),
            ".json"
        );
        json.write(filePath);

        console.log("Artifacts written to", filePath);
    }
}

contract IsOwnerMock {
    function isOwner(address _owner) external view returns (bool) {}
}
