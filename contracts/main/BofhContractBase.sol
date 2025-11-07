// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "../libs/SecurityLib.sol";
import "../libs/MathLib.sol";
import "../libs/PoolLib.sol";
import "../interfaces/ISwapInterfaces.sol";

abstract contract BofhContractBase {
    using SecurityLib for SecurityLib.SecurityState;
    using PoolLib for PoolLib.PoolState;

    // Security and state management
    SecurityLib.SecurityState internal securityState;
    
    // Constants
    uint256 internal constant PRECISION = 1e6;
    uint256 internal constant MAX_SLIPPAGE = PRECISION / 100; // 1%
    uint256 internal constant MIN_OPTIMALITY = PRECISION / 2; // 50%
    uint256 internal constant MAX_PATH_LENGTH = 5;
    
    // Risk management
    mapping(address => bool) public blacklistedPools;
    uint256 public maxTradeVolume;
    uint256 public minPoolLiquidity;
    uint256 public maxPriceImpact;
    uint256 public sandwichProtectionBips;

    // MEV Protection (Issue #9)
    struct RateLimitState {
        uint256 lastBlockNumber;
        uint256 transactionsThisBlock;
        uint256 lastTransactionTimestamp;
    }
    mapping(address => RateLimitState) private rateLimits;

    // MEV Protection Configuration
    bool public mevProtectionEnabled;
    uint256 public maxTxPerBlock = 3;
    uint256 public minTxDelay = 12; // seconds

    // MEV Protection Events
    event MEVProtectionUpdated(bool enabled, uint256 maxTxPerBlock, uint256 minTxDelay);

    // MEV Protection Errors
    error FlashLoanDetected();
    error RateLimitExceeded();
    
    // Events
    event PoolBlacklisted(address indexed pool, bool blacklisted);
    event RiskParamsUpdated(
        uint256 maxVolume,
        uint256 minLiquidity,
        uint256 maxImpact,
        uint256 sandwichProtection
    );
    event SwapExecuted(
        address indexed initiator,
        uint256 pathLength,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 priceImpact
    );
    
    // Modifiers
    modifier onlyOwner() {
        securityState.checkOwner();
        _;
    }
    
    modifier whenNotPaused() {
        securityState.checkNotPaused();
        _;
    }
    
    modifier nonReentrant() {
        securityState.enterProtectedSection(msg.sig);
        _;
        securityState.exitProtectedSection();
    }

    /// @dev MEV protection modifier (Issue #9)
    /// @notice Prevents flash loan attacks and rate limits transactions (if enabled)
    modifier antiMEV() {
        if (mevProtectionEnabled) {
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

            _;

            // Update timestamp after successful execution
            limit.lastTransactionTimestamp = block.timestamp;
        } else {
            _;
        }
    }

    // Constructor
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

    // Risk management functions
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

    // Emergency functions
    function emergencyPause() external onlyOwner {
        securityState.emergencyPause();
    }
    
    function emergencyUnpause() external onlyOwner {
        securityState.emergencyUnpause();
    }
    
    // Access control
    function transferOwnership(address newOwner) external onlyOwner {
        securityState.transferOwnership(newOwner);
    }
    
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