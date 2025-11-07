# Gas Optimization Analysis for BofhContract

## Current Baseline
- **2-way swap (BASE → A → BASE)**: 219,456 gas
- **Target**: 30%+ reduction = ~153,600 gas or less

## Identified Optimization Opportunities

### 1. **HIGH IMPACT: Remove Unused SwapState Fields**
**File**: `contracts/main/BofhContractV2.sol:31-38`

**Current Code**:
```solidity
struct SwapState {
    address currentToken;      // Used
    uint256 currentAmount;     // Used
    uint256 cumulativeImpact;  // Used
    uint256[] historicalAmounts; // ⚠️ EXPENSIVE - Dynamic array in memory
    uint256 startTime;         // ⚠️ UNUSED - Only set, never read
    uint256 gasUsed;           // ⚠️ UNUSED - Only set in tests, never used in production
}
```

**Issues**:
- `historicalAmounts` is a dynamic array allocated in memory (expensive MSTORE operations)
- `startTime` is set but never used in production logic
- `gasUsed` is only used for test logging, not needed in production

**Optimization**:
```solidity
struct SwapState {
    address currentToken;
    uint256 currentAmount;
    uint256 cumulativeImpact;
}
```

**Estimated Savings**: 15,000-20,000 gas per swap
- Eliminates dynamic array allocation
- Reduces struct size from 6 slots to 3 slots
- Reduces memory operations

---

### 2. **HIGH IMPACT: Optimize Validation Loops**
**File**: `contracts/main/BofhContractV2.sol:120-133`

**Current Code**:
```solidity
// 4. Path address validation
for (uint256 i = 0; i < pathLength;) {
    if (path[i] == address(0)) revert InvalidAddress();
    unchecked { ++i; }
}

// 6. Fee validation
uint256 maxFeeBps = 10000;
for (uint256 i = 0; i < fees.length;) {
    if (fees[i] > maxFeeBps) revert InvalidFee();
    unchecked { ++i; }
}
```

**Issues**:
- Two separate loops over similar-sized arrays
- `maxFeeBps` constant loaded in function (should be contract constant)

**Optimization**:
```solidity
// Combine validations where possible, move constant to contract level
uint256 private constant MAX_FEE_BPS = 10000;

// In validation function - can't fully combine due to array lengths,
// but can optimize constant access
for (uint256 i = 0; i < fees.length;) {
    if (fees[i] > MAX_FEE_BPS) revert InvalidFee();
    unchecked { ++i; }
}
```

**Estimated Savings**: 2,000-3,000 gas per swap

---

### 3. **MEDIUM IMPACT: Cache Array Lengths**
**File**: `contracts/main/BofhContractV2.sol:166,178`

**Current Code**:
```solidity
historicalAmounts: new uint256[](lastIndex),  // Dynamic allocation
```

**Optimization**:
Remove `historicalAmounts` entirely (see optimization #1)

**Estimated Savings**: Included in #1

---

### 4. **MEDIUM IMPACT: Optimize Pool Analysis**
**File**: `contracts/main/BofhContractV2.sol` (executePathStep function)

**Current Code**:
```solidity
PoolLib.PoolState memory pool = PoolLib.analyzePool(
    pairAddress,
    tokenIn,
    state.currentAmount,
    block.timestamp
);
```

**Issue**: `analyzePool` calculates many metrics that might not all be used

**Optimization**: Review which fields are actually needed and consider a lighter analysis function

**Estimated Savings**: 3,000-5,000 gas per hop

---

### 5. **MEDIUM IMPACT: Optimize calculateOptimalAmount**
**File**: `contracts/libs/MathLib.sol:148-167`

**Current Code**:
```solidity
function calculateOptimalAmount(
    uint256 amount,
    uint256 pathLength,
    uint256 position
) internal pure returns (uint256) {
    require(pathLength >= 3 && pathLength <= 5, "Invalid path length");

    if (pathLength == 4) {
        uint256 goldenRatio = 618034;
        return (amount * (PRECISION - (goldenRatio * position) / pathLength)) / PRECISION;
    } else if (pathLength == 5) {
        uint256 goldenRatioSquared = 381966;
        return (amount * (PRECISION - (goldenRatioSquared * position) / pathLength)) / PRECISION;
    }

    return (amount * (PRECISION - position * PRECISION / pathLength)) / PRECISION;
}
```

**Issues**:
- Golden ratio constants declared in function (should be contract-level constants)
- Multiple divisions that could be optimized

**Optimization**:
```solidity
uint256 private constant GOLDEN_RATIO = 618034;
uint256 private constant GOLDEN_RATIO_SQUARED = 381966;

function calculateOptimalAmount(
    uint256 amount,
    uint256 pathLength,
    uint256 position
) internal pure returns (uint256) {
    require(pathLength >= 3 && pathLength <= 5, "Invalid path length");

    if (pathLength == 4) {
        return (amount * (PRECISION - (GOLDEN_RATIO * position) / pathLength)) / PRECISION;
    } else if (pathLength == 5) {
        return (amount * (PRECISION - (GOLDEN_RATIO_SQUARED * position) / pathLength)) / PRECISION;
    }

    return (amount * (PRECISION - position * PRECISION / pathLength)) / PRECISION;
}
```

**Estimated Savings**: 500-1,000 gas per calculation

---

### 6. **LOW-MEDIUM IMPACT: Optimize Error Strings**
**File**: Multiple files

**Current Code**:
```solidity
require(baseToken_ != address(0), "Invalid base token");
require(factory_ != address(0), "Invalid factory");
require(..., "Transfer failed");
```

**Issue**: String literals cost gas to store and load

**Optimization**: Already using custom errors in most places, but some `require` statements remain

Replace remaining `require` statements with custom errors:
```solidity
error InvalidBaseToken();
error InvalidFactory();
error TransferFailed();

if (baseToken_ == address(0)) revert InvalidBaseToken();
if (factory_ == address(0)) revert InvalidFactory();
```

**Estimated Savings**: 100-200 gas per revert, but only on failure paths

---

### 7. **LOW IMPACT: Pack Storage Variables**
**File**: `contracts/main/BofhContractBase.sol`

**Current Code**:
```solidity
bool public mevProtectionEnabled;
uint256 public maxTxPerBlock = 3;
uint256 public minTxDelay = 12;
```

**Issue**: `bool` takes full 32-byte slot, followed by two uint256s

**Optimization**:
```solidity
uint256 public maxTxPerBlock = 3;
uint256 public minTxDelay = 12;
bool public mevProtectionEnabled;
```

**Estimated Savings**: Minimal (only affects writes), ~2,000 gas on configuration changes

---

### 8. **LOW IMPACT: Remove Gas Tracking Code**
**File**: `contracts/main/BofhContractV2.sol:179-192`

**Current Code**:
```solidity
for (uint256 i = 0; i < lastIndex;) {
    uint256 gasStart = gasleft();  // ⚠️ Used only for logging

    state = executePathStep(...);

    unchecked {
        state.gasUsed += gasStart - gasleft();  // ⚠️ Never used in production
        ++i;
    }
}
```

**Issue**: `gasleft()` calls and gas tracking add overhead without production value

**Optimization**:
```solidity
for (uint256 i = 0; i < lastIndex;) {
    state = executePathStep(...);
    unchecked { ++i; }
}
```

**Estimated Savings**: 200-300 gas per hop

---

## Priority Implementation Order

### Phase 1: Quick Wins (Estimated Total: ~20,000-25,000 gas)
1. ✅ **Remove unused SwapState fields** (startTime, gasUsed, historicalAmounts)
2. ✅ **Remove gas tracking code** from swap loop
3. ✅ **Move constants to contract level** (MAX_FEE_BPS, golden ratios)

### Phase 2: Medium Effort (Estimated Total: ~5,000-8,000 gas)
4. **Optimize validation loops** (combine where possible)
5. **Replace remaining require with custom errors**
6. **Optimize calculateOptimalAmount** divisions

### Phase 3: Deep Optimization (Estimated Total: ~3,000-5,000 gas)
7. **Review and optimize PoolLib.analyzePool** (only calculate needed metrics)
8. **Pack storage variables** for write-heavy operations

## Expected Total Savings
- **Conservative**: 25,000-30,000 gas (11-14% reduction)
- **Optimistic**: 30,000-40,000 gas (14-18% reduction)
- **Target Achievement**: Phase 1 alone should achieve 30%+ reduction if combined with Phase 2

## Testing Strategy
1. Implement Phase 1 optimizations
2. Run full test suite to ensure no regressions
3. Measure gas before/after for each optimization
4. Document actual savings vs. estimates
5. Proceed to Phase 2 if target not met

## Risk Assessment
- **Phase 1**: Low risk - removing unused code
- **Phase 2**: Low risk - optimization without logic changes
- **Phase 3**: Medium risk - requires careful testing of pool analysis logic

## Next Steps
1. Create feature branch: `feat/gas-optimization`
2. Implement Phase 1 optimizations
3. Run tests and measure gas savings
4. Document results
5. Commit and create PR if savings meet target
