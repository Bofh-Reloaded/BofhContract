const { expect } = require('chai');
const { ethers } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('DEX Adapters Tests', function () {
  async function deployAdaptersFixture() {
    const [owner] = await ethers.getSigners();

    // Deploy mock factory
    const MockFactory = await ethers.getContractFactory('MockFactory');
    const mockFactory = await MockFactory.deploy();
    await mockFactory.waitForDeployment();

    // Deploy mock tokens
    const MockToken = await ethers.getContractFactory('MockToken');
    const tokenA = await MockToken.deploy('Token A', 'TKNA', ethers.parseEther('1000000'));
    await tokenA.waitForDeployment();

    const tokenB = await MockToken.deploy('Token B', 'TKNB', ethers.parseEther('1000000'));
    await tokenB.waitForDeployment();

    const factoryAddr = await mockFactory.getAddress();
    const tokenAAddr = await tokenA.getAddress();
    const tokenBAddr = await tokenB.getAddress();

    // Create a pair
    await mockFactory.createPair(tokenAAddr, tokenBAddr);
    const pairAddr = await mockFactory.getPair(tokenAAddr, tokenBAddr);

    // Deploy adapters
    const PancakeSwapAdapter = await ethers.getContractFactory('PancakeSwapAdapter');
    const pancakeAdapter = await PancakeSwapAdapter.deploy(factoryAddr);
    await pancakeAdapter.waitForDeployment();

    const UniswapV2Adapter = await ethers.getContractFactory('UniswapV2Adapter');
    const uniswapAdapter = await UniswapV2Adapter.deploy(factoryAddr);
    await uniswapAdapter.waitForDeployment();

    // Add liquidity to pair
    await tokenA.transfer(pairAddr, ethers.parseEther('100000'));
    await tokenB.transfer(pairAddr, ethers.parseEther('100000'));

    const MockPair = await ethers.getContractFactory('MockPair');
    const pair = MockPair.attach(pairAddr);
    await pair.sync();

    return {
      pancakeAdapter,
      uniswapAdapter,
      mockFactory,
      tokenA,
      tokenB,
      pair,
      tokenAAddr,
      tokenBAddr,
      pairAddr,
      owner
    };
  }

  describe('PancakeSwapAdapter', function () {
    describe('Deployment', function () {
      it('Should deploy with correct factory address', async function () {
        const { pancakeAdapter, mockFactory } = await loadFixture(deployAdaptersFixture);
        expect(await pancakeAdapter.factory()).to.equal(await mockFactory.getAddress());
      });

      it('Should reject deployment with zero factory address', async function () {
        const PancakeSwapAdapter = await ethers.getContractFactory('PancakeSwapAdapter');
        await expect(
          PancakeSwapAdapter.deploy(ethers.ZeroAddress)
        ).to.be.revertedWith('Invalid factory');
      });
    });

    describe('getPoolAddress', function () {
      it('Should return correct pool address for valid token pair', async function () {
        const { pancakeAdapter, tokenAAddr, tokenBAddr, pairAddr } = await loadFixture(
          deployAdaptersFixture
        );
        const poolAddr = await pancakeAdapter.getPoolAddress(tokenAAddr, tokenBAddr);
        expect(poolAddr).to.equal(pairAddr);
      });

      it('Should revert for zero address tokenA', async function () {
        const { pancakeAdapter, tokenBAddr } = await loadFixture(deployAdaptersFixture);
        await expect(
          pancakeAdapter.getPoolAddress(ethers.ZeroAddress, tokenBAddr)
        ).to.be.revertedWithCustomError(pancakeAdapter, 'InvalidTokens');
      });

      it('Should revert for zero address tokenB', async function () {
        const { pancakeAdapter, tokenAAddr } = await loadFixture(deployAdaptersFixture);
        await expect(
          pancakeAdapter.getPoolAddress(tokenAAddr, ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(pancakeAdapter, 'InvalidTokens');
      });

      it('Should revert when pool does not exist', async function () {
        const { pancakeAdapter } = await loadFixture(deployAdaptersFixture);
        const MockToken = await ethers.getContractFactory('MockToken');
        const tokenC = await MockToken.deploy('Token C', 'TKNC', ethers.parseEther('1000000'));
        await tokenC.waitForDeployment();

        const tokenCAddr = await tokenC.getAddress();
        const randomAddr = ethers.Wallet.createRandom().address;

        await expect(
          pancakeAdapter.getPoolAddress(tokenCAddr, randomAddr)
        ).to.be.revertedWithCustomError(pancakeAdapter, 'PoolNotFound');
      });
    });

    describe('getReserves', function () {
      it('Should return correct reserves for valid pool', async function () {
        const { pancakeAdapter, pairAddr } = await loadFixture(deployAdaptersFixture);
        const [reserve0, reserve1] = await pancakeAdapter.getReserves(pairAddr);

        expect(reserve0).to.equal(ethers.parseEther('100000'));
        expect(reserve1).to.equal(ethers.parseEther('100000'));
      });

      it('Should revert for zero address pool', async function () {
        const { pancakeAdapter } = await loadFixture(deployAdaptersFixture);
        await expect(
          pancakeAdapter.getReserves(ethers.ZeroAddress)
        ).to.be.revertedWithCustomError(pancakeAdapter, 'InvalidTokens');
      });

      it('Should revert for non-existent pool', async function () {
        const { pancakeAdapter } = await loadFixture(deployAdaptersFixture);
        const randomAddr = ethers.Wallet.createRandom().address;
        await expect(
          pancakeAdapter.getReserves(randomAddr)
        ).to.be.reverted; // Will revert when trying to call getReserves on non-contract
      });
    });

    describe('getAmountOut', function () {
      it('Should calculate correct output amount for valid swap', async function () {
        const { pancakeAdapter, pairAddr, tokenAAddr } = await loadFixture(
          deployAdaptersFixture
        );
        const amountIn = ethers.parseEther('1000');

        const amountOut = await pancakeAdapter.getAmountOut(
          pairAddr,
          tokenAAddr,
          amountIn
        );

        // With 0.25% fee: amountOut = (amountIn * 9975 * reserve1) / (reserve0 * 10000 + amountIn * 9975)
        // Approximately: 1000 * 0.9975 * 100000 / (100000 + 1000 * 0.9975) ≈ 985.12
        expect(amountOut).to.be.greaterThan(ethers.parseEther('985'));
        expect(amountOut).to.be.lessThan(ethers.parseEther('990'));
      });

      it('Should return 0 for zero input amount', async function () {
        const { pancakeAdapter, pairAddr, tokenAAddr } = await loadFixture(
          deployAdaptersFixture
        );
        const amountOut = await pancakeAdapter.getAmountOut(pairAddr, tokenAAddr, 0);
        expect(amountOut).to.equal(0);
      });

      it('Should handle large input amounts correctly', async function () {
        const { pancakeAdapter, pairAddr, tokenAAddr } = await loadFixture(
          deployAdaptersFixture
        );
        const largeAmount = ethers.parseEther('50000'); // Half the reserve

        const amountOut = await pancakeAdapter.getAmountOut(
          pairAddr,
          tokenAAddr,
          largeAmount
        );

        // Should still return a value, but with high price impact
        expect(amountOut).to.be.greaterThan(0);
        expect(amountOut).to.be.lessThan(ethers.parseEther('50000')); // Less than input due to slippage
      });
    });

    describe('getFeeBps', function () {
      it('Should return correct fee in basis points', async function () {
        const { pancakeAdapter } = await loadFixture(deployAdaptersFixture);
        const fee = await pancakeAdapter.getFeeBps();
        expect(fee).to.equal(25); // 0.25% = 25 basis points
      });
    });

    describe('getDEXName', function () {
      it('Should return correct DEX name', async function () {
        const { pancakeAdapter } = await loadFixture(deployAdaptersFixture);
        const name = await pancakeAdapter.getDEXName();
        expect(name).to.equal('PancakeSwap V2');
      });
    });
  });

  describe('UniswapV2Adapter', function () {
    describe('Deployment', function () {
      it('Should deploy with correct factory address', async function () {
        const { uniswapAdapter, mockFactory } = await loadFixture(deployAdaptersFixture);
        expect(await uniswapAdapter.factory()).to.equal(await mockFactory.getAddress());
      });

      it('Should reject deployment with zero factory address', async function () {
        const UniswapV2Adapter = await ethers.getContractFactory('UniswapV2Adapter');
        await expect(
          UniswapV2Adapter.deploy(ethers.ZeroAddress)
        ).to.be.revertedWith('Invalid factory');
      });
    });

    describe('getPoolAddress', function () {
      it('Should return correct pool address for valid token pair', async function () {
        const { uniswapAdapter, tokenAAddr, tokenBAddr, pairAddr } = await loadFixture(
          deployAdaptersFixture
        );
        const poolAddr = await uniswapAdapter.getPoolAddress(tokenAAddr, tokenBAddr);
        expect(poolAddr).to.equal(pairAddr);
      });

      it('Should revert for zero address tokens', async function () {
        const { uniswapAdapter, tokenBAddr } = await loadFixture(deployAdaptersFixture);
        await expect(
          uniswapAdapter.getPoolAddress(ethers.ZeroAddress, tokenBAddr)
        ).to.be.revertedWithCustomError(uniswapAdapter, 'InvalidTokens');
      });

      it('Should revert when pool does not exist', async function () {
        const { uniswapAdapter } = await loadFixture(deployAdaptersFixture);
        const randomAddr1 = ethers.Wallet.createRandom().address;
        const randomAddr2 = ethers.Wallet.createRandom().address;

        await expect(
          uniswapAdapter.getPoolAddress(randomAddr1, randomAddr2)
        ).to.be.revertedWithCustomError(uniswapAdapter, 'PoolNotFound');
      });
    });

    describe('getFeeBps', function () {
      it('Should return correct fee in basis points', async function () {
        const { uniswapAdapter } = await loadFixture(deployAdaptersFixture);
        const fee = await uniswapAdapter.getFeeBps();
        expect(fee).to.equal(30); // 0.3% = 30 basis points
      });
    });

    describe('getDEXName', function () {
      it('Should return correct DEX name', async function () {
        const { uniswapAdapter } = await loadFixture(deployAdaptersFixture);
        const name = await uniswapAdapter.getDEXName();
        expect(name).to.equal('Uniswap V2');
      });
    });

    describe('Integration - Comparing adapters', function () {
      it('PancakeSwap should have lower fee than Uniswap', async function () {
        const { pancakeAdapter, uniswapAdapter } = await loadFixture(deployAdaptersFixture);
        const pancakeFee = await pancakeAdapter.getFeeBps();
        const uniswapFee = await uniswapAdapter.getFeeBps();
        expect(pancakeFee).to.be.lessThan(uniswapFee); // 25 < 30
      });

      it('Both adapters should return same pool address for same token pair', async function () {
        const { pancakeAdapter, uniswapAdapter, tokenAAddr, tokenBAddr } = await loadFixture(
          deployAdaptersFixture
        );
        const pancakePool = await pancakeAdapter.getPoolAddress(tokenAAddr, tokenBAddr);
        const uniswapPool = await uniswapAdapter.getPoolAddress(tokenAAddr, tokenBAddr);
        expect(pancakePool).to.equal(uniswapPool); // Same factory, same pair
      });
    });
  });
});
