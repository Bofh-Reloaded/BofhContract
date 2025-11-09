const hre = require('hardhat');
const { ethers } = require('hardhat');
const {
  deployLibrary,
  deployContract,
  saveDeployment,
  printDeploymentSummary,
  delay
} = require('./utils/helpers');
const { getBaseToken, getFactory, isTestNetwork } = require('./utils/addresses');

async function main() {
  console.log('\n🚀 Starting BofhContract deployment...\n');

  const [deployer] = await ethers.getSigners();
  const networkName = hre.network.name;

  const balance = await ethers.provider.getBalance(deployer.address);

  console.log(`Network: ${networkName}`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(balance)} BNB\n`);

  // ==================================================================
  // Step 1: Deploy Libraries
  // ==================================================================
  console.log('📚 STEP 1: Deploying Libraries\n');

  const mathLib = await deployLibrary(ethers, 'MathLib');
  const securityLib = await deployLibrary(ethers, 'SecurityLib');

  // PoolLib depends on MathLib
  const poolLib = await deployLibrary(ethers, 'PoolLib');

  const libraries = {
    MathLib: await mathLib.getAddress(),
    SecurityLib: await securityLib.getAddress(),
    PoolLib: await poolLib.getAddress()
  };

  // ==================================================================
  // Step 2: Get or Deploy Base Infrastructure
  // ==================================================================
  console.log('\n🏗️  STEP 2: Base Infrastructure\n');

  let baseToken, factory;
  let mockDeployments = {};

  if (isTestNetwork(networkName)) {
    if (networkName === 'bscTestnet') {
      // Use real testnet addresses
      baseToken = getBaseToken(networkName);
      factory = getFactory(networkName);
      console.log(`✅ Using BSC Testnet WBNB: ${baseToken}`);
      console.log(`✅ Using PancakeSwap V2 Factory: ${factory}`);
    } else {
      // Deploy mocks for local network
      console.log('   Deploying mock infrastructure for local testing...\n');

      // Deploy mock tokens
      const MockToken = await ethers.getContractFactory('MockToken');

      console.log('   📦 Deploying mock tokens...');
      const baseTokenContract = await MockToken.deploy(
        'Wrapped BNB',
        'WBNB',
        ethers.parseEther('1000000')
      );
      await baseTokenContract.waitForDeployment();
      baseToken = await baseTokenContract.getAddress();
      console.log(`      BASE (WBNB): ${baseToken}`);

      const tokenA = await MockToken.deploy(
        'Test Token A',
        'TKNA',
        ethers.parseEther('1000000')
      );
      await tokenA.waitForDeployment();
      console.log(`      TKNA: ${await tokenA.getAddress()}`);

      const tokenB = await MockToken.deploy(
        'Test Token B',
        'TKNB',
        ethers.parseEther('1000000')
      );
      await tokenB.waitForDeployment();
      console.log(`      TKNB: ${await tokenB.getAddress()}`);

      const tokenC = await MockToken.deploy(
        'Test Token C',
        'TKNC',
        ethers.parseEther('1000000')
      );
      await tokenC.waitForDeployment();
      console.log(`      TKNC: ${await tokenC.getAddress()}`);

      // Deploy mock factory
      console.log('\n   📦 Deploying mock factory...');
      const MockFactory = await ethers.getContractFactory('MockFactory');
      const factoryContract = await MockFactory.deploy();
      await factoryContract.waitForDeployment();
      factory = await factoryContract.getAddress();
      console.log(`      Factory: ${factory}`);

      // Create pairs
      console.log('\n   🔗 Creating mock pairs...');
      const tokenAAddr = await tokenA.getAddress();
      const tokenBAddr = await tokenB.getAddress();
      const tokenCAddr = await tokenC.getAddress();

      await factoryContract.createPair(baseToken, tokenAAddr);
      console.log(`      ✅ BASE-TKNA pair created`);

      await factoryContract.createPair(baseToken, tokenBAddr);
      console.log(`      ✅ BASE-TKNB pair created`);

      await factoryContract.createPair(baseToken, tokenCAddr);
      console.log(`      ✅ BASE-TKNC pair created`);

      await factoryContract.createPair(tokenAAddr, tokenBAddr);
      console.log(`      ✅ TKNA-TKNB pair created`);

      mockDeployments = {
        tokens: {
          BASE: baseToken,
          TKNA: tokenAAddr,
          TKNB: tokenBAddr,
          TKNC: tokenCAddr
        },
        factory: factory
      };
    }
  } else {
    // Production mainnet
    baseToken = getBaseToken(networkName);
    factory = getFactory(networkName);
    console.log(`✅ Using mainnet WBNB: ${baseToken}`);
    console.log(`✅ Using PancakeSwap V2 Factory: ${factory}`);
  }

  // ==================================================================
  // Step 3: Deploy Main Contract
  // ==================================================================
  console.log('\n📝 STEP 3: Deploying BofhContractV2\n');

  // Note: Libraries are embedded in contract bytecode by Hardhat compiler
  // No need for explicit linking
  const BofhContractV2 = await ethers.getContractFactory('BofhContractV2');

  const bofhContract = await BofhContractV2.deploy(baseToken, factory);
  await bofhContract.waitForDeployment();

  console.log(`✅ BofhContractV2 deployed to: ${await bofhContract.getAddress()}`);

  // ==================================================================
  // Step 4: Save Deployment Info
  // ==================================================================
  const deployment = {
    network: networkName,
    chainId: hre.network.config.chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    libraries,
    contracts: {
      BofhContractV2: await bofhContract.getAddress()
    },
    config: {
      baseToken,
      factory
    },
    ...(Object.keys(mockDeployments).length > 0 && { mocks: mockDeployments })
  };

  saveDeployment(networkName, deployment);
  printDeploymentSummary(deployment);

  // ==================================================================
  // Step 5: Verification (if on public network)
  // ==================================================================
  if (networkName === 'bscTestnet' || networkName === 'bsc') {
    console.log('\n🔍 STEP 5: Preparing for verification\n');
    console.log('⏳ Waiting 30 seconds for Etherscan to index...');
    await delay(30000);

    console.log('\nℹ️  To verify contracts, run:');
    console.log(`   npm run verify -- --network ${networkName}\n`);
  }

  console.log('\n✅ Deployment completed successfully!\n');
  console.log('Next steps:');
  console.log('1. Run configuration script: npm run configure');
  console.log('2. Verify contracts (if on testnet/mainnet): npm run verify');
  console.log('3. Test the deployment\n');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Deployment failed:\n', error);
    process.exit(1);
  });
