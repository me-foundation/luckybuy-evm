// test.ts or test.js
import { ethers } from "ethers";
import { MagicSigner } from "../cosigner-lib";
import dotenv from "dotenv";

dotenv.config();

async function testMagicSigner() {
  try {
    // Get private keys from env
    const cosigner1Key = process.env.PRIVATE_KEY;

    if (!cosigner1Key) {
      throw new Error("Missing private keys in environment variable");
    }

    const contract = "0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f"; // match solidity tests

    const id = BigInt(1);
    const from = "0x0000000000000000000000000000000000005678";
    const cosigner = "0xCf03Dd0a894Ef79CB5b601A43C4b25E3Ae4c67eD"; // from MESignatureVerifier.sol
    const seed = BigInt(1);
    const counter = BigInt(1);
    const orderHash = "0x0000000000000000000000000000000000005678";

    const chainId = 31337;

    // Create instances for both cosigners
    const signer = new MagicSigner({
      contract,
      privateKey: cosigner1Key,
      chainId, // forge testnet, change as needed
    });

    // Create vouchers with both signatures
    const result1 = await signer.signCommit(
      id,
      from,
      cosigner,
      seed,
      counter,
      orderHash
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

// Create .env file with these variables
// .env
/*
COSIGNER1_PRIVATE_KEY=your_private_key_1_here
COSIGNER2_PRIVATE_KEY=your_private_key_2_here
*/

testMagicSigner();
