#!/usr/bin/env python3
"""
CLI interface for BofhContract interface operations.
"""

from os.path import join, dirname, realpath
from re import split, search
import logging

from bofh.utils.solidity import add_solidity_search_path, get_abi
from bofh.utils.web3 import Web3Connector, JSONRPCConnector

logging.basicConfig(level=logging.INFO)

# Configure solidity search path
add_solidity_search_path(join(dirname(dirname(dirname(realpath(__file__)))), "contracts"))

def _extract_numeric_tail(text: str) -> str:
    """Extract numeric tail from a string using regex split."""
    return split(r'[^\d]', text)[-1]

def _parse_numeric_array_length(input_str: str) -> int:
    """Parse numeric array length from a Solidity type string."""
    m = search(r"\[(\d+)\]", input_str)
    if m:
        return int(m.group(1))
    else:
        raise ValueError("No numeric array length found in string.")

def enumerate_method_selectors(contract) -> None:
    """
    Enumerate method selectors from a contract's ABI and log them.

    For methods starting with 'multiswap' or 'swapinspect', extract numeric information
    and log the corresponding selector and description.
    """
    for c in contract.abi:
        fname = c.get("name")
        if fname and (fname.startswith("multiswap") or fname.startswith("swapinspect")):
            numeric_tail = _extract_numeric_tail(fname)
            if numeric_tail.isdigit():
                nn = int(numeric_tail)
                calldata = contract.encodeABI(fname)
                calldata = "0x" + calldata[2:10].upper()
                logging.info(f"{calldata}, // {fname}() reads uint256[{nn}] --> PATH_LENGTH={nn-1}")
            else:
                inputs = c.get("inputs", [])
                if len(inputs) != 1:
                    raise ValueError(f"Expected one input for function {fname}")
                internalType = inputs[0].get("internalType")
                if not internalType:
                    raise ValueError("Input missing internal type")
                array_length = _parse_numeric_array_length(internalType)
                args = [[123] * array_length]
                calldata = contract.encodeABI(fname, args)
                calldata = "0x" + calldata[2:10].upper()
                logging.info(f"{calldata}, // {fname}(uint256[{array_length}]) --> PATH_LENGTH={array_length-1}")

class BofhContractIface:
    """
    A class that encapsulates interactions with the BofhContract.

    It supports obtaining the contract instance and managing JSON RPC connections.
    """
    def __init__(self, get_contract_address=None, get_rpc_url=None):
        self.__get_contract_address = get_contract_address
        self.__get_rpc_url = get_rpc_url

    def get_contract(self, address: str = None, abi=None):
        """
        Obtain the contract instance.

        Parameters:
        - address: Optional blockchain address of the contract.
        - abi: Optional ABI for the contract; if not provided, defaults to 'BofhContract'.
        """
        if abi is None:
            abi = get_abi("BofhContract")
        if address is None and self.__get_contract_address:
            address = self.__get_contract_address()
        if address is None:
            address = "0x" + "0" * 40
        w3 = Web3Connector.get_connection(None)
        contract = w3.eth.contract(address=address, abi=abi)
        enumerate_method_selectors(contract)
        return contract

    @property
    def jsonrpc_conn(self):
        """
        Lazily instantiate and return the JSON RPC connection.
        """
        if not hasattr(self, '_BofhContractIface__jsonrpc_conn'):
            rpc_url = None
            if self.__get_rpc_url:
                rpc_url = self.__get_rpc_url()
            self.__jsonrpc_conn = JSONRPCConnector.get_connection(rpc_url)
        return self.__jsonrpc_conn

def main():
    """
    Main function: instantiate the contract interface and obtain contract.
    """
    iface = BofhContractIface()
    contract = iface.get_contract()
    # Additional operations can be performed with contract if needed.
    return contract

if __name__ == '__main__':
    main()