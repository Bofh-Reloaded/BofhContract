// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "./IDEXAdapter.sol";
import "../interfaces/ISwapInterfaces.sol";

/// @title PancakeSwapAdapter
/// @notice Adapter for PancakeSwap V2 on Binance Smart Chain
/// @dev Implements IDEXAdapter for PancakeSwap V2 pools (Uniswap V2 fork with 0.25% fee)
/// @custom:pattern Adapter Pattern - Wraps PancakeSwap functionality in standard interface
/// @custom:network BSC (Binance Smart Chain)
contract PancakeSwapAdapter is IDEXAdapter {
    /// @notice PancakeSwap V2 factory address for pair lookups
    address public immutable factory;

    /// @notice Fee in basis points (25 = 0.25% for PancakeSwap V2)
    uint256 private constant FEE_BPS = 25;

    /// @notice Fee numerator (9975 out of 10000 after 0.25% fee)
    uint256 private constant FEE_NUMERATOR = 9975;

    /// @notice Fee denominator
    uint256 private constant FEE_DENOMINATOR = 10000;

    /// @notice Deploy PancakeSwapAdapter with factory address
    /// @param factory_ PancakeSwap V2 factory address
    /// @custom:bsc-mainnet 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73
    /// @custom:bsc-testnet 0x6725F303b657a9451d8BA641348b6761A6CC7a17
    constructor(address factory_) {
        require(factory_ != address(0), "Invalid factory");
        factory = factory_;
    }

    /// @inheritdoc IDEXAdapter
    function getPoolAddress(address tokenA, address tokenB)
        external
        view
        override
        returns (address pool)
    {
        if (tokenA == address(0) || tokenB == address(0)) revert InvalidTokens();
        pool = IFactory(factory).getPair(tokenA, tokenB);
        if (pool == address(0)) revert PoolNotFound();
        return pool;
    }

    /// @inheritdoc IDEXAdapter
    function getReserves(address pool)
        external
        view
        override
        returns (
            uint256 reserve0,
            uint256 reserve1,
            uint256 blockTimestampLast
        )
    {
        if (pool == address(0)) revert InvalidTokens();

        (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) =
            IGenericPair(pool).getReserves();

        if (_reserve0 == 0 || _reserve1 == 0) revert InvalidReserves();

        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    /// @inheritdoc IDEXAdapter
    function getTokens(address pool)
        external
        view
        override
        returns (address token0, address token1)
    {
        if (pool == address(0)) revert InvalidTokens();

        token0 = IGenericPair(pool).token0();
        token1 = IGenericPair(pool).token1();

        if (token0 == address(0) || token1 == address(0)) revert InvalidTokens();

        return (token0, token1);
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
        if (pool == address(0)) revert InvalidTokens();
        if (tokenIn == address(0) || tokenOut == address(0)) revert InvalidTokens();
        if (amountIn == 0) revert SwapFailed();
        if (to == address(0)) revert InvalidTokens();

        // Determine if tokenIn is token0
        bool isToken0 = tokenIn == IGenericPair(pool).token0();
        require(isToken0 || tokenIn == IGenericPair(pool).token1(), "Token not in pool");

        // Get reserves and calculate output
        (uint256 reserve0, uint256 reserve1, ) = IGenericPair(pool).getReserves();
        if (reserve0 == 0 || reserve1 == 0) revert InvalidReserves();

        amountOut = _getAmountOut(
            amountIn,
            isToken0 ? reserve0 : reserve1,
            isToken0 ? reserve1 : reserve0
        );

        if (amountOut < amountOutMin) revert SwapFailed();

        // Transfer tokens to pool
        require(
            IBEP20(tokenIn).transferFrom(msg.sender, pool, amountIn),
            "Transfer to pool failed"
        );

        // Execute swap
        IGenericPair(pool).swap(
            isToken0 ? 0 : amountOut,
            isToken0 ? amountOut : 0,
            to,
            new bytes(0)
        );

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, pool);

        return amountOut;
    }

    /// @inheritdoc IDEXAdapter
    function getAmountOut(
        address pool,
        address tokenIn,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        if (pool == address(0)) revert InvalidTokens();
        if (tokenIn == address(0)) revert InvalidTokens();
        if (amountIn == 0) return 0;

        // Get pool tokens
        address token0 = IGenericPair(pool).token0();
        address token1 = IGenericPair(pool).token1();

        // Determine swap direction
        bool isToken0 = tokenIn == token0;
        bool isToken1 = tokenIn == token1;
        require(isToken0 || isToken1, "Token not in pool");

        // Get reserves
        (uint256 reserve0, uint256 reserve1, ) = IGenericPair(pool).getReserves();
        if (reserve0 == 0 || reserve1 == 0) revert InvalidReserves();

        uint256 reserveIn = isToken0 ? reserve0 : reserve1;
        uint256 reserveOut = isToken0 ? reserve1 : reserve0;

        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /// @inheritdoc IDEXAdapter
    function getDEXName() external pure override returns (string memory) {
        return "PancakeSwap V2";
    }

    /// @inheritdoc IDEXAdapter
    function getFactory() external view override returns (address) {
        return factory;
    }

    /// @inheritdoc IDEXAdapter
    function getFeeBps() external pure override returns (uint256) {
        return FEE_BPS;
    }

    /// @inheritdoc IDEXAdapter
    function isValidPool(address pool) external view override returns (bool) {
        if (pool == address(0)) return false;

        try IGenericPair(pool).getReserves() returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32
        ) {
            return reserve0 > 0 && reserve1 > 0;
        } catch {
            return false;
        }
    }

    /// @notice Internal function to calculate output amount using constant product formula
    /// @dev Formula: amountOut = (amountIn * 9975 * reserveOut) / (reserveIn * 10000 + amountIn * 9975)
    /// @dev PancakeSwap uses 0.25% fee (lower than Uniswap's 0.3%)
    /// @param amountIn Input amount
    /// @param reserveIn Input token reserve
    /// @param reserveOut Output token reserve
    /// @return amountOut Expected output amount
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) private pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
    }
}
