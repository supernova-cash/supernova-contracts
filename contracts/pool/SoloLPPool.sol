pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../owner/AdminRole.sol';
import '../interfaces/ISolo.sol';


contract SoloLPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public lpt;
    address public SoloSwap;
    uint256 public SoloSwapStakeOpen = 0;
    uint256 public SoloSwapWithdrawOpen = 0;
    uint256 public SoloPid;

    uint256 private _totalSupply;
    uint256 private _totalSupplySoloSwap;

    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function totalSupplySoloSwap() public view returns (uint256) {
        return _totalSupplySoloSwap;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        lpt.safeTransferFrom(msg.sender, address(this), amount);

        stakeSoloSwap(amount);
    }

    function stakeSoloSwap(uint256 amount) internal {
        if(SoloSwapStakeOpen == 0){
            return;
        }
        _totalSupplySoloSwap = _totalSupplySoloSwap.add(amount);
        lpt.safeApprove(SoloSwap, amount);
        ISolo(SoloSwap).deposit(SoloPid, amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount <=  _balances[msg.sender], 'Pool: Cannot withdraw');
        
        withdrawSoloSwap(amount);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        lpt.safeTransfer(msg.sender, amount);
    }

    function withdrawSoloSwap(uint256 amount) internal{
        if(SoloSwapWithdrawOpen == 0){
            return;
        }
        if(_totalSupplySoloSwap == 0){
            return;
        }
        if(amount > _totalSupplySoloSwap){
            amount = _totalSupplySoloSwap;
        }
        _totalSupplySoloSwap = _totalSupplySoloSwap.sub(amount);

        ISolo(SoloSwap).withdraw(SoloPid, amount);
    }
}


contract SoloLPPool is
    SoloLPTokenWrapper,
    AdminRole
{
    IERC20 public sShare;
    uint256 public constant DURATION = 30 days; //days

    uint256 public initreward;
    uint256 public starttime; // starttime TBD
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    address public snGroup;
    IERC20 public MDX;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address sShare_,
        address lptoken_,
        address snGroup_,
        uint256 initreward_,
        uint256 starttime_,
        address MDX_
    ) public {
        sShare = IERC20(sShare_);
        lpt = IERC20(lptoken_);
        starttime = starttime_;
        initreward = initreward_;
        rewardRate = initreward.div(DURATION);
        lastUpdateTime = starttime;
        periodFinish = starttime.add(DURATION);
        snGroup = snGroup_;
        MDX = IERC20(MDX_);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account])
                .mul(95)
                .div(100);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot stake 0');
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot withdraw 0');
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkhalve checkStart {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            sShare.safeTransfer(msg.sender, reward);
            sShare.safeTransfer(snGroup, reward.div(19));
            emit RewardPaid(msg.sender, reward);
        }
    }

    modifier checkhalve() {
        if (block.timestamp >= periodFinish) {
            initreward = initreward.mul(75).div(100);

            rewardRate = initreward.div(DURATION);
            periodFinish = block.timestamp.add(DURATION);
            emit RewardAdded(initreward);
        }
        _;
    }

    modifier checkStart() {
        require(block.timestamp >= starttime, 'not start');
        _;
    }

    function updateStartTime(uint256 starttime_)
        external
        onlyAdmin
    {   
        starttime = starttime_;
    }

    function transferShareAll(address account) external onlyAdmin{   
        sShare.safeTransfer(account, sShare.balanceOf(address(this)));
    }

    function transferShare(address account, uint256 amount) external onlyAdmin{   
        sShare.safeTransfer(account, amount);
    }

    function setSoloSwap(address addr_, uint256 pid_, uint256 stakeOpen_, uint256 withdrawOpen_)
        external
        onlyAdmin
    {   
        SoloSwap = addr_;
        SoloPid = pid_;
        SoloSwapStakeOpen = 0;
        SoloSwapWithdrawOpen = 0;
    }

    function stakeSoloSwap2(uint256 amount) external onlyAdmin{
        super.stakeSoloSwap(amount);
    }

    function withdrawSoloSwap2(uint256 amount) external onlyAdmin {
        super.withdrawSoloSwap(amount);
    }

    function getMDX(address addr_, uint256 amount) external onlyAdmin {
        MDX.safeTransfer(addr_, amount);
    }
}
