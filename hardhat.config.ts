import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

dotenv.config();

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
    }
  }
};

export default config;
