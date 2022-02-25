// SPDX-License-Identifier: UNLICENSED

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                                           THE BOFH Contract
    //                                                                v0.0.1
    //
    // About the entry point multiswap():
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
    // - the actual encoding of the parameters to be passed is laid out later. See multiswap_internal()
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
    // Versions:
    //
    // v0.0.0: unreleased. Initial deploy.
    // v0.0.1: pushes otimization farther. Squeezes 96 bytes of calldata out. Uses some inline asm for required magisms. (!!Breaks ABI!!)
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
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint blockTimestampLast);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}

#define OPT_BREAK_EARLY 0x01 // Debug option: break and return before performing a swap

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

    // returns calldata[idx]: uint256
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

    // note: the bulk of the code passes around the calldata "args" array, which is the contract invocation argument.
    //       Since Solidity 0.8.9 internal functions can share calldata things and avoid consuming gas to allocate additional stack or "memory"

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
        view
        returns (uint, uint, bool, address)
    {
        IGenericPair pair = IGenericPair(getPool(idx));
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

    struct getAmountOutWithFee_status {
            uint256 amountIn;
            uint256 reserveIn;
            uint256 reserveOut;
            uint256 feePPM;
            uint256 amountInWithFee;
            uint256 numerator;
            uint256 denominator;
            uint256 amountOut;
            address tokenOut;
    }


#define code_getAmountOutWithFee_status_snapshot_debug  \
        getAmountOutWithFee_status memory status;       \
        status.amountIn = amountIn;                     \
        status.reserveIn = reserveIn;                   \
        status.reserveOut = reserveOut;                 \
        status.feePPM = getFee(idx);                    \
        status.amountInWithFee = amountInWithFee;       \
        status.numerator = numerator;                   \
        status.denominator = denominator;               \
        status.amountOut = amountOut;                   \
        status.tokenOut = tokenOut;                 
#define code_getAmountOutWithFee_status_RETURNS_debug    ,getAmountOutWithFee_status memory
#define code_getAmountOutWithFee_status_val_debug        ,status
#define code_getAmountOutWithFee_status_snapshot_nodebug
#define code_getAmountOutWithFee_status_RETURNS_nodebug
#define code_getAmountOutWithFee_status_val_nodebug
#define code_getAmountOutWithFee(function_name, returns_token, status_snapshot, status_val) \
                                                                                                                     \
    function function_name(  uint idx                                                                                \
                             , address tokenIn                                                                       \
                             , uint amountIn                                                                         \
                            )                                                                                        \
        internal                                                                                                     \
        view                                                                                                         \
        returns (uint ,uint, address returns_token)                                                                  \
    {                                                                                                                \
        require(amountIn > 0, 'BOFH:INSUFFICIENT_INPUT_AMOUNT');                                                     \
        (uint reserveIn, uint reserveOut, bool sellingToken0, address tokenOut) = poolQuery(idx, tokenIn);           \
        require(reserveIn > 0 && reserveOut > 0, 'BOFH:INSUFFICIENT_LIQUIDITY');                                     \
        uint amountInWithFee = mul(amountIn, 1000000-getFee(idx));                                                   \
        uint numerator = mul(amountInWithFee, reserveOut);                                                           \
        uint denominator = mul(reserveIn, 1000000) + amountInWithFee;                                                \
        uint amountOut = numerator / denominator;                                                                    \
        status_snapshot                                                                                              \
        if (sellingToken0)                                                                                           \
        {                                                                                                            \
            return (0, amountOut, tokenOut status_val);                                                              \
        }                                                                                                            \
        return (amountOut, 0, tokenOut status_val);                                                                  \
     }


    code_getAmountOutWithFee(getAmountOutWithFee
                             , code_getAmountOutWithFee_status_RETURNS_nodebug
                             , code_getAmountOutWithFee_status_snapshot_nodebug
                             , code_getAmountOutWithFee_status_val_nodebug)
    code_getAmountOutWithFee(getAmountOutWithFee_debug
                             , code_getAmountOutWithFee_status_RETURNS_debug
                             , code_getAmountOutWithFee_status_snapshot_debug
                             , code_getAmountOutWithFee_status_val_debug  )



    // PRIVATE API: THIS is the main call. For the PUBLIC API Look for public spcializations later!
    // INPUT ARGS: uint256[] calldata args, read directly from calldata memory
    // args[0].bits[1..159]=pool0_address --> extract with getPool(0)
    // args[1].bits[1..159]=pool1_address --> extract with getPool(1)
    // args[N].bits[1..159]=poolN_address --> extract with getPool(N)
    // args[0].bits[160..255]=pool0_feePPM (parts per million) --> getFee(0)
    // args[1].bits[160..255]=pool1_feePPM (parts per million) --> getFee(1)
    // args[N].bits[160..255]=poolN_feePPM (parts per million) --> getFee(N)
    // [...]
    // args[args.length-1].bits[1..127]   initialAmount       --> extract with getInitialAmount()
    // args[args.length-1].bits[128..256] expectedFinalAmount --> extract with getExpectedAmount()
    // minimal args.length is 2 pools + trailer --> 4 elements

#define multiswap_internal_alloc_staus_debug \
        getAmountOutWithFee_status memory status;
#define multiswap_internal_calc_swap_debug                                                                      \
        (amount0Out, amount1Out, tokenOut, status) = getAmountOutWithFee_debug(i, transitToken, currentAmount); \
        if (getOptions(i, OPT_BREAK_EARLY))                                                                     \
        {                                                                                                       \
            return status;                                                                                      \
        }
#define multiswap_internal_trailer_return_debug \
        return status;
#define multiswap_internal_returns_debug \
        getAmountOutWithFee_status memory

#define multiswap_internal_alloc_staus_nodebug
#define multiswap_internal_calc_swap_nodebug \
    (amount0Out, amount1Out, tokenOut) = getAmountOutWithFee(i, transitToken, currentAmount);
#define multiswap_internal_trailer_return_nodebug \
        return currentAmount;
#define multiswap_internal_returns_nodebug \
        uint256




#define code_multiswap_internal(function_name, returns_token, alloc_status, calc_swap_block, trailer_return_code) \
    function function_name(                                                                             \
        uint args_length                                                                                \
    )                                                                                                   \
    internal                                                                                            \
    returns(returns_token)                                                                              \
    {                                                                                                   \
        alloc_status                                                                                    \
        require(args_length > 3, 'BOFH:PATH_TOO_SHORT');                                                \
                                                                                                        \
        address transitToken = baseToken;                                                               \
        uint256 currentAmount = getInitialAmount();                                                     \
        require(currentAmount <= IBEP20(baseToken).balanceOf(address(this)), 'BOFH:GIMMIE_MONEY');      \
                                                                                                        \
        /* transfer to 1st pool */                                                                      \
        safeTransfer(getPool(0), currentAmount);                                                        \
                                                                                                        \
        for (uint i=0; i < args_length-1; i++)                                                          \
        {                                                                                               \
            /* get infos from the LP */                                                                 \
            uint amount0Out;                                                                            \
            uint amount1Out;                                                                            \
            address tokenOut;                                                                           \
            calc_swap_block                                                                             \
            address swapBeneficiary = i >= (args_length-2)   /* it this the last swap of the path?                           */   \
                                      ? address(this)        /*   \__ yes: the contract collects the output of the last swap */   \
                                      : getPool(i+1);        /*   \__ no : send funds to the next pool                       */   \
            {                                                                                           \
                /* limit this specific stack frame: */                                                  \
                IGenericPair pair = IGenericPair(getPool(i));                                           \
                pair.swap(amount0Out, amount1Out, swapBeneficiary, new bytes(0));                       \
            }                                                                                           \
            transitToken = tokenOut;                                                                    \
            currentAmount = amount0Out == 0 ? amount1Out : amount0Out;                                  \
        }                                                                                               \
                                                                                                        \
        require(transitToken == baseToken, 'BOFH:NON_CIRCULAR_PATH');                                   \
        require(currentAmount >= getExpectedAmount(), 'BOFH:MP');                                       \
                                                                                                        \
        trailer_return_code                                                                             \
    }

    code_multiswap_internal(multiswap_internal
                            , multiswap_internal_returns_nodebug
                            , multiswap_internal_alloc_staus_nodebug
                            , multiswap_internal_calc_swap_nodebug
                            , multiswap_internal_trailer_return_nodebug)

    code_multiswap_internal(multiswap_internal_debug
                            , multiswap_internal_returns_debug
                            , multiswap_internal_alloc_staus_debug
                            , multiswap_internal_calc_swap_debug
                            , multiswap_internal_trailer_return_debug)

    // PUBLIC API for the main entry point.
    // Why and how this works:
    //  - this creates a N-way function overload using fixed-size arrays
    //  - this in turn produces different selector ids for each overload
    //       \___ and saves 32 bytes of calldata because the args.length is not part of it anymore
    //  - this also removes the need to encode variable-length payload in the calldata
    //       \___ and those are another 32 bytes of mostly zeros saved
    // Drawbacks:
    //  - one overload per supported args.length must be explicitly present
    //  - no offset in the calldata strings describes args.length. One must now look at the string length
    //  - internal functions fetch arguments directly from calldata area by reference. It's ugly and done in getU256()

#define multiswap_public_entrypoint(function_name, internal_function, returns_token, tuple_len) \
    function function_name(uint256[tuple_len] calldata args) external adminRestricted returns(returns_token) { return internal_function(tuple_len); } \
    function function_name##tuple_len() external adminRestricted returns(returns_token) { return internal_function(tuple_len); }

    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 3) // selector=0x12558fb4 or 0xab25564d
    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 4) // selector=0xb4859ac7 or 0xdaa5960e
    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 5) // selector=0x0ef12bbe or 0x7aae10f1
    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 6) // selector=0xa0a3d9d9 or 0x3ca172e4
    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 7) // selector=0xea704299 or 0xb009862e
    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 8) // selector=0xdacdc381 or 0xabdef753
    multiswap_public_entrypoint(multiswap, multiswap_internal, multiswap_internal_returns_nodebug, 9) // selector=0x86a99d4f or 0xc1a8841b
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 3)
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 4)
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 5)
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 6)
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 7)
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 8)
    multiswap_public_entrypoint(multiswap_debug, multiswap_internal_debug, multiswap_internal_returns_debug, 9)

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
}
