const BofhContractV2 = artifacts.require('BofhContractV2');
const MockToken = artifacts.require('MockToken');
const MockFactory = artifacts.require('MockFactory');
const MockPair = artifacts.require('MockPair');

const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

contract('BofhContractV2', function (accounts) {
    const [owner, user1, user2] = accounts;
    const PRECISION = new BN('1000000'); // 1e6
    
    beforeEach(async function () {
        // Deploy mock tokens
        this.baseToken = await MockToken.new('Base Token', 'BASE', new BN('1000000000000000000000000'));
        this.tokenA = await MockToken.new('Token A', 'TKNA', new BN('1000000000000000000000000'));
        this.tokenB = await MockToken.new('Token B', 'TKNB', new BN('1000000000000000000000000'));
        this.tokenC = await MockToken.new('Token C', 'TKNC', new BN('1000000000000000000000000'));
        
        // Deploy factory and create pairs
        this.factory = await MockFactory.new();
        
        await this.factory.createPair(this.baseToken.address, this.tokenA.address);
        await this.factory.createPair(this.baseToken.address, this.tokenB.address);
        await this.factory.createPair(this.tokenA.address, this.tokenB.address);
        await this.factory.createPair(this.tokenB.address, this.tokenC.address);
        
        // Get pair addresses
        this.pairAB = await this.factory.getPair(this.tokenA.address, this.tokenB.address);
        this.pairBC = await this.factory.getPair(this.tokenB.address, this.tokenC.address);
        this.pairBaseA = await this.factory.getPair(this.baseToken.address, this.tokenA.address);
        this.pairBaseB = await this.factory.getPair(this.baseToken.address, this.tokenB.address);
        
        // Deploy BofhContract
        this.bofh = await BofhContractV2.new(this.baseToken.address);
        
        // Add initial liquidity to pairs
        const liquidityAmount = new BN('1000000000000000000000'); // 1000 tokens
        
        // Approve tokens for liquidity
        await this.baseToken.approve(this.pairBaseA, liquidityAmount);
        await this.tokenA.approve(this.pairBaseA, liquidityAmount);
        await this.baseToken.approve(this.pairBaseB, liquidityAmount);
        await this.tokenB.approve(this.pairBaseB, liquidityAmount);
        await this.tokenA.approve(this.pairAB, liquidityAmount);
        await this.tokenB.approve(this.pairAB, liquidityAmount);
        await this.tokenB.approve(this.pairBC, liquidityAmount);
        await this.tokenC.approve(this.pairBC, liquidityAmount);
        
        // Add liquidity to pairs
        await Promise.all([
            MockPair.at(this.pairBaseA).then(pair => pair.mint(owner)),
            MockPair.at(this.pairBaseB).then(pair => pair.mint(owner)),
            MockPair.at(this.pairAB).then(pair => pair.mint(owner)),
            MockPair.at(this.pairBC).then(pair => pair.mint(owner))
        ]);
    });
    
    describe('Basic functionality', function () {
        it('should be owned by deployer', async function () {
            expect(await this.bofh.getAdmin()).to.equal(owner);
        });
        
        it('should have correct base token', async function () {
            expect(await this.bofh.getBaseToken()).to.equal(this.baseToken.address);
        });
    });
    
    describe('Risk management', function () {
        it('should allow owner to update risk parameters', async function () {
            const tx = await this.bofh.updateRiskParams(
                new BN('2000000000000000000000'), // 2000 max volume
                new BN('100000000000000000'),     // 0.1 min liquidity
                new BN('100000'),                 // 10% max impact
                new BN('50')                      // 0.5% sandwich protection
            );
            
            expectEvent(tx, 'RiskParamsUpdated');
        });
        
        it('should reject invalid risk parameters', async function () {
            await expectRevert(
                this.bofh.updateRiskParams(
                    0,
                    0,
                    PRECISION.add(new BN('1')), // > 100% impact
                    new BN('1000')              // 10% protection (too high)
                ),
                'Price impact too high'
            );
        });
    });
    
    describe('Swap execution', function () {
        beforeEach(async function () {
            // Approve tokens for swapping
            const swapAmount = new BN('1000000000000000000'); // 1 token
            await this.baseToken.approve(this.bofh.address, swapAmount);
        });
        
        it('should execute a simple swap', async function () {
            const amount = new BN('1000000000000000000'); // 1 token
            const minOut = new BN('900000000000000000');  // 0.9 tokens
            const deadline = (await web3.eth.getBlock('latest')).timestamp + 300;
            
            const path = [
                this.baseToken.address,
                this.tokenA.address,
                this.baseToken.address
            ];
            
            const fees = [
                new BN('3000'), // 0.3%
                new BN('3000')  // 0.3%
            ];
            
            const balanceBefore = await this.baseToken.balanceOf(user1);
            
            const tx = await this.bofh.executeSwap(
                path,
                fees,
                amount,
                minOut,
                deadline,
                { from: user1 }
            );
            
            const balanceAfter = await this.baseToken.balanceOf(user1);
            expect(balanceAfter.sub(balanceBefore)).to.be.bignumber.gt(minOut);
            
            expectEvent(tx, 'SwapExecuted');
        });
        
        it('should execute multi-path swaps', async function () {
            const amounts = [
                new BN('1000000000000000000'), // 1 token
                new BN('1000000000000000000')  // 1 token
            ];
            
            const minAmounts = [
                new BN('900000000000000000'), // 0.9 tokens
                new BN('900000000000000000')  // 0.9 tokens
            ];
            
            const deadline = (await web3.eth.getBlock('latest')).timestamp + 300;
            
            const paths = [
                [
                    this.baseToken.address,
                    this.tokenA.address,
                    this.baseToken.address
                ],
                [
                    this.baseToken.address,
                    this.tokenB.address,
                    this.baseToken.address
                ]
            ];
            
            const fees = [
                [new BN('3000'), new BN('3000')],
                [new BN('3000'), new BN('3000')]
            ];
            
            const tx = await this.bofh.executeMultiSwap(
                paths,
                fees,
                amounts,
                minAmounts,
                deadline,
                { from: user1 }
            );
            
            expectEvent(tx, 'SwapExecuted');
        });
    });
    
    describe('Path optimization', function () {
        it('should calculate optimal path metrics', async function () {
            const path = [
                this.baseToken.address,
                this.tokenA.address,
                this.tokenB.address,
                this.baseToken.address
            ];
            
            const amounts = [
                new BN('1000000000000000000') // 1 token
            ];
            
            const [expectedOutput, priceImpact, optimalityScore] = 
                await this.bofh.getOptimalPathMetrics(path, amounts);
            
            expect(expectedOutput).to.be.bignumber.gt('0');
            expect(priceImpact).to.be.bignumber.lt(PRECISION);
            expect(optimalityScore).to.be.bignumber.gt(PRECISION.div(new BN('2'))); // > 50%
        });
    });
});