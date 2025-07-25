import { ethers } from "ethers";
import { SHADOWLING_ADDRESS } from "./invoker";

const RPC_URL = "http://localhost:8545";
const CORS_URL = "https://corsproxy.io/?" + encodeURIComponent(RPC_URL);

var provider: ethers.Provider | undefined;

export const globalProvier = (): ethers.Provider => {
  if (!provider) {
    provider = new ethers.JsonRpcProvider(RPC_URL);
  }
  return provider;
};

const REGISTER_TOPIC =
  "0x6e2bac2cdd35232209f74220974a1637ad0407deaf178151454372ab3e8cfa3b";

export const queryRecoveryRegistrations = async (
  shadow: string,
): Promise<string | undefined> => {
  const p = globalProvier();
  const logs = await p.getLogs({
    address: ethers.getAddress(shadow),
    topics: [
      REGISTER_TOPIC,
    ],
    fromBlock: "earliest",
    toBlock: "latest",
  });
  if (logs.length == 0) return undefined;
  return logs[0].data;
};
