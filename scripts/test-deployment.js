const hre = require('hardhat');
const { ethers } = require('hardhat');
const { loadDeployment } = require('./utils/helpers');

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('DEPLOYMENT TEST & LIQUIDITY SETUP');
  console.log('='.repeat(70) + '\n');

  const [deployer] = await ethers.getSigners();
  const networkName = hre.network.name;
  const deployment = loadDeployment(networkName);

  if (!deployment) {
    console.error('❌ No deployment found');
    process.exit(1);
  }

  // Get contract instances
  const bofh = await ethers.getContractAt('BofhContractV2', deployment.contracts.BofhContractV2);
  const factory = await ethers.getContractAt('MockFactory', deployment.config.factory);
  const baseToken = await ethers.getContractAt('MockToken', deployment.mocks.tokens.BASE);
  const tokenA = await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNA);
  const tokenB = await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNB);
  const tokenC = await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNC);

  console.log('📊 STEP 1: Verify Deployment\n');
  console.log('✅ BofhContract:', await bofh.getAddress());
  console.log('✅ Base Token:', await bofh.getBaseToken());
  console.log('✅ Factory:', await bofh.getFactory());
  console.log('✅ Paused:', await bofh.isPaused());

  console.log('\n💧 STEP 2: Adding Liquidity to Pools\n');

  // Get pair addresses
  const pairBaseA = await factory.getPair(await baseToken.getAddress(), await tokenA.getAddress());
  const pairBaseB = await factory.getPair(await baseToken.getAddress(), await tokenB.getAddress());
  const pairBaseC = await factory.getPair(await baseToken.getAddress(), await tokenC.getAddress());
  const pairAB = await factory.getPair(await tokenA.getAddress(), await tokenB.getAddress());

  console.log('Pair BASE-TKNA:', pairBaseA);
  console.log('Pair BASE-TKNB:', pairBaseB);
  console.log('Pair BASE-TKNC:', pairBaseC);
  console.log('Pair TKNA-TKNB:', pairAB);

  const MockPair = await ethers.getContractFactory('MockPair');

  // Add liquidity to each pair
  const liquidityBase = ethers.parseEther('100000');
  const liquidityOther = ethers.parseEther('100000');

  console.log('\n   Adding liquidity to BASE-TKNA...');
  await baseToken.transfer(pairBaseA, liquidityBase);
  await tokenA.transfer(pairBaseA, liquidityOther);
  await MockPair.attach(pairBaseA).sync();
  console.log('   ✅ BASE-TKNA liquidity added');

  console.log('   Adding liquidity to BASE-TKNB...');
  await baseToken.transfer(pairBaseB, liquidityBase);
  await tokenB.transfer(pairBaseB, liquidityOther);
  await MockPair.attach(pairBaseB).sync();
  console.log('   ✅ BASE-TKNB liquidity added');

  console.log('   Adding liquidity to BASE-TKNC...');
  await baseToken.transfer(pairBaseC, liquidityBase);
  await tokenC.transfer(pairBaseC, liquidityOther);
  await MockPair.attach(pairBaseC).sync();
  console.log('   ✅ BASE-TKNC liquidity added');

  console.log('   Adding liquidity to TKNA-TKNB...');
  await tokenA.transfer(pairAB, liquidityOther);
  await tokenB.transfer(pairAB, liquidityOther);
  await MockPair.attach(pairAB).sync();
  console.log('   ✅ TKNA-TKNB liquidity added');

  console.log('\n🧪 STEP 3: Test Swap Execution\n');

  // Approve BofhContract to spend base tokens
  const approveAmount = ethers.parseEther('10000');
  await baseToken.approve(await bofh.getAddress(), approveAmount);
  console.log('✅ Approved BofhContract to spend', ethers.formatEther(approveAmount), 'BASE');

  // Test 2-way swap: BASE → TKNA → BASE
  console.log('\n📈 Testing 2-way swap (BASE → TKNA → BASE)...');
  const path = [
    await baseToken.getAddress(),
    await tokenA.getAddress(),
    await baseToken.getAddress()
  ];
  const fees = [3, 3]; // 0.3% fees
  const amountIn = ethers.parseEther('1000');
  const minAmountOut = ethers.parseEther('900');
  const deadline = Math.floor(Date.now() / 1000) + 3600;

  const balanceBefore = await baseToken.balanceOf(deployer.address);
  console.log('   Balance before:', ethers.formatEther(balanceBefore), 'BASE');

  const tx = await bofh.executeSwap(path, fees, amountIn, minAmountOut, deadline);
  const receipt = await tx.wait();

  const balanceAfter = await baseToken.balanceOf(deployer.address);
  console.log('   Balance after:', ethers.formatEther(balanceAfter), 'BASE');
  console.log('   Net change:', ethers.formatEther(balanceAfter - balanceBefore), 'BASE');
  console.log('   Gas used:', receipt.gasUsed.toString());
  console.log('   ✅ 2-way swap successful!');

  // Test 3-way swap: BASE → TKNA → TKNB → BASE
  console.log('\n📈 Testing 3-way swap (BASE → TKNA → TKNB → BASE)...');
  const path3 = [
    await baseToken.getAddress(),
    await tokenA.getAddress(),
    await tokenB.getAddress(),
    await baseToken.getAddress()
  ];
  const fees3 = [3, 3, 3];
  const amountIn3 = ethers.parseEther('1000');
  const minAmountOut3 = ethers.parseEther('800');

  const balance3Before = await baseToken.balanceOf(deployer.address);
  const tx3 = await bofh.executeSwap(path3, fees3, amountIn3, minAmountOut3, deadline);
  const receipt3 = await tx3.wait();
  const balance3After = await baseToken.balanceOf(deployer.address);

  console.log('   Balance before:', ethers.formatEther(balance3Before), 'BASE');
  console.log('   Balance after:', ethers.formatEther(balance3After), 'BASE');
  console.log('   Net change:', ethers.formatEther(balance3After - balance3Before), 'BASE');
  console.log('   Gas used:', receipt3.gasUsed.toString());
  console.log('   ✅ 3-way swap successful!');

  console.log('\n' + '='.repeat(70));
  console.log('✅ ALL TESTS PASSED');
  console.log('='.repeat(70) + '\n');

  console.log('📊 Summary:');
  console.log('   - Contract deployed and configured');
  console.log('   - 4 liquidity pools created');
  console.log('   - 2-way swap executed successfully');
  console.log('   - 3-way swap executed successfully');
  console.log('   - Gas costs measured and logged\n');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Test failed:\n', error);
    process.exit(1);
  });
