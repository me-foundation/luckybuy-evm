// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "src/LuckyBuy.sol";
import "test/Simulations.t.sol";

contract SimulationScript is Script {
    string constant OUTPUT_FILE = "./simulation_results_with_fee.csv";
    MockLuckyBuy luckyBuy;
    address admin = address(0x1);
    address user = address(0x2);
    uint256 constant COSIGNER_PRIVATE_KEY = 1234;
    address cosigner;
    uint256 protocolFee = 100;
    uint256 seed = 12345;

    function setUp() public {
        vm.startBroadcast(admin);
        luckyBuy = new MockLuckyBuy(protocolFee);
        vm.deal(admin, 1000000 ether);
        vm.deal(user, 100000 ether);

        (bool success, ) = address(luckyBuy).call{value: 10000 ether}("");
        require(success, "Failed to deploy contract");

        cosigner = vm.addr(COSIGNER_PRIVATE_KEY);
        luckyBuy.addCosigner(cosigner);
        vm.stopBroadcast();
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

        bytes32 digest = luckyBuy.hash(commitData);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(COSIGNER_PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function run() public {
        setUp();

        bytes32 orderHash = luckyBuy.hashOrder(
            address(0),
            1 ether,
            "",
            address(0),
            0
        );

        uint256 commitAmount = 0.5 ether;
        uint256 rewardAmount = 1 ether;
        uint256 fee = 0.05 ether;
        uint256 odds = (commitAmount * 100000) / rewardAmount;
        console.log("\nGame Parameters:");
        console.log("Odds of winning (basis points):", odds);
        console.log("Commit Amount:", commitAmount);
        console.log("Reward Amount:", rewardAmount);
        console.log("\nStarting 40k game simulations...\n");

        // Write CSV header
        vm.writeLine(OUTPUT_FILE, "commitId,won,balanceChange,treasuryBalance");

        uint256 BATCH_SIZE = 1000;
        uint256 TOTAL_ITERATIONS = 40_000;

        for (uint256 batch = 0; batch < TOTAL_ITERATIONS; batch += BATCH_SIZE) {
            uint256 endIndex = batch + BATCH_SIZE;
            if (endIndex > TOTAL_ITERATIONS) {
                endIndex = TOTAL_ITERATIONS;
            }

            console.log(
                "\nProcessing batch",
                batch / BATCH_SIZE + 1,
                "of",
                TOTAL_ITERATIONS / BATCH_SIZE
            );

            for (uint256 i = batch; i < endIndex; i++) {
                vm.startPrank(user);
                uint256 commitId = luckyBuy.commit{value: commitAmount + fee}(
                    user,
                    cosigner,
                    seed,
                    orderHash,
                    rewardAmount
                );
                vm.stopPrank();

                uint256 counter = luckyBuy.luckyBuyCount(user) - 1;
                bytes memory signature = signCommit(
                    commitId,
                    user,
                    seed,
                    counter,
                    orderHash,
                    commitAmount,
                    rewardAmount
                );

                uint256 initialTreasuryBalance = luckyBuy.treasuryBalance();

                vm.startPrank(user);
                luckyBuy.fulfill(
                    commitId,
                    address(0),
                    "",
                    rewardAmount,
                    address(0),
                    0,
                    signature
                );
                vm.stopPrank();

                bool won = luckyBuy.treasuryBalance() < initialTreasuryBalance;

                // Write to CSV with minimal console output
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
}
