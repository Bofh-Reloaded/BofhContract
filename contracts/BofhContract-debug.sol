pragma solidity >= 0.8.10;



interface IBEP20 {
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function symbol() external view returns (string memory);
}


interface IGenericPair {
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint blockTimestampLast);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}
contract BofhContract
{


    address private owner;
    address private baseToken;

    constructor(address ctrBaseToken)
    {

        owner = msg.sender;
        baseToken = ctrBaseToken;
    }

    function getAdmin() external view returns (address)
    {
        return owner;
    }

    function getBaseToken() external view returns (address)
    {
        return baseToken;
    }

    modifier adminRestricted()
    {
        require(msg.sender == owner, 'BOFH:SUX2BEU');



        _;
    }

    function safeTransfer(address to, uint256 value) internal
    {

        (bool success, bytes memory data) = baseToken.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'BOFH:TRANSFER_FAILED'
        );
    }


    function getU256(uint idx) internal pure returns (uint256 value)
    {
        assembly
        {
            let ptr := mload(0x40)
            calldatacopy(ptr, add(0x04, mul(idx, 0x20)), 0x20)
            value := mload(ptr)
        }
    }
    function getU256_last() internal pure returns (uint256 value)
    {
        assembly
        {
            let ptr := mload(0x40)
            calldatacopy(ptr, sub(calldatasize(), 0x20), 0x20)
            value := mload(ptr)
        }
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }




    function getFee(uint idx) internal pure returns (uint)
    {
        return (getU256(idx) >> 160) & 0xfffff;
    }

    function getOptions(uint idx, uint mask) internal pure returns (bool)
    {
        return ((getU256(idx) >> 180) & mask) == mask;
    }

    function getInitialAmount() internal pure returns (uint256)
    {
        return uint128(getU256_last());
    }

    function getExpectedAmount() internal pure returns (uint256)
    {
        return uint128(getU256_last() >> 128);
    }

    function getPool(uint idx) internal pure returns (address)
    {
        return address(uint160(getU256(idx)));
    }

    function poolQuery(uint idx, address tokenIn)
        internal

        returns (uint, uint, bool, address)
    {
        IGenericPair pair = IGenericPair(getPool(idx));
        (uint reserveIn, uint reserveOut,) = pair.getReserves();
        address tokenOut = pair.token1();

        if (tokenIn != tokenOut)
        {

            require(tokenIn == pair.token0(), 'BOFH:PAIR_NOT_IN_PATH');
            return (reserveIn, reserveOut, true, tokenOut);
        }



        tokenOut = pair.token0();
        (reserveOut, reserveIn) = (reserveIn, reserveOut);
        return (reserveIn, reserveOut, false, tokenOut);
    }

    function getAmountOutWithFee( uint idx
                                 , address tokenIn
                                 , uint amountIn)
        internal

        returns (uint ,uint, address)
    {
        require(amountIn > 0, 'BOFH:INSUFFICIENT_INPUT_AMOUNT');
        (uint reserveIn, uint reserveOut, bool sellingToken0, address tokenOut) = poolQuery(idx, tokenIn);
        require(reserveIn > 0 && reserveOut > 0, 'BOFH:INSUFFICIENT_LIQUIDITY');

       
       
       
       
        uint amountInWithFee = mul(amountIn, 1000000-getFee(idx));
       
        uint numerator = mul(amountInWithFee, reserveOut);
       
        uint denominator = mul(reserveIn, 1000000) + amountInWithFee;
       
        uint amountOut = numerator / denominator;
       
        if (sellingToken0)
        {
            return (0, amountOut, tokenOut);
        }

        return (amountOut, 0, tokenOut);
     }



    function multiswap_internal(
        uint args_length
    )
    internal
    returns(uint)
    {
        require(args_length > 3, 'BOFH:PATH_TOO_SHORT');

        address transitToken = baseToken;
        uint256 currentAmount = getInitialAmount();
        require(currentAmount <= IBEP20(baseToken).balanceOf(address(this)), 'BOFH:GIMMIE_MONEY');


        safeTransfer(getPool(0), currentAmount);

        for (uint i=0; i < args_length-1; i++)
        {

           
            (uint amount0Out, uint amount1Out, address tokenOut) = getAmountOutWithFee(i, transitToken, currentAmount);
            address swapBeneficiary = i >= (args_length-2)
                                      ? address(this)
                                      : getPool(i+1);






            {

                IGenericPair pair = IGenericPair(getPool(i));
                pair.swap(amount0Out, amount1Out, swapBeneficiary, new bytes(0));
            }
            transitToken = tokenOut;
            currentAmount = amount0Out == 0 ? amount1Out : amount0Out;
        }

        require(transitToken == baseToken, 'BOFH:NON_CIRCULAR_PATH');
        require(currentAmount >= getExpectedAmount(), 'BOFH:GREED_IS_GOOD');

        return currentAmount;
    }
    function multiswap(uint256[3] calldata args) external adminRestricted returns(uint) { return multiswap_internal(3); }
    function multiswap(uint256[4] calldata args) external adminRestricted returns(uint) { return multiswap_internal(4); }
    function multiswap(uint256[5] calldata args) external adminRestricted returns(uint) { return multiswap_internal(5); }
    function multiswap(uint256[6] calldata args) external adminRestricted returns(uint) { return multiswap_internal(6); }
    function multiswap(uint256[7] calldata args) external adminRestricted returns(uint) { return multiswap_internal(7); }
    function multiswap(uint256[8] calldata args) external adminRestricted returns(uint) { return multiswap_internal(8); }
    function multiswap(uint256[9] calldata args) external adminRestricted returns(uint) { return multiswap_internal(9); }
    function multiswap(uint256[10] calldata args) external adminRestricted returns(uint) { return multiswap_internal(10); }



    function multiswap3() external adminRestricted returns(uint) { return multiswap_internal(3); }
    function multiswap4() external adminRestricted returns(uint) { return multiswap_internal(4); }
    function multiswap5() external adminRestricted returns(uint) { return multiswap_internal(5); }
    function multiswap6() external adminRestricted returns(uint) { return multiswap_internal(6); }
    function multiswap7() external adminRestricted returns(uint) { return multiswap_internal(7); }
    function multiswap8() external adminRestricted returns(uint) { return multiswap_internal(8); }
    function multiswap9() external adminRestricted returns(uint) { return multiswap_internal(9); }
    function multiswap10() external adminRestricted returns(uint) { return multiswap_internal(10); }



    function adoptAllowance()
    external
    adminRestricted()
    {
        IBEP20 token = IBEP20(baseToken);
        token.transferFrom(msg.sender, address(this), token.allowance(msg.sender, address(this)));
    }


    function withdrawFunds()
    external
    adminRestricted()
    {
        IBEP20 token = IBEP20(baseToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }


    function changeAdmin(address newOwner)
    external
    adminRestricted()
    {
        owner = newOwner;
    }







    function kill()
    external
    adminRestricted()
    {
        IBEP20 token = IBEP20(baseToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
        selfdestruct(payable(msg.sender));
    }
}