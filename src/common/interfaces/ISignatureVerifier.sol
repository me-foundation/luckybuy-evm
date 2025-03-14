// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

interface ISignatureVerifier {
    // This data changes implementation to implementation
    struct CommitData {
        uint256 id;
        address receiver;
        address cosigner;
        uint256 seed;
        uint256 counter;
        bytes32 orderHash;
        uint256 amount;
        uint256 reward;
    }

    function hash(
        ISignatureVerifier.CommitData memory commit
    ) external view returns (bytes32);

    function verify(
        ISignatureVerifier.CommitData memory commit,
        bytes memory signature
    ) external view returns (address);
}
