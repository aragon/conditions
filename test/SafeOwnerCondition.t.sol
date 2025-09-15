// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {AragonTest} from "./base/AragonTest.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {SafeOwnerCondition, IOwnerManager} from "../src/SafeOwnerCondition.sol";
import {SafeMock} from "./mocks/SafeMock.sol";

contract SafeOwnerConditionTest is AragonTest {
    SafeMock safeMock;
    SafeOwnerCondition safeOwnerCondition;

    error InvalidSafe(address givenSafe);

    function setUp() public {
        vm.startPrank(alice);

        safeMock = new SafeMock();
        safeOwnerCondition = new SafeOwnerCondition(safeMock);
    }

    modifier whenDeployingTheContract() {
        _;
    }

    function test_WhenDeployingTheContract() external view whenDeployingTheContract {
        // It should define the given safe address

        assertEq(address(safeOwnerCondition.safe()), address(safeMock));
    }

    function test_RevertGiven_AnEmptyAddress() external whenDeployingTheContract {
        // It should revert

        vm.expectRevert(abi.encodeWithSelector(InvalidSafe.selector, address(0)));
        new SafeOwnerCondition(IOwnerManager(address(0)));
    }

    function test_RevertGiven_AContractThatIsNotASafe() external whenDeployingTheContract {
        // It should revert

        assertEq(IERC165(address(safeOwnerCondition.safe())).supportsInterface(type(IOwnerManager).interfaceId), true);
        assertEq(IERC165(address(safeOwnerCondition.safe())).supportsInterface(0x12345678), false);

        vm.expectRevert(abi.encodeWithSelector(InvalidSafe.selector, address(this)));
        new SafeOwnerCondition(IOwnerManager(address(this)));
    }

    modifier whenCallingIsGranted() {
        _;
    }

    function testFuzz_GivenTheGivenWhoIsNotASafeMember(address randomMember) external view whenCallingIsGranted {
        // It should return false

        assertEq(safeOwnerCondition.isGranted(address(0), randomMember, 0, bytes("")), false);
    }

    function testFuzz_GivenTheGivenWhoIsASafeMember(address randomMember) external whenCallingIsGranted {
        // It should return true

        safeMock.setOwner(randomMember);

        assertEq(safeOwnerCondition.isGranted(address(0), randomMember, 0, bytes("")), true);
    }

    function test_WhenCallingSupportsInterface() external view {
        // It does not support the empty interface
        // It supports IPermissionCondition

        bool supported = safeOwnerCondition.supportsInterface(bytes4(0xffffffff));
        assertEq(supported, false, "Should not support the empty interface");

        // It supports IERC165Upgradeable
        supported = safeOwnerCondition.supportsInterface(type(IERC165).interfaceId);
        assertEq(supported, true, "Should support IERC165");

        // It supports IPermissionCondition
        supported = safeOwnerCondition.supportsInterface(type(IPermissionCondition).interfaceId);
        assertEq(supported, true, "Should support IPermissionCondition");
    }
}
