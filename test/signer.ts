// test.ts or test.js
import { ethers } from "ethers";
import { MagicSigner } from "../cosigner-lib";
import dotenv from "dotenv";

dotenv.config();

async function testMagicSigner() {
  try {
    if (!process.env.PRIVATE_KEY) {
      throw new Error("Missing private keys in environment variable");
    }

    const contract = "0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f"; // match solidity tests
    const chainId = 31337; // Anvil

    const signer = new MagicSigner({
      contract,
      privateKey: process.env.PRIVATE_KEY,
      chainId,
    });

    console.log("Signer address:", signer.address);

    const id = BigInt(1);

    const from = "0xE052c9CFe22B5974DC821cBa907F1DAaC7979c94";
    const cosigner = signer.address;
    const seed = BigInt(1);
    const counter = BigInt(1);

    const orderHash = "0x0";
    const amount = BigInt(1);
    const reward = BigInt(100);

    const result1 = await signer.signCommit(
      id,
      from,
      cosigner,
      seed,
      counter,
      orderHash,
      amount,
      reward
    );

    console.log("Commit:", result1.commit);
    console.log("\nSignature:", result1.signature);
    console.log("\nCall Data:", result1.callData);
    console.log("Signer Address:", signer.address);
    console.log("Digest:", result1.digest);
  } catch (error) {
    console.error("Test failed:", error);
  }
}

testMagicSigner();
