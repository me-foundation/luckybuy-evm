// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {IERC1155} from "forge-std/interfaces/IERC1155.sol";

abstract contract TokenRescuer {
    // Custom errors
    error TokenRescuerInvalidAddress();
    error TokenRescuerTransferFailed();
    error TokenRescuerAmountMustBeGreaterThanZero();
    error TokenRescuerInsufficientBalance();
    error TokenRescuerArrayLengthMismatch();

    event ERC20BatchRescued(address[] tokens, address[] to, uint256[] amounts);
    event ERC721BatchRescued(
        address[] tokens,
        address[] to,
        uint256[] tokenIds
    );
    event ERC1155BatchRescued(
        address[] tokens,
        address[] to,
        uint256[] tokenIds,
        uint256[] amounts
    );

    /**
     * @notice Rescues multiple ERC20 tokens from the contract
     * @param tokens The addresses of the ERC20 tokens to rescue
     * @param to The addresses to send the tokens to
     * @param amounts The amounts of tokens to rescue
     */
    function _rescueERC20Batch(
        address[] memory tokens,
        address[] memory to,
        uint256[] memory amounts
    ) internal {
        if (tokens.length == 0)
            revert TokenRescuerAmountMustBeGreaterThanZero();
        if (tokens.length != to.length || tokens.length != amounts.length)
            revert TokenRescuerArrayLengthMismatch();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert TokenRescuerInvalidAddress();
            if (to[i] == address(0)) revert TokenRescuerInvalidAddress();
            if (amounts[i] == 0)
                revert TokenRescuerAmountMustBeGreaterThanZero();

            uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
            if (balance < amounts[i]) revert TokenRescuerInsufficientBalance();

            if (!IERC20(tokens[i]).transfer(to[i], amounts[i]))
                revert TokenRescuerTransferFailed();
        }
        emit ERC20BatchRescued(tokens, to, amounts);
    }

    /**
     * @notice Rescues multiple ERC721 tokens from the contract
     * @param tokens The addresses of the ERC721 tokens to rescue
     * @param to The addresses to send the tokens to
     * @param tokenIds The IDs of the tokens to rescue
     */
    function _rescueERC721Batch(
        address[] memory tokens,
        address[] memory to,
        uint256[] memory tokenIds
    ) internal {
        if (tokens.length == 0)
            revert TokenRescuerAmountMustBeGreaterThanZero();
        if (tokens.length != to.length || tokens.length != tokenIds.length)
            revert TokenRescuerArrayLengthMismatch();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert TokenRescuerInvalidAddress();
            if (to[i] == address(0)) revert TokenRescuerInvalidAddress();

            IERC721(tokens[i]).safeTransferFrom(
                address(this),
                to[i],
                tokenIds[i]
            );
        }
        emit ERC721BatchRescued(tokens, to, tokenIds);
    }

    /**
     * @notice Rescues multiple ERC1155 tokens from the contract
     * @param tokens The addresses of the ERC1155 tokens to rescue
     * @param to The addresses to send the tokens to
     * @param tokenIds The IDs of the tokens to rescue
     * @param amounts The amounts of each token to rescue
     */
    function _rescueERC1155Batch(
        address[] memory tokens,
        address[] memory to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) internal {
        if (tokens.length == 0)
            revert TokenRescuerAmountMustBeGreaterThanZero();
        if (
            tokens.length != to.length ||
            tokens.length != tokenIds.length ||
            tokens.length != amounts.length
        ) revert TokenRescuerArrayLengthMismatch();

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert TokenRescuerInvalidAddress();
            if (to[i] == address(0)) revert TokenRescuerInvalidAddress();
            if (amounts[i] == 0)
                revert TokenRescuerAmountMustBeGreaterThanZero();

            // Balance check for ERC1155
            uint256 balance = IERC1155(tokens[i]).balanceOf(
                address(this),
                tokenIds[i]
            );
            if (balance < amounts[i]) revert TokenRescuerInsufficientBalance();

            uint256[] memory singleTokenId = new uint256[](1);
            uint256[] memory singleAmount = new uint256[](1);
            singleTokenId[0] = tokenIds[i];
            singleAmount[0] = amounts[i];

            IERC1155(tokens[i]).safeBatchTransferFrom(
                address(this),
                to[i],
                singleTokenId,
                singleAmount,
                ""
            );
        }
        emit ERC1155BatchRescued(tokens, to, tokenIds, amounts);
    }

    /**
     * @notice Rescues multiple tokenIds/amounts from a single ERC1155 token to a single recipient
     */
    function _rescueSingleERC1155Batch(
        address token,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) internal {
        if (token == address(0)) revert TokenRescuerInvalidAddress();
        if (to == address(0)) revert TokenRescuerInvalidAddress();
        if (tokenIds.length == 0)
            revert TokenRescuerAmountMustBeGreaterThanZero();
        if (tokenIds.length != amounts.length)
            revert TokenRescuerArrayLengthMismatch();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (amounts[i] == 0)
                revert TokenRescuerAmountMustBeGreaterThanZero();
            uint256 balance = IERC1155(token).balanceOf(
                address(this),
                tokenIds[i]
            );
            if (balance < amounts[i]) revert TokenRescuerInsufficientBalance();
        }
        IERC1155(token).safeBatchTransferFrom(
            address(this),
            to,
            tokenIds,
            amounts,
            ""
        );
        // Emit the same event for consistency
        address[] memory tokens = new address[](1);
        address[] memory tos = new address[](1);
        tokens[0] = token;
        tos[0] = to;
        emit ERC1155BatchRescued(tokens, tos, tokenIds, amounts);
    }
}
