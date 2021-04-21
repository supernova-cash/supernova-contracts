pragma solidity ^0.6.0;
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../owner/AdminRole.sol";
import "../LiquidityOracle.sol";

contract TokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public token1;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        token1.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        token1.safeTransfer(msg.sender, amount);
    }
}

contract QPool is TokenWrapper, AdminRole {
    IERC20 public token0;
    uint256 public duration;
    uint256 public starttime;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public deposits;
    address public liquidityOracle;
    uint256 public minTVL;
    bool public tvlLine = false;
    uint256 public releaseAmount;
    uint256 public intialAmount;

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
        address liquidityOracle_,
        uint256 minTVL_,
        uint256 intialAmount_
    ) public {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        starttime = starttime_;
        duration = duration_;
        rewardRate = reward.div(duration);
        lastUpdateTime = starttime;
        periodFinish = starttime.add(duration);
        liquidityOracle = liquidityOracle_;
        minTVL = minTVL_;
        intialAmount = intialAmount_;
    }

    modifier checkStart() {
        require(block.timestamp >= starttime, "Pool: not start");
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

    function enabled() public returns (bool) {
        if (tvlLine) {
            return true;
        }
        if (LiquidityOracle(liquidityOracle).tvl() >= minTVL) {
            tvlLine = true;
        }
        return tvlLine;
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

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkStart
    {
        require(amount > 0, "Pool: Cannot stake 0");
        uint256 newDeposit = deposits[msg.sender].add(amount);
        deposits[msg.sender] = newDeposit;
        super.stake(amount);
        emit Staked(msg.sender, amount);
        LiquidityOracle(liquidityOracle).update();
    }

    function withdraw(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkStart
    {
        require(amount > 0, "Pool: Cannot withdraw 0");
        deposits[msg.sender] = deposits[msg.sender].sub(amount);
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkStart {
        require(enabled(), "TVL is not enough");
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            token0.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) private {
        periodFinish = periodFinish.add(duration);
        if (periodFinish > block.timestamp) {
            rewardRate = reward.div(periodFinish.sub(block.timestamp));
        } else {
            rewardRate = 0;
        }
    }

    function updateStartTime(uint256 starttime_) external onlyAdmin {
        starttime = starttime_;
    }

    function updateLiquidity(address liquidityOracle_, uint256 minTVL_)
        external
        onlyAdmin
    {
        liquidityOracle = liquidityOracle_;
        minTVL = minTVL_;
    }

    function renew() external onlyAdmin updateReward(address(0)) {
        uint256 releaseAmount1 = intialAmount;
        uint256 tvl = LiquidityOracle(liquidityOracle).tvl();
        if (tvl < minTVL) {
            releaseAmount1 = intialAmount.mul(tvl).div(minTVL);
        }

        if (releaseAmount1 >= releaseAmount) {
            uint256 reward = releaseAmount1.sub(releaseAmount);
            notifyRewardAmount(reward);
            releaseAmount = releaseAmount1;
        } else {
            notifyRewardAmount(0);
        }
    }
}
