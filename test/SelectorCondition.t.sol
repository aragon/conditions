// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";
import {ConditionFactory} from "../../src/factory/ConditionFactory.sol";
import {EXECUTE_PERMISSION_ID, SET_METADATA_PERMISSION_ID, MANAGE_SELECTORS_PERMISSION_ID} from "./constants.sol";

contract SelectorConditionTest is AragonTest {
    DaoBuilder builder;
    DAO dao;
    ConditionFactory factory;
    SelectorCondition selectorCondition;

    event SelectorAllowed(bytes4 selector);
    event SelectorDisallowed(bytes4 selector);

    function setUp() public {
        vm.startPrank(alice);
        builder = new DaoBuilder();
        (dao, factory, , selectorCondition) = builder.build();
    }

    function test_WhenDeployingTheContract() external {
        // It should set the given DAO
        // It should define the given selectors as allowed

        vm.assertEq(address(selectorCondition.dao()), address(dao));
        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0)));
        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0x11223344)));
        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0x55667788)));
        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0xffffffff)));

        // 1
        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = bytes4(0x11223344);
        _selectors[1] = bytes4(0x55667788);
        selectorCondition = new SelectorCondition(dao, _selectors);

        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0)));
        vm.assertTrue(selectorCondition.allowedSelectors(bytes4(0x11223344)));
        vm.assertTrue(selectorCondition.allowedSelectors(bytes4(0x55667788)));
        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0xffffffff)));

        // 2
        _selectors = new bytes4[](2);
        _selectors[0] = bytes4(0x00008888);
        _selectors[1] = bytes4(0x2222aaaa);
        selectorCondition = new SelectorCondition(dao, _selectors);

        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0)));
        vm.assertTrue(selectorCondition.allowedSelectors(bytes4(0x00008888)));
        vm.assertTrue(selectorCondition.allowedSelectors(bytes4(0x2222aaaa)));
        vm.assertFalse(selectorCondition.allowedSelectors(bytes4(0xffffffff)));
    }

    function test_RevertWhen_CallingADisallowedFunction() external {
        // It should revert

        bytes4[] memory _selectors = new bytes4[](0);
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(dao, _selectors)
        );

        // We have the permission, but the selector is not allowed
        dao.grantWithCondition(
            address(dao),
            bob,
            SET_METADATA_PERMISSION_ID,
            selectorCondition
        );
        vm.startPrank(bob);
        vm.expectRevert();
        dao.setMetadata("hi");

        // 2 permissions, only 1 selector allowed
        vm.startPrank(alice);
        dao.revoke(address(dao), bob, SET_METADATA_PERMISSION_ID);

        _selectors = new bytes4[](1);
        _selectors[0] = DAO.setMetadata.selector;
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(dao, _selectors)
        );
        dao.revoke(address(dao), bob, SET_METADATA_PERMISSION_ID);
        dao.grantWithCondition(
            address(dao),
            bob,
            SET_METADATA_PERMISSION_ID,
            selectorCondition
        );
        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            selectorCondition
        );

        vm.startPrank(bob);

        // works
        dao.setMetadata("ipfs://");

        // fails
        Action[] memory _actions = new Action[](0);
        vm.expectRevert();
        dao.execute(bytes32(0), _actions, 0);
    }

    function test_WhenCallingAnAllowedFunction() external {
        // It should allow execution

        // Fail (no permission)

        vm.startPrank(bob);
        vm.expectRevert();
        dao.setMetadata("ipfs://");

        Action[] memory _actions = new Action[](0);
        vm.expectRevert();
        dao.execute(bytes32(0), _actions, 0);

        // Fail (no selectors)

        vm.startPrank(alice);

        dao.grantWithCondition(
            address(dao),
            bob,
            SET_METADATA_PERMISSION_ID,
            selectorCondition
        );
        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            selectorCondition
        );

        vm.startPrank(bob);
        vm.expectRevert();
        dao.setMetadata("ipfs://");

        _actions = new Action[](0);
        vm.expectRevert();
        dao.execute(bytes32(0), _actions, 0);

        // Succeed (permission and selectors)

        vm.startPrank(alice);

        dao.revoke(address(dao), bob, SET_METADATA_PERMISSION_ID);
        dao.revoke(address(dao), bob, EXECUTE_PERMISSION_ID);

        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = DAO.setMetadata.selector;
        _selectors[1] = DAO.execute.selector;
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(dao, _selectors)
        );

        dao.grantWithCondition(
            address(dao),
            bob,
            SET_METADATA_PERMISSION_ID,
            selectorCondition
        );
        dao.grantWithCondition(
            address(dao),
            bob,
            EXECUTE_PERMISSION_ID,
            selectorCondition
        );

        vm.startPrank(bob);
        dao.setMetadata("ipfs://");
        dao.execute(bytes32(0), _actions, 0);
    }

    modifier whenCallingIsGranted() {
        _;
    }

    function test_GivenTheCalldataReferencesADisallowedSelector()
        external
        whenCallingIsGranted
    {
        // It should return false

        bytes4[] memory selectors = new bytes4[](0);
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(dao, selectors)
        );
        Action[] memory actions = new Action[](0);
        bytes memory _calldata = abi.encodeCall(DAO.execute, (0, actions, 0));

        // 1
        bool granted = selectorCondition.isGranted(
            address(0),
            address(0),
            bytes32(uint256(0)),
            _calldata
        );
        assertFalse(granted, "Should not be granted");

        // 2
        _calldata = abi.encodeCall(DAO.setMetadata, ("hi"));
        granted = selectorCondition.isGranted(
            address(dao),
            bob,
            bytes32(uint256(0x12345678)),
            _calldata
        );
        assertFalse(granted, "Should not be granted");
    }

    function test_GivenTheCalldataReferencesAnAllowedSelector()
        external
        whenCallingIsGranted
    {
        // It should return true

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = DAO.execute.selector;
        selectors[1] = DAO.setMetadata.selector;

        Action[] memory actions = new Action[](0);
        selectorCondition = SelectorCondition(
            factory.deploySelectorCondition(dao, selectors)
        );
        bytes memory _calldata = abi.encodeCall(DAO.execute, (0, actions, 0));

        // 1
        bool granted = selectorCondition.isGranted(
            address(0),
            address(0),
            bytes32(uint256(0)),
            _calldata
        );
        assertTrue(granted, "Should be granted");

        // 2
        _calldata = abi.encodeCall(DAO.setMetadata, ("hi"));
        granted = selectorCondition.isGranted(
            address(dao),
            bob,
            bytes32(uint256(0x12345678)),
            _calldata
        );
        assertTrue(granted, "Should be granted");

        // err
        _calldata = abi.encodeCall(DAO.setTrustedForwarder, (address(0)));
        granted = selectorCondition.isGranted(
            address(dao),
            bob,
            bytes32(uint256(0x12345678)),
            _calldata
        );
        assertFalse(granted, "Should not be granted");
    }

    modifier whenCallingAllowSelector() {
        _;
    }

    function test_RevertGiven_TheCallerHasNoPermission()
        external
        whenCallingAllowSelector
    {
        // It should revert

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(selectorCondition),
                address(alice),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        selectorCondition.allowSelector(bytes4(uint32(1)));

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(selectorCondition),
                address(bob),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        selectorCondition.allowSelector(bytes4(uint32(2)));

        vm.startPrank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(selectorCondition),
                address(carol),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        selectorCondition.allowSelector(bytes4(uint32(3)));

        // Now grant it
        vm.startPrank(alice);
        dao.grant(
            address(selectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        vm.startPrank(bob);
        selectorCondition.allowSelector(bytes4(uint32(3)));
    }

    function test_RevertGiven_TheSelectorIsAlreadyAllowed()
        external
        whenCallingAllowSelector
    {
        // It should revert

        dao.grant(
            address(selectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        // OK
        vm.startPrank(bob);
        selectorCondition.allowSelector(bytes4(uint32(1)));

        // KO
        vm.expectRevert(
            abi.encodeWithSelector(
                SelectorCondition.AlreadyAllowed.selector,
                bytes4(uint32(1))
            )
        );
        selectorCondition.allowSelector(bytes4(uint32(1)));
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
            selectorCondition.allowedSelectors(DAO.setMetadata.selector)
        );
        assertFalse(selectorCondition.allowedSelectors(DAO.execute.selector));
        assertFalse(
            selectorCondition.allowedSelectors(
                SelectorCondition.allowSelector.selector
            )
        );

        // Permission
        dao.grant(
            address(selectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        vm.startPrank(bob);
        vm.expectEmit();
        emit SelectorAllowed(DAO.setMetadata.selector);
        selectorCondition.allowSelector(DAO.setMetadata.selector);

        vm.expectEmit();
        emit SelectorAllowed(DAO.execute.selector);
        selectorCondition.allowSelector(DAO.execute.selector);

        vm.expectEmit();
        emit SelectorAllowed(SelectorCondition.allowSelector.selector);
        selectorCondition.allowSelector(
            SelectorCondition.allowSelector.selector
        );

        // Now true
        vm.assertTrue(
            selectorCondition.allowedSelectors(DAO.setMetadata.selector)
        );
        vm.assertTrue(selectorCondition.allowedSelectors(DAO.execute.selector));
        vm.assertTrue(
            selectorCondition.allowedSelectors(
                SelectorCondition.allowSelector.selector
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

        dao.grant(
            address(selectorCondition),
            alice,
            MANAGE_SELECTORS_PERMISSION_ID
        );
        selectorCondition.allowSelector(DAO.execute.selector);
        selectorCondition.allowSelector(DAO.setMetadata.selector);
        dao.revoke(
            address(selectorCondition),
            alice,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        // Try to remove

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(selectorCondition),
                address(alice),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        selectorCondition.disallowSelector(DAO.execute.selector);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(selectorCondition),
                address(bob),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        selectorCondition.disallowSelector(DAO.execute.selector);

        vm.startPrank(carol);
        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(selectorCondition),
                address(carol),
                MANAGE_SELECTORS_PERMISSION_ID
            )
        );
        selectorCondition.disallowSelector(DAO.setMetadata.selector);
    }

    function test_RevertGiven_TheSelectorIsNotAllowed()
        external
        whenCallingRemoveSelector
    {
        // It should revert

        dao.grant(
            address(selectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        // KO
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                SelectorCondition.AlreadyDisallowed.selector,
                bytes4(uint32(1))
            )
        );
        selectorCondition.disallowSelector(bytes4(uint32(1)));

        vm.expectRevert(
            abi.encodeWithSelector(
                SelectorCondition.AlreadyDisallowed.selector,
                DAO.execute.selector
            )
        );
        selectorCondition.disallowSelector(DAO.execute.selector);

        vm.expectRevert(
            abi.encodeWithSelector(
                SelectorCondition.AlreadyDisallowed.selector,
                DAO.setMetadata.selector
            )
        );
        selectorCondition.disallowSelector(DAO.setMetadata.selector);
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
            address(selectorCondition),
            bob,
            MANAGE_SELECTORS_PERMISSION_ID
        );

        // allow first
        vm.startPrank(bob);
        selectorCondition.allowSelector(DAO.setMetadata.selector);
        selectorCondition.allowSelector(DAO.execute.selector);
        selectorCondition.allowSelector(
            SelectorCondition.allowSelector.selector
        );

        vm.assertTrue(
            selectorCondition.allowedSelectors(DAO.setMetadata.selector)
        );
        vm.assertTrue(selectorCondition.allowedSelectors(DAO.execute.selector));
        vm.assertTrue(
            selectorCondition.allowedSelectors(
                SelectorCondition.allowSelector.selector
            )
        );

        // Then remove
        vm.expectEmit();
        emit SelectorDisallowed(DAO.setMetadata.selector);
        selectorCondition.disallowSelector(DAO.setMetadata.selector);

        vm.expectEmit();
        emit SelectorDisallowed(DAO.execute.selector);
        selectorCondition.disallowSelector(DAO.execute.selector);

        vm.expectEmit();
        emit SelectorDisallowed(SelectorCondition.allowSelector.selector);
        selectorCondition.disallowSelector(
            SelectorCondition.allowSelector.selector
        );

        // Now false
        assertFalse(
            selectorCondition.allowedSelectors(DAO.setMetadata.selector)
        );
        assertFalse(selectorCondition.allowedSelectors(DAO.execute.selector));
        assertFalse(
            selectorCondition.allowedSelectors(
                SelectorCondition.allowSelector.selector
            )
        );
    }

    function test_WhenCallingSupportsInterface() external view {
        // It does not support the empty interface
        // It supports IPermissionCondition

        // It does not support the empty interface
        bool supported = selectorCondition.supportsInterface(
            bytes4(0xffffffff)
        );
        assertEq(supported, false, "Should not support the empty interface");

        // It supports IERC165Upgradeable
        supported = selectorCondition.supportsInterface(
            type(IERC165Upgradeable).interfaceId
        );
        assertEq(supported, true, "Should support IERC165Upgradeable");

        // It supports IPermissionCondition
        supported = selectorCondition.supportsInterface(
            type(IPermissionCondition).interfaceId
        );
        assertEq(supported, true, "Should support IPermissionCondition");
    }
}
