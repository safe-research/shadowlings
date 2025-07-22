import { program } from "commander";
import { ethers } from "ethers";

import deployments from "../contracts/deployments.json" with { type: "json" };

const options = program
  .name("shadowlings-fund")
  .option("--token <address>", "The token to mint")
  .requiredOption("--to <address>", "The amount to transfer")
  .requiredOption("--amount <value>", "The recipient of the transfer")
  .option("--demo", "Run in demo mode, funding with hardcoded contracts.")
  .option("--rpc-url <url>", "The node RPC to connect to")
  .parse()
  .opts();

async function main() {
  const provider = new ethers.JsonRpcProvider(options.rpcUrl ?? "http://localhost:8545");
  const signer = await provider.getSigner();

  const to = ethers.getAddress(options.to);
  const value = ethers.parseEther(options.amount);

  const { chainId } = await provider.getNetwork();
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

  for (const token of tokens) {
    let transactionData;
    if (token === ethers.ZeroAddress) {
      transactionData = { to, value };
    } else {
      transactionData = {
        to: token,
        data: TOKEN.encodeFunctionData("mint", [to, value]),
      };
    }

    const transaction = await signer.sendTransaction(transactionData);
    const receipt = await transaction.wait();

    console.log(receipt);
  }

  const shadowlings = new ethers.Contract(
    options.shadowlings ?? deployments[chainId].Shadowlings,
    [
      `function ENTRY_POINT() view returns (address)`,
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

  if (await entryPoint.balanceOf(to) < ethers.parseEther("1.0")) {
    const transaction = await entryPoint.depositTo(to, {
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
