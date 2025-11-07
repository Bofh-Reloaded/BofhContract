"""
Solidity contract utilities for loading ABIs and managing contract artifacts.
"""
import json
from pathlib import Path
from typing import Dict, List, Optional

# Global list of search paths for Solidity contracts
SOLIDITY_SEARCH_PATHS: List[Path] = []


def add_solidity_search_path(path: str) -> None:
    """
    Add a directory to the Solidity contract search paths.

    Args:
        path: Directory path containing contract build artifacts

    Example:
        >>> add_solidity_search_path("/path/to/contracts")
    """
    search_path = Path(path).resolve()
    if not search_path.exists():
        raise FileNotFoundError(f"Path does not exist: {path}")

    if search_path not in SOLIDITY_SEARCH_PATHS:
        SOLIDITY_SEARCH_PATHS.append(search_path)


def get_abi(contract_name: str, build_dir: str = "artifacts/contracts") -> Dict:
    """
    Load contract ABI from Hardhat build artifacts.

    Args:
        contract_name: Name of the contract (e.g., "BofhContractV2")
        build_dir: Build directory name (default: "artifacts/contracts" for Hardhat)

    Returns:
        Contract ABI as dictionary

    Raises:
        FileNotFoundError: If ABI file cannot be found in any search path

    Example:
        >>> abi = get_abi("BofhContractV2")
        >>> print(f"Functions: {len(abi)}")
    """
    if not SOLIDITY_SEARCH_PATHS:
        raise RuntimeError(
            "No search paths configured. Call add_solidity_search_path() first."
        )

    # Try multiple common patterns for contract artifacts
    patterns = [
        # Hardhat pattern: artifacts/contracts/main/Contract.sol/Contract.json
        f"{build_dir}/main/{contract_name}.sol/{contract_name}.json",
        f"{build_dir}/{contract_name}.sol/{contract_name}.json",
        # Alternative: contracts/libs/Contract.sol/Contract.json
        f"{build_dir}/libs/{contract_name}.sol/{contract_name}.json",
        # Truffle pattern: build/contracts/Contract.json
        f"build/contracts/{contract_name}.json",
    ]

    for search_path in SOLIDITY_SEARCH_PATHS:
        for pattern in patterns:
            abi_path = search_path / pattern
            if abi_path.exists():
                try:
                    with open(abi_path, "r") as f:
                        artifact = json.load(f)
                        return artifact.get("abi", [])
                except (json.JSONDecodeError, KeyError) as e:
                    raise RuntimeError(
                        f"Invalid contract artifact at {abi_path}: {e}"
                    )

    # If not found, provide helpful error message
    searched_paths = "\n".join(
        f"  - {search_path / pattern}"
        for search_path in SOLIDITY_SEARCH_PATHS
        for pattern in patterns
    )
    raise FileNotFoundError(
        f"ABI for '{contract_name}' not found.\n"
        f"Searched paths:\n{searched_paths}\n\n"
        f"Make sure to compile contracts first:\n"
        f"  npm run compile"
    )


def get_bytecode(contract_name: str, build_dir: str = "artifacts/contracts") -> str:
    """
    Load contract bytecode from Hardhat build artifacts.

    Args:
        contract_name: Name of the contract
        build_dir: Build directory name

    Returns:
        Contract bytecode as hex string

    Raises:
        FileNotFoundError: If bytecode cannot be found
    """
    if not SOLIDITY_SEARCH_PATHS:
        raise RuntimeError(
            "No search paths configured. Call add_solidity_search_path() first."
        )

    patterns = [
        f"{build_dir}/main/{contract_name}.sol/{contract_name}.json",
        f"{build_dir}/{contract_name}.sol/{contract_name}.json",
        f"{build_dir}/libs/{contract_name}.sol/{contract_name}.json",
        f"build/contracts/{contract_name}.json",
    ]

    for search_path in SOLIDITY_SEARCH_PATHS:
        for pattern in patterns:
            bytecode_path = search_path / pattern
            if bytecode_path.exists():
                try:
                    with open(bytecode_path, "r") as f:
                        artifact = json.load(f)
                        return artifact.get("bytecode", "0x")
                except (json.JSONDecodeError, KeyError) as e:
                    raise RuntimeError(
                        f"Invalid contract artifact at {bytecode_path}: {e}"
                    )

    raise FileNotFoundError(f"Bytecode for '{contract_name}' not found")


def list_contracts(build_dir: str = "artifacts/contracts") -> List[str]:
    """
    List all available compiled contracts.

    Args:
        build_dir: Build directory name

    Returns:
        List of contract names
    """
    contracts = set()

    for search_path in SOLIDITY_SEARCH_PATHS:
        artifacts_dir = search_path / build_dir
        if not artifacts_dir.exists():
            continue

        # Find all .json files in artifacts directory
        for json_file in artifacts_dir.rglob("*.json"):
            # Extract contract name from path
            # Pattern: artifacts/contracts/main/ContractName.sol/ContractName.json
            if json_file.parent.suffix == ".sol":
                contract_name = json_file.stem
                contracts.add(contract_name)

    return sorted(list(contracts))
