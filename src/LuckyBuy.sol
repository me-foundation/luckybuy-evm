// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./common/SignatureVerifier.sol";

contract LuckyBuy is SignatureVerifier {
    uint256 public balance;

    constructor() SignatureVerifier("LuckyBuy", "1") {}

    function _depositTreasury(uint256 amount) internal {
        balance += amount;
    }

    receive() external payable {
        _depositTreasury(msg.value);
    }
}
