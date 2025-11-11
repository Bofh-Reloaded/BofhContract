# SPRINT 1: Critical Fixes - Task Plan

**Goal**: Resolve all critical blocking issues to make project compilable and secure

**Branch**: `fix/sprint-1-critical-fixes`

---

## Task Breakdown

### Task 1.1: Fix Solidity Version Mismatch (Issue #1)
**Target**: truffle-config.js
**Status**: pending
**Estimated**: 1-2 hours

#### Sub-tasks:
1. Update Solidity compiler version to 0.8.10
2. Enable optimizer
3. Update EVM version to default (remove byzantium)
4. Test compilation
5. Commit: `fix(config): update Solidity compiler to 0.8.10`

#### Success Criteria:
- [ ] `truffle compile` succeeds without errors
- [ ] All contracts compile
- [ ] No warnings about version mismatches

---

### Task 1.2: Add Reentrancy Protection (Issue #2)
**Target**: contracts/main/BofhContract.sol, contracts/main/BofhContractV2.sol
**Status**: pending
**Estimated**: 4-6 hours

#### Sub-tasks:
1. **RED**: Write test that exploits reentrancy
2. **GREEN**: Add OpenZeppelin ReentrancyGuard
3. **GREEN**: Apply nonReentrant modifier to executeSwap functions
4. **REFACTOR**: Ensure all external calls use CEI pattern
5. **TEST**: Verify reentrancy attack fails
6. Commit: `fix(security): add reentrancy protection with OpenZeppelin guard`

#### Files to Modify:
- contracts/main/BofhContract.sol
- contracts/main/BofhContractV2.sol
- package.json (add @openzeppelin/contracts)
- test/security/Reentrancy.test.js (new file)

#### Success Criteria:
- [ ] ReentrancyGuard imported and inherited
- [ ] nonReentrant modifier on all swap functions
- [ ] Reentrancy attack test fails as expected
- [ ] All existing tests still pass
- [ ] No gas regression > 5%

---

### Task 1.3: Replace Unsafe Storage Manipulation (Issue #3)
**Target**: contracts/main/BofhContract.sol:518-520
**Status**: pending
**Estimated**: 2-3 hours

#### Sub-tasks:
1. **RED**: Write test for ownership transfer
2. **GREEN**: Replace assembly with OpenZeppelin Ownable
3. **GREEN**: Update changeAdmin to use transferOwnership
4. **REFACTOR**: Remove assembly block
5. **TEST**: Verify ownership transfer works
6. Commit: `fix(security): replace unsafe storage manipulation with Ownable`

#### Files to Modify:
- contracts/main/BofhContract.sol
- test/security/Ownership.test.js (new file)

#### Success Criteria:
- [ ] No assembly storage manipulation
- [ ] Ownable pattern implemented correctly
- [ ] Ownership transfer tests pass
- [ ] No storage collisions

---

### Task 1.4: Fix npm Dependency Vulnerabilities (Issue #4)
**Target**: package.json, package-lock.json
**Status**: pending
**Estimated**: 4-8 hours

#### Sub-tasks:
1. Run `npm audit` and document findings
2. Run `npm audit fix`
3. Run `npm audit fix --force` if needed
4. Update critical packages manually if needed
5. Test all functionality after updates
6. Commit: `fix(deps): resolve 38 npm security vulnerabilities`

#### Success Criteria:
- [ ] `npm audit` shows 0 critical vulnerabilities
- [ ] `npm audit` shows 0 high vulnerabilities
- [ ] All tests pass after updates
- [ ] Project compiles after updates
- [ ] Document breaking changes if any

---

### Task 1.5: Remove Exposed API Key (Issue #5)
**Target**: env.json, .gitignore, git history
**Status**: pending
**Estimated**: 2-3 hours

#### Sub-tasks:
1. Create env.json.example template
2. Add env.json to .gitignore
3. Remove env.json from git history
4. Update README with environment setup
5. **Manual**: Rotate BSCScan API key
6. Commit: `fix(security): remove exposed API keys and update .gitignore`

#### Files to Create/Modify:
- env.json.example (new)
- .gitignore (update)
- README.md (update)
- env.json (remove from git)

#### Success Criteria:
- [ ] env.json not in git history
- [ ] env.json.example created
- [ ] .gitignore includes env.json
- [ ] README has setup instructions
- [ ] BSCScan API key rotated

---

## Development Standards (DEV-PROTO.yaml)

### Code Standards
- **Max file length**: 500 lines (hard limit)
- **Commit style**: Conventional Commits
- **Test style**: AAA (Arrange-Act-Assert)

### Testing Standards
- **Coverage gates**: 90% lines, 80% branches
- **Test types**: Unit, Integration, Security
- **Test runner**: Truffle + Chai

### TDD Cycle
For each task:
1. **RED**: Write failing test
2. **GREEN**: Implement minimal solution
3. **REFACTOR**: Improve design
4. **QUALITY GATES**: Run all checks

### Quality Gates (Per Task)
- [ ] All tests passing
- [ ] Coverage thresholds met (if applicable)
- [ ] Linting clean
- [ ] No new security vulnerabilities
- [ ] Git committed with conventional commit message

---

## Overall SPRINT 1 Quality Gates

### Entry Criteria
- ✅ All 5 issues documented and understood
- ✅ Technical approach validated
- ✅ Development environment ready

### Exit Criteria
- [ ] All 5 tasks completed
- [ ] Project compiles successfully
- [ ] All tests passing
- [ ] No critical/high vulnerabilities
- [ ] No secrets in repository
- [ ] Documentation updated
- [ ] Changes committed and pushed

---

## Execution Order

1. **Task 1.1** (Solidity version) - MUST BE FIRST (blocks compilation)
2. **Task 1.4** (npm deps) - Second (needed for OpenZeppelin)
3. **Task 1.2** (Reentrancy) - Third (uses OpenZeppelin)
4. **Task 1.3** (Storage) - Fourth (uses OpenZeppelin)
5. **Task 1.5** (API key) - Last (independent)

---

## Time Estimate

- Minimum: 13 hours (optimistic)
- Likely: 21 hours (realistic)
- Maximum: 29 hours (pessimistic)

**Expected completion**: 2-3 working days

---

**Created**: 2025-11-07
**Status**: Ready to execute
**Next**: Create branch and start Task 1.1
