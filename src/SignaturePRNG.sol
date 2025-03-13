// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "./common/CRC32.sol";

contract SignaturePRNG is CRC32 {
    uint256 public constant BASE_POINTS = 10000;
    uint32 public constant MAX_CRC32_HASH_VALUE =
        uint32(type(uint32).max - (type(uint32).max % BASE_POINTS));

    function _rng(bytes calldata signature) internal view returns (uint32) {
        bytes32 hashVal = keccak256(signature);
        uint32 hashNum = crc32(hashVal);

        // Loop until we get a value below MAX_CRC32_HASH_VALUE (to avoid modulo bias)
        while (hashNum >= MAX_CRC32_HASH_VALUE) {
            hashVal = keccak256(abi.encodePacked(hashVal));
            hashNum = crc32(hashVal);
        }

        return uint32(hashNum % BASE_POINTS);
    }
}
