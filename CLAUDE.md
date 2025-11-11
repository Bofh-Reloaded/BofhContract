# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BofhContract V2** is an advanced smart contract system for executing optimized multi-path token swaps on EVM-compatible blockchains (primarily BSC testnet). It implements sophisticated mathematical algorithms using the golden ratio (φ ≈ 0.618034) for 4-way and 5-way swap path optimization, with robust security features including MEV protection, circuit breakers, and comprehensive access control.

## Architecture

### Contract Hierarchy

```
BofhContractV2 (main implementation)
    └── BofhContractBase (abstract base with security & risk management)
         ├── Uses SecurityLib (access control, reentrancy protection, rate limiting)
         ├── Uses MathLib (sqrt, cbrt, geometric mean, golden ratio calculations)
         └── Uses PoolLib (liquidity analysis, price impact calculations)
```

### Key Contract Files

- `contracts/main/BofhContractV2.sol` - Main swap execution logic with path optimization
- `contracts/main/BofhContractBase.sol` - Base contract with security features and risk parameters
- `contracts/libs/MathLib.sol` - Mathematical operations using Newton's method for sqrt/cbrt
- `contracts/libs/PoolLib.sol` - Pool state management and liquidity analysis
- `contracts/libs/SecurityLib.sol` - Security primitives (reentrancy guards, access control)
- `contracts/interfaces/ISwapInterfaces.sol` - Interface definitions for DEX integration

### Mock Contracts (for testing)

- `contracts/mocks/MockToken.sol` - ERC20 token implementation for tests
- `contracts/mocks/MockPair.sol` - Uniswap V2-style pair with CPMM (x*y=k)
- `contracts/mocks/MockFactory.sol` - Factory for creating mock pairs

### Python CLI Tool

Located in `bofh/contract/`:
- `__main__.py` - CLI interface for contract interaction, method selector enumeration
- `__init__.py` - Contract interface utilities

## Development Commands

### Solidity Contract Development

```bash
# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Generate coverage report
npx hardhat coverage

# Deploy to BSC testnet
npm run migrate

# Verify deployed contract on BSCScan
npm run verify
```

### Python CLI Tool

```bash
# Install Python package
pip install -e .

# Run CLI interface
python -m bofh.contract

# Clean build artifacts
python setup.py clean
```

## Important Development Context

### Solidity Version & Compiler Settings

- Primary version: `0.8.10+` (for main contracts in `contracts/main/` and `contracts/libs/`)
- Legacy version: `0.6.12` (Truffle config for compatibility with some dependencies)
- Optimizer: **Enabled** in hardhat.config.js (200 runs)
- EVM version: `london`

### Network Configuration

The project uses BSC (Binance Smart Chain) testnet:
- Network ID: 97
- RPC: `https://data-seed-prebsc-1-s1.binance.org:8545`
- Explorer: BSCScan
- Mnemonic and API keys configured in `env.json` (not committed to git)

### Constants & Risk Parameters

Key constants defined in `BofhContractBase.sol`:
- `PRECISION = 1e6` - Base precision for calculations
- `MAX_SLIPPAGE = 1%` - Maximum allowed slippage
- `MIN_OPTIMALITY = 50%` - Minimum optimality threshold
- `MAX_PATH_LENGTH = 5` - Maximum swap path length

Default risk parameters (configurable via `updateRiskParams`):
- `maxTradeVolume = 1000 * PRECISION`
- `minPoolLiquidity = 100 * PRECISION`
- `maxPriceImpact = 10%`
- `sandwichProtectionBips = 50` (0.5%)

### Swap Algorithm Design

The contract uses a golden ratio-based optimization strategy:
- 4-way swaps: Split amounts using φ ≈ 0.618034
- 5-way swaps: Advanced optimization with geometric mean validation
- Path validation: All paths must start and end with baseToken
- Price impact tracking: Cumulative impact across entire path
- Slippage protection: Enforced via `minAmountOut` parameter

### Security Features

1. **Reentrancy Protection**: Via `SecurityLib.enterProtectedSection`/`exitProtectedSection`
2. **Access Control**: Owner-only functions with `onlyOwner` modifier
3. **Circuit Breakers**: Pause functionality via `whenNotPaused` modifier
4. **MEV Protection**: Deadline checks and sandwich attack mitigation with flash loan detection
5. **Blacklist System**: Pool-level blacklisting capability
6. **Input Validation**: Comprehensive validation with custom errors
7. **Rate Limiting**: Configurable max transactions per block and minimum delay

### Testing Architecture

Tests use:
- Hardhat framework with ethers.js
- Chai assertions
- Test fixtures via `loadFixture()` for efficiency
- Time manipulation via `@nomicfoundation/hardhat-toolbox/network-helpers`
- Test files:
  - `test/BofhContractV2.test.js` (44 tests for main contract)
  - `test/Libraries.test.js` (62 tests for library functions)
- Current coverage: 47.23% overall, 93.5% libraries, 64.29% for BofhContractBase

Test setup creates:
- Multiple mock tokens (BASE, TKNA, TKNB, TKNC)
- Mock factory for pair creation
- Pre-funded liquidity pools for swap testing

## Enhanced Development Workflow

### Code Standards & Quality Gates

#### Definition of Done (DoD)

- **Tests**:
  - Unit tests with ≥90% coverage for contracts
  - 100% pass rate for all test suites
  - Test pyramid: 70% unit, 25% integration, 5% e2e
- **Linting**:
  - Solidity: Pass `solhint` checks
  - JavaScript/TypeScript: Pass project linter
- **Security**:
  - Pass security scanning (Slither when available)
  - No high/critical vulnerabilities
  - No secrets in code
- **CI**: Green pipeline on all tests
- **Documentation**:
  - NatSpec comments on all public/external functions
  - Update README if user-facing changes
- **Commits**: Use Conventional Commits format
  - `feat:` - New features
  - `fix:` - Bug fixes
  - `docs:` - Documentation only
  - `test:` - Adding/updating tests
  - `refactor:` - Code refactoring
  - `chore:` - Maintenance tasks

#### File Size Limits

- **Soft Limit**: 300 lines per file
- **Hard Limit**: 500 lines per file
- **Refactoring Rule**: If a file exceeds hardLimit by >20% after modification, immediately:
  1. Pause current work
  2. Create refactoring sub-task to split the file
  3. Complete and commit the refactor
  4. Resume original task

### Test-Driven Development (TDD)

Follow RED→GREEN→REFACTOR cycle:

1. **RED**: Write failing test first
2. **GREEN**: Implement minimal code to pass
3. **REFACTOR**: Improve design while keeping tests green

Example commit sequence:
```
test(swap): add validation for zero amounts (RED)
feat(swap): implement zero amount checks (GREEN)
refactor(swap): extract validation logic (REFACTOR)
```

### Testing Standards

#### Coverage Gates (Pipeline must fail if under threshold)
- Lines: 90%
- Branches: 80%
- Functions: 90%
- Statements: 90%

#### Test Types
1. **Unit Tests** (70% of tests)
   - Individual function testing
   - Library function testing
   - Modifier behavior testing
   - File naming: `*.test.js` or `*.spec.js`

2. **Integration Tests** (25% of tests)
   - Multi-contract interactions
   - End-to-end swap scenarios
   - Risk management integration
   - File naming: `*.int.js`

3. **Security Tests** (included in unit/integration)
   - Reentrancy attempts
   - Access control bypasses
   - MEV attack scenarios
   - Input validation bypasses

#### Test Principles
- **AAA Pattern**: Arrange-Act-Assert
- **One Assertion**: One logical assertion per test case
- **Deterministic**: No real network/time dependencies
- **Fast**: Unit tests <100ms, Integration tests <1000ms
- **Fixtures**: Use factory functions over static fixtures

## Important Implementation Notes

### When Working with Swaps

1. All swap paths MUST begin and end with `baseToken` (enforced in `_executeSwap`)
2. Path length must be `2 ≤ length ≤ MAX_PATH_LENGTH (5)`
3. Fees array length must equal `path.length - 1`
4. Always check deadline: `block.timestamp > deadline` reverts with `DeadlineExpired()`
5. Output validation: Final amount must meet `minAmountOut` or transaction reverts

### Gas Optimization Patterns

- Use `unchecked` blocks for iterator increments in loops
- Track gas usage per swap step: `uint256 gasStart = gasleft()`
- Libraries (MathLib, PoolLib, SecurityLib) are used for code reuse and gas efficiency
- Minimize storage reads/writes
- Use `calldata` for external function parameters when possible

### Custom Errors

The contract uses custom errors (Solidity 0.8+) for gas efficiency:
- `InvalidPath()`, `InsufficientOutput()`, `ExcessiveSlippage()`
- `PathTooLong()`, `DeadlineExpired()`, `InsufficientLiquidity()`
- `InvalidAddress()`, `InvalidAmount()`, `InvalidArrayLength()`, `InvalidFee()`
- `FlashLoanDetected()`, `RateLimitExceeded()`

### Events

Key events to monitor:
- `SwapExecuted(initiator, pathLength, inputAmount, outputAmount, priceImpact)`
- `PoolBlacklisted(pool, blacklisted)`
- `RiskParamsUpdated(maxVolume, minLiquidity, maxImpact, sandwichProtection)`
- `MEVProtectionUpdated(enabled, maxTxPerBlock, minTxDelay)`

## Documentation

Comprehensive documentation in `docs/`:
- `ARCHITECTURE.md` - Detailed system design and component interaction
- `MATHEMATICAL_FOUNDATIONS.md` - CPMM theory and optimization algorithms
- `SWAP_ALGORITHMS.md` - 4-way and 5-way swap implementations
- `SECURITY.md` - Security analysis and threat mitigation
- `TESTING.md` - Testing framework and methodologies

Sprint documentation:
- `SPRINT2_COMPLETE.md` - Sprint 2 completion summary
- `SPRINT2_PROGRESS.md` - Sprint 2 progress tracking
- `SPRINT2_TASK_PLAN.md` - Sprint 2 task planning

Refer to these docs when implementing new features or debugging complex swap logic.

## Configuration Files

- `hardhat.config.js` - Hardhat configuration with BSC testnet setup
- `env.json` - Contains mnemonic and BSCSCANAPIKEY (gitignored, use placeholder values)
- `package.json` - Node dependencies and npm scripts
- `setup.py` - Python package configuration for CLI tool

## Branching & Release Strategy

### Branch Naming Convention
- **Feature branches**: `feat/<description>` (e.g., `feat/mev-protection`)
- **Bug fixes**: `fix/<description>` (e.g., `fix/deadline-validation`)
- **Refactoring**: `refactor/<description>` (e.g., `refactor/split-swap-logic`)
- **Documentation**: `docs/<description>` (e.g., `docs/update-readme`)
- **Chores**: `chore/<description>` (e.g., `chore/update-deps`)

### Main Branch
- **Protected**: `main` branch requires PR reviews
- **Stable**: All tests must pass before merge
- **Tagged**: Release versions tagged as `vX.Y.Z`

### Release Process
1. Create feature branch from `main`
2. Implement changes with TDD
3. Ensure all tests pass and coverage meets requirements
4. Create PR with comprehensive description
5. Code review and approval
6. Merge to `main`
7. Tag release with semantic version
8. Deploy to testnet/mainnet

### Versioning
Semantic versioning based on Conventional Commits:
- `feat:` → minor bump (v1.1.0 → v1.2.0)
- `fix:` → patch bump (v1.1.0 → v1.1.1)
- `BREAKING CHANGE:` → major bump (v1.1.0 → v2.0.0)

## Security Best Practices

### Secret Management
- **Never commit secrets** to repository
- Use `env.json` for local development (gitignored)
- Use environment variables in CI/CD
- For production: Use secure vault systems

### Code Security
- Run security linters when available (Slither, Mythril)
- Follow Solidity security patterns
- Implement comprehensive input validation
- Use reentrancy guards on all external calls
- Implement proper access control
- Add circuit breakers for emergency stops

### Audit Trail
- All privileged operations emit events
- Document security considerations in NatSpec
- Maintain comprehensive test coverage
- Regular security audits before major releases

## Development Workflow Protocols

The `dev-prompts/` directory contains standardized workflow protocols:

### Core Protocols
- **DEV-PROTO.yaml**: TDD workflow and code standards
- **QA.yaml**: Testing and quality assurance workflow
- **SECURITY-PROTO.yaml**: Security review and scanning
- **RELEASE-PROTO.yaml**: Release preparation and deployment
- **REFACTOR-PROTO.yaml**: Code refactoring guidelines
- **BUG-PROTO.yaml**: Bug triage and resolution workflow

### When to Use Each Protocol
- **New feature**: DEV-PROTO.yaml → QA.yaml → RELEASE-PROTO.yaml
- **Bug fix**: BUG-PROTO.yaml → QA.yaml
- **Refactoring**: REFACTOR-PROTO.yaml (no behavior change)
- **Security review**: SECURITY-PROTO.yaml
- **Release**: RELEASE-PROTO.yaml

These protocols provide structured checklists and ensure consistency across development activities.

## Common Development Scenarios

### Adding a New Feature
1. Create feature branch: `git checkout -b feat/new-feature`
2. Follow TDD cycle (RED-GREEN-REFACTOR)
3. Write tests first, then implementation
4. Ensure coverage meets 90%+ threshold
5. Run full test suite: `npx hardhat test`
6. Generate coverage: `npx hardhat coverage`
7. Commit with conventional commit message
8. Create PR with comprehensive description

### Fixing a Bug
1. Create bug fix branch: `git checkout -b fix/bug-description`
2. Write failing test that reproduces the bug (RED)
3. Fix the bug (GREEN)
4. Refactor if needed (REFACTOR)
5. Verify all tests pass
6. Commit and create PR

### Refactoring Code
1. Ensure all existing tests pass before starting
2. Create refactor branch: `git checkout -b refactor/description`
3. Make incremental changes
4. Keep all tests green throughout
5. Commit frequently with clear messages
6. Verify no behavior changes

### Running Security Scans
```bash
# When Slither is available
slither contracts/

# Run tests with gas reporting
REPORT_GAS=true npx hardhat test

# Generate coverage report
npx hardhat coverage
```

## CI/CD Integration

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push/PR:
- Contract compilation check
- Full test suite execution
- Coverage report generation
- Security scanning (when tools available)
- Automated deployment to testnet (manual trigger)

## Project Roadmap & Sprint Planning

### Current Status (Post Test Suite Expansion)
- ✅ Hardhat migration complete
- ✅ Comprehensive test suite (282 tests passing, 0 failing)
- ✅ Production code coverage: 94-97% (adapters, libraries, main contracts)
- ✅ Overall coverage: 80.43% (up from 47.23%)
- ✅ Critical math bugs fixed (sqrt, cbrt implementations)
- ✅ Security enhancements (MEV, validation, access control)
- ✅ CI/CD pipeline functional
- ✅ All security vulnerabilities resolved (45 → 15 low-severity dev dependencies)

### Upcoming Priorities
1. **Security Audit**: Professional audit before mainnet
2. **Gas Optimization**: Target 30%+ reduction for swap operations
3. **Mainnet Deployment**: Deploy to BSC mainnet after audit
4. **Integration Tests**: Add end-to-end integration test scenarios
5. **Performance Monitoring**: Implement metrics and monitoring stack

### Long-term Goals
- Mainnet deployment
- Multi-DEX support
- Advanced optimization algorithms
- Governance system
- Community engagement

## Getting Help

- **Documentation**: Check `docs/` directory for detailed guides
- **Issues**: Review open GitHub issues for known problems
- **Testing**: Run `npx hardhat test` to verify setup
- **Coverage**: Run `npx hardhat coverage` to check test coverage
- **Community**: Engage with project maintainers via GitHub

---

**Last Updated**: 2025-11-11 (Comprehensive Test Suite Expansion & Coverage Improvement)
**Project Version**: v1.5.0
**Coverage**: 80.43% overall (94.12% adapters, 94.74% libraries, 97.37% main contracts)
**Tests**: 282 passing, 4 pending, 0 failing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
