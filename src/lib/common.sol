// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.22;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice Extracts the selector given the calldata. If no calldata is passed, it returns zero
function getSelector(bytes memory _data) pure returns (bytes4 selector) {
    if (_data.length < 4) revert("Data is too short");

    return bytes4(_data);
}

/// @notice Copies the content of `buffer`, from `start` (included) to
///         `end` (excluded) into a new bytes object in memory.
///         The `end` argument is truncated to the length of the `buffer`.
/// @dev This doesn't modify the original `buffer` argument.
function slice(bytes memory buffer, uint256 start, uint256 end) pure returns (bytes memory) {
    // sanitize
    end = Math.min(end, buffer.length);
    start = Math.min(start, end);

    // allocate and copy
    bytes memory result = new bytes(end - start);
    assembly ("memory-safe") {
        mcopy(add(result, 0x20), add(add(buffer, 0x20), start), sub(end, start))
    }

    return result;
}

/// @dev Strips the first 4 bytes selector.
function stripSelector(bytes memory data) pure returns (bytes memory) {
    return slice(data, 4, data.length);
}

