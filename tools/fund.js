import { program } from "commander";
import { ethers } from "ethers";

import { buildMimcHasher } from "../circuits/util.js";
import deployments from "../contracts/deployments.json" with { type: "json" };

const options = program
  .name("shadowlings-fund")
  .requiredOption("--owner <address>", "The owner of the shadowling")
  .option(
    "--entropy <value>",
    "Additional entropy for preserving privacy with recovery",
  )
  .requiredOption("--salt <value>", "The shadowling specific salt")
  .requiredOption("--amount <value>", "The recipient of the transfer")
  .option("--token <address>", "The token to mint")
  .option("--demo", "Run in demo mode, funding with hardcoded contracts.")
  .option("--rpc-url <url>", "The node RPC to connect to")
  .parse()
  .opts();

async function main() {
  const provider = new ethers.JsonRpcProvider(
    options.rpcUrl ?? "http://localhost:8545",
  );
  const signer = await provider.getSigner();

  const { chainId } = await provider.getNetwork();
  const shadowlings = new ethers.Contract(
    options.shadowlings ?? deployments[chainId].Shadowlings,
    [
      `function ENTRY_POINT() view returns (address)`,
      `function getShadowling(uint256 commit) view returns (address)`,
    ],
    provider,
  );
  const entryPoint = new ethers.Contract(
    await shadowlings.ENTRY_POINT(),
    [
      `function balanceOf(address sender) view returns (uint256 amount)`,
      `function depositTo(address account) public payable`,
    ],
    signer,
  );

  const owner = ethers.getAddress(options.owner);
  const entropy = options.entropy
    ? BigInt(ethers.hexlify(ethers.toUtf8Bytes(options.entropy)))
    : 0n;
  const salt = BigInt(options.salt);
  const pepper = 42;

  const mimc = await buildMimcHasher();

  const ownerHash = mimc(owner, entropy);
  const saltHash = mimc(salt, pepper);
  const commit = mimc(ownerHash, saltHash);
  console.log({ entropy, commit });

  const shadowling = await shadowlings.getShadowling(commit);
  console.log({ shadowling });

  let tokens = [ethers.getAddress(options.token ?? ethers.ZeroAddress)];
  if (options.demo) {
    tokens = [
      ...new Set([
        ...tokens,
        ethers.ZeroAddress,
        deployments[chainId].ShadowToken,
      ]),
    ];
  }
  const value = ethers.parseEther(options.amount);

  for (const token of tokens) {
    let transactionData;
    if (token === ethers.ZeroAddress) {
      transactionData = { to: shadowling, value };
    } else {
      transactionData = {
        to: token,
        data: TOKEN.encodeFunctionData("mint", [shadowling, value]),
      };
    }

    const transaction = await signer.sendTransaction(transactionData);
    const receipt = await transaction.wait();

    console.log(receipt);
  }

  if (await entryPoint.balanceOf(shadowling) < ethers.parseEther("1.0")) {
    const transaction = await entryPoint.depositTo(shadowling, {
      value: ethers.parseEther("10.0"),
    });
    const receipt = await transaction.wait();
    console.log(receipt);
  }
}

const TOKEN = new ethers.Interface([
  `function mint(address to, uint256 amount)`,
]);

main().catch((err) => console.error(err));
