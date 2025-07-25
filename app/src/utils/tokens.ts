import { ethers } from "ethers";
import { globalProvier } from "./web3";

import deployments from "../config/deployments.json";

export interface Token {
  address: string;
  decimals: number;
  name: string;
  symbol: string;
}

export const KNOWN_TOKEN: Token[] = [{
  address: deployments[1337].ShadowToken,
  decimals: 18,
  name: "Shadow Token",
  symbol: "SHD",
}];

const TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
];

const TOKEN = new ethers.Interface(TOKEN_ABI);

export const getToken = (address: string): ethers.Contract => {
  return new ethers.Contract(address, TOKEN, globalProvier());
};
