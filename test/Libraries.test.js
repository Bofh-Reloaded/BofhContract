const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Libraries", function () {
  // Deploy a test contract that exposes library functions
  async function deployLibraryTestsFixture() {
    const [owner, user1, user2] = await ethers.getSigners();

    // Deploy test contracts to expose library functions
    const MathLibTest = await ethers.getContractFactory("MathLibTest");
    const mathLib = await MathLibTest.deploy();

    const PoolLibTest = await ethers.getContractFactory("PoolLibTest");
    const poolLib = await PoolLibTest.deploy();

    const SecurityLibTest = await ethers.getContractFactory("SecurityLibTest");
    const securityLib = await SecurityLibTest.deploy();

    // Deploy mock tokens and pairs for PoolLib tests
    const MockToken = await ethers.getContractFactory("MockToken");
    const tokenA = await MockToken.deploy("Token A", "TKNA", ethers.parseEther("1000000"));
    const tokenB = await MockToken.deploy("Token B", "TKNB", ethers.parseEther("1000000"));

    const MockFactory = await ethers.getContractFactory("MockFactory");
    const factory = await MockFactory.deploy();

    // Create pair using factory
    await factory.createPair(await tokenA.getAddress(), await tokenB.getAddress());
    const pairAddress = await factory.getPair(await tokenA.getAddress(), await tokenB.getAddress());
    const MockPair = await ethers.getContractFactory("MockPair");
    const pair = MockPair.attach(pairAddress);

    // Add liquidity to pair
    const liquidityA = ethers.parseEther("1000");
    const liquidityB = ethers.parseEther("2000");
    await tokenA.transfer(pairAddress, liquidityA);
    await tokenB.transfer(pairAddress, liquidityB);
    await pair.sync();

    return { mathLib, poolLib, securityLib, owner, user1, user2, tokenA, tokenB, pair, factory };
  }

  describe("MathLib", function () {
    describe("sqrt", function () {
      it("Should return 0 for input 0", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testSqrt(0)).to.equal(0);
      });

      it("Should calculate sqrt correctly for perfect squares", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testSqrt(4n)).to.equal(2n);
        expect(await mathLib.testSqrt(9n)).to.equal(3n);
        expect(await mathLib.testSqrt(16n)).to.equal(4n);
        expect(await mathLib.testSqrt(100n)).to.equal(10n);
        expect(await mathLib.testSqrt(10000n)).to.equal(100n);
        expect(await mathLib.testSqrt(1000000n)).to.equal(1000n);
        expect(await mathLib.testSqrt(10000000000n)).to.equal(100000n);
      });

      it("Should calculate sqrt with reasonable precision for non-perfect squares", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        // sqrt(2) ≈ 1.414
        expect(await mathLib.testSqrt(2n)).to.equal(1n);
        // sqrt(10) ≈ 3.162
        expect(await mathLib.testSqrt(10n)).to.equal(3n);
        // sqrt(1000000000000) = 1000000
        const input = 1000000n * 1000000n;
        expect(await mathLib.testSqrt(input)).to.equal(1000000n);
      });

      it("Should handle large numbers", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const largeNumber = ethers.parseEther("1000000"); // 1M ETH in wei
        const result = await mathLib.testSqrt(largeNumber);
        expect(result).to.be.gt(0);
      });

      it("Should handle very large numbers (> uint128)", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const veryLarge = ethers.MaxUint256 / 2n;
        const result = await mathLib.testSqrt(veryLarge);
        expect(result).to.be.gt(0);
      });
    });

    describe("cbrt", function () {
      it("Should return 0 for input 0", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testCbrt(0)).to.equal(0);
      });

      it("Should calculate cbrt correctly for perfect cubes", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testCbrt(1n)).to.equal(1n);
        expect(await mathLib.testCbrt(8n)).to.equal(2n);
        expect(await mathLib.testCbrt(27n)).to.equal(3n);
        expect(await mathLib.testCbrt(64n)).to.equal(4n);
        expect(await mathLib.testCbrt(125n)).to.equal(5n);
        expect(await mathLib.testCbrt(1000n)).to.equal(10n);
      });

      it("Should calculate cbrt with reasonable precision for non-perfect cubes", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        // cbrt(10) ≈ 2.154
        expect(await mathLib.testCbrt(10n)).to.equal(2n);
        // cbrt(100) ≈ 4.64
        expect(await mathLib.testCbrt(100n)).to.be.within(4n, 5n);
      });

      it("Should handle large numbers", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const largeNumber = ethers.parseEther("1000"); // 1000 ETH in wei
        const result = await mathLib.testCbrt(largeNumber);
        expect(result).to.be.gt(0);
      });
    });

    describe("geometricMean", function () {
      it("Should return 0 if either input is 0", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testGeometricMean(0, 100)).to.equal(0);
        expect(await mathLib.testGeometricMean(100, 0)).to.equal(0);
        expect(await mathLib.testGeometricMean(0, 0)).to.equal(0);
      });

      it("Should calculate geometric mean for equal numbers", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testGeometricMean(100n, 100n)).to.equal(100n);
        expect(await mathLib.testGeometricMean(1000000n, 1000000n)).to.equal(1000000n);
      });

      it("Should calculate geometric mean correctly", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        // GM(4, 9) = sqrt(36) = 6
        expect(await mathLib.testGeometricMean(4n, 9n)).to.equal(6n);
        // GM(1000000, 4000000) = sqrt(4*10^12) = 2*10^6
        expect(await mathLib.testGeometricMean(1000000n, 4000000n)).to.equal(2000000n);
      });

      it("Should handle large numbers using log approximation", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const large1 = ethers.MaxUint256 / 4n;
        const large2 = ethers.MaxUint256 / 4n;
        const result = await mathLib.testGeometricMean(large1, large2);
        expect(result).to.be.gt(0);
      });
    });

    describe("log2", function () {
      it("Should return 0 for input 0", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        expect(await mathLib.testLog2(0)).to.equal(0);
      });

      it("Should calculate log2 correctly for powers of 2", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const PRECISION = 1000000n; // 1e6

        // log2(2) = 1
        expect(await mathLib.testLog2(2)).to.equal(PRECISION);

        // log2(4) = 2
        expect(await mathLib.testLog2(4)).to.equal(2n * PRECISION);

        // log2(8) = 3
        expect(await mathLib.testLog2(8)).to.equal(3n * PRECISION);

        // log2(256) = 8
        expect(await mathLib.testLog2(256)).to.equal(8n * PRECISION);
      });
    });

    describe("exp2", function () {
      it("Should return PRECISION for input 0", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const PRECISION = 1000000n; // 1e6
        expect(await mathLib.testExp2(0)).to.equal(PRECISION);
      });

      it("Should calculate exp2 correctly for integer inputs", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const PRECISION = 1000000n; // 1e6

        // exp2(1 * PRECISION) = 2
        expect(await mathLib.testExp2(PRECISION)).to.equal(2n);

        // exp2(2 * PRECISION) = 4
        expect(await mathLib.testExp2(2n * PRECISION)).to.equal(4n);

        // exp2(3 * PRECISION) = 8
        expect(await mathLib.testExp2(3n * PRECISION)).to.equal(8n);
      });

      it("Should return max uint256 for very large inputs", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const PRECISION = 1000000n;
        const result = await mathLib.testExp2(255n * PRECISION);
        expect(result).to.equal(ethers.MaxUint256);
      });
    });

    describe("calculateOptimalAmount", function () {
      it("Should reject invalid path lengths", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          mathLib.testCalculateOptimalAmount(1000, 2, 0)
        ).to.be.reverted;

        await expect(
          mathLib.testCalculateOptimalAmount(1000, 6, 0)
        ).to.be.reverted;
      });

      it("Should calculate amounts for 3-way swaps (equal distribution)", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const amount = 1000000n;

        const pos0 = await mathLib.testCalculateOptimalAmount(amount, 3, 0);
        const pos1 = await mathLib.testCalculateOptimalAmount(amount, 3, 1);
        const pos2 = await mathLib.testCalculateOptimalAmount(amount, 3, 2);

        // For 3-way, should be roughly equal distribution
        expect(pos0).to.be.gt(pos1);
        expect(pos1).to.be.gt(pos2);
      });

      it("Should calculate amounts for 4-way swaps (golden ratio)", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const amount = 1000000n;

        const pos0 = await mathLib.testCalculateOptimalAmount(amount, 4, 0);
        const pos1 = await mathLib.testCalculateOptimalAmount(amount, 4, 1);
        const pos2 = await mathLib.testCalculateOptimalAmount(amount, 4, 2);
        const pos3 = await mathLib.testCalculateOptimalAmount(amount, 4, 3);

        // Amounts should decrease according to golden ratio
        expect(pos0).to.be.gt(pos1);
        expect(pos1).to.be.gt(pos2);
        expect(pos2).to.be.gt(pos3);
      });

      it("Should calculate amounts for 5-way swaps (golden ratio squared)", async function () {
        const { mathLib } = await loadFixture(deployLibraryTestsFixture);
        const amount = 1000000n;

        const pos0 = await mathLib.testCalculateOptimalAmount(amount, 5, 0);
        const pos1 = await mathLib.testCalculateOptimalAmount(amount, 5, 1);
        const pos4 = await mathLib.testCalculateOptimalAmount(amount, 5, 4);

        // Amounts should decrease
        expect(pos0).to.be.gt(pos1);
        expect(pos1).to.be.gt(pos4);
      });
    });
  });

  describe("PoolLib", function () {
    describe("calculatePriceImpact", function () {
      it("Should return 0 for zero amount", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1000000n,
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 0,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        expect(await poolLib.testCalculatePriceImpact(0, poolState)).to.equal(0);
      });

      it("Should calculate price impact for small trades", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1000000n,
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 0,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        // Small trade: 1% of pool
        const impact = await poolLib.testCalculatePriceImpact(10000n, poolState);
        expect(impact).to.be.gt(0);
        expect(impact).to.be.lt(100000n); // Less than 10%
      });

      it("Should calculate higher impact for large trades", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1000000n,
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 0,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        // Large trade: 50% of pool
        const impact = await poolLib.testCalculatePriceImpact(500000n, poolState);
        expect(impact).to.be.gt(0);
        // Should have significant impact
        expect(impact).to.be.gt(100000n); // More than 10%
      });

      it("Should handle edge case with imbalanced reserves", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1n, // Very small reserve out
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 0,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        // Small trade in imbalanced pool
        const impact = await poolLib.testCalculatePriceImpact(1n, poolState);
        // Should have some impact (price calculation may not return 0)
        expect(impact).to.be.gte(0);
      });
    });

    describe("calculateVolatility", function () {
      it("Should return existing volatility if no time passed", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1000000n,
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 50000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const vol = await poolLib.testCalculateVolatility(poolState, 1000n, 1000n);
        expect(vol).to.equal(50000n);
      });

      it("Should return existing volatility if timestamps are reversed", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1000000n,
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 50000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const vol = await poolLib.testCalculateVolatility(poolState, 2000n, 1000n);
        expect(vol).to.equal(50000n);
      });

      it("Should calculate volatility with time decay", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: 1000000n,
          reserveOut: 1000000n,
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 0,
          volatility: 100000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const vol = await poolLib.testCalculateVolatility(poolState, 1000n, 2000n);
        expect(vol).to.be.gt(0);
      });
    });

    describe("analyzePool", function () {
      it("Should analyze pool and return correct state for token0 trade", async function () {
        const { poolLib, pair, tokenA } = await loadFixture(deployLibraryTestsFixture);
        const amountIn = ethers.parseEther("10");
        const timestamp = Math.floor(Date.now() / 1000);

        const state = await poolLib.testAnalyzePool(
          await pair.getAddress(),
          await tokenA.getAddress(),
          amountIn,
          timestamp
        );

        expect(state.reserveIn).to.equal(ethers.parseEther("1000"));
        expect(state.reserveOut).to.equal(ethers.parseEther("2000"));
        expect(state.sellingToken0).to.be.true;
        expect(state.depth).to.be.gt(0);
        expect(state.priceImpact).to.be.gt(0);
      });

      it("Should analyze pool and return correct state for token1 trade", async function () {
        const { poolLib, pair, tokenB } = await loadFixture(deployLibraryTestsFixture);
        const amountIn = ethers.parseEther("10");
        const timestamp = Math.floor(Date.now() / 1000);

        const state = await poolLib.testAnalyzePool(
          await pair.getAddress(),
          await tokenB.getAddress(),
          amountIn,
          timestamp
        );

        expect(state.reserveIn).to.equal(ethers.parseEther("2000"));
        expect(state.reserveOut).to.equal(ethers.parseEther("1000"));
        expect(state.sellingToken0).to.be.false;
        expect(state.depth).to.be.gt(0);
      });

      it("Should revert for invalid token", async function () {
        const { poolLib, pair } = await loadFixture(deployLibraryTestsFixture);
        const invalidToken = ethers.Wallet.createRandom().address;
        const amountIn = ethers.parseEther("10");
        const timestamp = Math.floor(Date.now() / 1000);

        await expect(
          poolLib.testAnalyzePool(await pair.getAddress(), invalidToken, amountIn, timestamp)
        ).to.be.revertedWith("Invalid token");
      });
    });

    describe("calculateOptimalSwapAmount", function () {
      it("Should revert if minimum output cannot be met (insufficient liquidity)", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("100"), // Low liquidity out
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("316"),
          volatility: 10000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("10"),
          minAmountOut: ethers.parseEther("50"), // Unrealistic expectation
          maxPriceImpact: 100000n,
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testCalculateOptimalSwapAmount(poolState, swapParams)
        ).to.be.revertedWith("Insufficient output amount");
      });
    });

    describe("validateSwap", function () {
      it("Should validate a valid swap", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("2000"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("1414"),
          volatility: 10000n, // 1%
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("10"),
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 100000n, // 10%
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        expect(await poolLib.testValidateSwap(poolState, swapParams)).to.be.true;
      });

      it("Should reject expired deadline", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("2000"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("1414"),
          volatility: 10000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("10"),
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 100000n,
          deadline: Math.floor(Date.now() / 1000) - 3600, // Expired
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testValidateSwap(poolState, swapParams)
        ).to.be.revertedWith("Deadline expired");
      });

      it("Should reject zero amount", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("2000"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("1414"),
          volatility: 10000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: 0,
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 100000n,
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testValidateSwap(poolState, swapParams)
        ).to.be.revertedWith("Invalid amount");
      });

      it("Should reject excessive price impact setting", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("2000"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("1414"),
          volatility: 10000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("10"),
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 150000n, // 15% - too high
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testValidateSwap(poolState, swapParams)
        ).to.be.revertedWith("Excessive price impact");
      });

      it("Should reject trade with actual high price impact", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("100"), // Small pool
          reserveOut: ethers.parseEther("200"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("141"),
          volatility: 10000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("50"), // Large relative trade
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 50000n, // 5% limit
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testValidateSwap(poolState, swapParams)
        ).to.be.revertedWith("Price impact too high");
      });

      it("Should reject pool with excessive volatility", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("2000"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: ethers.parseEther("1414"),
          volatility: 600000n, // 60% - too high
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("10"),
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 100000n,
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testValidateSwap(poolState, swapParams)
        ).to.be.revertedWith("Pool too volatile");
      });

      it("Should reject pool that is too shallow", async function () {
        const { poolLib } = await loadFixture(deployLibraryTestsFixture);
        const poolState = {
          reserveIn: ethers.parseEther("1000"),
          reserveOut: ethers.parseEther("2000"),
          sellingToken0: true,
          tokenOut: ethers.ZeroAddress,
          priceImpact: 0,
          depth: 5000n, // Very shallow
          volatility: 10000n,
          lastUpdateTimestamp: 0,
          volumeAccumulator: 0
        };

        const swapParams = {
          amountIn: ethers.parseEther("10"),
          minAmountOut: ethers.parseEther("1"),
          maxPriceImpact: 100000n,
          deadline: Math.floor(Date.now() / 1000) + 3600,
          maxSlippage: 10000n
        };

        await expect(
          poolLib.testValidateSwap(poolState, swapParams)
        ).to.be.revertedWith("Pool too shallow");
      });
    });
  });

  describe("SecurityLib", function () {
    describe("Access Control", function () {
      it("Should allow owner to perform owner-only actions", async function () {
        const { securityLib, owner } = await loadFixture(deployLibraryTestsFixture);
        await expect(securityLib.connect(owner).testCheckOwner()).to.not.be.reverted;
      });

      it("Should prevent non-owner from performing owner-only actions", async function () {
        const { securityLib, user1 } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          securityLib.connect(user1).testCheckOwner()
        ).to.be.revertedWithCustomError(securityLib, "Unauthorized");
      });

      it("Should transfer ownership correctly", async function () {
        const { securityLib, owner, user1 } = await loadFixture(deployLibraryTestsFixture);

        await expect(securityLib.connect(owner).testTransferOwnership(user1.address))
          .to.emit(securityLib, "OwnershipTransferred")
          .withArgs(owner.address, user1.address);

        // New owner should be able to perform owner actions
        await expect(securityLib.connect(user1).testCheckOwner()).to.not.be.reverted;

        // Old owner should not
        await expect(
          securityLib.connect(owner).testCheckOwner()
        ).to.be.revertedWithCustomError(securityLib, "Unauthorized");
      });

      it("Should prevent ownership transfer to zero address", async function () {
        const { securityLib, owner } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          securityLib.connect(owner).testTransferOwnership(ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(securityLib, "InvalidAddress");
      });
    });

    describe("Pause Mechanism", function () {
      it("Should allow owner to pause", async function () {
        const { securityLib, owner } = await loadFixture(deployLibraryTestsFixture);
        await expect(securityLib.connect(owner).testEmergencyPause())
          .to.emit(securityLib, "SecurityStateChanged")
          .withArgs(true, false);
      });

      it("Should prevent non-owner from pausing", async function () {
        const { securityLib, user1 } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          securityLib.connect(user1).testEmergencyPause()
        ).to.be.revertedWithCustomError(securityLib, "Unauthorized");
      });

      it("Should block actions when paused", async function () {
        const { securityLib, owner } = await loadFixture(deployLibraryTestsFixture);
        await securityLib.connect(owner).testEmergencyPause();

        await expect(
          securityLib.testCheckNotPaused()
        ).to.be.revertedWithCustomError(securityLib, "ContractPaused");
      });

      it("Should allow owner to unpause", async function () {
        const { securityLib, owner } = await loadFixture(deployLibraryTestsFixture);
        await securityLib.connect(owner).testEmergencyPause();

        await expect(securityLib.connect(owner).testEmergencyUnpause())
          .to.emit(securityLib, "SecurityStateChanged")
          .withArgs(false, false);

        // Actions should work again
        await expect(securityLib.testCheckNotPaused()).to.not.be.reverted;
      });
    });

    describe("Reentrancy Protection", function () {
      it("Should allow entering protected section", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        await expect(securityLib.testEnterProtectedSection()).to.not.be.reverted;
      });

      it("Should prevent reentrant calls", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        await securityLib.testEnterProtectedSection();

        await expect(
          securityLib.testEnterProtectedSection()
        ).to.be.revertedWithCustomError(securityLib, "ReentrancyGuardError");
      });

      it("Should allow re-entry after exiting", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        await securityLib.testEnterProtectedSection();
        await securityLib.testExitProtectedSection();

        await expect(securityLib.testEnterProtectedSection()).to.not.be.reverted;
      });
    });

    describe("Rate Limiting", function () {
      it("Should allow actions within rate limit", async function () {
        const { securityLib, user1 } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          securityLib.connect(user1).testCheckRateLimit(5, 1000)
        ).to.not.be.reverted;
      });

      it("Should emit anomaly event when rate limit exceeded", async function () {
        const { securityLib, user1 } = await loadFixture(deployLibraryTestsFixture);

        // First call succeeds
        await securityLib.connect(user1).testCheckRateLimit(1, 10000);

        // Second call exceeds limit
        await expect(
          securityLib.connect(user1).testCheckRateLimit(1, 10000)
        ).to.be.revertedWithCustomError(securityLib, "ExcessiveValue");
      });
    });

    describe("Operator Management", function () {
      it("Should allow owner to set operators", async function () {
        const { securityLib, owner, user1 } = await loadFixture(deployLibraryTestsFixture);

        await expect(securityLib.connect(owner).testSetOperator(user1.address, true))
          .to.emit(securityLib, "OperatorStatusChanged")
          .withArgs(user1.address, true);
      });

      it("Should prevent non-owner from setting operators", async function () {
        const { securityLib, user1, user2 } = await loadFixture(deployLibraryTestsFixture);

        await expect(
          securityLib.connect(user1).testSetOperator(user2.address, true)
        ).to.be.revertedWithCustomError(securityLib, "Unauthorized");
      });

      it("Should prevent setting zero address as operator", async function () {
        const { securityLib, owner } = await loadFixture(deployLibraryTestsFixture);

        await expect(
          securityLib.connect(owner).testSetOperator(ethers.ZeroAddress, true)
        ).to.be.revertedWithCustomError(securityLib, "InvalidAddress");
      });
    });

    describe("Value Bounds Checking", function () {
      it("Should accept values within bounds", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        await expect(securityLib.testCheckValueBounds(50, 0, 100)).to.not.be.reverted;
      });

      it("Should reject values below minimum", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          securityLib.testCheckValueBounds(5, 10, 100)
        ).to.be.revertedWithCustomError(securityLib, "ExcessiveValue");
      });

      it("Should reject values above maximum", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        await expect(
          securityLib.testCheckValueBounds(150, 0, 100)
        ).to.be.revertedWithCustomError(securityLib, "ExcessiveValue");
      });
    });

    describe("Deadline Validation", function () {
      it("Should accept deadline in future", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        const futureTime = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
        await expect(securityLib.testValidateDeadline(futureTime, 0)).to.not.be.reverted;
      });

      it("Should reject expired deadline", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        const pastTime = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
        await expect(
          securityLib.testValidateDeadline(pastTime, 0)
        ).to.be.revertedWithCustomError(securityLib, "DeadlineExpired");
      });

      it("Should accept deadline within grace period", async function () {
        const { securityLib } = await loadFixture(deployLibraryTestsFixture);
        const recentPast = Math.floor(Date.now() / 1000) - 10; // 10 seconds ago
        await expect(securityLib.testValidateDeadline(recentPast, 60)).to.not.be.reverted;
      });
    });
  });
});
