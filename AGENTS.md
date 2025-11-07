# Repository Guidelines

## Project Structure & Module Organization
- `contracts/` — Solidity sources: `main/` (core), `libs/`, `interfaces/`, `variants/`, `mocks/`. Artifacts in `build/contracts/`.
- `migrations/` — Truffle deployment scripts.
- `test/` — Smart-contract tests (`*.test.js`) and Python tests (`test_*.py`).
- `bofh/` — Python helper/CLI package for contract interactions.
- `docs/` — Architecture, security, testing and algorithms.
- `env.json` — Local config (mnemonic, API keys). Do not commit secrets.

## Build, Test, and Development Commands
- Install deps: `npm install`
- Compile contracts: `npm run compile` (Truffle compile, see `truffle-config.js`).
- Migrate/deploy: `npm run migrate` (sets network from config).
- JS tests: `truffle test` (preferred) or `npm test` if maintained.
- Coverage: `npm run coverage` (solidity-coverage via buidler/Hardhat setup).
- Python env: `pip install -r requirements.txt`; run tests with `python -m unittest discover -s test -p "test_*.py"`.

## Coding Style & Naming Conventions
- Solidity: 4-space indent, 120 cols, NatSpec for public/external. Contracts/Libraries `PascalCase` (e.g., `BofhContractV2`, `MathLib`), interfaces `I*` (e.g., `IPancakePair`). Events `PascalCase`, errors `CapsWords`.
- JavaScript tests: use Chai + OZ test-helpers; files end with `.test.js` (e.g., `BofhContractV2.test.js`).
- Python: 4-space indent, type hints where practical. Test files `test_*.py`.
- Keep revert messages and event names stable; prefer explicit types over `var`/`auto` patterns.

## Testing Guidelines
- Unit tests for libraries and core flows; integration tests for multi-path swaps and risk checks.
- JS test naming: `<Contract>.test.js`; Python: `test_<area>.py`.
- Run: `truffle test` and `python -m unittest ...` locally before PRs.
- Aim to cover new branches/paths; add mocks under `contracts/mocks/` when needed.

## Commit & Pull Request Guidelines
- Follow Conventional Commits with emojis (seen in history): `✨ feat:`, `♻️ refactor:`, `📝 docs:`.
- PRs must include: clear description, linked issues, test results, and doc updates when applicable (see `docs/`).
- Validate: `npm run compile`, `truffle test`, `python -m unittest`, and (if configured) `npm run coverage` before request review.

## Security & Configuration Tips
- Never commit real mnemonics or private keys; keep `env.json` local. Use `truffle-plugin-verify` for on-chain verification (example: `truffle run verify <Contract>@<address> --network <network>`).
- Review `docs/SECURITY.md`; do not relax guards or access control without justification.
- If upgrading Solidity (some sources use 0.8.x), align `truffle-config.js` appropriately and document in the PR.

