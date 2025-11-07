// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "./BofhContractBase.sol";
import "../interfaces/ISwapInterfaces.sol";

contract BofhContractV2 is BofhContractBase {
    using MathLib for uint256;
    using PoolLib for PoolLib.PoolState;

    // Immutable state
    address private immutable baseToken;
    address private immutable factory;

    // Optimized swap state tracking
    struct SwapState {
        address currentToken;
        uint256 currentAmount;
        uint256 cumulativeImpact;
        uint256[] historicalAmounts;
        uint256 startTime;
        uint256 gasUsed;
    }

    // Custom errors
    // Existing errors
    error InvalidPath();
    error InsufficientOutput();
    error ExcessiveSlippage();
    error PathTooLong();
    error DeadlineExpired();
    error InsufficientLiquidity();

    // New input validation errors (Issue #8)
    error InvalidAddress();
    error InvalidAmount();
    error InvalidArrayLength();
    error InvalidFee();

    constructor(
        address baseToken_,
        address factory_
    ) BofhContractBase(msg.sender, baseToken_) {
        require(baseToken_ != address(0), "Invalid base token");
        require(factory_ != address(0), "Invalid factory");
        baseToken = baseToken_;
        factory = factory_;
    }

    /// @dev Internal function to validate swap inputs (Issue #8)
    /// @param path Token swap path
    /// @param fees Fee array
    /// @param amountIn Input amount
    /// @param minAmountOut Minimum output amount
    /// @param deadline Transaction deadline
    /// @return pathLength Length of the path for gas optimization
    function _validateSwapInputs(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) private view returns (uint256 pathLength) {
        // 1. Deadline validation
        if (deadline == 0) revert InvalidAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();

        // 2. Array length validation
        pathLength = path.length;
        if (pathLength == 0) revert InvalidArrayLength();
        if (pathLength < 2 || pathLength > MAX_PATH_LENGTH) revert InvalidPath();
        if (pathLength != fees.length + 1) revert InvalidArrayLength();

        // 3. Amount validation
        if (amountIn == 0) revert InvalidAmount();
        if (minAmountOut == 0) revert InvalidAmount();

        // 4. Path address validation
        for (uint256 i = 0; i < pathLength;) {
            if (path[i] == address(0)) revert InvalidAddress();
            unchecked { ++i; }
        }

        // 5. Path structure validation
        if (path[0] != baseToken || path[pathLength - 1] != baseToken) revert InvalidPath();

        // 6. Fee validation (fees must be reasonable, max 100% = 10000 bps)
        uint256 maxFeeBps = 10000; // 100%
        for (uint256 i = 0; i < fees.length;) {
            if (fees[i] > maxFeeBps) revert InvalidFee();
            unchecked { ++i; }
        }
    }

    // Internal swap execution
    function _executeSwap(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256) {
        // Comprehensive input validation (Issue #8)
        uint256 pathLength = _validateSwapInputs(path, fees, amountIn, minAmountOut, deadline);

        // Initialize swap state
        uint256 lastIndex = pathLength - 1;
        SwapState memory state = SwapState({
            currentToken: baseToken,
            currentAmount: amountIn,
            cumulativeImpact: 0,
            historicalAmounts: new uint256[](lastIndex),
            startTime: block.timestamp,
            gasUsed: 0
        });

        // Transfer initial amount from user
        require(
            IBEP20(baseToken).transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );

        // Execute swaps along the path
        for (uint256 i = 0; i < lastIndex;) {
            uint256 gasStart = gasleft();

            state = executePathStep(
                state,
                path[i],
                path[i + 1],
                fees[i],
                i,
                lastIndex
            );
            
            unchecked {
                state.gasUsed += gasStart - gasleft();
                ++i;
            }
        }

        // Validate final output
        if (state.currentAmount < minAmountOut) revert InsufficientOutput();
        
        // Calculate total price impact and validate
        uint256 priceImpact = (state.cumulativeImpact * PRECISION) / amountIn;
        if (priceImpact > maxPriceImpact) revert ExcessiveSlippage();

        // Transfer profit to user
        require(
            IBEP20(baseToken).transfer(msg.sender, state.currentAmount),
            "Transfer failed"
        );

        emit SwapExecuted(
            msg.sender,
            pathLength,
            amountIn,
            state.currentAmount,
            priceImpact
        );

        return state.currentAmount;
    }

    /// @notice Execute a swap through a single path
    /// @dev Implements virtual function from BofhContractBase with required security modifiers
    /// @dev Protected by: nonReentrant (reentrancy guard), whenNotPaused (circuit breaker), antiMEV (flash loan protection)
    /// @dev MEV Protection (Issue #9): Limits transactions per block and enforces delay between transactions
    /// @param path Array of token addresses representing the swap path
    /// @param fees Array of fee amounts for each swap step
    /// @param amountIn Input amount for the swap
    /// @param minAmountOut Minimum acceptable output amount (slippage protection)
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return The actual output amount from the swap
    function executeSwap(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external override nonReentrant whenNotPaused antiMEV returns (uint256) {
        return _executeSwap(path, fees, amountIn, minAmountOut, deadline);
    }

    /// @notice Execute multiple swaps through different paths in parallel
    /// @dev Implements virtual function from BofhContractBase with required security modifiers
    /// @dev Protected by: nonReentrant (reentrancy guard), whenNotPaused (circuit breaker)
    /// @dev NOTE: antiMEV modifier not applied here due to stack depth limitations
    /// @param paths Array of swap paths, each path is an array of token addresses
    /// @param fees Array of fee arrays, one per path
    /// @param amounts Array of input amounts, one per path
    /// @param minAmounts Array of minimum output amounts, one per path
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return Array of actual output amounts from each swap path
    function executeMultiSwap(
        address[][] calldata paths,
        uint256[][] calldata fees,
        uint256[] calldata amounts,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external override nonReentrant whenNotPaused returns (uint256[] memory) {
        // === Comprehensive Input Validation (Issue #8) ===

        // 1. Deadline validation
        if (deadline == 0) revert InvalidAmount();
        if (block.timestamp > deadline) revert DeadlineExpired();

        // 2. Array length consistency validation
        uint256 numPaths = paths.length;
        if (numPaths == 0) revert InvalidArrayLength();
        if (numPaths != fees.length) revert InvalidArrayLength();
        if (numPaths != amounts.length) revert InvalidArrayLength();
        if (numPaths != minAmounts.length) revert InvalidArrayLength();

        // 3. Per-path validation (will be done in _executeSwap for each path)
        // Note: Individual path validations happen in _executeSwap

        uint256[] memory outputs = new uint256[](numPaths);
        uint256 totalInput = 0;
        uint256 totalOutput = 0;

        // Execute each path
        for (uint256 i = 0; i < numPaths;) {
            unchecked {
                totalInput += amounts[i];
                outputs[i] = _executeSwap(
                    paths[i],
                    fees[i],
                    amounts[i],
                    minAmounts[i],
                    deadline
                );
                totalOutput += outputs[i];
                ++i;
            }
        }

        // Verify total profitability
        require(totalOutput > totalInput, "Unprofitable execution");
        
        return outputs;
    }

    // Internal optimized swap step execution
    function executePathStep(
        SwapState memory state,
        address tokenIn,
        address tokenOut,
        uint256 fee,
        uint256 stepIndex,
        uint256 pathLength
    ) private returns (SwapState memory) {
        // Get the pair address for these two tokens
        address pairAddress = _getPair(tokenIn, tokenOut);

        // Analyze pool state using the pair address
        PoolLib.PoolState memory pool = PoolLib.analyzePool(
            pairAddress,
            tokenIn,
            state.currentAmount,
            block.timestamp
        );

        // Calculate optimal swap parameters
        PoolLib.SwapParams memory params = PoolLib.SwapParams({
            amountIn: state.currentAmount,
            minAmountOut: 0, // Calculated dynamically
            maxPriceImpact: maxPriceImpact,
            deadline: block.timestamp + 1, // Immediate execution
            maxSlippage: MAX_SLIPPAGE
        });

        // Validate pool state
        require(PoolLib.validateSwap(pool, params), "Invalid swap parameters");

        // Calculate optimal amounts
        (uint256 optimalAmount, uint256 expectedOutput) =
            PoolLib.calculateOptimalSwapAmount(pool, params);

        // Update state with optimal values
        state.currentAmount = optimalAmount;
        state.historicalAmounts[stepIndex] = expectedOutput;
        state.cumulativeImpact += pool.priceImpact;

        // Approve the pair contract to spend our tokens
        require(
            IBEP20(tokenIn).approve(pairAddress, optimalAmount),
            "Approve failed"
        );

        uint256 balanceBefore = IBEP20(tokenOut).balanceOf(address(this));

        // Execute swap on the pair contract
        IGenericPair(pairAddress).swap(
            pool.sellingToken0 ? 0 : expectedOutput,
            pool.sellingToken0 ? expectedOutput : 0,
            address(this),
            new bytes(0)
        );

        uint256 balanceAfter = IBEP20(tokenOut).balanceOf(address(this));
        state.currentAmount = balanceAfter - balanceBefore;
        state.currentToken = tokenOut;

        return state;
    }

    // View functions
    function getOptimalPathMetrics(
        address[] calldata path,
        uint256[] calldata amounts
    ) external view returns (
        uint256 expectedOutput,
        uint256 priceImpact,
        uint256 optimalityScore
    ) {
        require(path.length >= 2 && path.length <= MAX_PATH_LENGTH, "Invalid path length");
        
        uint256 pathLength = path.length - 1;
        uint256 cumulativeImpact = 0;
        expectedOutput = amounts[0];
        
        for (uint256 i = 0; i < pathLength;) {
            PoolLib.PoolState memory pool = PoolLib.analyzePool(
                path[i],
                path[i + 1],
                expectedOutput,
                block.timestamp
            );
            
            cumulativeImpact += pool.priceImpact;
            expectedOutput = (expectedOutput * (PRECISION - pool.priceImpact)) / PRECISION;
            
            unchecked { ++i; }
        }
        
        priceImpact = cumulativeImpact;
        optimalityScore = (expectedOutput * PRECISION) / amounts[0];

        return (expectedOutput, priceImpact, optimalityScore);
    }

    /// @notice Get pair address for two tokens from factory
    /// @dev Helper function to resolve pair address from token addresses
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @return pair The pair contract address
    function _getPair(address tokenA, address tokenB) internal view returns (address pair) {
        pair = IFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Pair does not exist");
    }

    /// @notice Get the base token address used for swaps
    /// @return The address of the base token
    function getBaseToken() external view returns (address) {
        return baseToken;
    }

    /// @notice Get the factory address
    /// @return The address of the factory
    function getFactory() external view returns (address) {
        return factory;
    }
}