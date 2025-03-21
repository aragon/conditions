// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {PermissionManager} from "@aragon/osx/core/permission/PermissionManager.sol";
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
        vm.assertFalse(
            executeSelectorCondition.allowedTargets(address(dao), bytes4(0))
        );
        vm.assertFalse(
            executeSelectorCondition.allowedTargets(
                address(dao),
                bytes4(0x11223344)
            )
        );
        vm.assertFalse(
            executeSelectorCondition.allowedTargets(
                address(dao),
                bytes4(0x55667788)
            )
        );
        vm.assertFalse(
            executeSelectorCondition.allowedTargets(
                address(dao),
                bytes4(0xffffffff)
            )
        );

        // 1
        ExecuteSelectorCondition.InitialTarget[]
            memory _initialTargets = new ExecuteSelectorCondition.InitialTarget[](
                2
            );
        _initialTargets[0].selector = bytes4(0x11223344);
        _initialTargets[0].target = address(dao);
        _initialTargets[1].selector = bytes4(0x55667788);
        _initialTargets[1].target = address(dao);
        executeSelectorCondition = new ExecuteSelectorCondition(
            dao,
            _initialTargets
        );

        vm.assertFalse(
            executeSelectorCondition.allowedTargets(address(dao), bytes4(0))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedTargets(
                address(dao),
                bytes4(0x11223344)
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedTargets(
                address(dao),
                bytes4(0x55667788)
            )
        );
        vm.assertFalse(
            executeSelectorCondition.allowedTargets(
                address(dao),
                bytes4(0xffffffff)
            )
        );

        // 2
        _initialTargets = new ExecuteSelectorCondition.InitialTarget[](2);
        _initialTargets[0].selector = bytes4(0x00008888);
        _initialTargets[0].target = carol;
        _initialTargets[1].selector = bytes4(0x2222aaaa);
        _initialTargets[1].target = carol;
        executeSelectorCondition = new ExecuteSelectorCondition(
            dao,
            _initialTargets
        );

        vm.assertFalse(
            executeSelectorCondition.allowedTargets(carol, bytes4(0))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedTargets(carol, bytes4(0x00008888))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedTargets(carol, bytes4(0x2222aaaa))
        );
        vm.assertFalse(
            executeSelectorCondition.allowedTargets(carol, bytes4(0xffffffff))
        );
    }

    function test_RevertWhen_NotCallingExecute() external {
        // It should revert

        ExecuteSelectorCondition.InitialTarget[]
            memory _initialTargets = new ExecuteSelectorCondition.InitialTarget[](
                0
            );
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _initialTargets)
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

        // Allow the DAO to call its own functions
        dao.grant(address(dao), address(dao), SET_METADATA_PERMISSION_ID);
        dao.grant(
            address(dao),
            address(dao),
            SET_SIGNATURE_VALIDATOR_PERMISSION_ID
        );
        dao.grant(
            address(dao),
            address(dao),
            REGISTER_STANDARD_CALLBACK_PERMISSION_ID
        );
        dao.grant(
            address(dao),
            address(dao),
            SET_TRUSTED_FORWARDER_PERMISSION_ID
        );

        // No targets allowed yet

        ExecuteSelectorCondition.InitialTarget[]
            memory _targets = new ExecuteSelectorCondition.InitialTarget[](0);
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _targets)
        );

        IDAO.Action[] memory _actions = new IDAO.Action[](0);

        // Can execute, but no selectors are allowed
        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            executeSelectorCondition
        );

        // 1 nop
        vm.startPrank(bob);
        dao.execute(bytes32(0), _actions, 0);

        // 2 all out
        _actions = new IDAO.Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(DAO.setSignatureValidator, (bob));
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[2].to = address(dao);
        _actions[3].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[3].to = address(dao);

        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.Unauthorized.selector,
                address(dao),
                address(bob),
                EXECUTE_PERMISSION_ID
            )
        );
        dao.execute(bytes32(uint256(1)), _actions, 0);

        // 3 some out
        {
            vm.startPrank(alice);
            dao.revoke(address(dao), bob, EXECUTE_PERMISSION_ID);

            _targets = new ExecuteSelectorCondition.InitialTarget[](1);
            _targets[0].selector = DAO.setMetadata.selector;
            _targets[0].target = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _targets)
            );
            dao.grantWithCondition(
                address(dao),
                bob,
                EXECUTE_PERMISSION_ID,
                executeSelectorCondition
            );

            vm.startPrank(bob);
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.Unauthorized.selector,
                address(dao),
                address(bob),
                EXECUTE_PERMISSION_ID
            )
        );
        dao.execute(bytes32(uint256(2)), _actions, 0);

        // 4 some still out
        {
            vm.startPrank(alice);
            dao.revoke(address(dao), bob, EXECUTE_PERMISSION_ID);

            _targets = new ExecuteSelectorCondition.InitialTarget[](2);
            _targets[0].selector = DAO.setMetadata.selector;
            _targets[0].target = address(dao);
            _targets[1].selector = DAO.setSignatureValidator.selector;
            _targets[1].target = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _targets)
            );
            dao.grantWithCondition(
                address(dao),
                bob,
                EXECUTE_PERMISSION_ID,
                executeSelectorCondition
            );

            vm.startPrank(bob);
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.Unauthorized.selector,
                address(dao),
                address(bob),
                EXECUTE_PERMISSION_ID
            )
        );
        dao.execute(bytes32(uint256(2)), _actions, 0);

        // 5 still one left
        {
            vm.startPrank(alice);
            dao.revoke(address(dao), bob, EXECUTE_PERMISSION_ID);

            _targets = new ExecuteSelectorCondition.InitialTarget[](3);
            _targets[0].selector = DAO.setMetadata.selector;
            _targets[0].target = address(dao);
            _targets[1].selector = DAO.setSignatureValidator.selector;
            _targets[1].target = address(dao);
            _targets[2].selector = DAO.registerStandardCallback.selector;
            _targets[2].target = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _targets)
            );
            dao.grantWithCondition(
                address(dao),
                bob,
                EXECUTE_PERMISSION_ID,
                executeSelectorCondition
            );

            vm.startPrank(bob);
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                PermissionManager.Unauthorized.selector,
                address(dao),
                address(bob),
                EXECUTE_PERMISSION_ID
            )
        );
        dao.execute(bytes32(uint256(2)), _actions, 0);
    }

    function test_RevertGiven_NotAllTargetsAreAllowed()
        external
        whenCallingExecute
    {
        // It should revert
    }

    function test_GivenAllActionsAreAllowed() external whenCallingExecute {
        // It should allow execution

        // Allow the DAO to call its own functions
        dao.grant(address(dao), address(dao), SET_METADATA_PERMISSION_ID);
        dao.grant(
            address(dao),
            address(dao),
            SET_SIGNATURE_VALIDATOR_PERMISSION_ID
        );
        dao.grant(
            address(dao),
            address(dao),
            REGISTER_STANDARD_CALLBACK_PERMISSION_ID
        );
        dao.grant(
            address(dao),
            address(dao),
            SET_TRUSTED_FORWARDER_PERMISSION_ID
        );

        // All selectors allowed
        ExecuteSelectorCondition.InitialTarget[]
            memory _targets = new ExecuteSelectorCondition.InitialTarget[](4);
        _targets[0].selector = DAO.setMetadata.selector;
        _targets[0].target = address(dao);
        _targets[1].selector = DAO.setSignatureValidator.selector;
        _targets[1].target = address(dao);
        _targets[2].selector = DAO.registerStandardCallback.selector;
        _targets[2].target = address(dao);
        _targets[3].selector = DAO.setTrustedForwarder.selector;
        _targets[3].target = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _targets)
        );

        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            executeSelectorCondition
        );

        // Bob can now execute these actions
        vm.startPrank(bob);

        IDAO.Action[] memory _actions = new IDAO.Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(DAO.setSignatureValidator, (bob));
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[2].to = address(dao);
        _actions[3].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[3].to = address(dao);

        dao.execute(bytes32(uint256(2)), _actions, 0);
    }

    modifier whenCallingIsGranted() {
        _;
    }

    function test_GivenNotAllActionsAreAllowed2()
        external
        whenCallingIsGranted
    {
        // It should return false

        // No selectors allowed yet
        ExecuteSelectorCondition.InitialTarget[]
            memory _targets = new ExecuteSelectorCondition.InitialTarget[](0);
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _targets)
        );

        IDAO.Action[] memory _actions = new IDAO.Action[](0);

        // 1 no actions
        bytes memory _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        vm.assertTrue(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 2 all out
        _actions = new IDAO.Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(DAO.setSignatureValidator, (bob));
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[2].to = address(dao);
        _actions[3].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[3].to = address(dao);

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        vm.assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 3 some out
        _targets = new ExecuteSelectorCondition.InitialTarget[](1);
        _targets[0].selector = DAO.setMetadata.selector;
        _targets[0].target = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _targets)
        );

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        vm.assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 4 some still out
        _targets = new ExecuteSelectorCondition.InitialTarget[](2);
        _targets[0].selector = DAO.setMetadata.selector;
        _targets[0].target = address(dao);
        _targets[1].selector = DAO.setSignatureValidator.selector;
        _targets[1].target = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _targets)
        );

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        vm.assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 5 still one left
        _targets = new ExecuteSelectorCondition.InitialTarget[](3);
        _targets[0].selector = DAO.setMetadata.selector;
        _targets[0].target = address(dao);
        _targets[1].selector = DAO.setSignatureValidator.selector;
        _targets[1].target = address(dao);
        _targets[2].selector = DAO.registerStandardCallback.selector;
        _targets[2].target = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _targets)
        );

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        vm.assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );
    }

    function test_GivenNotAllTargetsAreAllowed2()
        external
        whenCallingIsGranted
    {
        // It return false
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
        // It allowedTargets should return true
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
        // It allowedTargets should return false
        vm.skip(true);
    }

    function test_WhenCallingSupportsInterface() external {
        // It does not support the empty interface
        // It supports IPermissionCondition
        vm.skip(true);
    }
}
