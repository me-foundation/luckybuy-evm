// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "./common/SignatureVerifier.sol";
import "./common/CRC32.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./common/MEAccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
contract LuckyBuy is MEAccessControl, Pausable, SignatureVerifier, CRC32 {
    uint256 public balance;
    uint256 public commitedBalance;

    mapping(address cosigner => bool isActive) public cosigners;

    CommitData[] public luckyBuys;
    mapping(uint256 luckyBuyId => bool isFulfilled) public luckyBuyIsFulfilled;
    mapping(address user => uint256 count) public luckyBuyCount;

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Commit(
        address sender,
        uint256 id,
        address receiver,
        address cosigner,
        uint256 seed,
        uint256 counter,
        string orderHash,
        uint256 amount
    );
    event CosignerAdded(address indexed cosigner);
    event CosignerRemoved(address indexed cosigner);

    error InvalidAmount();
    error InvalidCoSigner();
    error InvalidReceiver();

    constructor() MEAccessControl() SignatureVerifier("LuckyBuy", "1") {
        uint256 existingBalance = address(this).balance;
        if (existingBalance > 0) {
            _depositTreasury(existingBalance);
        }
    }

    // WIP more to follow, just getting the rng working for now
    function commit(
        address receiver_,
        address cosigner_,
        uint256 seed_,
        string calldata orderHash_
    ) external payable {
        if (msg.value == 0) revert InvalidAmount();
        if (!cosigners[cosigner_]) revert InvalidCoSigner();
        if (receiver_ == address(0)) revert InvalidReceiver();

        uint256 commitId = luckyBuys.length;
        uint256 userCounter = luckyBuyCount[receiver_]++;

        luckyBuys.push(
            CommitData({
                id: commitId,
                receiver: receiver_,
                cosigner: cosigner_,
                seed: seed_,
                counter: userCounter,
                orderHash: orderHash_,
                amount: msg.value
            })
        );

        emit Commit(
            msg.sender,
            commitId,
            receiver_,
            cosigner_,
            seed_,
            userCounter,
            orderHash_,
            msg.value
        );
    }

    function addCosigner(
        address cosigner_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cosigners[cosigner_] = true;
        emit CosignerAdded(cosigner_);
    }

    function removeCosigner(
        address cosigner_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        cosigners[cosigner_] = false;
        emit CosignerRemoved(cosigner_);
    }

    function _depositTreasury(uint256 amount) internal {
        if (amount == 0) revert InvalidAmount();
        balance += amount;
        emit Deposit(msg.sender, amount);
    }

    receive() external payable {
        _depositTreasury(msg.value);
    }
}
