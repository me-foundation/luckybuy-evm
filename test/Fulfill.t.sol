// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "forge-std/Test.sol";
import "src/LuckyBuy.sol";

// I grabbed this data from the Magic Eden API. This is a seaport order that is valid as of FORK_BLOCK:
// curl 'https://api-mainnet.magiceden.us/v3/rtp/ethereum/execute/buy/v7' \
//   -H 'accept: application/json, text/plain, */*' \
//   -H 'accept-language: en-US,en;q=0.9' \
//   -H 'content-type: application/json' \
//   -H 'origin: https://magiceden.us' \
//   -H 'priority: u=1, i' \
//   -H 'referer: https://magiceden.us/' \
//   --data-raw '{"items":[{"key":"0x415a82e77642113701fe190554fddd7701c3b262:8295","token":"0x415a82e77642113701fe190554fddd7701c3b262:8295","is1155":false,"source":"opensea.io","fillType":"trade","quantity":1}],"taker":"0x522B3294E6d06aA25Ad0f1B8891242E335D3B459","source":"magiceden.us","partial":true,"currency":"0x0000000000000000000000000000000000000000","currencyChainId":1,"forwarderChannel":"0x5ebc127fae83ed5bdd91fc6a5f5767E259dF5642","maxFeePerGas":"100000000000","maxPriorityFeePerGas":"100000000000","normalizeRoyalties":false}'

contract MockLuckyBuy is LuckyBuy {
    constructor() LuckyBuy() {}

    function fulfillOrder(
        address txTo_,
        bytes calldata data_,
        uint256 amount_
    ) public returns (bool success) {
        (success, ) = txTo_.call{value: amount_}(data_);
    }
}
contract FulfillTest is Test {
    MockLuckyBuy luckyBuy;
    address admin = address(0x1);
    address user = address(0x2);
    address receiver = address(0x3);
    address cosigner = 0xE052c9CFe22B5974DC821cBa907F1DAaC7979c94;
    bytes signature =
        hex"6e770e2253444563387afd1d832f07704ca9bdef17e46763219a2680f77c3f530ae8541e17eea7601b981b3f50711b980e534d0226ef8a53fea579993be6d1241b";
    // The target block number from the comment
    uint256 constant FORK_BLOCK = 22035010;

    // check test/signer.ts to verify
    bytes32 constant TypescriptOrderHash =
        hex"00b839f580603f650be760ccd549d9ddbb877aa80ccf709f00f1950f51c35a99";

    address constant RECEIVER = 0xE052c9CFe22B5974DC821cBa907F1DAaC7979c94;
    bytes constant DATA =
        hex"e7acab24000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000006e00000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000000000000000000000000000e052c9cfe22b5974dc821cba907f1daac7979c9400000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000006400000000000000000000000000db2536a038f68a2c4d5f7428a98299cf566a59a000000000000000000000000004c00500000ad104d7dbd00e3ae0a5c00560c000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000067cf174c0000000000000000000000000000000000000000000000000000000067d30b520000000000000000000000000000000000000000000000000000000000000000360c6ebe000000000000000000000000000000000000000033c2f8be86434b860000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000415a82e77642113701fe190554fddd7701c3b262000000000000000000000000000000000000000000000000000000000000206700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001101eedb780000000000000000000000000000000000000000000000000000001101eedb78000000000000000000000000000db2536a038f68a2c4d5f7428a98299cf566a59a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000174876e800000000000000000000000000000000000000000000000000000000174876e8000000000000000000000000000000a26b00c1f0df003000390027140000faa719000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001176592e000000000000000000000000000000000000000000000000000000001176592e0000000000000000000000000005d0d2229c75f13cb989bc5b48966f19170e879c600000000000000000000000000000000000000000000000000000000000000e3937d7c3c7bad7cce0343e161705a5cb7174c4b10366d4501fc48bddb0466cef2657da121e80b7e9e8dc7580fd672177fc431ed96a3bfdaa8160c2619c247a10500000f5555e3c5fe5d036886ef457c6099624d36106d0a7a5963416e619e0dd70ef5afb6c923cf26789f0637c18b43ad5509d0ad354daf1410a3574aebf3e5f420371f2e2b5d598b446140dc14a0a0ab918e458caf518097b88a1e2bacf2641058740982e1363e69190f9b615b749711f5529e4ba38f45955fa7a0e2ed592e3d6a88544d8707848281e625f61622aeeccb0af71cff27e28538a891165116f41d8c6dbf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d4da48b1ebc9d95";

    // Token address from the transaction data
    address constant TARGET = 0x0000000000000068F116a894984e2DB1123eB395; // Seaport
    address constant TOKEN = 0x415A82E77642113701FE190554fDDD7701c3B262;
    uint256 constant TOKEN_ID = 8295;
    uint256 constant REWARD = 20000000000000 wei;
    uint256 constant COMMIT_AMOUNT = REWARD / 100; // 1%

    IERC721 nft = IERC721(TOKEN);

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

    // Flag to track if we should run the actual tests
    bool shouldRunTests;

    function setUp() public {
        string memory rpcUrl = vm.envOr("MAINNET_RPC_URL", string(""));

        // Only set up the fork if the RPC URL is provided
        if (bytes(rpcUrl).length > 0) {
            vm.createSelectFork(rpcUrl, FORK_BLOCK);
            vm.deal(address(this), 1 ether);
            shouldRunTests = true;

            vm.startPrank(admin);
            luckyBuy = new MockLuckyBuy();
            vm.deal(admin, 100 ether);
            vm.deal(address(this), 100 ether);
            // Add a cosigner for testing
            luckyBuy.addCosigner(cosigner);
            vm.stopPrank();
        } else {
            console.log("Skipping tests: MAINNET_RPC_URL not provided");
            shouldRunTests = false;
        }
    }

    function test_baseline_fulfill() public {
        // Skip the test entirely if we don't have an RPC URL
        if (!shouldRunTests) {
            console.log("Test skipped: MAINNET_RPC_URL not defined");
            return;
        }

        // Send the transaction
        (bool success, ) = TARGET.call{value: REWARD}(DATA);

        // Verify the transaction was successful
        assertTrue(success, "Transaction failed");

        console.log("NFT owner:", nft.ownerOf(TOKEN_ID));
        console.log("Target:", TARGET);
        console.log("Token:", TOKEN);
        console.log("Token ID:", TOKEN_ID);
        console.log("TX Value:", REWARD);

        console.log(address(luckyBuy));

        assertEq(nft.ownerOf(TOKEN_ID), RECEIVER);
    }

    function test_luckybuy_fulfill() public {
        // Skip the test entirely if we don't have an RPC URL
        if (!shouldRunTests) {
            console.log("Test skipped: MAINNET_RPC_URL not defined");
            return;
        }
        // deposit treasury
        (bool success, ) = address(luckyBuy).call{value: 10 ether}("");

        assertEq(success, true);

        luckyBuy.fulfillOrder(TARGET, DATA, REWARD);

        assertEq(nft.ownerOf(TOKEN_ID), RECEIVER);
    }

    function test_end_to_end() public {
        // Skip the test entirely if we don't have an RPC URL
        if (!shouldRunTests) {
            console.log("Test skipped: MAINNET_RPC_URL not defined");
            return;
        }

        // The user selects a token and amount to pay from our API.
        // This gives us TARGET, REWARD, DATA, TOKEN, TOKEN_ID
        // Typescript will hash to: 0x00b839f580603f650be760ccd549d9ddbb877aa80ccf709f00f1950f51c35a99

        bytes32 orderHash = luckyBuy.hashOrder(
            TARGET,
            REWARD,
            DATA,
            TOKEN,
            TOKEN_ID
        );

        assertEq(orderHash, TypescriptOrderHash);

        // backend builds the commit data off chain. The user should technically choose the cosigner or we could be accused of trying random cosigners until we find one that benefits us.
        uint256 seed = 12345; // User provides this data

        // User submits the commit data from the back end with their payment to the contract
        vm.expectEmit(true, true, true, false);
        emit Commit(
            user,
            0, // First commit ID should be 0
            RECEIVER,
            cosigner,
            seed,
            0, // First counter for this receiver should be 0
            orderHash,
            COMMIT_AMOUNT,
            REWARD
        );
        vm.prank(user);
        luckyBuy.commit{value: COMMIT_AMOUNT}(
            RECEIVER,
            cosigner,
            seed,
            orderHash,
            REWARD
        );

        // Backend sees the event

        // User submits the commit data and signature to the contract
    }

    function testhashDataView() public {
        console.logBytes32(
            luckyBuy.hashOrder(TARGET, REWARD, DATA, TOKEN, TOKEN_ID)
        );
    }
}
