pragma solidity ^0.6.0;
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../utils/ContractGuard.sol';
import '../interfaces/IRewardDistributionRecipient.sol';
import '../interfaces/ISimpleERCFund.sol';
import '../wrapper/CASHWrapper.sol';


contract SharePool is CASHWrapper, IRewardDistributionRecipient, ContractGuard{

    uint256 public starttime;
    address public fund;
    address public share;
    address public snGroup;

    constructor(
        address share_,
        address cash_, 
        address fund_,
        address snGroup_,
        uint256 starttime_
    ) public {
        share = share_;
        cash = IERC20(cash_);
        starttime = starttime_;
        fund = fund_;
        snGroup = snGroup_;
    }

    mapping(address => uint256) private investors;

    function earned(address investor) public view returns (uint256) {
        return investors[investor].mul(95).div(100);
    }

    function stake(uint256 amount)
        public
        override
        onlyOneBlock
    {
        require(amount > 0, 'SharePool: Cannot stake 0');
        require(block.timestamp >= starttime, 'SharePool: not start');

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
            IERC20(share).safeTransfer(msg.sender, reward.mul(95).div(100));
            IERC20(share).safeTransfer(snGroup, reward.mul(5).div(100));
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
        require(amount <= IERC20(share).balanceOf(address(this)), 'balance is not enough');

        require(amount > 0, 'SharePool: Cannot allocate 0');
        require(
            totalSupply() > 0,
            'SharePool: Cannot allocate when totalSupply is 0'
        );

        uint256 rps = amount.mul(10 ** 18).div(totalSupply());

        address[] memory _addrList = addrList(); 
        for(uint i = 0; i < _addrList.length; i++){
            uint256 reward = balanceOf(_addrList[i]).mul(rps).div(10 ** 18);
            investors[_addrList[i]] = investors[_addrList[i]].add(reward);
        }
        emit RewardAdded(amount);

        uint256 fundamount = totalSupply();
        cash.safeApprove(fund, fundamount);
        ISimpleERCFund(fund).deposit(
            address(cash),
            fundamount,
            'SharePool: Desposit Fund'
        );
        emit DespositFund(now, fundamount);
    
        balanceClean();
    }

    function setFund(address newFund) public onlyAdmin {
        fund = newFund;
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DespositFund(uint256 timestamp, uint256 fundamount);

}
