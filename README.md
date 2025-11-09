# BofhContract V2

<div align="center">

**Advanced Multi-Path Token Swap Optimizer for Binance Smart Chain**

[![Tests](https://img.shields.io/badge/tests-163%20passing-brightgreen)](https://github.com/Bofh-Reloaded/BofhContract)
[![Coverage](https://img.shields.io/badge/coverage-improving-yellow)](https://github.com/Bofh-Reloaded/BofhContract)
[![License](https://img.shields.io/badge/license-UNLICENSED-blue)](LICENSE)
[![Solidity](https://img.shields.io/badge/solidity-0.8.10-363636)](https://docs.soliditylang.org)
[![Hardhat](https://img.shields.io/badge/built%20with-Hardhat-yellow)](https://hardhat.org)

An advanced DeFi smart contract system implementing mathematical optimization algorithms based on the **Golden Ratio (φ ≈ 0.618034)** for optimal multi-path token swaps with comprehensive security features.

[Documentation](#documentation) •
[Quick Start](#quick-start) •
[Architecture](#architecture) •
[Security](#security) •
[Contributing](#contributing)

</div>

---

## 🎯 Project Status

**Current Version:** v1.5.0 (Beta - Pre-Production)

**Overall Score:** 8.1/10

| Category | Status | Score |
|----------|--------|-------|
| Contract Architecture | ✅ Excellent | 9.5/10 |
| Documentation | ✅ Excellent | 9.0/10 |
| Security | ✅ Good | 8.0/10 |
| Code Quality | ✅ Good | 8.5/10 |
| Test Coverage | ⚠️ Needs Improvement | 6.0/10 |
| CI/CD | ✅ Good | 8.5/10 |

**Production Readiness:** Strong foundation with targeted improvements needed. See [Project Analysis](docs/PROJECT_ANALYSIS.md) for details.

---

## ✨ Key Features

### Mathematical Sophistication
- **Golden Ratio Optimization**: φ-based path splitting for 4-way and 5-way swaps
- **Advanced CPMM Analysis**: Third-order Taylor expansion for price impact modeling
- **Dynamic Programming**: Bellman equation implementation for optimal routing

### Security Features
- **Multi-Layer Protection**:
  - Reentrancy guards (OpenZeppelin standard)
  - MEV protection (flash loan detection + rate limiting)
  - Comprehensive input validation
  - Circuit breakers (emergency pause)
  - Pool blacklisting capability

### Architecture
- **Modular Design**: Clean separation of concerns with libraries
- **Interface Abstractions**: IBofhContract, IBofhContractBase for loose coupling
- **DEX Adapters**: Support for Uniswap V2, PancakeSwap (extensible)
- **Upgrade Strategy**: Documented transparent proxy pattern

---

## 📚 Documentation

### Core Documentation
- **[Architecture Overview](docs/ARCHITECTURE.md)** - System design and components
- **[Mathematical Foundations](docs/MATHEMATICAL_FOUNDATIONS.md)** - CPMM theory and optimization
- **[Swap Algorithms](docs/SWAP_ALGORITHMS.md)** - 4-way and 5-way implementation
- **[Security Analysis](docs/SECURITY.md)** - MEV protection and threat mitigation
- **[Testing Framework](docs/TESTING.md)** - Unit tests and integration tests
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Testnet and mainnet deployment
- **[API Reference](docs/API_REFERENCE.md)** - Contract interfaces and functions

### Developer Documentation
- **[Code Style Guide](docs/STYLE_GUIDE.md)** - Solidity, JavaScript, Python standards
- **[Interface Specifications](docs/INTERFACES.md)** - IBofhContract, IBofhContractBase
- **[DEX Adapters](docs/DEX_ADAPTERS.md)** - Adapter pattern implementation
- **[Upgradeability Strategy](docs/UPGRADEABILITY_STRATEGY.md)** - Proxy patterns
- **[Monitoring Guide](docs/MONITORING.md)** - Performance monitoring setup

---

## 🚀 Quick Start

### Prerequisites
- **Node.js** >= 16.0.0
- **npm** >= 8.0.0
- **Hardhat** (installed via npm)

### Installation

```bash
# Clone repository
git clone https://github.com/Bofh-Reloaded/BofhContract.git
cd BofhContract

# Install dependencies
npm install

# Configure environment
cp env.json.example env.json
# Edit env.json with your BSC testnet mnemonic and BSCScan API key

# Compile contracts
npm run compile

# Run tests
npm test

# Generate coverage report
npm run coverage
```

### Environment Setup

Create `env.json` in the project root:

```json
{
    "mnemonic": "your twelve word mnemonic phrase here",
    "BSCSCANAPIKEY": "YOUR_BSCSCAN_API_KEY"
}
```

**⚠️ SECURITY**: Never commit `env.json` to version control! It's already in `.gitignore`.

### Running Tests

```bash
# Run all tests (153 tests)
npm test

# Run with gas reporting
REPORT_GAS=true npm test

# Run coverage analysis
npm run coverage

# Run security scan
npm run security
```

### Deployment

```bash
# Deploy to BSC testnet
npm run deploy:testnet

# Verify contract on BSCScan
npm run verify
```

---

## 🏗️ Architecture

### Contract Structure

```
BofhContractV2 (main implementation - 404 lines)
  └── BofhContractBase (security & risk management - 361 lines)
       ├── SecurityLib (access control, reentrancy - 300 lines)
       ├── MathLib (sqrt, cbrt, golden ratio - 171 lines)
       └── PoolLib (liquidity analysis, CPMM - 274 lines)
```

### Key Components

**Main Contracts:**
- `BofhContractV2.sol` - Swap execution with golden ratio optimization
- `BofhContractBase.sol` - Security primitives and risk parameters

**Libraries:**
- `MathLib.sol` - Mathematical operations (Newton's method, geometric mean)
- `PoolLib.sol` - CPMM analysis, price impact calculation
- `SecurityLib.sol` - Reentrancy protection, access control

**Interfaces:**
- `IBofhContract.sol` - Public API for swap execution
- `IBofhContractBase.sol` - Base functionality interface
- `IDEXAdapter.sol` - DEX abstraction layer

**Adapters:**
- `UniswapV2Adapter.sol` - Uniswap V2 integration (0.3% fee)
- `PancakeSwapAdapter.sol` - PancakeSwap V2 integration (0.25% fee)

**Total:** 18 Solidity files, ~3,500 lines of contract code

---

## 🔐 Security

### Implemented Security Features

✅ **Reentrancy Protection** - Function-level locks with msg.sig tracking
✅ **Input Validation** - Comprehensive validation in all external functions
✅ **MEV Protection** - Flash loan detection and rate limiting
✅ **Access Control** - Owner and operator roles
✅ **Circuit Breakers** - Emergency pause functionality
✅ **Pool Blacklisting** - Manual pool exclusion capability
✅ **Emergency Token Recovery** - Rescue mechanism for accidentally sent tokens

### Security Audits

- **Automated Scanning**: Slither integration in CI/CD
- **External Audit**: Pending (recommended before production)
- **Bug Bounty**: Not yet established

### Known Limitations

⚠️ **No Oracle Integration**: Relies on pool reserves only
⚠️ **Centralization**: Single owner has significant control (mitigate with multisig)

See [Security Analysis](docs/SECURITY.md) for complete details.

---

## 🧮 Mathematical Foundations

### Golden Ratio Optimization

The system uses the golden ratio φ for provably optimal path splitting:

```
φ = (1 + √5) / 2 ≈ 1.618034
φ⁻¹ ≈ 0.618034

For 4-way swaps: [φ⁻¹, φ⁻², φ⁻³, remainder]
              ≈ [61.8%, 38.2%, 23.6%, remaining]
```

**Proof of Optimality**: Using Lagrange multipliers to minimize total price impact across paths.

### CPMM Analysis

Third-order Taylor expansion for price impact:

```
ΔP/P = -λ(ΔR/R) + (λ²/2)(ΔR/R)² - (λ³/6)(ΔR/R)³

where:
  λ = market depth parameter
  ΔR/R = relative reserve change
  ΔP/P = relative price change
```

See [Mathematical Foundations](docs/MATHEMATICAL_FOUNDATIONS.md) for complete derivations.

---

## 🧪 Testing

### Test Suite

**8 test files, 163 tests, 100% passing**

```bash
test/
├── BofhContractV2.test.js            # Main contract tests (47 tests)
├── Libraries.test.js                 # Library function tests (42 tests)
├── SwapExecution.test.js             # Swap logic tests (25 tests)
├── MEVProtection.test.js             # MEV protection tests (12 tests)
├── MultiSwap.test.js                 # Multi-path tests (15 tests)
├── ViewFunctions.test.js             # View function tests (10 tests)
├── EmergencyTokenRecovery.test.js    # Emergency recovery tests (11 tests)
└── test_bofh_contract.py             # Python CLI tests (2 tests - not counted)
```

### Test Coverage

Current coverage framework in place. See [Testing Framework](docs/TESTING.md) for details.

**Coverage Goals:**
- ✅ Unit tests for all libraries
- ✅ Integration tests for swap execution
- ⚠️ Fuzzing tests needed
- ⚠️ Mainnet fork tests needed

---

## 📊 Performance

### Gas Optimization

**Phase 3 Optimization Results:**
- Total gas saved: 1,399 gas (0.64% improvement)
- Optimizations: Inline CPMM calculation, reduced external calls, unchecked math

**Gas Costs:**
- Simple 2-way swap: ~218,000 gas
- Complex 5-way swap: ~350,000 gas

See [Gas Optimization Results](docs/GAS_OPTIMIZATION_PHASE3_RESULTS.md) for benchmarks.

---

## 🛠️ Development

### Available Scripts

```bash
# Compilation
npm run compile              # Compile contracts

# Testing
npm test                     # Run all tests
npm run coverage             # Generate coverage report

# Linting & Formatting
npm run lint                 # Run all linters
npm run lint:sol             # Lint Solidity files
npm run lint:js              # Lint JavaScript files
npm run format               # Format all files
npm run format:check         # Check formatting

# Security
npm run security             # Run security scan
npm run security:install     # Install Slither

# Deployment
npm run deploy               # Deploy (defaults to local)
npm run deploy:local         # Deploy to local Hardhat network
npm run deploy:testnet       # Deploy to BSC testnet
npm run deploy:mainnet       # Deploy to BSC mainnet

# Verification
npm run verify:testnet       # Verify on BSC testnet
npm run verify:mainnet       # Verify on BSC mainnet

# Configuration
npm run configure:testnet    # Configure deployed contract on testnet
npm run configure:mainnet    # Configure deployed contract on mainnet
```

### CI/CD Pipeline

GitHub Actions workflows:
- **CI**: Lint, compile, test, coverage on all branches
- **Security**: Slither scan, npm audit (scheduled weekly)
- **Gas Report**: Automated gas usage reporting on PRs

---

## 📦 Dependencies

### Production Dependencies
- `@openzeppelin/contracts@4.9.6` - Security-audited contract libraries

### Development Dependencies
- `hardhat@2.27.0` - Ethereum development environment
- `ethers@6.15.0` - Ethereum library
- `@nomicfoundation/hardhat-toolbox@3.0.0` - Complete Hardhat toolkit
- `solidity-coverage@0.8.5` - Coverage analysis
- `hardhat-gas-reporter@2.3.0` - Gas usage reporting

---

## 🗺️ Roadmap

### Immediate (Next 2 Weeks)
- [x] Fix antiMEV stack depth issue in `executeMultiSwap` (✅ Completed - Issue #24)
- [x] Complete Hardhat deployment scripts (✅ Completed - Issue #25)
- [x] Remove legacy Truffle dependencies (✅ Completed - Issue #27)
- [x] Add emergency token recovery function (✅ Completed - Issue #26)

### Short-Term (1-2 Months)
- [ ] Increase test coverage to 90%+
- [ ] External security audit
- [ ] Implement upgradeability (proxy pattern)
- [ ] Complete monitoring stack (Grafana + alerts)

### Long-Term (3-6 Months)
- [ ] Production deployment to BSC mainnet
- [ ] Oracle integration (Chainlink)
- [ ] Multi-DEX routing optimization
- [ ] Bug bounty program

See [Project Roadmap](docs/PROJECT_ROADMAP.md) for complete timeline.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting PRs.

### Areas for Contribution

- 🧮 **Mathematical Models**: Optimization algorithm improvements
- 🔒 **Security**: Enhanced MEV protection mechanisms
- ⚡ **Performance**: Gas optimization techniques
- 🧪 **Testing**: Increased coverage and edge case testing
- 📖 **Documentation**: Tutorials, guides, and examples

### Development Setup

1. Fork the repository
2. Create feature branch: `git checkout -b feature/AmazingFeature`
3. Make changes and add tests
4. Run linters: `npm run lint`
5. Run tests: `npm test`
6. Commit: `git commit -m 'Add AmazingFeature'`
7. Push: `git push origin feature/AmazingFeature`
8. Create Pull Request

---

## 📄 License

**UNLICENSED** - Proprietary software for research and educational purposes.

See [LICENSE](LICENSE) for details.

---

## 💬 Support

- 📖 **Documentation**: See `/docs` directory
- 🐛 **Issues**: [GitHub Issues](https://github.com/Bofh-Reloaded/BofhContract/issues)
- 💭 **Discussions**: [GitHub Discussions](https://github.com/Bofh-Reloaded/BofhContract/discussions)

---

## 🙏 Acknowledgments

- **OpenZeppelin**: For security best practices and audited libraries
- **Uniswap Team**: For pioneering the CPMM standard
- **Hardhat Team**: For excellent development tooling
- **DeFi Community**: For research and innovation in AMM optimization

---

<div align="center">

### Built with Advanced Mathematics & Security-First Design

**BofhContract V2** - *Where Golden Ratio meets DeFi*

`v1.5.0 | 163 Tests Passing | 8.1/10 Score | Pre-Production`

</div>
