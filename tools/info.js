import { program } from "commander";
import { ethers } from "ethers";
import { promises as fs } from "fs";
import { initialize } from "zokrates-js";

import { buildMimcHasher, fromHex, toFieldElement } from "../circuits/util.js";
import deployments from "../contracts/deployments.json" with { type: "json" };

const options = program
  .name("shadowlings-shadowling")
  .option("--shadowlings <address>", "The Shadowlings contract address")
  .requiredOption("--owner <address>", "The owner of the shadowling")
  .option(
    "--entropy <value>",
    "Additional entropy for preserving privacy with recovery",
  )
  .requiredOption("--salt <value>", "The shadowling specific salt")
  .option("--rpc-url <url>", "The RPC URL, defaulting to public Otim instance")
  .parse()
  .opts();

async function main() {
  const owner = ethers.getAddress(options.owner);
  const entropy = options.entropy
    ? BigInt(ethers.hexlify(ethers.toUtf8Bytes(options.entropy)))
    : 0n;
  const salt = BigInt(options.salt);
  const pepper = 42;

  const provider = new ethers.JsonRpcProvider(
    options.rpcUrl ?? "http://localhost:8545",
  );

  const { chainId } = await provider.getNetwork();
  const shadowlings = new ethers.Contract(
    options.shadowlings ?? deployments[chainId].Shadowlings,
    [
      `function getShadowling(uint256 commit) view returns (address)`,
    ],
    provider,
  );

  const mimc = await buildMimcHasher();

  const ownerHash = mimc(owner, entropy);
  const saltHash = mimc(salt, pepper);
  const commit = mimc(ownerHash, saltHash);
  console.log({ entropy, commit });

  const shadowling = await shadowlings.getShadowling(commit);
  console.log({ shadowling });
}

main().catch((err) => console.error(err));
