// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

/// @notice Extracts the selector given the calldata. If no calldata is passed, it returns zero
function getSelector(bytes memory _data) pure returns (bytes4 selector) {
    if (_data.length < 4) revert("Data is too short");

    // Slices are only supported for bytes calldata, not bytes memory
    // Bytes memory requires an assembly block
    assembly {
        selector := mload(add(_data, 0x20)) // 32
    }
}
