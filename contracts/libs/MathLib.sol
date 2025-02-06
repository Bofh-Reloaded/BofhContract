// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

library MathLib {
    uint256 private constant PRECISION = 1e6;
    uint256 private constant SQRT_PRECISION = 1e3;
    uint256 private constant CBRT_PRECISION = 1e2;

    // Enhanced sqrt using Newton's method with better initial guess
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        
        // Use bit shifts for better initial guess
        uint256 z = x;
        if (x > 0x100000000000000000000000000000000) {
            z = x >> 128;
            y = z << 64;
        } else {
            y = z << 32;
        }
        
        // Newton's method with optimized iteration count
        for (uint256 i = 0; i < 7; i++) {
            uint256 newY = (y + x / y) >> 1;
            if (newY >= y) break;
            y = newY;
        }
    }

    // Enhanced cbrt using Newton's method with dynamic precision
    function cbrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 r = x;
        uint256 p = x / 3;
        
        // Newton's method with precision-based early exit
        for (uint256 i = 0; i < 7; i++) {
            uint256 prev = r;
            r = (2 * r + x / (r * r)) / 3;
            
            // Check for convergence with dynamic precision
            if (prev > r) {
                if (prev - r < CBRT_PRECISION) break;
            } else {
                if (r - prev < CBRT_PRECISION) break;
            }
            
            if (r <= p) break;
            p = r;
        }
        return r;
    }

    // Enhanced geometric mean with overflow protection
    function geometricMean(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        
        // Use log approximation for very large numbers
        if (a > type(uint128).max || b > type(uint128).max) {
            uint256 logSum = (log2(a) + log2(b)) / 2;
            return exp2(logSum);
        }
        
        return sqrt(a * b);
    }

    // Log2 approximation using binary search
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

    // Exp2 implementation using bit manipulation
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

    // Calculate optimal amounts for n-way swaps
    function calculateOptimalAmount(
        uint256 amount,
        uint256 pathLength,
        uint256 position
    ) internal pure returns (uint256) {
        require(pathLength >= 3 && pathLength <= 5, "Invalid path length");
        
        // Golden ratio-based optimization
        if (pathLength == 4) {
            uint256 goldenRatio = 618034; // φ ≈ 0.618034
            return (amount * (PRECISION - (goldenRatio * position) / pathLength)) / PRECISION;
        } else if (pathLength == 5) {
            uint256 goldenRatioSquared = 381966; // φ2 ≈ 0.381966
            return (amount * (PRECISION - (goldenRatioSquared * position) / pathLength)) / PRECISION;
        }
        
        // Default to equal distribution for 3-way
        return (amount * (PRECISION - position * PRECISION / pathLength)) / PRECISION;
    }
}