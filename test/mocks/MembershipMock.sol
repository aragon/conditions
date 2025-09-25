// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMembership} from "@aragon/osx-commons-contracts/src/plugin/extensions/membership/IMembership.sol";

contract MembershipMock is IMembership {
    mapping(address => bool) members;

    function isMember(address _account) external view returns (bool) {
        return members[_account];
    }

    // Test setters
    function setMember(address _who) public {
        members[_who] = true;
    }

    function unsetMember(address _who) public {
        members[_who] = false;
    }
}
