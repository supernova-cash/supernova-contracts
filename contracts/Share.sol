pragma solidity ^0.6.0;

import "./owner/AdminRole.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract Share is ERC20Burnable, AdminRole {
    constructor() public ERC20("TESTSHARE", "TESTSHARE") {
        _mint(msg.sender, 1 * 10**18);
    }

    function mint(address recipient_, uint256 amount_)
        public
        onlyAdmin
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override onlyAdmin {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyAdmin
    {
        super.burnFrom(account, amount);
    }
}
