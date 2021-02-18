pragma solidity ^0.6.0;

import "./owner/Operator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract Share is ERC20Burnable, Operator {
    constructor() public ERC20("SHARE", "SHARE") {
        _mint(msg.sender, 1 * 10**18);
    }

    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }
}
