// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {ConditionFactory} from "../../src/factory/ConditionFactory.sol";
import {EXECUTE_PERMISSION_ID, SET_METADATA_PERMISSION_ID, SET_SIGNATURE_VALIDATOR_PERMISSION_ID, REGISTER_STANDARD_CALLBACK_PERMISSION_ID, SET_TRUSTED_FORWARDER_PERMISSION_ID} from "./constants.sol";

contract ExecuteSelectorConditionTest is AragonTest {
    DaoBuilder builder;
    DAO dao;
    ConditionFactory factory;
    ExecuteSelectorCondition executeSelectorCondition;

    function setUp() public {
        vm.startPrank(alice);
        builder = new DaoBuilder();
        (dao, factory, executeSelectorCondition, ) = builder.build();
    }

    function test_WhenDeployingTheContract() external {
        // It should set the given DAO
        // It should define the given selectors as allowed

        vm.assertEq(address(executeSelectorCondition.dao()), address(dao));
        vm.assertFalse(executeSelectorCondition.allowedSelectors(bytes4(0)));
        vm.assertFalse(
            executeSelectorCondition.allowedSelectors(bytes4(0x11223344))
        );
        vm.assertFalse(
            executeSelectorCondition.allowedSelectors(bytes4(0x55667788))
        );
        vm.assertFalse(
            executeSelectorCondition.allowedSelectors(bytes4(0xffffffff))
        );

        // 1
        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = bytes4(0x11223344);
        _selectors[1] = bytes4(0x55667788);
        executeSelectorCondition = new ExecuteSelectorCondition(
            dao,
            _selectors
        );

        vm.assertFalse(executeSelectorCondition.allowedSelectors(bytes4(0)));
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(bytes4(0x11223344))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(bytes4(0x55667788))
        );
        vm.assertFalse(
            executeSelectorCondition.allowedSelectors(bytes4(0xffffffff))
        );

        // 2
        _selectors = new bytes4[](2);
        _selectors[0] = bytes4(0x00008888);
        _selectors[1] = bytes4(0x2222aaaa);
        executeSelectorCondition = new ExecuteSelectorCondition(
            dao,
            _selectors
        );

        vm.assertFalse(executeSelectorCondition.allowedSelectors(bytes4(0)));
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(bytes4(0x00008888))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(bytes4(0x2222aaaa))
        );
        vm.assertFalse(
            executeSelectorCondition.allowedSelectors(bytes4(0xffffffff))
        );
    }

    function test_RevertWhen_NotCallingExecute() external {
        // It should revert

        bytes4[] memory _selectors = new bytes4[](0);
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _selectors)
        );

        // Granting permission to call something other than execute()
        dao.grantWithCondition(
            address(dao),
            bob,
            SET_METADATA_PERMISSION_ID,
            executeSelectorCondition
        );

        // not execute()
        vm.expectRevert();
        vm.startPrank(bob);
        dao.setMetadata("new-value");

        // Granting execute (no selectors)
        vm.startPrank(alice);
        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            executeSelectorCondition
        );

        // Now calling execute (no actions)
        vm.startPrank(bob);
        IDAO.Action[] memory _actions = new IDAO.Action[](0);
        dao.execute(bytes32(0), _actions, 0);
    }

    modifier whenCallingExecute() {
        _;
    }

    function test_RevertGiven_NotAllActionsAreAllowed()
        external
        whenCallingExecute
    {
        // It should revert

        // No selectore allowed
        bytes4[] memory _selectors = new bytes4[](0);
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _selectors)
        );

        // // Can execute, but no selectors
        // dao.grantWithCondition(
        //     address(dao),
        //     bob,
        //     EXECUTE_PERMISSION_ID,
        //     selectorCondition
        // );
        vm.skip(true);
    }

    function test_GivenAllActionsAreAllowed() external whenCallingExecute {
        // It should allow execution
        vm.skip(true);
    }

    modifier whenCallingIsGranted() {
        _;
    }

    function test_GivenNotAllActionsAreAllowed2()
        external
        whenCallingIsGranted
    {
        // It should return false
        vm.skip(true);
    }

    function test_GivenAllActionsAreAllowed2() external whenCallingIsGranted {
        // It should return true
        vm.skip(true);
    }

    modifier whenCallingAddSelector() {
        _;
    }

    function test_RevertGiven_TheCallerHasNoPermission()
        external
        whenCallingAddSelector
    {
        // It should revert
        vm.skip(true);
    }

    function test_RevertGiven_TheSelectorIsAlreadyAllowed()
        external
        whenCallingAddSelector
    {
        // It should revert
        vm.skip(true);
    }

    function test_GivenTheCallerHasPermission()
        external
        whenCallingAddSelector
    {
        // It should succeed
        // It should emit an event
        // It allowedSelectors should return true
        vm.skip(true);
    }

    modifier whenCallingRemoveSelector() {
        _;
    }

    function test_RevertGiven_TheCallerHasNoPermission2()
        external
        whenCallingRemoveSelector
    {
        // It should revert
        vm.skip(true);
    }

    function test_RevertGiven_TheSelectorIsNotAllowed()
        external
        whenCallingRemoveSelector
    {
        // It should revert
        vm.skip(true);
    }

    function test_GivenTheCallerHasPermission2()
        external
        whenCallingRemoveSelector
    {
        // It should succeed
        // It should emit an event
        // It allowedSelectors should return false
        vm.skip(true);
    }

    function test_WhenCallingSupportsInterface() external {
        // It does not support the empty interface
        // It supports IPermissionCondition
        vm.skip(true);
    }
}
