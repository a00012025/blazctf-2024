import {
  createWalletClient,
  http,
  parseGwei,
  stringToHex,
  toBlobs,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { hardhat } from "viem/chains";
import { kzg } from "./kzg";

export const account = privateKeyToAccount(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
);

export const client = createWalletClient({
  account,
  chain: hardhat,
  transport: http(),
});

console.log("Hi");

async function main() {
  const chainId = await client.getChainId();
  console.log("chainId", chainId);

  const blobs = toBlobs({ data: stringToHex("hello world") });
  // console.log("blobs", blobs);

  const hash = await client.sendTransaction({
    blobs,
    kzg,
    maxPriorityFeePerGas: 10000n,
    // maxFeePerGas: 3425394258324883561976808248654023868257665024n,
    maxFeePerGas: 340282366920938463463374607431768211455n,
    maxFeePerBlobGas: 10000n,
    gas: 50000n,
    to: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  });
  console.log("hash", hash);
}

main().catch(console.error);
