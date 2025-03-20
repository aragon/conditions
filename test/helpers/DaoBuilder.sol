// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {ALICE_ADDRESS, BOB_ADDRESS} from "../constants.sol";
import {ExecuteSelectorCondition} from "../../src/ExecuteSelectorCondition.sol";
import {SelectorCondition} from "../../src/SelectorCondition.sol";
import {ConditionFactory} from "../../src/factory/ConditionFactory.sol";
import {createProxyAndCall} from "../helpers/proxy.sol";

contract DaoBuilder is Test {
    address immutable DAO_BASE = address(new DAO());

    address internal owner = ALICE_ADDRESS;
    bytes4[] internal selectors;

    function withDaoOwner(address newOwner) public returns (DaoBuilder) {
        owner = newOwner;
        return this;
    }

    function withSelectors(
        bytes4[] memory _selectors
    ) public returns (DaoBuilder) {
        selectors = _selectors;
        return this;
    }

    /// @dev Creates a DAO with the given orchestration settings.
    /// @dev The setup is done on block/timestamp 0 and tests should be made on block/timestamp 1 or later.
    function build()
        public
        returns (
            DAO dao,
            ExecuteSelectorCondition executeSelectorCondition,
            SelectorCondition selectorCondition
        )
    {
        // Deploy the DAO with `this` as root
        dao = DAO(
            payable(
                createProxyAndCall(
                    address(DAO_BASE),
                    abi.encodeCall(
                        DAO.initialize,
                        ("", address(owner), address(0x0), "")
                    )
                )
            )
        );

        // Deploy conditions
        ConditionFactory factory = new ConditionFactory();

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(IDAO(dao), selectors)
        );
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(IDAO(dao), selectors)
        );

        // Transfer ownership to the owner
        dao.grant(address(dao), owner, dao.ROOT_PERMISSION_ID());
        dao.revoke(address(dao), address(this), dao.ROOT_PERMISSION_ID());

        // Labels
        vm.label(address(dao), "DAO");
        vm.label(address(selectorCondition), "SelectorCondition");
    }
}
