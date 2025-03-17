// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "src/common/CRC32.sol";

contract TestCRC32 is Test {
    CRC32 crc32;

    // File paths for different test sizes
    string constant OUTPUT_1K = "./crc32_1k.csv";
    string constant OUTPUT_10K = "./crc32_10k.csv";
    string constant OUTPUT_100K = "./crc32_100k.csv";
    string constant OUTPUT_1M = "./crc32_1m.csv";

    function setUp() public {
        crc32 = new CRC32();
    }

    function test_crc32_table() public {
        for (uint256 i = 0; i < 256; i++) {
            uint256 crcValue = crc32.crcTable(i);
            console.log("CRC32 of", i, "is", crcValue);
        }
    }

    function test_crc32_single() public {
        string memory data = "test";
        uint32 result = crc32.crc32(data);
        console.log("CRC32 of 'test':", result);
        console.log("CRC32 of 'test' (hex):", toHexString(result));
    }

    //function test_generate_1k() public {
    //    _generateCRC32Values(1000, OUTPUT_1K);
    //}
    //
    //function test_generate_10k() public {
    //    _generateCRC32Values(10000, OUTPUT_10K);
    //}
    //
    //function test_generate_100k() public {
    //    _generateCRC32Values(100000, OUTPUT_100K);
    //}
    //
    //function test_generate_1m() public {
    //    _generateCRC32Values(1000000, OUTPUT_1M);
    //}

    /**
     * @dev Helper function to generate a specified number of CRC32 values and write to file
     * @param count Number of values to generate
     * @param outputPath Path to write the output file
     */
    function _generateCRC32Values(
        uint256 count,
        string memory outputPath
    ) internal {
        // Write header
        //vm.writeLine(outputPath, "index,input,crc32_decimal,crc32_hex");

        for (uint256 i = 0; i < count; i++) {
            // Create a deterministic but varied input string
            string memory input = string(
                abi.encodePacked("input_", vm.toString(i))
            );

            // Calculate CRC32
            uint32 crcValue = crc32.crc32(input);

            // Format as CSV row: index, decimal, hex
            string memory row = string(
                abi.encodePacked(
                    vm.toString(i),
                    ",",
                    vm.toString(uint256(crcValue)),
                    ",",
                    "0x",
                    toHexString(crcValue)
                )
            );

            // Write line to file
            vm.writeLine(outputPath, row);

            // Log progress for large datasets
            if (i % 10000 == 0 || i == count - 1) {
                console.log("Generated CRC32 values:", i + 1);
            }
        }

        console.log(
            "Successfully generated",
            count,
            "CRC32 values. Output written to",
            outputPath
        );
    }

    /**
     * @dev Helper function to convert uint32 to hex string without 0x prefix
     * @param value The uint32 value to convert
     * @return The hex string representation
     */
    function toHexString(uint32 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(8);
        for (uint256 i = 0; i < 8; i++) {
            buffer[7 - i] = bytes1(
                uint8(
                    (value & 0xf) > 9
                        ? (value & 0xf) + 87 // a-f
                        : (value & 0xf) + 48 // 0-9
                )
            );
            value >>= 4;
        }
        return string(buffer);
    }
}
