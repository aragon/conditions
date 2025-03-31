// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.22;

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
    bytes4[] internal initialSelectors;
    ExecuteSelectorCondition.InitialTarget[] internal initialExecuteTargets;

    function withDaoOwner(address newOwner) public returns (DaoBuilder) {
        owner = newOwner;
        return this;
    }

    function withSelectors(
        bytes4[] memory _initialSelectors
    ) public returns (DaoBuilder) {
        initialSelectors = _initialSelectors;
        return this;
    }

    function withInitialExecuteTargets(
        ExecuteSelectorCondition.InitialTarget[] memory _initialExecuteTargets
    ) public returns (DaoBuilder) {
        for (uint256 i; i < _initialExecuteTargets.length; ) {
            initialExecuteTargets.push(
                ExecuteSelectorCondition.InitialTarget(
                    _initialExecuteTargets[i].selector,
                    _initialExecuteTargets[i].target
                )
            );

            unchecked {
                i++;
            }
        }
        return this;
    }

    /// @dev Creates a DAO with the given orchestration settings.
    /// @dev The setup is done on block/timestamp 0 and tests should be made on block/timestamp 1 or later.
    function build()
        public
        returns (
            DAO dao,
            ConditionFactory factory,
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
                        ("", address(this), address(0x0), "")
                    )
                )
            )
        );

        // Deploy conditions
        factory = new ConditionFactory();

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(
                IDAO(dao),
                initialExecuteTargets
            )
        );
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(IDAO(dao), initialSelectors)
        );

        // Transfer ownership to the owner
        dao.grant(address(dao), owner, dao.ROOT_PERMISSION_ID());
        dao.revoke(address(dao), address(this), dao.ROOT_PERMISSION_ID());

        // Labels
        vm.label(address(dao), "DAO");
        vm.label(address(selectorCondition), "SelectorCondition");
    }
}
