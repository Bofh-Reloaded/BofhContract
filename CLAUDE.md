# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BofhContract V2 is an advanced smart contract system for executing optimized multi-path token swaps on EVM-compatible blockchains (primarily BSC testnet). It implements sophisticated mathematical algorithms using the golden ratio (φ ≈ 0.618034) for 4-way and 5-way swap path optimization, with robust security features including MEV protection, circuit breakers, and comprehensive access control.

## Development Commands

### Solidity Contract Development

```bash
# Compile contracts
truffle compile --network bscTestnet
# Or simply:
npm run compile

# Run tests
truffle test
# Or using builder:
npm test

# Generate coverage report
npm run coverage

# Deploy to BSC testnet
npm run migrate

# Verify deployed contract on BSCScan
npm run verify
# Note: Replace {your contract address} in package.json script before running
```

### Python CLI Tool

```bash
# Install Python package
pip install -e .

# Run CLI interface
python -m bofh.contract

# Clean build artifacts
python setup.py clean
```

## Architecture

### Contract Hierarchy

```
BofhContractV2 (main implementation)
    └── BofhContractBase (abstract base with security & risk management)
         ├── Uses SecurityLib (access control, reentrancy protection, rate limiting)
         ├── Uses MathLib (sqrt, cbrt, geometric mean, golden ratio calculations)
         └── Uses PoolLib (liquidity analysis, price impact calculations)
```

### Key Contract Files

- `contracts/main/BofhContractV2.sol` - Main swap execution logic with path optimization
- `contracts/main/BofhContractBase.sol` - Base contract with security features and risk parameters
- `contracts/libs/MathLib.sol` - Mathematical operations using Newton's method for sqrt/cbrt
- `contracts/libs/PoolLib.sol` - Pool state management and liquidity analysis
- `contracts/libs/SecurityLib.sol` - Security primitives (reentrancy guards, access control)
- `contracts/interfaces/ISwapInterfaces.sol` - Interface definitions for DEX integration

### Mock Contracts (for testing)

- `contracts/mocks/MockToken.sol` - ERC20 token implementation for tests
- `contracts/mocks/MockPair.sol` - Uniswap V2-style pair with CPMM (x*y=k)
- `contracts/mocks/MockFactory.sol` - Factory for creating mock pairs

### Python CLI Tool

Located in `bofh/contract/`:
- `__main__.py` - CLI interface for contract interaction, method selector enumeration
- `__init__.py` - Contract interface utilities

## Important Development Context

### Solidity Version & Compiler Settings

- Primary version: `0.8.10+` (for main contracts in `contracts/main/` and `contracts/libs/`)
- Legacy version: `0.6.12` (Truffle config for compatibility with some dependencies)
- Optimizer: **Disabled** in truffle-config.js
- EVM version: `byzantium`

### Network Configuration

The project uses BSC (Binance Smart Chain) testnet:
- Network ID: 97
- RPC: `https://data-seed-prebsc-1-s1.binance.org:8545`
- Explorer: BSCScan
- Mnemonic and API keys configured in `env.json` (not committed to git)

### Constants & Risk Parameters

Key constants defined in `BofhContractBase.sol`:
- `PRECISION = 1e6` - Base precision for calculations
- `MAX_SLIPPAGE = 1%` - Maximum allowed slippage
- `MIN_OPTIMALITY = 50%` - Minimum optimality threshold
- `MAX_PATH_LENGTH = 5` - Maximum swap path length

Default risk parameters (configurable via `updateRiskParams`):
- `maxTradeVolume = 1000 * PRECISION`
- `minPoolLiquidity = 100 * PRECISION`
- `maxPriceImpact = 10%`
- `sandwichProtectionBips = 50` (0.5%)

### Swap Algorithm Design

The contract uses a golden ratio-based optimization strategy:
- 4-way swaps: Split amounts using φ ≈ 0.618034
- 5-way swaps: Advanced optimization with geometric mean validation
- Path validation: All paths must start and end with baseToken
- Price impact tracking: Cumulative impact across entire path
- Slippage protection: Enforced via `minAmountOut` parameter

### Security Features

1. **Reentrancy Protection**: Via `SecurityLib.enterProtectedSection`/`exitProtectedSection`
2. **Access Control**: Owner-only functions with `onlyOwner` modifier
3. **Circuit Breakers**: Pause functionality via `whenNotPaused` modifier
4. **MEV Protection**: Deadline checks and sandwich attack mitigation
5. **Blacklist System**: Pool-level blacklisting capability

### Testing Architecture

Tests use:
- Truffle framework with OpenZeppelin test helpers
- Mock contracts (MockToken, MockPair, MockFactory)
- Chai assertions with BN (BigNumber) support
- Test file: `test/BofhContractV2.test.js`

Test setup creates:
- Multiple mock tokens (BASE, TKNA, TKNB, TKNC)
- Mock factory for pair creation
- Pre-funded liquidity pools for swap testing

## Important Implementation Notes

### When Working with Swaps

1. All swap paths MUST begin and end with `baseToken` (enforced in `_executeSwap`)
2. Path length must be `2 ≤ length ≤ MAX_PATH_LENGTH (5)`
3. Fees array length must equal `path.length - 1`
4. Always check deadline: `block.timestamp > deadline` reverts with `DeadlineExpired()`
5. Output validation: Final amount must meet `minAmountOut` or transaction reverts

### Gas Optimization Patterns

- Use `unchecked` blocks for iterator increments in loops (contracts/main/BofhContractV2.sol:80-83)
- Track gas usage per swap step: `uint256 gasStart = gasleft()`
- Libraries (MathLib, PoolLib, SecurityLib) are used for code reuse and gas efficiency

### Custom Errors

The contract uses custom errors (Solidity 0.8+) for gas efficiency:
- `InvalidPath()`, `InsufficientOutput()`, `ExcessiveSlippage()`
- `PathTooLong()`, `DeadlineExpired()`, `InsufficientLiquidity()`

### Events

Key events to monitor:
- `SwapExecuted(initiator, pathLength, inputAmount, outputAmount, priceImpact)`
- `PoolBlacklisted(pool, blacklisted)`
- `RiskParamsUpdated(maxVolume, minLiquidity, maxImpact, sandwichProtection)`

## Documentation

Comprehensive documentation in `docs/`:
- `ARCHITECTURE.md` - Detailed system design and component interaction
- `MATHEMATICAL_FOUNDATIONS.md` - CPMM theory and optimization algorithms
- `SWAP_ALGORITHMS.md` - 4-way and 5-way swap implementations
- `SECURITY.md` - Security analysis and threat mitigation
- `TESTING.md` - Testing framework and methodologies

Refer to these docs when implementing new features or debugging complex swap logic.

## Configuration Files

- `truffle-config.js` - Truffle configuration with BSC testnet setup
- `env.json` - Contains mnemonic and BSCSCANAPIKEY (gitignored, use placeholder values)
- `package.json` - Node dependencies and npm scripts
- `setup.py` - Python package configuration for CLI tool
