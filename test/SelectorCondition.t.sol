// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {AragonTest} from "./base/AragonTest.sol";
import {DaoBuilder} from "./helpers/DaoBuilder.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {SelectorCondition} from "../src/SelectorCondition.sol";
import {ConditionFactory} from "../../src/factory/ConditionFactory.sol";
import {EXECUTE_PERMISSION_ID, SET_METADATA_PERMISSION_ID} from "./constants.sol";

contract SelectorConditionTest is AragonTest {
    DaoBuilder builder;
    DAO dao;
    ConditionFactory factory;
    SelectorCondition selectorCondition;

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
        IDAO.Action[] memory _actions = new IDAO.Action[](0);
        vm.expectRevert();
        dao.execute(bytes32(0), _actions, 0);
    }

    function test_WhenCallingAnAllowedFunction() external {
        // It should allow execution

        // Fail (no permission)

        vm.startPrank(bob);
        vm.expectRevert();
        dao.setMetadata("ipfs://");

        IDAO.Action[] memory _actions = new IDAO.Action[](0);
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

        _actions = new IDAO.Action[](0);
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

        // bytes4[] memory selectors = new bytes4[](0);
        // IDAO.Action[] memory actions = new IDAO.Action[](0);
        // selectorCondition = SelectorCondition(
        //     factory.deploySelectorCondition(dao, selectors)
        // );
        // bytes memory _calldata = abi.encodeCall(DAO.execute, (0, actions, 0));

        vm.skip(true);
    }

    function test_GivenTheCalldataReferencesAnAllowedSelector()
        external
        whenCallingIsGranted
    {
        // It should return true
        vm.skip(true);
    }

    modifier whenCallingAllowSelector() {
        _;
    }

    function test_RevertGiven_TheCallerHasNoPermission()
        external
        whenCallingAllowSelector
    {
        // It should revert
        vm.skip(true);
    }

    function test_RevertGiven_TheSelectorIsAlreadyAllowed()
        external
        whenCallingAllowSelector
    {
        // It should revert
        vm.skip(true);
    }

    function test_GivenTheCallerHasPermission()
        external
        whenCallingAllowSelector
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
