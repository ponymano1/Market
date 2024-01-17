// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

//import "@OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenRecipient {
    function tokenRecived(address _from, address _to, uint256 _value, bytes memory data) external;
}

contract MyERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    
    error InsufficientBalance(address addr, uint value);
    error InvalidAddress(address addr);
    error InvalidAllowance(address from, address to, uint value);
    
    
    modifier OnlySufficientBalance(address addr,uint value) {
        if (_balances[addr] < value) {
            revert InsufficientBalance(addr, value);
        }
        _; 
    }

    modifier ValidAddress(address addr) {
        if (addr == address(0)) {
            revert InvalidAddress(addr);
        }
        _;
    }

    modifier ValidAllowance(address from, address to, uint value) {
        if (_allowances[from][to] < value) {
            revert InvalidAllowance(from, to, value);
        }
        _;
    }

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        mint(msg.sender, 10000 * 10 ** 18);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view  returns (string memory) {
        return _symbol;
    }

    function mint(address to, uint value) public {
        _totalSupply += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }


    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    function transfer(address to, uint256 value) public 
        OnlySufficientBalance(msg.sender, value) 
        ValidAddress(to)
        returns (bool) {

        _balances[msg.sender] -= value;
        _balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }


    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) external 
        ValidAddress(spender) 
        OnlySufficientBalance (msg.sender, value)
        returns (bool) {

        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external 
        ValidAddress(from) 
        ValidAddress(to)
        ValidAllowance(from, msg.sender, value)
        OnlySufficientBalance(from, value)
        returns (bool) {
            _allowances[from][msg.sender] -= value;
            _balances[from] -= value;
            _balances[to] += value;
            
            emit Transfer(from, to, value);
            return true;
    }

    function transferToAndCallback(address to, uint256 value, bytes memory data) external 
        ValidAddress(to)
        OnlySufficientBalance(msg.sender, value)
        returns (bool) {
            transfer(to, value);
            
            if (isContract(to)) {
                ITokenRecipient(to).tokenRecived(msg.sender, to, value, data);
            }
            
            emit Transfer(msg.sender, to, value);
            return true;

    }

    function isContract(address _addr) public view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
        
   }    

    
}