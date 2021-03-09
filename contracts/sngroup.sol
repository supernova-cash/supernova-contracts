pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import './utils/ContractGuard.sol';
import './owner/AdminRole.sol';


contract SnGroup is AdminRole, ContractGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public token;

    constructor(
        address token_
    ) public {
        token = IERC20(token_);
    }

    function reward() onlyOneBlock public {
        uint256 _totalSupply = token.balanceOf(address(this));
        token.safeTransfer(0xd8f1a5fbea003ea15530840C954213FeD6cAa546, _totalSupply.div(100).mul(10));
        token.safeTransfer(0xD5dBaFdB1F41faF903642994D6A44C87b69A1F91, _totalSupply.div(100).mul(10));
        token.safeTransfer(0x2896a06dA6926d3a3b857C040E4453A1a220dF74, _totalSupply.div(100).mul(3));
        token.safeTransfer(0x2F850E57C5E5F307Dd98CC27Ec38329f68Fe8E14, _totalSupply.div(100).mul(10));
        token.safeTransfer(0xF1Fc8962e740a6eD88C39f8ab7a3B087c98AcE34, _totalSupply.div(100).mul(10));
        token.safeTransfer(0xB2173fE82cD0CBDF9F887773012c96dBF3C3015e, _totalSupply.div(100).mul(5));
        token.safeTransfer(0xa59b7f3E17f7f16f1d1a60962336a1BB7Ba39091, _totalSupply.div(100).mul(1));
        token.safeTransfer(0x16df6524Ea467cd0D6F596F081058027Ae38a06d, _totalSupply.div(100).mul(1));
        token.safeTransfer(0x84931d80Eda80893C8bCc919539fD3Bca62E0213, _totalSupply.div(100).mul(1));
        token.safeTransfer(0x774b8D0Db5c42BC8153e3884016b7B36855fab88, _totalSupply.div(100).mul(3));
        token.safeTransfer(0xff2A604cCC36fB5f8fc3ab730355CF3AC9194d67, _totalSupply.div(100).mul(6));
        token.safeTransfer(0x6585DDae5725CCDB775071742EC2FDD6C3558658, _totalSupply.div(100).mul(20));
        token.safeTransfer(0x7CC72830C25a7c765C19A16C9d1F74d303bd7cC8, _totalSupply.div(100).mul(20));
    }
}
