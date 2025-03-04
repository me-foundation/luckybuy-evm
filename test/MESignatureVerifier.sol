// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "src/common/SignatureVerifier.sol";
import "src/common/interfaces/IMESignatureVerifier.sol";

contract TestMESignatureVerifier is Test {
    MESignatureVerifier sigVerifier;
    uint256 cosignerPrivateKey = 0x1234;
    address cosignerAddress;

    // Sample commit data for testing
    IMESignatureVerifier.CommitData commitData;

    function setUp() public {
        sigVerifier = new MESignatureVerifier("MESignatureVerifier", "1");
        cosignerAddress = vm.addr(cosignerPrivateKey);

        // Initialize sample commit data
        commitData = IMESignatureVerifier.CommitData({
            id: 1,
            from: address(0xABCD),
            cosigner: cosignerAddress,
            seed: 42,
            counter: 123,
            orderHash: abi.encodePacked(bytes32(uint256(0x5678)))
        });
    }

    function _signCommit(
        IMESignatureVerifier.CommitData memory commit
    ) internal returns (bytes memory signature) {
        // Sign voucher with cosigner's private key
        bytes32 digest = sigVerifier.hash(commit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cosignerPrivateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    function testHashConsistency() public {
        bytes32 hash1 = sigVerifier.hash(commitData);
        bytes32 hash2 = sigVerifier.hash(commitData);

        assertEq(hash1, hash2, "Hash function should be idempotent");
    }

    function testVerifyValidSignature() public {
        // Create a signature using the cosigner's private key
        bytes memory signature = _signCommit(commitData);

        // Verify the signature
        address recoveredSigner = sigVerifier.verify(commitData, signature);

        // The recovered signer should match our cosigner address
        assertEq(
            recoveredSigner,
            cosignerAddress,
            "Signature verification should recover the correct signer"
        );
    }

    function testVerifyModifiedCommitFails() public {
        // Sign the original commit data
        bytes memory signature = _signCommit(commitData);

        // Create a modified commit with a different id
        IMESignatureVerifier.CommitData memory modifiedCommit = commitData;
        modifiedCommit.id = 999;

        // Verify the signature with modified commit data
        address recoveredSigner = sigVerifier.verify(modifiedCommit, signature);

        // The recovered signer should not match our cosigner address
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Verification with modified commit data should fail"
        );
    }

    // Malleability tests
    function testVerifyDifferentCommitFields() public {
        // Test that each field of the commit data affects the signature

        // Original signature
        bytes memory originalSignature = _signCommit(commitData);

        // Test id field
        IMESignatureVerifier.CommitData memory modifiedCommit = commitData;
        modifiedCommit.id = commitData.id + 1;
        address recoveredSigner = sigVerifier.verify(
            modifiedCommit,
            originalSignature
        );
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing id should invalidate signature"
        );

        // Test from field
        modifiedCommit = commitData;
        modifiedCommit.from = address(0x1111);
        recoveredSigner = sigVerifier.verify(modifiedCommit, originalSignature);
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing from should invalidate signature"
        );

        // Test cosigner field
        modifiedCommit = commitData;
        modifiedCommit.cosigner = address(0x2222);
        recoveredSigner = sigVerifier.verify(modifiedCommit, originalSignature);
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing cosigner should invalidate signature"
        );

        // Test seed field
        modifiedCommit = commitData;
        modifiedCommit.seed = commitData.seed + 1;
        recoveredSigner = sigVerifier.verify(modifiedCommit, originalSignature);
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing seed should invalidate signature"
        );

        // Test counter field
        modifiedCommit = commitData;
        modifiedCommit.counter = commitData.counter + 1;
        recoveredSigner = sigVerifier.verify(modifiedCommit, originalSignature);
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing counter should invalidate signature"
        );

        // Test orderHash field
        modifiedCommit = commitData;
        modifiedCommit.orderHash = abi.encodePacked(bytes32(uint256(0x9999)));
        recoveredSigner = sigVerifier.verify(modifiedCommit, originalSignature);
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing orderHash should invalidate signature"
        );
    }

    function testSignatureWithDifferentPrivateKey() public {
        // Create a different private key
        uint256 differentPrivateKey = 0x5678;
        address differentAddress = vm.addr(differentPrivateKey);

        // Sign with different private key
        bytes32 digest = sigVerifier.hash(commitData);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(differentPrivateKey, digest);
        bytes memory differentSignature = abi.encodePacked(r, s, v);

        // Verify the signature
        address recoveredSigner = sigVerifier.verify(
            commitData,
            differentSignature
        );

        // Should recover the different address, not the original cosigner
        assertEq(
            recoveredSigner,
            differentAddress,
            "Should recover the correct different signer"
        );
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Should not recover the original cosigner"
        );
    }

    function testMalformedSignature() public {
        // Create a malformed signature (too short)
        bytes memory malformedSignature = bytes("malformed");

        // This should revert when trying to decode the signature
        vm.expectRevert();
        sigVerifier.verify(commitData, malformedSignature);
    }
}
