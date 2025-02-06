// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

library SecurityLib {
    // Custom errors for gas optimization
    error Unauthorized();
    error ReentrancyGuardError();
    error ContractPaused();
    error DeadlineExpired();
    error InvalidAddress();
    error ExcessiveValue();
    error ContractLocked();

    struct SecurityState {
        address owner;
        bool paused;
        bool locked;
        uint256 lastActionTimestamp;
        mapping(address => bool) operators;
        mapping(bytes4 => uint256) functionCooldowns;
        mapping(address => uint256) userActionCounts;
        uint256 globalActionCounter;
    }

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorStatusChanged(address indexed operator, bool status);
    event SecurityStateChanged(bool paused, bool locked);
    event AnomalyDetected(address indexed user, bytes4 indexed selector, string reason);

    // Modifier-like functions
    function checkOwner(SecurityState storage self) internal view {
        if (msg.sender != self.owner) revert Unauthorized();
    }

    function checkOperator(SecurityState storage self) internal view {
        if (!self.operators[msg.sender] && msg.sender != self.owner) revert Unauthorized();
    }

    function checkNotPaused(SecurityState storage self) internal view {
        if (self.paused) revert ContractPaused();
    }

    function checkNotLocked(SecurityState storage self) internal view {
        if (self.locked) revert ContractLocked();
    }

    // Reentrancy guard with cooldown
    function enterProtectedSection(
        SecurityState storage self,
        bytes4 selector
    ) internal {
        if (self.locked) revert ReentrancyGuardError();
        
        uint256 cooldown = self.functionCooldowns[selector];
        if (cooldown > 0 && block.timestamp - self.lastActionTimestamp < cooldown) {
            revert ReentrancyGuardError();
        }
        
        self.locked = true;
        self.lastActionTimestamp = block.timestamp;
    }

    function exitProtectedSection(SecurityState storage self) internal {
        self.locked = false;
    }

    // Advanced access control
    function transferOwnership(
        SecurityState storage self,
        address newOwner
    ) internal {
        address oldOwner = self.owner;
        if (msg.sender != oldOwner) revert Unauthorized();
        if (newOwner == address(0)) revert InvalidAddress();
        
        self.owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function setOperator(
        SecurityState storage self,
        address operator,
        bool status
    ) internal {
        if (msg.sender != self.owner) revert Unauthorized();
        if (operator == address(0)) revert InvalidAddress();
        
        self.operators[operator] = status;
        emit OperatorStatusChanged(operator, status);
    }

    // Emergency controls
    function emergencyPause(SecurityState storage self) internal {
        if (msg.sender != self.owner) revert Unauthorized();
        self.paused = true;
        emit SecurityStateChanged(true, self.locked);
    }

    function emergencyUnpause(SecurityState storage self) internal {
        if (msg.sender != self.owner) revert Unauthorized();
        self.paused = false;
        emit SecurityStateChanged(false, self.locked);
    }

    // Rate limiting and anomaly detection
    function checkRateLimit(
        SecurityState storage self,
        address user,
        uint256 maxActionsPerInterval,
        uint256 interval
    ) internal {
        uint256 currentTime = block.timestamp;
        if (currentTime - self.lastActionTimestamp >= interval) {
            // Reset counters after interval
            self.userActionCounts[user] = 0;
            self.globalActionCounter = 0;
            self.lastActionTimestamp = currentTime;
        }

        // Check user-specific limit
        if (self.userActionCounts[user] >= maxActionsPerInterval) {
            emit AnomalyDetected(user, msg.sig, "Rate limit exceeded");
            revert ExcessiveValue();
        }

        // Update counters
        self.userActionCounts[user]++;
        self.globalActionCounter++;
    }

    // Function cooldown management
    function setFunctionCooldown(
        SecurityState storage self,
        bytes4 selector,
        uint256 cooldownPeriod
    ) internal {
        if (msg.sender != self.owner) revert Unauthorized();
        self.functionCooldowns[selector] = cooldownPeriod;
    }

    // Deadline validation with grace period
    function validateDeadline(
        uint256 deadline,
        uint256 gracePeriod
    ) internal view {
        if (block.timestamp > deadline + gracePeriod) {
            revert DeadlineExpired();
        }
    }

    // Value bounds checking
    function checkValueBounds(
        uint256 value,
        uint256 minValue,
        uint256 maxValue
    ) internal pure {
        if (value < minValue || value > maxValue) {
            revert ExcessiveValue();
        }
    }

    // Address validation
    function validateAddress(address addr) internal view {
        if (addr == address(0) || addr.code.length == 0) {
            revert InvalidAddress();
        }
    }

    // Contract size check for anti-contract bias
    function ensureNotContract(address addr) internal view {
        if (addr.code.length > 0) {
            revert InvalidAddress();
        }
    }
}