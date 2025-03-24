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
    address user = address(0x6);

    bool skipTest = true;

    uint256 constant COSIGNER_PRIVATE_KEY = 1234;
    address cosigner;
    uint256 protocolFee = 0;

    uint256 seed = 12345;
    address marketplace = address(0);
    uint256 orderAmount = 1 ether;
    bytes32 orderData = hex"00";
    address orderToken = address(0);
    uint256 orderTokenId = 0;
    bytes32 orderHash = hex"";
    uint256 amount = 1 ether;
    uint256 reward = 10 ether; // 10% odds

    string constant OUTPUT_FILE = "./simulation_results.csv";

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new MockLuckyBuy(protocolFee);
        vm.deal(admin, 1000000 ether);
        vm.deal(user, 100000 ether);

        (bool success, ) = address(luckyBuy).call{value: 10000 ether}("");
        require(success, "Failed to deploy contract");

        // Set up cosigner with known private key
        cosigner = vm.addr(COSIGNER_PRIVATE_KEY);
        // Add a cosigner for testing
        luckyBuy.addCosigner(cosigner);
        vm.stopPrank();
    }

    function signCommit(
        uint256 commitId,
        address receiver,
        uint256 seed,
        uint256 counter,
        bytes32 orderHash,
        uint256 amount,
        uint256 reward
    ) public returns (bytes memory) {
        // Create the commit data struct
        ISignatureVerifier.CommitData memory commitData = ISignatureVerifier
            .CommitData({
                id: commitId,
                receiver: receiver,
                cosigner: cosigner,
                seed: seed,
                counter: counter,
                orderHash: orderHash,
                amount: amount,
                reward: reward
            });

        // Get the digest using the LuckyBuy contract's hash function
        bytes32 digest = luckyBuy.hash(commitData);

        // Sign the digest with the cosigner's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(COSIGNER_PRIVATE_KEY, digest);

        // Return the signature
        return abi.encodePacked(r, s, v);
    }

    function testCreateCommit() public {
        if (skipTest) return;
        // Create order hash for a simple ETH transfer - this stays the same for all plays
        bytes32 orderHash = luckyBuy.hashOrder(
            address(0), // to address(0)
            1 ether, // amount 1 ether (reward amount)
            "", // no data
            address(0), // no token
            0 // no token id
        );

        // Calculate odds: amount/reward = 0.1/1 = 10%
        uint256 commitAmount = 0.5 ether;
        uint256 rewardAmount = 1 ether;
        uint256 odds = (commitAmount * 100000) / rewardAmount;
        console.log("\nGame Parameters:");
        console.log("Odds of winning (basis points):", odds); // Should be 1000 (10%)
        console.log("Commit Amount:", commitAmount);
        console.log("Reward Amount:", rewardAmount);
        console.log("\nStarting 10 game simulations...\n");

        for (uint256 i = 0; i < 40_000; i++) {
            console.log("Game", i + 1, ":");

            vm.startPrank(user);
            // Create commit
            uint256 commitId = luckyBuy.commit{value: commitAmount}(
                user, // receiver
                cosigner, // cosigner
                seed, // random seed
                orderHash, // order hash we just created
                rewardAmount // reward amount (10x the commit for 10% odds)
            );
            vm.stopPrank();

            // Get the counter for this commit
            uint256 counter = luckyBuy.luckyBuyCount(user) - 1;

            // Sign the commit
            bytes memory signature = signCommit(
                commitId,
                user,
                seed,
                counter,
                orderHash,
                commitAmount,
                rewardAmount
            );

            // Track treasury balance for win/loss determination
            uint256 initialTreasuryBalance = luckyBuy.treasuryBalance();

            // Fulfill the commit
            vm.startPrank(user);
            luckyBuy.fulfill(
                commitId,
                address(0), // marketplace
                "", // orderData
                rewardAmount, // orderAmount
                address(0), // token
                0, // tokenId
                signature
            );
            vm.stopPrank();

            // Calculate and log results
            bool won = luckyBuy.treasuryBalance() < initialTreasuryBalance;

            console.log("  Commit ID:", commitId);
            console.log("  Counter:", counter);
            console.log("  Won:", won);
            console.log(
                "  Treasury Balance Change:",
                won
                    ? initialTreasuryBalance - luckyBuy.treasuryBalance()
                    : luckyBuy.treasuryBalance() - initialTreasuryBalance
            );
            console.log("  LuckyBuy Balance:", luckyBuy.treasuryBalance());
            console.log("");

            // Write to CSV
            string memory row = string(
                abi.encodePacked(
                    vm.toString(commitId),
                    ",",
                    won ? "true" : "false",
                    ",",
                    vm.toString(
                        won
                            ? initialTreasuryBalance -
                                luckyBuy.treasuryBalance()
                            : luckyBuy.treasuryBalance() -
                                initialTreasuryBalance
                    ),
                    ",",
                    vm.toString(luckyBuy.treasuryBalance())
                )
            );
            vm.writeLine(OUTPUT_FILE, row);
        }
    }
}
