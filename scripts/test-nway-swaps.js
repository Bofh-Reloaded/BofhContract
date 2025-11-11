const hre = require("hardhat");
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

function loadDeployment(network) {
  const deploymentPath = path.join(__dirname, '..', 'deployments', `${network}.json`);
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(`Deployment file not found for network: ${network}`);
  }
  return JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
}

async function main() {
  const networkName = hre.network.name;
  console.log("\n" + "=".repeat(70));
  console.log("N-WAY SWAP PROFITABILITY & TIMING ANALYSIS");
  console.log("=".repeat(70) + "\n");

  // Load deployment
  const deployment = loadDeployment(networkName);
  const [deployer] = await ethers.getSigners();

  console.log("📊 Test Configuration:");
  console.log(`   Network: ${networkName}`);
  console.log(`   Tester: ${deployer.address}`);
  console.log(`   BofhContract: ${deployment.contracts.BofhContractV2}\n`);

  // Get contracts
  const bofh = await ethers.getContractAt('BofhContractV2', deployment.contracts.BofhContractV2);
  const baseToken = await ethers.getContractAt('MockToken', deployment.mocks.tokens.BASE);
  const tokenA = await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNA);
  const tokenB = await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNB);
  const tokenC = await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNC);

  // Test parameters
  const testAmount = ethers.parseEther("1000");
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  const minAmountOut = ethers.parseEther("1"); // Must be > 0

  // Add liquidity to pools first
  console.log("💧 Adding liquidity to pools...\n");
  const factory = await ethers.getContractAt('MockFactory', deployment.mocks.factory);
  const MockPair = await ethers.getContractFactory('MockPair');

  const liquidityBase = ethers.parseEther("100000");
  const pairs = [
    { name: "BASE-TKNA", token0: baseToken, token1: tokenA },
    { name: "BASE-TKNB", token0: baseToken, token1: tokenB },
    { name: "BASE-TKNC", token0: baseToken, token1: tokenC },
    { name: "TKNA-TKNB", token0: tokenA, token1: tokenB }
  ];

  for (const { name, token0, token1 } of pairs) {
    const pairAddr = await factory.getPair(await token0.getAddress(), await token1.getAddress());
    const pair = MockPair.attach(pairAddr);

    await token0.transfer(pairAddr, liquidityBase);
    await token1.transfer(pairAddr, liquidityBase);
    await pair.sync();

    console.log(`   ✅ ${name}: ${liquidityBase / BigInt(1e18)} tokens each`);
  }

  // Approve spending
  const approvalAmount = ethers.parseEther("100000");
  await baseToken.approve(deployment.contracts.BofhContractV2, approvalAmount);
  console.log(`\n✅ Approved BofhContract to spend ${ethers.formatEther(approvalAmount)} BASE\n`);

  // Define all test paths
  const testPaths = [
    {
      name: "2-Way Swap",
      path: [deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNA, deployment.mocks.tokens.BASE],
      fees: [3, 3]
    },
    {
      name: "3-Way Swap",
      path: [deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNA, deployment.mocks.tokens.TKNB, deployment.mocks.tokens.BASE],
      fees: [3, 3, 3]
    },
    {
      name: "4-Way Swap",
      path: [deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNA, deployment.mocks.tokens.TKNB, deployment.mocks.tokens.TKNA, deployment.mocks.tokens.BASE],
      fees: [3, 3, 3, 3]
    },
    {
      name: "5-Way Swap (Max)",
      path: [deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNA, deployment.mocks.tokens.TKNB, deployment.mocks.tokens.TKNA, deployment.mocks.tokens.TKNB, deployment.mocks.tokens.BASE],
      fees: [3, 3, 3, 3, 3]
    }
  ];

  const results = [];

  // Execute all test swaps
  for (const test of testPaths) {
    console.log(`\n${"─".repeat(70)}`);
    console.log(`📈 ${test.name} (${test.path.length - 1} hops)`);
    console.log(`${"─".repeat(70)}\n`);

    try {
      const balanceBefore = await baseToken.balanceOf(deployer.address);
      const startTime = Date.now();
      const startBlock = await ethers.provider.getBlockNumber();

      const tx = await bofh.executeSwap(
        test.path,
        test.fees,
        testAmount,
        minAmountOut,
        deadline
      );

      const receipt = await tx.wait();
      const endTime = Date.now();
      const endBlock = await ethers.provider.getBlockNumber();

      const balanceAfter = await baseToken.balanceOf(deployer.address);
      const netChange = balanceAfter - balanceBefore;
      const netChangeEth = parseFloat(ethers.formatEther(netChange));
      const inputEth = parseFloat(ethers.formatEther(testAmount));
      const profitLossPercent = ((netChangeEth / inputEth) * 100).toFixed(4);

      // Calculate expected fees
      const expectedFees = (test.fees.length * 0.3).toFixed(2);

      // Timing metrics
      const executionTime = endTime - startTime;
      const gasUsed = receipt.gasUsed.toString();
      const blocksUsed = endBlock - startBlock;

      const result = {
        name: test.name,
        hops: test.path.length - 1,
        input: inputEth,
        output: parseFloat(ethers.formatEther(balanceAfter - balanceBefore + testAmount)),
        netChange: netChangeEth,
        profitLossPercent: parseFloat(profitLossPercent),
        gasUsed: parseInt(gasUsed),
        gasPerHop: Math.round(parseInt(gasUsed) / (test.path.length - 1)),
        executionTime,
        blocksUsed,
        expectedFees: parseFloat(expectedFees),
        success: true
      };

      results.push(result);

      console.log(`   Input Amount:      ${inputEth.toFixed(2)} BASE`);
      console.log(`   Output Amount:     ${result.output.toFixed(2)} BASE`);
      console.log(`   Net Change:        ${netChangeEth >= 0 ? '+' : ''}${netChangeEth.toFixed(6)} BASE`);
      console.log(`   Profit/Loss:       ${profitLossPercent >= 0 ? '+' : ''}${profitLossPercent}%`);
      console.log(`   Expected Fees:     ${expectedFees}% (${test.fees.length} hops × 0.3%)`);
      console.log(`   Gas Used:          ${gasUsed.toLocaleString()}`);
      console.log(`   Gas per Hop:       ${result.gasPerHop.toLocaleString()}`);
      console.log(`   Execution Time:    ${executionTime}ms`);
      console.log(`   Blocks Used:       ${blocksUsed}`);

      if (netChangeEth >= 0) {
        console.log(`   ✅ PROFITABLE! +${netChangeEth.toFixed(6)} BASE`);
      } else {
        console.log(`   ❌ LOSS: ${netChangeEth.toFixed(6)} BASE`);
      }

    } catch (error) {
      console.log(`   ❌ FAILED: ${error.message}`);
      results.push({
        name: test.name,
        hops: test.path.length - 1,
        success: false,
        error: error.message
      });
    }
  }

  // Summary Analysis
  console.log("\n" + "=".repeat(70));
  console.log("📊 SUMMARY ANALYSIS");
  console.log("=".repeat(70) + "\n");

  const successfulSwaps = results.filter(r => r.success);

  if (successfulSwaps.length > 0) {
    console.log("┌────────────────┬──────┬─────────────┬─────────────┬───────────┬──────────┐");
    console.log("│ Swap Type      │ Hops │ Net Change  │ Profit/Loss │ Gas Used  │ Time (ms)│");
    console.log("├────────────────┼──────┼─────────────┼─────────────┼───────────┼──────────┤");

    for (const result of successfulSwaps) {
      const nameCol = result.name.padEnd(14);
      const hopsCol = result.hops.toString().padStart(4);
      const changeCol = `${result.netChange >= 0 ? '+' : ''}${result.netChange.toFixed(2)} BASE`.padStart(11);
      const plCol = `${result.profitLossPercent >= 0 ? '+' : ''}${result.profitLossPercent.toFixed(2)}%`.padStart(11);
      const gasCol = result.gasUsed.toLocaleString().padStart(9);
      const timeCol = result.executionTime.toString().padStart(8);

      console.log(`│ ${nameCol} │ ${hopsCol} │ ${changeCol} │ ${plCol} │ ${gasCol} │ ${timeCol} │`);
    }

    console.log("└────────────────┴──────┴─────────────┴─────────────┴───────────┴──────────┘");

    // Performance metrics
    const totalGas = successfulSwaps.reduce((sum, r) => sum + r.gasUsed, 0);
    const avgGas = Math.round(totalGas / successfulSwaps.length);
    const totalTime = successfulSwaps.reduce((sum, r) => sum + r.executionTime, 0);
    const avgTime = Math.round(totalTime / successfulSwaps.length);
    const totalLoss = successfulSwaps.reduce((sum, r) => sum + r.netChange, 0);

    console.log("\n📈 Performance Metrics:");
    const inputEth = parseFloat(ethers.formatEther(testAmount));
    console.log(`   Total Swaps:        ${successfulSwaps.length}/${testPaths.length}`);
    console.log(`   Average Gas:        ${avgGas.toLocaleString()}`);
    console.log(`   Average Time:       ${avgTime}ms`);
    console.log(`   Total Net Change:   ${totalLoss >= 0 ? '+' : ''}${totalLoss.toFixed(6)} BASE`);
    console.log(`   Overall P/L:        ${((totalLoss / (inputEth * successfulSwaps.length)) * 100).toFixed(4)}%`);

    // Gas efficiency analysis
    console.log("\n⛽ Gas Efficiency Analysis:");
    console.log(`   Most Efficient:     ${successfulSwaps[0].name} (${successfulSwaps[0].gasPerHop.toLocaleString()} gas/hop)`);
    console.log(`   Least Efficient:    ${successfulSwaps[successfulSwaps.length-1].name} (${successfulSwaps[successfulSwaps.length-1].gasPerHop.toLocaleString()} gas/hop)`);

    // Gas optimization comparison
    const twoWayGas = successfulSwaps.find(r => r.hops === 2)?.gasUsed || 0;
    const targetGas = 180000;
    const optimizationNeeded = ((twoWayGas - targetGas) / twoWayGas * 100).toFixed(2);

    console.log("\n🎯 Gas Optimization Target:");
    console.log(`   Current (2-way):    ${twoWayGas.toLocaleString()} gas`);
    console.log(`   Target:             ${targetGas.toLocaleString()} gas`);
    console.log(`   Reduction Needed:   ${optimizationNeeded}% (${(twoWayGas - targetGas).toLocaleString()} gas)`);

    // Profitability insights
    console.log("\n💡 Profitability Insights:");
    const profitable = successfulSwaps.filter(r => r.netChange >= 0);
    if (profitable.length > 0) {
      console.log(`   ✅ ${profitable.length} profitable path(s) found!`);
      profitable.forEach(r => {
        console.log(`      - ${r.name}: +${r.netChange.toFixed(6)} BASE (${r.profitLossPercent.toFixed(2)}%)`);
      });
    } else {
      console.log(`   ❌ No profitable paths found`);
      console.log(`   📝 All paths show loss due to:`);
      console.log(`      - Trading fees: 0.3% per hop`);
      console.log(`      - Price impact: Slippage from CPMM model`);
      console.log(`      - No arbitrage: All pools have 1:1 price ratio`);
      console.log(`   💡 Profitability requires:`);
      console.log(`      - Price imbalances between pools`);
      console.log(`      - Arbitrage opportunities (e.g., BASE/A cheaper than BASE/B)`);
      console.log(`      - Sufficient price difference to overcome fees + slippage`);
    }
  }

  console.log("\n" + "=".repeat(70));
  console.log("✅ N-WAY SWAP ANALYSIS COMPLETE");
  console.log("=".repeat(70) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Test failed:");
    console.error(error);
    process.exit(1);
  });
