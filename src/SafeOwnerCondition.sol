// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IOwnerManager} from "./interfaces/IOwnerManager.sol";

/// @title SafeOwnerCondition
/// @author AragonX 2025
/// @notice A permission that only allows Safe owners to make use of a granted permission.
contract SafeOwnerCondition is ERC165, IPermissionCondition {
    IOwnerManager public safe;

    /// @notice Thrown when given address is not a compatible Safe.
    /// @param invalidAddress The address received.
    error InvalidSafe(address invalidAddress);

    constructor(IOwnerManager _safe) {
        // Check if the given address is compatible with a Safe
        (bool success, bytes memory result) =
            address(_safe).staticcall(abi.encodeWithSelector(IOwnerManager.isOwner.selector, address(0)));
        if (!success || result.length != 32) {
            revert InvalidSafe(address(_safe));
        }
        abi.decode(result, (bool));

        safe = _safe;
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
            address(safe).staticcall(abi.encodeWithSelector(IOwnerManager.isOwner.selector, _who));

        // If the call failed or returned malformed data, treat as "not owner"
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
