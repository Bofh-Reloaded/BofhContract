// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "../interfaces/IBofhContract.sol";

/// @title MockBofhContract
/// @notice Mock implementation of IBofhContract for testing external integrations
/// @dev Provides simplified swap logic without actual token transfers
/// @custom:testing Use this contract to test integrations without deploying full BofhContractV2
contract MockBofhContract is IBofhContract {
    address private immutable baseToken;
    address private immutable factory;

    /// @notice Counter for tracking swap executions in tests
    uint256 public swapCounter;

    /// @notice Counter for tracking multi-swap executions in tests
    uint256 public multiSwapCounter;

    /// @notice Last swap parameters for testing verification
    struct LastSwap {
        address[] path;
        uint256[] fees;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        uint256 outputAmount;
    }

    /// @notice Store last swap parameters for testing
    LastSwap public lastSwap;

    /// @notice Configurable mock output amount (default: returns minAmountOut)
    uint256 public mockOutputAmount;

    /// @notice Flag to simulate swap failure
    bool public shouldFail;

    /// @notice Flag to simulate insufficient output
    bool public simulateInsufficientOutput;

    /// @notice Deploy MockBofhContract with base token and factory
    /// @param baseToken_ Base token address
    /// @param factory_ Factory address
    constructor(address baseToken_, address factory_) {
        baseToken = baseToken_;
        factory = factory_;
        mockOutputAmount = 0; // 0 means use minAmountOut
    }

    /// @notice Execute a mock swap (no actual token transfers)
    /// @dev Stores parameters in lastSwap for testing verification
    /// @param path Swap path
    /// @param fees Fee array
    /// @param amountIn Input amount
    /// @param minAmountOut Minimum output amount
    /// @param deadline Transaction deadline
    /// @return Output amount (mockOutputAmount if set, otherwise minAmountOut)
    function executeSwap(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external override returns (uint256) {
        // Simulate failure if configured
        if (shouldFail) {
            revert("Mock failure");
        }

        // Validate deadline
        if (block.timestamp > deadline) revert DeadlineExpired();

        // Validate path
        if (path.length == 0) revert InvalidPath();
        if (path[0] != baseToken || path[path.length - 1] != baseToken) {
            revert InvalidPath();
        }

        // Validate arrays
        if (path.length != fees.length + 1) revert InvalidArrayLength();

        // Validate amounts
        if (amountIn == 0) revert InvalidAmount();
        if (minAmountOut == 0) revert InvalidAmount();

        // Increment counter
        swapCounter++;

        // Determine output amount
        uint256 outputAmount = mockOutputAmount > 0 ? mockOutputAmount : minAmountOut;

        // Simulate insufficient output
        if (simulateInsufficientOutput) {
            outputAmount = minAmountOut - 1;
            revert InsufficientOutput();
        }

        // Store last swap parameters
        delete lastSwap.path;
        delete lastSwap.fees;
        for (uint256 i = 0; i < path.length; i++) {
            lastSwap.path.push(path[i]);
        }
        for (uint256 i = 0; i < fees.length; i++) {
            lastSwap.fees.push(fees[i]);
        }
        lastSwap.amountIn = amountIn;
        lastSwap.minAmountOut = minAmountOut;
        lastSwap.deadline = deadline;
        lastSwap.outputAmount = outputAmount;

        // Emit event (use 0 for price impact in mock)
        emit SwapExecuted(msg.sender, path.length, amountIn, outputAmount, 0);

        return outputAmount;
    }

    /// @notice Execute mock multi-swap (no actual token transfers)
    /// @dev Simply calls executeSwap for each path
    /// @param paths Array of swap paths
    /// @param fees Array of fee arrays
    /// @param amounts Array of input amounts
    /// @param minAmounts Array of minimum output amounts
    /// @param deadline Transaction deadline
    /// @return Array of output amounts
    function executeMultiSwap(
        address[][] calldata paths,
        uint256[][] calldata fees,
        uint256[] calldata amounts,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external override returns (uint256[] memory) {
        // Validate arrays
        if (paths.length == 0) revert InvalidArrayLength();
        if (paths.length != fees.length) revert InvalidArrayLength();
        if (paths.length != amounts.length) revert InvalidArrayLength();
        if (paths.length != minAmounts.length) revert InvalidArrayLength();

        // Validate deadline
        if (block.timestamp > deadline) revert DeadlineExpired();

        // Increment counter
        multiSwapCounter++;

        uint256[] memory outputs = new uint256[](paths.length);

        // Execute each swap
        for (uint256 i = 0; i < paths.length; i++) {
            // Validate individual path
            if (paths[i].length == 0) revert InvalidPath();
            if (paths[i][0] != baseToken || paths[i][paths[i].length - 1] != baseToken) {
                revert InvalidPath();
            }

            // Determine output
            uint256 output = mockOutputAmount > 0 ? mockOutputAmount : minAmounts[i];

            // Check profitability (simplified)
            if (output <= amounts[i]) revert UnprofitableExecution();

            outputs[i] = output;

            // Emit event for each swap
            emit SwapExecuted(msg.sender, paths[i].length, amounts[i], output, 0);
        }

        return outputs;
    }

    /// @notice Mock implementation of getOptimalPathMetrics
    /// @dev Returns simplified metrics for testing
    /// @param path Swap path
    /// @param amounts Amount array
    /// @return expectedOutput Equal to input amount (no price impact)
    /// @return priceImpact Always returns 0 (no impact in mock)
    /// @return optimalityScore Always returns 1e6 (100% = break-even)
    function getOptimalPathMetrics(
        address[] calldata path,
        uint256[] calldata amounts
    )
        external
        pure
        override
        returns (uint256 expectedOutput, uint256 priceImpact, uint256 optimalityScore)
    {
        if (path.length < 2) revert InvalidPath();
        if (amounts.length == 0) revert InvalidArrayLength();

        // Mock implementation: no price impact
        expectedOutput = amounts[0];
        priceImpact = 0;
        optimalityScore = 1e6; // 100% (break-even)

        return (expectedOutput, priceImpact, optimalityScore);
    }

    /// @notice Get base token address
    /// @return Base token address
    function getBaseToken() external view override returns (address) {
        return baseToken;
    }

    /// @notice Get factory address
    /// @return Factory address
    function getFactory() external view override returns (address) {
        return factory;
    }

    // ============================================
    // TEST HELPER FUNCTIONS
    // ============================================

    /// @notice Set mock output amount for testing
    /// @param amount Output amount to return (0 = use minAmountOut)
    function setMockOutputAmount(uint256 amount) external {
        mockOutputAmount = amount;
    }

    /// @notice Configure swap failure simulation
    /// @param fail True to simulate failure, false for normal operation
    function setShouldFail(bool fail) external {
        shouldFail = fail;
    }

    /// @notice Configure insufficient output simulation
    /// @param simulate True to simulate insufficient output
    function setSimulateInsufficientOutput(bool simulate) external {
        simulateInsufficientOutput = simulate;
    }

    /// @notice Reset mock state for testing
    function reset() external {
        swapCounter = 0;
        multiSwapCounter = 0;
        mockOutputAmount = 0;
        shouldFail = false;
        simulateInsufficientOutput = false;
        delete lastSwap;
    }

    /// @notice Get last swap path for testing verification
    /// @return Array of addresses from last swap path
    function getLastSwapPath() external view returns (address[] memory) {
        return lastSwap.path;
    }

    /// @notice Get last swap fees for testing verification
    /// @return Array of fees from last swap
    function getLastSwapFees() external view returns (uint256[] memory) {
        return lastSwap.fees;
    }

    /// @notice Event stub - defined in IBofhContract but emitted here for compatibility
    event SwapExecuted(
        address indexed initiator,
        uint256 pathLength,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 priceImpact
    );
}
