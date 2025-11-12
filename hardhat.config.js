// Import individual plugins instead of toolbox to avoid ignition peer dependency conflict
// Note: hardhat-toolbox includes ignition which has peer dependency conflicts
// We import only what we need
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-network-helpers");
require("hardhat-gas-reporter");
require("solidity-coverage");

// Import environment configuration (same format as Truffle)
// Fallback to placeholder values in CI where env.json doesn't exist
let mnemonic, BSCSCANAPIKEY;
try {
  const env = require('./env.json');
  mnemonic = env.mnemonic;
  BSCSCANAPIKEY = env.BSCSCANAPIKEY;
} catch (e) {
  // Use placeholder values for CI/CD
  mnemonic = "test test test test test test test test test test test junk";
  BSCSCANAPIKEY = "placeholder";
}

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
