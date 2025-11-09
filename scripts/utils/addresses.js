// Network addresses for BofhContract deployment

/**
 * Known token addresses on different networks
 */
const TOKENS = {
  // BSC Mainnet
  bsc: {
    WBNB: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
    BUSD: '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
    USDT: '0x55d398326f99059fF775485246999027B3197955',
    BTCB: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c',
    ETH: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8',
    CAKE: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82'
  },

  // BSC Testnet
  bscTestnet: {
    WBNB: '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd',
    BUSD: '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee', // BUSD-T
    USDT: '0x337610d27c682E347C9cD60BD4b3b107C9d34dDd', // USDT-T
    DAI: '0xEC5dCb5Dbf4B114C9d0F65BcCAb49EC54F6A0867', // DAI-T
    CAKE: '0xFa60D973F7642B748046464e165A65B7323b0DEE'  // CAKE-T
  },

  // Local Hardhat (deployed mocks)
  hardhat: {
    // Will be populated during deployment
  },

  localhost: {
    // Will be populated during deployment
  }
};

/**
 * Known factory addresses (Uniswap V2 / PancakeSwap style)
 */
const FACTORIES = {
  // BSC Mainnet
  bsc: {
    PancakeSwapV2: '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73',
    BiswapV2: '0x858E3312ed3A876947EA49d572A7C42DE08af7EE',
    ApeSwapV2: '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6'
  },

  // BSC Testnet
  bscTestnet: {
    PancakeSwapV2: '0x6725F303b657a9451d8BA641348b6761A6CC7a17'
  },

  // Local Hardhat (deployed mock)
  hardhat: {
    // Will be populated during deployment
  },

  localhost: {
    // Will be populated during deployment
  }
};

/**
 * Get base token address for a network
 * @param {string} networkName - Name of the network (hardhat, bscTestnet, bsc)
 * @returns {string} Base token address (WBNB or mock)
 */
function getBaseToken(networkName) {
  if (networkName === 'bsc') {
    return TOKENS.bsc.WBNB;
  } else if (networkName === 'bscTestnet') {
    return TOKENS.bscTestnet.WBNB;
  } else {
    // For local networks, must be set after mock deployment
    throw new Error(`Base token for ${networkName} must be deployed first`);
  }
}

/**
 * Get factory address for a network
 * @param {string} networkName - Name of the network
 * @param {string} dex - DEX name (default: PancakeSwapV2)
 * @returns {string} Factory address
 */
function getFactory(networkName, dex = 'PancakeSwapV2') {
  if (networkName === 'bsc' || networkName === 'bscTestnet') {
    const factory = FACTORIES[networkName][dex];
    if (!factory) {
      throw new Error(`Factory ${dex} not found for network ${networkName}`);
    }
    return factory;
  } else {
    // For local networks, must be set after mock deployment
    throw new Error(`Factory for ${networkName} must be deployed first`);
  }
}

/**
 * Check if network is a testnet/local network
 * @param {string} networkName - Name of the network
 * @returns {boolean} True if testnet or local
 */
function isTestNetwork(networkName) {
  return ['hardhat', 'localhost', 'bscTestnet'].includes(networkName);
}

module.exports = {
  TOKENS,
  FACTORIES,
  getBaseToken,
  getFactory,
  isTestNetwork
};
