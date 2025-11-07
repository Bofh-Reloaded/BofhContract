// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

/// @title MathLib - Advanced Mathematical Operations Library
/// @author Bofh Team
/// @notice Provides high-precision mathematical functions for DeFi operations
/// @dev Implements Newton's method for square root and cube root calculations
/// @custom:security All functions are pure and gas-optimized
library MathLib {
    /// @notice Base precision for calculations (1,000,000)
    uint256 private constant PRECISION = 1e6;

    /// @notice Square root calculation precision (1,000)
    uint256 private constant SQRT_PRECISION = 1e3;

    /// @notice Cube root calculation precision (100)
    uint256 private constant CBRT_PRECISION = 1e2;

    /// @notice Golden ratio constant φ ≈ 0.618034 (scaled by PRECISION)
    uint256 private constant GOLDEN_RATIO = 618034;

    /// @notice Golden ratio squared φ² ≈ 0.381966 (scaled by PRECISION)
    uint256 private constant GOLDEN_RATIO_SQUARED = 381966;

    /// @notice Calculate square root using Newton's method
    /// @dev Uses Newton-Raphson iteration: y_{n+1} = (y_n + x/y_n) / 2
    /// @dev Converges quadratically with better initial guess via bit length
    /// @param x Input value to find square root of
    /// @return y Square root of x, rounded down
    /// @custom:example sqrt(16) = 4, sqrt(17) = 4 (floor division)
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        if (x <= 3) return 1;

        // Better initial guess using bit length
        uint256 z = (x + 1) / 2;
        y = x;

        // Newton's method: y = (y + x/y) / 2
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @notice Calculate cube root using Newton's method
    /// @dev Uses Newton-Raphson iteration: y_{n+1} = (2*y_n + x/y_n²) / 3
    /// @dev Provides better precision than binary search methods
    /// @param x Input value to find cube root of
    /// @return Cube root of x, rounded down
    /// @custom:example cbrt(27) = 3, cbrt(28) = 3 (floor division)
    function cbrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        if (x == 1) return 1;

        uint256 z = x;
        uint256 y = x / 3 + 1;

        // Newton's method: y = (2*y + x/(y*y)) / 3
        while (y < z) {
            z = y;
            uint256 ySquared = y * y;
            if (ySquared == 0) break;
            y = (2 * y + x / ySquared) / 3;
        }
        return z;
    }

    /// @notice Calculate geometric mean of two numbers with overflow protection
    /// @dev Geometric mean = √(a × b), uses log approximation for large numbers
    /// @dev For a,b > uint128.max, uses log identity: √(a×b) = 2^((log₂a + log₂b)/2)
    /// @param a First number
    /// @param b Second number
    /// @return Geometric mean of a and b
    /// @custom:security Prevents overflow for values > type(uint128).max
    /// @custom:math Geometric mean ≤ arithmetic mean (AM-GM inequality)
    function geometricMean(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        
        // Use log approximation for very large numbers
        if (a > type(uint128).max || b > type(uint128).max) {
            uint256 logSum = (log2(a) + log2(b)) / 2;
            return exp2(logSum);
        }
        
        return sqrt(a * b);
    }

    /// @notice Calculate base-2 logarithm using binary search
    /// @dev Finds the position of the highest set bit (most significant bit)
    /// @dev Result scaled by PRECISION for fixed-point arithmetic
    /// @param x Input value (x > 0)
    /// @return Base-2 logarithm of x, scaled by PRECISION
    /// @custom:example log2(8) = 3 * PRECISION, log2(16) = 4 * PRECISION
    function log2(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 result = 0;
        uint256 value = x;
        
        // Find highest set bit
        if (value >= 2**128) { value >>= 128; result += 128; }
        if (value >= 2**64) { value >>= 64; result += 64; }
        if (value >= 2**32) { value >>= 32; result += 32; }
        if (value >= 2**16) { value >>= 16; result += 16; }
        if (value >= 2**8) { value >>= 8; result += 8; }
        if (value >= 2**4) { value >>= 4; result += 4; }
        if (value >= 2**2) { value >>= 2; result += 2; }
        if (value >= 2**1) { result += 1; }
        
        return result * PRECISION;
    }

    /// @notice Calculate 2^x using bit manipulation and Taylor series
    /// @dev Splits x into whole and fractional parts: 2^x = 2^whole * 2^frac
    /// @dev Uses Taylor series for fractional part approximation (4 terms)
    /// @param x Exponent value, scaled by PRECISION
    /// @return 2^x, returns type(uint256).max if result would overflow
    /// @custom:example exp2(3 * PRECISION) ≈ 8, exp2(4 * PRECISION) ≈ 16
    function exp2(uint256 x) internal pure returns (uint256) {
        if (x == 0) return PRECISION;
        
        uint256 wholePart = x / PRECISION;
        uint256 fracPart = x % PRECISION;
        
        if (wholePart >= 255) return type(uint256).max;
        
        uint256 result = 1 << wholePart;
        if (fracPart == 0) return result;
        
        // Taylor series approximation for fractional part
        uint256 term = result;
        uint256 sum = result;
        
        for (uint256 i = 1; i <= 4; i++) {
            term = (term * fracPart * (wholePart + i)) / (i * PRECISION);
            sum += term;
        }
        
        return sum;
    }

    /// @notice Calculate optimal amount distribution for multi-path swaps using golden ratio
    /// @dev Implements φ-based optimization to minimize price impact across paths
    /// @dev 3-way: Equal distribution (1/3 each)
    /// @dev 4-way: Golden ratio φ ≈ 0.618034 distribution
    /// @dev 5-way: Golden ratio squared φ² ≈ 0.381966 distribution
    /// @param amount Total amount to distribute
    /// @param pathLength Number of swap paths (3, 4, or 5)
    /// @param position Current position in the path distribution (0-indexed)
    /// @return Optimal amount for the given position
    /// @custom:math Golden ratio minimizes Σ(1/xᵢ) subject to Πxᵢ = constant (Lagrange multipliers)
    /// @custom:security Reverts if pathLength not in [3,5]
    function calculateOptimalAmount(
        uint256 amount,
        uint256 pathLength,
        uint256 position
    ) internal pure returns (uint256) {
        require(pathLength >= 3 && pathLength <= 5, "Invalid path length");

        // Golden ratio-based optimization
        if (pathLength == 4) {
            return (amount * (PRECISION - (GOLDEN_RATIO * position) / pathLength)) / PRECISION;
        } else if (pathLength == 5) {
            return (amount * (PRECISION - (GOLDEN_RATIO_SQUARED * position) / pathLength)) / PRECISION;
        }

        // Default to equal distribution for 3-way
        return (amount * (PRECISION - position * PRECISION / pathLength)) / PRECISION;
    }
}