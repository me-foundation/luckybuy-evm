// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CRC32 Hash Calculator
 * @dev Implements the CRC-32 (Cyclic Redundancy Check) algorithm as defined by ISO-HDLC, IEEE 802.3, and others.
 *
 * ref: https://gist.github.com/kbhokray/683f4260f9c13a767fcfdac2ac3ee188
 * ref: https://reveng.sourceforge.io/crc-catalogue/all.htm#crc.cat.crc-32-iso-hdlc
 *
 * check online:
 * https://www.browserling.com/tools/crc32-hash
 * https://crccalc.com/?crc=test&method=&datatype=ascii&outtype=hex
 *
 * The CRC-32 ISO-HDLC algorithm uses the following parameters:
 * - Width: 32 bits
 * - Polynomial: 0x04C11DB7 (expressed in the standard form used in specifications)
 * - Initial value: 0xFFFFFFFF
 * - Final XOR: 0xFFFFFFFF
 * - Reflect input: true (bits are processed LSB first)
 * - Reflect output: true (the final value is bit-reflected)
 *
 * Note on Polynomial Representation:
 * While the standard specification defines the polynomial as 0x04C11DB7, this implementation
 * uses 0x1DB710640. This discrepancy is due to implementation details in the table-based algorithm:
 *
 * 1. The standard polynomial (0x04C11DB7) gets bit-reflected to 0xEDB88320 for LSB-first processing
 * 2. For the table-driven implementation, we left-shift this reflected polynomial by 1 bit, resulting in 0x1DB710640
 *
 * This transformation is purely an optimization for the lookup table approach but produces
 * mathematically equivalent results to the standard algorithm.
 */
contract CRC32 {
    /**
     * @dev The CRC-32 polynomial used in the lookup table calculation.
     * This is NOT the canonical form (0x04C11DB7) from the spec, but rather:
     * - The bit-reflected value (0xEDB88320) left-shifted by 1 bit
     * - This transformation is required for the right-shift table-based implementation
     */
    uint256 private constant CRC_POLYNOMIAL = 0x1DB710640;

    /**
     * @dev Lookup table for fast CRC calculation.
     * Each entry represents the CRC value for a specific byte pattern.
     */
    uint256[256] private crcTable;

    /**
     * @dev Constructor that pre-calculates the CRC lookup table.
     * The table is generated once when the contract is deployed to save gas during calculations.
     */
    constructor() {
        // Generate the CRC-32 lookup table with 256 entries (one for each possible byte value)
        for (uint256 i = 0; i < 256; i++) {
            uint256 v = i;

            // For each bit in the byte (LSB first)
            for (uint256 j = 0; j < 8; j++) {
                // If the least significant bit is 1, apply the polynomial
                if (v & 1 == 1) {
                    v = v ^ CRC_POLYNOMIAL;
                }
                // Right-shift to process the next bit
                v >>= 1;
            }

            // Store the resulting CRC value in the table
            crcTable[i] = v;
        }
    }

    /**
     * @dev Calculate CRC32 hash of a byte array.
     * This follows the ISO-HDLC standard for CRC-32 calculations.
     *
     * @param data The input byte array to calculate the CRC32 hash for
     * @return The 32-bit CRC value as a uint32
     */
    function crc32(bytes memory data) public view returns (uint32) {
        unchecked {
            // Initialize CRC with all 1's (0xFFFFFFFF) as per the standard
            uint256 crc = 0xFFFFFFFF;

            // Process each byte in the input data
            for (uint256 i = 0; i < data.length; i++) {
                uint8 b = uint8(data[i]);

                // XOR the low byte of the current CRC with the input byte
                // Use this as an index into the lookup table
                // XOR the table value with the shifted CRC
                crc = (crc >> 8) ^ crcTable[(crc ^ uint256(b)) & 0xFF];
            }

            // Final XOR with all 1's (0xFFFFFFFF) as per the standard
            // and conversion to uint32 (which is the standard CRC-32 width)
            return uint32(crc ^ 0xFFFFFFFF);
        }
    }

    /**
     * @dev Calculate CRC32 hash of a string.
     * This is a convenience function that converts the string to bytes first.
     *
     * @param input The input string to calculate the CRC32 hash for
     * @return The 32-bit CRC value as a uint32
     */
    function stringToCRC32(string memory input) public view returns (uint32) {
        return crc32(bytes(input));
    }
}
