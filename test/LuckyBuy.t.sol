// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "src/LuckyBuy.sol";

contract TestLuckyBuyCommit is Test {
    LuckyBuy luckyBuy;
    address admin = address(0x1);
    address user = address(0x2);
    address receiver = address(0x3);
    address cosigner = address(0x4);

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
        uint256 reward
    );

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new LuckyBuy();
        vm.deal(admin, 100 ether);
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
            reward
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

        // Act & Assert - Should revert with InvalidCoSigner
        vm.expectRevert(LuckyBuy.InvalidCoSigner.selector);
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

        vm.expectRevert(LuckyBuy.InvalidCoSigner.selector);
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
        LuckyBuy newLuckyBuy = new LuckyBuy();

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
}
