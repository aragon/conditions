// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IMembership} from "@aragon/osx-commons-contracts/src/plugin/extensions/membership/IMembership.sol";

/// @title OnlyMemberCondition
/// @author AragonX 2025
/// @notice A permission that only allows Members of a given target to make use of a granted permission.
contract OnlyMemberCondition is ERC165, IPermissionCondition {
    IMembership public target;

    /// @notice Thrown when given address is not compatible with IMembership.
    /// @param invalidAddress The address received.
    error InvalidAddress(address invalidAddress);

    constructor(IMembership _target)  {
        // Check if the given address is compatible with a Safe
        (bool success, bytes memory result) =
            address(_target).staticcall(abi.encodeWithSelector(IMembership.isMember.selector, address(0)));
        if (!success || result.length != 32) {
            revert InvalidAddress(address(_target));
        }

	      target = _target;
    }

    /// @inheritdoc IPermissionCondition
    function isGranted(address _where, address _who, bytes32 _permissionId, bytes calldata _data)
        public
        view
        virtual
        returns (bool)
    {
        (_where, _permissionId, _data);

        (bool success, bytes memory result) =
            address(target).staticcall(abi.encodeWithSelector(IMembership.isMember.selector, _who));
        // If the call failed or returned malformed data, treat as "not member"
        if (!success || result.length != 32) {
            return false;
        }

        return abi.decode(result, (bool));
    }

    /// @notice Checks if an interface is supported by this or its parent contract.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IPermissionCondition).interfaceId || super.supportsInterface(_interfaceId);
    }
}
