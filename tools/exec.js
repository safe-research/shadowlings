import { program } from "commander";
import { ethers } from "ethers";

const options = program
  .name("shadowlings-exec")
  .requiredOption("--to <to>", "The contract to call")
  .requiredOption("--data <data>", "The data to send")
  .parse()
  .opts();

async function main() {
  const provider = new ethers.JsonRpcProvider("http://localhost:8545");
  const signer = await provider.getSigner();

  const to = ethers.getAddress(options.to);
  const data = options.data;

  const transaction = await signer.sendTransaction({
    from: await signer.getAddress(),
    to,
    data,
  });
  const receipt = await transaction.wait();

  console.log(receipt);
}

main().catch((err) => console.error(err));
