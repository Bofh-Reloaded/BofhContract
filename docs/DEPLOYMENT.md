# BofhContract Deployment Guide

## Table of Contents
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Local Development Deployment](#local-development-deployment)
- [BSC Testnet Deployment](#bsc-testnet-deployment)
- [BSC Mainnet Deployment](#bsc-mainnet-deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software
- **Node.js** >= 16.x
- **npm** >= 8.x
- **Hardhat** >= 2.27.0
- **Git**

### Required Accounts and Keys
1. **Wallet with funds**:
   - Testnet: Get BNB from [BSC Testnet Faucet](https://testnet.binance.org/faucet-smart)
   - Mainnet: Minimum 0.1 BNB for deployment gas fees

2. **BSCScan API Key**:
   - Get from [BSCScan](https://bscscan.com/apis)
   - Required for contract verification

3. **Mnemonic Phrase**:
   - 12 or 24-word recovery phrase for deployment wallet
   - **CRITICAL**: Never commit this to version control

## Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/your-org/BofhContract.git
cd BofhContract
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure Environment

Create `env.json` in project root (this file is gitignored):
```json
{
  "mnemonic": "your twelve or twenty four word mnemonic phrase here",
  "BSCSCANAPIKEY": "YOUR_BSCSCAN_API_KEY_HERE"
}
```

**Security Note**: Never commit `env.json`. It's already in `.gitignore`.

### 4. Verify Configuration
```bash
# Compile contracts
npm run compile

# Run tests
npm test

# Generate coverage report
npm run coverage
```

## Local Development Deployment

### Using Hardhat Local Network

1. **Start Local Node**:
```bash
npx hardhat node
```
This starts a local Ethereum network at `http://127.0.0.1:8545/`.

2. **Deploy to Local Network** (in separate terminal):
```bash
npx hardhat run scripts/deploy.js --network localhost
```

3. **Interact with Local Contract**:
```javascript
// In Hardhat console
npx hardhat console --network localhost

const BofhContractV2 = await ethers.getContractFactory("BofhContractV2");
const bofh = await BofhContractV2.attach("DEPLOYED_ADDRESS");
console.log("Base Token:", await bofh.getBaseToken());
```

## BSC Testnet Deployment

### Network Details
- **Chain ID**: 97
- **RPC URL**: https://data-seed-prebsc-1-s1.binance.org:8545
- **Explorer**: https://testnet.bscscan.com
- **Faucet**: https://testnet.binance.org/faucet-smart

### Deployment Steps

#### 1. Update Deployment Script

Edit `scripts/deploy.js` with testnet addresses:
```javascript
// BSC Testnet addresses
const BASE_TOKEN = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"; // WBNB Testnet
const FACTORY = "0x6725F303b657a9451d8BA641348b6761A6CC7a17"; // PancakeSwap V2 Factory Testnet
```

#### 2. Deploy Contract
```bash
npm run deploy:testnet
# or
npx hardhat run scripts/deploy.js --network bscTestnet
```

Expected output:
```
Deploying BofhContractV2...
BofhContractV2 deployed to: 0x1234...
Base Token: 0xae13...
Factory: 0x6725...
Deployment gas used: ~2,500,000
```

#### 3. Save Deployment Address
Create `deployments/bsc-testnet.json`:
```json
{
  "network": "bsc-testnet",
  "chainId": 97,
  "contracts": {
    "BofhContractV2": {
      "address": "0x...",
      "deployer": "0x...",
      "deploymentBlock": 12345678,
      "deploymentTx": "0x...",
      "timestamp": "2025-01-15T10:30:00Z"
    }
  },
  "configuration": {
    "baseToken": "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
    "factory": "0x6725F303b657a9451d8BA641348b6761A6CC7a17"
  }
}
```

#### 4. Verify Contract on BSCScan
```bash
npx hardhat verify --network bscTestnet DEPLOYED_ADDRESS \
  "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd" \
  "0x6725F303b657a9451d8BA641348b6761A6CC7a17"
```

Successful verification output:
```
Successfully submitted source code for contract
contracts/main/BofhContractV2.sol:BofhContractV2 at 0x...
for verification on the block explorer. Waiting for verification result...

Successfully verified contract BofhContractV2 on Etherscan.
https://testnet.bscscan.com/address/0x...#code
```

## BSC Mainnet Deployment

**⚠️ WARNING: Mainnet deployment involves real funds. Triple-check all parameters.**

### Pre-Deployment Checklist

- [ ] All tests passing (100% pass rate)
- [ ] Coverage > 90% on production code
- [ ] Security audit completed (if required)
- [ ] Testnet deployment tested thoroughly
- [ ] All parameters validated
- [ ] Deployment wallet has sufficient BNB (~0.1 BNB)
- [ ] Backup of mnemonic phrase stored securely
- [ ] Emergency pause procedures documented
- [ ] Multisig or Timelock for ownership (recommended)

### Network Details
- **Chain ID**: 56
- **RPC URL**: https://bsc-dataseed1.binance.org
- **Explorer**: https://bscscan.com
- **Gas Price**: Check current price at https://bscscan.com/gastracker

### Deployment Steps

#### 1. Update Deployment Script

Edit `scripts/deploy.js` with mainnet addresses:
```javascript
// BSC Mainnet addresses
const BASE_TOKEN = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"; // WBNB Mainnet
const FACTORY = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"; // PancakeSwap V2 Factory Mainnet
```

#### 2. Enable Mainnet in Config

Uncomment mainnet configuration in `hardhat.config.js`:
```javascript
bscMainnet: {
  url: "https://bsc-dataseed1.binance.org",
  chainId: 56,
  accounts: {
    mnemonic: mnemonic
  },
  gasPrice: 5000000000, // 5 gwei - adjust based on network conditions
  confirmations: 10
}
```

#### 3. Deploy to Mainnet
```bash
npx hardhat run scripts/deploy.js --network bscMainnet
```

#### 4. Verify Contract
```bash
npx hardhat verify --network bscMainnet DEPLOYED_ADDRESS \
  "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c" \
  "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
```

#### 5. Save Mainnet Deployment
Create `deployments/bsc-mainnet.json` with deployment details.

## Post-Deployment Configuration

### 1. Configure Risk Parameters

Connect to deployed contract and set initial parameters:

```javascript
const bofh = await ethers.getContractAt("BofhContractV2", DEPLOYED_ADDRESS);

// Update risk parameters
await bofh.updateRiskParams(
  ethers.parseEther("1000"),  // maxTradeVolume: 1000 tokens
  ethers.parseEther("100"),   // minPoolLiquidity: 100 tokens
  BigInt(100000),             // maxPriceImpact: 10% (PRECISION/10)
  BigInt(50)                  // sandwichProtectionBips: 0.5%
);
```

### 2. Enable MEV Protection (Optional)

```javascript
await bofh.configureMEVProtection(
  true,  // enabled
  3,     // maxTxPerBlock
  12     // minTxDelay (seconds)
);
```

### 3. Set Up Operators (Optional)

Grant operator permissions to trusted addresses:

```javascript
await bofh.setOperator(
  "0xOperatorAddress",
  true  // grant operator status
);
```

### 4. Blacklist Malicious Pools (If Needed)

```javascript
await bofh.setPoolBlacklist(
  "0xMaliciousPoolAddress",
  true  // blacklist
);
```

### 5. Transfer Ownership to Multisig (Recommended for Mainnet)

```javascript
// Transfer to Gnosis Safe or other multisig
await bofh.transferOwnership("0xMultisigAddress");
```

## Verification

### 1. Verify Contract State

```javascript
const bofh = await ethers.getContractAt("BofhContractV2", DEPLOYED_ADDRESS);

console.log("Base Token:", await bofh.getBaseToken());
console.log("Factory:", await bofh.getFactory());
console.log("Owner:", await bofh.getAdmin());
console.log("Is Paused:", await bofh.isPaused());

const [maxVol, minLiq, maxImpact, sandwich] = await bofh.getRiskParameters();
console.log("Risk Parameters:", {
  maxTradeVolume: maxVol.toString(),
  minPoolLiquidity: minLiq.toString(),
  maxPriceImpact: maxImpact.toString(),
  sandwichProtectionBips: sandwich.toString()
});

const [enabled, maxTx, minDelay] = await bofh.getMEVProtectionConfig();
console.log("MEV Protection:", {
  enabled,
  maxTxPerBlock: maxTx.toString(),
  minTxDelay: minDelay.toString()
});
```

### 2. Test Swap Execution

**Testnet only** - execute a small test swap:

```javascript
// Approve base token
const baseToken = await ethers.getContractAt("IBEP20", BASE_TOKEN);
await baseToken.approve(DEPLOYED_ADDRESS, ethers.MaxUint256);

// Execute test swap
const path = [BASE_TOKEN, TOKEN_A, BASE_TOKEN];
const fees = [3000, 3000]; // 0.3% fees
const amountIn = ethers.parseEther("0.01");
const minAmountOut = ethers.parseEther("0.009");
const deadline = Math.floor(Date.now() / 1000) + 3600;

const tx = await bofh.executeSwap(path, fees, amountIn, minAmountOut, deadline);
const receipt = await tx.wait();
console.log("Swap executed:", receipt.hash);
```

### 3. Monitor Events

```javascript
// Listen for SwapExecuted events
bofh.on("SwapExecuted", (initiator, pathLength, inputAmount, outputAmount, priceImpact) => {
  console.log("Swap executed:", {
    initiator,
    pathLength: pathLength.toString(),
    inputAmount: inputAmount.toString(),
    outputAmount: outputAmount.toString(),
    priceImpact: priceImpact.toString()
  });
});
```

## Troubleshooting

### Common Issues

#### 1. "Insufficient funds for gas"
**Solution**: Ensure deployment wallet has enough BNB:
- Testnet: Use faucet to get test BNB
- Mainnet: Transfer at least 0.1 BNB to deployment wallet

#### 2. "Nonce too high"
**Solution**: Reset nonce in MetaMask or:
```bash
npx hardhat clean
rm -rf cache artifacts
npx hardhat compile
```

#### 3. "Contract verification failed"
**Causes**:
- Incorrect constructor arguments
- Source code doesn't match deployed bytecode
- Optimization settings mismatch

**Solution**: Ensure constructor args match deployment:
```bash
npx hardhat verify --network bscTestnet \
  --constructor-args scripts/verify-args.js \
  DEPLOYED_ADDRESS
```

#### 4. "Transaction underpriced"
**Solution**: Increase gas price in `hardhat.config.js`:
```javascript
gasPrice: 10000000000, // 10 gwei
```

#### 5. "Pair does not exist"
**Cause**: Invalid token pair or factory address
**Solution**: Verify factory address and ensure pair exists:
```javascript
const factory = await ethers.getContractAt("IFactory", FACTORY_ADDRESS);
const pair = await factory.getPair(TOKEN_A, TOKEN_B);
console.log("Pair address:", pair);
```

### Gas Estimation

Typical gas costs on BSC:
- **Contract Deployment**: ~2,500,000 gas (~0.0125 BNB @ 5 gwei)
- **executeSwap (3-hop)**: ~200,000 gas (~0.001 BNB @ 5 gwei)
- **executeMultiSwap (2 paths)**: ~350,000 gas (~0.00175 BNB @ 5 gwei)
- **Configuration updates**: ~50,000 gas (~0.00025 BNB @ 5 gwei)

### Emergency Procedures

#### Pause Contract
```javascript
await bofh.emergencyPause();
console.log("Contract paused:", await bofh.isPaused());
```

#### Unpause Contract
```javascript
await bofh.emergencyUnpause();
console.log("Contract paused:", await bofh.isPaused());
```

#### Transfer Ownership (Emergency)
```javascript
await bofh.transferOwnership(NEW_OWNER_ADDRESS);
console.log("New owner:", await bofh.getAdmin());
```

## Best Practices

### Security
1. **Never commit sensitive data** (mnemonic, private keys)
2. **Use hardware wallet** for mainnet deployments
3. **Implement timelock** for critical parameter changes
4. **Set up monitoring** for unusual activity
5. **Audit before mainnet** deployment
6. **Use multisig wallet** for contract ownership
7. **Test thoroughly** on testnet before mainnet

### Operational
1. **Document all deployments** in `deployments/` directory
2. **Tag releases** in git with deployment addresses
3. **Monitor gas prices** before deploying
4. **Keep backup** of deployment scripts and artifacts
5. **Set up alerts** for contract events
6. **Maintain deployment diary** with timestamps and decisions

### Upgrade Strategy
BofhContract is **not upgradeable** by design for security. For upgrades:
1. Deploy new contract version
2. Pause old contract
3. Migrate liquidity to new contract
4. Update frontend to point to new contract
5. Keep old contract paused for emergency recovery

## Additional Resources

- [Hardhat Documentation](https://hardhat.org/getting-started/)
- [BSC Documentation](https://docs.binance.org/smart-chain/developer/deploy/hardhat.html)
- [PancakeSwap Documentation](https://docs.pancakeswap.finance/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Ethers.js Documentation](https://docs.ethers.org/)

## Support

For deployment issues:
1. Check [GitHub Issues](https://github.com/your-org/BofhContract/issues)
2. Review [CLAUDE.md](../CLAUDE.md) for development guidelines
3. Consult [ARCHITECTURE.md](./ARCHITECTURE.md) for system design
4. Review [SECURITY.md](./SECURITY.md) for security considerations
