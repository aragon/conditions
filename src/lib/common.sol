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

/// @notice Strips the selector and returns remaining data.
function stripSelector(bytes memory data) pure returns (bytes memory out) {
    if (data.length < 4) revert("Data is too Short");

    // Slices are only supported for bytes calldata, not bytes memory
    // Bytes memory requires an assembly block
    assembly ("memory-safe") {
        out := add(data, 4) // move header 4 bytes forward
        mstore(out, sub(mload(data), 4)) // write the new, shorter length
    }
}
