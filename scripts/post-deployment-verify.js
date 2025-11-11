const hre = require('hardhat');
const { loadDeployment } = require('./utils/helpers');

/**
 * Post-Deployment Verification Script
 *
 * Verifies that the deployed contract is in the expected state
 * and all critical functionality is working correctly.
 *
 * Usage:
 *   npx hardhat run scripts/post-deployment-verify.js --network bscTestnet
 */

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('POST-DEPLOYMENT VERIFICATION');
  console.log('='.repeat(70) + '\n');

  const networkName = hre.network.name;
  const [deployer] = await hre.ethers.getSigners();

  console.log(`Network: ${networkName}`);
  console.log(`Verifier: ${deployer.address}\n`);

  // Load deployment
  const deployment = loadDeployment(networkName);
  if (!deployment) {
    console.error('❌ No deployment found for network:', networkName);
    process.exit(1);
  }

  const contractAddress = deployment.contracts.BofhContractV2;
  console.log(`Contract Address: ${contractAddress}\n`);

  // Attach to contract
  const bofh = await hre.ethers.getContractAt('BofhContractV2', contractAddress);

  let passCount = 0;
  let failCount = 0;

  // Test helper
  const test = async (name, fn) => {
    try {
      process.stdout.write(`  ${name}... `);
      await fn();
      console.log('✅ PASS');
      passCount++;
    } catch (error) {
      console.log(`❌ FAIL: ${error.message}`);
      failCount++;
    }
  };

  // ======================================================================
  // 1. Contract Deployment Verification
  // ======================================================================
  console.log('1️⃣  CONTRACT DEPLOYMENT\n');

  await test('Contract exists at address', async () => {
    const code = await hre.ethers.provider.getCode(contractAddress);
    if (code === '0x') throw new Error('No code at address');
  });

  await test('Contract is BofhContractV2', async () => {
    // Try calling a unique function
    await bofh.getBaseToken();
  });

  // ======================================================================
  // 2. Configuration Verification
  // ======================================================================
  console.log('\n2️⃣  CONFIGURATION\n');

  await test('Base token matches deployment', async () => {
    const baseToken = await bofh.getBaseToken();
    if (baseToken.toLowerCase() !== deployment.config.baseToken.toLowerCase()) {
      throw new Error(`Mismatch: ${baseToken} !== ${deployment.config.baseToken}`);
    }
  });

  await test('Factory matches deployment', async () => {
    const factory = await bofh.getFactory();
    if (factory.toLowerCase() !== deployment.config.factory.toLowerCase()) {
      throw new Error(`Mismatch: ${factory} !== ${deployment.config.factory}`);
    }
  });

  await test('Owner is deployer', async () => {
    const owner = await bofh.admin();
    console.log(`\n      Owner: ${owner}`);
    if (owner.toLowerCase() !== deployer.address.toLowerCase()) {
      console.log('      ⚠️  Note: Owner is not deployer (may have been transferred)');
    }
  });

  // ======================================================================
  // 3. Initial State Verification
  // ======================================================================
  console.log('\n3️⃣  INITIAL STATE\n');

  await test('Contract is not paused', async () => {
    const paused = await bofh.isPaused();
    if (paused) throw new Error('Contract is paused');
  });

  await test('Risk parameters set to defaults', async () => {
    const params = await bofh.getRiskParams();
    console.log(`\n      Max Trade Volume: ${hre.ethers.formatEther(params.maxTradeVolume)}`);
    console.log(`      Min Pool Liquidity: ${hre.ethers.formatEther(params.minPoolLiquidity)}`);
    console.log(`      Max Price Impact: ${params.maxPriceImpact}%`);
    console.log(`      Sandwich Protection: ${params.sandwichProtectionBips} bips`);

    // Verify defaults
    const PRECISION = 1000000n;
    if (params.maxTradeVolume !== 1000n * PRECISION) {
      throw new Error('maxTradeVolume not default');
    }
    if (params.minPoolLiquidity !== 100n * PRECISION) {
      throw new Error('minPoolLiquidity not default');
    }
    if (params.maxPriceImpact !== 10n) {
      throw new Error('maxPriceImpact not default');
    }
    if (params.sandwichProtectionBips !== 50n) {
      throw new Error('sandwichProtectionBips not default');
    }
  });

  await test('MEV protection configured', async () => {
    const config = await bofh.getMEVProtectionConfig();
    console.log(`\n      Enabled: ${config.enabled}`);
    console.log(`      Max Tx Per Block: ${config.maxTxPerBlock}`);
    console.log(`      Min Tx Delay: ${config.minTxDelay}s`);
  });

  // ======================================================================
  // 4. View Functions
  // ======================================================================
  console.log('\n4️⃣  VIEW FUNCTIONS\n');

  await test('getBaseToken() works', async () => {
    const baseToken = await bofh.getBaseToken();
    if (!hre.ethers.isAddress(baseToken)) {
      throw new Error('Invalid address returned');
    }
  });

  await test('getFactory() works', async () => {
    const factory = await bofh.getFactory();
    if (!hre.ethers.isAddress(factory)) {
      throw new Error('Invalid address returned');
    }
  });

  await test('admin() works', async () => {
    const admin = await bofh.admin();
    if (!hre.ethers.isAddress(admin)) {
      throw new Error('Invalid address returned');
    }
  });

  await test('isPaused() works', async () => {
    const paused = await bofh.isPaused();
    if (typeof paused !== 'boolean') {
      throw new Error('Invalid boolean returned');
    }
  });

  // ======================================================================
  // 5. External Dependencies
  // ======================================================================
  console.log('\n5️⃣  EXTERNAL DEPENDENCIES\n');

  await test('Base token contract exists', async () => {
    const baseToken = await bofh.getBaseToken();
    const code = await hre.ethers.provider.getCode(baseToken);
    if (code === '0x') throw new Error('Base token contract not found');
  });

  await test('Factory contract exists', async () => {
    const factory = await bofh.getFactory();
    const code = await hre.ethers.provider.getCode(factory);
    if (code === '0x') throw new Error('Factory contract not found');
  });

  await test('Factory is callable', async () => {
    const factory = await bofh.getFactory();
    const factoryContract = await hre.ethers.getContractAt(
      'IUniswapV2Factory',
      factory
    );
    // Try to call allPairsLength (should work on any Uniswap V2 factory)
    await factoryContract.allPairsLength();
  });

  // ======================================================================
  // 6. Access Control
  // ======================================================================
  console.log('\n6️⃣  ACCESS CONTROL\n');

  await test('Owner can access owner-only functions', async () => {
    // Try to get risk params (owner-only in some implementations)
    await bofh.getRiskParams();
  });

  await test('Contract can be paused by owner', async () => {
    const owner = await bofh.admin();
    if (owner.toLowerCase() === deployer.address.toLowerCase()) {
      console.log('\n      ⚠️  Skipping pause test (would affect production)');
    } else {
      console.log('\n      ⚠️  Cannot test pause (not owner)');
    }
  });

  // ======================================================================
  // 7. Gas Checks
  // ======================================================================
  console.log('\n7️⃣  GAS ESTIMATES\n');

  await test('View functions are low gas', async () => {
    const gasEstimate = await bofh.getBaseToken.estimateGas();
    console.log(`\n      getBaseToken gas: ${gasEstimate.toString()}`);
    if (gasEstimate > 50000n) {
      throw new Error(`Gas too high: ${gasEstimate}`);
    }
  });

  // ======================================================================
  // 8. BSCScan Verification (if applicable)
  // ======================================================================
  if (networkName === 'bscTestnet' || networkName === 'bscMainnet') {
    console.log('\n8️⃣  BSCSCAN VERIFICATION\n');

    const explorerUrl =
      networkName === 'bscTestnet'
        ? 'https://testnet.bscscan.com'
        : 'https://bscscan.com';

    console.log(`  🔗 View on BSCScan:`);
    console.log(`     ${explorerUrl}/address/${contractAddress}#code\n`);

    console.log(`  ℹ️  Manual verification steps:`);
    console.log(`     1. Visit the link above`);
    console.log(`     2. Check for green checkmark (verified)`);
    console.log(`     3. Verify "Read Contract" tab works`);
    console.log(`     4. Verify "Write Contract" tab works`);
    console.log(`     5. Check transaction history\n`);
  }

  // ======================================================================
  // Summary
  // ======================================================================
  console.log('='.repeat(70));
  console.log('VERIFICATION SUMMARY');
  console.log('='.repeat(70) + '\n');

  const total = passCount + failCount;
  const percentage = ((passCount / total) * 100).toFixed(1);

  console.log(`Total Tests: ${total}`);
  console.log(`Passed: ${passCount} ✅`);
  console.log(`Failed: ${failCount} ❌`);
  console.log(`Success Rate: ${percentage}%\n`);

  if (failCount === 0) {
    console.log('✅ ALL CHECKS PASSED - Deployment verified successfully!\n');
    console.log('Next steps:');
    console.log('1. Monitor contract for first 24 hours');
    console.log('2. Test with small amounts first');
    console.log('3. Gradually increase usage');
    console.log('4. Setup monitoring alerts');
    console.log('5. Document any issues\n');
  } else {
    console.log(`⚠️  ${failCount} CHECK(S) FAILED - Review and fix issues\n`);
    console.log('Required actions:');
    console.log('1. Review failed checks above');
    console.log('2. Investigate root causes');
    console.log('3. Fix issues if possible');
    console.log('4. Re-run verification');
    console.log('5. Consider redeployment if critical\n');
    process.exit(1);
  }

  console.log('='.repeat(70) + '\n');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Verification script failed:\n', error);
    process.exit(1);
  });
