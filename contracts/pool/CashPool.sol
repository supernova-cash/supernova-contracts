pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../utils/ContractGuard.sol';
import '../interfaces/IRewardDistributionRecipient.sol';
import '../interfaces/ISimpleERCFund.sol';
import '../wrapper/PEGWrapper.sol';


contract CashPool is PEGWrapper, IRewardDistributionRecipient, ContractGuard{

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
        require(amount > 0, 'CashPool: Cannot stake 0');
        require(block.timestamp >= starttime, 'CashPool: not start');

        super.stake(amount);
        emit Staked(msg.sender, amount);
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

    function notifyRewardAmount(uint256 reward)
        external
        override
        onlyRewardDistribution
    {
        emit RewardAdded(reward);
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

        uint256 fundamount = totalSupply();
        peg.safeApprove(fund, fundamount);
        // 调用fund合约的存款方法存入sFUND
        ISimpleERCFund(fund).deposit(
            address(peg),
            fundamount,
            'CashPool: Desposit Fund'
        );
        emit DespositFund(now, fundamount);

        balanceClean();
    }

    function setFund(address newFund) public onlyAdmin {
        fund = newFund;
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DespositFund(uint256 timestamp, uint256 fundamount);

}
