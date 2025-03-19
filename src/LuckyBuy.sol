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

    uint256 public treasuryBalance; // The contract balance
    uint256 public commitBalance; // The open commit balances
    uint256 public protocolBalance; // The protocol fees for the open commits
    uint256 public maxReward = 30 ether;
    uint256 public protocolFee = 0;

    uint256 public constant minReward = BASE_POINTS;

    mapping(address cosigner => bool active) public isCosigner;
    mapping(address receiver => uint256 counter) public luckyBuyCount;
    mapping(uint256 commitId => bool fulfilled) public isFulfilled;
    // We track this because we can change the fees at any time. This allows open commits to be fulfilled/returned with the fees at the time of commit
    mapping(uint256 commitId => uint256 fee) public feesPaid;

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
        uint256 fee
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
        address receiver,
        uint256 fee
    );
    event MaxRewardUpdated(uint256 oldMaxReward, uint256 newMaxReward);
    event ProtocolFeeUpdated(uint256 oldProtocolFee, uint256 newProtocolFee);
    event Withdrawal(address indexed sender, uint256 amount);
    event Deposit(address indexed sender, uint256 amount);
    error AlreadyCosigner();
    error AlreadyFulfilled();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidCosigner();
    error InvalidOrderHash();
    error InvalidProtocolFee();
    error InvalidReceiver();
    error InvalidReward();
    error FulfillmentFailed();
    error InvalidCommitId();
    error WithdrawalFailed();

    /// @notice Constructor initializes the contract and handles any pre-existing balance
    /// @dev Sets up EIP712 domain separator and deposits any ETH sent during deployment
    constructor(
        uint256 protocolFee_
    ) MEAccessControl() SignatureVerifier("LuckyBuy", "1") {
        uint256 existingBalance = address(this).balance;
        if (existingBalance > 0) {
            _depositTreasury(existingBalance);
        }

        _setProtocolFee(protocolFee_);
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

        uint256 amountWithoutFee = calculateContributionWithoutFee(msg.value);

        if (amountWithoutFee > reward_) revert InvalidAmount();
        if (reward_ == 0) revert InvalidReward();

        if ((amountWithoutFee * BASE_POINTS) / reward_ > BASE_POINTS)
            revert InvalidAmount();

        uint256 commitId = luckyBuys.length;
        uint256 userCounter = luckyBuyCount[receiver_]++;

        uint256 fee = msg.value - amountWithoutFee;

        feesPaid[commitId] = fee;
        protocolBalance += fee;
        commitBalance += amountWithoutFee;

        CommitData memory commitData = CommitData({
            id: commitId,
            receiver: receiver_,
            cosigner: cosigner_,
            seed: seed_,
            counter: userCounter,
            orderHash: orderHash_,
            amount: amountWithoutFee,
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
            amountWithoutFee,
            reward_,
            fee
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
        if (orderAmount_ > treasuryBalance) revert InsufficientBalance();
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

        // Collect the commit balance and protocol fees
        // transfer the commit balance to the contract
        treasuryBalance += commitData.amount;
        commitBalance -= commitData.amount;

        // transfer the protocol fees to the contract
        uint256 protocolFeesPaid = feesPaid[commitData.id];
        treasuryBalance += protocolFeesPaid;
        protocolBalance -= protocolFeesPaid;

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
                tokenId_,
                protocolFeesPaid
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
                commitData.receiver,
                protocolFeesPaid
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
        uint256 tokenId_,
        uint256 protocolFeesPaid
    ) internal {
        // execute the market data to transfer the nft
        bool success = _fulfillOrder(marketplace_, orderData_, orderAmount_);
        if (success) {
            // subtract the order amount from the contract balance
            treasuryBalance -= orderAmount_;
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
                commitData.receiver,
                protocolFeesPaid
            );
        } else {
            // Order failed, transfer the eth commit + fees back to the receiver
            uint256 protocolFeesPaid = feesPaid[commitData.id];
            // Headcheck: Because fees are tracked separately, this should never happen
            // if (protocolFeesPaid > treasuryBalance) revert InsufficientBalance();

            uint256 transferAmount = commitData.amount + protocolFeesPaid;

            treasuryBalance -= transferAmount;

            // This can also revert if the receiver is a contract that doesn't accept ETH
            payable(commitData.receiver).transfer(transferAmount);
            emit Fulfillment(
                msg.sender,
                commitData.id,
                rng_,
                odds_,
                win_,
                address(0),
                0,
                transferAmount,
                commitData.receiver,
                protocolFeesPaid
            );
        }
    }

    /// @notice Allows the admin to withdraw ETH from the contract balance
    /// @param amount The amount of ETH to withdraw
    /// @dev Only callable by admin role
    /// @dev Emits a Withdrawal event
    function withdraw(
        uint256 amount
    ) external nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount > treasuryBalance) revert InsufficientBalance();
        treasuryBalance -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, amount);
    }

    /// @notice Allows the admin to withdraw all ETH from the contract
    /// @dev Only callable by admin role
    /// @dev Emits a Withdrawal event
    function emergencyWithdraw()
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        treasuryBalance = 0;
        commitBalance = 0;
        protocolBalance = 0;

        uint256 currentBalance = address(this).balance;
        (bool success, ) = payable(msg.sender).call{value: currentBalance}("");
        if (!success) revert WithdrawalFailed();

        _pause();
        emit Withdrawal(msg.sender, currentBalance);
    }

    /// @notice Calculates contribution amount after removing fee
    /// @param amount The original amount including fee
    /// @return The contribution amount without the fee
    /// @dev Uses formula: contribution = (amount * FEE_DENOMINATOR) / (FEE_DENOMINATOR + feePercent)
    /// @dev This ensures fee isn't charged on the fee portion itself
    function calculateContributionWithoutFee(
        uint256 amount
    ) public view returns (uint256) {
        return (amount * BASE_POINTS) / (BASE_POINTS + protocolFee);
    }

    /// @notice Calculates fee amount based on input amount and fee percentage
    /// @param _amount The amount to calculate fee on
    /// @return The calculated fee amount
    /// @dev Uses fee denominator of 10000 (100% = 10000)
    function calculateFee(uint256 _amount) external view returns (uint256) {
        return _calculateFee(_amount);
    }

    function _calculateFee(uint256 _amount) internal view returns (uint256) {
        return (_amount * protocolFee) / BASE_POINTS;
    }

    // ############################################################
    // ############ GETTERS & SETTERS ############
    // ############################################################

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
        treasuryBalance += amount;
        emit Deposit(msg.sender, amount);
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

    function setProtocolFee(
        uint256 protocolFee_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (protocolFee_ > BASE_POINTS) revert InvalidProtocolFee();
        _setProtocolFee(protocolFee_);
    }

    function _setProtocolFee(uint256 protocolFee_) internal {
        uint256 oldProtocolFee = protocolFee;
        protocolFee = protocolFee_;
        emit ProtocolFeeUpdated(oldProtocolFee, protocolFee_);
    }
}
