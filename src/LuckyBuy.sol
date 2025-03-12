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
    uint256 public balance;
    uint256 public maxReward = 30 ether;

    mapping(address cosigner => bool active) public isCosigner;

    CommitData[] public luckyBuys;
    mapping(address receiver => uint256 counter) public luckyBuyCount;

    event Commit(
        address indexed sender,
        uint256 indexed commitId,
        address indexed receiver,
        address cosigner,
        uint256 seed,
        uint256 counter,
        string orderHash,
        uint256 amount,
        uint256 reward,
        bytes32 hash
    );
    event CoSignerAdded(address indexed cosigner);
    event CoSignerRemoved(address indexed cosigner);

    error InvalidAmount();
    error InvalidCoSigner();
    error InvalidReceiver();
    error InvalidReward();

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
        string calldata orderHash_,
        uint256 reward_
    ) external payable {
        if (msg.value == 0) revert InvalidAmount();
        if (!isCosigner[cosigner_]) revert InvalidCoSigner();
        if (receiver_ == address(0)) revert InvalidReceiver();
        if (reward_ > maxReward) revert InvalidReward();
        if (msg.value > reward_) revert InvalidReward();

        // Calc odds, check if odds in range
        // Check if reward is below max bet

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
            reward_,
            hash(commitData) // verify above values offchain with this hash
        );
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
