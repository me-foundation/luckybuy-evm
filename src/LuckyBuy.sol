// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "./common/SignatureVerifier.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./common/MEAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./PRNG.sol";

contract LuckyBuy is
    MEAccessControl,
    Pausable,
    SignatureVerifier,
    PRNG,
    ReentrancyGuard
{
    CommitData[] public luckyBuys;

    uint256 public balance;
    uint256 public maxReward = 30 ether;
    uint256 public constant minReward = BASE_POINTS;

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
    event CosignerAdded(address indexed cosigner);
    event CosignerRemoved(address indexed cosigner);
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
    event MaxRewardUpdated(uint256 oldMaxReward, uint256 newMaxReward);

    error AlreadyCosigner();
    error AlreadyFulfilled();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidCosigner();
    error InvalidOrderHash();
    error InvalidReceiver();
    error InvalidReward();
    error FulfillmentFailed();
    error InvalidCommitId();

    /// @notice Constructor initializes the contract and handles any pre-existing balance
    /// @dev Sets up EIP712 domain separator and deposits any ETH sent during deployment /// @notice Constructor initializes the contract and handles any pre-existing balance
    /// @dev Sets up EIP712 domain separator and deposits any ETH sent during deployment
    constructor() MEAccessControl() SignatureVerifier("LuckyBuy", "1") {
        uint256 existingBalance = address(this).balance;
        if (existingBalance > 0) {
            _depositTreasury(existingBalance);
        }
    }

    /// @notice Allows a user to commit funds for a chance to win
    /// @param receiver_ Address that will receive the NFT/ETH if won
    /// @param cosigner_ Address of the authorized cosigner
    /// @param seed_ Random seed for the commit
    /// @param orderHash_ Hash of the order details
    /// @param reward_ Amount of reward if won
    /// @dev Emits a Commit event on success
    /// @return commitId The ID of the created commit
    function commit(
        address receiver_,
        address cosigner_,
        uint256 seed_,
        bytes32 orderHash_,
        uint256 reward_
    ) external payable whenNotPaused returns (uint256) {
        if (msg.value == 0) revert InvalidAmount();
        if (!isCosigner[cosigner_]) revert InvalidCosigner();
        if (cosigner_ == address(0)) revert InvalidCosigner();
        if (receiver_ == address(0)) revert InvalidReceiver();
        if (reward_ > maxReward) revert InvalidReward();
        if (reward_ < minReward) revert InvalidReward();
        if (msg.value > reward_) revert InvalidAmount();
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

        return commitId;
    }

    /// @notice Fulfills a commit with the result of the random number generation
    /// @param commitId_ ID of the commit to fulfill
    /// @param marketplace_ Address where the order should be executed
    /// @param orderData_ Calldata for the order execution
    /// @param orderAmount_ Amount of ETH to send with the order
    /// @param token_ Address of the token being transferred (zero address for ETH)
    /// @param tokenId_ ID of the token if it's an NFT
    /// @param signature_ Signature used for random number generation
    /// @dev Emits a Fulfillment event on success
    function fulfill(
        uint256 commitId_,
        address marketplace_,
        bytes calldata orderData_,
        uint256 orderAmount_,
        address token_,
        uint256 tokenId_,
        bytes calldata signature_
    ) external payable nonReentrant whenNotPaused {
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
            hashOrder(marketplace_, orderAmount_, orderData_, token_, tokenId_)
        ) revert InvalidOrderHash();

        // validate the reward amount
        if (orderAmount_ != commitData.reward) revert InvalidAmount();

        // hash commit, check signature
        address cosigner = verify(commitData, signature_);
        if (cosigner != commitData.cosigner) revert InvalidCosigner();
        if (!isCosigner[cosigner]) revert InvalidCosigner();

        // calculate the odds in base points
        uint256 odds = _calculateOdds(commitData.amount, commitData.reward);
        uint256 rng = _rng(signature_);
        bool win = rng < odds;

        if (win) {
            _handleWin(
                commitData,
                marketplace_,
                orderData_,
                orderAmount_,
                rng,
                odds,
                win,
                token_,
                tokenId_
            );
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

    function _handleWin(
        CommitData memory commitData,
        address marketplace_,
        bytes calldata orderData_,
        uint256 orderAmount_,
        uint256 rng_,
        uint256 odds_,
        bool win_,
        address token_,
        uint256 tokenId_
    ) internal {
        balance -= orderAmount_;

        // execute the market data to transfer the nft
        bool success = _fulfillOrder(marketplace_, orderData_, orderAmount_);
        if (success) {
            // emit a success transfer for the nft
            emit Fulfillment(
                msg.sender,
                commitData.id,
                rng_,
                odds_,
                win_,
                token_,
                tokenId_,
                orderAmount_,
                commitData.receiver
            );
        } else {
            // Order failed, transfer the eth back to the receiver
            payable(commitData.receiver).transfer(commitData.amount);
            emit Fulfillment(
                msg.sender,
                commitData.id,
                rng_,
                odds_,
                win_,
                address(0),
                0,
                commitData.amount,
                commitData.receiver
            );
        }
    }

    /// @notice Adds a new authorized cosigner
    /// @param cosigner_ Address to add as cosigner
    /// @dev Only callable by admin role
    /// @dev Emits a CoSignerAdded event
    function addCosigner(
        address cosigner_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (cosigner_ == address(0)) revert InvalidCosigner();
        if (isCosigner[cosigner_]) revert AlreadyCosigner();
        isCosigner[cosigner_] = true;
        emit CosignerAdded(cosigner_);
    }

    /// @notice Removes an authorized cosigner
    /// @param cosigner_ Address to remove as cosigner
    /// @dev Only callable by admin role
    /// @dev Emits a CoSignerRemoved event
    function removeCosigner(
        address cosigner_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isCosigner[cosigner_] = false;
        emit CosignerRemoved(cosigner_);
    }

    /// @notice Sets the maximum allowed reward
    /// @param maxReward_ New maximum reward value
    /// @dev Only callable by admin role
    function setMaxReward(
        uint256 maxReward_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxReward = maxReward_;
        emit MaxRewardUpdated(maxReward, maxReward_);
    }

    /// @notice Deposits ETH into the treasury
    /// @dev Called internally when receiving ETH
    /// @param amount Amount of ETH to deposit
    function _depositTreasury(uint256 amount) internal {
        balance += amount;
    }

    /// @notice Pauses the contract
    /// @dev Only callable by admin role
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Handles receiving ETH
    /// @dev Required for contract to receive ETH
    receive() external payable {
        _depositTreasury(msg.value);
    }

    /// @notice Calculates the odds of winning based on amount and reward
    /// @dev Internal function used in fulfill()
    /// @param amount Amount committed
    /// @param reward Potential reward
    /// @return odds The calculated odds as a percentage (0-100)
    function _calculateOdds(
        uint256 amount,
        uint256 reward
    ) internal pure returns (uint256) {
        return (amount * 10000) / reward;
    }

    /// @notice Fulfills an order with the specified parameters
    /// @dev Internal function called by fulfill()
    /// @param to Address to send the transaction to
    /// @param data Calldata for the transaction
    /// @param amount Amount of ETH to send
    /// @return success Whether the transaction was successful
    function _fulfillOrder(
        address to,
        bytes calldata data,
        uint256 amount
    ) internal returns (bool success) {
        (success, ) = to.call{value: amount}(data);
    }
}
