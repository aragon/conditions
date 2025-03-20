// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.17;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {DaoAuthorizable} from "@aragon/osx/core/plugin/dao-authorizable/DaoAuthorizable.sol";
import {IPermissionCondition} from "@aragon/osx/core/permission/IPermissionCondition.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";

/// @title SelectorCondition
/// @author AragonX 2025
/// @notice A permission that only allows a specified group of function selectors to be invoked within DAO.execute()
contract SelectorCondition is ERC165, DaoAuthorizable, IPermissionCondition {
    mapping(bytes4 => bool) public allowedSelectors;

    bytes32 constant MANAGE_SELECTORS_PERMISSION_ID =
        keccak256("MANAGE_SELECTORS_PERMISSION");

    error AlreadyAllowed();
    error AlreadyDisallowed();

    event SelectorAllowed(bytes4 selector);
    event SelectorDisallowed(bytes4 selector);

    /// @notice Disables the initializers on the implementation contract to prevent it from being left uninitialized.
    constructor(
        IDAO _dao,
        bytes4[] memory _initialSelectors
    ) DaoAuthorizable(_dao) {
        for (uint256 i; i < _initialSelectors.length; ) {
            allowedSelectors[_initialSelectors[i]] = true;
            unchecked {
                i++;
            }
        }
    }

    /// @notice Marks the given selector as allowed
    /// @param _selector The function selector to start allowing
    function allowSelector(
        bytes4 _selector
    ) public auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (allowedSelectors[_selector]) revert AlreadyAllowed();
        allowedSelectors[_selector] = true;

        emit SelectorAllowed(_selector);
    }

    /// @notice Marks the given selector as disallowed
    /// @param _selector The function selector to stop allowing
    function disallowSelector(
        bytes4 _selector
    ) public auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (!allowedSelectors[_selector]) revert AlreadyDisallowed();
        allowedSelectors[_selector] = false;

        emit SelectorDisallowed(_selector);
    }

    /// @inheritdoc IPermissionCondition
    function isGranted(
        address _where,
        address _who,
        bytes32 _permissionId,
        bytes calldata _data
    ) external view returns (bool isPermitted) {
        (_where, _who, _permissionId);

        return allowedSelectors[_getSelector(_data)];
    }

    /// @notice Checks if an interface is supported by this or its parent contract.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(
        bytes4 _interfaceId
    ) public view virtual override returns (bool) {
        return
            _interfaceId == type(IPermissionCondition).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    // Internal helpers

    function _getSelector(
        bytes memory _data
    ) internal pure returns (bytes4 selector) {
        // Slices are only supported for bytes calldata, not bytes memory
        // Bytes memory requires an assembly block
        assembly {
            selector := mload(add(_data, 0x20)) // 32
        }
    }
}
