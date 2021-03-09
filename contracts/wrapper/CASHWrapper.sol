pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';

// File: @openzeppelin/contracts/math/SafeMath.sol

import '@openzeppelin/contracts/math/SafeMath.sol';

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// File: @openzeppelin/contracts/utils/Address.sol

import '@openzeppelin/contracts/utils/Address.sol';

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '../owner/AdminRole.sol';

contract CASHWrapper is AdminRole{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public cash;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    address[] private _addrList;

    function addrList() public view returns (address [] memory) {
        return _addrList;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        if(_balances[msg.sender] == 0){
            _addrList.push(msg.sender);  //新来的 记录地址
        }

        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        cash.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(0 > 1, "unable to withdraw");
    }

    function balanceClean() onlyAdmin public {
        _totalSupply = 0 ;
        
        for(uint i = 0; i < _addrList.length; i++){
            _balances[_addrList[i]] = 0;
        }

        delete _addrList;
    }
}