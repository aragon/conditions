// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {PermissionManager} from "@aragon/osx/core/permission/PermissionManager.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {ExecuteSelectorCondition} from "../src/ExecuteSelectorCondition.sol";
import {ConditionFactory} from "../src/factory/ConditionFactory.sol";
import {EXECUTE_PERMISSION_ID, SET_METADATA_PERMISSION_ID, SET_SIGNATURE_VALIDATOR_PERMISSION_ID, REGISTER_STANDARD_CALLBACK_PERMISSION_ID, SET_TRUSTED_FORWARDER_PERMISSION_ID, MANAGE_SELECTORS_PERMISSION_ID} from "./constants.sol";

contract ExecuteSelectorConditionTest is AragonTest {
    DaoBuilder builder;
    DAO dao;
    ConditionFactory factory;
    ExecuteSelectorCondition executeSelectorCondition;

    event SelectorAllowed(bytes4 selector, address target);
    event SelectorDisallowed(bytes4 selector, address target);

    function setUp() public {
        vm.startPrank(alice);
        builder = new DaoBuilder();
        (dao, factory, executeSelectorCondition, ) = builder.build();
    }

    function test_WhenDeployingTheContract() external {
        // It should set the given DAO
        // It should define the given selectors as allowed

        vm.assertEq(address(executeSelectorCondition.dao()), address(dao));
        assertFalse(
            executeSelectorCondition.allowedSelectors(address(dao), bytes4(0))
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                bytes4(0x11223344)
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                bytes4(0x55667788)
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                bytes4(0xffffffff)
            )
        );

        // 1
        ExecuteSelectorCondition.SelectorTarget[]
            memory _initialEntries = new ExecuteSelectorCondition.SelectorTarget[](
                2
            );
        _initialEntries[0].selectors = new bytes4[](2);
        _initialEntries[0].selectors[0] = bytes4(0x11223344);
        _initialEntries[0].selectors[1] = bytes4(0x55667788);
        _initialEntries[0].where = address(dao);
        _initialEntries[1].selectors = new bytes4[](1);
        _initialEntries[1].selectors[0] = bytes4(0x99aabbcc);
        _initialEntries[1].where = address(this);
        executeSelectorCondition = new ExecuteSelectorCondition(
            dao,
            _initialEntries
        );

        assertFalse(
            executeSelectorCondition.allowedSelectors(address(dao), bytes4(0))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                bytes4(0x11223344)
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                bytes4(0x55667788)
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(this),
                bytes4(0x99aabbcc)
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                bytes4(0xffffffff)
            )
        );

        // 2
        _initialEntries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _initialEntries[0].selectors = new bytes4[](2);
        _initialEntries[0].selectors[0] = bytes4(0x00008888);
        _initialEntries[0].selectors[1] = bytes4(0x2222aaaa);
        _initialEntries[0].where = carol;
        _initialEntries[1].selectors = new bytes4[](1);
        _initialEntries[1].selectors[0] = bytes4(0x446688aa);
        _initialEntries[1].where = david;
        executeSelectorCondition = new ExecuteSelectorCondition(
            dao,
            _initialEntries
        );

        assertFalse(
            executeSelectorCondition.allowedSelectors(carol, bytes4(0))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(carol, bytes4(0x00008888))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(carol, bytes4(0x2222aaaa))
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(david, bytes4(0x446688aa))
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(david, bytes4(0xffffffff))
        );
    }

    function test_RevertWhen_NotCallingExecute() external {
        // It should revert

        ExecuteSelectorCondition.SelectorTarget[]
            memory _initialEntries = new ExecuteSelectorCondition.SelectorTarget[](
                0
            );
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _initialEntries)
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
        Action[] memory _actions = new Action[](0);
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

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](0);
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        vm.deal(address(dao), 1 ether);

        Action[] memory _actions = new Action[](0);

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
        _actions = new Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[2].to = address(dao);
        _actions[3].to = alice;
        _actions[3].value = 1 ether;

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

            _entries = new ExecuteSelectorCondition.SelectorTarget[](1);
            _entries[0].selectors = new bytes4[](1);
            _entries[0].selectors[0] = DAO.setMetadata.selector;
            _entries[0].where = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _entries)
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

            _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
            _entries[0].selectors = new bytes4[](2);
            _entries[0].selectors[0] = DAO.setMetadata.selector;
            _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
            _entries[0].where = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _entries)
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

        // 5 some still out
        {
            vm.startPrank(alice);
            dao.revoke(address(dao), bob, EXECUTE_PERMISSION_ID);

            _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
            _entries[0].selectors = new bytes4[](3);
            _entries[0].selectors[0] = DAO.setMetadata.selector;
            _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
            _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
            _entries[0].where = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _entries)
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

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](0);

        // All selectors target another address

        _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _entries[0].selectors = new bytes4[](3);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
        _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
        _entries[0].where = carol;
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = bytes4(0);
        _entries[1].where = david;
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        vm.deal(address(dao), 1 ether);

        Action[] memory _actions = new Action[](0);

        // Can execute, but no selectors are allowed
        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            executeSelectorCondition
        );

        // 1 no actions, ok
        vm.startPrank(bob);
        dao.execute(bytes32(0), _actions, 0);

        // 2 all on a different target
        _actions = new Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[2].to = address(dao);
        _actions[3].to = alice;
        _actions[3].value = 1 ether;

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

            _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
            _entries[0].selectors = new bytes4[](1);
            _entries[0].selectors[0] = DAO.setMetadata.selector;
            _entries[0].where = address(dao);
            _entries[1].selectors = new bytes4[](2);
            _entries[1].selectors[0] = DAO.registerStandardCallback.selector;
            _entries[1].selectors[1] = DAO.setTrustedForwarder.selector;
            _entries[1].where = carol;

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _entries)
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

        // 4 some left
        {
            vm.startPrank(alice);
            dao.revoke(address(dao), bob, EXECUTE_PERMISSION_ID);

            _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
            _entries[0].selectors = new bytes4[](2);
            _entries[0].selectors[0] = DAO.setMetadata.selector;
            _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
            _entries[0].where = address(dao);
            _entries[1].selectors = new bytes4[](1);
            _entries[1].selectors[0] = DAO.setTrustedForwarder.selector;
            _entries[1].where = carol;

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _entries)
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

            _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
            _entries[0].selectors = new bytes4[](3);
            _entries[0].selectors[0] = DAO.setMetadata.selector;
            _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
            _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
            _entries[0].where = address(dao);

            executeSelectorCondition = ExecuteSelectorCondition(
                factory.deployExecuteSelectorCondition(dao, _entries)
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

        // All allowed selectors
        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _entries[0].selectors = new bytes4[](3);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
        _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
        _entries[0].where = address(dao);
        _entries[1].where = alice;
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = bytes4(0); // Eth transfer

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            executeSelectorCondition
        );

        vm.deal(address(dao), 1 ether);

        // Bob can now execute these actions
        vm.startPrank(bob);

        Action[] memory _actions = new Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[2].to = address(dao);
        _actions[3].to = alice;
        _actions[3].value = 1 ether;

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
        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](0);
        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        vm.deal(address(dao), 1 ether);

        Action[] memory _actions = new Action[](0);

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
        _actions = new Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[2].to = address(dao);
        _actions[3].to = alice;
        _actions[3].value = 1 ether;

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 3 some out
        _entries = new ExecuteSelectorCondition.SelectorTarget[](1);
        _entries[0].selectors = new bytes4[](1);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].where = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 4 some still out
        _entries = new ExecuteSelectorCondition.SelectorTarget[](1);
        _entries[0].selectors = new bytes4[](2);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
        _entries[0].where = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 5 some still out
        _entries = new ExecuteSelectorCondition.SelectorTarget[](1);
        _entries[0].selectors = new bytes4[](3);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
        _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
        _entries[0].where = address(dao);

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
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
        // It returns false

        // All allowed selectors
        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _entries[0].selectors = new bytes4[](3);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
        _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
        _entries[0].where = address(dao);
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = bytes4(0);
        _entries[1].where = alice;

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        vm.deal(address(dao), 1 ether);

        // 1 no actions
        Action[] memory _actions = new Action[](0);
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

        // 2 all targets off
        _actions = new Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = carol;
        _actions[1].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[1].to = carol;
        _actions[2].data = abi.encodeCall(DAO.setTrustedForwarder, (carol));
        _actions[2].to = carol;
        _actions[3].to = david;
        _actions[3].value = 1 ether;

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 3 some out
        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 4 still 3 left
        _actions[0].to = address(dao);
        _actions[1].to = carol;
        _actions[2].to = carol;
        _actions[3].to = david;

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 5 still 2 left
        _actions[0].to = address(dao);
        _actions[1].to = address(dao);
        _actions[2].to = carol;
        _actions[3].to = david;

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );

        // 6 still 1 left
        _actions[0].to = address(dao);
        _actions[1].to = address(dao);
        _actions[2].to = address(dao);
        _actions[3].to = david;

        _calldata = abi.encodeCall(
            DAO.execute,
            (bytes32(uint256(1)), _actions, 0)
        );
        assertFalse(
            executeSelectorCondition.isGranted(
                address(0),
                address(0),
                bytes32(0),
                _calldata
            )
        );
    }

    function test_GivenAllActionsAreAllowed2() external whenCallingIsGranted {
        // It should return true

        // All allowed selectors
        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _entries[0].selectors = new bytes4[](3);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.registerStandardCallback.selector;
        _entries[0].selectors[2] = DAO.setTrustedForwarder.selector;
        _entries[0].where = address(dao);
        _entries[1].where = alice;
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = bytes4(0); // Eth transfer

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        // 1 no actions
        Action[] memory _actions = new Action[](0);
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

        // 2 all targets match
        _actions = new Action[](4);
        _actions[0].data = abi.encodeCall(DAO.setMetadata, ("hi"));
        _actions[0].to = address(dao);
        _actions[1].data = abi.encodeCall(
            DAO.registerStandardCallback,
            (bytes4(uint32(1)), bytes4(uint32(2)), bytes4(uint32(3)))
        );
        _actions[1].to = address(dao);
        _actions[2].data = abi.encodeCall(
            DAO.setTrustedForwarder,
            (address(dao))
        );
        _actions[2].to = address(dao);
        _actions[3].to = alice;
        _actions[3].value = 1 ether;

        _calldata = abi.encodeCall(
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
    }

    modifier whenCallingAllowSelector() {
        _;
    }

    function test_RevertGiven_TheCallerHasNoPermission()
        external
        whenCallingAllowSelector
    {
        // It should revert

        ExecuteSelectorCondition.SelectorTarget
            memory _target = ExecuteSelectorCondition.SelectorTarget({
                selectors: new bytes4[](1),
                where: address(dao)
            });
        _target.selectors[0] = DAO.setMetadata.selector;

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                address(alice),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.allowSelectors(_target);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                address(bob),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.allowSelectors(_target);

        vm.startPrank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                address(carol),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.allowSelectors(_target);

        // Now grant it
        vm.startPrank(alice);
        dao.grant(
            address(executeSelectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        vm.startPrank(bob);
        executeSelectorCondition.allowSelectors(_target);
    }

    function test_RevertGiven_TheSelectorIsAlreadyAllowed()
        external
        whenCallingAllowSelector
    {
        // It should revert

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](4);
        _entries[0].selectors = new bytes4[](1);
        _entries[0].selectors[0] = bytes4(uint32(1));
        _entries[0].where = address(this);
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = bytes4(uint32(2));
        _entries[1].where = address(dao);
        _entries[2].selectors = new bytes4[](1);
        _entries[2].selectors[0] = bytes4(uint32(3));
        _entries[2].where = alice;
        _entries[3].selectors = new bytes4[](1);
        _entries[3].selectors[0] = bytes4(uint32(4));
        _entries[3].where = bob;

        executeSelectorCondition = ExecuteSelectorCondition(
            factory.deployExecuteSelectorCondition(dao, _entries)
        );

        dao.grant(
            address(executeSelectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        vm.startPrank(bob);

        // KO
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecuteSelectorCondition.AlreadyAllowed.selector,
                bytes4(uint32(1)),
                address(this)
            )
        );
        executeSelectorCondition.allowSelectors(_entries[0]);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExecuteSelectorCondition.AlreadyAllowed.selector,
                bytes4(uint32(2)),
                address(dao)
            )
        );
        executeSelectorCondition.allowSelectors(_entries[1]);
    }

    function test_GivenTheCallerHasPermission()
        external
        whenCallingAllowSelector
    {
        // It should succeed
        // It should emit an event
        // It allowedSelectors should return true

        // Still false
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.setMetadata.selector
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.execute.selector
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(executeSelectorCondition),
                ExecuteSelectorCondition.allowSelectors.selector
            )
        );

        // Permission
        dao.grant(
            address(executeSelectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _entries[0].selectors = new bytes4[](2);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.execute.selector;
        _entries[0].where = address(dao);
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = ExecuteSelectorCondition
            .allowSelectors
            .selector;
        _entries[1].where = address(executeSelectorCondition);

        vm.startPrank(bob);

        vm.expectEmit();
        emit SelectorAllowed(DAO.setMetadata.selector, address(dao));
        vm.expectEmit();
        emit SelectorAllowed(DAO.execute.selector, address(dao));
        executeSelectorCondition.allowSelectors(_entries[0]);

        vm.expectEmit();
        emit SelectorAllowed(
            ExecuteSelectorCondition.allowSelectors.selector,
            address(executeSelectorCondition)
        );
        executeSelectorCondition.allowSelectors(_entries[1]);

        // Now true
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.setMetadata.selector
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.execute.selector
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(executeSelectorCondition),
                ExecuteSelectorCondition.allowSelectors.selector
            )
        );
    }

    modifier whenCallingRemoveSelector() {
        _;
    }

    function test_RevertGiven_TheCallerHasNoPermission2()
        external
        whenCallingRemoveSelector
    {
        // It should revert

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](2);
        _entries[0].selectors = new bytes4[](2);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].selectors[1] = DAO.execute.selector;
        _entries[0].where = address(dao);
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = ExecuteSelectorCondition
            .allowSelectors
            .selector;
        _entries[1].where = address(executeSelectorCondition);

        dao.grant(
            address(executeSelectorCondition),
            alice,
            MANAGE_SELECTORS_PERMISSION_ID
        );
        executeSelectorCondition.allowSelectors(_entries[0]);
        executeSelectorCondition.allowSelectors(_entries[1]);
        dao.revoke(
            address(executeSelectorCondition),
            alice,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        // Try to remove

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                address(alice),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.disallowSelectors(_entries[0]);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                address(bob),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.disallowSelectors(_entries[1]);

        vm.startPrank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(executeSelectorCondition),
                address(carol),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        executeSelectorCondition.disallowSelectors(_entries[1]);
    }

    function test_RevertGiven_TheSelectorIsNotAllowed()
        external
        whenCallingRemoveSelector
    {
        // It should revert

        dao.grant(
            address(executeSelectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](3);
        _entries[0].selectors = new bytes4[](1);
        _entries[0].selectors[0] = bytes4(uint32(1));
        _entries[0].where = address(this);
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = DAO.execute.selector;
        _entries[1].where = address(dao);
        _entries[2].selectors = new bytes4[](1);
        _entries[2].selectors[0] = DAO.setMetadata.selector;
        _entries[2].where = address(dao);

        // KO
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ExecuteSelectorCondition.AlreadyDisallowed.selector,
                bytes4(uint32(1)),
                address(this)
            )
        );
        executeSelectorCondition.disallowSelectors(_entries[0]);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExecuteSelectorCondition.AlreadyDisallowed.selector,
                DAO.execute.selector,
                address(dao)
            )
        );
        executeSelectorCondition.disallowSelectors(_entries[1]);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExecuteSelectorCondition.AlreadyDisallowed.selector,
                DAO.setMetadata.selector,
                address(dao)
            )
        );
        executeSelectorCondition.disallowSelectors(_entries[2]);
    }

    function test_GivenTheCallerHasPermission2()
        external
        whenCallingRemoveSelector
    {
        // It should succeed
        // It should emit an event
        // It allowedSelectors should return false

        // Permission
        dao.grant(
            address(executeSelectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        ExecuteSelectorCondition.SelectorTarget[]
            memory _entries = new ExecuteSelectorCondition.SelectorTarget[](3);
        _entries[0].selectors = new bytes4[](1);
        _entries[0].selectors[0] = DAO.setMetadata.selector;
        _entries[0].where = address(dao);
        _entries[1].selectors = new bytes4[](1);
        _entries[1].selectors[0] = DAO.execute.selector;
        _entries[1].where = address(dao);
        _entries[2].selectors = new bytes4[](1);
        _entries[2].selectors[0] = ExecuteSelectorCondition
            .allowSelectors
            .selector;
        _entries[2].where = address(executeSelectorCondition);

        // allow first
        vm.startPrank(bob);
        executeSelectorCondition.allowSelectors(_entries[0]);
        executeSelectorCondition.allowSelectors(_entries[1]);
        executeSelectorCondition.allowSelectors(_entries[2]);

        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.setMetadata.selector
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.execute.selector
            )
        );
        vm.assertTrue(
            executeSelectorCondition.allowedSelectors(
                address(executeSelectorCondition),
                ExecuteSelectorCondition.allowSelectors.selector
            )
        );

        // Then remove
        vm.expectEmit();
        emit SelectorDisallowed(DAO.setMetadata.selector, address(dao));
        executeSelectorCondition.disallowSelectors(_entries[0]);

        vm.expectEmit();
        emit SelectorDisallowed(DAO.execute.selector, address(dao));
        executeSelectorCondition.disallowSelectors(_entries[1]);

        vm.expectEmit();
        emit SelectorDisallowed(
            ExecuteSelectorCondition.allowSelectors.selector,
            address(executeSelectorCondition)
        );
        executeSelectorCondition.disallowSelectors(_entries[2]);

        // Now false
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.setMetadata.selector
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(dao),
                DAO.execute.selector
            )
        );
        assertFalse(
            executeSelectorCondition.allowedSelectors(
                address(executeSelectorCondition),
                ExecuteSelectorCondition.allowSelectors.selector
            )
        );
    }

    function test_WhenCallingSupportsInterface() external view {
        // It does not support the empty interface
        // It supports IPermissionCondition

        // It does not support the empty interface
        bool supported = executeSelectorCondition.supportsInterface(
            bytes4(0xffffffff)
        );
        assertEq(supported, false, "Should not support the empty interface");

        // It supports IERC165Upgradeable
        supported = executeSelectorCondition.supportsInterface(
            type(IERC165Upgradeable).interfaceId
        );
        assertEq(supported, true, "Should support IERC165Upgradeable");

        // It supports IPermissionCondition
        supported = executeSelectorCondition.supportsInterface(
            type(IPermissionCondition).interfaceId
        );
        assertEq(supported, true, "Should support IPermissionCondition");
    }
}
