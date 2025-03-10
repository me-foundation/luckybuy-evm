// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/LuckyBuy.sol";

contract LuckyBuyDepositTest is Test {
    LuckyBuy public luckyBuy;
    address public admin = address(0x1);
    address public user = address(0x2);

    event Deposit(address indexed sender, uint256 amount);

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new LuckyBuy();
        vm.stopPrank();
    }

    function testReceiveFunction() public {
        address sender = address(0x5);
        uint256 amount = 1 ether;
        uint256 initialBalance = luckyBuy.balance();

        vm.deal(sender, amount);
        vm.prank(sender);
        (bool success, ) = address(luckyBuy).call{value: amount}("");

        assertTrue(success, "ETH transfer should succeed");
        assertEq(
            luckyBuy.balance(),
            initialBalance + amount,
            "Contract balance should increase"
        );
    }

    function testReceiveMultipleDeposits() public {
        address sender = address(0x5);
        uint256 amount1 = 0.5 ether;
        uint256 amount2 = 1.5 ether;
        uint256 initialBalance = luckyBuy.balance();

        vm.deal(sender, amount1 + amount2);
        vm.prank(sender);
        (bool success1, ) = address(luckyBuy).call{value: amount1}("");

        assertTrue(success1, "First ETH transfer should succeed");
        assertEq(
            luckyBuy.balance(),
            initialBalance + amount1,
            "Contract balance should increase after first deposit"
        );

        vm.prank(sender);
        (bool success2, ) = address(luckyBuy).call{value: amount2}("");

        assertTrue(success2, "Second ETH transfer should succeed");
        assertEq(
            luckyBuy.balance(),
            initialBalance + amount1 + amount2,
            "Contract balance should increase after second deposit"
        );
    }

    function testReceiveZeroValue() public {
        address sender = address(0x5);
        uint256 amount = 0;
        uint256 initialBalance = luckyBuy.balance();

        vm.prank(sender);
        (bool success, ) = address(luckyBuy).call{value: amount}("");

        assertTrue(!success, "Zero value transfer should not succeed");
        assertEq(
            luckyBuy.balance(),
            initialBalance,
            "Contract balance should remain unchanged"
        );
    }

    function testBalanceTrackingAccuracy() public {
        address sender = address(0x5);
        uint256 depositAmount = 2 ether;

        vm.deal(sender, depositAmount);

        vm.prank(sender);
        (bool success, ) = address(luckyBuy).call{value: depositAmount}("");

        assertTrue(success, "ETH transfer should succeed");
        assertEq(
            luckyBuy.balance(),
            depositAmount,
            "Contract balance should equal deposit amount"
        );
        assertEq(
            address(luckyBuy).balance,
            depositAmount,
            "Actual ETH balance should match tracked balance"
        );
    }

    function testContractInitialDepositHandling() public {
        address newContractAddress = computeCreateAddress(
            address(this),
            vm.getNonce(address(this))
        );
        uint256 preExistingAmount = 0.5 ether;

        vm.deal(address(this), preExistingAmount);
        (bool success, ) = newContractAddress.call{value: preExistingAmount}(
            ""
        );
        assertTrue(success, "Pre-deployment ETH transfer should succeed");

        LuckyBuy newLuckyBuy = new LuckyBuy();

        assertEq(
            address(newLuckyBuy).balance,
            preExistingAmount,
            "Contract should have pre-existing ETH"
        );
        assertEq(
            newLuckyBuy.balance(),
            preExistingAmount,
            "Contract balance should account for pre-existing ETH"
        );
    }
}
