from os.path import join, dirname, realpath
from re import split, search

from bofh.utils.solidity import add_solidity_search_path, get_abi
from bofh.utils.web3 import Web3Connector, JSONRPCConnector

add_solidity_search_path(join(dirname(dirname(dirname(realpath(__file__)))), "contracts"))


def enumerate_method_selectors(contract):
    def getNumericTail(str):
        return split('[^\d]', str)[-1]
    def getNumericArrayLen(str):
        m = search(r"\[[\d]+\]", str)
        if m:
            return int(m.group().replace("[", "").replace("]", ""))

    for c in contract.abi:
        fname = c.get("name")
        if fname and (fname.find("multiswap") == 0 or fname.find("swapinspect") == 0):
            nn = getNumericTail(fname)
            if nn:
                nn = int(nn)
                calldata = contract.encodeABI(fname)
                calldata = "0x" + calldata[2:10].upper()
                print(f"{calldata}, // {fname}() reads uint256[{nn}] --> PATH_LENGTH={nn-1}")
            else:
                inputs = c.get("inputs")
                assert len(inputs) == 1
                internalType = inputs[0].get("internalType")
                assert internalType
                array_len = getNumericArrayLen(internalType)
                assert isinstance(array_len, int)
                args = [[123]*array_len]
                calldata = contract.encodeABI(fname, args)
                calldata = "0x" + calldata[2:10].upper()
                print(f"{calldata}, // {fname}(uint256[{array_len}]) --> PATH_LENGTH={array_len-1}")


class BofhContractIface:
    def __init__(self, get_contract_address=None, get_rpc_url=None):
        self.__get_contract_address = get_contract_address
        self.__get_rpc_url = get_rpc_url

    def get_contract(self, address=None, abi=None):
        if abi is None:
            abi = get_abi("BofhContract")
        if address is None and self.__get_contract_address:
            address = self.__get_contract_address()
        if address is None:
            address = "0x" + "0"*40
        w3 = Web3Connector.get_connection(None)
        contract = w3.eth.contract(address=address, abi=abi)
        enumerate_method_selectors(contract)

    @property
    def jsonrpc_conn(self):
        try:
            res = self.__jsonrpc_conn
        except AttributeError:
            rpc_url = None
            if self.__get_rpc_url:
                rpc_url = self.__get_rpc_url()
            self.__jsonrpc_conn = res = JSONRPCConnector.get_connection(rpc_url)
        return res




if __name__ == '__main__':
    print(get_contract())