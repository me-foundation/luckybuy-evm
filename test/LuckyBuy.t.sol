// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "src/LuckyBuy.sol";

contract TestLuckyBuy is Test {
    LuckyBuy luckyBuy;

    function setUp() public {
        luckyBuy = new LuckyBuy();
    }
}
