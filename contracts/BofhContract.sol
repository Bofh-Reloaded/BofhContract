pragma solidity >= 0.6.12;

// Minimal functionality of the BSC token we are going to use
interface IBEP20 {
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// helper methods for interacting with ERC20 tokens and sending
// ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

// ROUTER INTERFACE (reduced)

interface IPancakeRouter01 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


// BARE BONES generic Pair interface (works with Uniswap v2 descendents, so basically all of them)
interface IPancakePair {
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}

contract BofhContract {

    address private constant CAKE_V2_ROUTER = 0x10ed43c718714eb63d5aa57b78b54704e256024e;

    // THIS is the entry point
    function doCakeInternalSwaps(address[] calldata tokenPath  // array of LPs to be traversed (order of occurrence)
                                 , address startToken          // initial token (starting liquidity)
                                 , uint256 initialAmount       // balance of initial token to use
                                 , uint256 minProfit           // minimum yield to achieve, in startToken, othervise rollback
                                 )
    public
    {
        require(tokenPath[tokenPath.length-1] == startToken);
        IBEP20 startTokenI = IBEP20(startToken);
        startTokenI.transferFrom(msg.sender, address(this), initialAmount);
        startTokenI.approve(CAKE_V2_ROUTER, initialAmount);

        IPancakeRouter01(CAKE_V2_ROUTER).swapExactTokensForTokens(
                initialAmount
                , initialAmount+minProfit
                , tokenPath
                , msg.sender
                , block.timestamp+20);
        // CASOMAI SERVISSE:
        // startTokenI.transfer(msg.sender, startTokenI.balanceOf(address(this)));
    }


//    // **** SWAP ****
//    // requires the initial amount to have already been sent to the pair
//    function _swap(address pair,uint[] memory amounts, address[] memory path, address _to) internal virtual {
//        (address input, address output) = (path[0], path[1]);
//        (address token0,) = sortTokens(input, output);
//        uint amountOut = amounts[1];
//        (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
//        IPancakePair(pair).swap(
//            amount0Out, amount1Out, _to, new bytes(0)
//        );
//    }
//
//    function swapExactTokensForTokens(
//        address pair,
//        uint amountIn,
//        uint amountOutMin,
//        address[] memory path,
//        address to
//    ) public returns (uint256 amounts) {
//        amounts = getAmountsOut(pair, amountIn, path);
//        require(amounts >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
//        /*TransferHelper.safeApprove(path[0], pair, amountIn);
//        TransferHelper.safeTransferFrom(
//            path[0], from, pair, amountIn
//        );*/
//        // 1. transfer from last storage to next LP
//        IBEP20(path[0]).approve(pair, amountIn);
//        IBEP20(path[0]).transfer(pair, amountIn);
//        uint[] memory amountArray = new uint[](2);
//        amountArray[0] = amountIn;
//        amountArray[1] = amounts;
//        _swap(pair, amountArray, path, to);
//        // 2. transfer to next LP or to caller if this was last swap
//    }
//
//    function getAmountsOut(address pair, uint amountIn, address[] memory path) internal view returns (uint256) {
//        require(path.length == 2, 'INVALID_PATH');
//        (uint reserveIn, uint reserveOut) = getReserves(pair, path[0], path[1]);
//        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
//        return amountOut;
//    }
//
//    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
//    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
//        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
//        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
//        uint amountInWithFee = amountIn*998;
//        uint numerator = amountInWithFee* reserveOut;
//        uint denominator = reserveIn*1000 + amountInWithFee;
//        amountOut = numerator / denominator;
//    }
//
//    // fetches and sorts the reserves for a pair
//    function getReserves(address pair, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
//        (address token0,) = sortTokens(tokenA, tokenB);
//        (uint reserve0, uint reserve1,) = IPancakePair(pair).getReserves();
//        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
//    }
//    // returns sorted token addresses, used to handle return values from pairs sorted in this order
//    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
//        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
//        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
//        require(token0 != address(0), 'ZERO_ADDRESS');
//    }
//
//    // THIS is the entry point
//    function doSwap(IPancakePair[] memory pairs // array of LPs to be traversed (order of occurrence)
//                    , IBEP20 startToken         // initial token (starting liquidity)
//                    , uint256 initialAmount          // balance of initial token to use
//                    , uint256 minProfit         // minimum yield to achieve, in startToken, othervise rollback
//                    )
//    public
//    {
//        address currentToken = address(startToken);
//        uint256 currentAmount = initialAmount;
//
////        TransferHelper.safeTransferFrom(
////            currentToken, msg.sender, address(this), initialAmount
////        );
//        address[] memory path = new address[](2);
//
//        for(uint i = 0; i < pairs.length; i++)
//        {
//            path[0] = pairs[i].token0();
//            path[1] = pairs[i].token1();
//            if(path[1] == currentToken)
//            {
//                path[1] = path[0];
//                path[0] = currentToken;
//            }
//            swapExactTokensForTokens(address(pairs[i]), currentAmount, 0, path, address(this));
//            currentToken = path[1];
//            currentAmount = IBEP20(currentToken).balanceOf(address(this));
//        }
//
//        require(currentAmount >= initialAmount+minProfit, "NO_GAIN");
//        require(tokenIn == address(startToken), "NON_CIRCULAR_PATH");
//    }
}
