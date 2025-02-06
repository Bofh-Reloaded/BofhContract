# BofhContract V2

An optimized smart contract implementation for executing multi-path token swaps with advanced mathematical optimization techniques and robust security features.

## Architecture

The project is structured into several modular components:

### Core Contracts

- `BofhContractBase.sol`: Base contract with common functionality and security features
- `BofhContractV2.sol`: Main implementation with optimized swap execution logic
- `MathLib.sol`: Advanced mathematical functions library
- `PoolLib.sol`: DEX pool interaction and analysis library
- `SecurityLib.sol`: Security and access control library

### Interfaces

- `ISwapInterfaces.sol`: Common interfaces for token and pool interactions

### Mock Contracts (for testing)

- `MockToken.sol`: ERC20 token implementation
- `MockPair.sol`: DEX pair contract simulation
- `MockFactory.sol`: DEX factory contract simulation

## Features

- Optimized 4-way and 5-way swap paths using golden ratio techniques
- Advanced price impact calculation and slippage protection
- MEV protection with configurable parameters
- Dynamic gas optimization
- Comprehensive security features including:
  - Reentrancy protection
  - Circuit breakers
  - Access control
  - Rate limiting
- Modular and upgradeable architecture
- Extensive test coverage

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/BofhContract.git
cd BofhContract
```

2. Install dependencies:
```bash
npm install
```

3. Compile contracts:
```bash
truffle compile
```

4. Run tests:
```bash
truffle test
```

## Usage

### Deployment

1. Configure your network in `truffle-config.js`
2. Set up your deployment variables in `.env`
3. Run migrations:
```bash
truffle migrate --network <network_name>
```

### Contract Interaction

The main contract exposes the following key functions:

```solidity
// Execute a single path swap
function executeSwap(
    address[] calldata path,
    uint256[] calldata fees,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline
) external returns (uint256);

// Execute multiple path swaps
function executeMultiSwap(
    address[][] calldata paths,
    uint256[][] calldata fees,
    uint256[] calldata amounts,
    uint256[] calldata minAmounts,
    uint256 deadline
) external returns (uint256[] memory);

// Get optimal path metrics
function getOptimalPathMetrics(
    address[] calldata path,
    uint256[] calldata amounts
) external view returns (
    uint256 expectedOutput,
    uint256 priceImpact,
    uint256 optimalityScore
);
```

### Risk Management

Administrators can configure risk parameters:

```solidity
function updateRiskParams(
    uint256 maxTradeVolume,
    uint256 minPoolLiquidity,
    uint256 maxPriceImpact,
    uint256 sandwichProtectionBips
) external;
```

## Mathematical Optimizations

The contract implements several advanced mathematical techniques:

1. Golden Ratio Optimization
   - Uses φ (≈ 0.618034) for optimal 4-way splits
   - Uses φ2 (≈ 0.381966) for optimal 5-way splits

2. Dynamic Programming
   - Implements path optimization using historical amounts
   - Calculates geometric means for expected outputs

3. Price Impact Analysis
   - Advanced slippage calculation using cubic root approximation
   - Volatility tracking with exponential moving averages

## Security Considerations

1. MEV Protection
   - Sandwich attack detection
   - Configurable slippage tolerance
   - Maximum price impact limits

2. Circuit Breakers
   - Emergency pause functionality
   - Blacklist capability for compromised pools
   - Rate limiting for high-frequency operations

3. Access Control
   - Role-based permissions
   - Time-locked administrative functions
   - Operator management

## Testing

The test suite includes:

- Unit tests for mathematical functions
- Integration tests for swap execution
- Security tests for access control
- Gas optimization tests
- Mock contract tests

Run the full test suite:
```bash
truffle test
```

## License

UNLICENSED

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request
