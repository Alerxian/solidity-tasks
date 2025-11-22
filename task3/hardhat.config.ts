import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;
