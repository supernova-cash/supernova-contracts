pragma solidity ^0.6.0;
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../interfaces/ISimpleERCFund.sol';
import '../owner/AdminRole.sol';
import '../utils/ContractGuard.sol';
import '../wrapper/PEGWrapper.sol';


contract SPool is PEGWrapper, ContractGuard{

    uint256 public stake_duration;
    uint256 public starttime;
    uint256 public times = 0;
    uint256 public dailyReward;
    address public fund;
    address public cash;

    bool public once = true;

    /// @notice 结构体：SPool席位
    struct SPoolseat {
        uint256 lastSnapshotIndex; // 最后快照索引
        uint256 rewardEarned; // 未领取的奖励数量
    }

    /// @notice 结构体：SPool快照
    struct SPoolSnapshot {
        uint256 time; // 区块高度
        uint256 rewardReceived; // 收到的奖励
        uint256 rewardPerPeg; // 每股奖励数量
    }

    constructor(
        address _cash,
        address _peg,
        address _fund,
        uint256 _reward,
        uint256 _stake_duration,
        uint256 _starttime
    ) public {
        cash = _cash;
        peg = IERC20(_peg);
        starttime = _starttime;
        dailyReward = _reward;
        stake_duration = _stake_duration;
        fund = _fund;

        // 创建SPool快照
        SPoolSnapshot memory genesisSnapshot = SPoolSnapshot({
            time: block.number,
            rewardReceived: 0,
            rewardPerPeg: 0
        });
        //SPool的创世快照推入数组
        SPoolHistory.push(genesisSnapshot);
    }


    mapping(address => SPoolseat) private investors;
    /// @dev spool快照
    SPoolSnapshot[] private SPoolHistory;

    /* ========== Modifiers =============== */
    /// @notice 修饰符：需要调用者抵押数量大于0
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
            // 根据成员地址实例化SPool席位
            SPoolseat memory seat = investors[investor];
            // 已获取奖励数量 = 计算可提取的总奖励
            seat.rewardEarned = earned(investor);
            // 最后快照索引 = SPool快照数组长度-1
            seat.lastSnapshotIndex = latestSnapshotIndex();
            // 重新赋值
            investors[investor] = seat;
        }
        _;
    }

    function latestSnapshotIndex() public view returns (uint256) {
        // SPool数组长度-1
        return SPoolHistory.length.sub(1);
    }

    function getLatestSnapshot() internal view returns (SPoolSnapshot memory) {
        return SPoolHistory[latestSnapshotIndex()];
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
        returns (SPoolSnapshot memory)
    {
        return SPoolHistory[getLastSnapshotIndexOf(investor)];
    }

    function rewardPerPeg() public view returns (uint256) {
        return getLatestSnapshot().rewardPerPeg;
    }

    function earned(address investor) public view returns (uint256) {
        uint256 latestRPS = rewardPerPeg();
        uint256 storedRPS = getLastSnapshotOf(investor).rewardPerPeg;
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
        require(amount > 0, 'SPool: Cannot stake 0');
        require(block.timestamp >= starttime, 'SPool: not start');
        require(block.timestamp < starttime + stake_duration, 'SPool: stake end');

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
        //更新SPool的奖励后，获取奖励数量
        uint256 reward = investors[msg.sender].rewardEarned;
        // 如果数量大于0
        if (reward > 0) {
            //把未领取的奖励数量重设为0
            investors[msg.sender].rewardEarned = 0;
            // 将奖励发送给用户
            IERC20(cash).safeTransfer(msg.sender, reward);
            //触发完成奖励事件
            emit RewardPaid(msg.sender, reward);
        }
    }

    function release(uint256 amount)
        external
        onlyOneBlock
        onlyAdmin
    {
        require(once, 'SPool: release err');
        // 确认分配数量大于0
        require(amount > 0, 'SPoolroom: Cannot allocate 0');
        // 确认质押总量大于0
        require(
            totalSupply() > 0,
            'SPoolroom: Cannot allocate when totalSupply is 0'
        );

        uint256 prevRPS = rewardPerPeg();
        uint256 nextRPS = prevRPS.add(amount.mul(10**18).div(totalSupply()));
        SPoolSnapshot memory newSnapshot = SPoolSnapshot({
            time: block.number, // 当前区块高度
            rewardReceived: amount, // 收到的分配数量
            rewardPerPeg: nextRPS // 每股奖励数量
        });
        //更新快照推入数组
        SPoolHistory.push(newSnapshot);

        emit RewardAdded(amount);

        uint256 fundamount= totalSupply();
        peg.safeApprove(fund, fundamount);
        // 调用fund合约的存款方法存入sFUND
        ISimpleERCFund(fund).deposit(
            address(peg),
            fundamount,
            'Treasury: Desposit Fund'
        );
        emit DespositFund(now, fundamount);
        once = false;
    }

    function updateStartTime(uint256 starttime_)
        external
        onlyAdmin
    {   
        starttime = starttime_;
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DespositFund(uint256 timestamp, uint256 fundamount);

}