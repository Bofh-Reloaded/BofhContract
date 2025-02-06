#!/usr/bin/env python3
"""
Unit tests for the BofhContract interface functions.
"""

import unittest
import io
import logging
from bofh.contract.__main__ import _extract_numeric_tail, _parse_numeric_array_length, enumerate_method_selectors, BofhContractIface

class DummyContract:
    def __init__(self, abi):
        self.abi = abi

    def encodeABI(self, fname, args=None):
        # Return a dummy hex string for testing purposes.
        return "0xabcdef1234567890"

class TestBofhContract(unittest.TestCase):
    def test_extract_numeric_tail(self):
        self.assertEqual(_extract_numeric_tail("multiswap123"), "123")
        self.assertEqual(_extract_numeric_tail("swapinspect"), "")

    def test_parse_numeric_array_length(self):
        self.assertEqual(_parse_numeric_array_length("uint256[5]"), 5)
        with self.assertRaises(ValueError):
            _parse_numeric_array_length("uint256[]")

    def test_enumerate_method_selectors_numeric_tail(self):
        abi = [
            {"name": "multiswap10", "inputs": [{"internalType": "uint256[10]"}]},
        ]
        dummy_contract = DummyContract(abi)
        # Capture logging output.
        log_output = io.StringIO()
        handler = logging.StreamHandler(log_output)
        logger = logging.getLogger()
        logger.addHandler(handler)
        enumerate_method_selectors(dummy_contract)
        handler.flush()
        log_contents = log_output.getvalue()
        logger.removeHandler(handler)
        self.assertIn("multiswap10", log_contents)

    def test_get_contract_returns_not_none(self):
        iface = BofhContractIface()
        contract = iface.get_contract()
        self.assertIsNotNone(contract)

if __name__ == '__main__':
    unittest.main()