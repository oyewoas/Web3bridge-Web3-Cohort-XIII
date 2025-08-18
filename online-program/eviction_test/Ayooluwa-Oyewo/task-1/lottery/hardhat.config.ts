

import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatVerify from "@nomicfoundation/hardhat-verify";

import { configVariable } from "hardhat/config";

const ACCOUNTS = configVariable("PRIVATE_KEY")
  ? [configVariable("PRIVATE_KEY")]
  : [];
const ETHERSCAN_API_KEY = configVariable("ETHERSCAN_API_KEY")
  ? configVariable("ETHERSCAN_API_KEY")
  : "";
const SEPOLIA_RPC_URL = "https://sepolia.drpc.org";
const LISK_SEPOLIA_RPC_URL = "https://rpc.sepolia-api.lisk.com";

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxMochaEthersPlugin, hardhatVerify],
  paths: {
    tests: {
      solidity: "./solidity-tests",
    },
  },
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: false,
            runs: 200,
          },
          viaIR: true,
        },
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: SEPOLIA_RPC_URL,
      accounts: ACCOUNTS,
    },
    "lisk-sepolia": {
      type: "http",
      chainType: "l1",
      url: LISK_SEPOLIA_RPC_URL,
      accounts: ACCOUNTS,
    },
  },
  verify: {
    blockscout: {
      enabled: true,
    },
    etherscan: {
      apiKey: ETHERSCAN_API_KEY,
    },
    
  },
  chainDescriptors: {
    4202: {
      name: "Lisk Sepolia",
      blockExplorers: {
        blockscout: {
          name: "Lisk Sepolia Explorer",
          url: "https://sepolia-blockscout.lisk.com",
          apiUrl: "https://sepolia-blockscout.lisk.com/api"
        }
      }
    },
    44787: {
      name: "Alfajores",
      blockExplorers: {
        etherscan: {
          name: "Alfajores Explorer",
          url: "https://alfajores.celoscan.io",
          apiUrl: "https://api-alfajores.celoscan.io/api"
        }
      }
    }
  }
};

export default config;
