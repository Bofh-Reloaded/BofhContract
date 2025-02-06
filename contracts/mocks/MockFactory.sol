// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

import "./MockPair.sol";

contract MockFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );
    
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        require(tokenA != tokenB, "Identical addresses");
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        require(token0 != address(0), "Zero address");
        require(getPair[token0][token1] == address(0), "Pair exists");
        
        // Deploy new pair contract with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(MockPair).creationCode,
            abi.encode(token0, token1)
        );
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Store pair mapping both ways
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
    
    // Helper function to compute pair address without creating it
    function computePairAddress(
        address tokenA,
        address tokenB
    ) public view returns (address) {
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(type(MockPair).creationCode)
            )
        );
        return address(uint160(uint256(hash)));
    }
}