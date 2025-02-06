// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "./BofhContractBase.sol";

contract BofhContractV2 is BofhContractBase {
    using MathLib for uint256;
    using PoolLib for PoolLib.PoolState;

    // Immutable state
    address private immutable baseToken;

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
    error InvalidPath();
    error InsufficientOutput();
    error ExcessiveSlippage();
    error PathTooLong();
    error DeadlineExpired();
    error InsufficientLiquidity();

    constructor(
        address baseToken_
    ) BofhContractBase(msg.sender, baseToken_) {
        baseToken = baseToken_;
    }

    // Internal swap execution
    function _executeSwap(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256) {
        // Validate inputs
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (path.length < 2 || path.length > MAX_PATH_LENGTH) revert InvalidPath();
        if (path.length != fees.length + 1) revert InvalidPath();
        if (path[0] != baseToken || path[path.length - 1] != baseToken) revert InvalidPath();

        // Initialize swap state
        SwapState memory state = SwapState({
            currentToken: baseToken,
            currentAmount: amountIn,
            cumulativeImpact: 0,
            historicalAmounts: new uint256[](path.length - 1),
            startTime: block.timestamp,
            gasUsed: 0
        });

        // Transfer initial amount from user
        require(
            IBEP20(baseToken).transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );

        // Execute swaps along the path
        for (uint256 i = 0; i < path.length - 1;) {
            uint256 gasStart = gasleft();
            
            state = executePathStep(
                state,
                path[i],
                path[i + 1],
                fees[i],
                i,
                path.length - 1
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
            path.length,
            amountIn,
            state.currentAmount,
            priceImpact
        );

        return state.currentAmount;
    }

    // Main swap execution function
    function executeSwap(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external override nonReentrant whenNotPaused returns (uint256) {
        return _executeSwap(path, fees, amountIn, minAmountOut, deadline);
    }

    // Optimized multi-path swap execution
    function executeMultiSwap(
        address[][] calldata paths,
        uint256[][] calldata fees,
        uint256[] calldata amounts,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external override nonReentrant whenNotPaused returns (uint256[] memory) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        
        uint256[] memory outputs = new uint256[](paths.length);
        uint256 totalInput = 0;
        uint256 totalOutput = 0;

        // Execute each path
        for (uint256 i = 0; i < paths.length;) {
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
        // Analyze pool state
        PoolLib.PoolState memory pool = PoolLib.analyzePool(
            tokenIn, // Using tokenIn as pool address since it's passed directly in path
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

        // Execute optimized swap
        require(
            IBEP20(tokenIn).approve(tokenIn, optimalAmount),
            "Approve failed"
        );

        uint256 balanceBefore = IBEP20(tokenOut).balanceOf(address(this));
        
        IGenericPair(tokenIn).swap(
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
}