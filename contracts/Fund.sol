pragma solidity ^0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import './owner/AdminRole.sol';
import './interfaces/ISimpleERCFund.sol';

contract Fund is ISimpleERCFund, AdminRole {
    using SafeERC20 for IERC20;

    address public pegPool;

    function deposit(
        address token,
        uint256 amount,
        string memory reason
    ) public override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, now, reason);
    }

    function withdraw(
        address token,
        uint256 amount,
        address to,
        string memory reason
    ) public override onlyAdmin {
        require(to == pegPool, "address err");
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawal(msg.sender, to, now, reason);
    }

    function setPegPool(address pegPool_) public onlyAdmin {
        pegPool = pegPool_;
    }

    event Deposit(address indexed from, uint256 indexed at, string reason);
    event Withdrawal(
        address indexed from,
        address indexed to,
        uint256 indexed at,
        string reason
    );
}
