import { ethers } from "ethers";

const SIGNING_DOMAIN_NAME = "LuckyBuy";
const SIGNING_DOMAIN_VERSION = "1";

interface CommitParams {
  contract: string;
  privateKey: string;
  chainId: number;
}

interface CommitData {
  id: bigint;
  receiver: string;
  cosigner: string;
  seed: bigint;
  counter: bigint;
  orderHash: string;
  amount: bigint;
  reward: bigint;
}

export class MagicSigner {
  public contract: string;
  public signer: ethers.Wallet;
  public chainId: number;
  private _domain: any;

  constructor({ contract, privateKey, chainId }: CommitParams) {
    this.contract = contract;
    this.chainId = chainId;
    this.signer = new ethers.Wallet(privateKey);
  }

  public get address() {
    return this.signer.address;
  }

  private _signingDomain() {
    if (this._domain != null) {
      return this._domain;
    }

    this._domain = {
      name: SIGNING_DOMAIN_NAME,
      version: SIGNING_DOMAIN_VERSION,
      verifyingContract: this.contract,
      chainId: this.chainId,
    };

    return this._domain;
  }

  async signCommit(
    id: bigint,
    receiver: string,
    cosigner: string,
    seed: bigint,
    counter: bigint,
    orderHash: string,
    amount: bigint,
    reward: bigint
  ): Promise<{
    commit: CommitData;
    callData: string;
    signature: string;
    digest: string;
  }> {
    if (!ethers.isAddress(receiver) || !ethers.isAddress(cosigner)) {
      throw new Error("Invalid address");
    }

    const domain = this._signingDomain();

    const types = {
      CommitData: [
        { name: "id", type: "uint256" },
        { name: "receiver", type: "address" },
        { name: "cosigner", type: "address" },
        { name: "seed", type: "uint256" },
        { name: "counter", type: "uint256" },
        { name: "orderHash", type: "bytes32" },
        { name: "amount", type: "uint256" },
        { name: "reward", type: "uint256" },
      ],
    };

    const commit: CommitData = {
      id,
      receiver,
      cosigner,
      seed,
      counter,
      orderHash,
      amount,
      reward,
    };

    const signature = await this.signer.signTypedData(domain, types, commit);
    const digest = ethers.TypedDataEncoder.hash(domain, types, commit);

    const callData = this._signCommitCallData(
      id,
      receiver,
      cosigner,
      seed,
      counter,
      orderHash,
      amount,
      reward
    );

    return {
      commit,
      callData,
      signature,
      digest,
    };
  }

  _signCommitCallData(
    id: bigint,
    receiver: string,
    cosigner: string,
    seed: bigint,
    counter: bigint,
    orderHash: string,
    amount: bigint,
    reward: bigint
  ) {
    const structData = {
      id,
      receiver,
      cosigner,
      seed,
      counter,
      orderHash,
      amount,
      reward,
    };

    // Define the types for encoding
    const types = [
      "uint256", // id
      "address", // receiver
      "address", // cosigner
      "uint256", // seed
      "uint256", // counter
      "bytes32", // orderHash
      "uint256", // amount
      "uint256", // reward
    ];

    // Encode the parameters
    const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(types, [
      structData.id,
      structData.receiver,
      structData.cosigner,
      structData.seed,
      structData.counter,
      structData.orderHash,
      structData.amount,
      structData.reward,
    ]);

    return encodedData;
  }

  async hashOrder(
    to: string,
    value: bigint | number,
    data: string | Uint8Array,
    tokenAddress: string,
    tokenId: bigint | number
  ): Promise<string> {
    // Convert all parameters to their appropriate types for encoding
    const addressTo = ethers.getAddress(to); // Normalize address format
    const bigValue = BigInt(value); // Ensure it's a BigInt for encoding

    // Handle data based on type
    let bytesData: Uint8Array;
    if (typeof data === "string") {
      // If it's a hex string
      if (data.startsWith("0x")) {
        bytesData = ethers.getBytes(data);
      } else {
        // If it's a normal string, convert to UTF-8 bytes
        bytesData = ethers.toUtf8Bytes(data);
      }
    } else {
      // It's already a Uint8Array
      bytesData = data;
    }

    const tokenAddr = ethers.getAddress(tokenAddress); // Normalize address
    const bigTokenId = BigInt(tokenId); // Ensure it's a BigInt

    // Use ABI encoding to match Solidity's abi.encode exactly
    const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256", "bytes", "address", "uint256"],
      [addressTo, bigValue, bytesData, tokenAddr, bigTokenId]
    );

    // Hash the encoded data
    const hash = ethers.keccak256(encodedData);

    return hash;
  }
}

export default MagicSigner;
