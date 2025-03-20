// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

bytes32 constant EXECUTE_PERMISSION_ID = keccak256("EXECUTE_PERMISSION");
bytes32 constant SET_METADATA_PERMISSION_ID = keccak256(
    "SET_METADATA_PERMISSION"
);
bytes32 constant SET_SIGNATURE_VALIDATOR_PERMISSION_ID = keccak256(
    "SET_SIGNATURE_VALIDATOR_PERMISSION"
);
bytes32 constant REGISTER_STANDARD_CALLBACK_PERMISSION_ID = keccak256(
    "REGISTER_STANDARD_CALLBACK_PERMISSION"
);
bytes32 constant SET_TRUSTED_FORWARDER_PERMISSION_ID = keccak256(
    "SET_TRUSTED_FORWARDER_PERMISSION"
);
bytes32 constant ROOT_PERMISSION_ID = keccak256("ROOT_PERMISSION");

uint64 constant MAX_UINT64 = uint64(2 ** 64 - 1);
address constant ADDRESS_ZERO = address(0x0);
address constant NO_CONDITION = ADDRESS_ZERO;

// Actors
address constant ALICE_ADDRESS = address(0xa11ce);
address constant BOB_ADDRESS = address(0xB0B);
address constant CAROL_ADDRESS = address(0xc4601);
address constant DAVID_ADDRESS = address(0xd471d);
