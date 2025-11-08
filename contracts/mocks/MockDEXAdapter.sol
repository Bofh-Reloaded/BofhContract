// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "../adapters/IDEXAdapter.sol";

/// @title MockDEXAdapter
/// @notice Mock implementation of IDEXAdapter for testing
/// @dev Provides configurable behavior for testing adapter integration
contract MockDEXAdapter is IDEXAdapter {
    /// @notice Mock factory address
    address public immutable factory;

    /// @notice Configurable mock pool address
    address public mockPoolAddress;

    /// @notice Configurable mock reserves
    uint256 public mockReserve0;
    uint256 public mockReserve1;
    uint256 public mockBlockTimestamp;

    /// @notice Configurable mock tokens
    address public mockToken0;
    address public mockToken1;

    /// @notice Configurable mock output amount
    uint256 public mockAmountOut;

    /// @notice Flag to simulate pool not found
    bool public simulatePoolNotFound;

    /// @notice Flag to simulate invalid reserves
    bool public simulateInvalidReserves;

    /// @notice Flag to simulate swap failure
    bool public simulateSwapFailure;

    /// @notice Counter for swap executions
    uint256 public swapExecutionCount;

    /// @notice Last swap parameters for verification
    struct LastSwap {
        address pool;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOutMin;
        address to;
    }

    /// @notice Last swap execution data
    LastSwap public lastSwap;

    /// @notice Deploy MockDEXAdapter with factory address
    /// @param factory_ Mock factory address
    constructor(address factory_) {
        factory = factory_;
        mockBlockTimestamp = block.timestamp;
    }

    /// @inheritdoc IDEXAdapter
    function getPoolAddress(address tokenA, address tokenB)
        external
        view
        override
        returns (address pool)
    {
        if (simulatePoolNotFound) revert PoolNotFound();
        if (tokenA == address(0) || tokenB == address(0)) revert InvalidTokens();
        return mockPoolAddress != address(0) ? mockPoolAddress : address(this);
    }

    /// @inheritdoc IDEXAdapter
    function getReserves(address /* pool */)
        external
        view
        override
        returns (
            uint256 reserve0,
            uint256 reserve1,
            uint256 blockTimestampLast
        )
    {
        if (simulateInvalidReserves) revert InvalidReserves();
        return (mockReserve0, mockReserve1, mockBlockTimestamp);
    }

    /// @inheritdoc IDEXAdapter
    function getTokens(address /* pool */)
        external
        view
        override
        returns (address token0, address token1)
    {
        if (mockToken0 == address(0) || mockToken1 == address(0)) {
            revert InvalidTokens();
        }
        return (mockToken0, mockToken1);
    }

    /// @inheritdoc IDEXAdapter
    function executeSwap(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external override returns (uint256 amountOut) {
        if (simulateSwapFailure) revert SwapFailed();

        // Store last swap parameters
        lastSwap = LastSwap({
            pool: pool,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOutMin: amountOutMin,
            to: to
        });

        // Increment counter
        swapExecutionCount++;

        // Return configured mock output or minAmount
        amountOut = mockAmountOut > 0 ? mockAmountOut : amountOutMin;

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, pool);

        return amountOut;
    }

    /// @inheritdoc IDEXAdapter
    function getAmountOut(
        address /* pool */,
        address /* tokenIn */,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        // Simple mock: return configured amount or use simple calculation
        if (mockAmountOut > 0) {
            return mockAmountOut;
        }

        // Default: 1% slippage simulation
        return (amountIn * 99) / 100;
    }

    /// @inheritdoc IDEXAdapter
    function getDEXName() external pure override returns (string memory) {
        return "Mock DEX";
    }

    /// @inheritdoc IDEXAdapter
    function getFactory() external view override returns (address) {
        return factory;
    }

    /// @inheritdoc IDEXAdapter
    function getFeeBps() external pure override returns (uint256) {
        return 30; // 0.3% like Uniswap V2
    }

    /// @inheritdoc IDEXAdapter
    function isValidPool(address /* pool */) external view override returns (bool) {
        if (simulatePoolNotFound) return false;
        if (simulateInvalidReserves) return false;
        return mockReserve0 > 0 && mockReserve1 > 0;
    }

    // ============================================
    // TEST HELPER FUNCTIONS
    // ============================================

    /// @notice Configure mock pool address
    /// @param pool Pool address to return from getPoolAddress
    function setMockPoolAddress(address pool) external {
        mockPoolAddress = pool;
    }

    /// @notice Configure mock reserves
    /// @param reserve0 Reserve for token0
    /// @param reserve1 Reserve for token1
    function setMockReserves(uint256 reserve0, uint256 reserve1) external {
        mockReserve0 = reserve0;
        mockReserve1 = reserve1;
    }

    /// @notice Configure mock tokens
    /// @param token0 Address of token0
    /// @param token1 Address of token1
    function setMockTokens(address token0, address token1) external {
        mockToken0 = token0;
        mockToken1 = token1;
    }

    /// @notice Configure mock output amount
    /// @param amountOut Output amount to return from executeSwap
    function setMockAmountOut(uint256 amountOut) external {
        mockAmountOut = amountOut;
    }

    /// @notice Simulate pool not found error
    /// @param simulate True to simulate error, false for normal operation
    function setSimulatePoolNotFound(bool simulate) external {
        simulatePoolNotFound = simulate;
    }

    /// @notice Simulate invalid reserves error
    /// @param simulate True to simulate error, false for normal operation
    function setSimulateInvalidReserves(bool simulate) external {
        simulateInvalidReserves = simulate;
    }

    /// @notice Simulate swap failure
    /// @param simulate True to simulate failure, false for normal operation
    function setSimulateSwapFailure(bool simulate) external {
        simulateSwapFailure = simulate;
    }

    /// @notice Reset all mock state
    function reset() external {
        mockPoolAddress = address(0);
        mockReserve0 = 0;
        mockReserve1 = 0;
        mockToken0 = address(0);
        mockToken1 = address(0);
        mockAmountOut = 0;
        simulatePoolNotFound = false;
        simulateInvalidReserves = false;
        simulateSwapFailure = false;
        swapExecutionCount = 0;
        delete lastSwap;
    }

    /// @notice Get last swap pool address
    /// @return Pool address from last swap
    function getLastSwapPool() external view returns (address) {
        return lastSwap.pool;
    }

    /// @notice Get last swap token addresses
    /// @return tokenIn Input token from last swap
    /// @return tokenOut Output token from last swap
    function getLastSwapTokens() external view returns (address tokenIn, address tokenOut) {
        return (lastSwap.tokenIn, lastSwap.tokenOut);
    }

    /// @notice Get last swap amounts
    /// @return amountIn Input amount from last swap
    /// @return amountOutMin Minimum output from last swap
    function getLastSwapAmounts() external view returns (uint256 amountIn, uint256 amountOutMin) {
        return (lastSwap.amountIn, lastSwap.amountOutMin);
    }
}
