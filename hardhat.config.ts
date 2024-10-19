import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import { HttpNetworkAccountsUserConfig } from "hardhat/types";
import "@nomicfoundation/hardhat-toolbox";

dotenv.config();

const MNEMONIC = process.env.MNEMONIC

const PRIVATE_KEY = process.env.PRIVATE_KEY

const accounts: HttpNetworkAccountsUserConfig | undefined = MNEMONIC
    ? { mnemonic: MNEMONIC }
    : PRIVATE_KEY
      ? [PRIVATE_KEY]
      : undefined

if (accounts == null) {
    console.warn(
        'Could not find MNEMONIC or PRIVATE_KEY environment variables. It will not be possible to execute transactions in your example.'
    )
}

const alchemyApiKey: string | undefined = process.env.ALCHEMY_API;
if (!alchemyApiKey) {
  throw new Error("Please set your ALCHEMY_API in a .env file");
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
  },
  networks:{
    hardhat:{
      forking:{
        url: alchemyApiKey,
        blockNumber: 14638929
      }
    },
    'sepolia': {
      url: process.env.RPC_URL_SEPOLIA || 'https://rpc.sepolia.org/',
      accounts,
    },
  }
};

export default config;
