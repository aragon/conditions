// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {DaoAuthorizable} from "@aragon/osx-commons-contracts/src/permission/auth/DaoAuthorizable.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {getSelector} from "./lib/common.sol";

/// @title SelectorCondition
/// @author AragonX 2025
/// @notice A permission that only allows a specified group of function selectors to be invoked within DAO.execute()
contract SelectorCondition is ERC165, IPermissionCondition, DaoAuthorizable {
    mapping(bytes4 => bool) public allowedSelectors;

    bytes32 public constant MANAGE_SELECTORS_PERMISSION_ID =
        keccak256("MANAGE_SELECTORS_PERMISSION");

    error AlreadyAllowed(bytes4 selector);
    error AlreadyDisallowed(bytes4 selector);

    event SelectorAllowed(bytes4 selector);
    event SelectorDisallowed(bytes4 selector);

    constructor(
        IDAO _dao,
        bytes4[] memory _initialSelectors
    ) DaoAuthorizable(_dao) {
        for (uint256 i; i < _initialSelectors.length; i++) {
            allowedSelectors[_initialSelectors[i]] = true;
            emit SelectorAllowed(_initialSelectors[i]);
        }
    }

    /// @notice Marks the given selector as allowed
    /// @param _selector The function selector to start allowing
    function allowSelector(
        bytes4 _selector
    ) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (allowedSelectors[_selector]) revert AlreadyAllowed(_selector);
        allowedSelectors[_selector] = true;

        emit SelectorAllowed(_selector);
    }

    /// @notice Marks the given selector as disallowed
    /// @param _selector The function selector to stop allowing
    function disallowSelector(
        bytes4 _selector
    ) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (!allowedSelectors[_selector]) revert AlreadyDisallowed(_selector);
        allowedSelectors[_selector] = false;

        emit SelectorDisallowed(_selector);
    }

    /// @inheritdoc IPermissionCondition
    function isGranted(
        address _where,
        address _who,
        bytes32 _permissionId,
        bytes calldata _data
    ) public view virtual returns (bool isPermitted) {
        (_where, _who, _permissionId);

        return allowedSelectors[getSelector(_data)];
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
}
