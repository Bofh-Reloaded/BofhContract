// SPDX-License-Identifier: UNLICENSED

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//                                                           THE BOFH Contract
//                                                                v0.0.2
//
// Functional preface:
// This contract is meant to operate a connected chain of swaps, starting and ending in the contract base token.
// This contract has a single admin user, only sender able to invoke its functions. (See "owner" storage var).
// This contract stores an operational amount of baseToken on itself. (See "baseToken" storage var).
// The final yield of the swap chain is credited back to the contract's address.
//
// Public API:
//
// - getAdmin()
//      Returns contract instance's current admin address
// - getBaseToken()
//      Returns contract instance's current base token
// - changeAdmin(address newOwner)
//      Transfer admin rights to another address
// - adoptAllowance()
//      Transfer credited amount to the contract instance's address (Must be preceeded by baseToken.allow()).@author
//      The credited amount is compounded on top of any previously established credit of baseToken.
// - withdrawFunds()
//      Withdraw 100% of the current contract baseToken credit, and transfer it to the admin address.
// - kill()
//      Self-destruct contract instance. (Also performs withdrawFunds()). Rebates storage gas to the admin address.
// - multiswap(uint256[3])
// - multiswap(uint256[4])
// - multiswap(uint256[...])
// - multiswap(uint256[N])
// - multiswap3()
// - multiswap4()
// - multiswapN()
//      This is the main entry point. (They all do the same thing)
//      See later.
//
// About the entry point multiswap():
//
// - receives an array of POOL addresses
//          \___ each with their respective fee estimation (in parts per 10E+6)
// - receives initialAmount of baseToken (Wei units) to start the swap chain
// - receives expectedAmount of baseToken (Wei units) as profit target. Execution reverts if target is missed
// - the initialAmount is transferred to the first pool of the path
// - the pool is observed (with getReserves()) and the amountOut is computed, according to pool's K and fees
// - a swap is performed with the next pool in line as its beneficiary address and the cycle repeats
// - at the end of the swap sequence, the beneficiary of the final swap is the contract itself
// - if the described path is broken, too short, or is not circular respective of baseToken, execution reverts
// - if the final yield of the swap does not match or exceed expectedAmount, execution reverts
// - the code exploits calldata and bit shifting optimizations to save on gas. This is at the expense of clarity of argument encoding
// - the actual encoding of the parameters to be passed is laid out later. See multiswap_internal()
//
// Description of payload format:
// Formally (at web3 level), all multicall() entrypoints accept a sized uint256[] array as a parameter.
// The payload format is:
// args[0].bits[1..159]=pool0_address --> extract with getPool(0)
// args[1].bits[1..159]=pool1_address --> extract with getPool(1)
// args[N].bits[1..159]=poolN_address --> extract with getPool(N)
// args[0].bits[160..255]=pool0_feePPM (parts per million) --> getFee(0)
// args[1].bits[160..255]=pool1_feePPM (parts per million) --> getFee(1)
// args[N].bits[160..255]=poolN_feePPM (parts per million) --> getFee(N)
// [...]
// args[args.length-1].bits[1..127]   initialAmount       --> extract with getInitialAmount()
// args[args.length-1].bits[128..256] expectedFinalAmount --> extract with getExpectedAmount()
// In other words:
// - Each element of the array besides the last one, describes a swap pool and its fees
// - The last element describes initialAmount and expectedAmount quantities
// - The minimal functional length of an invocation is an array of length 3 (2 swaps).
//
// Usage remarks:
// - THE CONTRACT IS PRIVATE: only the deployer of the contract has the right to invoke its public functions
// - a baseToken address must be specified for the contract instance at deploy time
// - a sufficient amount of baseToken must be approved to the contract ONCE, prior of calling multiswap()
// - in order to actually move the balance to the contract, call ONCE adoptAllowance()
// - for each subsequent funding injection, it is necessary to repeat this same sequence (approve first then adoptAllowance)
//
// How to retrieve the balance:
// - call withdrawFunds(). The baseToken funds are sent back to the caller. All of it. The contract has then zero balance of the token.
//
// Versions:
//
// v0.0.0: unreleased. Initial deploy.
// v0.0.1: pushes optimization further. Squeezes 96 bytes of calldata out. Uses some inline asm for required magisms. (!!Breaks ABI!!)
// v0.0.2: rewrite using C preprocessor for loop-unrolling and injection of debug code
//
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// IMPORTANT: using Solidity 0.8.9+. Some calldata optimizations are buggy in pre-0.8.9 compilers
pragma solidity >=0.8.10;

// Minimal functionality of the BSC token we are going to use
interface IBEP20 {
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    function symbol() external view returns (string memory);
}

// BARE BONES generic Pair interface (works with Uniswap v2 descendents, so basically all of them)
interface IGenericPair {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint256 blockTimestampLast
        );

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;
}

contract BofhContract {
    address private owner; // rightful owner of the contract
    address private baseToken; // = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WBNB on testnet

    constructor(address ctrBaseToken) {
        // owner and baseToken are is set at deploy time
        owner = msg.sender;
        baseToken = ctrBaseToken;
    }

    function getAdmin() external view returns (address) {
        return owner;
    }

    function getBaseToken() external view returns (address) {
        return baseToken;
    }

    // Modifier applied to all state-changing APIs later:
    modifier adminRestricted() {
        require(msg.sender == owner, "BOFH:SUX2BEU");
        // Do not forget the "_;"! It will
        // be replaced by the actual function
        // body when the modifier is used.
        _;
    }

    // Horrible Uniswap hack to implement an uniform transfer call even for non-compliant tokens:
    function safeTransfer(address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = baseToken.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "BOFH:TRANSFER_FAILED"
        );
    }

    // Access calldata memory area, returns args[idx]. NO BOUNDARY CHECKS IN PLACE!!
    function getU256(uint256 idx) internal pure returns (uint256 value) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, add(0x04, mul(idx, 0x20)), 0x20)
            value := mload(ptr)
        }
    }

    // Access calldata memory area, returns args[args.length-1]
    function getU256_last() internal pure returns (uint256 value) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, sub(calldatasize(), 0x20), 0x20)
            value := mload(ptr)
        }
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    // get fee amount (in parts per million), for the N-th pool of the swap chain
    function getFee(uint256 idx) internal pure returns (uint256) {
        return (getU256(idx) >> 160) & 0xfffff;
    }

    // get the options bitmask for the N-th pool of the swap chain (currently only used for debug purposes)
    // Implemented list of options:
    //
    //  OPT_BREAK_EARLY=0x01 -- Break swap chain early, and return immediately.
    //                          This can be used with eth_call() in order to obtain a StatusSnapshot() tuple
    //                          describing the contract's internal status at the N-th step of the swap.
    //
    function getOptions(uint256 idx, uint256 mask)
        internal
        pure
        returns (bool)
    {
        return ((getU256(idx) >> 180) & mask) == mask;
    }

    // Return initialAmount (weis) of baseToken, which is the start size for the first swap of the chain
    function getInitialAmount() internal pure returns (uint256) {
        return uint128(getU256_last());
    }

    // Return expectedAmount (weis) of baseToken, which is the minimum expected output amount of the swap chain
    function getExpectedAmount() internal pure returns (uint256) {
        return uint128(getU256_last() >> 128);
    }

    // get N-th pool address (idx between 0 to args.length-1)
    function getPool(uint256 idx) internal pure returns (address) {
        return address(uint160(getU256(idx)));
    }

    /* fetch pool reserves, return a tuple telling: */
    /* reserveIn, reserveOut, swapDirection, outputToken */
    function poolQuery(uint256 idx, address tokenIn)
        internal
        view
        returns (
            uint256,
            uint256,
            bool,
            address
        )
    {
        IGenericPair pair = IGenericPair(getPool(idx));
        (uint256 reserveIn, uint256 reserveOut, ) = pair.getReserves();
        address tokenOut = pair.token1();
        /* 50/50 change of this being the case: */
        if (tokenIn != tokenOut) {
            /* we got lucky */
            require(tokenIn == pair.token0(), "BOFH:PAIR_NOT_IN_PATH");
            /* for paranoia */
            return (reserveIn, reserveOut, true, tokenOut);
        }
        /* else: */
        /* we are going in with pool.token1(). Need to reverse assumptions: */
        tokenOut = pair.token0();
        (reserveOut, reserveIn) = (reserveIn, reserveOut);
        return (reserveIn, reserveOut, false, tokenOut);
    }

    /* observe next pool's reserves, compute fees, return amount0Out, amount1Out and nextToken */
    function getAmountOutWithFee(
        uint256 idx,
        address tokenIn,
        uint256 amountIn
    )
        internal
        view
        returns (
            uint256,
            uint256,
            address
        )
    {
        require(amountIn > 0, "BOFH:INSUFFICIENT_INPUT_AMOUNT");
        (
            uint256 reserveIn,
            uint256 reserveOut,
            bool sellingToken0,
            address tokenOut
        ) = poolQuery(idx, tokenIn);
        require(reserveIn > 0 && reserveOut > 0, "BOFH:INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = mul(amountIn, 1000000 - getFee(idx));
        uint256 numerator = mul(amountInWithFee, reserveOut);
        uint256 denominator = mul(reserveIn, 1000000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;
        if (sellingToken0) {
            return (0, amountOut, tokenOut);
        }
        return (amountOut, 0, tokenOut);
    }

    /* Main entry-point. Called from external overloads (see later) */
    function multiswap_internal(uint256 args_length)
        internal
        returns (uint256)
    {
        require(args_length > 3, "BOFH:PATH_TOO_SHORT");
        /* always start with a specified amount of baseToken */
        address transitToken = baseToken;
        uint256 currentAmount = getInitialAmount();
        /* check if the contract actually owns the specified amount of baseToken */
        require(
            currentAmount <= IBEP20(baseToken).balanceOf(address(this)),
            "BOFH:GIMMIE_MONEY"
        );
        /* transfer to 1st pool */
        safeTransfer(getPool(0), currentAmount);
        for (uint256 i = 0; i < args_length - 1; i++) {
            /* get infos from the LP */
            uint256 amount0Out;
            uint256 amount1Out;
            address tokenOut;
            (amount0Out, amount1Out, tokenOut) = getAmountOutWithFee(
                i,
                transitToken,
                currentAmount
            );
            address swapBeneficiary = i >= (args_length - 2) /* it this the last swap of the path? */
                ? address(this) /*   \__ yes: the contract collects the output of the last swap */
                : getPool(i + 1);
            /*   \__ no : send funds to the next pool */
            {
                /* limit this specific stack frame: */
                IGenericPair pair = IGenericPair(getPool(i));
                /* Perform the swap!! */
                pair.swap(
                    amount0Out,
                    amount1Out,
                    swapBeneficiary,
                    new bytes(0)
                );
            }
            /* we are now handling a certain amount the swap's output token */
            transitToken = tokenOut;
            currentAmount = amount0Out == 0 ? amount1Out : amount0Out;
        }
        /* final sanity checks: */
        require(transitToken == baseToken, "BOFH:NON_CIRCULAR_PATH");
        require(currentAmount >= getExpectedAmount(), "BOFH:MP");
        /* return some status (this can be inspected with eth_call()) */
        return currentAmount;
    }

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

    function multiswap(uint256[3] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(3);
    }

    function multiswap3() external adminRestricted returns (uint256) {
        return multiswap_internal(3);
    } // selector=0x12558fb4 or 0xab25564d

    function multiswap(uint256[4] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(4);
    }

    function multiswap4() external adminRestricted returns (uint256) {
        return multiswap_internal(4);
    } // selector=0xb4859ac7 or 0xdaa5960e

    function multiswap(uint256[5] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(5);
    }

    function multiswap5() external adminRestricted returns (uint256) {
        return multiswap_internal(5);
    } // selector=0x0ef12bbe or 0x7aae10f1

    function multiswap(uint256[6] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(6);
    }

    function multiswap6() external adminRestricted returns (uint256) {
        return multiswap_internal(6);
    } // selector=0xa0a3d9d9 or 0x3ca172e4

    function multiswap(uint256[7] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(7);
    }

    function multiswap7() external adminRestricted returns (uint256) {
        return multiswap_internal(7);
    } // selector=0xea704299 or 0xb009862e

    function multiswap(uint256[8] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(8);
    }

    function multiswap8() external adminRestricted returns (uint256) {
        return multiswap_internal(8);
    } // selector=0xdacdc381 or 0xabdef753

    function multiswap(uint256[9] calldata args)
        external
        adminRestricted
        returns (uint256)
    {
        return multiswap_internal(9);
    }

    function multiswap9() external adminRestricted returns (uint256) {
        return multiswap_internal(9);
    } // selector=0x86a99d4f or 0xc1a8841b

    // PUBLIC API: have the contract move its allowance to itself
    function adoptAllowance() external adminRestricted {
        IBEP20 token = IBEP20(baseToken);
        token.transferFrom(
            msg.sender,
            address(this),
            token.allowance(msg.sender, address(this))
        );
    }

    // PUBLIC API: have the contract send its token balance to the caller
    function withdrawFunds() external adminRestricted {
        IBEP20 token = IBEP20(baseToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    // PUBLIC API: adopt another rightful admin address
    function changeAdmin(address newOwner) external adminRestricted {
        owner = newOwner;
    }

    // PUBLIC API: this removes the contract from the chain status (however leaves its copy in its deploy block)
    //             - also sends any credited token back to the caller
    //             - also, the blockchain rebates the caller some coin because this frees up storage
    //             - IT'S A GOOD IDEA to call this upon obsoleted contracts. It ensures funds recovery and that
    //               broken contracts won't be callable again.
    function kill() external adminRestricted {
        IBEP20 token = IBEP20(baseToken);
        token.transfer(msg.sender, token.balanceOf(address(this)));
        selfdestruct(payable(msg.sender));
    }
}