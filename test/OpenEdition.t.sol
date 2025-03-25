// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "src/LuckyBuy.sol";

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockLuckyBuy is LuckyBuy {
    constructor(uint256 protocolFee_) LuckyBuy(protocolFee_) {}

    function setIsFulfilled(uint256 commitId_, bool isFulfilled_) public {
        isFulfilled[commitId_] = isFulfilled_;
    }
}

contract MockERC1155 is ERC1155 {
    constructor(string memory uri_) ERC1155(uri_) {}

    function mint(address to, uint256 id, uint256 amount) public {
        _mint(to, id, amount, "");
    }
}

contract TestLuckyBuyOpenEdition is Test {
    MockLuckyBuy luckyBuy;
    MockERC1155 openEditionToken;
    address admin = address(0x1);
    address user = address(0x2);

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

    function setUp() public {
        vm.startPrank(admin);
        luckyBuy = new MockLuckyBuy(protocolFee);
        vm.deal(admin, 1000000 ether);
        vm.deal(user, 100000 ether);

        openEditionToken = new MockERC1155("");
        openEditionToken.mint(address(luckyBuy), 1, 1000000);

        (bool success, ) = address(luckyBuy).call{value: 10000 ether}("");
        require(success, "Failed to deploy contract");

        // Set up cosigner with known private key
        cosigner = vm.addr(COSIGNER_PRIVATE_KEY);
        // Add a cosigner for testing
        luckyBuy.addCosigner(cosigner);
        // Mint 1 open edition token id 1 on failures
        luckyBuy.setOpenEditionToken(address(openEditionToken), 1, 1);
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

    function testOpenEdition() public {
        // out of base points

        vm.prank(admin);

        uint256 commitAmount = 0.001 ether;
        uint256 rewardAmount = 1 ether;
        // Create order hash for a simple ETH transfer - this stays the same for all plays
        bytes32 orderHash = luckyBuy.hashOrder(
            address(0), // to address(0)
            rewardAmount, // amount 1 ether (reward amount)
            "", // no data
            address(0), // no token
            0 // no token id
        );

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

        (
            uint256 _id,
            address _receiver,
            address _cosigner,
            uint256 _seed,
            uint256 _counter,
            bytes32 _orderHash,
            uint256 _amount,
            uint256 _reward
        ) = luckyBuy.luckyBuys(commitId);

        // Get the counter for this commit
        uint256 counter = 0;

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

        assertEq(openEditionToken.balanceOf(address(user), 1), 1);
    }
    function testOpenEditionTransferFail() public {
        // out of base points

        vm.prank(admin);
        luckyBuy.setOpenEditionToken(address(1), 1, 1);

        uint256 commitAmount = 0.001 ether;
        uint256 rewardAmount = 1 ether;
        // Create order hash for a simple ETH transfer - this stays the same for all plays
        bytes32 orderHash = luckyBuy.hashOrder(
            address(0), // to address(0)
            rewardAmount, // amount 1 ether (reward amount)
            "", // no data
            address(0), // no token
            0 // no token id
        );

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

        (
            uint256 _id,
            address _receiver,
            address _cosigner,
            uint256 _seed,
            uint256 _counter,
            bytes32 _orderHash,
            uint256 _amount,
            uint256 _reward
        ) = luckyBuy.luckyBuys(commitId);

        // Get the counter for this commit
        uint256 counter = 0;

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

        // Fulfill the commit
        vm.startPrank(user);
        // This revert happens because there is no code at the address. The error will be different in different cases. E.g. bad address vs no balance
        vm.expectRevert();
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

        assertEq(openEditionToken.balanceOf(address(user), 1), 0);
    }
}
