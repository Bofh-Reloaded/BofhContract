// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "../libs/SecurityLib.sol";
import "../libs/MathLib.sol";
import "../libs/PoolLib.sol";
import "../interfaces/ISwapInterfaces.sol";
import "../interfaces/IBofhContractBase.sol";

/// @title BofhContractBase - Abstract Base Contract with Security and Risk Management
/// @author Bofh Team
/// @notice Provides security features, risk parameters, and MEV protection for swap contracts
/// @dev Abstract contract inherited by BofhContractV2, implements security primitives and modifiers
/// @custom:security Implements reentrancy protection, access control, pause mechanism, and MEV protection
/// @custom:risk Configurable risk parameters: maxTradeVolume, minPoolLiquidity, maxPriceImpact, sandwichProtection
abstract contract BofhContractBase is IBofhContractBase {
    using SecurityLib for SecurityLib.SecurityState;
    using PoolLib for PoolLib.PoolState;

    /// @notice Security state containing owner, pause status, lock, and access control
    SecurityLib.SecurityState internal securityState;

    /// @notice Base precision for all percentage calculations (1,000,000 = 100%)
    uint256 internal constant PRECISION = 1e6;

    /// @notice Maximum allowed slippage percentage (1% = 10,000)
    uint256 internal constant MAX_SLIPPAGE = PRECISION / 100; // 1%

    /// @notice Minimum optimality threshold for swap paths (50% = 500,000)
    uint256 internal constant MIN_OPTIMALITY = PRECISION / 2; // 50%

    /// @notice Maximum swap path length (6 tokens = 5 hops for 5-way swaps)
    uint256 internal constant MAX_PATH_LENGTH = 6; // Supports up to 5-way swaps (6 tokens = 5 hops)

    /// @notice Mapping of blacklisted pool addresses (true = blacklisted, cannot be used)
    mapping(address => bool) public blacklistedPools;

    /// @notice Maximum trade volume per swap (prevents large trades that could destabilize pools)
    uint256 public maxTradeVolume;

    /// @notice Minimum required pool liquidity (swaps revert if pool liquidity below this)
    uint256 public minPoolLiquidity;

    /// @notice Maximum allowed price impact percentage (swaps revert if exceeded)
    uint256 public maxPriceImpact;

    /// @notice Sandwich attack protection in basis points (additional slippage check)
    uint256 public sandwichProtectionBips;

    /// @notice Per-user rate limiting state for MEV protection
    /// @dev Tracks transactions per block and last transaction timestamp
    /// @custom:field lastBlockNumber Last block number user transacted
    /// @custom:field transactionsThisBlock Count of transactions in current block
    /// @custom:field lastTransactionTimestamp Timestamp of user's last transaction
    struct RateLimitState {
        uint256 lastBlockNumber;
        uint256 transactionsThisBlock;
        uint256 lastTransactionTimestamp;
    }

    /// @notice Per-user rate limit tracking (address => rate limit state)
    mapping(address => RateLimitState) private rateLimits;

    /// @notice MEV protection enabled flag (true = active, false = disabled)
    bool public mevProtectionEnabled;

    /// @notice Maximum transactions allowed per block per user (flash loan detection)
    uint256 public maxTxPerBlock = 3;

    /// @notice Minimum delay required between transactions in seconds (rate limiting)
    uint256 public minTxDelay = 12; // seconds

    // Events and errors inherited from IBofhContractBase interface

    /// @notice Emitted when a swap is successfully executed
    /// @dev Defined here (not in interface) since it's emitted by derived contracts
    /// @param initiator Address that initiated the swap
    /// @param pathLength Number of tokens in the swap path
    /// @param inputAmount Amount of input tokens
    /// @param outputAmount Amount of output tokens received
    /// @param priceImpact Cumulative price impact of the swap
    event SwapExecuted(
        address indexed initiator,
        uint256 pathLength,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 priceImpact
    );

    /// @notice Modifier to restrict function access to contract owner only
    /// @dev Uses SecurityLib.checkOwner, reverts with Unauthorized if not owner
    modifier onlyOwner() {
        securityState.checkOwner();
        _;
    }

    /// @notice Modifier to prevent execution when contract is paused
    /// @dev Uses SecurityLib.checkNotPaused, reverts with ContractPaused if paused
    modifier whenNotPaused() {
        securityState.checkNotPaused();
        _;
    }

    /// @notice Modifier to prevent reentrancy attacks
    /// @dev Uses SecurityLib enter/exitProtectedSection with function selector
    /// @dev Locks before execution, unlocks after, reverts if already locked
    modifier nonReentrant() {
        securityState.enterProtectedSection(msg.sig);
        _;
        securityState.exitProtectedSection();
    }

    /// @notice Internal function to check MEV protection before transaction
    /// @dev Validates flash loan detection and rate limiting rules
    /// @dev Separated from modifier to reduce stack depth (Issue #24)
    /// @custom:security Reverts with FlashLoanDetected if too many txs in one block
    /// @custom:security Reverts with RateLimitExceeded if transactions too frequent
    function _checkMEVProtection() internal {
        if (!mevProtectionEnabled) return;

        RateLimitState storage limit = rateLimits[msg.sender];

        // Detect flash loan (multiple transactions in same block)
        if (limit.lastBlockNumber == block.number) {
            limit.transactionsThisBlock++;
            if (limit.transactionsThisBlock > maxTxPerBlock) {
                revert FlashLoanDetected();
            }
        } else {
            limit.lastBlockNumber = block.number;
            limit.transactionsThisBlock = 1;
        }

        // Enforce minimum delay between transactions
        if (block.timestamp - limit.lastTransactionTimestamp < minTxDelay) {
            revert RateLimitExceeded();
        }
    }

    /// @notice Internal function to update MEV protection state after transaction
    /// @dev Updates timestamp after successful execution
    /// @dev Separated from modifier to reduce stack depth (Issue #24)
    function _updateMEVProtection() internal {
        if (!mevProtectionEnabled) return;
        rateLimits[msg.sender].lastTransactionTimestamp = block.timestamp;
    }

    /// @notice Modifier to prevent MEV attacks via flash loan detection and rate limiting
    /// @dev Only enforces checks when mevProtectionEnabled = true
    /// @dev Flash loan detection: Counts transactions per block, reverts if > maxTxPerBlock
    /// @dev Rate limiting: Enforces minTxDelay seconds between consecutive transactions
    /// @dev Added in Issue #9 for MEV protection
    /// @dev Refactored in Issue #24 to reduce stack depth by extracting logic to internal functions
    /// @custom:security Reverts with FlashLoanDetected if too many txs in one block
    /// @custom:security Reverts with RateLimitExceeded if transactions too frequent
    modifier antiMEV() {
        _checkMEVProtection();
        _;
        _updateMEVProtection();
    }

    /// @notice Initialize base contract with owner and base token, set default risk parameters
    /// @dev Validates addresses are non-zero, sets conservative default risk parameters
    /// @param owner_ Address of contract owner (receives full admin permissions)
    /// @param baseToken_ Address of base token for swaps (not used in base, required by derived)
    /// @custom:security Validates both addresses != address(0)
    /// @custom:defaults maxTradeVolume=1000e6, minPoolLiquidity=100e6, maxPriceImpact=10%, sandwichProtection=0.5%
    constructor(address owner_, address baseToken_) {
        require(owner_ != address(0), "Invalid owner");
        require(baseToken_ != address(0), "Invalid base token");

        securityState.owner = owner_;

        // Initialize with conservative default values
        maxTradeVolume = 1000 * PRECISION;
        minPoolLiquidity = 100 * PRECISION;
        maxPriceImpact = PRECISION / 10; // 10%
        sandwichProtectionBips = 50; // 0.5%
    }

    /// @notice Update risk management parameters
    /// @dev Only callable by owner, validates maxPriceImpact ≤ 20% and sandwichProtection ≤ 1%
    /// @param _maxTradeVolume New maximum trade volume per swap
    /// @param _minPoolLiquidity New minimum required pool liquidity
    /// @param _maxPriceImpact New maximum allowed price impact (max 20% = PRECISION/5)
    /// @param _sandwichProtectionBips New sandwich protection in basis points (max 100 = 1%)
    /// @custom:security Validates price impact and sandwich protection within safe limits
    /// @custom:security Emits RiskParamsUpdated event for off-chain tracking
    function updateRiskParams(
        uint256 _maxTradeVolume,
        uint256 _minPoolLiquidity,
        uint256 _maxPriceImpact,
        uint256 _sandwichProtectionBips
    ) external onlyOwner {
        require(_maxPriceImpact <= PRECISION / 5, "Price impact too high"); // Max 20%
        require(_sandwichProtectionBips <= 100, "Protection too high"); // Max 1%
        
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
    
    /// @notice Blacklist or whitelist a specific pool address
    /// @dev Only callable by owner, prevents swaps through blacklisted pools
    /// @param pool Address of the pool to blacklist/whitelist
    /// @param blacklisted True to blacklist (block swaps), false to whitelist (allow swaps)
    /// @custom:security Validates pool address != address(0)
    /// @custom:security Emits PoolBlacklisted event for off-chain tracking
    function setPoolBlacklist(
        address pool,
        bool blacklisted
    ) external onlyOwner {
        require(pool != address(0), "Invalid pool");
        blacklistedPools[pool] = blacklisted;
        emit PoolBlacklisted(pool, blacklisted);
    }

    /// @notice Configure MEV protection parameters (Issue #9)
    /// @param enabled Enable or disable MEV protection
    /// @param _maxTxPerBlock Maximum transactions per block per address
    /// @param _minTxDelay Minimum seconds between transactions per address
    function configureMEVProtection(
        bool enabled,
        uint256 _maxTxPerBlock,
        uint256 _minTxDelay
    ) external onlyOwner {
        require(_maxTxPerBlock > 0, "Invalid max tx per block");
        require(_minTxDelay > 0, "Invalid min tx delay");

        mevProtectionEnabled = enabled;
        maxTxPerBlock = _maxTxPerBlock;
        minTxDelay = _minTxDelay;

        emit MEVProtectionUpdated(enabled, _maxTxPerBlock, _minTxDelay);
    }

    /// @notice Pause all contract operations in emergency situations
    /// @dev Only callable by owner, sets paused flag via SecurityLib
    /// @dev Blocks all functions with whenNotPaused modifier
    /// @custom:security Use when: exploit detected, critical bug found, oracle compromise
    /// @custom:security Emits SecurityStateChanged event via SecurityLib
    function emergencyPause() external onlyOwner {
        securityState.emergencyPause();
    }

    /// @notice Resume contract operations after emergency is resolved
    /// @dev Only callable by owner, clears paused flag via SecurityLib
    /// @dev Allows functions with whenNotPaused to execute again
    /// @custom:security Only unpause after verifying issue is fully resolved
    /// @custom:security Emits SecurityStateChanged event via SecurityLib
    function emergencyUnpause() external onlyOwner {
        securityState.emergencyUnpause();
    }

    /// @notice Transfer contract ownership to a new address
    /// @dev Only callable by current owner, delegates to SecurityLib.transferOwnership
    /// @param newOwner Address of new owner (must not be address(0))
    /// @custom:security Validates newOwner != address(0) in SecurityLib
    /// @custom:security Emits OwnershipTransferred event via SecurityLib
    function transferOwnership(address newOwner) external onlyOwner {
        securityState.transferOwnership(newOwner);
    }

    /// @notice Grant or revoke operator status for an address
    /// @dev Only callable by owner, delegates to SecurityLib.setOperator
    /// @param operator Address to grant/revoke operator status
    /// @param status True to grant operator role, false to revoke
    /// @custom:security Validates operator != address(0) in SecurityLib
    /// @custom:security Emits OperatorStatusChanged event via SecurityLib
    function setOperator(
        address operator,
        bool status
    ) external onlyOwner {
        securityState.setOperator(operator, status);
    }

    /// @notice Virtual swap execution function to be implemented by derived contracts
    /// @dev SECURITY REQUIREMENT: Override MUST include nonReentrant and whenNotPaused modifiers
    /// @dev Access control: Public execution is allowed, but protected by circuit breakers
    /// @param path Array of token addresses representing the swap path
    /// @param fees Array of fee amounts for each swap step
    /// @param amountIn Input amount for the swap
    /// @param minAmountOut Minimum acceptable output amount (slippage protection)
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return The actual output amount from the swap
    function executeSwap(
        address[] calldata path,
        uint256[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external virtual returns (uint256);

    /// @notice Virtual multi-path swap execution function to be implemented by derived contracts
    /// @dev SECURITY REQUIREMENT: Override MUST include nonReentrant and whenNotPaused modifiers
    /// @dev Access control: Public execution is allowed, but protected by circuit breakers
    /// @param paths Array of swap paths, each path is an array of token addresses
    /// @param fees Array of fee arrays, one per path
    /// @param amounts Array of input amounts, one per path
    /// @param minAmounts Array of minimum output amounts, one per path
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return Array of actual output amounts from each swap path
    function executeMultiSwap(
        address[][] calldata paths,
        uint256[][] calldata fees,
        uint256[] calldata amounts,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external virtual returns (uint256[] memory);

    // View functions for testing and external integrations

    /// @notice Get the contract administrator address
    /// @return The address of the contract owner
    function getAdmin() external view returns (address) {
        return securityState.owner;
    }

    /// @notice Get all risk management parameters
    /// @return maxVolume Maximum trade volume allowed
    /// @return minLiquidity Minimum pool liquidity required
    /// @return maxImpact Maximum price impact allowed (in PRECISION units)
    /// @return sandwichProtection Sandwich attack protection in basis points
    function getRiskParameters() external view returns (
        uint256 maxVolume,
        uint256 minLiquidity,
        uint256 maxImpact,
        uint256 sandwichProtection
    ) {
        return (
            maxTradeVolume,
            minPoolLiquidity,
            maxPriceImpact,
            sandwichProtectionBips
        );
    }

    /// @notice Check if a pool is blacklisted
    /// @param pool The address of the pool to check
    /// @return True if the pool is blacklisted, false otherwise
    function isPoolBlacklisted(address pool) external view returns (bool) {
        return blacklistedPools[pool];
    }

    /// @notice Check if the contract is currently paused
    /// @return True if paused, false if active
    function isPaused() external view returns (bool) {
        return securityState.paused;
    }

    /// @notice Get MEV protection configuration
    /// @return enabled Whether MEV protection is enabled
    /// @return maxTx Maximum transactions per block
    /// @return minDelay Minimum delay between transactions in seconds
    function getMEVProtectionConfig() external view returns (
        bool enabled,
        uint256 maxTx,
        uint256 minDelay
    ) {
        return (
            mevProtectionEnabled,
            maxTxPerBlock,
            minTxDelay
        );
    }
}