// SPDX-License-Identifier: UNLICENSED

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                                           THE BOFH Contract
    //                                                                v0.0.0
    //
    // About the entry point multiswap1:
    //
    // - receives an array of POOL addresses
    //          \___ each with their respective fee estimation (in parts per 10E+6)
    // - receives initialAmount of baseToken (Wei units) to start the swap chain
    // - receives expectedAmount of baseToken (Wei units) as profit target. Execution reverts if target is missed
    // - the initialAmount is transferred to the first pool of the path
    // - a swap is performed with the next pool in line as its beneficiary address
    // - at the end of the swap sequence, the beneficieary is the contract itself
    // - if the described path is broken, too short, or is not circular respective of baseToken, execution reverts
    // - the code exploits calldata and bit shifting optimizations to save on gas. This is at the expense of clarity of argument encoding
    // - the actual encoding of the parameters to be passed is laid out later. See multiswap1()
    //
    // Presequisites:
    // - THE CONTRACT IS PRIVATE: only the deployer of the contract has the right to invoke its public functions
    // - a sufficient amount of baseToken must be approved to the contract ONCE, prior of calling multiswap()
    // - in order to actually move the balance to the contract, call ONCE adoptAllowance()
    // - for each subsequent funding injection, it is necessaty to repeat this same sequence (approve first then adoptAllowance)
    //
    // How to retrieve the balance:
    // - call withdrawFunds(). The baseToken funds are sent back to the caller. All of it. The contract has then zero balance of the token.
    //
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// IMPORTANT: using Solidity 0.8.9+ calldata optimizations here
pragma solidity >= 0.8.10;


// Minimal functionality of the BSC token we are going to use
interface IBEP20 {
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function symbol() external view returns (string memory);
}

// BARE BONES generic Pair interface (works with Uniswap v2 descendents, so basically all of them)
interface IGenericPair {
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


contract BofhContract
{
    address private owner; // rightful owner of the contract
    address private baseToken; // = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WBNB on testnet

    constructor(address ctrBaseToken)
    {
        // owner is set at deploy time, set to the transaction signer
        owner = msg.sender;
        baseToken = ctrBaseToken;
    }

    function getAdmin() external pure returns (address)
    {
        return owner;
    }

    function getBaseToken() external pure returns (address)
    {
        return baseToken;
    }

    modifier adminRestricted()
    {
        require(msg.sender == owner, 'BOFH:SUX2BEU');
        // Do not forget the "_;"! It will
        // be replaced by the actual function
        // body when the modifier is used.
        _;
    }

    function safeTransfer(address to, uint256 value) internal
    {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = baseToken.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'BOFH:TRANSFER_FAILED'
        );
    }


    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    // note: the bulk of the code passes around the calldata "args" array, which is the contract invocation argument.
    //       Since Solidity 0.8.9 internal functions can share calldata things and avoid consuming gas to allocate additional stack or "memory"

    function getFee(uint256[] calldata args, uint32 idx) internal pure returns (uint32)
    {
        return uint32((args[args.length-2] >> (idx*32)) & 0xffffffff); // truncate to uint32
    }

    function getAmount(uint256[] calldata args, uint32 idx) internal pure returns (uint256)
    {
        return (args[args.length-1] >> (idx*128)) & 0xffffffffffffffffffffffffffffffff; // truncate to uint128, plenty enough
    }

    function getPool(uint256[] calldata args, uint32 idx) internal pure returns (address)
    {
        return address(uint160(args[idx]));
    }

    function poolQuery(uint256[] calldata args, uint32 idx, address tokenIn)
        internal
        // view
        returns (uint, uint, bool, address)
    {
        IGenericPair pair = IGenericPair(getPool(args, idx));
        (uint reserveIn, uint reserveOut,) = pair.getReserves();
        address tokenOut = pair.token1();
        // 50/50 change of this being the case:
        if (tokenIn != tokenOut)
        {
            // we got lucky
            require(tokenIn == pair.token0(), 'BOFH:PAIR_NOT_IN_PATH'); // for paranoia
            return (reserveIn, reserveOut, true, tokenOut);
        }

        // else:
        // we are going in with pool.token1(). Need to reverse assumptions:
        tokenOut = pair.token0();
        (reserveOut, reserveIn) = (reserveIn, reserveOut);
        return (reserveIn, reserveOut, false, tokenOut);
    }

    function getAmountOutWithFee(  uint256[] calldata args
                                 , uint32 idx
                                 , address tokenIn
                                 , uint amountIn)
        internal
        // view
        returns (uint ,uint, address)
    {
        require(amountIn > 0, 'BOFH:INSUFFICIENT_INPUT_AMOUNT');
        (uint reserveIn, uint reserveOut, bool sellingToken0, address tokenOut) = poolQuery(args, idx, tokenIn);
        require(reserveIn > 0 && reserveOut > 0, 'BOFH:INSUFFICIENT_LIQUIDITY');

        uint amountInWithFee = mul(amountIn, 1000000-getFee(args, idx));
        uint numerator = mul(amountInWithFee, reserveOut);
        uint denominator = mul(reserveIn, 1000000) + amountInWithFee;
        uint amountOut = numerator / denominator;
        if (sellingToken0)
        {
            return (0, amountOut, tokenOut);
        }
        // else:
        return (amountOut, 0, tokenOut);
     }


    // PUBLIC API: THIS is the entry point.
    function multiswap1(
        uint256[] calldata args
        // args[0] pool0
        // args[1] pool1
        // args[N] poolN
        // args[-2].bits[0..31]    feesppm0 --> extract with getFee(args, 0)
        // args[-2].bits[32..63]   feesppm1 --> extract with getFee(args, 1)
        // args[-2].bits[64..95]   feesppm2 --> extract with getFee(args, 2)
        // args[-2].bits[66..127]  feesppm3 --> extract with getFee(args, 3)
        // args[-2].bits[128..256] <unused>
        // args[-1].bits[1..127]   initialAmount       --> extract with getAmount(args, 0)
        // args[-1].bits[128..256] expectedFinalAmount --> extract with getAmount(args, 1)
        // minimal args.length is 2 pools + trailer --> 4 elements
    )
    external
    adminRestricted()
    returns(uint)
    {
        require(args.length > 3, 'BOFH:PATH_TOO_SHORT');

        address transitToken = baseToken;
        uint256 currentAmount = getAmount(args, 0);
        require(currentAmount <= IBEP20(baseToken).balanceOf(address(this)), 'BOFH:GIMMIE_MONEY');

        // transfer to 1st pool
        safeTransfer(getPool(args, 0), currentAmount);

        for (uint32 i; i < args.length-2; i++)
        {
            // get infos from the LP
            (uint amount0Out, uint amount1Out, address tokenOut) = getAmountOutWithFee(args, i, transitToken, currentAmount);
            address swapBeneficiary = i >= (args.length-2)   // it this the last swap of the path?
                                      ? address(this)        //   \__ yes: the contract collects the output of the last swap
                                      : getPool(args, i+1);  //   \__ no : send funds to the next pool
            {
                // limit this specific stack frame:
                IGenericPair pair = IGenericPair(getPool(args, i));
                pair.swap(amount0Out, amount1Out, swapBeneficiary, new bytes(0));

            }
            transitToken = tokenOut;
            currentAmount = amount0Out == 0 ? amount1Out : amount0Out;
        }

        require(transitToken == baseToken, 'BOFH:NON_CIRCULAR_PATH');
        require(currentAmount >= getAmount(args, 1), 'BOFH:GREED_IS_GOOD');

        return currentAmount;
    }

    // PUBLIC API: have the contract move its allowance to itself
    function adoptAllowance()
    external
    adminRestricted()
    {
        IBEP20 token = IBEP20(baseToken);
        token.transferFrom(msg.sender, address(this), token.allowance(msg.sender, address(this)));
    }

    // PUBLIC API: have the contract send its token balance to the caller
    function withdrawFunds()
    external
    adminRestricted()
    {
        IBEP20 token = IBEP20(baseToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    // PUBLIC API: adopt another rightful admin address
    function changeAdmin(address newOwner)
    external
    adminRestricted()
    {
        owner = newOwner;
    }


    // PUBLIC API: this removes the contract from the chain status (however leaves its copy in its deploy block)
    //             - also sends any credited token back to the caller
    //             - also, the blockchain rebates the caller some coin because this frees up storage
    //             - IT'S A GOOD IDEA to call this upon obsoleted contracts. It ensures funds recovery and that
    //               broken contracts won't be callable again.
    function kill()
    external
    adminRestricted()
    {
        IBEP20 token = IBEP20(baseToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
        selfdestruct(payable(msg.sender));
    }


    // Test callpoints. Remove in production!

    function test_getFee(uint256[] calldata args, uint32 idx) external returns (uint32)
    {
        return getFee(args, idx);
    }

    function test_getAmount(uint256[] calldata args, uint32 idx) external returns (uint256)
    {
        return getAmount(args, idx);
    }

    function test_getPool(uint256[] calldata args, uint32 idx) external returns (address)
    {
        return getPool(args, idx);
    }

    function test_poolQuery(uint256[] calldata args, uint32 idx, address tokenIn) external returns (uint, uint, bool, address)
    {
        return poolQuery(args, idx, tokenIn);
    }

    function test_getAmountOutWithFee(  uint256[] calldata args
                                      , uint32 idx
                                      , address tokenIn
                                      , uint amountIn)
        external
        returns (uint, uint, address)
    {
        return getAmountOutWithFee(args, idx, tokenIn, amountIn);
    }


    function test_Hello()
        external
        returns (string memory)
    {
        return "Hello, World!";
    }



}
