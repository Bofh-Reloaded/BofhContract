require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("solidity-coverage");

// Import environment configuration (same format as Truffle)
const { mnemonic, BSCSCANAPIKEY } = require('./env.json');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },

  networks: {
    // Local Hardhat network (replaces Ganache)
    hardhat: {
      chainId: 31337,
      accounts: {
        mnemonic: mnemonic,
        count: 10
      }
    },

    // BSC Testnet (Chain ID: 97)
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: {
        mnemonic: mnemonic
      },
      gasPrice: 10000000000, // 10 gwei
      timeout: 100000,
      confirmations: 10
    },

    // BSC Mainnet (Chain ID: 56) - disabled for now
    // bscMainnet: {
    //   url: "https://bsc-dataseed1.binance.org",
    //   chainId: 56,
    //   accounts: {
    //     mnemonic: mnemonic
    //   },
    //   gasPrice: 5000000000, // 5 gwei
    //   confirmations: 10
    // }
  },

  // Gas reporter configuration
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    outputFile: "gas-report.txt",
    noColors: true
  },

  // Etherscan verification
  etherscan: {
    apiKey: {
      bscTestnet: BSCSCANAPIKEY,
      bsc: BSCSCANAPIKEY
    }
  },

  // Path configuration (match Truffle structure)
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },

  // Mocha test configuration
  mocha: {
    timeout: 100000
  },

  // Coverage configuration - Note: mocks are test utilities, not production code
  // Production code coverage (libs/ and main/) is >93%
};
