// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {DaoAuthorizable} from "@aragon/osx-commons-contracts/src/permission/auth/DaoAuthorizable.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IExecutor, Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {getSelector} from "./lib/common.sol";

/// @title ExecuteSelectorCondition
/// @author AragonX 2025
/// @notice A permission that only allows a specified group of function selectors to be invoked within DAO.execute()
contract ExecuteSelectorCondition is
    ERC165,
    IPermissionCondition,
    DaoAuthorizable
{
    /// @notice Contains a list of selectors for the given target (where) address
    struct SelectorTarget {
        /// @notice The address where the selectors below can be invoked
        address where;
        /// @notice The list of function selectors that can be invoked within an execute() call.
        /// @notice Plain eth transfers should contain 0 as the selector.
        bytes4[] selectors;
    }

    /// @notice Stores whether the given address and selector are allowed
    /// @dev allowedSelectors[where][selector]
    mapping(address => mapping(bytes4 => bool)) public allowedSelectors;

    /// @notice Stores whether eth transfers are allowed to the given target address
    mapping(address => bool) public allowedEthTransfers;

    bytes32 public constant MANAGE_SELECTORS_PERMISSION_ID =
        keccak256("MANAGE_SELECTORS_PERMISSION");

    /// @notice Thrown when alowing an empty selector. Ether transfers and fallback functions are out the scope of this condition.
    error EmptySelector();

    /// @notice Emitted when a new selector is allowed.
    event SelectorAllowed(bytes4 selector, address where);
    /// @notice Emitted when a selector is disallowed.
    event SelectorDisallowed(bytes4 selector, address where);
    /// @notice Emitted when eth transfers are allowed to the given address
    event EthTransfersAllowed(address where);
    /// @notice Emitted when eth transfers are disallowed to the given address
    event EthTransfersDisallowed(address where);

    /// @notice Configures a new instance with the given set of allowed selectors
    /// @param _dao The address of the DAO where the contract should read the permissions from
    /// @param _initialEntries The list of allowed selectors and the addresses where they can be invoked
    constructor(
        IDAO _dao,
        SelectorTarget[] memory _initialEntries
    ) DaoAuthorizable(_dao) {
        for (uint256 i; i < _initialEntries.length; i++) {
            _allowSelectors(_initialEntries[i]);
        }
    }

    /// @notice Marks the given selectors as allowed on the given where address
    /// @param _newEntry The new selectors and the address where they can be invoked
    function allowSelectors(
        SelectorTarget memory _newEntry
    ) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        _allowSelectors(_newEntry);
    }

    /// @notice Marks the given selector(s) as disallowed
    /// @param _entry The selectors to remove and the address where they can no longer be invoked
    function disallowSelectors(
        SelectorTarget memory _entry
    ) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        _disallowSelectors(_entry);
    }

    /// @notice Allows actions with a non-zero `value` to pass for the given target address
    /// @param _where The target address
    function allowEthTransfers(
        address _where
    ) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (allowedEthTransfers[_where]) return;

        _allowEthTransfers(_where);
    }

    /// @notice Restricts actions with a non-zero `value` for the given target address
    /// @param _where The target address
    function disallowEthTransfers(
        address _where
    ) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (!allowedEthTransfers[_where]) return;

        _disallowEthTransfers(_where);
    }

    /// @inheritdoc IPermissionCondition
    function isGranted(
        address _where,
        address _who,
        bytes32 _permissionId,
        bytes calldata _data
    ) public view virtual returns (bool isPermitted) {
        (_where, _who, _permissionId);

        // Calling execute()?
        if (getSelector(_data) != IExecutor.execute.selector) {
            return false;
        }

        // Decode proposal params
        (, Action[] memory _actions, ) = abi.decode(
            _data[4:],
            (bytes32, Action[], uint256)
        );
        for (uint256 i; i < _actions.length; i++) {
            if (_actions[i].data.length == 0) {
                if (_actions[i].value == 0) return false;
                else if(!allowedEthTransfers[_actions[i].to]) return false;
            } else if (_actions[i].data.length < 4) {
                return false;
            } else if (
                !allowedSelectors[_actions[i].to][getSelector(_actions[i].data)]
            ) {
                return false;
            } else if (
                _actions[i].value != 0 && !allowedEthTransfers[_actions[i].to]
            ) {
                return false;
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

    function _allowSelectors(SelectorTarget memory _newEntry) internal virtual {
        for (uint256 i; i < _newEntry.selectors.length; i++) {
            if (allowedSelectors[_newEntry.where][_newEntry.selectors[i]]) {
                // The requested state is already in place
                continue;
            }
            allowedSelectors[_newEntry.where][_newEntry.selectors[i]] = true;
            emit SelectorAllowed(_newEntry.selectors[i], _newEntry.where);
        }
    }

    function _disallowSelectors(SelectorTarget memory _entry) internal virtual {
        for (uint256 i; i < _entry.selectors.length; i++) {
            if (!allowedSelectors[_entry.where][_entry.selectors[i]]) {
                // The requested state is already in place
                continue;
            }
            allowedSelectors[_entry.where][_entry.selectors[i]] = false;
            emit SelectorDisallowed(_entry.selectors[i], _entry.where);
        }
    }

    function _allowEthTransfers(address _where) internal virtual {
        allowedEthTransfers[_where] = true;
        emit EthTransfersAllowed(_where);
    }

    function _disallowEthTransfers(address _where) internal virtual {
        allowedEthTransfers[_where] = false;
        emit EthTransfersDisallowed(_where);
    }
}
