// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {DaoAuthorizable} from "@aragon/osx-commons-contracts/src/permission/auth/DaoAuthorizable.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IExecutor, Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";

/// @title ExecuteSelectorCondition
/// @author AragonX 2025
/// @notice A permission that only allows a specified group of function selectors to be invoked within DAO.execute()
contract ExecuteSelectorCondition is
    ERC165,
    DaoAuthorizable,
    IPermissionCondition
{
    struct InitialTarget {
        bytes4 selector;
        address target;
    }
    /// @notice Stores whether the given address and selector are allowed
    /// @dev allowedTargets[where][selector]
    mapping(address => mapping(bytes4 => bool)) public allowedTargets;

    bytes32 immutable MANAGE_SELECTORS_PERMISSION_ID =
        keccak256("MANAGE_SELECTORS_PERMISSION");

    error AlreadyAllowed();
    error AlreadyDisallowed();

    event SelectorAllowed(bytes4 selector, address target);
    event SelectorDisallowed(bytes4 selector, address target);

    /// @notice Disables the initializers on the implementation contract to prevent it from being left uninitialized.
    constructor(
        IDAO _dao,
        InitialTarget[] memory _initialTargets
    ) DaoAuthorizable(_dao) {
        for (uint256 i; i < _initialTargets.length; ) {
            allowedTargets[_initialTargets[i].target][
                _initialTargets[i].selector
            ] = true;
            unchecked {
                i++;
            }
        }
    }

    /// @notice Marks the given selector as allowed
    /// @param _selector The function selector to start allowing
    /// @param _target The target address where the selector can be invoked
    function allowSelector(
        bytes4 _selector,
        address _target
    ) public auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (allowedTargets[_target][_selector]) revert AlreadyAllowed();
        allowedTargets[_target][_selector] = true;

        emit SelectorAllowed(_selector, _target);
    }

    /// @notice Marks the given selector as disallowed
    /// @param _selector The function selector to stop allowing
    /// @param _target The target address where the selector can no longer be invoked
    function disallowSelector(
        bytes4 _selector,
        address _target
    ) public auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (!allowedTargets[_target][_selector]) revert AlreadyDisallowed();
        allowedTargets[_target][_selector] = false;

        emit SelectorDisallowed(_selector, _target);
    }

    /// @inheritdoc IPermissionCondition
    function isGranted(
        address _where,
        address _who,
        bytes32 _permissionId,
        bytes calldata _data
    ) external view returns (bool isPermitted) {
        (_where, _who, _permissionId);

        // Is it execute()?
        if (_getSelector(_data) != IExecutor.execute.selector) {
            return false;
        }

        // Decode proposal params
        (, Action[] memory _actions, ) = abi.decode(
            _data[4:],
            (bytes32, Action[], uint256)
        );
        for (uint256 i; i < _actions.length; ) {
            if (!allowedTargets[_actions[i].to][_getSelector(_actions[i].data)])
                return false;
            unchecked {
                i++;
            }
        }
        return true;
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
