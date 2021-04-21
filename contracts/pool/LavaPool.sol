pragma solidity ^0.6.0;
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../owner/AdminRole.sol';

interface ILavaSwap {
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
}

contract LavaTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public token1;
    address public lavaSwap;
    uint256 public lavaSwapOpen = 0;
    uint256 public lavaPid;

    uint256 private _totalSupply;
    uint256 private _totalSupplyLavaSwap;
    
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function totalSupplyLavaSwap() public view returns (uint256) {
        return _totalSupplyLavaSwap;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        token1.safeTransferFrom(msg.sender, address(this), amount);

        stakeLavaSwap(amount);
    }

    function stakeLavaSwap(uint256 amount) internal {
        if(lavaSwapOpen == 0){
            return;
        }
        _totalSupplyLavaSwap = _totalSupplyLavaSwap.add(amount);
        token1.safeApprove(lavaSwap, amount);
        ILavaSwap(lavaSwap).deposit(lavaPid, amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount <=  _balances[msg.sender], 'Pool: Cannot withdraw');
        
        withdrawLavaSwap(amount);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        token1.safeTransfer(msg.sender, amount);
    }

    function withdrawLavaSwap(uint256 amount) internal{
        if(_totalSupplyLavaSwap == 0){
            return;
        }
        if(amount > _totalSupplyLavaSwap){
            amount = _totalSupplyLavaSwap;
        }
        _totalSupplyLavaSwap = _totalSupplyLavaSwap.sub(amount);

        ILavaSwap(lavaSwap).withdraw(lavaPid, amount);
    }
}

contract LavaPool is LavaTokenWrapper, AdminRole {
    IERC20 public token0;
    uint256 public duration;
    uint256 public starttime;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    IERC20 public lava;
    address public snGroup;
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
        uint256 lava_,
        address snGroup_
    ) public {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        starttime = starttime_;
        duration = duration_ * 86400;
        rewardRate = reward.div(duration);
        lastUpdateTime = starttime;
        periodFinish = starttime.add(duration);
        lava = IERC20(lava_);
        snGroup = snGroup_;
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
                .add(rewards[account])
                .mul(95)
                .div(100);
    }

    function earnedLavaP(address account) public view returns (uint256) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            if(lava.balanceOf(address(this)) > 0){
                return reward.mul(lava.balanceOf(address(this))).div(token0.balanceOf(address(this)));
            }
        }
        return 0;
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
        if (reward > 0) {
            if(lava.balanceOf(address(this)) > 0){
                uint256 lavaP = reward.mul(lava.balanceOf(address(this))).div(token0.balanceOf(address(this)));
                lava.safeTransfer(msg.sender, lavaP);
            }

            rewards[msg.sender] = 0;
            token0.safeTransfer(msg.sender, reward);
            token0.safeTransfer(snGroup, reward.div(19));
            emit RewardPaid(msg.sender, reward);
        }
    }

    function updateStartTime(uint256 starttime_)
        external
        onlyAdmin
    {   
        starttime = starttime_;
    }

    function setLavaSwap(address addr_, uint256 pid_, uint256 lavaOpen_)
        external
        onlyAdmin
    {   
        lavaSwap = addr_;
        lavaSwapOpen = lavaOpen_;
        lavaPid = pid_;
    }

    function stakeLavaSwap2(uint256 amount) external onlyAdmin{
        super.stakeLavaSwap(amount);
    }

    function withdrawLavaSwap2(uint256 amount) external onlyAdmin {
        super.withdrawLavaSwap(amount);
    }

    function getLava(address addr_, uint256 amount) external onlyAdmin {
        lava.safeTransfer(addr_, amount);
    }

    function getToken0(address addr_, uint256 amount) external onlyAdmin {
        token0.safeTransfer(addr_, amount);
    }
}
