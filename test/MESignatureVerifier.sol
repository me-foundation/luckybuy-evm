// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "src/common/SignatureVerifier.sol";

contract TestMESignatureVerifier is Test {
    MESignatureVerifier sigVerifier;

    function setUp() public {
        sigVerifier = new MESignatureVerifier("MESignatureVerifier", "1");
    }
}
