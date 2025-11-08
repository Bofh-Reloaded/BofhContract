# BofhContract Upgradeability Strategy

Comprehensive guide for implementing contract upgradeability using proxy patterns.

## Current Status

**BofhContractV2 is NOT upgradeable** - Uses standard deployment pattern with immutable code.

## Why Upgradeability?

### Benefits
- **Bug fixes** - Fix critical bugs without redeployment
- **Feature additions** - Add new functionality post-deployment
- **Parameter updates** - Modify constants and limits
- **Security patches** - Respond to vulnerabilities quickly
- **Gradual migration** - No need to migrate all users at once

### Trade-offs
- **Increased complexity** - More moving parts and potential failure modes
- **Gas overhead** - Proxy adds ~2-3k gas per call
- **Centralization concerns** - Admin can upgrade (mitigate with timelock/multisig)
- **Storage layout constraints** - Must maintain compatibility

## Upgrade Pattern Comparison

### 1. Transparent Proxy Pattern ⭐ RECOMMENDED

**Pros:**
- Battle-tested (OpenZeppelin standard)
- Clear separation between admin and users
- Admin calls go to proxy, user calls go to implementation
- Well-documented and audited

**Cons:**
- Higher deployment gas cost
- Slightly more complex than UUPS

**Best for:** Production systems requiring maximum security

### 2. UUPS (Universal Upgradeable Proxy Standard)

**Pros:**
- Lower deployment gas cost
- Upgrade logic in implementation (not proxy)
- Cheaper proxy deployment

**Cons:**
- Risk of bricking if upgrade function removed
- Less battle-tested than Transparent

**Best for:** Cost-sensitive deployments with expert teams

### 3. Diamond Pattern (EIP-2535)

**Pros:**
- Unlimited contract size (bypass 24KB limit)
- Granular upgrades (replace individual functions)
- Multiple facets for modularity

**Cons:**
- Most complex pattern
- Overkill for most projects
- Harder to audit

**Best for:** Very large, modular systems

## Recommended Approach: Transparent Proxy

### Architecture

```
User → TransparentUpgradeableProxy → BofhContractV2 (Implementation)
         ↓                              ↑
      ProxyAdmin                    (upgradeTo)
```

### Implementation Steps

#### Step 1: Install Dependencies

```bash
npm install @openzeppelin/contracts-upgradeable@4.9.6
npm install @openzeppelin/hardhat-upgrades
```

#### Step 2: Create Upgradeable Contract

**contracts/upgradeable/BofhContractV2Upgradeable.sol:**

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../main/BofhContractBase.sol";

/// @title BofhContractV2Upgradeable
/// @notice Upgradeable version of BofhContractV2
/// @custom:oz-upgrades-from BofhContractV2
contract BofhContractV2Upgradeable is
    Initializable,
    UUPSUpgradeable,
    BofhContractBase
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract (replaces constructor)
    /// @param baseToken_ Base token address
    /// @param factory_ Factory address
    function initialize(
        address baseToken_,
        address factory_,
        address owner_
    ) public initializer {
        __UUPSUpgradeable_init();

        // Initialize base contract state
        baseToken = baseToken_;
        factory = factory_;
        securityState.owner = owner_;

        // Initialize risk parameters
        maxTradeVolume = 1000 * PRECISION;
        minPoolLiquidity = 100 * PRECISION;
        maxPriceImpact = PRECISION / 10;
        sandwichProtectionBips = 50;
    }

    /// @notice Authorize upgrade (only owner)
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
```

#### Step 3: Deployment Script

**scripts/deploy-upgradeable.js:**

```javascript
const { ethers, upgrades } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying upgradeable BofhContract...');
  console.log('Deployer:', deployer.address);

  // Get contract factory
  const BofhContract = await ethers.getContractFactory('BofhContractV2Upgradeable');

  // Deploy proxy + implementation
  const proxy = await upgrades.deployProxy(
    BofhContract,
    [baseToken, factory, deployer.address], // initializer args
    {
      kind: 'uups',
      initializer: 'initialize'
    }
  );

  await proxy.deployed();

  console.log('Proxy deployed to:', proxy.address);
  console.log('Implementation deployed to:', await upgrades.erc1967.getImplementationAddress(proxy.address));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

#### Step 4: Upgrade Script

**scripts/upgrade.js:**

```javascript
const { ethers, upgrades } = require('hardhat');

async function main() {
  const proxyAddress = process.env.PROXY_ADDRESS;

  console.log('Upgrading BofhContract at:', proxyAddress);

  // Get V3 factory
  const BofhContractV3 = await ethers.getContractFactory('BofhContractV3Upgradeable');

  // Upgrade proxy to V3
  const upgraded = await upgrades.upgradeProxy(proxyAddress, BofhContractV3);

  console.log('Upgraded successfully');
  console.log('New implementation:', await upgrades.erc1967.getImplementationAddress(proxyAddress));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

## Storage Layout Management

### Critical Rules

1. **Never reorder variables** - Slots must stay consistent
2. **Never change variable types** - Breaks storage reading
3. **Never insert variables in middle** - Shifts all following slots
4. **Only append new variables** - Add at end of contract
5. **Never delete variables** - Leave as deprecated, don't remove

### Current BofhContractV2 Storage Layout

```solidity
// Slot 0 (inherited from BofhContractBase)
SecurityLib.SecurityState internal securityState;

// Slot 1
uint256 internal constant PRECISION = 1e6;  // Not stored (constant)

// Slot 2
uint256 internal constant MAX_SLIPPAGE = PRECISION / 100;  // Not stored

// Slot 3
uint256 internal constant MIN_OPTIMALITY = PRECISION / 2;  // Not stored

// Slot 4
uint256 internal constant MAX_PATH_LENGTH = 6;  // Not stored

// Slot 5
mapping(address => bool) public blacklistedPools;

// Slot 6
uint256 public maxTradeVolume;

// Slot 7
uint256 public minPoolLiquidity;

// Slot 8
uint256 public maxPriceImpact;

// Slot 9
uint256 public sandwichProtectionBips;

// Slot 10
mapping(address => RateLimitState) private rateLimits;

// Slot 11
bool public mevProtectionEnabled;

// Slot 12
uint256 public maxTxPerBlock;

// Slot 13
uint256 public minTxDelay;

// Slot 14 (BofhContractV2)
address private immutable baseToken;  // Immutables stored in code, not storage

// Slot 15
address private immutable factory;  // Immutables stored in code, not storage
```

### Adding New Variables (V3)

```solidity
contract BofhContractV3Upgradeable is BofhContractV2Upgradeable {
    // ✅ CORRECT - Add at end
    uint256 public newFeature;          // New slot
    mapping(address => uint256) public userScores;  // New slot

    // ❌ WRONG - Never do this
    // uint256 public inserted;  // Would shift all following slots!
}
```

### Validate Storage Layout

**scripts/validate-storage.js:**

```javascript
const { ethers, upgrades } = require('hardhat');

async function main() {
  const V2 = await ethers.getContractFactory('BofhContractV2Upgradeable');
  const V3 = await ethers.getContractFactory('BofhContractV3Upgradeable');

  // Validate upgrade is safe
  await upgrades.validateUpgrade(V2, V3, {
    kind: 'uups'
  });

  console.log('✓ Storage layout is compatible');
}

main().catch(console.error);
```

## Testing Upgrades

### Test Suite Structure

```javascript
const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');

describe('BofhContract Upgrades', () => {
  let proxy, v2, v3;
  let owner, user;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();

    // Deploy V2
    const V2 = await ethers.getContractFactory('BofhContractV2Upgradeable');
    proxy = await upgrades.deployProxy(V2, [baseToken, factory, owner.address]);
    v2 = await ethers.getContractAt('BofhContractV2Upgradeable', proxy.address);
  });

  it('should preserve state after upgrade', async () => {
    // Set state in V2
    await v2.updateRiskParams(5000, 200, 50000, 25);
    const beforeVolume = await v2.maxTradeVolume();

    // Upgrade to V3
    const V3 = await ethers.getContractFactory('BofhContractV3Upgradeable');
    await upgrades.upgradeProxy(proxy.address, V3);
    v3 = await ethers.getContractAt('BofhContractV3Upgradeable', proxy.address);

    // Verify state preserved
    const afterVolume = await v3.maxTradeVolume();
    expect(afterVolume).to.equal(beforeVolume);
  });

  it('should have new functionality in V3', async () => {
    // Upgrade to V3
    const V3 = await ethers.getContractFactory('BofhContractV3Upgradeable');
    await upgrades.upgradeProxy(proxy.address, V3);
    v3 = await ethers.getContractAt('BofhContractV3Upgradeable', proxy.address);

    // Test new V3 function
    await v3.newV3Function();
    expect(await v3.newFeature()).to.equal(expectedValue);
  });

  it('should prevent unauthorized upgrades', async () => {
    const V3 = await ethers.getContractFactory('BofhContractV3Upgradeable');
    const newImpl = await V3.deploy();

    // Non-owner cannot upgrade
    await expect(
      v2.connect(user).upgradeTo(newImpl.address)
    ).to.be.revertedWith('Unauthorized');
  });
});
```

## Security Considerations

### 1. Use Timelock for Upgrades

```solidity
import "@openzeppelin/contracts/governance/TimelockController.sol";

// Deploy timelock (48-hour delay)
const timelock = await TimelockController.new(
  172800, // 48 hours
  [deployer.address], // proposers
  [deployer.address], // executors
  deployer.address // admin
);

// Set timelock as proxy admin
await proxyAdmin.transferOwnership(timelock.address);
```

### 2. Use Multisig for Admin

```javascript
// Use Gnosis Safe or similar
const MULTISIG_ADDRESS = '0x...';
await proxyAdmin.transferOwnership(MULTISIG_ADDRESS);
```

### 3. Emergency Pause Before Upgrade

```solidity
function safeUpgrade(address newImplementation) external onlyOwner {
  // Pause contract
  emergencyPause();

  // Perform upgrade
  _upgradeTo(newImplementation);

  // Resume after testing
  // emergencyUnpause(); // Manual unpause after verification
}
```

## Migration Path for Current Deployment

### Option A: Deploy New Upgradeable Contract

1. Deploy upgradeable version alongside existing
2. Gradually migrate users
3. Deprecate old contract

**Pros:** No risk to existing deployment
**Cons:** Split liquidity during migration

### Option B: Fresh Start with Upgradeable

1. Deploy new upgradeable contract
2. Coordinate full migration
3. Sunset old contract

**Pros:** Clean slate
**Cons:** Requires coordination

## Checklist for Implementing Upgrades

- [ ] Install OpenZeppelin upgradeable contracts
- [ ] Refactor contracts to use initializer pattern
- [ ] Remove immutable variables (store in regular storage)
- [ ] Document current storage layout
- [ ] Create deployment scripts
- [ ] Create upgrade scripts
- [ ] Write comprehensive upgrade tests
- [ ] Set up storage layout validation
- [ ] Implement timelock/multisig for admin
- [ ] Create emergency pause mechanism
- [ ] Audit upgrade logic
- [ ] Test on testnet with real upgrade scenario
- [ ] Document upgrade process for team

## Recommended Timeline

**Phase 1: Preparation (Week 1)**
- Install dependencies
- Document storage layout
- Create test suite structure

**Phase 2: Implementation (Weeks 2-3)**
- Refactor contracts to upgradeable
- Write deployment scripts
- Comprehensive testing

**Phase 3: Security (Week 4)**
- Audit upgrade logic
- Set up timelock/multisig
- Testnet deployment and testing

**Phase 4: Deployment (Week 5)**
- Mainnet deployment
- Monitor for issues
- Document lessons learned

## References

- [OpenZeppelin Upgrades Documentation](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [Proxy Upgrade Pattern](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [Writing Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)

---

**Status:** Strategy documented, implementation deferred
**Priority:** Low - Implement when bug fixes or major features needed
**Estimated Effort:** 4-5 weeks for full implementation
**Version:** 1.0
**Date:** 2025-11-08
