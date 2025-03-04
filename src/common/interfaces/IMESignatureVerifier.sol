// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.28;

interface IMESignatureVerifier {
    // This data changes implementation to implementation
    struct CommitData {
        uint256 id;
        address from;
        address cosigner;
        uint256 seed;
        uint256 counter;
        bytes orderHash;
    }

    function hash(
        IMESignatureVerifier.CommitData memory commit
    ) external view returns (bytes32);

    function verify(
        IMESignatureVerifier.CommitData memory commit,
        bytes memory signature
    ) external view returns (address);
}
