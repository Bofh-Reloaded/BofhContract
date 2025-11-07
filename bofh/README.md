# BofhContract Python CLI

Python utilities and CLI tools for interacting with BofhContract V2 smart contracts.

## Features

- 🔍 **Contract ABI Management** - Automatically load ABIs from Hardhat build artifacts
- 🌐 **Web3 Connection Utilities** - Simplified connection to BSC, Ethereum, Polygon networks
- 🛠️ **CLI Interface** - Interactive command-line tools for contract interaction
- 📊 **Swap Simulation** - Test swaps before execution
- ℹ️ **Contract Information** - Query contract state and parameters

## Installation

### Prerequisites

- Python 3.8 or higher
- Compiled Solidity contracts (run `npm run compile` in project root)

### Install Package

```bash
# From project root
pip install -e .
```

This will install the `bofh` package in editable mode with all dependencies.

### Required Dependencies

The package requires the following Python libraries:
- `web3` - Ethereum/BSC blockchain interaction
- `click` - CLI framework
- `eth-utils` - Ethereum utilities

These are automatically installed via `setup.py`.

## Usage

### 1. Method Selector Enumeration

The original functionality for enumerating method selectors from contract ABIs:

```bash
python -m bofh.contract
```

**Output Example:**
```
INFO - Initializing BofhContract interface...
INFO - Loading contract ABI...
INFO - Contract interface loaded successfully
```

### 2. CLI Interface

The enhanced CLI provides multiple commands for contract interaction:

```bash
python -m bofh.contract.cli --help
```

#### Available Commands

##### Network Information

Display information about the connected blockchain network:

```bash
# Default: BSC Testnet
python -m bofh.contract.cli network-info

# Custom network
python -m bofh.contract.cli --network bsc network-info

# Custom RPC
python -m bofh.contract.cli --rpc https://bsc-dataseed1.binance.org network-info
```

**Output:**
```
==================================================
Network Information
==================================================
RPC URL:      https://data-seed-prebsc-1-s1.binance.org:8545
Chain ID:     97
Latest Block: 45123456
Gas Price:    3.0 Gwei
Connected:    True
==================================================
```

##### Contract Information

Get details about a deployed BofhContract:

```bash
python -m bofh.contract.cli contract-info --address 0x...
```

**Output:**
```
==================================================
Contract Information
==================================================
Address:       0x1234567890123456789012345678901234567890
Base Token:    0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd
Factory:       0x6725F303b657a9451d8BA641348b6761A6CC7a17

Risk Parameters:
  Max Trade Volume:     1000000000
  Min Pool Liquidity:   100000000
  Max Price Impact:     10.0%
  Sandwich Protection:  0.5%

Total Functions: 23
==================================================
```

##### List Available Contracts

Show all compiled contracts in the project:

```bash
python -m bofh.contract.cli list-available-contracts
```

**Output:**
```
==================================================
Available Contracts (8)
==================================================
  - BofhContractV2
  - BofhContractBase
  - MockFactory
  - MockPair
  - MockToken
  - MathLib
  - PoolLib
  - SecurityLib
==================================================
```

##### Simulate Swap

Test a swap path without executing it (uses view functions):

```bash
python -m bofh.contract.cli simulate-swap \
  --address 0x... \
  --path 0xWBNB,0xBUSD,0xWBNB \
  --fees 3000,3000 \
  --amount 1.0 \
  --min-out 0.95
```

**Output:**
```
==================================================
Swap Simulation
==================================================
Path: 0xae13...cd → 0x78867...ab → 0xae13...cd
Fees: [3000, 3000]
Amount In: 1.0 ETH (1000000000000000000 wei)

Results:
  Expected Output: 0.994 ETH
  Price Impact:    0.6%
  Optimality Score: 0.9940
==================================================
```

##### Show ABI

Display the ABI for a contract:

```bash
python -m bofh.contract.cli show-abi BofhContractV2
```

## Module API

### bofh.utils.solidity

Utilities for loading Solidity contract artifacts.

```python
from bofh.utils.solidity import add_solidity_search_path, get_abi, list_contracts

# Configure search paths
add_solidity_search_path("/path/to/contracts")

# Load contract ABI
abi = get_abi("BofhContractV2")
print(f"Functions: {len(abi)}")

# List all available contracts
contracts = list_contracts()
print(f"Available: {contracts}")
```

**Functions:**

- `add_solidity_search_path(path: str)` - Add directory to contract search paths
- `get_abi(contract_name: str, build_dir: str = "artifacts/contracts")` - Load contract ABI
- `get_bytecode(contract_name: str, build_dir: str = "artifacts/contracts")` - Load contract bytecode
- `list_contracts(build_dir: str = "artifacts/contracts")` - List all compiled contracts

### bofh.utils.web3

Web3 connection management and utilities.

```python
from bofh.utils.web3 import Web3Connector, get_contract, get_network_info

# Get Web3 connection
web3 = Web3Connector.get_connection(network="bsc_testnet")
print(f"Connected: {web3.is_connected()}")
print(f"Chain ID: {web3.eth.chain_id}")

# Load contract instance
from bofh.utils.solidity import get_abi
abi = get_abi("BofhContractV2")
contract = get_contract("0x...", abi, network="bsc_testnet")

# Get network information
info = get_network_info(network="bsc")
print(f"Latest block: {info['latest_block']}")
print(f"Gas price: {info['gas_price']}")
```

**Functions:**

- `Web3Connector.get_connection(rpc_url: Optional[str], network: str)` - Get or create Web3 instance
- `get_contract(address: str, abi: list, rpc_url: Optional[str], network: str)` - Load contract instance
- `get_network_info(rpc_url: Optional[str], network: str)` - Get network information

**Supported Networks:**
- `bsc` - Binance Smart Chain Mainnet
- `bsc_testnet` - BSC Testnet (default)
- `ethereum` - Ethereum Mainnet
- `polygon` - Polygon Mainnet

### bofh.contract

Contract interface utilities.

```python
from bofh.contract import BofhContractIface

# Create interface
iface = BofhContractIface()

# Get contract instance
contract = iface.get_contract(address="0x...")

# Access contract functions
base_token = contract.functions.getBaseToken().call()
factory = contract.functions.getFactory().call()

# Get risk parameters
risk_params = contract.functions.getRiskParams().call()
max_volume, min_liquidity, max_impact, sandwich_protection = risk_params
```

## Examples

### Example 1: Check Contract State

```python
from bofh.utils.solidity import get_abi
from bofh.utils.web3 import get_contract

# Load contract
abi = get_abi("BofhContractV2")
contract = get_contract(
    "0x1234567890123456789012345678901234567890",
    abi,
    network="bsc_testnet"
)

# Query state
print(f"Base Token: {contract.functions.getBaseToken().call()}")
print(f"Factory: {contract.functions.getFactory().call()}")

# Get risk parameters
risk = contract.functions.getRiskParams().call()
print(f"Max Price Impact: {risk[2] / 10000}%")
```

### Example 2: Simulate Swap Path

```python
from web3 import Web3
from bofh.utils.solidity import get_abi
from bofh.utils.web3 import get_contract

# Setup
abi = get_abi("BofhContractV2")
contract = get_contract("0x...", abi, network="bsc_testnet")

# Define swap path
path = [
    "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",  # WBNB
    "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7",  # BUSD
    "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"   # WBNB
]
amount = Web3.to_wei(1, 'ether')

# Simulate
result = contract.functions.getOptimalPathMetrics(path, [amount]).call()
expected_output, price_impact, optimality_score = result

print(f"Expected Output: {Web3.from_wei(expected_output, 'ether')} BNB")
print(f"Price Impact: {price_impact / 10000}%")
print(f"Optimality: {optimality_score / 1e6:.4f}")
```

### Example 3: List All Contracts

```python
from bofh.utils.solidity import list_contracts

contracts = list_contracts()
print(f"Found {len(contracts)} contracts:")
for name in contracts:
    print(f"  - {name}")
```

## Error Handling

The CLI and modules provide comprehensive error handling:

### Missing Dependencies

```bash
$ python -m bofh.contract
Error: Missing required dependencies: No module named 'web3'

Please install the package:
  pip install -e .
```

### Contract Not Compiled

```bash
$ python -m bofh.contract.cli list-available-contracts
Error: ABI for 'BofhContractV2' not found.
Searched paths:
  - /path/to/contracts/artifacts/contracts/main/BofhContractV2.sol/BofhContractV2.json
  ...

Make sure to compile contracts first:
  npm run compile
```

### Network Connection Error

```bash
$ python -m bofh.contract.cli network-info
Error: Failed to connect to https://invalid-rpc.com
```

## Development

### Project Structure

```
bofh/
├── __init__.py                 # Package initialization
├── README.md                   # This file
├── contract/
│   ├── __init__.py            # Contract utilities and data classes
│   ├── __main__.py            # Method selector enumeration tool
│   └── cli.py                 # Interactive CLI interface
└── utils/
    ├── __init__.py            # Utils package initialization
    ├── solidity.py            # Solidity artifact management
    └── web3.py                # Web3 connection utilities
```

### Adding New Commands

To add a new CLI command, edit `bofh/contract/cli.py`:

```python
@cli.command()
@click.option('--param', required=True, help='Parameter description')
@click.pass_context
def new_command(ctx, param):
    """Command description."""
    try:
        # Your implementation
        click.echo(f"Executing with param: {param}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        sys.exit(1)
```

## Troubleshooting

### Import Errors

If you encounter import errors:

```bash
# Reinstall package
pip uninstall bofh
pip install -e .
```

### ABI Not Found

Make sure contracts are compiled:

```bash
npm run compile
```

Check that you're running from the project root:

```bash
# Wrong
cd bofh && python -m contract

# Correct
python -m bofh.contract
```

### Web3 Connection Issues

Test connection manually:

```python
from web3 import Web3

w3 = Web3(Web3.HTTPProvider('https://data-seed-prebsc-1-s1.binance.org:8545'))
print(f"Connected: {w3.is_connected()}")
print(f"Block: {w3.eth.block_number}")
```

## License

UNLICENSED - Internal use only

## Contributing

This is part of the BofhContract project. See main project README for contribution guidelines.
