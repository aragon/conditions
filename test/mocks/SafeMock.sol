// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IOwnerManager} from "../../src/interfaces/IOwnerManager.sol";

contract SafeMock is IOwnerManager {
    mapping(address => bool) owners;

    function addOwnerWithThreshold(address owner, uint256 _threshold) external {}

    function removeOwner(address prevOwner, address owner, uint256 _threshold) external {}

    function swapOwner(address prevOwner, address oldOwner, address newOwner) external {}

    function changeThreshold(uint256 _threshold) external {}

    function getThreshold() external view returns (uint256) {}

    function isOwner(address _owner) external view returns (bool) {
        return owners[_owner];
    }

    function getOwners() external view returns (address[] memory) {}

    // Test setters
    function setOwner(address _who) public {
        owners[_who] = true;
    }

    function unsetOwner(address _who) public {
        owners[_who] = false;
    }
}
