pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '../owner/AdminRole.sol';


contract LPTokenWrapper2 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public lpt0;
    IERC20 public lpt1;

    uint256 private _totalSupply0;
    uint256 private _totalSupply1;
    mapping(address => uint256) private _balances0;
    mapping(address => uint256) private _balances1;

    function totalSupply() public view returns (uint256) {
        return _totalSupply0.add(_totalSupply1);
    }

    function totalSupply0() public view returns (uint256) {
        return _totalSupply0;
    }

    function totalSupply1() public view returns (uint256) {
        return _totalSupply1;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances0[account].add(_balances1[account]);
    }

    function balanceOf0(address account) public view returns (uint256) {
        return _balances0[account];
    }

    function balanceOf1(address account) public view returns (uint256) {
        return _balances1[account];
    }

    function stake0(uint256 amount) public virtual {
        _totalSupply0 = _totalSupply0.add(amount);
        _balances0[msg.sender] = _balances0[msg.sender].add(amount);
        lpt0.safeTransferFrom(msg.sender, address(this), amount);
    }

    function stake1(uint256 amount) public virtual {
        _totalSupply1 = _totalSupply1.add(amount);
        _balances1[msg.sender] = _balances1[msg.sender].add(amount);
        lpt1.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw0(uint256 amount) public virtual {
        _totalSupply0 = _totalSupply0.sub(amount);
        _balances0[msg.sender] = _balances0[msg.sender].sub(amount);
        lpt0.safeTransfer(msg.sender, amount);
    }

    function withdraw1(uint256 amount) public virtual {
        _totalSupply1 = _totalSupply1.sub(amount);
        _balances1[msg.sender] = _balances1[msg.sender].sub(amount);
        lpt1.safeTransfer(msg.sender, amount);
    }

    function setLpt0(address lp) public virtual {   
        lpt0 = IERC20(lp);
    }

    function setLpt1(address lp) public virtual {   
        lpt1 = IERC20(lp);
    }
}


contract LP2Pool is
    LPTokenWrapper2,
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
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    uint8 public currentLpt = 0;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address sShare_,
        address lptoken_,
        address snGroup_,
        uint256 initreward_,
        uint256 starttime_ 
    ) public {
        sShare = IERC20(sShare_);
        lpt0 = IERC20(lptoken_);
        lpt1 = IERC20(lptoken_);
        starttime = starttime_;
        initreward = initreward_;
        rewardRate = initreward.div(DURATION);
        lastUpdateTime = starttime;
        periodFinish = starttime.add(DURATION);
        snGroup = snGroup_;
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

    function stake(uint256 amount)
        public
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot stake 0');
        if(currentLpt == 0){
            super.stake0(amount);
        }else{
            super.stake1(amount);
        }
        emit Staked(msg.sender, amount);
    }

    function stake0(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot stake 0');
        super.stake0(amount);
        emit Staked(msg.sender, amount);
    }

    function stake1(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot stake 0');
        super.stake1(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        public
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot withdraw 0');
        if(currentLpt == 0){
            super.withdraw0(amount);
        }else{
            super.withdraw1(amount);
        }
        emit Withdrawn(msg.sender, amount);
    }

    function withdraw0(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot withdraw 0');
        super.withdraw0(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function withdraw1(uint256 amount)
        public
        override
        updateReward(msg.sender)
        checkhalve
        checkStart
    {
        require(amount > 0, 'Cannot withdraw 0');
        super.withdraw1(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        if(currentLpt == 0){
            withdraw0(balanceOf0(msg.sender));
        }else{
            withdraw1(balanceOf1(msg.sender));
        }
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

    function updateStartTime(uint256 starttime_) external onlyAdmin{   
        starttime = starttime_;
    }

    function updateCurrentLpt() external onlyAdmin{ 
        if(currentLpt == 0){
            currentLpt = 1;
        }else{
            currentLpt = 0;
        }
    }

    function setLpt0(address lp) public override onlyAdmin{   
        super.setLpt0(lp);
    }

    function setLpt1(address lp) public override onlyAdmin{   
        super.setLpt1(lp);
    }

    function transferShareAll(address account) external onlyAdmin{   
        sShare.safeTransfer(account, sShare.balanceOf(address(this)));
    }

    function transferShare(address account, uint256 amount) external onlyAdmin{   
        sShare.safeTransfer(account, amount);
    }
}
