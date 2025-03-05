// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "src/common/SignatureVerifier.sol";
import "src/common/interfaces/ISignatureVerifier.sol";

contract TestSignatureVerifier is Test {
    SignatureVerifier sigVerifier;
    uint256 cosignerPrivateKey = 0x1; //vm.envUint("PRIVATE_KEY");
    address cosignerAddress;

    // Sample commit data for testing
    ISignatureVerifier.CommitData commitData;

    function setUp() public {
        sigVerifier = new SignatureVerifier("MagicSigner", "1");
        cosignerAddress = vm.addr(cosignerPrivateKey);

        // Initialize sample commit data
        commitData = ISignatureVerifier.CommitData({
            id: 1,
            receiver: 0xE052c9CFe22B5974DC821cBa907F1DAaC7979c94,
            cosigner: cosignerAddress,
            seed: 1,
            counter: 1,
            orderHash: "0x0"
        });

        console.log("Commit data:");
        console.log("id:", commitData.id);
        console.log("receiver:", commitData.receiver);
        console.log("cosigner:", commitData.cosigner);
        console.log("seed:", commitData.seed);
        console.log("counter:", commitData.counter);
        console.log("orderHash:", commitData.orderHash);

        console.logBytes32(sigVerifier.hash(commitData));
    }

    // Quick way to test the signature from the typescript test
    //function testTypescriptSignatures() public {
    //    bytes
    //        memory signature = hex"09a0f1a38d41262e87c6bfc526c9a415b94ca4126e6cecba371a0efacf3db47c4ec97521c9ccc9396dcdf8e664ea57d04a1caa956c53180e2330b61908bacff61b";
    //
    //    address recovered = sigVerifier.debugVerify(
    //        0xa1ad0acce1b2568da1ab9d0687af53984d6e8396a4feb3b4cf2fd70115171bc0,
    //        signature
    //    );
    //
    //    console.log("Recovered:", recovered);
    //}

    function _signCommit(
        ISignatureVerifier.CommitData memory commit
    ) internal returns (bytes memory signature) {
        // Sign voucher with cosigner's private key
        bytes32 digest = sigVerifier.hash(commit);
        console.logBytes32(digest);
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
        ISignatureVerifier.CommitData memory modifiedCommit = commitData;
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
        ISignatureVerifier.CommitData memory modifiedCommit = commitData;
        modifiedCommit.id = commitData.id + 1;
        address recoveredSigner = sigVerifier.verify(
            modifiedCommit,
            originalSignature
        );
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing id should invalidate signature"
        );

        // Test receiver field
        modifiedCommit = commitData;
        modifiedCommit.receiver = address(0x1111);
        recoveredSigner = sigVerifier.verify(modifiedCommit, originalSignature);
        assertTrue(
            recoveredSigner != cosignerAddress,
            "Changing receiver should invalidate signature"
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
        modifiedCommit.orderHash = "0x1";
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
