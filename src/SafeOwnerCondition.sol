// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {DaoAuthorizable} from "@aragon/osx-commons-contracts/src/permission/auth/DaoAuthorizable.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IOwnerManager} from "./interfaces/IOwnerManager.sol";

/// @title SafeOwnerCondition
/// @author AragonX 2025
/// @notice A permission that only allows Safe owners to make use of a granted permission.
contract SafeOwnerCondition is ERC165, IPermissionCondition, DaoAuthorizable {
    IOwnerManager public safe;

    /// @notice Thrown when the address of the given Safe is empty or incompatible.
    /// @param givenSafe The invalid address received
    error InvalidSafe(address givenSafe);

    constructor(IDAO _dao, IOwnerManager _safe) DaoAuthorizable(_dao) {
        if (address(_safe) == address(0)) {
            revert InvalidSafe(address(_safe));
        }

        try IERC165(address(_safe)).supportsInterface(type(IOwnerManager).interfaceId) returns (bool _supported) {
            if (!_supported) {
                revert InvalidSafe(address(_safe));
            }
        } catch {
            revert InvalidSafe(address(_safe));
        }

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

        return safe.isOwner(_who);
    }

    /// @notice Checks if an interface is supported by this or its parent contract.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IPermissionCondition).interfaceId || super.supportsInterface(_interfaceId);
    }
}
