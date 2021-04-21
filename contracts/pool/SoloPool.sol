pragma solidity ^0.6.0;
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../owner/AdminRole.sol';
import '../interfaces/ISolo.sol';


contract SoloTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public token1;
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
        token1.safeTransferFrom(msg.sender, address(this), amount);

        stakeSoloSwap(amount);
    }

    function stakeSoloSwap(uint256 amount) internal {
        if(SoloSwapStakeOpen == 0){
            return;
        }
        _totalSupplySoloSwap = _totalSupplySoloSwap.add(amount);
        token1.safeApprove(SoloSwap, amount);
        ISolo(SoloSwap).deposit(SoloPid, amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount <=  _balances[msg.sender], 'Pool: Cannot withdraw');
        
        withdrawSoloSwap(amount);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        token1.safeTransfer(msg.sender, amount);
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

contract SoloPool is SoloTokenWrapper, AdminRole {
    IERC20 public token0;
    uint256 public duration;
    uint256 public starttime;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    IERC20 public MDX;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public deposits;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address token0_,
        address token1_,
        uint256 reward,
        uint256 duration_,
        uint256 starttime_,
        address MDX_
    ) public {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        starttime = starttime_;
        duration = duration_ * 86400;
        rewardRate = reward.div(duration);
        lastUpdateTime = starttime;
        periodFinish = starttime.add(duration);
        MDX = IERC20(MDX_);
    }

    modifier checkStart() {
        require(block.timestamp >= starttime, 'Pool: not start');
        _;
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
                .add(rewards[account]);
    }

    function stake(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkStart
    {
        require(amount > 0, 'Pool: Cannot stake 0');
        uint256 newDeposit = deposits[msg.sender].add(amount);
        
        deposits[msg.sender] = newDeposit;
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkStart
    {
        require(amount > 0, 'Pool: Cannot withdraw 0');
        deposits[msg.sender] = deposits[msg.sender].sub(amount);
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();       
    }

    function getReward() public updateReward(msg.sender) checkStart {
        uint256 reward = earned(msg.sender);
        rewards[msg.sender] = 0;
        token0.safeTransfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function updateStartTime(uint256 starttime_)
        external
        onlyAdmin
    {   
        starttime = starttime_;
    }

    function setSoloSwap(address addr_, uint256 pid_, uint256 stakeOpen_, uint256 withdrawOpen_)
        external
        onlyAdmin
    {   
        SoloSwap = addr_;
        SoloPid = pid_;
        SoloSwapStakeOpen = stakeOpen_;
        SoloSwapWithdrawOpen = withdrawOpen_;
    }

    function setMDX(address addr_) external onlyAdmin {
        MDX = IERC20(addr_);
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

    function getToken0(address addr_, uint256 amount) external onlyAdmin {
        token0.safeTransfer(addr_, amount);
    }
}
