# LuckyBuy EVM Contracts

LuckyBuy is a decentralized protocol that enables probabilistic NFT purchases. Users can commit a fraction of an NFT's price for a proportional chance to win the NFT. If they win, they receive the NFT at a discount. If they don't win, they keep their committed amount.

## Overview

The protocol works in three steps:

1. **Commit**: Users commit ETH with a proportional chance to win (e.g., commit 0.1 ETH on a 1 ETH NFT for a 10% chance to win)
2. **Verify**: Trusted cosigners verify and sign valid commits
3. **Fulfill**: The protocol attempts to purchase the NFT if the user wins, or returns the ETH if they lose

### Key Features

- Trustless probability calculation based on commit amount
- Secure random number generation using signature-based PRNG
- Support for any NFT marketplace that accepts Off Chain Orders
- Fallback ETH transfer if NFT purchase fails
- Multi-cosigner support for redundancy

## Architecture

The system consists of three main components:

- **LuckyBuy.sol**: Core contract handling commits, verification, and fulfillment
- **PRNG.sol**: Secure random number generation using CRC32 and signatures
- **SignatureVerifier.sol**: EIP-712 compliant signature verification

### Security Features

- EIP-712 structured data signing
- Unbiased random number generation
- Access control for admin functions
- Atomic execution of NFT purchases
- Protected against signature malleability

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm
- Ethereum RPC URL (for forked tests)

### Setup

1. Clone the repository:

```bash
git clone https://github.com/your-org/luckybuy-evm.git
cd luckybuy-evm
```

2. Install dependencies:

```bash
forge install
npm install
```

3. Set up environment:

```bash
cp .env.example .env
# Add your RPC URL to .env
```

### Testing

Run the test suite:

```bash
forge test
```

For detailed gas reports:

```bash
forge test --gas-report
```

For fork testing (requires RPC URL):

```bash
forge test --fork-url $MAINNET_RPC_URL
```

### Deployment

1. Set required environment variables:

```bash
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url
```

2. Deploy:

```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## Usage

### Making a Commit

1. Calculate the order hash for the NFT purchase:

```solidity
bytes32 orderHash = luckyBuy.hashOrder(
    target,
    reward,
    data,
    tokenAddress,
    tokenId
);
```

2. Submit a commit:

```solidity
luckyBuy.commit{value: amount}(
    receiver,
    cosigner,
    seed,
    orderHash,
    reward
);
```

### Fulfilling Orders

Cosigners monitor commit events and fulfill valid commits:

```solidity
luckyBuy.fulfill(
    commitId,
    orderTo,
    orderData,
    orderAmount,
    token,
    tokenId,
    signature
);
```

## Administration

### Managing Cosigners

Add a cosigner:

```solidity
luckyBuy.addCosigner(cosignerAddress);
```

Remove a cosigner:

```solidity
luckyBuy.removeCosigner(cosignerAddress);
```

### Treasury Management

Set maximum reward:

```solidity
luckyBuy.setMaxReward(newMaxReward);
```

## License

This project is licensed under the Unlicense - see the [LICENSE](LICENSE) file for details.

## Improvements

The fulfillment could whitelist the marketplace addresses that are allowed to be used. This would greatly reduce the risk of accidental misuse and restrict arbitrary contract calls.
