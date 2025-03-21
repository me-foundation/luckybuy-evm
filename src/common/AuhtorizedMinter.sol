// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ERC1155M {
    function authorizedMint(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof
    ) external payable {}
}

abstract contract AuthorizedMinter {
    address ERC1155M openEdition;

    constructor(address openEdition_) {
        openEdition = openEdition_;
    }

    function _authorizedMint(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof
    ) internal {
        ERC1155M(openEdition).authorizedMint(to, tokenId, qty, limit, proof);
    }
}
