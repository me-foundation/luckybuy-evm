// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "./common/SignatureVerifier.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./common/MEAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./SignaturePRNG.sol";
contract LuckyBuy is
    MEAccessControl,
    Pausable,
    SignatureVerifier,
    SignaturePRNG
{
    CommitData[] public luckyBuys;

    uint256 public balance;
    uint256 public maxReward = 30 ether;

    mapping(address cosigner => bool active) public isCosigner;
    mapping(address receiver => uint256 counter) public luckyBuyCount;
    mapping(uint256 commitId => bool fulfilled) public isFulfilled;

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

    event CoSignerAdded(address indexed cosigner);
    event CoSignerRemoved(address indexed cosigner);
    event Fulfillment(
        address indexed sender,
        uint256 indexed commitId,
        uint256 rng,
        uint256 odds,
        bool win,
        address token,
        uint256 tokenId,
        uint256 amount,
        address receiver
    );

    error AlreadyFulfilled();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidCoSigner();
    error InvalidOrderHash();
    error InvalidReceiver();
    error InvalidReward();
    error FulfillmentFailed();
    error InvalidCommitId();

    constructor() MEAccessControl() SignatureVerifier("LuckyBuy", "1") {
        uint256 existingBalance = address(this).balance;
        if (existingBalance > 0) {
            _depositTreasury(existingBalance);
        }
    }

    function commit(
        address receiver_,
        address cosigner_,
        uint256 seed_,
        bytes32 orderHash_,
        uint256 reward_
    ) external payable {
        if (msg.value == 0) revert InvalidAmount();
        if (!isCosigner[cosigner_]) revert InvalidCoSigner();
        if (cosigner_ == address(0)) revert InvalidCoSigner();
        if (receiver_ == address(0)) revert InvalidReceiver();
        if (reward_ > maxReward) revert InvalidReward();
        if (msg.value > reward_) revert InvalidReward();
        if (reward_ == 0) revert InvalidReward();

        if ((msg.value * BASE_POINTS) / reward_ > BASE_POINTS)
            revert InvalidAmount();

        uint256 commitId = luckyBuys.length;
        uint256 userCounter = luckyBuyCount[receiver_]++;

        CommitData memory commitData = CommitData({
            id: commitId,
            receiver: receiver_,
            cosigner: cosigner_,
            seed: seed_,
            counter: userCounter,
            orderHash: orderHash_,
            amount: msg.value,
            reward: reward_
        });

        luckyBuys.push(commitData);

        emit Commit(
            msg.sender,
            commitId,
            receiver_,
            cosigner_,
            seed_,
            userCounter,
            orderHash_, // Relay tx properties: to, data, value
            msg.value,
            reward_
        );
    }

    function fulfill(
        uint256 commitId_,
        address orderTo_,
        bytes calldata orderData_,
        uint256 orderAmount_,
        address token_,
        uint256 tokenId_,
        bytes calldata signature_
    ) external payable {
        // validate tx
        if (msg.value > 0) _depositTreasury(msg.value);
        if (orderAmount_ > balance) revert InsufficientBalance();
        if (isFulfilled[commitId_]) revert AlreadyFulfilled();
        if (commitId_ >= luckyBuys.length) revert InvalidCommitId();

        // mark the commit as fulfilled
        isFulfilled[commitId_] = true;

        // validate commit data matches tx data
        CommitData memory commitData = luckyBuys[commitId_];

        // validate the order hash
        if (
            commitData.orderHash !=
            hashOrder(orderTo_, orderAmount_, orderData_, token_, tokenId_)
        ) revert InvalidOrderHash();

        // validate the reward amount
        if (orderAmount_ != commitData.reward) revert InvalidAmount();

        // hash commit, check signature
        address cosigner = verify(commitData, signature_);
        if (cosigner != commitData.cosigner) revert InvalidCoSigner();
        if (!isCosigner[cosigner]) revert InvalidCoSigner();

        // TODO: check win conditions
        // calculate the odds in base points
        uint256 odds = _calculateOdds(commitData.amount, commitData.reward);
        uint256 rng = _rng(signature_);
        bool win = rng < odds;

        if (win) {
            // If the user wins, we need to transfer the NFT to the receiver
            balance -= orderAmount_;

            bool success = _fulfillOrder(orderTo_, orderData_, orderAmount_);
            if (success) {
                // emit a success transfer for the nft
                emit Fulfillment(
                    msg.sender,
                    commitId_,
                    rng,
                    odds,
                    win,
                    token_,
                    tokenId_,
                    orderAmount_,
                    commitData.receiver
                );
            } else {
                // emit a success transfer for eth
                payable(commitData.receiver).transfer(commitData.amount);
                emit Fulfillment(
                    msg.sender,
                    commitId_,
                    rng,
                    odds,
                    win,
                    address(0),
                    0,
                    commitData.amount,
                    commitData.receiver
                );
            }
        } else {
            // emit the failure
            emit Fulfillment(
                msg.sender,
                commitId_,
                rng,
                odds,
                win,
                address(0),
                0,
                0,
                commitData.receiver
            );
        }
    }

    function _calculateOdds(
        uint256 amount,
        uint256 reward
    ) internal returns (uint256) {
        return (amount * 10000) / reward;
    }

    function _fulfillOrder(
        address txTo_,
        bytes calldata data_,
        uint256 amount_
    ) internal returns (bool success) {
        (success, ) = txTo_.call{value: amount_}(data_);
    }

    function addCosigner(
        address cosigner_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isCosigner[cosigner_] = true;
        emit CoSignerAdded(cosigner_);
    }

    function removeCosigner(
        address cosigner_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isCosigner[cosigner_] = false;
        emit CoSignerRemoved(cosigner_);
    }

    function setMaxReward(
        uint256 maxReward_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxReward = maxReward_;
    }

    function _depositTreasury(uint256 amount) internal {
        balance += amount;
    }

    receive() external payable {
        _depositTreasury(msg.value);
    }
}
