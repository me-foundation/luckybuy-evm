// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "src/LuckyBuy.sol";

contract MockLuckyBuy is LuckyBuy {
    constructor(uint256 protocolFee_) LuckyBuy(protocolFee_) {}

    function setIsFulfilled(uint256 commitId_, bool isFulfilled_) public {
        isFulfilled[commitId_] = isFulfilled_;
    }
}

contract TestLuckyBuyCommit is Test {
    MockLuckyBuy luckyBuy;
    address admin = address(0x1);
    address user = address(0x2);
    address receiver = address(0x3);
    address cosigner = address(0x4);
    uint256 protocolFee = 0;

    uint256 seed = 12345;
    bytes32 orderHash = hex"1234";
    uint256 amount = 1 ether;
    uint256 reward = 10 ether; // 10% odds

    event Commit(
        address indexed sender,
        uint256 indexed commitId,
        address indexed receiver,
        address cosigner,
        uint256 seed,
        uint256 counter,
        bytes32 orderHash,
        uint256 amount,
        uint256 reward,
        uint256 fee,
        bytes32 digest
    );
    event CommitExpireTimeUpdated(
        uint256 oldCommitExpireTime,
        uint256 newCommitExpireTime
    );
    event CommitExpired(uint256 indexed commitId);

    event Withdrawal(address indexed sender, uint256 amount);

    event MaxRewardUpdated(uint256 oldMaxReward, uint256 newMaxReward);

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new MockLuckyBuy(protocolFee);
        vm.deal(admin, 100 ether);
        vm.deal(receiver, 100 ether);
        vm.deal(address(this), 100 ether);
        // Add a cosigner for testing
        luckyBuy.addCosigner(cosigner);
        vm.stopPrank();
    }

    function testCommitSuccess() public {
        vm.startPrank(user);
        vm.deal(user, amount);

        // Note: We can't easily check the hash in the event since it's calculated inside the contract
        vm.expectEmit(true, true, true, false); // We don't check the non-indexed parameters
        emit Commit(
            user,
            0, // First commit ID should be 0
            receiver,
            cosigner,
            seed,
            0, // First counter for this receiver should be 0
            orderHash,
            amount,
            reward,
            0,
            bytes32(0)
        );

        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        assertEq(
            luckyBuy.luckyBuyCount(receiver),
            1,
            "Receiver counter should be incremented"
        );

        (
            uint256 id,
            address storedReceiver,
            address storedCosigner,
            uint256 storedSeed,
            uint256 storedCounter,
            bytes32 storedOrderHash,
            uint256 storedAmount,
            uint256 storedReward
        ) = luckyBuy.luckyBuys(0);

        assertEq(id, 0, "Commit ID should be 0");
        assertEq(storedReceiver, receiver, "Receiver should match");
        assertEq(storedCosigner, cosigner, "Cosigner should match");
        assertEq(storedSeed, seed, "Seed should match");
        assertEq(storedCounter, 0, "Counter should be 0");
        assertEq(storedOrderHash, orderHash, "Order hash should match");
        assertEq(storedAmount, amount, "Amount should match");
        assertEq(storedReward, reward, "Reward should match");
        vm.stopPrank();
    }

    function testCommitMultipleTimes() public {
        vm.startPrank(user);
        vm.deal(user, amount * 2);

        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        assertEq(
            luckyBuy.luckyBuyCount(receiver),
            1,
            "Receiver counter should be 1 after first commit"
        );

        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed + 1,
            "secondOrderHash",
            reward
        );

        assertEq(
            luckyBuy.luckyBuyCount(receiver),
            2,
            "Receiver counter should be 2 after second commit"
        );

        (
            uint256 id,
            address storedReceiver,
            address storedCosigner,
            uint256 storedSeed,
            uint256 storedCounter,
            bytes32 storedOrderHash,
            uint256 storedAmount,
            uint256 storedReward
        ) = luckyBuy.luckyBuys(1);

        assertEq(id, 1, "Second commit ID should be 1");
        assertEq(storedReceiver, receiver, "Receiver should match");
        assertEq(storedCosigner, cosigner, "Cosigner should match");
        assertEq(storedSeed, seed + 1, "Seed should match");
        assertEq(storedCounter, 1, "Counter should be 1 for second commit");
        assertEq(storedOrderHash, "secondOrderHash", "Order hash should match");
        assertEq(storedAmount, amount, "Amount should match");
        assertEq(storedReward, reward, "Reward should match");
        vm.stopPrank();
    }

    function testCommitWithZeroAmount() public {
        vm.startPrank(user);

        vm.expectRevert(LuckyBuy.InvalidAmount.selector);
        luckyBuy.commit{value: 0}(receiver, cosigner, seed, orderHash, reward);

        vm.stopPrank();
    }

    function testCommitWithInvalidCosigner() public {
        address invalidCosigner = address(0x5);
        vm.startPrank(user);
        vm.deal(user, amount);

        // Act & Assert - Should revert with InvalidCosigner
        vm.expectRevert(LuckyBuy.InvalidCosigner.selector);
        luckyBuy.commit{value: amount}(
            receiver,
            invalidCosigner,
            seed,
            orderHash,
            reward
        );

        vm.stopPrank();
    }

    function testCommitWithZeroAddressReceiver() public {
        vm.startPrank(user);
        vm.deal(user, amount);

        vm.expectRevert(LuckyBuy.InvalidReceiver.selector);
        luckyBuy.commit{value: amount}(
            address(0),
            cosigner,
            seed,
            orderHash,
            reward
        );

        vm.stopPrank();
    }

    function testCommitWithRemovedCosigner() public {
        vm.startPrank(admin);
        luckyBuy.removeCosigner(cosigner);
        vm.stopPrank();

        vm.startPrank(user);
        vm.deal(user, amount);

        vm.expectRevert(LuckyBuy.InvalidCosigner.selector);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        vm.stopPrank();
    }

    function testCommitFromDifferentUsers() public {
        address user2 = address(0x6);

        vm.startPrank(user);
        vm.deal(user, amount);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, amount);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed + 1,
            orderHash,
            reward
        );
        vm.stopPrank();
        assertEq(
            luckyBuy.luckyBuyCount(receiver),
            2,
            "Receiver counter should be 2 after commits from two users"
        );

        (
            uint256 id1,
            address receiver1,
            address cosigner1,
            ,
            ,
            bytes32 orderHash1,
            uint256 amount1,
            uint256 reward1
        ) = luckyBuy.luckyBuys(0);

        (
            uint256 id2,
            address receiver2,
            address cosigner2,
            ,
            ,
            bytes32 orderHash2,
            uint256 amount2,
            uint256 reward2
        ) = luckyBuy.luckyBuys(1);

        assertEq(id1, 0, "First commit ID should be 0");
        assertEq(id2, 1, "Second commit ID should be 1");
        assertEq(receiver1, receiver, "First receiver should match");
        assertEq(receiver2, receiver, "Second receiver should match");
        assertEq(orderHash1, orderHash, "First order hash should match");
        assertEq(orderHash2, orderHash, "Second order hash should match");
        assertEq(amount1, amount, "First amount should match");
        assertEq(amount2, amount, "Second amount should match");
        assertEq(reward1, reward, "First reward should match");
        assertEq(reward2, reward, "Second reward should match");
    }

    function testCommitToDifferentReceivers() public {
        address receiver2 = address(0x7);

        vm.startPrank(user);
        vm.deal(user, amount * 2);

        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        luckyBuy.commit{value: amount}(
            receiver2,
            cosigner,
            seed + 1,
            orderHash,
            reward
        );

        assertEq(
            luckyBuy.luckyBuyCount(receiver),
            1,
            "First receiver counter should be 1"
        );
        assertEq(
            luckyBuy.luckyBuyCount(receiver2),
            1,
            "Second receiver counter should be 1"
        );

        (
            ,
            address storedReceiver1,
            ,
            ,
            uint256 storedCounter1,
            ,
            ,
            uint256 storedReward1
        ) = luckyBuy.luckyBuys(0);

        (
            ,
            address storedReceiver2,
            ,
            ,
            uint256 storedCounter2,
            ,
            ,
            uint256 storedReward2
        ) = luckyBuy.luckyBuys(1);

        assertEq(
            storedReceiver1,
            receiver,
            "First stored receiver should match"
        );
        assertEq(
            storedReceiver2,
            receiver2,
            "Second stored receiver should match"
        );
        assertEq(storedCounter1, 0, "First receiver counter should be 0");
        assertEq(storedCounter2, 0, "Second receiver counter should be 0");
        assertEq(storedReward1, reward, "First reward should match");
        assertEq(storedReward2, reward, "Second reward should match");

        vm.stopPrank();
    }

    function testCommitWithVaryingAmounts() public {
        uint256 amount1 = 0.5 ether;
        uint256 amount2 = 2 ether;

        vm.startPrank(user);
        vm.deal(user, amount1 + amount2);

        luckyBuy.commit{value: amount1}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        luckyBuy.commit{value: amount2}(
            receiver,
            cosigner,
            seed + 1,
            orderHash,
            reward
        );

        (, , , , , , uint256 storedAmount1, uint256 storedReward1) = luckyBuy
            .luckyBuys(0);

        (, , , , , , uint256 storedAmount2, uint256 storedReward2) = luckyBuy
            .luckyBuys(1);

        assertEq(storedAmount1, amount1, "First stored amount should match");
        assertEq(storedAmount2, amount2, "Second stored amount should match");
        assertEq(storedReward1, reward, "First stored reward should match");
        assertEq(storedReward2, reward, "Second stored reward should match");

        vm.stopPrank();
    }

    function testCommitCounterIncrement() public {
        vm.startPrank(user);
        vm.deal(user, amount * 5);
        for (uint i = 0; i < 5; i++) {
            console.log("Here:");
            luckyBuy.commit{value: amount}(
                receiver,
                cosigner,
                seed + i,
                orderHash,
                reward
            );

            assertEq(
                luckyBuy.luckyBuyCount(receiver),
                i + 1,
                "Receiver counter should increment correctly"
            );

            (, , , , uint256 storedCounter, , , ) = luckyBuy.luckyBuys(i);
            console.log(storedCounter);
            assertEq(storedCounter, i, "Stored counter should match index");
        }

        vm.stopPrank();
    }

    function testSetMaxReward() public {
        uint256 startMaxReward = luckyBuy.maxReward();

        vm.expectRevert();
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            startMaxReward * 2
        );

        vm.expectRevert();
        luckyBuy.setMaxReward(startMaxReward * 2);

        vm.startPrank(admin);
        luckyBuy.setMaxReward(startMaxReward * 2);

        assertEq(luckyBuy.maxReward(), startMaxReward * 2);

        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            startMaxReward * 2
        );

        vm.expectRevert();
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            startMaxReward * 3
        );
    }

    function testDepositTreasury() public {
        // Initial balance check
        uint256 initialBalance = address(luckyBuy).balance;

        // Test direct ETH transfer
        vm.deal(user, 1 ether);
        vm.prank(user);
        (bool success, ) = address(luckyBuy).call{value: 1 ether}("");

        assertTrue(success, "ETH transfer should succeed");
        assertEq(
            address(luckyBuy).balance,
            initialBalance + 1 ether,
            "Contract balance should increase by 1 ether"
        );
    }

    function testDepositTreasuryFromDifferentAccounts() public {
        address user2 = address(0x8);
        uint256 initialBalance = address(luckyBuy).balance;

        // First deposit from user1
        vm.deal(user, 0.5 ether);
        vm.prank(user);
        (bool success1, ) = address(luckyBuy).call{value: 0.5 ether}("");

        // Second deposit from user2
        vm.deal(user2, 1.5 ether);
        vm.prank(user2);
        (bool success2, ) = address(luckyBuy).call{value: 1.5 ether}("");

        assertTrue(success1 && success2, "Both transfers should succeed");
        assertEq(
            address(luckyBuy).balance,
            initialBalance + 2 ether,
            "Contract balance should increase by total amount"
        );
    }

    function testPredictAddressAndPreFund() public {
        // Calculate the future address of LuckyBuy contract
        address predictedAddress = computeCreateAddress(
            admin,
            vm.getNonce(admin)
        );

        // Pre-fund the future contract address
        vm.deal(predictedAddress, 5 ether);
        assertEq(
            predictedAddress.balance,
            5 ether,
            "Predicted address should be funded"
        );

        // Deploy LuckyBuy from admin account
        vm.prank(admin);
        LuckyBuy newLuckyBuy = new LuckyBuy(protocolFee);

        // Verify the deployment address matches prediction
        assertEq(
            address(newLuckyBuy),
            predictedAddress,
            "Deployed address should match prediction"
        );

        // Verify the contract balance is preserved
        assertEq(
            address(newLuckyBuy).balance,
            5 ether,
            "Contract should maintain pre-funded balance"
        );
    }

    function testCommitWithEqualValueAndReward() public {
        vm.startPrank(user);
        vm.deal(user, 1 ether);

        // Try to commit with msg.value equal to reward
        // Guarantee win, but they pay a fee
        luckyBuy.commit{value: 1 ether}(
            receiver,
            cosigner,
            seed,
            orderHash,
            1 ether // reward equal to msg.value
        );

        vm.stopPrank();
    }

    function testPauseAndUnpause() public {
        vm.startPrank(admin);
        luckyBuy.pause();
        vm.stopPrank();

        assertEq(luckyBuy.paused(), true);

        vm.expectRevert();
        luckyBuy.pause();

        vm.startPrank(admin);
        luckyBuy.unpause();
        vm.stopPrank();

        vm.expectRevert();
        luckyBuy.unpause();

        assertEq(luckyBuy.paused(), false);
    }

    function testCommitWhenPaused() public {
        vm.startPrank(admin);
        luckyBuy.pause();
        vm.stopPrank();

        vm.expectRevert();
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );
    }

    function testFulfillWhenPaused() public {
        // First create a valid commit
        vm.startPrank(receiver);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );
        vm.stopPrank();

        // Then pause and try to fulfill
        vm.startPrank(admin);
        luckyBuy.pause();
        vm.stopPrank();

        vm.expectRevert();
        luckyBuy.fulfill(
            0,
            receiver,
            new bytes(0),
            reward,
            address(0),
            0,
            new bytes(0)
        );
    }

    function testMaxRewardUpdate() public {
        vm.startPrank(admin);
        uint256 newMaxReward = 50 ether;

        vm.expectEmit(true, true, true, false);
        emit MaxRewardUpdated(reward, newMaxReward);

        luckyBuy.setMaxReward(newMaxReward);
        assertEq(luckyBuy.maxReward(), newMaxReward);
        vm.stopPrank();
    }

    function testCommitWithRewardBelowMinimum() public {
        uint256 belowMinReward = luckyBuy.BASE_POINTS() - 1;

        vm.expectRevert(LuckyBuy.InvalidReward.selector);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            belowMinReward
        );
    }

    function testTreasuryBalanceManagement() public {
        uint256 initialBalance = address(luckyBuy).balance;
        uint256 depositAmount = 5 ether;

        // Test direct ETH transfer
        (bool success, ) = address(luckyBuy).call{value: depositAmount}("");
        assertTrue(success);
        assertEq(luckyBuy.treasuryBalance(), initialBalance + depositAmount);

        // Test balance update during commit
        vm.startPrank(receiver);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );
        vm.stopPrank();

        assertEq(luckyBuy.treasuryBalance(), depositAmount);
        assertEq(luckyBuy.commitBalance(), amount);
        assertEq(luckyBuy.protocolBalance(), 0);
    }

    function testCommitId() public {
        vm.startPrank(user);
        vm.deal(user, amount);

        uint256 commitId = luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        assertEq(luckyBuy.luckyBuyCount(receiver), 1);

        vm.stopPrank();

        assertEq(commitId, 0);

        (uint256 id, , , , , , , ) = luckyBuy.luckyBuys(commitId);
        assertEq(id, commitId);
    }

    function testInvalidAmountOverOdds() public {
        vm.startPrank(user);
        vm.deal(user, 2 ether);

        // Try to commit with amount that would result in >100% odds
        // If amount * BASE_POINTS / reward > BASE_POINTS, it should revert
        vm.expectRevert(LuckyBuy.InvalidAmount.selector);
        luckyBuy.commit{value: 2 ether}(
            receiver,
            cosigner,
            seed,
            orderHash,
            1 ether // This would result in 200% odds
        );

        vm.stopPrank();
    }

    function testProtocolFee() public {
        vm.startPrank(admin);
        luckyBuy.setProtocolFee(100);
        vm.stopPrank();

        assertEq(luckyBuy.protocolFee(), 100);
    }

    function testCalculateFee() public {
        uint256 amount = 1 ether;
        uint256 protocolFee = 100;

        vm.startPrank(admin);
        luckyBuy.setProtocolFee(protocolFee);
        vm.stopPrank();

        uint256 fee = luckyBuy.calculateFee(amount);
        assertEq(fee, (amount * protocolFee) / luckyBuy.BASE_POINTS());
    }

    function testCommitWithFee() public {
        uint256 amount = 1 ether;
        uint256 protocolFee = 100;

        vm.startPrank(admin);
        luckyBuy.setProtocolFee(protocolFee);
        vm.stopPrank();

        uint256 fee = luckyBuy.calculateFee(reward);
        uint256 amountWithFee = amount + fee;

        vm.startPrank(user);
        vm.deal(user, amountWithFee);

        luckyBuy.commit{value: amountWithFee}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        (
            uint256 id,
            ,
            ,
            ,
            ,
            ,
            uint256 amountWithoutFee,
            uint256 reward
        ) = luckyBuy.luckyBuys(0);
        assertEq(amountWithoutFee, amount);
        assertEq(amountWithFee, address(luckyBuy).balance);
    }

    function testWithdrawSuccess() public {
        uint256 withdrawAmount = 1 ether;

        // Fund the contract first
        vm.deal(address(this), withdrawAmount);
        (bool success, ) = address(luckyBuy).call{value: withdrawAmount}("");
        assertTrue(success, "Initial funding should succeed");

        uint256 initialBalance = address(luckyBuy).balance;
        uint256 initialAdminBalance = address(admin).balance;

        vm.expectEmit(true, true, true, false);
        emit Withdrawal(admin, withdrawAmount);

        vm.prank(admin);
        luckyBuy.withdraw(withdrawAmount);

        assertEq(
            address(luckyBuy).balance,
            initialBalance - withdrawAmount,
            "Contract balance should decrease"
        );
        assertEq(
            address(admin).balance,
            initialAdminBalance + withdrawAmount,
            "Admin balance should increase"
        );
        assertEq(
            luckyBuy.treasuryBalance(),
            initialBalance - withdrawAmount,
            "Contract balance state should update"
        );
    }

    function testWithdrawInsufficientBalance() public {
        uint256 withdrawAmount = 1 ether;

        // Try to withdraw without funding
        vm.startPrank(admin);
        vm.expectRevert(LuckyBuy.InsufficientBalance.selector);
        luckyBuy.withdraw(withdrawAmount);
        vm.stopPrank();

        // Fund with less than withdraw amount
        vm.deal(address(this), withdrawAmount / 2);
        (bool success, ) = address(luckyBuy).call{value: withdrawAmount / 2}(
            ""
        );
        assertTrue(success, "Initial funding should succeed");

        // Try to withdraw more than available
        vm.startPrank(admin);
        vm.expectRevert(LuckyBuy.InsufficientBalance.selector);
        luckyBuy.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function testWithdrawNonAdmin() public {
        uint256 withdrawAmount = 1 ether;

        // Fund the contract
        vm.deal(address(this), withdrawAmount);
        (bool success, ) = address(luckyBuy).call{value: withdrawAmount}("");
        assertTrue(success, "Initial funding should succeed");

        // Try to withdraw as non-admin
        vm.startPrank(user);
        vm.expectRevert();
        luckyBuy.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function testWithdrawMultiple() public {
        uint256 totalAmount = 5 ether;
        uint256 withdrawAmount = 1 ether;

        // Fund the contract
        vm.deal(address(this), totalAmount);
        (bool success, ) = address(luckyBuy).call{value: totalAmount}("");
        assertTrue(success, "Initial funding should succeed");

        uint256 initialBalance = address(luckyBuy).balance;
        uint256 initialAdminBalance = address(admin).balance;

        // Perform multiple withdrawals
        for (uint256 i = 0; i < 5; i++) {
            vm.startPrank(admin);
            luckyBuy.withdraw(withdrawAmount);
            vm.stopPrank();

            assertEq(
                address(luckyBuy).balance,
                initialBalance - (withdrawAmount * (i + 1)),
                "Contract balance should decrease correctly"
            );
            assertEq(
                address(admin).balance,
                initialAdminBalance + (withdrawAmount * (i + 1)),
                "Admin balance should increase correctly"
            );
            assertEq(
                luckyBuy.treasuryBalance(),
                initialBalance - (withdrawAmount * (i + 1)),
                "Contract balance state should update correctly"
            );
        }
    }

    function testWithdrawZeroAmount() public {
        // Try to withdraw zero amount
        vm.startPrank(admin);
        luckyBuy.withdraw(0);
        vm.stopPrank();

        // State should remain unchanged
        assertEq(
            address(luckyBuy).balance,
            0,
            "Contract balance should remain 0"
        );
        assertEq(
            luckyBuy.treasuryBalance(),
            0,
            "Contract balance state should remain 0"
        );
    }

    function testEmergencyWithdraw() public {
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed,
            orderHash,
            reward
        );

        uint256 initialBalance = address(admin).balance;

        vm.startPrank(admin);
        luckyBuy.emergencyWithdraw();
        vm.stopPrank();

        assertEq(address(luckyBuy).balance, 0);
        assertEq(address(admin).balance, initialBalance + amount);
        assertEq(luckyBuy.treasuryBalance(), 0);
        assertEq(luckyBuy.commitBalance(), 0);
        assertEq(luckyBuy.protocolBalance(), 0);
        assertEq(luckyBuy.paused(), true);
    }

    function testInvalidProtocolFee() public {
        vm.startPrank(admin);
        uint256 invalidProtocolFee = luckyBuy.BASE_POINTS() + 1;
        vm.expectRevert(LuckyBuy.InvalidProtocolFee.selector);
        luckyBuy.setProtocolFee(invalidProtocolFee);
        vm.stopPrank();
    }

    function testProtocolFeeUpdate() public {
        vm.startPrank(admin);
        luckyBuy.setProtocolFee(100);
        vm.stopPrank();
    }

    function testSetCommitExpireTime() public {
        uint256 expireTime = 10 days;
        vm.startPrank(admin);
        luckyBuy.setCommitExpireTime(expireTime);
        vm.stopPrank();
        assertEq(luckyBuy.commitExpireTime(), expireTime);
    }

    function testSetCommitExpireTimeZero() public {
        vm.startPrank(admin);
        vm.expectRevert(LuckyBuy.InvalidCommitExpireTime.selector);
        luckyBuy.setCommitExpireTime(0);
    }

    function testExpireCommit() public {
        vm.startPrank(admin);
        luckyBuy.setCommitExpireTime(1 days);

        vm.expectRevert(LuckyBuy.InvalidCommitExpireTime.selector);
        luckyBuy.setCommitExpireTime(0);

        vm.stopPrank();

        vm.deal(address(this), amount);

        uint256 initialBalance = address(this).balance;

        luckyBuy.commit{value: amount}(
            address(this),
            cosigner,
            seed,
            orderHash,
            reward
        );

        assertEq(address(this).balance, initialBalance - amount);

        vm.warp(block.timestamp + 2 days);

        luckyBuy.expire(0);

        assertEq(address(this).balance, initialBalance);

        vm.expectRevert(LuckyBuy.CommitIsExpired.selector);
        luckyBuy.expire(0);
    }

    function testExpireCommitNotOwner() public {
        vm.startPrank(admin);
        luckyBuy.setCommitExpireTime(1 days);
        vm.stopPrank();

        vm.deal(address(this), amount);
        luckyBuy.commit{value: amount}(
            address(this),
            cosigner,
            seed,
            orderHash,
            reward
        );

        vm.expectRevert(LuckyBuy.CommitNotExpired.selector);
        luckyBuy.expire(0);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert(LuckyBuy.InvalidCommitOwner.selector);
        vm.prank(user);
        luckyBuy.expire(0);
    }

    function testExpireCommitAlreadyFulfilled() public {
        vm.startPrank(admin);
        luckyBuy.setCommitExpireTime(1 days);
        vm.stopPrank();

        vm.deal(address(this), amount);
        luckyBuy.commit{value: amount}(
            address(this),
            cosigner,
            seed,
            orderHash,
            reward
        );

        luckyBuy.setIsFulfilled(0, true);
        assertEq(luckyBuy.isFulfilled(0), true);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert(LuckyBuy.AlreadyFulfilled.selector);
        luckyBuy.expire(0);
    }

    function testFulfillIsExpired() public {
        vm.startPrank(admin);
        luckyBuy.setCommitExpireTime(1 days);
        vm.stopPrank();

        vm.deal(address(this), 100 ether);
        (bool success, ) = address(luckyBuy).call{value: 10 ether}("");
        assertTrue(success, "Initial funding should succeed");
        luckyBuy.commit{value: amount}(
            address(this),
            cosigner,
            seed,
            orderHash,
            reward
        );

        assertEq(luckyBuy.isFulfilled(0), false);

        vm.warp(block.timestamp + 2 days);

        luckyBuy.expire(0);

        assertEq(luckyBuy.isExpired(0), true);

        vm.expectRevert(LuckyBuy.CommitIsExpired.selector);
        luckyBuy.fulfill(
            0,
            address(this),
            new bytes(0),
            reward,
            address(0),
            0,
            new bytes(0)
        );
    }

    receive() external payable {}
}
