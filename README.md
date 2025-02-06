# BofhContract - Advanced DEX Arbitrage System

BofhContract implements a sophisticated arbitrage system for decentralized exchanges (DEX) using advanced mathematical principles and MEV protection mechanisms.

## Mathematical Foundations

### 1. Golden Ratio Optimization (φ)

The contract uses the golden ratio (φ ≈ 0.618034) for optimal trade splitting based on the following principles:

1. Fibonacci Sequence Properties:
   - φ = (1 + √5) / 2 ≈ 1.618034
   - 1/φ = φ - 1 ≈ 0.618034
   - φ2 = φ + 1 ≈ 2.618034

2. Trade Size Optimization:
   ```solidity
   optimalAmount = currentAmount * GOLDEN_RATIO // φ ≈ 0.618034
   ```
   - Balances price impact vs. trade size
   - Minimizes slippage across multiple pools
   - Maintains optimal liquidity utilization

3. Path-Specific Applications:
   - 4-way paths: Uses φ directly
   - 5-way paths: Uses φ2 for deeper paths
   - Dynamic adjustment based on path length

### 2. Price Impact Calculation

The contract uses cubic root for price impact calculation to provide more accurate slippage estimation:

```solidity
function calculatePriceImpact(amountIn, pool) {
    k = reserveIn * reserveOut;
    newReserveIn = reserveIn + amountIn;
    newK = newReserveIn * reserveOut;
    impactCubed = (newK * PRECISION * PRECISION) / (k * PRECISION);
    return cbrt(impactCubed);
}
```

This approach:
- Provides more accurate impact assessment than linear calculation
- Better handles large trades
- Accounts for pool depth

### 3. MEV Protection

The contract implements multiple layers of MEV protection:

1. Sandwich Attack Detection:
   ```solidity
   expectedPrice = (reserveOut * PRECISION) / reserveIn;
   actualPrice = (currentAmount * PRECISION) / reserveIn;
   priceDeviation = |actualPrice - expectedPrice| * PRECISION / expectedPrice;
   require(priceDeviation <= sandwichProtectionBips);
   ```

2. Dynamic Slippage Tolerance:
   ```solidity
   maxAllowedSlippage = (MAX_SLIPPAGE * (idx + 1)) / pathLength;
   ```
   - Increases with path depth
   - Accounts for cumulative impact

3. Price Impact Monitoring:
   - Uses geometric mean for validation
   - Tracks cumulative impact
   - Enforces maximum deviation limits

### 4. Dynamic Programming Implementation

For 5-way paths, the contract uses dynamic programming to optimize execution:

1. Historical Analysis:
   ```solidity
   historicalAmounts[i] = currentAmount;
   expectedOutput = geometricMean(
       historicalAmounts[i-1],
       i > 1 ? historicalAmounts[i-2] : preSwapAmount
   );
   ```

2. Progressive Tolerance:
   ```solidity
   tolerance = PRECISION + ((i + 1) * INVERSE_GOLDEN_RATIO) / 5;
   ```
   - Adapts to path position
   - Uses inverse golden ratio for scaling

## Advanced Features

### 1. Risk Management System

```solidity
// Risk parameters
mapping(address => bool) public blacklistedPools;
uint256 public maxTradeVolume;
uint256 public minPoolLiquidity;
uint256 public maxPriceImpact;
uint256 public sandwichProtectionBips;
```

1. Pool Validation:
   - Minimum liquidity requirements
   - Blacklist functionality
   - Volume-based limits

2. Dynamic Profit Thresholds:
   ```solidity
   gasUsed = GAS_OVERHEAD_PER_SWAP * (idx + 1);
   minProfitRequired = (gasUsed * tx.gasprice * 12) / 10; // 20% buffer
   ```
   - Accounts for gas costs
   - Includes safety buffer
   - Prevents unprofitable trades

### 2. Path Optimization

1. Four-Way Paths:
   ```
   baseToken → token1 → token2 → token3 → baseToken
   ```
   - Uses golden ratio (φ)
   - Optimal for moderate market inefficiencies
   - Lower gas costs

2. Five-Way Paths:
   ```
   baseToken → token1 → token2 → token3 → token4 → baseToken
   ```
   - Uses golden ratio squared (φ2)
   - Better for complex arbitrage
   - Higher potential profit

### 3. Safety Mechanisms

1. Emergency Controls:
   ```solidity
   function emergencyPause(bool pause) external onlyOwner {
       emergencyPaused = pause;
       if (pause) {
           // Withdraw all funds
           uint256 balance = IBEP20(baseToken).balanceOf(address(this));
           if (balance > 0) {
               IBEP20(baseToken).transfer(msg.sender, balance);
           }
       }
   }
   ```

2. Circuit Breakers:
   - Maximum slippage per swap
   - Cumulative impact limits
   - Volume restrictions

## Technical Implementation

### 1. Gas Optimizations

1. Memory Management:
   - Packed structs
   - Efficient calldata handling
   - Minimal storage operations

2. Computational Efficiency:
   - Unchecked arithmetic where safe
   - Assembly for critical operations
   - Optimized loops

### 2. Error Handling

Custom errors with specific conditions:
```solidity
error InsufficientLiquidity();
error ExcessiveSlippage();
error SuboptimalPath();
error MinimumProfitNotMet();
```

## Usage Guide

### Parameter Encoding

The contract uses an optimized encoding scheme:

```solidity
// Pool data encoding
poolData = (feePPM << 160) | poolAddress

// Amount data encoding
amountData = initialAmount | (expectedAmount << 128)
```

### Function Calls

1. Four-Way Arbitrage:
```solidity
function fourWaySwap(uint256[4] calldata args) external
```

2. Five-Way Arbitrage:
```solidity
function fiveWaySwap(uint256[5] calldata args) external
```

### Risk Parameters

Configurable via admin functions:
```solidity
function updateRiskParams(
    uint256 _maxTradeVolume,
    uint256 _minPoolLiquidity,
    uint256 _maxPriceImpact,
    uint256 _sandwichProtectionBips
) external onlyOwner
```

## Monitoring and Control

### Events

```solidity
event PoolBlacklisted(address indexed pool, bool blacklisted);
event RiskParamsUpdated(
    uint256 maxVolume,
    uint256 minLiquidity,
    uint256 maxImpact,
    uint256 sandwichProtection
);
event EmergencyAction(bool paused);
```

### Admin Functions

1. Risk Management:
   - `setPoolBlacklist(address pool, bool blacklisted)`
   - `updateRiskParams(...)`
   - `emergencyPause(bool pause)`

2. Fund Management:
   - `adoptAllowance()`
   - `withdrawFunds()`
   - `deactivateContract()`

The contract combines advanced mathematical principles with robust safety mechanisms to execute profitable arbitrage while protecting against MEV attacks and maintaining optimal gas efficiency.
