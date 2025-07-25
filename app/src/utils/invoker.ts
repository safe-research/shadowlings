import { BigNumberish, ethers } from "ethers";
import { Proof } from "zokrates-js";

import deployments from "../config/deployments.json";
import { globalProvier } from "./web3";

export const SHADOWLING_ADDRESS = deployments[1337].Shadowlings;
const SHADOWLING_ABI = [
  `function ENTRY_POINT() view returns (address)`,
  `function getShadowling(uint256 commit) view returns (address)`,
  `function getShadowlingDelegationSignature(uint256 commit) pure returns (uint8, bytes32, bytes32)`,
  `function execute(address token, address to, uint256 amount)`,
  `function register(uint256 saltHash)`,
  `function executeWithRecovery(uint256 commit, uint256 saltHash, address token, address to, uint256 amount, ((uint256, uint256), (uint256[2], uint256[2]), (uint256, uint256)) proof) external returns (bool success)`,
];
const SHADOWLING = new ethers.Interface(SHADOWLING_ABI);

export const shadowling = (
  provider: ethers.Provider = globalProvier(),
): ethers.Contract =>
  new ethers.Contract(
    SHADOWLING_ADDRESS,
    SHADOWLING,
    provider,
  );

export const encodeExecute = (
  token: string,
  to: string,
  amount: BigNumberish,
): string => {
  return SHADOWLING.encodeFunctionData("execute", [
    token,
    to,
    amount,
  ]);
};

export const encodeRegister = (
  saltHash: string,
): string => {
  return SHADOWLING.encodeFunctionData("register", [
    saltHash,
  ]);
};

export const encodeRecovery = (
  commit: string,
  saltHash: string,
  token: string,
  to: string,
  amount: BigNumberish,
  proof: Proof,
): string => {
  const p: any = proof.proof;
  return SHADOWLING.encodeFunctionData("executeWithRecovery", [
    commit,
    saltHash,
    token,
    to,
    amount,
    [p.a, p.b, p.c],
  ]);
};
