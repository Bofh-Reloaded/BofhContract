// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "./MathLib.sol";
import "../interfaces/ISwapInterfaces.sol";

library PoolLib {
    uint256 private constant PRECISION = 1e6;
    uint256 private constant MIN_POOL_LIQUIDITY = 1000;

    struct PoolState {
        uint256 reserveIn;
        uint256 reserveOut;
        bool sellingToken0;
        address tokenOut;
        uint256 priceImpact;
        uint256 depth;
        uint256 volatility;
        uint256 lastUpdateTimestamp;
        uint256 volumeAccumulator;
    }

    struct SwapParams {
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 maxPriceImpact;
        uint256 deadline;
        uint256 maxSlippage;
    }

    // Enhanced pool analysis with volume tracking and volatility estimation
    function analyzePool(
        address pool,
        address tokenIn,
        uint256 amountIn,
        uint256 timestamp
    ) internal view returns (PoolState memory state) {
        (uint256 reserve0, uint256 reserve1, uint256 lastTimestamp) = 
            IGenericPair(pool).getReserves();
        
        address token1 = IGenericPair(pool).token1();
        state.tokenOut = token1;
        
        if (tokenIn != token1) {
            address token0 = IGenericPair(pool).token0();
            require(tokenIn == token0, "Invalid token");
            state.reserveIn = reserve0;
            state.reserveOut = reserve1;
            state.sellingToken0 = true;
        } else {
            state.tokenOut = IGenericPair(pool).token0();
            state.reserveIn = reserve1;
            state.reserveOut = reserve0;
            state.sellingToken0 = false;
        }

        require(
            state.reserveIn >= MIN_POOL_LIQUIDITY && 
            state.reserveOut >= MIN_POOL_LIQUIDITY,
            "Insufficient liquidity"
        );

        // Calculate advanced metrics
        state.depth = MathLib.sqrt(state.reserveIn * state.reserveOut);
        state.volatility = calculateVolatility(state, lastTimestamp, timestamp);
        state.priceImpact = calculatePriceImpact(amountIn, state);
        state.lastUpdateTimestamp = timestamp;
        
        return state;
    }

    // Enhanced price impact calculation with slippage protection
    function calculatePriceImpact(
        uint256 amountIn,
        PoolState memory pool
    ) internal pure returns (uint256) {
        if (amountIn == 0) return 0;
        
        uint256 k = pool.reserveIn * pool.reserveOut;
        uint256 newReserveIn = pool.reserveIn + amountIn;
        uint256 newReserveOut = k / newReserveIn; // New reserve after swap
        
        // Calculate price impact as percentage change
        uint256 oldPrice = (pool.reserveOut * PRECISION) / pool.reserveIn;
        uint256 newPrice = (newReserveOut * PRECISION) / newReserveIn;
        
        if (newPrice >= oldPrice) return 0;
        
        return ((oldPrice - newPrice) * PRECISION) / oldPrice;
    }

    // Volatility calculation using exponential moving average
    function calculateVolatility(
        PoolState memory pool,
        uint256 lastTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        if (lastTimestamp >= currentTimestamp) return pool.volatility;
        
        uint256 timeDelta = currentTimestamp - lastTimestamp;
        if (timeDelta == 0) return pool.volatility;
        
        // Calculate price change
        uint256 currentPrice = (pool.reserveOut * PRECISION) / pool.reserveIn;
        uint256 priceChange = pool.volatility > currentPrice ? 
            pool.volatility - currentPrice : 
            currentPrice - pool.volatility;
            
        // Exponential decay factor based on time delta
        uint256 decay = MathLib.exp2(PRECISION * timeDelta / 1 days);
        
        return (pool.volatility * decay + priceChange * (PRECISION - decay)) / PRECISION;
    }

    // Calculate optimal swap amounts considering pool depth and volatility
    function calculateOptimalSwapAmount(
        PoolState memory pool,
        SwapParams memory params
    ) internal pure returns (uint256 optimalAmount, uint256 expectedOutput) {
        // Base optimal amount using square root formula
        optimalAmount = MathLib.sqrt(
            (params.amountIn * pool.reserveIn * PRECISION) / 
            (pool.depth * (PRECISION + pool.volatility))
        );
        
        // Adjust for price impact
        uint256 priceImpact = calculatePriceImpact(optimalAmount, pool);
        if (priceImpact > params.maxPriceImpact) {
            // Reduce amount to meet price impact constraint
            optimalAmount = (optimalAmount * params.maxPriceImpact) / priceImpact;
        }
        
        // Calculate expected output
        uint256 numerator = optimalAmount * pool.reserveOut;
        uint256 denominator = pool.reserveIn + optimalAmount;
        expectedOutput = (numerator * (PRECISION - params.maxSlippage)) / (denominator * PRECISION);
        
        // Ensure minimum output is met
        require(expectedOutput >= params.minAmountOut, "Insufficient output amount");
        
        return (optimalAmount, expectedOutput);
    }

    // Validate pool state and parameters
    function validateSwap(
        PoolState memory pool,
        SwapParams memory params
    ) internal view returns (bool) {
        require(params.deadline >= block.timestamp, "Deadline expired");
        require(params.amountIn > 0, "Invalid amount");
        require(params.maxPriceImpact <= PRECISION / 10, "Excessive price impact"); // Max 10%
        
        uint256 priceImpact = calculatePriceImpact(params.amountIn, pool);
        require(priceImpact <= params.maxPriceImpact, "Price impact too high");
        
        // Check for extreme pool conditions
        require(pool.volatility <= PRECISION / 2, "Pool too volatile"); // Max 50% volatility
        require(pool.depth >= MIN_POOL_LIQUIDITY * 10, "Pool too shallow");
        
        return true;
    }
}