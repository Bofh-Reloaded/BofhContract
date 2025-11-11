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

/**
 * Simulates realistic market scenarios with price imbalances
 * In real markets, different DEXs/pools have different prices due to:
 * 1. Different liquidity depths
 * 2. Recent large trades
 * 3. Different trading volumes
 * 4. Geographic/temporal arbitrage delays
 */
async function createMarketImbalance(pairs, tokens, scenario) {
  console.log(`\n🎭 Setting up market scenario: ${scenario.name}`);
  console.log(`   Description: ${scenario.description}\n`);

  const MockPair = await ethers.getContractFactory('MockPair');

  for (const pool of scenario.pools) {
    const pair = MockPair.attach(pairs[pool.name]);
    const token0 = tokens[pool.token0];
    const token1 = tokens[pool.token1];

    // Add imbalanced liquidity
    await token0.transfer(pair, ethers.parseEther(pool.amount0));
    await token1.transfer(pair, ethers.parseEther(pool.amount1));
    await pair.sync();

    const price = pool.amount1 / pool.amount0;
    console.log(`   📊 ${pool.name}: ${pool.amount0.toLocaleString()} ${pool.token0} / ${pool.amount1.toLocaleString()} ${pool.token1}`);
    console.log(`      Price: 1 ${pool.token0} = ${price.toFixed(4)} ${pool.token1}`);
  }
}

/**
 * Calculates expected output for a swap path using CPMM formula
 */
function calculateExpectedOutput(path, amounts, fees) {
  let currentAmount = amounts[0];

  for (let i = 0; i < path.length - 1; i++) {
    const reserveIn = amounts[path[i]];
    const reserveOut = amounts[path[i + 1]];
    const fee = fees[i];

    // CPMM formula: amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
    const amountInWithFee = currentAmount * (1000 - fee);
    const numerator = amountInWithFee * reserveOut;
    const denominator = (reserveIn * 1000) + amountInWithFee;
    currentAmount = Math.floor(numerator / denominator);
  }

  return currentAmount;
}

/**
 * Finds arbitrage opportunities by testing all possible paths
 */
async function findArbitrageOpportunities(bofh, deployment, pairs, tokens) {
  console.log("\n" + "=".repeat(70));
  console.log("🔍 SCANNING FOR ARBITRAGE OPPORTUNITIES");
  console.log("=".repeat(70) + "\n");

  const baseToken = tokens.BASE;
  const testAmount = ethers.parseEther("1000");
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  const minAmountOut = ethers.parseEther("1");

  // Define potential arbitrage paths
  const arbitragePaths = [
    {
      name: "2-Way: BASE → TKNA → BASE",
      path: ['BASE', 'TKNA', 'BASE'],
      fees: [3, 3]
    },
    {
      name: "3-Way: BASE → TKNA → TKNB → BASE",
      path: ['BASE', 'TKNA', 'TKNB', 'BASE'],
      fees: [3, 3, 3]
    },
    {
      name: "3-Way: BASE → TKNB → TKNA → BASE",
      path: ['BASE', 'TKNB', 'TKNA', 'BASE'],
      fees: [3, 3, 3]
    },
    {
      name: "4-Way: BASE → TKNA → TKNB → TKNA → BASE",
      path: ['BASE', 'TKNA', 'TKNB', 'TKNA', 'BASE'],
      fees: [3, 3, 3, 3]
    },
    {
      name: "4-Way: BASE → TKNB → TKNA → TKNB → BASE",
      path: ['BASE', 'TKNB', 'TKNA', 'TKNB', 'BASE'],
      fees: [3, 3, 3, 3]
    }
  ];

  const opportunities = [];

  for (const pathDef of arbitragePaths) {
    try {
      // Convert token names to addresses
      const path = pathDef.path.map(name => deployment.mocks.tokens[name]);

      const balanceBefore = await baseToken.balanceOf((await ethers.getSigners())[0].address);

      const tx = await bofh.executeSwap(
        path,
        pathDef.fees,
        testAmount,
        minAmountOut,
        deadline
      );

      const receipt = await tx.wait();
      const balanceAfter = await baseToken.balanceOf((await ethers.getSigners())[0].address);

      const netChange = balanceAfter - balanceBefore;
      const netChangeEth = parseFloat(ethers.formatEther(netChange));
      const inputEth = parseFloat(ethers.formatEther(testAmount));
      const profitPercent = ((netChangeEth / inputEth) * 100);
      const isProfitable = netChangeEth > 0;

      const result = {
        name: pathDef.name,
        path: pathDef.path,
        input: inputEth,
        output: parseFloat(ethers.formatEther(balanceAfter - balanceBefore + testAmount)),
        netChange: netChangeEth,
        profitPercent: profitPercent,
        gasUsed: parseInt(receipt.gasUsed.toString()),
        isProfitable: isProfitable
      };

      opportunities.push(result);

      const icon = isProfitable ? "✅💰" : "❌";
      const changeStr = netChangeEth >= 0 ? `+${netChangeEth.toFixed(6)}` : netChangeEth.toFixed(6);

      console.log(`${icon} ${pathDef.name}`);
      console.log(`   Input:  ${inputEth.toFixed(2)} BASE`);
      console.log(`   Output: ${result.output.toFixed(2)} BASE`);
      console.log(`   Net:    ${changeStr} BASE (${profitPercent >= 0 ? '+' : ''}${profitPercent.toFixed(4)}%)`);
      console.log(`   Gas:    ${result.gasUsed.toLocaleString()}`);

      if (isProfitable) {
        const gasCostBNB = (result.gasUsed * 5) / 1e9; // 5 gwei gas price
        const bnbPrice = 600; // $600 per BNB
        const gasCostUSD = gasCostBNB * bnbPrice;
        const profitUSD = netChangeEth * bnbPrice; // Assuming BASE = BNB
        const netProfitUSD = profitUSD - gasCostUSD;

        console.log(`   💵 Profit: $${profitUSD.toFixed(2)} - Gas: $${gasCostUSD.toFixed(2)} = Net: $${netProfitUSD.toFixed(2)}`);
      }
      console.log();

    } catch (error) {
      console.log(`❌ ${pathDef.name}: Failed - ${error.message.split('\n')[0]}\n`);
    }
  }

  return opportunities;
}

/**
 * Main function
 */
async function main() {
  const networkName = hre.network.name;
  console.log("\n" + "=".repeat(70));
  console.log("🎯 REAL MARKET ARBITRAGE OPPORTUNITY FINDER");
  console.log("=".repeat(70));

  const deployment = loadDeployment(networkName);
  const [deployer] = await ethers.getSigners();

  console.log(`\n📊 Configuration:`);
  console.log(`   Network: ${networkName}`);
  console.log(`   Trader: ${deployer.address}`);
  console.log(`   BofhContract: ${deployment.contracts.BofhContractV2}`);

  // Get contracts
  const bofh = await ethers.getContractAt('BofhContractV2', deployment.contracts.BofhContractV2);
  const factory = await ethers.getContractAt('MockFactory', deployment.mocks.factory);
  const MockPair = await ethers.getContractFactory('MockPair');

  const tokens = {
    BASE: await ethers.getContractAt('MockToken', deployment.mocks.tokens.BASE),
    TKNA: await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNA),
    TKNB: await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNB),
    TKNC: await ethers.getContractAt('MockToken', deployment.mocks.tokens.TKNC)
  };

  // Get pair addresses
  const pairs = {
    'BASE-TKNA': await factory.getPair(deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNA),
    'BASE-TKNB': await factory.getPair(deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNB),
    'BASE-TKNC': await factory.getPair(deployment.mocks.tokens.BASE, deployment.mocks.tokens.TKNC),
    'TKNA-TKNB': await factory.getPair(deployment.mocks.tokens.TKNA, deployment.mocks.tokens.TKNB)
  };

  // Approve spending
  const approvalAmount = ethers.parseEther("1000000");
  await tokens.BASE.approve(deployment.contracts.BofhContractV2, approvalAmount);

  // ============================================
  // SCENARIO 1: Recent Large Trade (Price Dislocation)
  // ============================================
  const scenario1 = {
    name: "Recent Large Trade",
    description: "Someone just dumped TKNA, making it cheap vs BASE",
    pools: [
      { name: 'BASE-TKNA', token0: 'BASE', token1: 'TKNA', amount0: '90000', amount1: '120000' }, // TKNA cheap!
      { name: 'BASE-TKNB', token0: 'BASE', token1: 'TKNB', amount0: '100000', amount1: '100000' },
      { name: 'TKNA-TKNB', token0: 'TKNA', token1: 'TKNB', amount0: '100000', amount1: '100000' }
    ]
  };

  await createMarketImbalance(pairs, tokens, scenario1);
  const opportunities1 = await findArbitrageOpportunities(bofh, deployment, pairs, tokens);

  // ============================================
  // SCENARIO 2: Cross-Pool Arbitrage
  // ============================================
  console.log("\n" + "=".repeat(70));
  console.log("🔄 RESETTING FOR NEW SCENARIO");
  console.log("=".repeat(70));

  // Kill and restart node for fresh state
  console.log("\n⚠️  To test multiple scenarios, restart the Hardhat node and redeploy");
  console.log("    Then run this script again with different scenario parameters\n");

  // ============================================
  // SUMMARY & ANALYSIS
  // ============================================
  console.log("=".repeat(70));
  console.log("📈 ARBITRAGE OPPORTUNITY SUMMARY");
  console.log("=".repeat(70) + "\n");

  const profitable = opportunities1.filter(o => o.isProfitable);

  if (profitable.length > 0) {
    console.log(`✅ Found ${profitable.length} profitable arbitrage opportunities!\n`);

    console.log("┌─────────────────────────────────────┬──────────────┬──────────────┬───────────┐");
    console.log("│ Path                                │ Net Profit   │ Profit %     │ Gas Used  │");
    console.log("├─────────────────────────────────────┼──────────────┼──────────────┼───────────┤");

    profitable.sort((a, b) => b.profitPercent - a.profitPercent).forEach(opp => {
      const pathCol = opp.name.padEnd(35);
      const profitCol = `+${opp.netChange.toFixed(2)} BASE`.padStart(12);
      const percentCol = `+${opp.profitPercent.toFixed(4)}%`.padStart(12);
      const gasCol = opp.gasUsed.toLocaleString().padStart(9);

      console.log(`│ ${pathCol} │ ${profitCol} │ ${percentCol} │ ${gasCol} │`);
    });

    console.log("└─────────────────────────────────────┴──────────────┴──────────────┴───────────┘");

    const bestOpp = profitable[0];
    console.log(`\n🏆 Best Opportunity: ${bestOpp.name}`);
    console.log(`   Profit: +${bestOpp.netChange.toFixed(6)} BASE (+${bestOpp.profitPercent.toFixed(4)}%)`);
    console.log(`   Strategy: ${bestOpp.path.join(' → ')}`);

  } else {
    console.log("❌ No profitable opportunities found in current market conditions\n");
  }

  // ============================================
  // HOW TO FIND REAL ARBITRAGE
  // ============================================
  console.log("\n" + "=".repeat(70));
  console.log("💡 HOW TO FIND REAL ARBITRAGE OPPORTUNITIES");
  console.log("=".repeat(70) + "\n");

  console.log("1️⃣  MONITOR MULTIPLE DEXs (Real-time Price Feeds)");
  console.log("   • PancakeSwap V2/V3");
  console.log("   • Biswap");
  console.log("   • ApeSwap");
  console.log("   • BakerySwap");
  console.log("   • Use: Web3.js/Ethers.js to query reserves\n");

  console.log("2️⃣  CALCULATE PRICE DIFFERENCES");
  console.log("   • Query: pair.getReserves() for each pool");
  console.log("   • Calculate: price = reserve1 / reserve0");
  console.log("   • Compare: prices across different DEXs");
  console.log("   • Alert: when difference > (fees + slippage + gas)\n");

  console.log("3️⃣  EXAMPLE: Price Monitoring Bot (Pseudocode)");
  console.log(`
   const pancakePrice = await getPairPrice(pancakePair);
   const biswapPrice = await getPairPrice(biswapPair);

   const priceDiff = Math.abs(pancakePrice - biswapPrice);
   const minProfitThreshold = 0.01; // 1%

   if (priceDiff > minProfitThreshold) {
     const profitablePath = findBestPath(prices);
     await executeTrade(profitablePath);
   }
  `);

  console.log("4️⃣  TOOLS & SERVICES");
  console.log("   • Dune Analytics: Track DEX volumes");
  console.log("   • DexScreener: Real-time price charts");
  console.log("   • The Graph: Query historical data");
  console.log("   • Chainlink Oracles: Price feeds");
  console.log("   • Flashbots: MEV protection\n");

  console.log("5️⃣  EXECUTION STRATEGIES");
  console.log("   • Mempool Monitoring: Watch for large pending trades");
  console.log("   • Flash Loans: Maximize capital efficiency");
  console.log("   • Gas Optimization: Minimize transaction costs");
  console.log("   • MEV Protection: Use private relayers (Flashbots)\n");

  console.log("6️⃣  RISK MANAGEMENT");
  console.log("   • Slippage Protection: Set appropriate minAmountOut");
  console.log("   • Gas Price Limits: Don't overpay for execution");
  console.log("   • Position Sizing: Start small, scale gradually");
  console.log("   • Monitoring: Alert on failed transactions\n");

  console.log("=".repeat(70));
  console.log("✅ ARBITRAGE OPPORTUNITY FINDER COMPLETE");
  console.log("=".repeat(70) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Error:");
    console.error(error);
    process.exit(1);
  });
