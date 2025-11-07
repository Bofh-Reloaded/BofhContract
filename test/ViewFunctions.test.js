const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("View Functions Tests", function () {
  async function deployContractsFixture() {
    const [owner, user1] = await ethers.getSigners();

    // Deploy mock tokens
    const MockToken = await ethers.getContractFactory("MockToken");
    const baseToken = await MockToken.deploy("Base Token", "BASE", ethers.parseEther("1000000"));
    const tokenA = await MockToken.deploy("Token A", "TKNA", ethers.parseEther("1000000"));
    const tokenB = await MockToken.deploy("Token B", "TKNB", ethers.parseEther("1000000"));
    const tokenC = await MockToken.deploy("Token C", "TKNC", ethers.parseEther("1000000"));

    // Deploy factory
    const MockFactory = await ethers.getContractFactory("MockFactory");
    const factory = await MockFactory.deploy();

    // Create pairs
    await factory.createPair(await baseToken.getAddress(), await tokenA.getAddress());
    await factory.createPair(await tokenA.getAddress(), await tokenB.getAddress());
    await factory.createPair(await tokenB.getAddress(), await tokenC.getAddress());
    await factory.createPair(await baseToken.getAddress(), await tokenB.getAddress());

    const pairBaseA = await factory.getPair(await baseToken.getAddress(), await tokenA.getAddress());
    const pairAB = await factory.getPair(await tokenA.getAddress(), await tokenB.getAddress());
    const pairBC = await factory.getPair(await tokenB.getAddress(), await tokenC.getAddress());
    const pairBaseB = await factory.getPair(await baseToken.getAddress(), await tokenB.getAddress());

    const MockPair = await ethers.getContractFactory("MockPair");
    const pairBaseAContract = MockPair.attach(pairBaseA);
    const pairABContract = MockPair.attach(pairAB);
    const pairBCContract = MockPair.attach(pairBC);
    const pairBaseBContract = MockPair.attach(pairBaseB);

    // Add liquidity
    const liquidityBase = ethers.parseEther("10000");
    const liquidityOther = ethers.parseEther("5000");

    await baseToken.transfer(pairBaseA, liquidityBase);
    await tokenA.transfer(pairBaseA, liquidityOther);
    await pairBaseAContract.sync();

    await tokenA.transfer(pairAB, liquidityOther);
    await tokenB.transfer(pairAB, liquidityOther);
    await pairABContract.sync();

    await tokenB.transfer(pairBC, liquidityOther);
    await tokenC.transfer(pairBC, liquidityOther);
    await pairBCContract.sync();

    await baseToken.transfer(pairBaseB, liquidityBase);
    await tokenB.transfer(pairBaseB, liquidityOther);
    await pairBaseBContract.sync();

    // Deploy BofhContractV2
    const BofhContractV2 = await ethers.getContractFactory("BofhContractV2");
    const bofh = await BofhContractV2.deploy(
      await baseToken.getAddress(),
      await factory.getAddress()
    );

    return {
      bofh,
      baseToken,
      tokenA,
      tokenB,
      tokenC,
      factory,
      owner,
      user1
    };
  }

  describe("getOptimalPathMetrics", function () {
    it("Should calculate metrics for 2-token path", async function () {
      const { bofh, baseToken, tokenA } = await loadFixture(deployContractsFixture);

      const path = [await baseToken.getAddress(), await tokenA.getAddress()];
      const amounts = [ethers.parseEther("10")];

      const [expectedOutput, priceImpact, optimalityScore] = await bofh.getOptimalPathMetrics(path, amounts);

      expect(expectedOutput).to.be.gt(0);
      expect(priceImpact).to.be.gt(0);
      expect(optimalityScore).to.be.gt(0);
      expect(optimalityScore).to.be.lte(ethers.parseUnits("1", 6)); // ≤ 100%
    });

    it("Should calculate metrics for 3-token path", async function () {
      const { bofh, baseToken, tokenA, tokenB } = await loadFixture(deployContractsFixture);

      const path = [
        await baseToken.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress()
      ];
      const amounts = [ethers.parseEther("10")];

      const [expectedOutput, priceImpact, optimalityScore] = await bofh.getOptimalPathMetrics(path, amounts);

      expect(expectedOutput).to.be.gt(0);
      expect(priceImpact).to.be.gt(0);
      expect(optimalityScore).to.be.gt(0);
    });

    it("Should calculate metrics for 4-token path", async function () {
      const { bofh, baseToken, tokenA, tokenB, tokenC } = await loadFixture(deployContractsFixture);

      const path = [
        await baseToken.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        await tokenC.getAddress()
      ];
      const amounts = [ethers.parseEther("10")];

      const [expectedOutput, priceImpact, optimalityScore] = await bofh.getOptimalPathMetrics(path, amounts);

      expect(expectedOutput).to.be.gt(0);
      expect(priceImpact).to.be.gt(0);
      expect(optimalityScore).to.be.gt(0);
    });

    it("Should show higher price impact for larger amounts", async function () {
      const { bofh, baseToken, tokenA } = await loadFixture(deployContractsFixture);

      const path = [await baseToken.getAddress(), await tokenA.getAddress()];

      const smallAmount = [ethers.parseEther("1")];
      const largeAmount = [ethers.parseEther("100")];

      const [, smallImpact] = await bofh.getOptimalPathMetrics(path, smallAmount);
      const [, largeImpact] = await bofh.getOptimalPathMetrics(path, largeAmount);

      expect(largeImpact).to.be.gt(smallImpact);
    });

    it("Should show cumulative price impact increases with path length", async function () {
      const { bofh, baseToken, tokenA, tokenB } = await loadFixture(deployContractsFixture);

      const shortPath = [await baseToken.getAddress(), await tokenA.getAddress()];
      const longPath = [
        await baseToken.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress()
      ];
      const amounts = [ethers.parseEther("10")];

      const [, shortImpact] = await bofh.getOptimalPathMetrics(shortPath, amounts);
      const [, longImpact] = await bofh.getOptimalPathMetrics(longPath, amounts);

      expect(longImpact).to.be.gt(shortImpact);
    });

    it("Should calculate optimality score correctly", async function () {
      const { bofh, baseToken, tokenA } = await loadFixture(deployContractsFixture);

      const path = [await baseToken.getAddress(), await tokenA.getAddress()];
      const amounts = [ethers.parseEther("10")];

      const [expectedOutput, , optimalityScore] = await bofh.getOptimalPathMetrics(path, amounts);

      // Optimality score should be (output / input) * PRECISION
      const PRECISION = 1000000n;
      const expectedScore = (expectedOutput * PRECISION) / amounts[0];

      expect(optimalityScore).to.equal(expectedScore);
    });

    it("Should reject path with length < 2", async function () {
      const { bofh, baseToken } = await loadFixture(deployContractsFixture);

      const path = [await baseToken.getAddress()];
      const amounts = [ethers.parseEther("10")];

      await expect(
        bofh.getOptimalPathMetrics(path, amounts)
      ).to.be.revertedWith("Invalid path length");
    });

    it("Should reject path with length > MAX_PATH_LENGTH", async function () {
      const { bofh, baseToken, tokenA, tokenB, tokenC } = await loadFixture(deployContractsFixture);

      // Create a path with 7 tokens (exceeds MAX_PATH_LENGTH = 6)
      const path = [
        await baseToken.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        await tokenC.getAddress(),
        await baseToken.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress()
      ];
      const amounts = [ethers.parseEther("10")];

      await expect(
        bofh.getOptimalPathMetrics(path, amounts)
      ).to.be.revertedWith("Invalid path length");
    });

    it("Should handle maximum valid path length", async function () {
      const { bofh, baseToken, tokenA, tokenB } = await loadFixture(deployContractsFixture);

      // 6 tokens = MAX_PATH_LENGTH = 6
      // Path: BASE → A → B → A → B → A (uses only existing pairs)
      const path = [
        await baseToken.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        await tokenA.getAddress()
      ];
      const amounts = [ethers.parseEther("0.1")]; // Small amount to avoid excessive slippage

      const [expectedOutput, priceImpact, optimalityScore] = await bofh.getOptimalPathMetrics(path, amounts);

      expect(expectedOutput).to.be.gt(0);
      expect(priceImpact).to.be.gt(0);
      expect(optimalityScore).to.be.gt(0);
    });
  });

  describe("getBaseToken", function () {
    it("Should return correct base token address", async function () {
      const { bofh, baseToken } = await loadFixture(deployContractsFixture);

      const returnedBaseToken = await bofh.getBaseToken();

      expect(returnedBaseToken).to.equal(await baseToken.getAddress());
    });
  });

  describe("getFactory", function () {
    it("Should return correct factory address", async function () {
      const { bofh, factory } = await loadFixture(deployContractsFixture);

      const returnedFactory = await bofh.getFactory();

      expect(returnedFactory).to.equal(await factory.getAddress());
    });
  });
});
