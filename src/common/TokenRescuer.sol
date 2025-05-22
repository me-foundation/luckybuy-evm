// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC1155} from "forge-std/interfaces/IERC1155.sol";

abstract contract TokenRescuer {
    // Custom errors
    error InvalidAddress();
    error TransferFailed();
    error AmountMustBeGreaterThanZero();
    error InsufficientBalance();

    event TokensRescued(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event NFTRescued(
        address indexed token,
        address indexed to,
        uint256 tokenId
    );
    event NFTBatchRescued(
        address indexed token,
        address indexed to,
        uint256[] tokenIds,
        uint256[] amounts
    );

    /**
     * @notice Rescues ERC20 tokens from the contract
     * @param token The address of the ERC20 token to rescue
     * @param to The address to send the tokens to
     * @param amount The amount of tokens to rescue
     */
    function _rescueERC20(address token, address to, uint256 amount) internal {
        if (token == address(0)) revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert AmountMustBeGreaterThanZero();

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit TokensRescued(token, to, amount);
    }

    /**
     * @notice Rescues an ERC721 token from the contract
     * @param token The address of the ERC721 token to rescue
     * @param to The address to send the token to
     * @param tokenId The ID of the token to rescue
     */
    function _rescueERC721(
        address token,
        address to,
        uint256 tokenId
    ) internal {
        if (token == address(0)) revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();

        IERC721(token).safeTransferFrom(address(this), to, tokenId);
        emit NFTRescued(token, to, tokenId);
    }

    /**
     * @notice Rescues multiple ERC1155 tokens from the contract
     * @param token The address of the ERC1155 token to rescue
     * @param to The address to send the tokens to
     * @param tokenIds The IDs of the tokens to rescue
     * @param amounts The amounts of each token to rescue
     */
    function _rescueERC721Batch(
        address token,
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) internal {
        if (token == address(0)) revert InvalidAddress();
        if (to == address(0)) revert InvalidAddress();
        if (tokenIds.length != amounts.length) revert InvalidAddress();

        IERC1155(token).safeBatchTransferFrom(
            address(this),
            to,
            tokenIds,
            amounts,
            ""
        );
        emit NFTBatchRescued(token, to, tokenIds, amounts);
    }
}
