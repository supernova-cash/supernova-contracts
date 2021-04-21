pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../utils/ContractGuard.sol';
import '../interfaces/ISimpleERCFund.sol';
import '../owner/AdminRole.sol';

contract PEGWrapper2 is AdminRole{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public peg;

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
        peg.safeTransferFrom(msg.sender, address(this), amount);
    }

    function stake2(address account, uint256 amount) onlyAdmin public {
        if(_balances[account] == 0){
            _addrList.push(account);  //新来的 记录地址
        }
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
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

contract DonatePool is PEGWrapper2, ContractGuard{
    uint256 public starttime;
    address public fund;
    address public cash;

    constructor(
        address cash_,
        address peg_, 
        address fund_,
        uint256 starttime_
    ) public {
        cash = cash_;
        peg = IERC20(peg_);
        starttime = starttime_;
        fund = fund_;
    }

    mapping(address => uint256) private investors;  //用户奖励

    function earned(address investor) public view returns (uint256) {
        return investors[investor];
    }

    function stake(uint256 amount)
        public
        override
        onlyOneBlock
    {
        require(0 > 1, "unable to stake");
    }

    function withdraw(uint256 amount)
        public
        override
    {
        require(0 > 1, "unable to withdraw");
    }

    function exit() external {
        require(block.timestamp >= starttime, 'CashPool: not start');
        getReward();
    }

    function getReward() public {
        uint256 reward = investors[msg.sender];
        if (reward > 0) {
            investors[msg.sender] = 0;
            IERC20(cash).safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
     
    function release(uint256 amount) //每个周期执行一次
        external
        onlyOneBlock
        onlyAdmin
    {
        require(amount <= IERC20(cash).balanceOf(address(this)), 'balance is not enough');

        require(amount > 0, 'CashPool: Cannot allocate 0');
        // 确认质押总量大于0
        require(
            totalSupply() > 0,
            'CashPool: Cannot allocate when totalSupply is 0'
        );

        uint256 rps = amount.mul(10 ** 18).div(totalSupply());

        address[] memory _addrList = addrList(); 
        for(uint i = 0; i < _addrList.length; i++){
            uint256 reward = balanceOf(_addrList[i]).mul(rps).div(10 ** 18);
            investors[_addrList[i]] = investors[_addrList[i]].add(reward);
        }
        emit RewardAdded(amount);
    }

    function updateStartTime(uint256 starttime_)
        external
        onlyAdmin
    {   
        starttime = starttime_;
    }

    function setFund(address newFund) public onlyAdmin {
        fund = newFund;
    }

    function setCash(address newCash) public onlyAdmin {
        cash = newCash;
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DespositFund(uint256 timestamp, uint256 fundamount);

}
