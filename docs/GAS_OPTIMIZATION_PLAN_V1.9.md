# Gas Optimization Plan v1.9.0

**Target**: Reduce 2-way swap gas from **223,788** to **180,000** (19.5% reduction)
**Date**: 2025-11-11
**Status**: Ready for Implementation

---

## 📊 Current Baseline

| Swap Type | Gas Used | Gas/Hop | Target | Reduction Needed |
|-----------|----------|---------|--------|------------------|
| **2-Way** | 223,788 | 111,894 | 180,000 | **43,788 gas (19.5%)** |
| 3-Way | 308,080 | 102,693 | - | - |
| 4-Way | 347,155 | 86,789 | - | - |
| 5-Way | 423,748 | 84,750 | - | - |

**Deployment Gas**: 2,795,278 (BofhContractV2)

---

## 🔍 Identified Optimization Opportunities

### **Category 1: Storage Optimizations** (Est. 10-15k gas savings)

#### 1.1 Constants Already Optimized ✅
```solidity
// BofhContractV2.sol - Already immutable
address private immutable baseToken;  // ✅ GOOD
address private immutable factory;    // ✅ GOOD
```

#### 1.2 Storage Packing Improvements

**BofhContractBase.sol (Lines 39-70):**
```solidity
// CURRENT (Suboptimal):
uint256 public maxTradeVolume;           // Slot 0
uint256 public minPoolLiquidity;         // Slot 1
uint256 public maxPriceImpact;           // Slot 2
uint256 public sandwichProtectionBips;   // Slot 3
uint256 public maxTxPerBlock = 3;        // Slot 4
uint256 public minTxDelay = 12;          // Slot 5
bool public mevProtectionEnabled;        // Slot 6 (wastes 31 bytes!)

// OPTIMIZED (Pack bool with uint256):
uint256 public maxTradeVolume;           // Slot 0
uint256 public minPoolLiquidity;         // Slot 1
uint256 public maxPriceImpact;           // Slot 2
uint256 public sandwichProtectionBips;   // Slot 3
uint248 public maxTxPerBlock = 3;        // Slot 4 (leaves 8 bytes)
bool public mevProtectionEnabled;        // Slot 4 (packed!)
uint256 public minTxDelay = 12;          // Slot 5

// SAVINGS: 1 storage slot = ~20,000 gas per deployment, ~2,100 gas per SSTORE
```

**Estimated Savings**: 5,000-10,000 gas per swap (multiple SLOAD operations)

---

### **Category 2: Loop & Calculation Optimizations** (Est. 5-10k gas savings)

#### 2.1 Cache Array Length in Loops

**BofhContractV2.sol `_validateSwapInputs` (Line 100):**
```solidity
// CURRENT:
for (uint256 i = 0; i < pathLength;) {  // ✅ Already optimized!
    if (path[i] == address(0)) revert InvalidAddress();
    unchecked { ++i; }
}
```
**Status**: ✅ Already optimal (uses cached pathLength)

#### 2.2 Unchecked Arithmetic Where Safe

**BofhContractV2.sol `_executeSwap` (Line 139-177):**
```solidity
// CURRENT:
for (uint256 i = 0; i < pathLength - 1; i++) {
    // Multiple arithmetic operations
}

// OPTIMIZED:
unchecked {
    for (uint256 i = 0; i < pathLength - 1; ++i) {
        // Arithmetic here is safe (i never overflows)
        uint256 amountOut = ... calculations ...
    }
}
```

**Estimated Savings**: 300-500 gas per loop iteration × 2-5 iterations = 600-2,500 gas

---

### **Category 3: Function Call Optimizations** (Est. 10-20k gas savings)

#### 3.1 Inline Small External Library Calls

**HIGH IMPACT: `PoolLib.analyzePool` is called every hop**

**BofhContractV2.sol (Lines 150-160):**
```solidity
// CURRENT: External library call
PoolLib.PoolState memory poolState = PoolLib.analyzePool(
    pair,
    state.currentToken,
    nextToken
);

// This calls:
// - pair.getReserves() (external call ~2,100 gas)
// - pair.token0() (external call ~2,100 gas)
// - pair.token1() (external call ~2,100 gas)
// = ~6,300 gas per hop
```

**OPTIMIZATION: Cache pair data to avoid repeated calls**

```solidity
// Add to SwapState struct:
struct SwapState {
    address currentToken;
    uint256 currentAmount;
    uint256 cumulativeImpact;
    mapping(address => PoolCache) pairCache;  // NEW!
}

struct PoolCache {
    address token0;
    address token1;
    uint112 reserve0;
    uint112 reserve1;
    bool cached;
}

// First call: Cache the data
// Subsequent calls: Use cached data
```

**Estimated Savings**: 4,000-6,000 gas per hop for repeated pairs = 8,000-30,000 gas for circular paths!

---

#### 3.2 Reduce SecurityLib Overhead

**BofhContractBase.sol (Lines 118-122):**
```solidity
// CURRENT: Modifier calls library function
modifier nonReentrant() {
    securityState.enterProtectedSection(msg.sig);  // External lib call
    _;
    securityState.exitProtectedSection();           // External lib call
}

// OPTIMIZATION: Inline the critical path
modifier nonReentrant() {
    if (securityState.locked) revert Reentrancy();
    securityState.locked = true;
    _;
    securityState.locked = false;
}
```

**Estimated Savings**: 2,000-3,000 gas per swap

---

### **Category 4: Remove Redundant Operations** (Est. 5-10k gas savings)

#### 4.1 Eliminate Double Address Lookups

**BofhContractV2.sol (Lines 144-148):**
```solidity
// CURRENT: getPair called, then pair used multiple times
address pair = IUniswapV2Factory(factory).getPair(state.currentToken, nextToken);

if (blacklistedPools[pair]) revert PoolBlacklisted(pair);

PoolLib.PoolState memory poolState = PoolLib.analyzePool(
    pair,  // Used again
    state.currentToken,
    nextToken
);
```

**OPTIMIZATION**: Store pair in memory to avoid re-reading storage

```solidity
// Use local variable to avoid multiple storage reads
address cachedPair = pair;
```

**Estimated Savings**: 100-200 gas per operation × multiple uses = 500-1,000 gas

---

#### 4.2 Optimize Token Transfer Checks

**BofhContractV2.sol (Lines 139-142):**
```solidity
// CURRENT: Transfer input tokens
bool success = IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
if (!success) revert TransferFailed();
```

**OPTIMIZATION**: Use assembly for more efficient transfer check

```solidity
// Assembly version (saves ~500 gas)
assembly {
    let ptr := mload(0x40)
    mstore(ptr, 0x23b872dd)  // transferFrom selector
    // ... rest of assembly
}
```

**Estimated Savings**: 500-1,000 gas per swap

---

### **Category 5: Event & Error Optimizations** (Est. 2-5k gas savings)

#### 5.1 Optimize Event Emission

**BofhContractBase.sol (Lines 85-91):**
```solidity
// CURRENT:
emit SwapExecuted(
    msg.sender,
    pathLength,
    amountIn,
    state.currentAmount,
    state.cumulativeImpact
);

// OPTIMIZATION: Use indexed parameters efficiently
// (Already optimal - msg.sender is indexed)
```

**Status**: ✅ Already optimal

---

## 📋 Implementation Priority

### **Phase 1: Quick Wins** (Est. 15-20k gas savings)
**Effort**: 2-4 hours
**Risk**: Low

1. ✅ Storage packing (bool + uint248)
2. ✅ Unchecked arithmetic in loops
3. ✅ Inline reentrancy check

**Expected Result**: 223,788 → 205,000 gas (~8% reduction)

---

### **Phase 2: Medium Impact** (Est. 10-15k gas savings)
**Effort**: 4-8 hours
**Risk**: Medium

4. ✅ Cache pair data to avoid repeated external calls
5. ✅ Optimize token transfer checks
6. ✅ Remove redundant address lookups

**Expected Result**: 205,000 → 190,000 gas (~7% reduction)

---

### **Phase 3: Advanced Optimizations** (Est. 5-10k gas savings)
**Effort**: 8-12 hours
**Risk**: Medium-High

7. ✅ Assembly optimizations for critical paths
8. ✅ Further library call inlining
9. ✅ Memory vs calldata optimizations

**Expected Result**: 190,000 → 180,000 gas (~5% reduction)

---

## 🎯 Target Achievement Plan

| Phase | Gas After | Reduction | Status |
|-------|-----------|-----------|--------|
| **Baseline** | 223,788 | - | ✅ Complete |
| **Phase 1** | 205,000 | 8.4% | 🟡 Ready |
| **Phase 2** | 190,000 | 7.3% | 🟡 Ready |
| **Phase 3** | 180,000 | 5.3% | 🟡 Ready |
| **Total** | **180,000** | **19.5%** | 🎯 **TARGET** |

---

## 🧪 Testing Strategy

### Test Each Phase Independently

```bash
# Baseline
npx hardhat run scripts/test-nway-swaps.js --network localhost

# After Phase 1
npx hardhat test
npx hardhat run scripts/test-nway-swaps.js --network localhost

# Compare gas usage
```

### Automated Gas Regression Testing

```javascript
// Add to test suite
it("Gas optimization: 2-way swap should use <205k gas (Phase 1)", async function() {
  const tx = await bofh.executeSwap(path, fees, amountIn, minAmountOut, deadline);
  const receipt = await tx.wait();
  expect(receipt.gasUsed).to.be.lessThan(205000);
});
```

---

## 🚨 Risk Mitigation

### Safety Checks

1. **Test Coverage**: Run full test suite after each change
   ```bash
   npx hardhat test
   # Must maintain 80%+ coverage
   ```

2. **Behavior Verification**: Ensure no functional changes
   ```bash
   # All swaps must produce identical results
   npx hardhat run scripts/test-nway-swaps.js
   ```

3. **Security Audit**: Review security implications
   - Reentrancy protection must remain intact
   - Access control unchanged
   - MEV protection functional

### Rollback Plan

- Git branch for each phase
- Commit after each optimization
- Easy rollback if issues found

```bash
git checkout -b gas-opt-phase1
# Make changes
git commit -m "Phase 1 optimizations"
git tag v1.9.0-phase1

# If issues:
git checkout main
```

---

## 📊 Expected Impact on Other Operations

| Operation | Current Gas | Expected After | Change |
|-----------|-------------|----------------|--------|
| Deployment | 2,795,278 | ~2,700,000 | -3.4% |
| emergencyPause | 28,066 | ~27,000 | -3.8% |
| updateRiskParams | 41,334 | ~40,000 | -3.2% |
| setPoolBlacklist | 42,443 | ~41,000 | -3.4% |

---

## 💡 Future Optimizations (v2.0+)

### Beyond 180k Target

1. **EIP-2929 Awareness**: Warm vs cold SLOAD optimization
2. **Batch Operations**: Process multiple swaps in one tx
3. **Flash Loan Integration**: Eliminate initial transfer
4. **Custom Router**: Bypass factory lookups
5. **Assembly Rewrite**: Critical path in pure assembly

**Potential**: Additional 10-20% reduction (180k → 144-162k)

---

## 🏁 Success Criteria

### Must Meet All:

✅ 2-way swap gas ≤ 180,000
✅ All 291 tests passing
✅ Test coverage ≥ 80%
✅ No security vulnerabilities introduced
✅ No functional behavior changes
✅ Deployment gas reduced by 3-5%

### Nice to Have:

🎯 3-way swap gas <270,000
🎯 4-way swap gas <300,000
🎯 5-way swap gas <360,000

---

## 📅 Implementation Timeline

**Week 1: Phase 1** (Quick Wins)
- Day 1-2: Storage packing optimization
- Day 3: Unchecked arithmetic
- Day 4: Inline reentrancy check
- Day 5: Testing & validation

**Week 2: Phase 2** (Medium Impact)
- Day 1-2: Pair data caching
- Day 3: Transfer optimization
- Day 4: Remove redundant lookups
- Day 5: Testing & validation

**Week 3: Phase 3** (Advanced)
- Day 1-3: Assembly optimizations
- Day 4: Library call inlining
- Day 5: Final testing & release

**Total**: 3 weeks to v1.9.0 release

---

## 🔗 References

- **Solidity Gas Optimization**: https://github.com/iskdrews/awesome-solidity-gas-optimization
- **Storage Packing Guide**: https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
- **EVM Opcodes**: https://www.evm.codes/
- **Hardhat Gas Reporter**: https://github.com/cgewecke/hardhat-gas-reporter

---

**Status**: ✅ Ready for Implementation
**Next Step**: Begin Phase 1 - Storage Optimizations

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
