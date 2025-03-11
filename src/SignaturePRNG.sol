// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "./common/CRC32.sol";

contract SignaturePRNG is CRC32 {
    uint256 public constant BASE_POINTS = 10000;
    uint256 public constant BITS_NEEDED = 14;
    uint256 public constant BIT_WINDOW = 32 - BITS_NEEDED;
    uint256 public constant BIT_MASK = (1 << BITS_NEEDED) - 1;

    function _rng(bytes calldata signature) internal view returns (uint32) {
        bytes32 sigHash = keccak256(signature);
        uint32 checksum = crc32(sigHash);

        // Try every possible overlapping 14-bit window
        for (uint8 i = 0; i <= BIT_WINDOW; i++) {
            uint32 value = uint32((checksum >> i) & BIT_MASK);
            if (value < BASE_POINTS) {
                return value;
            }
        }

        // Fallback, ~.39^14 chance of happening. (1 - (BASE_POINTS / 2^14)))^14
        return _rngFallback(checksum);
    }

    function _rngFallback(uint32 checksum) internal pure returns (uint32) {
        return uint32(checksum % BASE_POINTS);
    }
}
