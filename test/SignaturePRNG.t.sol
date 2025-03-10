// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "src/SignaturePRNG.sol";

contract MockSignaturePRNG is SignaturePRNG {
    function exposed_rng(
        bytes calldata signature
    ) public view returns (uint32) {
        return _rng(signature);
    }

    function exposed_rngFallback(uint32 checksum) public pure returns (uint32) {
        return _rngFallback(checksum);
    }
}

contract TestSignaturePRNG is Test {
    MockSignaturePRNG prng;

    // Sample signature data
    bytes sampleSignature1;
    bytes sampleSignature2;
    bytes sampleSignatureIdentical;

    function setUp() public {
        prng = new MockSignaturePRNG();

        // Create some sample signatures for testing
        sampleSignature1 = hex"09a0f1a38d41262e87c6bfc526c9a415b94ca4126e6cecba371a0efacf3db47c4ec97521c9ccc9396dcdf8e664ea57d04a1caa956c53180e2330b61908bacff61b";
        sampleSignature2 = hex"1ca0f1a38d41262e87c6bfc526c9a415b94ca4126e6cecba371a0efacf3db47c4ec97521c9ccc9396dcdf8e664ea57d04a1caa956c53180e2330b61908bacff61c";
        // Identical to signature1 for determinism tests
        sampleSignatureIdentical = hex"09a0f1a38d41262e87c6bfc526c9a415b94ca4126e6cecba371a0efacf3db47c4ec97521c9ccc9396dcdf8e664ea57d04a1caa956c53180e2330b61908bacff61b";
    }

    function testRngInRange() public {
        // Test that the output is within the expected range
        uint32 result = prng.exposed_rng(sampleSignature1);

        assertTrue(
            result < prng.BASE_POINTS(),
            "RNG output should be less than BASE_POINTS"
        );
    }

    function testRngDeterminism() public {
        // Test that the same input produces the same output
        uint32 result1 = prng.exposed_rng(sampleSignature1);
        uint32 result2 = prng.exposed_rng(sampleSignatureIdentical);

        assertEq(
            result1,
            result2,
            "Same input signature should produce the same random number"
        );
    }

    function testRngDifferentInputs() public {
        // Test that different inputs produce different outputs
        uint32 result1 = prng.exposed_rng(sampleSignature1);
        uint32 result2 = prng.exposed_rng(sampleSignature2);

        // Note: There's a tiny chance this could fail if both inputs happen to generate the same number
        // But that's extremely unlikely given the space of possible outputs
        assertTrue(
            result1 != result2,
            "Different input signatures should produce different random numbers"
        );
    }

    function testRngZeroLengthSignature() public {
        // Test handling of empty signature
        bytes memory emptySignature = bytes("");

        uint32 result = prng.exposed_rng(emptySignature);

        // Should still produce a value in the correct range
        assertTrue(
            result < prng.BASE_POINTS(),
            "RNG should handle empty signatures and produce output in range"
        );
    }

    function testRngShortSignature() public {
        // Test with a very short signature
        bytes memory shortSignature = bytes("short");

        uint32 result = prng.exposed_rng(shortSignature);

        assertTrue(
            result < prng.BASE_POINTS(),
            "RNG should handle short signatures and produce output in range"
        );
    }

    function testRngFallbackInRange() public {
        // Test various input values to ensure fallback always returns values in range
        uint32[] memory testValues = new uint32[](5);
        testValues[0] = 0;
        testValues[1] = 9999;
        testValues[2] = 10000;
        testValues[3] = 0xFFFFFFFF; // Max uint32
        testValues[4] = 123456789;

        for (uint i = 0; i < testValues.length; i++) {
            uint32 result = prng.exposed_rngFallback(testValues[i]);
            assertTrue(
                result < prng.BASE_POINTS(),
                "Fallback output should always be less than BASE_POINTS"
            );
        }
    }

    function testRngFallbackDeterminism() public {
        // Ensure fallback is deterministic
        uint32 input = 0xABCDEF12;

        uint32 result1 = prng.exposed_rngFallback(input);
        uint32 result2 = prng.exposed_rngFallback(input);

        assertEq(
            result1,
            result2,
            "Fallback should produce deterministic results for the same input"
        );
    }

    function testRngFallbackModuloProperties() public {
        // Test modulo properties specific to our use case

        // 1. Verify modulo cycles correctly
        uint32 base1 = 12345;
        uint32 base2 = base1 + uint32(prng.BASE_POINTS());

        assertEq(
            prng.exposed_rngFallback(base1),
            prng.exposed_rngFallback(base2),
            "Values differing by BASE_POINTS should yield the same result"
        );

        // 2. Test edge cases for modulo
        assertEq(
            prng.exposed_rngFallback(0),
            0,
            "Fallback should return 0 for input 0"
        );

        assertEq(
            prng.exposed_rngFallback(uint32(prng.BASE_POINTS())),
            0,
            "Fallback should return 0 for input equal to BASE_POINTS"
        );

        // 3. Test identity property for values < BASE_POINTS
        for (uint32 i = 0; i < 100; i++) {
            uint32 smallValue = i * 100; // Values 0 through 9900
            if (smallValue < prng.BASE_POINTS()) {
                assertEq(
                    prng.exposed_rngFallback(smallValue),
                    smallValue,
                    "Fallback should return input when input < BASE_POINTS"
                );
            }
        }
    }

    function testRngFallbackWithRealChecksum() public {
        // Generate a real CRC32 checksum that would trigger the fallback
        // Note: This is challenging to do deterministically since the fallback
        // is extremely rare, so we'll manually craft a value

        // Create a special signature that generates a hash that needs the fallback
        // This is hypothetical since finding such a signature is extremely unlikely
        uint32 hypotheticalChecksum = 0xFFFFFFFF; // Max uint32

        // For every possible bit window position
        bool allWindowsAboveBasePoints = true;
        for (uint8 i = 0; i <= prng.BIT_WINDOW(); i++) {
            uint32 value = uint32(
                (hypotheticalChecksum >> i) & prng.BIT_MASK()
            );
            if (value < prng.BASE_POINTS()) {
                allWindowsAboveBasePoints = false;
                break;
            }
        }

        assertTrue(
            allWindowsAboveBasePoints,
            "Test setup: Our hypothetical checksum should require fallback"
        );

        // Now test that fallback works with this checksum
        uint32 fallbackResult = prng.exposed_rngFallback(hypotheticalChecksum);

        assertTrue(
            fallbackResult < prng.BASE_POINTS(),
            "Fallback should produce a result within range"
        );

        // Verify the expected modulo calculation
        assertEq(
            fallbackResult,
            hypotheticalChecksum % prng.BASE_POINTS(),
            "Fallback should be equivalent to modulo BASE_POINTS"
        );
    }
}
