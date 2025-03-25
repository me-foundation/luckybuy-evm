// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/LuckyBuy.sol";

contract MinorBugsTest is Test {
    LuckyBuy public luckyBuy;
    address public admin;
    address public user;
    address public cosigner;
    address public marketplace;
    uint256 constant PROTOCOL_FEE = 500; // 5%
    uint256 constant BASE_POINTS = 10000;

    function setUp() public {
        admin = makeAddr("admin");
        user = makeAddr("user");
        cosigner = makeAddr("cosigner");
        marketplace = makeAddr("marketplace");

        vm.startPrank(admin);
        luckyBuy = new LuckyBuy(PROTOCOL_FEE);
        luckyBuy.addCosigner(cosigner);
        luckyBuy.grantRole(luckyBuy.OPS_ROLE(), admin);
        vm.stopPrank();
    }

    // Test #1: Edge case with minimum contribution and maximum reward
    function testMinContributionMaxReward() public {
        uint256 minContribution = 1; // 1 wei
        uint256 maxRewardAmount = luckyBuy.maxReward();
        bytes32 orderHash = bytes32(0);

        vm.deal(user, minContribution);
        vm.startPrank(user);

        // This should revert because the odds would be too low
        vm.expectRevert();
        luckyBuy.commit{value: minContribution}(
            user,
            cosigner,
            1234,
            orderHash,
            maxRewardAmount
        );

        vm.stopPrank();
    }

    // Test #2: Verify commit counter behavior
    function testCommitCounterOverflow() public {
        bytes32 orderHash = bytes32(0);
        uint256 amount = 0.1 ether;
        uint256 reward = 0.2 ether;

        vm.deal(user, amount * 3);
        vm.startPrank(user);

        // Create multiple commits and verify counter increments
        uint256 initialCounter = luckyBuy.luckyBuyCount(user);

        luckyBuy.commit{value: amount}(user, cosigner, 1234, orderHash, reward);

        assertEq(
            luckyBuy.luckyBuyCount(user),
            initialCounter + 1,
            "Counter should increment by 1"
        );

        luckyBuy.commit{value: amount}(user, cosigner, 1235, orderHash, reward);

        assertEq(
            luckyBuy.luckyBuyCount(user),
            initialCounter + 2,
            "Counter should increment by 2"
        );

        vm.stopPrank();
    }

    // Test #3: Check rounding behavior in fee calculations
    function testFeeRoundingEdgeCases() public {
        vm.startPrank(admin);
        // Set a small protocol fee to test rounding
        luckyBuy.setProtocolFee(1); // 0.01%
        vm.stopPrank();

        uint256 smallAmount = 100; // 100 wei

        // Calculate fee for small amount
        uint256 fee = luckyBuy.calculateFee(smallAmount);
        uint256 contributionWithoutFee = luckyBuy
            .calculateContributionWithoutFee(smallAmount);

        // Verify no value is lost in calculations
        assertEq(
            smallAmount,
            contributionWithoutFee + fee,
            "Fee calculations should not lose value"
        );
    }

    // Test #4: Verify commit expiry timing precision
    function testCommitExpiryPrecision() public {
        bytes32 orderHash = bytes32(0);
        uint256 amount = 0.1 ether;
        uint256 reward = 0.2 ether;

        vm.deal(user, amount);
        vm.startPrank(user);

        uint256 commitId = luckyBuy.commit{value: amount}(
            user,
            cosigner,
            1234,
            orderHash,
            reward
        );

        // Test exactly at expiry time
        vm.warp(block.timestamp + luckyBuy.commitExpireTime());
        vm.expectRevert(); // Should revert as not expired yet
        luckyBuy.expire(commitId);

        // Test one second after expiry
        vm.warp(block.timestamp + 1);
        luckyBuy.expire(commitId); // Should succeed

        vm.stopPrank();
    }

    // Test #5: Check behavior with zero address marketplace
    function testZeroAddressMarketplace() public {
        bytes32 orderHash = keccak256(
            abi.encodePacked(address(0), uint256(0.2 ether), "", address(0), 0)
        );
        uint256 amount = 0.1 ether;
        uint256 reward = 0.2 ether;

        vm.deal(user, amount);
        vm.startPrank(user);

        uint256 commitId = luckyBuy.commit{value: amount}(
            user,
            cosigner,
            1234,
            orderHash,
            reward
        );

        vm.stopPrank();

        // Try to fulfill with zero address marketplace
        vm.startPrank(cosigner);
        // This should work as the contract doesn't explicitly prevent zero address marketplace
        luckyBuy.fulfill(
            commitId,
            address(0),
            "",
            reward,
            address(0),
            0,
            abi.encodePacked(bytes32(uint256(1)))
        );
        vm.stopPrank();
    }

    // Test #6: Check multiple commits with same parameters
    function testDuplicateCommits() public {
        bytes32 orderHash = bytes32(0);
        uint256 amount = 0.1 ether;
        uint256 reward = 0.2 ether;

        vm.deal(user, amount * 2);
        vm.startPrank(user);

        // Create two commits with identical parameters
        uint256 commitId1 = luckyBuy.commit{value: amount}(
            user,
            cosigner,
            1234,
            orderHash,
            reward
        );

        uint256 commitId2 = luckyBuy.commit{value: amount}(
            user,
            cosigner,
            1234,
            orderHash,
            reward
        );

        // Verify they get different IDs despite same parameters
        assertTrue(commitId1 != commitId2, "Commits should have unique IDs");

        vm.stopPrank();
    }
}
