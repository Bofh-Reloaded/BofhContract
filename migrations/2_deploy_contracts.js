const MathLib = artifacts.require('MathLib');
const PoolLib = artifacts.require('PoolLib');
const SecurityLib = artifacts.require('SecurityLib');
const BofhContractV2 = artifacts.require('BofhContractV2');

module.exports = async function(deployer, network, accounts) {
  // Deploy libraries first
  await deployer.deploy(MathLib);
  await deployer.link(MathLib, [PoolLib, BofhContractV2]);
  
  await deployer.deploy(SecurityLib);
  await deployer.link(SecurityLib, BofhContractV2);
  
  await deployer.deploy(PoolLib);
  await deployer.link(PoolLib, BofhContractV2);

  // Deploy mock contracts for testing
  let baseTokenAddress;
  let factoryAddress;
  
  if (network === 'mainnet') {
    baseTokenAddress = '0x...'; // Production base token address
    factoryAddress = '0x...';   // Production factory address
  } else if (network === 'testnet') {
    baseTokenAddress = '0x...'; // Testnet base token address
    factoryAddress = '0x...';   // Testnet factory address
  } else {
    // For development, deploy mock infrastructure
    const MockToken = artifacts.require('MockToken');
    const MockFactory = artifacts.require('MockFactory');
    
    // Deploy tokens
    await deployer.deploy(MockToken, 'Base Token', 'BASE', '1000000000000000000000000');
    const baseToken = await MockToken.deployed();
    baseTokenAddress = baseToken.address;
    
    await deployer.deploy(MockToken, 'Test Token A', 'TKNA', '1000000000000000000000000');
    const tokenA = await MockToken.deployed();
    
    await deployer.deploy(MockToken, 'Test Token B', 'TKNB', '1000000000000000000000000');
    const tokenB = await MockToken.deployed();
    
    // Deploy factory and create initial pairs
    await deployer.deploy(MockFactory);
    const factory = await MockFactory.deployed();
    factoryAddress = factory.address;
    
    // Create test pairs
    await factory.createPair(baseTokenAddress, tokenA.address);
    await factory.createPair(baseTokenAddress, tokenB.address);
    await factory.createPair(tokenA.address, tokenB.address);
    
    // Add initial liquidity (this would be done through a separate script in practice)
    console.log('Mock tokens and pairs deployed:');
    console.log('Base Token:', baseTokenAddress);
    console.log('Token A:', tokenA.address);
    console.log('Token B:', tokenB.address);
    console.log('Factory:', factoryAddress);
  }

  // Deploy main contract
  await deployer.deploy(BofhContractV2, baseTokenAddress);
  const bofhContract = await BofhContractV2.deployed();

  // Set up initial configuration
  if (network !== 'mainnet') {
    // Set conservative test parameters
    await bofhContract.updateRiskParams(
      '1000000000000000000', // 1 token max trade volume
      '100000000000000000',  // 0.1 token min liquidity
      '100000',              // 10% max price impact
      '50'                   // 0.5% sandwich protection
    );
  }

  console.log('Deployment completed:');
  console.log('MathLib:', MathLib.address);
  console.log('SecurityLib:', SecurityLib.address);
  console.log('PoolLib:', PoolLib.address);
  console.log('BofhContractV2:', BofhContractV2.address);
  console.log('Base Token:', baseTokenAddress);
};
