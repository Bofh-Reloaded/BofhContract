pragma solidity >= 0.8.10;
interface IBEP20 {
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function symbol() external view returns (string memory);
}
interface IGenericPair {
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint256 blockTimestampLast);
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}
contract BofhContract {
    uint256 private constant PRECISION = 1e6;
    uint256 private constant GOLDEN_RATIO = 618034;
    uint256 private constant GOLDEN_RATIO_SQUARED = 381966;
    uint256 private constant INVERSE_GOLDEN_RATIO = 381966;
    uint256 private constant MAX_SLIPPAGE = PRECISION / 100;
    uint256 private constant FOUR_WAY = 4;
    uint256 private constant FIVE_WAY = 5;
    uint256 private constant GAS_OVERHEAD_PER_SWAP = 150000;
    address private immutable owner;
    address private immutable baseToken;
    bool private isDeactivated;
    mapping(address => bool) public blacklistedPools;
    uint256 public maxTradeVolume;
    uint256 public minPoolLiquidity;
    uint256 public maxPriceImpact;
    uint256 public sandwichProtectionBips;
    event PoolBlacklisted(address indexed pool, bool blacklisted);
    event RiskParamsUpdated(uint256 maxVolume, uint256 minLiquidity, uint256 maxImpact, uint256 sandwichProtection);
    event EmergencyAction(bool paused);
    error Unauthorized();
    error InsufficientFunds();
    error InsufficientLiquidity();
    error InvalidPath();
    error NonCircularPath();
    error MinimumProfitNotMet();
    error PairNotInPath();
    error TransferFailed();
    error ContractDeactivated();
    error SuboptimalPath();
    error ExcessiveSlippage();
    error NumericalInstability();
    struct SwapState {
        address transitToken;
        uint256 currentAmount;
        bool isLastSwap;
        uint256 amountInWithFee;
        uint256 amountOut;
        uint256 slippage;
        uint256 optimalityScore;
        uint256 pathLength;
        uint256 cumulativeImpact;
        uint256 volumeProfile;
    }
    struct PoolState {
        uint256 reserveIn;
        uint256 reserveOut;
        bool sellingToken0;
        address tokenOut;
        uint256 priceImpact;
        uint256 depth;
        uint256 volatility;
    }
    constructor(address ctrBaseToken) {
        owner = msg.sender;
        baseToken = ctrBaseToken;
        isDeactivated = false;
    }
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
    modifier whenActive() {
        if (isDeactivated) revert ContractDeactivated();
        _;
    }
    function getAdmin() external view returns (address) {
        return owner;
    }
    function getBaseToken() external view returns (address) {
        return baseToken;
    }
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    function cbrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 r = x;
        uint256 p = x / 3;
        for (uint256 i = 0; i < 7; i++) {
            r = (2 * r + x / (r * r)) / 3;
            if (r <= p) break;
            p = r;
        }
        return r;
    }
    function geometricMean(uint256 a, uint256 b) internal pure returns (uint256) {
        return sqrt(a * b);
    }
    function getU256(uint256 idx) internal pure returns (uint256 value) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, add(0x04, mul(idx, 0x20)), 0x20)
            value := mload(ptr)
        }
    }
    function getU256_last() internal pure returns (uint256 value) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, sub(calldatasize(), 0x20), 0x20)
            value := mload(ptr)
        }
    }
    function getFee(uint256 idx) internal pure returns (uint256) {
        return (getU256(idx) >> 160) & 0xfffff;
    }
    function getPool(uint256 idx) internal pure returns (address) {
        return address(uint160(getU256(idx)));
    }
    function getInitialAmount() internal pure returns (uint256) {
        return uint128(getU256_last());
    }
    function getExpectedAmount() internal pure returns (uint256) {
        return uint128(getU256_last() >> 128);
    }
    function safeTransfer(address to, uint256 value) internal {
        (bool success, bytes memory data) = baseToken.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool))))
            revert TransferFailed();
    }
    function analyzePool(uint256 idx, address tokenIn, uint256 amountIn) internal view returns (PoolState memory pool) {
        IGenericPair pair = IGenericPair(getPool(idx));
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        pool.tokenOut = pair.token1();
        if (tokenIn != pool.tokenOut) {
            if (tokenIn != pair.token0()) revert PairNotInPath();
            pool.reserveIn = reserve0;
            pool.reserveOut = reserve1;
            pool.sellingToken0 = true;
        } else {
            pool.tokenOut = pair.token0();
            pool.reserveIn = reserve1;
            pool.reserveOut = reserve0;
            pool.sellingToken0 = false;
        }
        pool.depth = sqrt(pool.reserveIn * pool.reserveOut);
        pool.volatility = (pool.reserveIn * PRECISION) / (pool.reserveOut + 1);
        pool.priceImpact = calculatePriceImpact(amountIn, pool);
        return pool;
    }
    function calculatePriceImpact(uint256 amountIn, PoolState memory pool) internal pure returns (uint256) {
        uint256 k = pool.reserveIn * pool.reserveOut;
        uint256 newReserveIn = pool.reserveIn + amountIn;
        uint256 newK = newReserveIn * pool.reserveOut;
        uint256 impactCubed = (newK * PRECISION * PRECISION) / (k * PRECISION);
        return cbrt(impactCubed);
    }
    function performSwap(SwapState memory state, uint256 idx, uint256 argsLength) internal returns (SwapState memory) {
        if (isDeactivated) revert ContractDeactivated();
        address poolAddress = getPool(idx);
        if (blacklistedPools[poolAddress]) revert PairNotInPath();
        PoolState memory poolState = analyzePool(idx, state.transitToken, state.currentAmount);
        if (poolState.reserveIn < minPoolLiquidity || poolState.reserveOut < minPoolLiquidity)
            revert InsufficientLiquidity();
        unchecked {
            uint256 expectedPrice = (poolState.reserveOut * PRECISION) / poolState.reserveIn;
            uint256 actualPrice = (state.currentAmount * PRECISION) / poolState.reserveIn;
            uint256 priceDeviation;
            if (actualPrice > expectedPrice) {
                priceDeviation = ((actualPrice - expectedPrice) * PRECISION) / expectedPrice;
            } else {
                priceDeviation = ((expectedPrice - actualPrice) * PRECISION) / expectedPrice;
            }
            if (priceDeviation > sandwichProtectionBips)
                revert ExcessiveSlippage();
        }
        unchecked {
            state.amountInWithFee = calculateOptimalAmountIn(state, poolState);
            if (state.amountInWithFee > maxTradeVolume) revert ExcessiveSlippage();
            uint256 slippage;
            (state.amountOut, slippage) = calculateOptimalAmountOut(state, poolState);
            state.slippage = slippage;
            state.cumulativeImpact += slippage;
            uint256 maxAllowedSlippage = (MAX_SLIPPAGE * (idx + 1)) / argsLength;
            if (state.slippage > maxAllowedSlippage) revert ExcessiveSlippage();
            uint256 gasUsed = GAS_OVERHEAD_PER_SWAP * (idx + 1);
            uint256 minProfitRequired = (gasUsed * tx.gasprice * 12) / 10;
            if (idx == argsLength - 2 && state.currentAmount <= minProfitRequired)
                revert MinimumProfitNotMet();
        }
        state.isLastSwap = idx >= (argsLength - 2);
        address beneficiary = state.isLastSwap ? address(this) : getPool(idx + 1);
        uint256 prevAmount = IBEP20(poolState.tokenOut).balanceOf(beneficiary);
        IGenericPair(poolAddress).swap(
            poolState.sellingToken0 ? 0 : state.amountOut,
            poolState.sellingToken0 ? state.amountOut : 0,
            beneficiary,
            new bytes(0)
        );
        uint256 nextAmount = IBEP20(poolState.tokenOut).balanceOf(beneficiary);
        state.currentAmount = nextAmount - prevAmount;
        state.transitToken = poolState.tokenOut;
        return state;
    }
    function calculateOptimalAmountIn(SwapState memory state, PoolState memory) internal pure returns (uint256) {
        uint256 baseAmount = state.currentAmount * (PRECISION - getFee(state.pathLength - 1));
        if (state.pathLength == FOUR_WAY) {
            return (baseAmount * GOLDEN_RATIO) / PRECISION;
        } else if (state.pathLength == FIVE_WAY) {
            return (baseAmount * GOLDEN_RATIO_SQUARED) / PRECISION;
        }
        return baseAmount;
    }
    function calculateOptimalAmountOut(
        SwapState memory state,
        PoolState memory pool
    ) internal pure returns (uint256 amountOut, uint256 slippage) {
        uint256 numerator = state.amountInWithFee * pool.reserveOut;
        uint256 denominator = (pool.reserveIn * PRECISION) + state.amountInWithFee;
        if (denominator == 0) revert NumericalInstability();
        amountOut = numerator / denominator;
        slippage = (pool.priceImpact * state.currentAmount) / PRECISION;
        return (amountOut, slippage);
    }
    function fourWaySwap(uint256[4] calldata args) external onlyOwner whenActive returns (uint256) {
        SwapState memory state = SwapState({
            transitToken: baseToken,
            currentAmount: uint128(args[3]),
            isLastSwap: false,
            amountInWithFee: 0,
            amountOut: 0,
            slippage: 0,
            optimalityScore: PRECISION,
            pathLength: FOUR_WAY,
            cumulativeImpact: 0,
            volumeProfile: 0
        });
        if (state.currentAmount > IBEP20(baseToken).balanceOf(address(this)))
            revert InsufficientFunds();
        uint256 optimalAmount = (state.currentAmount * GOLDEN_RATIO) / PRECISION;
        address firstPool = address(uint160(args[0]));
        uint256 prevAmount = IBEP20(baseToken).balanceOf(firstPool);
        safeTransfer(firstPool, optimalAmount);
        uint256 nextAmount = IBEP20(baseToken).balanceOf(firstPool);
        state.currentAmount = nextAmount - prevAmount;
        for (uint256 i = 0; i < 3;) {
            uint256 preSwapAmount = state.currentAmount;
            state = performSwap(state, i, FOUR_WAY);
            uint256 expectedOutput = geometricMean(preSwapAmount, state.currentAmount);
            if (state.currentAmount < (expectedOutput * GOLDEN_RATIO) / PRECISION)
                revert SuboptimalPath();
            unchecked { ++i; }
        }
        if (state.transitToken != baseToken) revert NonCircularPath();
        if (state.currentAmount < uint128(args[3] >> 128)) revert MinimumProfitNotMet();
        if (state.cumulativeImpact > MAX_SLIPPAGE * 4) revert ExcessiveSlippage();
        return state.currentAmount;
    }
    function fiveWaySwap(uint256[5] calldata args) external onlyOwner whenActive returns (uint256) {
        SwapState memory state = SwapState({
            transitToken: baseToken,
            currentAmount: uint128(args[4]),
            isLastSwap: false,
            amountInWithFee: 0,
            amountOut: 0,
            slippage: 0,
            optimalityScore: PRECISION,
            pathLength: FIVE_WAY,
            cumulativeImpact: 0,
            volumeProfile: 0
        });
        if (state.currentAmount > IBEP20(baseToken).balanceOf(address(this)))
            revert InsufficientFunds();
        uint256 optimalAmount = (state.currentAmount * GOLDEN_RATIO_SQUARED) / PRECISION;
        address firstPool = address(uint160(args[0]));
        uint256 prevAmount = IBEP20(baseToken).balanceOf(firstPool);
        safeTransfer(firstPool, optimalAmount);
        uint256 nextAmount = IBEP20(baseToken).balanceOf(firstPool);
        state.currentAmount = nextAmount - prevAmount;
        uint256[] memory historicalAmounts = new uint256[](4);
        for (uint256 i = 0; i < 4;) {
            uint256 preSwapAmount = state.currentAmount;
            state = performSwap(state, i, FIVE_WAY);
            historicalAmounts[i] = state.currentAmount;
            uint256 expectedOutput;
            if (i == 0) {
                expectedOutput = preSwapAmount;
            } else {
                expectedOutput = geometricMean(
                    historicalAmounts[i-1],
                    i > 1 ? historicalAmounts[i-2] : preSwapAmount
                );
            }
            uint256 tolerance = PRECISION + ((i + 1) * INVERSE_GOLDEN_RATIO) / 5;
            if (state.currentAmount < (expectedOutput * tolerance) / PRECISION)
                revert SuboptimalPath();
            unchecked { ++i; }
        }
        if (state.transitToken != baseToken) revert NonCircularPath();
        if (state.currentAmount < uint128(args[4] >> 128)) revert MinimumProfitNotMet();
        if (state.cumulativeImpact > MAX_SLIPPAGE * 5) revert ExcessiveSlippage();
        return state.currentAmount;
    }
    function updateRiskParams(
        uint256 _maxTradeVolume,
        uint256 _minPoolLiquidity,
        uint256 _maxPriceImpact,
        uint256 _sandwichProtectionBips
    ) external onlyOwner {
        maxTradeVolume = _maxTradeVolume;
        minPoolLiquidity = _minPoolLiquidity;
        maxPriceImpact = _maxPriceImpact;
        sandwichProtectionBips = _sandwichProtectionBips;
        emit RiskParamsUpdated(
            _maxTradeVolume,
            _minPoolLiquidity,
            _maxPriceImpact,
            _sandwichProtectionBips
        );
    }
    function setPoolBlacklist(address pool, bool blacklisted) external onlyOwner {
        blacklistedPools[pool] = blacklisted;
        emit PoolBlacklisted(pool, blacklisted);
    }
    function emergencyPause(bool pause) external onlyOwner {
        isDeactivated = pause;
        emit EmergencyAction(pause);
        if (pause) {
            uint256 balance = IBEP20(baseToken).balanceOf(address(this));
            if (balance > 0) {
                IBEP20(baseToken).transfer(msg.sender, balance);
            }
        }
    }
    function adoptAllowance() external onlyOwner whenActive {
        IBEP20(baseToken).transferFrom(
            msg.sender,
            address(this),
            IBEP20(baseToken).allowance(msg.sender, address(this))
        );
    }
    function withdrawFunds() external onlyOwner {
        IBEP20(baseToken).transfer(msg.sender, IBEP20(baseToken).balanceOf(address(this)));
    }
    function changeAdmin(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Unauthorized();
        assembly {
            sstore(0, newOwner)
        }
    }
    function deactivateContract() external onlyOwner {
        uint256 balance = IBEP20(baseToken).balanceOf(address(this));
        if (balance > 0) {
            IBEP20(baseToken).transfer(msg.sender, balance);
        }
        isDeactivated = true;
    }
}
