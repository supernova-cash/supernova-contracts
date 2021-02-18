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

contract PegPool is CASHWrapper, IRewardDistributionRecipient, ContractGuard{

    uint256 public starttime;
    uint256 public times = 0;
    uint256 public dailyReward;
    address public fund;
    address public peg;

    bool public once = true;


        /// @notice 结构体：PegPool席位
    struct PegPoolseat {
        uint256 lastSnapshotIndex; // 最后快照索引
        uint256 rewardEarned; // 未领取的奖励数量
    }

    /// @notice 结构体：PegPool快照
    struct PegPoolSnapshot {
        uint256 time; // 区块高度
        uint256 rewardReceived; // 收到的奖励
        uint256 rewardPerCash; // 每股奖励数量
    }

    constructor(
        address peg_,
        address cash_, 
        address fund_,
        uint256 reward_,
        uint256 starttime_
    ) public {
        peg = peg_;
        cash = IERC20(cash_);
        starttime = starttime_;
        dailyReward = reward_;
        fund = fund_;

        // 创建PegPool快照
        PegPoolSnapshot memory genesisSnapshot = PegPoolSnapshot({
            time: block.number,
            rewardReceived: 0,
            rewardPerCash: 0
        });
        //PegPool的创世快照推入数组
        PegPoolHistory.push(genesisSnapshot);

    }


    mapping(address => PegPoolseat) private investors;
    /// @dev PegPool快照
    PegPoolSnapshot[] private PegPoolHistory;

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
            // 根据成员地址实例化PegPool席位
            PegPoolseat memory seat = investors[investor];
            // 已获取奖励数量 = 计算可提取的总奖励
            seat.rewardEarned = earned(investor);
            // 最后快照索引 = PegPool快照数组长度-1
            seat.lastSnapshotIndex = latestSnapshotIndex();
            // 重新赋值
            investors[investor] = seat;
        }
        _;
    }

    function latestSnapshotIndex() public view returns (uint256) {
        // PegPool数组长度-1
        return PegPoolHistory.length.sub(1);
    }

    /**
     * @dev PegPool最后一次快照具体内容
     * @return PegPool快照结构体
     */
    function getLatestSnapshot() internal view returns (PegPoolSnapshot memory) {
        return PegPoolHistory[latestSnapshotIndex()];
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
        returns (PegPoolSnapshot memory)
    {
        return PegPoolHistory[getLastSnapshotIndexOf(investor)];
    }


    function rewardPerCash() public view returns (uint256) {
        return getLatestSnapshot().rewardPerCash;
    }

    function earned(address investor) public view returns (uint256) {
        uint256 latestRPS = rewardPerCash();
        uint256 storedRPS = getLastSnapshotOf(investor).rewardPerCash;
        return
            balanceOf(investor).mul(latestRPS.sub(storedRPS)).div(1e18).add(
                investors[investor].rewardEarned
            );
    }

    function stake(uint256 amount)
        public
        override
        onlyOneBlock
    {
        require(amount > 0, 'PegPool: Cannot stake 0');
        require(block.timestamp >= starttime, 'PegPool: not start');

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
        uint256 reward = investors[msg.sender].rewardEarned;
        if (reward > 0) {
            investors[msg.sender].rewardEarned = 0;
            cash.safeTransfer(msg.sender, reward);
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
        require(amount > 0, 'PegPool: Cannot allocate 0');
        require(
            totalSupply() > 0,
            'PegPoolroom: Cannot allocate when totalSupply is 0'
        );

        uint256 prevRPS = rewardPerCash();
        uint256 nextRPS = prevRPS.add(amount.mul(10**18).div(totalSupply()));
        PegPoolSnapshot memory newSnapshot = PegPoolSnapshot({
            time: block.number, // 当前区块高度
            rewardReceived: amount, // 收到的分配数量
            rewardPerCash: nextRPS // 每股奖励数量
        });
        PegPoolHistory.push(newSnapshot);
        emit RewardAdded(amount);

        uint256 fundamount= totalSupply();
        cash.safeApprove(fund, fundamount);
            ISimpleERCFund(fund).deposit(
                address(cash),
                fundamount,
                'PegPool: Desposit Fund'
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
