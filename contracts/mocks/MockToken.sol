// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.10;

contract MockToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) {
        name = name_;
        symbol = symbol_;
        totalSupply = initialSupply_;
        balances[msg.sender] = initialSupply_;
        emit Transfer(address(0), msg.sender, initialSupply_);
    }
    
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }
    
    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, allowances[owner][spender] + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "Decreased below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        require(to != address(0), "Mint to zero address");
        totalSupply += amount;
        unchecked {
            balances[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        require(from != address(0), "Burn from zero address");
        require(balances[from] >= amount, "Burn amount exceeds balance");
        unchecked {
            balances[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(balances[from] >= amount, "Transfer amount exceeds balance");
        unchecked {
            balances[from] -= amount;
            balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
    
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(spender != address(0), "Approve to zero address");
        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}