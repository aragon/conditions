// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {DaoAuthorizable} from "@aragon/osx-commons-contracts/src/permission/auth/DaoAuthorizable.sol";
import {IPermissionCondition} from "@aragon/osx-commons-contracts/src/permission/condition/IPermissionCondition.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IExecutor, Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {getSelector, stripSelector} from "./lib/common.sol";

interface ICrossChainController {
    function forwardMessage(uint256 _destinationChainId, uint256 _gasLimit, bytes memory _message)
        external
        returns (bytes32 txId);

    function receiveMessage(uint256 _messageId, bytes memory _encodedTx, uint256 _originChainId)
        external
        returns (bytes32 txId);

    function retryMessage(bytes memory _encodedTx) external;
}

/// @title ExecuteSelectorCrossChainCondition
/// @author AragonX 2026
/// @notice A permission condition that restricts which function selectors (and native transfers) can be invoked
///         through DAO.execute(), with allowlists scoped per chain — covering both actions executed locally and
///         actions relayed to other chains through a CrossChainController.
/// @dev How it works:
///      - The condition intercepts calls to `execute()` and inspects each action in the batch.
///      - If an action's target does NOT support the `ICrossChainController` interface (checked via ERC-165),
///        it is a local action: its selector (or native transfer) must be allowed for `(block.chainid, target)`.
///      - If the target IS a CrossChainController, the action is a cross-chain relay: its calldata is decoded as
///        a `forwardMessage(destinationChainId, gasLimit, message)` payload, where `message` encodes the `Action[]`
///        to be executed on the destination chain. Each of those inner actions must then be allowed for
///        `(destinationChainId, innerTarget)`.
///      - Note on `value` for cross-chain actions: an inner action with a non-zero `value` is executed on the
///        destination chain, and the native tokens are paid out of the destination chain executor's balance —
///        not from the DAO on this chain. Therefore the current chain must also decide, via
///        `allowedNativeTransfers[destinationChainId][target]`, whether the destination chain's executor is
///        allowed to call the given target with value attached.
///      - Allowlists are managed per chain via `allowSelectors`/`disallowSelectors` and
///        `allowNativeTransfers`/`disallowNativeTransfers`, gated by `MANAGE_SELECTORS_PERMISSION`.
///        The overloads without a `chainId` parameter operate on the current chain (`block.chainid`).
///      - This lets a DAO on one chain constrain not only what its proposals can call locally, but also what
///        they can trigger remotely on every destination chain it bridges to.
contract ExecuteSelectorCrossChainCondition is ERC165, IPermissionCondition, DaoAuthorizable {
    using ERC165Checker for address;

    /// @notice Contains a list of selectors for the given target (where) address
    struct SelectorTarget {
        /// @notice The address where the selectors below can be invoked
        address where;
        /// @notice The list of function selectors that can be invoked within an execute() call.
        /// @notice Plain native transfers should contain 0 as the selector.
        bytes4[] selectors;
    }

    /// @notice Stores whether the given address and selector are allowed on the given chain
    /// @dev allowedSelectors[chainId][where][selector]
    mapping(uint256 => mapping(address => mapping(bytes4 => bool))) public allowedSelectors;

    /// @notice Stores whether native transfers are allowed to the given target address on the given chain
    /// @dev allowedNativeTransfers[chainId][where]
    mapping(uint256 => mapping(address => bool)) public allowedNativeTransfers;

    bytes32 public constant MANAGE_SELECTORS_PERMISSION_ID = keccak256("MANAGE_SELECTORS_PERMISSION");

    /// @notice Emitted when a new selector is allowed.
    /// @param chainId The chain on which the selector is allowed
    /// @param selector The function selector being allowed
    /// @param where The address on which the selector can be invoked
    event SelectorAllowed(uint256 chainId, bytes4 selector, address where);

    /// @notice Emitted when a selector is disallowed.
    /// @param chainId The chain on which the selector is no longer allowed
    /// @param selector The function selector being disallowed
    /// @param where The address on which the selector can no longer be invoked
    event SelectorDisallowed(uint256 chainId, bytes4 selector, address where);

    /// @notice Emitted when native transfers are allowed to the given address
    /// @param chainId The chain on which native transfers are allowed
    /// @param where The address to which native transfers are allowed
    event NativeTransfersAllowed(uint256 chainId, address where);

    /// @notice Emitted when native transfers are disallowed to the given address
    /// @param chainId The chain on which native transfers are no longer allowed
    /// @param where The address to which native transfers are no longer allowed
    event NativeTransfersDisallowed(uint256 chainId, address where);

    /// @notice Thrown when the given chain id's and selector entries have a different length
    error ChainIdsLengthMismatch(uint256 chainIds, uint256 entries);

    /// @notice Thrown when attempting to allow something on the chain id zero, which is not a valid chain
    error InvalidChainId();

    /// @notice Configures a new instance with the given set of allowed selectors
    /// @param _dao The address of the DAO where the contract should read the permissions from
    /// @param _chainIds The chain on which each of the entries below applies, matched by index.
    ///        Pass `block.chainid` for the entries that apply to the current chain.
    /// @param _initialEntries The list of allowed selectors and the addresses where they can be invoked
    constructor(IDAO _dao, uint256[] memory _chainIds, SelectorTarget[] memory _initialEntries) DaoAuthorizable(_dao) {
        if (_chainIds.length != _initialEntries.length) {
            revert ChainIdsLengthMismatch(_chainIds.length, _initialEntries.length);
        }

        for (uint256 i; i < _initialEntries.length; i++) {
            _allowSelectors(_chainIds[i], _initialEntries[i]);
        }
    }

    /// @notice Marks the given selectors as allowed on the given where address, on the current chain
    /// @param _newEntry The new selectors and the address where they can be invoked
    function allowSelectors(SelectorTarget memory _newEntry) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        _allowSelectors(block.chainid, _newEntry);
    }

    /// @notice Marks the given selectors as allowed on the given where address, on the given chain
    /// @param _chainId The chain on which the selectors can be invoked
    /// @param _newEntry The new selectors and the address where they can be invoked
    function allowSelectors(uint256 _chainId, SelectorTarget memory _newEntry)
        public
        virtual
        auth(MANAGE_SELECTORS_PERMISSION_ID)
    {
        _allowSelectors(_chainId, _newEntry);
    }

    /// @notice Marks the given selector(s) as disallowed on the current chain
    /// @param _entry The selectors to remove and the address where they can no longer be invoked
    function disallowSelectors(SelectorTarget memory _entry) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        _disallowSelectors(block.chainid, _entry);
    }

    /// @notice Marks the given selector(s) as disallowed on the given chain
    /// @param _chainId The chain on which the selectors can no longer be invoked
    /// @param _entry The selectors to remove and the address where they can no longer be invoked
    function disallowSelectors(uint256 _chainId, SelectorTarget memory _entry)
        public
        virtual
        auth(MANAGE_SELECTORS_PERMISSION_ID)
    {
        _disallowSelectors(_chainId, _entry);
    }

    /// @notice Allows actions with a non-zero `value` to pass for the given target address, on the current chain
    /// @param _where The target address
    function allowNativeTransfers(address _where) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (allowedNativeTransfers[block.chainid][_where]) return;

        _allowNativeTransfers(block.chainid, _where);
    }

    /// @notice Allows actions with a non-zero `value` to pass for the given target address, on the given chain
    /// @param _chainId The chain on which native transfers are allowed
    /// @param _where The target address
    function allowNativeTransfers(uint256 _chainId, address _where)
        public
        virtual
        auth(MANAGE_SELECTORS_PERMISSION_ID)
    {
        if (allowedNativeTransfers[_chainId][_where]) return;

        _allowNativeTransfers(_chainId, _where);
    }

    /// @notice Restricts actions with a non-zero `value` for the given target address, on the current chain
    /// @param _where The target address
    function disallowNativeTransfers(address _where) public virtual auth(MANAGE_SELECTORS_PERMISSION_ID) {
        if (!allowedNativeTransfers[block.chainid][_where]) return;

        _disallowNativeTransfers(block.chainid, _where);
    }

    /// @notice Restricts actions with a non-zero `value` for the given target address, on the given chain
    /// @param _chainId The chain on which native transfers are no longer allowed
    /// @param _where The target address
    function disallowNativeTransfers(uint256 _chainId, address _where)
        public
        virtual
        auth(MANAGE_SELECTORS_PERMISSION_ID)
    {
        if (!allowedNativeTransfers[_chainId][_where]) return;

        _disallowNativeTransfers(_chainId, _where);
    }

    /// @inheritdoc IPermissionCondition
    function isGranted(address _where, address _who, bytes32 _permissionId, bytes calldata _data)
        public
        view
        virtual
        returns (bool isPermitted)
    {
        (_where, _who, _permissionId);

        // Calling execute()?
        if (getSelector(_data) != IExecutor.execute.selector) {
            return false;
        }

        (, Action[] memory _actions,) = abi.decode(_data[4:], (bytes32, Action[], uint256));

        for (uint256 i = 0; i < _actions.length; i++) {
            // NOT CrossChain: check whether selector on same chain is supported.
            if (!_actions[i].to.supportsInterface(type(ICrossChainController).interfaceId)) {
                if (!_isActionAllowed(block.chainid, _actions[i])) return false;
                continue;
            }

            // CrossChain:
            // Check that `_actions[i].data` is at least length of 4
            // so selector can be decoded without revert.
            if (_actions[i].data.length < 4) return false;

            // Before decoding, check that action is calling forwardMessage on CrossChainController.
            if (getSelector(_actions[i].data) != ICrossChainController.forwardMessage.selector) {
                // Only allow if selector is forwardMessage on CrossChainController
                return false;
            }

            (uint256 dstChainId,/* uint256 gasLimit */, bytes memory message) =
                abi.decode(stripSelector(_actions[i].data), (uint256, uint256, bytes));

            Action[] memory innerActions = abi.decode(message, (Action[]));

            for (uint256 j = 0; j < innerActions.length; j++) {
                if (!_isActionAllowed(dstChainId, innerActions[j])) return false;
            }
        }

        return true;
    }

    /// @notice Checks whether a single action is allowed on the given chain
    /// @param _chainId The chain on which the action would be executed
    /// @param _action The action to check
    /// @return Returns `true` if the action's selector (or native transfer) is allowed
    function _isActionAllowed(uint256 _chainId, Action memory _action) internal view virtual returns (bool) {
        if (_action.data.length == 0) {
            if (_action.value == 0) return false;
            return allowedNativeTransfers[_chainId][_action.to];
        } else if (_action.data.length < 4) {
            return false;
        } else if (!allowedSelectors[_chainId][_action.to][getSelector(_action.data)]) {
            return false;
        } else if (_action.value != 0 && !allowedNativeTransfers[_chainId][_action.to]) {
            return false;
        }

        return true;
    }

    /// @notice Checks if an interface is supported by this or its parent contract.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IPermissionCondition).interfaceId || super.supportsInterface(_interfaceId);
    }

    // Internal helpers

    function _allowSelectors(uint256 _chainId, SelectorTarget memory _newEntry) internal virtual {
        if (_chainId == 0) revert InvalidChainId();

        for (uint256 i; i < _newEntry.selectors.length; i++) {
            if (allowedSelectors[_chainId][_newEntry.where][_newEntry.selectors[i]]) {
                // The requested state is already in place
                continue;
            }
            allowedSelectors[_chainId][_newEntry.where][_newEntry.selectors[i]] = true;
            emit SelectorAllowed(_chainId, _newEntry.selectors[i], _newEntry.where);
        }
    }

    function _disallowSelectors(uint256 _chainId, SelectorTarget memory _entry) internal virtual {
        for (uint256 i; i < _entry.selectors.length; i++) {
            if (!allowedSelectors[_chainId][_entry.where][_entry.selectors[i]]) {
                // The requested state is already in place
                continue;
            }
            allowedSelectors[_chainId][_entry.where][_entry.selectors[i]] = false;
            emit SelectorDisallowed(_chainId, _entry.selectors[i], _entry.where);
        }
    }

    function _allowNativeTransfers(uint256 _chainId, address _where) internal virtual {
        if (_chainId == 0) revert InvalidChainId();

        allowedNativeTransfers[_chainId][_where] = true;
        emit NativeTransfersAllowed(_chainId, _where);
    }

    function _disallowNativeTransfers(uint256 _chainId, address _where) internal virtual {
        allowedNativeTransfers[_chainId][_where] = false;
        emit NativeTransfersDisallowed(_chainId, _where);
    }
}
