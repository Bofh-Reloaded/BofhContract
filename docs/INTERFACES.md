# BofhContract Interfaces

Comprehensive guide to using BofhContract interfaces for external integrations and testing.

## Table of Contents

- [Overview](#overview)
- [Interface Architecture](#interface-architecture)
- [IBofhContract](#ibofhcontract)
- [IBofhContractBase](#ibofhcontractbase)
- [Integration Examples](#integration-examples)
- [Testing with MockBofhContract](#testing-with-mockbofhcontract)
- [Best Practices](#best-practices)

---

## Overview

The BofhContract project follows the **Dependency Inversion Principle** by defining clear interface abstractions. This allows:

- **Loose coupling** - External contracts depend on interfaces, not implementations
- **Easy testing** - Mock implementations can replace actual contracts
- **Multiple implementations** - Future versions can implement the same interface
- **Clear API contracts** - Interface defines what functionality is available

### Interface Hierarchy

```
IBofhContractBase (security, risk management, admin)
    ↓
IBofhContract (swap execution, path optimization)
    ↓
BofhContractV2 (concrete implementation)
```

---

## Interface Architecture

### IBofhContractBase

**Location:** `contracts/interfaces/IBofhContractBase.sol`

Defines security, risk management, and administrative functionality.

**Key Responsibilities:**
- Risk parameter management (maxTradeVolume, minPoolLiquidity, maxPriceImpact)
- Pool blacklisting/whitelisting
- MEV protection configuration
- Emergency pause/unpause
- Ownership and operator management

### IBofhContract

**Location:** `contracts/interfaces/IBofhContract.sol`

Defines core swap execution and path optimization functionality.

**Key Responsibilities:**
- Single-path swap execution
- Multi-path parallel swap execution
- Path metrics calculation (expected output, price impact, optimality)
- View functions for base token and factory

---

## IBofhContract

### Core Functions

#### executeSwap

Execute a token swap through a single path.

```solidity
function executeSwap(
    address[] calldata path,
    uint256[] calldata fees,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline
) external returns (uint256);
```

**Parameters:**
- `path` - Array of token addresses (must start and end with baseToken)
- `fees` - Array of fee amounts in basis points for each hop (length = path.length - 1)
- `amountIn` - Input amount in base token
- `minAmountOut` - Minimum acceptable output (slippage protection)
- `deadline` - Unix timestamp after which tx reverts

**Returns:**
- Actual output amount received

**Example:**

```solidity
// Swap BASE → TKNA → BASE (2-way arbitrage)
address[] memory path = new address[](3);
path[0] = baseToken;  // BASE
path[1] = tokenA;     // TKNA
path[2] = baseToken;  // BASE

uint256[] memory fees = new uint256[](2);
fees[0] = 997;  // 0.3% fee (997/1000 after fee)
fees[1] = 997;

uint256 output = bofhContract.executeSwap(
    path,
    fees,
    1000 * 1e18,           // 1000 tokens in
    990 * 1e18,            // Accept 1% slippage
    block.timestamp + 300  // 5 minute deadline
);
```

#### executeMultiSwap

Execute multiple swaps through different paths in parallel.

```solidity
function executeMultiSwap(
    address[][] calldata paths,
    uint256[][] calldata fees,
    uint256[] calldata amounts,
    uint256[] calldata minAmounts,
    uint256 deadline
) external returns (uint256[] memory);
```

**Parameters:**
- `paths` - Array of swap paths
- `fees` - Array of fee arrays (one per path)
- `amounts` - Array of input amounts (one per path)
- `minAmounts` - Array of minimum outputs (one per path)
- `deadline` - Unix timestamp

**Returns:**
- Array of actual output amounts

**Example:**

```solidity
// Execute 2 parallel swaps
address[][] memory paths = new address[][](2);

// Path 1: BASE → TKNA → BASE
paths[0] = new address[](3);
paths[0][0] = baseToken;
paths[0][1] = tokenA;
paths[0][2] = baseToken;

// Path 2: BASE → TKNB → BASE
paths[1] = new address[](3);
paths[1][0] = baseToken;
paths[1][1] = tokenB;
paths[1][2] = baseToken;

uint256[][] memory fees = new uint256[][](2);
fees[0] = new uint256[](2);
fees[0][0] = 997;
fees[0][1] = 997;
fees[1] = new uint256[](2);
fees[1][0] = 997;
fees[1][1] = 997;

uint256[] memory amounts = new uint256[](2);
amounts[0] = 500 * 1e18;
amounts[1] = 500 * 1e18;

uint256[] memory minAmounts = new uint256[](2);
minAmounts[0] = 495 * 1e18;
minAmounts[1] = 495 * 1e18;

uint256[] memory outputs = bofhContract.executeMultiSwap(
    paths,
    fees,
    amounts,
    minAmounts,
    block.timestamp + 300
);
```

#### getOptimalPathMetrics

Calculate expected output, price impact, and optimality score for a swap path (view function).

```solidity
function getOptimalPathMetrics(
    address[] calldata path,
    uint256[] calldata amounts
) external view returns (
    uint256 expectedOutput,
    uint256 priceImpact,
    uint256 optimalityScore
);
```

**Parameters:**
- `path` - Swap path to analyze
- `amounts` - Amount at each step (amounts[0] is initial input)

**Returns:**
- `expectedOutput` - Expected final output amount
- `priceImpact` - Cumulative price impact (scaled by PRECISION = 1e6)
- `optimalityScore` - Ratio of output to input (>1e6 = profitable)

**Example:**

```solidity
address[] memory path = new address[](3);
path[0] = baseToken;
path[1] = tokenA;
path[2] = baseToken;

uint256[] memory amounts = new uint256[](1);
amounts[0] = 1000 * 1e18;

(uint256 expectedOutput, uint256 priceImpact, uint256 optimality) =
    bofhContract.getOptimalPathMetrics(path, amounts);

// Check if swap is profitable
require(optimality > 1e6, "Swap not profitable");

// Check if price impact is acceptable
require(priceImpact < 50000, "Price impact too high (>5%)");
```

### View Functions

#### getBaseToken

```solidity
function getBaseToken() external view returns (address);
```

Returns the base token address. All swap paths must start and end with this token.

#### getFactory

```solidity
function getFactory() external view returns (address);
```

Returns the Uniswap V2-style factory address used for pair lookups.

### Events

#### SwapExecuted

```solidity
event SwapExecuted(
    address indexed initiator,
    uint256 pathLength,
    uint256 inputAmount,
    uint256 outputAmount,
    uint256 priceImpact
);
```

Emitted when a swap is successfully executed.

### Custom Errors

All errors use custom error syntax (Solidity 0.8+) for gas efficiency:

- `InvalidPath()` - Path structure invalid (wrong start/end token, length)
- `InsufficientOutput()` - Final output < minAmountOut
- `ExcessiveSlippage()` - Price slippage > MAX_SLIPPAGE (1%)
- `PathTooLong()` - Path length > MAX_PATH_LENGTH (5)
- `DeadlineExpired()` - block.timestamp > deadline
- `InsufficientLiquidity()` - Pool liquidity below minimum
- `InvalidAddress()` - Address parameter is address(0)
- `InvalidAmount()` - Amount parameter is 0
- `InvalidArrayLength()` - Array lengths don't match
- `InvalidFee()` - Fee > 100% (10000 bps)
- `TransferFailed()` - Token transfer failed
- `UnprofitableExecution()` - Multi-swap is unprofitable
- `InvalidSwapParameters()` - Pool validation failed
- `PairDoesNotExist()` - Pair not found in factory

---

## IBofhContractBase

### Admin Functions

#### updateRiskParams

```solidity
function updateRiskParams(
    uint256 _maxTradeVolume,
    uint256 _minPoolLiquidity,
    uint256 _maxPriceImpact,
    uint256 _sandwichProtectionBips
) external;
```

Update risk management parameters (owner only).

**Example:**

```solidity
bofhContract.updateRiskParams(
    5000 * 1e6,  // maxTradeVolume: 5000 tokens
    500 * 1e6,   // minPoolLiquidity: 500 tokens
    100000,      // maxPriceImpact: 10% (100000/1e6)
    50           // sandwichProtection: 0.5% (50 bps)
);
```

#### setPoolBlacklist

```solidity
function setPoolBlacklist(address pool, bool blacklisted) external;
```

Blacklist or whitelist a pool address (owner only).

**Example:**

```solidity
// Blacklist a suspicious pool
bofhContract.setPoolBlacklist(suspiciousPool, true);

// Later, whitelist it again
bofhContract.setPoolBlacklist(suspiciousPool, false);
```

#### configureMEVProtection

```solidity
function configureMEVProtection(
    bool enabled,
    uint256 _maxTxPerBlock,
    uint256 _minTxDelay
) external;
```

Configure MEV protection parameters (owner only).

**Example:**

```solidity
// Enable MEV protection with strict limits
bofhContract.configureMEVProtection(
    true,  // enabled
    2,     // max 2 transactions per block
    30     // min 30 seconds between transactions
);
```

#### Emergency Controls

```solidity
function emergencyPause() external;
function emergencyUnpause() external;
```

Pause/unpause contract in emergency situations (owner only).

**Example:**

```solidity
// Pause contract if exploit detected
bofhContract.emergencyPause();

// After issue resolved
bofhContract.emergencyUnpause();
```

### View Functions

#### getRiskParameters

```solidity
function getRiskParameters() external view returns (
    uint256 maxVolume,
    uint256 minLiquidity,
    uint256 maxImpact,
    uint256 sandwichProtection
);
```

Get all risk parameters.

#### getMEVProtectionConfig

```solidity
function getMEVProtectionConfig() external view returns (
    bool enabled,
    uint256 maxTx,
    uint256 minDelay
);
```

Get MEV protection configuration.

#### Other View Functions

```solidity
function getAdmin() external view returns (address);
function isPoolBlacklisted(address pool) external view returns (bool);
function isPaused() external view returns (bool);
```

---

## Integration Examples

### External Contract Integration

Example of a contract that integrates with BofhContract via interface:

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "./interfaces/IBofhContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ArbitrageBot
/// @notice Automated arbitrage bot using BofhContract
contract ArbitrageBot {
    IBofhContract public immutable bofhContract;
    address public immutable baseToken;
    address public owner;

    constructor(address _bofhContract) {
        bofhContract = IBofhContract(_bofhContract);
        baseToken = bofhContract.getBaseToken();
        owner = msg.sender;
    }

    /// @notice Execute arbitrage if profitable
    /// @param path Arbitrage path
    /// @param fees Fee array
    /// @param amountIn Amount to arbitrage
    function executeArbitrage(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn
    ) external {
        require(msg.sender == owner, "Not owner");

        // Check if path is profitable
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountIn;

        (uint256 expectedOutput, , uint256 optimality) =
            bofhContract.getOptimalPathMetrics(path, amounts);

        // Only execute if profitable (optimality > 100%)
        require(optimality > 1e6, "Not profitable");

        // Approve tokens
        IERC20(baseToken).approve(address(bofhContract), amountIn);

        // Execute swap with 1% slippage tolerance
        uint256 minOut = (expectedOutput * 99) / 100;

        uint256 output = bofhContract.executeSwap(
            path,
            fees,
            amountIn,
            minOut,
            block.timestamp + 300
        );

        // Profit = output - amountIn
        emit ArbitrageExecuted(path, amountIn, output, output - amountIn);
    }

    event ArbitrageExecuted(
        address[] path,
        uint256 amountIn,
        uint256 output,
        uint256 profit
    );
}
```

### Off-Chain Integration (JavaScript/TypeScript)

```javascript
const { ethers } = require('ethers');

// Connect to contract via interface
const bofhContract = new ethers.Contract(
    contractAddress,
    IBofhContractABI,  // Use interface ABI
    signer
);

// Check if swap is profitable before executing
async function executeIfProfitable(path, fees, amountIn) {
    // Get path metrics
    const [expectedOutput, priceImpact, optimality] =
        await bofhContract.getOptimalPathMetrics(path, [amountIn]);

    console.log(`Expected output: ${ethers.utils.formatEther(expectedOutput)}`);
    console.log(`Price impact: ${priceImpact.toNumber() / 1e6}%`);
    console.log(`Optimality: ${optimality.toNumber() / 1e6}`);

    // Check profitability (optimality > 1.0 = profitable)
    if (optimality.gt(ethers.BigNumber.from('1000000'))) {
        // Execute swap with 1% slippage
        const minOut = expectedOutput.mul(99).div(100);
        const deadline = Math.floor(Date.now() / 1000) + 300; // 5 minutes

        const tx = await bofhContract.executeSwap(
            path,
            fees,
            amountIn,
            minOut,
            deadline
        );

        const receipt = await tx.wait();
        console.log(`Swap executed: ${receipt.transactionHash}`);
    } else {
        console.log('Swap not profitable, skipping');
    }
}
```

---

## Testing with MockBofhContract

### Overview

`MockBofhContract` is a simplified implementation of `IBofhContract` for testing external integrations.

**Location:** `contracts/mocks/MockBofhContract.sol`

### Features

- Implements full `IBofhContract` interface
- No actual token transfers (simplified logic)
- Configurable output amounts for testing
- Tracks swap execution for verification
- Can simulate failures and edge cases

### Usage Example

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "../mocks/MockBofhContract.sol";
import "../MyIntegration.sol";

contract MyIntegrationTest is Test {
    MockBofhContract mockBofh;
    MyIntegration integration;

    function setUp() public {
        // Deploy mock contract
        mockBofh = new MockBofhContract(baseToken, factory);

        // Deploy integration contract with mock
        integration = new MyIntegration(address(mockBofh));
    }

    function testSuccessfulSwap() public {
        // Configure mock to return specific output
        mockBofh.setMockOutputAmount(1100 * 1e18); // 10% profit

        // Execute integration logic
        integration.executeArbitrage(path, fees, 1000 * 1e18);

        // Verify mock was called
        assertEq(mockBofh.swapCounter(), 1);

        // Verify parameters
        address[] memory lastPath = mockBofh.getLastSwapPath();
        assertEq(lastPath.length, 3);
        assertEq(lastPath[0], baseToken);
    }

    function testHandlesFailure() public {
        // Simulate swap failure
        mockBofh.setShouldFail(true);

        // Expect revert
        vm.expectRevert("Mock failure");
        integration.executeArbitrage(path, fees, 1000 * 1e18);
    }

    function testHandlesInsufficientOutput() public {
        // Simulate insufficient output
        mockBofh.setSimulateInsufficientOutput(true);

        // Expect InsufficientOutput error
        vm.expectRevert(IBofhContract.InsufficientOutput.selector);
        integration.executeArbitrage(path, fees, 1000 * 1e18);
    }
}
```

### Mock Configuration Functions

```solidity
// Set custom output amount (0 = use minAmountOut)
mockBofh.setMockOutputAmount(1100 * 1e18);

// Simulate generic failure
mockBofh.setShouldFail(true);

// Simulate insufficient output error
mockBofh.setSimulateInsufficientOutput(true);

// Reset all state
mockBofh.reset();
```

### Verification Functions

```solidity
// Get execution counts
uint256 swaps = mockBofh.swapCounter();
uint256 multiSwaps = mockBofh.multiSwapCounter();

// Get last swap parameters
address[] memory lastPath = mockBofh.getLastSwapPath();
uint256[] memory lastFees = mockBofh.getLastSwapFees();
```

---

## Best Practices

### For External Integrations

1. **Always use interfaces** - Depend on `IBofhContract`, not `BofhContractV2`
2. **Check profitability first** - Call `getOptimalPathMetrics` before executing swaps
3. **Handle all errors** - Implement proper error handling for all custom errors
4. **Set realistic deadlines** - Don't use block.timestamp, add buffer time
5. **Account for slippage** - Calculate `minAmountOut` with appropriate tolerance
6. **Monitor events** - Listen to `SwapExecuted` for swap tracking

### For Testing

1. **Use MockBofhContract** - Don't deploy full contract in unit tests
2. **Test error cases** - Verify handling of all custom errors
3. **Test edge cases** - Min amounts, max path length, deadline expiry
4. **Verify state changes** - Check balances, counters, events after operations
5. **Test with different configs** - Mock different output amounts, failures

### For Contract Deployment

1. **Verify implementation** - Ensure contract implements interface correctly
2. **Check compiler version** - Use Solidity >=0.8.10 for custom error support
3. **Validate constructor** - Ensure baseToken and factory are correct
4. **Test on testnet first** - Deploy to testnet (BSC testnet) before mainnet
5. **Monitor initial swaps** - Watch first swaps closely for unexpected behavior

---

## Interface Versioning

Current interface version: **v1.0**

### Version History

- **v1.0** (2025-11-08) - Initial interface release
  - `IBofhContract`: Core swap functionality
  - `IBofhContractBase`: Security and risk management
  - `MockBofhContract`: Testing mock implementation

### Future Versions

If breaking changes are needed:
1. Create new interface version (e.g., `IBofhContractV2`)
2. Maintain backward compatibility with v1
3. Provide migration guide
4. Deprecate old interfaces with sufficient notice

---

## Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [Security Documentation](SECURITY.md)
- [Testing Guide](TESTING.md)
- [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)

---

**Last Updated:** 2025-11-08
**Version:** 1.0
**Maintainer:** BofhContract Team
