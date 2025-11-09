const fs = require('fs');
const path = require('path');

/**
 * Save deployment information to JSON file
 * @param {string} networkName - Network name
 * @param {object} deployment - Deployment data
 */
function saveDeployment(networkName, deployment) {
  const deploymentsDir = path.join(__dirname, '../../deployments');

  // Ensure deployments directory exists
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }

  const filePath = path.join(deploymentsDir, `${networkName}.json`);

  fs.writeFileSync(
    filePath,
    JSON.stringify(deployment, null, 2)
  );

  console.log(`\n📝 Deployment saved to: ${filePath}`);
}

/**
 * Load deployment information from JSON file
 * @param {string} networkName - Network name
 * @returns {object|null} Deployment data or null if not found
 */
function loadDeployment(networkName) {
  const filePath = path.join(__dirname, '../../deployments', `${networkName}.json`);

  if (!fs.existsSync(filePath)) {
    return null;
  }

  const data = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(data);
}

/**
 * Wait for a transaction with user feedback
 * @param {object} tx - Transaction object
 * @param {string} description - Description of the transaction
 * @returns {object} Transaction receipt
 */
async function waitForTx(tx, description) {
  console.log(`⏳ ${description}...`);
  const receipt = await tx.wait();
  console.log(`✅ ${description} (gas: ${receipt.gasUsed.toString()})`);
  return receipt;
}

/**
 * Deploy a contract with feedback
 * @param {object} ethers - Ethers object
 * @param {string} contractName - Name of the contract
 * @param {array} args - Constructor arguments
 * @param {object} options - Deploy options (libraries, etc.)
 * @returns {object} Deployed contract
 */
async function deployContract(ethers, contractName, args = [], options = {}) {
  console.log(`\n📦 Deploying ${contractName}...`);

  const Contract = await ethers.getContractFactory(contractName, options);
  const contract = await Contract.deploy(...args);
  await contract.deployed();

  console.log(`✅ ${contractName} deployed to: ${contract.address}`);

  return contract;
}

/**
 * Deploy a library with feedback
 * @param {object} ethers - Ethers object
 * @param {string} libraryName - Name of the library
 * @returns {object} Deployed library
 */
async function deployLibrary(ethers, libraryName) {
  console.log(`📚 Deploying library: ${libraryName}...`);

  const Library = await ethers.getContractFactory(libraryName);
  const library = await Library.deploy();
  await library.waitForDeployment();

  const address = await library.getAddress();
  console.log(`   ✅ ${libraryName}: ${address}`);

  return library;
}

/**
 * Verify contract on block explorer
 * @param {object} hre - Hardhat Runtime Environment
 * @param {string} address - Contract address
 * @param {array} constructorArguments - Constructor arguments
 * @param {object} libraries - Library addresses
 */
async function verifyContract(hre, address, constructorArguments = [], libraries = {}) {
  console.log(`\n🔍 Verifying contract at ${address}...`);

  try {
    await hre.run('verify:verify', {
      address,
      constructorArguments,
      libraries
    });
    console.log(`✅ Contract verified successfully`);
  } catch (error) {
    if (error.message.includes('Already Verified')) {
      console.log(`ℹ️  Contract already verified`);
    } else {
      console.error(`❌ Verification failed:`, error.message);
      throw error;
    }
  }
}

/**
 * Format token amount for display
 * @param {BigNumber} amount - Amount in wei
 * @param {number} decimals - Token decimals (default 18)
 * @returns {string} Formatted amount
 */
function formatAmount(amount, decimals = 18) {
  const { ethers } = require('hardhat');
  return ethers.formatUnits(amount, decimals);
}

/**
 * Parse token amount from human-readable string
 * @param {string} amount - Amount string (e.g., "1.5")
 * @param {number} decimals - Token decimals (default 18)
 * @returns {BigNumber} Amount in wei
 */
function parseAmount(amount, decimals = 18) {
  const { ethers } = require('hardhat');
  return ethers.parseUnits(amount, decimals);
}

/**
 * Delay execution for specified milliseconds
 * @param {number} ms - Milliseconds to delay
 */
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Print deployment summary
 * @param {object} deployment - Deployment data
 */
function printDeploymentSummary(deployment) {
  console.log('\n' + '='.repeat(60));
  console.log('📊 DEPLOYMENT SUMMARY');
  console.log('='.repeat(60));
  console.log(`Network: ${deployment.network}`);
  console.log(`Timestamp: ${deployment.timestamp}`);
  console.log(`Deployer: ${deployment.deployer}`);

  console.log('\n📚 Libraries:');
  Object.entries(deployment.libraries).forEach(([name, address]) => {
    console.log(`   ${name}: ${address}`);
  });

  console.log('\n📝 Contracts:');
  Object.entries(deployment.contracts).forEach(([name, address]) => {
    console.log(`   ${name}: ${address}`);
  });

  if (deployment.config) {
    console.log('\n⚙️  Configuration:');
    console.log(`   Base Token: ${deployment.config.baseToken}`);
    console.log(`   Factory: ${deployment.config.factory}`);
  }

  console.log('='.repeat(60) + '\n');
}

module.exports = {
  saveDeployment,
  loadDeployment,
  waitForTx,
  deployContract,
  deployLibrary,
  verifyContract,
  formatAmount,
  parseAmount,
  delay,
  printDeploymentSummary
};
