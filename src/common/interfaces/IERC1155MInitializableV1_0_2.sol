// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// https://github.com/me-foundation/magicdrop/blob/597dcc01051e88200ad7ba0531a5ea8d921fae6a/contracts/nft/erc1155m/ERC1155MInitializableV1_0_2.sol#L115
interface IERC1155MInitializableV1_0_2 {
    function authorizedMint(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof
    ) external payable;
}
