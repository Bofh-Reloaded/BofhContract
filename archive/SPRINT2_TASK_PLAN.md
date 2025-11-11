# SPRINT 2 - Task Plan: Security & Testing

**Project**: BofhContract V2
**Sprint**: SPRINT 2 - Security Enhancements & Testing Infrastructure
**Status**: 🟡 PLANNING
**Start Date**: 2025-11-07
**Estimated Duration**: 3-4 days
**Dependencies**: SPRINT 1 (✅ COMPLETE)

---

## 🎯 Sprint Objectives

### Primary Goals
1. ✅ Migrate testing infrastructure from Truffle/Ganache to Hardhat
2. ✅ Create comprehensive test suite with 90%+ coverage
3. ✅ Enhance security features (MEV protection, input validation, access control)
4. ✅ Resolve Node.js v25 compatibility issues

### Success Criteria
- [ ] All contracts compile with Hardhat
- [ ] Test suite runs without errors
- [ ] Code coverage ≥ 90%
- [ ] All SPRINT 2 issues resolved
- [ ] Security audit tools integrated (Slither, Mythril)
- [ ] CI/CD pipeline functional

---

## 📋 Issues in SPRINT 2

### Issue #6: Create Comprehensive Test Suite (90%+ Coverage)
**Priority**: 🔶 HIGH
**Labels**: testing, priority:high
**Estimate**: 1.5 days
**Dependencies**: Task 2.1 (Hardhat migration)

### Issue #7: Add Missing Access Control to Virtual Functions
**Priority**: 🔶 HIGH
**Labels**: security, priority:high
**Estimate**: 0.5 days
**Dependencies**: None

### Issue #8: Add Comprehensive Input Validation
**Priority**: 🔶 HIGH
**Labels**: security, priority:high
**Estimate**: 0.5 days
**Dependencies**: None

### Issue #9: Enhance MEV Protection Against Flash Loan Attacks
**Priority**: 🔶 HIGH
**Labels**: security, priority:high
**Estimate**: 0.5 days
**Dependencies**: None

**Total Estimated Time**: 3 days

---

## 🔄 Task Breakdown with TDD

### Task 2.1: Migrate to Hardhat Testing Framework
**Priority**: CRITICAL (Blocking)
**Estimate**: 1 day
**Issue**: #6 (partial)
**Approach**: RED-GREEN-REFACTOR

#### Subtasks:
1. **Install Hardhat Dependencies**
   - [ ] Add hardhat and hardhat-toolbox
   - [ ] Add @nomicfoundation/hardhat-chai-matchers
   - [ ] Add @nomicfoundation/hardhat-ethers
   - [ ] Add hardhat-gas-reporter
   - [ ] Add solidity-coverage

2. **Create Hardhat Configuration**
   - [ ] Create hardhat.config.js with BSC testnet
   - [ ] Configure Solidity compiler (0.8.10)
   - [ ] Set up networks (localhost, BSC testnet)
   - [ ] Configure gas reporter
   - [ ] Configure coverage plugin

3. **Migrate Test Structure**
   - [ ] Convert existing Truffle tests to Hardhat format
   - [ ] Update from web3 to ethers.js
   - [ ] Replace OpenZeppelin test-helpers with Hardhat matchers
   - [ ] Update deployment scripts for Hardhat
   - [ ] Update package.json scripts

4. **Verify Migration**
   - [ ] Compile all contracts with Hardhat
   - [ ] Run migrated tests (should pass)
   - [ ] Generate coverage report
   - [ ] Verify deployment works

**Acceptance Criteria**:
- ✅ All contracts compile with `npx hardhat compile`
- ✅ Existing tests pass with `npx hardhat test`
- ✅ Coverage report generates successfully
- ✅ No Ganache/Node.js v25 compatibility issues

---

### Task 2.2: Create Comprehensive Test Suite
**Priority**: HIGH
**Estimate**: 1.5 days
**Issue**: #6
**Approach**: RED-GREEN-REFACTOR

#### Subtasks:

**Phase 1: Unit Tests for Core Functions (0.5 days)**
1. **BofhContractV2 Core Tests**
   - [ ] Test fourWaySwap() with valid inputs
   - [ ] Test fourWaySwap() with invalid paths
   - [ ] Test fiveWaySwap() with valid inputs
   - [ ] Test fiveWaySwap() edge cases
   - [ ] Test slippage protection
   - [ ] Test deadline enforcement
   - [ ] Test reentrancy protection
   - [ ] Test ownership transfer

2. **Library Tests**
   - [ ] Test MathLib.sqrt() with various inputs
   - [ ] Test MathLib.cbrt() with various inputs
   - [ ] Test MathLib.geometricMean()
   - [ ] Test PoolLib liquidity calculations
   - [ ] Test SecurityLib access control
   - [ ] Test SecurityLib reentrancy guard

**Phase 2: Integration Tests (0.5 days)**
1. **Multi-Path Swap Scenarios**
   - [ ] Test 4-way swap with realistic liquidity
   - [ ] Test 5-way swap with realistic liquidity
   - [ ] Test swap with multiple tokens
   - [ ] Test swap with high price impact
   - [ ] Test swap with blacklisted pools
   - [ ] Test emergency pause during swap

2. **Risk Management Tests**
   - [ ] Test max trade volume enforcement
   - [ ] Test min liquidity requirements
   - [ ] Test max price impact limits
   - [ ] Test sandwich protection
   - [ ] Test circuit breakers

**Phase 3: Edge Cases & Security Tests (0.5 days)**
1. **Attack Vector Tests**
   - [ ] Test reentrancy attack attempts
   - [ ] Test front-running scenarios
   - [ ] Test sandwich attack attempts
   - [ ] Test flash loan attack scenarios
   - [ ] Test unauthorized access attempts
   - [ ] Test integer overflow/underflow (should be impossible in 0.8.10)

2. **Boundary Tests**
   - [ ] Test with zero amounts
   - [ ] Test with maximum uint256 values
   - [ ] Test with path length = 2 (minimum)
   - [ ] Test with path length = 5 (maximum)
   - [ ] Test with empty liquidity pools
   - [ ] Test with very high liquidity

**Acceptance Criteria**:
- ✅ Code coverage ≥ 90% for all contracts
- ✅ All critical functions covered
- ✅ All edge cases tested
- ✅ All security scenarios validated
- ✅ Gas usage documented for key operations

---

### Task 2.3: Add Missing Access Control to Virtual Functions
**Priority**: HIGH
**Estimate**: 0.5 days
**Issue**: #7
**Approach**: RED-GREEN-REFACTOR

#### Problem:
Virtual functions in BofhContractBase.sol lack proper access control modifiers:
- `_executeSwap()` - Should be internal only (already is)
- `_validatePath()` - Should be internal only (already is)
- `_calculatePriceImpact()` - Should be internal only (already is)

Virtual functions that override behavior need careful review.

#### Subtasks:
1. **Audit Virtual Functions**
   - [ ] List all virtual functions in BofhContractBase
   - [ ] Identify which need access control
   - [ ] Check for unintended public exposure

2. **Add Access Control**
   - [ ] Add appropriate modifiers to virtual functions
   - [ ] Add override checks where needed
   - [ ] Update derived contracts (BofhContractV2)

3. **Write Tests**
   - [ ] Test unauthorized override attempts
   - [ ] Test proper inheritance chain
   - [ ] Test access control enforcement

**Files to Modify**:
- `contracts/main/BofhContractBase.sol`
- `contracts/main/BofhContractV2.sol`
- `test/BofhContractV2.test.js` (add new tests)

**Acceptance Criteria**:
- ✅ All virtual functions have appropriate access control
- ✅ Tests verify access control enforcement
- ✅ No unintended public exposure
- ✅ Inheritance chain properly secured

---

### Task 2.4: Add Comprehensive Input Validation
**Priority**: HIGH
**Estimate**: 0.5 days
**Issue**: #8
**Approach**: RED-GREEN-REFACTOR

#### Problem:
Several functions lack comprehensive input validation:
- Token addresses not validated for zero address
- Array lengths not validated for consistency
- Amount bounds not checked
- Path validation incomplete

#### Subtasks:
1. **Audit Input Validation**
   - [ ] Review all public/external functions
   - [ ] Identify missing validations
   - [ ] Document validation requirements

2. **Add Validations**
   - [ ] Add address(0) checks for all address inputs
   - [ ] Add array length consistency checks
   - [ ] Add amount bound checks (min/max)
   - [ ] Add path validation improvements
   - [ ] Add fee validation (must be < 10000 bps)
   - [ ] Add deadline validation (must be future timestamp)

3. **Create Custom Errors**
   - [ ] Add `InvalidAddress()` error
   - [ ] Add `InvalidAmount()` error
   - [ ] Add `InvalidArrayLength()` error
   - [ ] Add `InvalidFee()` error

4. **Write Tests**
   - [ ] Test zero address rejection
   - [ ] Test invalid amount rejection
   - [ ] Test mismatched array lengths
   - [ ] Test invalid fees
   - [ ] Test invalid deadlines

**Files to Modify**:
- `contracts/main/BofhContractV2.sol`
- `contracts/main/BofhContractBase.sol`
- `test/BofhContractV2.test.js` (add new tests)

**Example Validations to Add**:
```solidity
function fourWaySwap(
    address[] memory path,
    uint24[] memory fees,
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline
) external onlyOwner whenActive nonReentrant returns (uint256) {
    // NEW VALIDATIONS
    if (path.length == 0) revert InvalidPath();
    if (fees.length != path.length - 1) revert InvalidArrayLength();
    if (amountIn == 0) revert InvalidAmount();
    if (minAmountOut == 0) revert InvalidAmount();
    if (deadline <= block.timestamp) revert DeadlineExpired();

    for (uint256 i = 0; i < path.length; i++) {
        if (path[i] == address(0)) revert InvalidAddress();
    }

    for (uint256 i = 0; i < fees.length; i++) {
        if (fees[i] > 10000) revert InvalidFee(); // Max 100%
    }

    // Existing logic...
}
```

**Acceptance Criteria**:
- ✅ All inputs validated at function entry
- ✅ Custom errors for each validation type
- ✅ Tests cover all validation scenarios
- ✅ Gas-efficient validation (minimal overhead)

---

### Task 2.5: Enhance MEV Protection Against Flash Loan Attacks
**Priority**: HIGH
**Estimate**: 0.5 days
**Issue**: #9
**Approach**: RED-GREEN-REFACTOR

#### Problem:
Current MEV protection is basic:
- Deadline checks (prevents delayed execution)
- Sandwich protection (basic price impact monitoring)
- Missing: Flash loan attack detection, multi-block attack prevention

#### Subtasks:
1. **Research MEV Attack Vectors**
   - [ ] Study flash loan attack patterns
   - [ ] Analyze sandwich attack techniques
   - [ ] Review front-running scenarios
   - [ ] Study time-bandit attacks

2. **Implement Enhanced Protection**
   - [ ] Add flash loan detection (check block.number for same-block borrows)
   - [ ] Add multi-transaction rate limiting
   - [ ] Add liquidity change monitoring
   - [ ] Add price oracle integration (optional)
   - [ ] Enhance sandwich protection

3. **Add Rate Limiting**
   - [ ] Track transactions per block
   - [ ] Track transactions per address
   - [ ] Add configurable rate limits
   - [ ] Add cooldown periods

4. **Write Tests**
   - [ ] Test flash loan attack prevention
   - [ ] Test rate limiting enforcement
   - [ ] Test multi-transaction attacks
   - [ ] Test cooldown period enforcement

**Files to Modify**:
- `contracts/main/BofhContractBase.sol` (add protection logic)
- `contracts/libs/SecurityLib.sol` (add rate limiting)
- `contracts/main/BofhContractV2.sol` (apply protections)
- `test/BofhContractV2.test.js` (add attack tests)

**Example Implementation**:
```solidity
// In BofhContractBase.sol
struct RateLimitState {
    uint256 lastBlockNumber;
    uint256 transactionsThisBlock;
    uint256 lastTransactionTimestamp;
}

mapping(address => RateLimitState) private rateLimits;

uint256 private constant MAX_TX_PER_BLOCK = 3;
uint256 private constant MIN_TX_DELAY = 12; // seconds

modifier antiFlashLoan() {
    RateLimitState storage limit = rateLimits[msg.sender];

    // Detect flash loan (multiple transactions in same block)
    if (limit.lastBlockNumber == block.number) {
        limit.transactionsThisBlock++;
        if (limit.transactionsThisBlock > MAX_TX_PER_BLOCK) {
            revert FlashLoanDetected();
        }
    } else {
        limit.lastBlockNumber = block.number;
        limit.transactionsThisBlock = 1;
    }

    // Enforce minimum delay between transactions
    if (block.timestamp - limit.lastTransactionTimestamp < MIN_TX_DELAY) {
        revert RateLimitExceeded();
    }

    _;

    limit.lastTransactionTimestamp = block.timestamp;
}
```

**Acceptance Criteria**:
- ✅ Flash loan attacks prevented
- ✅ Rate limiting enforced
- ✅ Configurable protection parameters
- ✅ Tests validate all protection mechanisms
- ✅ Gas overhead < 50k per transaction

---

### Task 2.6: Integrate Security Audit Tools
**Priority**: MEDIUM
**Estimate**: 0.5 days
**Issue**: None (proactive)
**Approach**: Tool integration and CI/CD

#### Subtasks:
1. **Install Security Tools**
   - [ ] Install Slither (static analysis)
   - [ ] Install Mythril (symbolic execution)
   - [ ] Install Echidna (fuzzing) - optional
   - [ ] Add to package.json scripts

2. **Run Initial Scans**
   - [ ] Run Slither and analyze results
   - [ ] Run Mythril and analyze results
   - [ ] Document findings
   - [ ] Create issues for any high-severity findings

3. **Create GitHub Actions Workflow**
   - [ ] Create .github/workflows/security.yml
   - [ ] Add Slither job
   - [ ] Add Mythril job (optional, slow)
   - [ ] Add test coverage job
   - [ ] Add compilation check

4. **Create CI/CD Pipeline**
   - [ ] Create .github/workflows/ci.yml
   - [ ] Add build job
   - [ ] Add test job with coverage
   - [ ] Add deployment job (manual trigger)

**Files to Create**:
- `.github/workflows/security.yml`
- `.github/workflows/ci.yml`
- `scripts/security-scan.sh`

**Example GitHub Actions Workflow**:
```yaml
name: Security Audit

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  slither:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install --legacy-peer-deps
      - uses: crytic/slither-action@v0.3.0
        with:
          target: 'contracts/'
          slither-args: '--filter-paths "node_modules|test" --exclude naming-convention,solc-version'
```

**Acceptance Criteria**:
- ✅ Security tools installed and functional
- ✅ GitHub Actions workflows created
- ✅ CI/CD pipeline runs on every PR
- ✅ Security findings documented and addressed

---

## 📊 Sprint Execution Plan

### Phase 1: Infrastructure (Day 1)
**Goal**: Get Hardhat working and tests running

1. Morning: Task 2.1 - Hardhat Migration
   - Install dependencies
   - Create configuration
   - Migrate basic tests

2. Afternoon: Task 2.1 (continued)
   - Verify compilation
   - Run migrated tests
   - Fix any migration issues

**End of Day 1 Checklist**:
- [ ] Hardhat installed and configured
- [ ] All contracts compile
- [ ] Basic tests pass
- [ ] Coverage report generates

---

### Phase 2: Security Fixes (Day 2)
**Goal**: Complete all security enhancements

1. Morning:
   - Task 2.3 - Access Control (2 hours)
   - Task 2.4 - Input Validation (2 hours)

2. Afternoon:
   - Task 2.5 - MEV Protection (2 hours)
   - Task 2.6 - Security Tools Setup (2 hours)

**End of Day 2 Checklist**:
- [ ] All security issues resolved
- [ ] Security tools integrated
- [ ] Initial security scan complete

---

### Phase 3: Testing & Coverage (Day 3)
**Goal**: Achieve 90%+ test coverage

1. Full Day: Task 2.2 - Comprehensive Test Suite
   - Morning: Unit tests
   - Afternoon: Integration tests
   - Evening: Edge cases and security tests

**End of Day 3 Checklist**:
- [ ] Test coverage ≥ 90%
- [ ] All critical paths tested
- [ ] Security scenarios validated

---

### Phase 4: Review & Release (Day 4 - Half Day)
**Goal**: Code review, documentation, and release

1. Morning:
   - Run comprehensive code review
   - Generate coverage reports
   - Update documentation
   - Create release PR

2. Afternoon:
   - Address review feedback
   - Merge and release v1.2.0
   - Close SPRINT 2 milestone

**End of Sprint Checklist**:
- [ ] All SPRINT 2 issues closed
- [ ] Code coverage ≥ 90%
- [ ] Security audit tools integrated
- [ ] CI/CD pipeline functional
- [ ] v1.2.0 released

---

## 🧪 Testing Strategy

### Test Categories

1. **Unit Tests** (Target: 80% coverage)
   - Individual function testing
   - Library function testing
   - Modifier behavior testing

2. **Integration Tests** (Target: 70% coverage)
   - Multi-contract interactions
   - End-to-end swap scenarios
   - Risk management integration

3. **Security Tests** (Target: 100% of attack vectors)
   - Reentrancy attempts
   - Access control bypasses
   - MEV attack scenarios
   - Input validation bypasses

4. **Edge Case Tests** (Target: All identified edge cases)
   - Boundary values
   - Zero/max values
   - Empty arrays
   - Invalid states

### Test Coverage Goals

| Contract | Target Coverage | Priority |
|----------|----------------|----------|
| BofhContractV2 | 95% | Critical |
| BofhContractBase | 90% | Critical |
| MathLib | 100% | High |
| PoolLib | 90% | High |
| SecurityLib | 100% | Critical |
| MockContracts | 70% | Low |

---

## 📈 Success Metrics

### Code Quality
- [ ] Test coverage ≥ 90%
- [ ] All contracts compile without warnings
- [ ] Slither scan passes (no high/critical issues)
- [ ] Gas usage optimized (< 500k for complex swaps)

### Security
- [ ] All identified vulnerabilities fixed
- [ ] Security audit tools integrated
- [ ] No high-severity findings from Slither/Mythril
- [ ] Reentrancy protection verified

### Infrastructure
- [ ] Hardhat fully functional
- [ ] CI/CD pipeline operational
- [ ] Coverage reports automated
- [ ] Deployment scripts updated

### Documentation
- [ ] All security fixes documented
- [ ] Test documentation complete
- [ ] SPRINT2_COMPLETE.md created
- [ ] RELEASE_NOTES_v1.2.0.md created

---

## 🔒 Security Considerations

### Critical Security Features to Test
1. Reentrancy protection on all external calls
2. Access control on all privileged functions
3. Input validation on all public functions
4. MEV protection mechanisms
5. Rate limiting and cooldown periods
6. Emergency pause functionality

### Attack Scenarios to Test
1. Flash loan attacks
2. Sandwich attacks
3. Front-running attempts
4. Reentrancy attacks
5. Integer overflow/underflow (should be impossible in 0.8.10)
6. Unauthorized access attempts

---

## 📝 Documentation Requirements

### Code Documentation
- [ ] NatSpec comments on all public functions
- [ ] Security notes on all critical functions
- [ ] Gas optimization notes where applicable
- [ ] Test coverage documentation

### User Documentation
- [ ] Updated README with new test commands
- [ ] Migration guide from Truffle to Hardhat
- [ ] Security audit report summary
- [ ] Deployment guide updates

### Developer Documentation
- [ ] SPRINT2_PROGRESS.md (real-time tracking)
- [ ] SPRINT2_COMPLETE.md (summary)
- [ ] CODE_REVIEW_REPORT_v1.2.0.md
- [ ] RELEASE_NOTES_v1.2.0.md

---

## ⚠️ Risks and Mitigations

### Risk 1: Hardhat Migration Complexity
**Risk**: Migration from Truffle to Hardhat may uncover unexpected issues
**Likelihood**: Medium
**Impact**: High (could block all testing)
**Mitigation**:
- Thorough testing of migration
- Keep Truffle config as backup
- Incremental migration approach

### Risk 2: Test Coverage Goal
**Risk**: 90% coverage may be difficult to achieve
**Likelihood**: Low
**Impact**: Medium (quality goal not met)
**Mitigation**:
- Prioritize critical paths first
- Use coverage reports to identify gaps
- Add tests incrementally

### Risk 3: Security Tool False Positives
**Risk**: Slither/Mythril may generate many false positives
**Likelihood**: High
**Impact**: Low (time consuming to triage)
**Mitigation**:
- Configure tools to filter known false positives
- Document all findings and decisions
- Focus on high-severity issues first

---

## 🔗 Dependencies

### External Dependencies
- Hardhat and hardhat-toolbox
- ethers.js v6
- OpenZeppelin Contracts v4.9.6
- Slither (Python-based)
- Mythril (optional)

### Internal Dependencies
- SPRINT 1 completion (✅ COMPLETE)
- Clean compilation of all contracts
- Functional deployment scripts

---

## 📅 Timeline

**Start**: 2025-11-07
**Estimated End**: 2025-11-11 (4 days)
**Buffer**: 1 day for unexpected issues

### Milestones
- Day 1 End: Hardhat functional with basic tests passing
- Day 2 End: All security fixes complete
- Day 3 End: Test coverage ≥ 90%
- Day 4 End: Code review, release, and SPRINT 2 closure

---

## 🎯 Definition of Done

A task is considered complete when:
- [ ] Code implementation finished
- [ ] Tests written and passing
- [ ] Coverage target met
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Committed and pushed to feature branch

SPRINT 2 is considered complete when:
- [ ] All 4 issues resolved (#6, #7, #8, #9)
- [ ] Test coverage ≥ 90%
- [ ] All security enhancements implemented
- [ ] CI/CD pipeline functional
- [ ] Code review approved
- [ ] v1.2.0 released
- [ ] Milestone closed

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
