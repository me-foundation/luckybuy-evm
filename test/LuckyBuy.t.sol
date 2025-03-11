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
    string orderHash = "testOrderHash123";
    uint256 amount = 1 ether;

    event Commit(
        address indexed sender,
        uint256 indexed commitId,
        address indexed receiver,
        address cosigner,
        uint256 seed,
        uint256 counter,
        string orderHash,
        uint256 amount,
        bytes32 hash
    );

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new LuckyBuy();

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
            bytes32(0) // We don't check the hash value
        );

        luckyBuy.commit{value: amount}(receiver, cosigner, seed, orderHash);

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
            string memory storedOrderHash,
            uint256 storedAmount
        ) = luckyBuy.luckyBuys(0);

        assertEq(id, 0, "Commit ID should be 0");
        assertEq(storedReceiver, receiver, "Receiver should match");
        assertEq(storedCosigner, cosigner, "Cosigner should match");
        assertEq(storedSeed, seed, "Seed should match");
        assertEq(storedCounter, 0, "Counter should be 0");
        assertEq(storedOrderHash, orderHash, "Order hash should match");
        assertEq(storedAmount, amount, "Amount should match");

        vm.stopPrank();
    }

    function testCommitMultipleTimes() public {
        vm.startPrank(user);
        vm.deal(user, amount * 2);

        luckyBuy.commit{value: amount}(receiver, cosigner, seed, orderHash);

        assertEq(
            luckyBuy.luckyBuyCount(receiver),
            1,
            "Receiver counter should be 1 after first commit"
        );

        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed + 1,
            "secondOrderHash"
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
            string memory storedOrderHash,
            uint256 storedAmount
        ) = luckyBuy.luckyBuys(1);

        assertEq(id, 1, "Second commit ID should be 1");
        assertEq(storedReceiver, receiver, "Receiver should match");
        assertEq(storedCosigner, cosigner, "Cosigner should match");
        assertEq(storedSeed, seed + 1, "Seed should match");
        assertEq(storedCounter, 1, "Counter should be 1 for second commit");
        assertEq(storedOrderHash, "secondOrderHash", "Order hash should match");
        assertEq(storedAmount, amount, "Amount should match");

        vm.stopPrank();
    }

    function testCommitWithZeroAmount() public {
        vm.startPrank(user);

        vm.expectRevert(LuckyBuy.InvalidAmount.selector);
        luckyBuy.commit{value: 0}(receiver, cosigner, seed, orderHash);

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
            orderHash
        );

        vm.stopPrank();
    }

    function testCommitWithZeroAddressReceiver() public {
        vm.startPrank(user);
        vm.deal(user, amount);

        vm.expectRevert(LuckyBuy.InvalidReceiver.selector);
        luckyBuy.commit{value: amount}(address(0), cosigner, seed, orderHash);

        vm.stopPrank();
    }

    function testCommitWithRemovedCosigner() public {
        vm.startPrank(admin);
        luckyBuy.removeCosigner(cosigner);
        vm.stopPrank();

        vm.startPrank(user);
        vm.deal(user, amount);

        vm.expectRevert(LuckyBuy.InvalidCoSigner.selector);
        luckyBuy.commit{value: amount}(receiver, cosigner, seed, orderHash);

        vm.stopPrank();
    }

    function testCommitFromDifferentUsers() public {
        address user2 = address(0x6);

        vm.startPrank(user);
        vm.deal(user, amount);
        luckyBuy.commit{value: amount}(receiver, cosigner, seed, orderHash);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.deal(user2, amount);
        luckyBuy.commit{value: amount}(
            receiver,
            cosigner,
            seed + 1,
            "user2OrderHash"
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
            string memory orderHash1,
            uint256 amount1
        ) = luckyBuy.luckyBuys(0);

        (
            uint256 id2,
            address receiver2,
            address cosigner2,
            ,
            ,
            string memory orderHash2,
            uint256 amount2
        ) = luckyBuy.luckyBuys(1);

        assertEq(id1, 0, "First commit ID should be 0");
        assertEq(id2, 1, "Second commit ID should be 1");
        assertEq(receiver1, receiver, "First receiver should match");
        assertEq(receiver2, receiver, "Second receiver should match");
        assertEq(orderHash1, orderHash, "First order hash should match");
        assertEq(
            orderHash2,
            "user2OrderHash",
            "Second order hash should match"
        );
        assertEq(amount1, amount, "First amount should match");
        assertEq(amount2, amount, "Second amount should match");
    }

    function testCommitToDifferentReceivers() public {
        address receiver2 = address(0x7);

        vm.startPrank(user);
        vm.deal(user, amount * 2);

        luckyBuy.commit{value: amount}(receiver, cosigner, seed, orderHash);

        luckyBuy.commit{value: amount}(
            receiver2,
            cosigner,
            seed + 1,
            "receiver2OrderHash"
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

        (, address storedReceiver1, , , uint256 storedCounter1, , ) = luckyBuy
            .luckyBuys(0);

        (, address storedReceiver2, , , uint256 storedCounter2, , ) = luckyBuy
            .luckyBuys(1);

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
            "smallAmount"
        );

        luckyBuy.commit{value: amount2}(
            receiver,
            cosigner,
            seed + 1,
            "largeAmount"
        );

        (, , , , , , uint256 storedAmount1) = luckyBuy.luckyBuys(0);

        (, , , , , , uint256 storedAmount2) = luckyBuy.luckyBuys(1);

        assertEq(storedAmount1, amount1, "First stored amount should match");
        assertEq(storedAmount2, amount2, "Second stored amount should match");

        vm.stopPrank();
    }

    function testCommitCounterIncrement() public {
        vm.startPrank(user);
        vm.deal(user, amount * 5);

        for (uint i = 0; i < 5; i++) {
            luckyBuy.commit{value: amount}(
                receiver,
                cosigner,
                seed + i,
                string(abi.encodePacked("orderHash", i))
            );

            assertEq(
                luckyBuy.luckyBuyCount(receiver),
                i + 1,
                "Receiver counter should increment correctly"
            );

            (, , , , uint256 storedCounter, , ) = luckyBuy.luckyBuys(i);

            assertEq(storedCounter, i, "Stored counter should match index");
        }

        vm.stopPrank();
    }
}
