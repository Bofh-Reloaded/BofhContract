pragma solidity >= 0.6.12;

// Minimal functionality of the BSC token we are going to use
interface IBEP20 {
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);

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
    address owner; // rightful owner of the contract

    constructor ()
    {
        // owner is set at deploy time, set to the transaction signer
        owner = msg.sender;
    }


    event Trace(uint value);



    // address private constant CAKE_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // mainnet
    address private constant CAKE_V2_ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3; // testnet
    IBEP20 private constant BASE_TOKEN = IBEP20(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd); // WBNB on testnet

    // THIS is the entry point
    function doCakeInternalSwaps(address[] calldata tokenPath  // array of LPs to be traversed (order of occurrence)
                                 , uint256 initialAmount       // balance of initial token to use
                                 , uint256 minProfit           // minimum yield to achieve, in startToken, othervise rollback
                                 )
    external
    {
        require(tokenPath.length > 3, 'PATH_TOO_SHORT');
        address startToken = tokenPath[0];
        emit Trace(1);
        require(tokenPath[tokenPath.length-1] == startToken, 'NON_CIRCULAR_PATH');
        IBEP20 startTokenI = IBEP20(startToken);
        emit Trace(2);
        startTokenI.transferFrom(msg.sender, address(this), initialAmount);
        emit Trace(3);
        startTokenI.approve(CAKE_V2_ROUTER, initialAmount);
        emit Trace(4);

        IPancakeRouter01(CAKE_V2_ROUTER).swapExactTokensForTokens(
                initialAmount
                , initialAmount+minProfit
                , tokenPath
                , msg.sender
                , block.timestamp+20);
        emit Trace(5);
        // CASOMAI SERVISSE:
        // startTokenI.transfer(msg.sender, startTokenI.balanceOf(address(this)));
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'BOFH: transfer failed'
        );
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }



    function _getAmountOutWithFee(uint[4] memory args
                                    // indexing is:
                                    // [0] uint amountIn
                                    // [1] uint reserveIn
                                    // [2] uint reserveOut
                                    // [3] uint feePPM parts-per-million
                                    ) internal pure returns (uint amountOut)
    {
         require(args[0] > 0, 'BOFH: INSUFFICIENT_INPUT_AMOUNT');
         require(args[1] > 0 && args[2] > 0, 'BOFH: INSUFFICIENT_LIQUIDITY');
         uint amountInWithFee = mul(args[0], 1000000-args[3]);
         uint numerator = mul(amountInWithFee, args[2]);
         uint denominator = mul(args[2], 1000000) + amountInWithFee;
         amountOut = numerator / denominator;
     }


    //function _getAmountOutWithFee(uint amountIn, uint reserveIn, uint reserveOut, uint feePPM /* parts-per-million */) internal pure returns (uint amountOut)
    //{
    //     require(amountIn > 0, 'BOFH: INSUFFICIENT_INPUT_AMOUNT');
    //     require(reserveIn > 0 && reserveOut > 0, 'BOFH: INSUFFICIENT_LIQUIDITY');
    //     uint amountInWithFee = mul(amountIn, 1000000-feePPM);
    //     uint numerator = mul(amountInWithFee, reserveOut);
    //     uint denominator = mul(reserveIn, 1000000) + amountInWithFee;
    //     amountOut = numerator / denominator;
    //}

    // have the contract transfer its allowance to itself
    function adoptAllowance() external
    {
        require(msg.sender == owner, 'SUCKS2BEU');
        BASE_TOKEN.transferFrom(msg.sender, address(this), BASE_TOKEN.allowance(msg.sender, address(this)));
    }

    function withdrawFunds() external
    {
        require(msg.sender == owner, 'SUCKS2BEU');
        BASE_TOKEN.transfer(msg.sender, BASE_TOKEN.balanceOf(address(this)));
    }




    function multiSwap(
        address[] calldata pools
        , uint32[] calldata feesPPM
        , uint256 initialAmount
        , uint256 expectedFinalAmount

    ) external {
        require(msg.sender == owner, 'SUCKS2BEU');
        require(pools.length >= 2, 'PATH_TOO_SHORT');

        // transfer to 1st pool
        _safeTransfer(address(BASE_TOKEN)
                      , pools[0]
                      , initialAmount);

        address transitToken = address(BASE_TOKEN);
        uint256 currentAmount = initialAmount;
        for (uint i; i < pools.length; i++)
        {
            // get infos from the LP
            IPancakePair pair = IPancakePair(pools[i]);
            address t0 = pair.token0();
            address t1 = pair.token1();
            (uint reserveIn, uint reserveOut,) = pair.getReserves();

            address tokenOut;
            require(transitToken == t0 || transitToken == t1, 'BOFH: PAIR_NOT_IN_PATH');

            // see which direction we are traversing the
            if (t0 == transitToken)
            {
                tokenOut = t1;
                // reserveIn is already reserve0, reserveOut is already reserve1
            }
            else
            {
                tokenOut = t0;
                // transitToken is token1, need to swap reserveIn <=> reserveOut
                (reserveIn, reserveOut) = (reserveOut, reserveIn);
            }

            uint[4] memory aaarghs = [currentAmount, reserveIn, reserveOut, feesPPM[i]];
            uint amountOut = _getAmountOutWithFee(aaarghs);

            uint256 amount0Out = 0;
            uint256 amount1Out = 0;
            if (t0 == transitToken)
            {
                amount1Out = amountOut;
            }
            else
            {
                amount0Out = amountOut;
            }

            // have the next swap send funds to the next pool or, if this is the last step of the path
            // send the funds bach to the contract address
            address to = i < (pools.length-1) ? pools[i+1] : address(this);

            pair.swap(amount0Out, amount1Out, to, new bytes(0));
            transitToken = tokenOut;
            currentAmount = amountOut;
        }

        require(transitToken == address(BASE_TOKEN), 'BOFH: NON_CIRCULAR_PATH');
        require(currentAmount >= expectedFinalAmount, 'BOFH: GREED_IS_GOOD');
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
