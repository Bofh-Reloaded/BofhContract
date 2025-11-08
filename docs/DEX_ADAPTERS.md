# DEX Adapter Pattern

Infrastructure for decoupling DEX dependencies using the Adapter Pattern.

## Overview

The DEX Adapter Pattern provides a uniform interface for interacting with different decentralized exchanges (Uniswap V2, PancakeSwap, SushiSwap, etc.), enabling:

- **Protocol independence** - Swap between DEXs without code changes
- **Easy testing** - MockDEXAdapter for unit tests
- **Future extensibility** - Add new DEX support by implementing IDEXAdapter
- **Best price routing** - Compare prices across multiple DEXs

## Architecture

```
IDEXAdapter (interface)
    ├── UniswapV2Adapter (Uniswap V2, 0.3% fee)
    ├── PancakeSwapAdapter (PancakeSwap V2, 0.25% fee)
    └── MockDEXAdapter (testing)
```

## IDEXAdapter Interface

**Location:** `contracts/adapters/IDEXAdapter.sol`

### Core Functions

- `getPoolAddress(tokenA, tokenB)` - Get pool/pair address
- `getReserves(pool)` - Get pool reserves
- `getTokens(pool)` - Get token0 and token1
- `executeSwap(...)` - Execute swap through pool
- `getAmountOut(...)` - Calculate expected output (view)
- `getDEXName()` - Get DEX name
- `getFactory()` - Get factory address
- `getFeeBps()` - Get fee in basis points
- `isValidPool(pool)` - Check if pool exists

## Adapters

### UniswapV2Adapter

**Location:** `contracts/adapters/UniswapV2Adapter.sol`

- Protocol: Uniswap V2 and forks
- Fee: 0.3% (30 bps)
- Formula: `amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)`

### PancakeSwapAdapter

**Location:** `contracts/adapters/PancakeSwapAdapter.sol`

- Protocol: PancakeSwap V2 (BSC)
- Fee: 0.25% (25 bps)
- Formula: `amountOut = (amountIn * 9975 * reserveOut) / (reserveIn * 10000 + amountIn * 9975)`
- BSC Testnet Factory: `0x6725F303b657a9451d8BA641348b6761A6CC7a17`

### MockDEXAdapter

**Location:** `contracts/mocks/MockDEXAdapter.sol`

Mock implementation for testing with configurable behavior.

## Usage Example

```solidity
// Deploy adapter
UniswapV2Adapter adapter = new UniswapV2Adapter(factoryAddress);

// Get pool
address pool = adapter.getPoolAddress(tokenA, tokenB);

// Check if valid
require(adapter.isValidPool(pool), "Invalid pool");

// Get expected output
uint256 expectedOut = adapter.getAmountOut(pool, tokenA, 1000 * 1e18);

// Execute swap
uint256 output = adapter.executeSwap(
    pool,
    tokenA,
    tokenB,
    1000 * 1e18,
    950 * 1e18,  // 5% slippage
    msg.sender
);
```

## Future Integration

Phase 2 (Future Sprint): Integrate adapters into BofhContractV2 for multi-DEX support.

---

**Version:** 1.0 (Phase 1 - Infrastructure)
**Date:** 2025-11-08
