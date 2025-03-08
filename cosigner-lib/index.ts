import { ethers } from "ethers";

const SIGNING_DOMAIN_NAME = "MagicSigner";
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
    amount: bigint
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
        { name: "orderHash", type: "string" },
        { name: "amount", type: "uint256" },
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
      amount
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
    amount: bigint
  ) {
    const structData = {
      id,
      receiver,
      cosigner,
      seed,
      counter,
      orderHash,
      amount,
    };

    // Define the types for encoding
    const types = [
      "uint256", // id
      "address", // receiver
      "address", // cosigner
      "uint256", // seed
      "uint256", // counter
      "string", // orderHash
      "uint256", // amount
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
    ]);

    return encodedData;
  }
}

export default MagicSigner;
