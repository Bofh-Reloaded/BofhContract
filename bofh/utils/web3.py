"""
Web3 connection utilities for interacting with blockchain networks.
"""
from typing import Optional, Dict
from web3 import Web3
from web3.providers import HTTPProvider
import logging

logger = logging.getLogger(__name__)


# Default RPC endpoints for common networks
DEFAULT_RPC_ENDPOINTS = {
    "bsc": "https://bsc-dataseed1.binance.org",
    "bsc_testnet": "https://data-seed-prebsc-1-s1.binance.org:8545",
    "ethereum": "https://eth.public-rpc.com",
    "polygon": "https://polygon-rpc.com",
}


class Web3Connector:
    """
    Singleton Web3 connection manager.

    Manages a single Web3 instance to avoid multiple connections.
    """

    _instance: Optional[Web3] = None
    _rpc_url: Optional[str] = None

    @classmethod
    def get_connection(cls, rpc_url: Optional[str] = None, network: str = "bsc_testnet") -> Web3:
        """
        Get or create a Web3 connection.

        Args:
            rpc_url: Custom RPC URL (overrides network parameter)
            network: Network name ("bsc", "bsc_testnet", "ethereum", "polygon")

        Returns:
            Web3 instance connected to the specified network

        Example:
            >>> web3 = Web3Connector.get_connection(network="bsc_testnet")
            >>> print(f"Connected: {web3.is_connected()}")
            >>> print(f"Chain ID: {web3.eth.chain_id}")
        """
        # Determine RPC URL
        if rpc_url:
            url = rpc_url
        elif network in DEFAULT_RPC_ENDPOINTS:
            url = DEFAULT_RPC_ENDPOINTS[network]
        else:
            raise ValueError(
                f"Unknown network '{network}'. "
                f"Available: {list(DEFAULT_RPC_ENDPOINTS.keys())}"
            )

        # Create new instance if needed or if URL changed
        if cls._instance is None or cls._rpc_url != url:
            logger.info(f"Connecting to {network} at {url}")
            cls._instance = Web3(HTTPProvider(url))
            cls._rpc_url = url

            # Verify connection
            if not cls._instance.is_connected():
                raise ConnectionError(f"Failed to connect to {url}")

            logger.info(
                f"Connected successfully. Chain ID: {cls._instance.eth.chain_id}"
            )

        return cls._instance

    @classmethod
    def reset_connection(cls):
        """Reset the connection (useful for testing or switching networks)."""
        cls._instance = None
        cls._rpc_url = None


class JSONRPCConnector:
    """
    JSON-RPC provider connector for direct RPC calls.

    Wrapper around Web3Connector for compatibility with legacy code.
    """

    @classmethod
    def get_connection(cls, rpc_url: Optional[str] = None, network: str = "bsc_testnet"):
        """
        Get the underlying JSON-RPC provider.

        Args:
            rpc_url: Custom RPC URL
            network: Network name

        Returns:
            HTTPProvider instance
        """
        web3 = Web3Connector.get_connection(rpc_url, network)
        return web3.provider


def get_contract(
    address: str,
    abi: list,
    rpc_url: Optional[str] = None,
    network: str = "bsc_testnet",
) -> object:
    """
    Load a contract instance.

    Args:
        address: Contract address (with or without 0x prefix)
        abi: Contract ABI
        rpc_url: Custom RPC URL
        network: Network name

    Returns:
        Web3 contract instance

    Example:
        >>> from bofh.utils.solidity import get_abi
        >>> abi = get_abi("BofhContractV2")
        >>> contract = get_contract("0x...", abi, network="bsc_testnet")
        >>> base_token = contract.functions.getBaseToken().call()
    """
    web3 = Web3Connector.get_connection(rpc_url, network)

    # Ensure address is checksummed
    address = Web3.to_checksum_address(address)

    # Create contract instance
    contract = web3.eth.contract(address=address, abi=abi)

    logger.info(f"Loaded contract at {address}")
    return contract


def get_network_info(rpc_url: Optional[str] = None, network: str = "bsc_testnet") -> Dict:
    """
    Get information about the connected network.

    Args:
        rpc_url: Custom RPC URL
        network: Network name

    Returns:
        Dictionary with network information

    Example:
        >>> info = get_network_info(network="bsc_testnet")
        >>> print(f"Chain ID: {info['chain_id']}")
        >>> print(f"Latest block: {info['latest_block']}")
    """
    web3 = Web3Connector.get_connection(rpc_url, network)

    return {
        "chain_id": web3.eth.chain_id,
        "latest_block": web3.eth.block_number,
        "gas_price": web3.eth.gas_price,
        "is_connected": web3.is_connected(),
        "rpc_url": Web3Connector._rpc_url,
    }
