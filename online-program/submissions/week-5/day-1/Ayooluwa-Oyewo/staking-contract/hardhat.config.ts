import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import { vars } from "hardhat/config";

const ACCOUNTS = vars.has("PRIVATE_KEY") ? [vars.get("PRIVATE_KEY")] : [];
const ETHERSCAN_API_KEY = vars.has("ETHERSCAN_API_KEY") ? vars.get("ETHERSCAN_API_KEY") : "";
const config: HardhatUserConfig = {
  solidity: "0.8.28",
  defaultNetwork: "hardhat",
  networks: {
    'lisk-sepolia': {
      url: 'https://rpc.sepolia-api.lisk.com',
      accounts: ACCOUNTS,
      gasPrice: 1000000000,
    },
    alfajores: {
      // can be replaced with the RPC url of your choice.
      url: "https://alfajores-forno.celo-testnet.org",
      accounts: ACCOUNTS,
  },
  },
  etherscan: {
    apiKey: {
      "lisk-sepolia": "123",
      sepolia: ETHERSCAN_API_KEY,
      alfajores: ETHERSCAN_API_KEY,
    },
    customChains: [
      {
          network: "lisk-sepolia",
          chainId: 4202,
          urls: {
              apiURL: "https://sepolia-blockscout.lisk.com/api",
              browserURL: "https://sepolia-blockscout.lisk.com"
          }
      },
      {
        chainId: 44787,
        network: 'alfajores',
        urls: {
          apiURL: 'https://api-alfajores.celoscan.io/api',
          browserURL: 'https://alfajores.celoscan.io',
        },
      },
    ]
  },
  sourcify: {
    enabled: false
  },
  
}
export default config;