// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {AragonTest} from "./base/AragonTest.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {OnlyMemberCondition} from "../src/OnlyMemberCondition.sol";
import {IMembership} from "@aragon/osx-commons-contracts/src/plugin/extensions/membership/IMembership.sol";
import {MembershipMock} from "./mocks/MembershipMock.sol";

contract OnlyMemberConditionTest is AragonTest {
    MembershipMock membershipMock;
    OnlyMemberCondition onlyMemberCondition;

    error InvalidAddress(address invalidAddress);

    function setUp() public {
        vm.startPrank(alice);

        membershipMock = new MembershipMock();
        onlyMemberCondition = new OnlyMemberCondition(membershipMock);
    }

    modifier whenDeployingTheContract() {
        _;
    }

    function test_WhenDeployingTheContract() external view whenDeployingTheContract {
        // It should define the given target address

        assertEq(address(onlyMemberCondition.target()), address(membershipMock));
    }

    function test_RevertGiven_AnEmptyAddress() external whenDeployingTheContract {
        // It should revert

        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(0)));
        new OnlyMemberCondition(IMembership(address(0)));
    }

    function test_RevertGiven_AContractThatDoesNotImplementIMembership() external whenDeployingTheContract {
        // It should revert

        vm.expectRevert(abi.encodeWithSelector(InvalidAddress.selector, address(this)));
        new OnlyMemberCondition(IMembership(address(this)));
    }

    modifier whenCallingIsGranted() {
        _;
    }

    function testFuzz_GivenTheGivenWhoIsNotAMember(address randomMember) external view whenCallingIsGranted {
        // It should return false

        assertEq(onlyMemberCondition.isGranted(address(0), randomMember, 0, bytes("")), false);
    }

    function testFuzz_GivenTheGivenWhoIsAMember(address randomMember) external whenCallingIsGranted {
        // It should return true

        membershipMock.setMember(randomMember);

        assertEq(onlyMemberCondition.isGranted(address(0), randomMember, 0, bytes("")), true);
    }

    function test_WhenCallingSupportsInterface() external view {
        // It does not support the empty interface
        // It supports IPermissionCondition

        bool supported = onlyMemberCondition.supportsInterface(bytes4(0xffffffff));
        assertEq(supported, false, "Should not support the empty interface");

        // It supports IERC165
        supported = onlyMemberCondition.supportsInterface(type(IERC165).interfaceId);
        assertEq(supported, true, "Should support IERC165");

        // It supports IPermissionCondition
        supported = onlyMemberCondition.supportsInterface(type(IPermissionCondition).interfaceId);
        assertEq(supported, true, "Should support IPermissionCondition");
    }
}