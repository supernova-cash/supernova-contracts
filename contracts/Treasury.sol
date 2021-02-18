pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import './interfaces/IOracle.sol';
import './interfaces/IBoardroom.sol';
import './interfaces/ISuperNovaAsset.sol';
import './interfaces/ISimpleERCFund.sol';
import './interfaces/IRewardPool.sol';
import './interfaces/ISharePool.sol';
import './interfaces/ICashPool.sol';
import './interfaces/IPegPool.sol';
import './lib/Babylonian.sol';
import './lib/FixedPoint.sol';
import './lib/Safe112.sol';
import './owner/Operator.sol';
import './utils/Epoch.sol';
import './utils/ContractGuard.sol';
import './Fund.sol';


contract Treasury is ContractGuard, Epoch {
    using FixedPoint for *;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using Safe112 for uint112;

    /* ========== STATE VARIABLES ========== */

    // ========== FLAGS
    bool public migrated = false;
    bool public initialized = false;

    // ========== CORE
    address public fund;
    address public cash;
    address public share;
    address public peg;
    address public boardroom;
    address public sharePool;
    address public cashPool;
    address public pegPool;

    address public oracle;

    // ========== PARAMS
    uint256 public cashPriceOne;
    uint256 public cashPriceCeiling;
    uint256 public cashPriceFloor;
    uint256 private accumulatedSeigniorage = 0;
    uint256 public fundAllocationRate = 5; 
    uint256 public inflationPercentCeil;
    uint256 public initShare;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _cash,
        address _share,
        address _peg,
        address _oracle,
        address _boardroom,
        address _fund,
        address _cashPool,
        address _sharePool,
        address _pegPool,
        uint256 _initShare,
        uint256 _startTime
    ) public Epoch(1 hours, _startTime, 0) {
        cash = _cash;
        share = _share;
        peg = _peg;
        oracle = _oracle;
        boardroom = _boardroom;
        fund = _fund;
        cashPool = _cashPool;
        sharePool = _sharePool;
        pegPool = _pegPool;
        initShare = _initShare;

        cashPriceOne = 10**18;
        cashPriceCeiling = uint256(105).mul(cashPriceOne).div(10**2);
        cashPriceFloor = uint256(95).mul(cashPriceOne).div(10**2);
        // inflation at most 100%
        inflationPercentCeil = uint256(100).mul(cashPriceOne).div(10**2);
    }

    /* =================== Modifier =================== */

    modifier checkMigration {
        require(!migrated, 'Treasury: migrated');

        _;
    }

    modifier checkOperator {
        require(
            ISuperNovaAsset(cash).operator() == address(this) &&
            ISuperNovaAsset(share).operator() == address(this) &&
            Operator(boardroom).operator() == address(this),

            //Operator(SharePool).operator() == address(this)&&
            //Operator(PegPool).operator() == address(this)&&
            //Operator(CashPool).operator() == address(this),
            'Treasury: need more permission'
        );

        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // budget
    function getReserve() public view returns (uint256) {
        return accumulatedSeigniorage;
    }

    // oracle
    function getSeigniorageOraclePrice() public view returns (uint256) {
        return _getCashPrice(oracle);
    }

    function _getCashPrice(address oracle_) internal view returns (uint256) {
        try IOracle(oracle_).consult(cash, 1e18) returns (uint256 price) {
            return price.mul(cashPriceOne).div(cashPriceOne);
        } catch {
            revert('Treasury: failed to consult cash price from the oracle');
        }
    }

    /* ========== GOVERNANCE ========== */

    function initialize() public checkOperator {
        require(!initialized, 'Treasury: initialized');

        // burn all of it's balance
        ISuperNovaAsset(cash).burn(IERC20(cash).balanceOf(address(this)));

        // set accumulatedSeigniorage to it's balance
        accumulatedSeigniorage = IERC20(cash).balanceOf(address(this));

        initialized = true;
        emit Initialized(msg.sender, block.number);
    }

    function migrate(address target) public onlyOperator checkOperator {
        require(!migrated, 'Treasury: migrated');

        // cash
        Operator(cash).transferOperator(target);
        Operator(cash).transferOwnership(target);
        IERC20(cash).transfer(target, IERC20(cash).balanceOf(address(this)));

        // share
        Operator(share).transferOperator(target);
        Operator(share).transferOwnership(target);
        IERC20(share).transfer(target, IERC20(share).balanceOf(address(this)));
    
        // peg
        IERC20(peg).transfer(target, IERC20(peg).balanceOf(address(this)));
    
        migrated = true;
        emit Migration(target);
    }

    function setFund(address newFund) public onlyOperator {
        fund = newFund;
        emit ContributionPoolChanged(msg.sender, newFund);
    }

    function setFundAllocationRate(uint256 rate) public onlyOperator {
        fundAllocationRate = rate;
        emit ContributionPoolRateChanged(msg.sender, rate);
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function _updateCashPrice() internal {
        try IOracle(oracle).update()  {} catch {}
    }

    function allocateSeigniorage()
        external
        onlyOneBlock
        checkMigration
        checkStartTime
        checkEpoch
        checkOperator
    {
        //SharePool
        uint256 ShareAmount= IERC20(share).balanceOf(sharePool);
        if (ShareAmount > 0) {
        IERC20(share).safeApprove(sharePool, ShareAmount);
        ISharePool(sharePool).release(ShareAmount);
        emit SharePoolFunded(now, ShareAmount);
        }
  
        //CashPool

        uint256 CashAmount= IERC20(cash).balanceOf(cashPool);
        if (CashAmount > 0) {
        IERC20(cash).safeApprove(cashPool, CashAmount);
        ICashPool(cashPool).release(CashAmount);
        emit CashPoolFunded(now, CashAmount);
        }

        //PegPool
        
        uint256 PegAmount= IERC20(peg).balanceOf(pegPool);
        if (PegAmount > 0) {
        IERC20(peg).safeApprove(pegPool, PegAmount);
        IPegPool(pegPool).release(PegAmount);
        emit PegPoolFunded(now, PegAmount);
        }
        
        //销毁cash
        uint256 burnAmount= IERC20(cash).balanceOf(fund);
        ISuperNovaAsset(cash).burnFrom(fund, burnAmount);
        emit BurnCash(now, burnAmount);

        _updateCashPrice();
        uint256 cashPrice = _getCashPrice(oracle);
        uint256 percentage = cashPriceOne > cashPrice ? cashPriceOne.sub(cashPrice) : cashPrice.sub(cashPriceOne);
        //价格<0.95
        if (cashPrice <= cashPriceFloor) {
            uint256 shareAmount=initShare.mul(10**18).div(10**2);
            ISuperNovaAsset(share).mint(sharePool, shareAmount);
            IRewardPool(sharePool).notifyRewardAmount(shareAmount);
            emit MintSharePool(block.timestamp, shareAmount);

            uint256 pegAmount= IERC20(peg).balanceOf(fund).mul(percentage).div(cashPriceOne);
            IERC20(peg).safeApprove(pegPool, pegAmount);
            ISimpleERCFund(fund).withdraw(
                peg,
                pegAmount,
                pegPool,
                'Treasury: Desposit PegPool'
            );
            emit DespositPegPool(now, pegAmount);

        }

        if (cashPrice <= cashPriceCeiling) {
            return; // just advance epoch instead revert
        }

        // circulating supply
        uint256 cashSupply = IERC20(cash).totalSupply().sub(
            accumulatedSeigniorage
        );

        percentage = Math.min(percentage, inflationPercentCeil);

        uint256 seigniorage = cashSupply.mul(percentage).div(10**18);

        uint256 fundReserve = seigniorage.mul(fundAllocationRate).div(100);

        ISuperNovaAsset(cash).mint(address(this), seigniorage);

        //ISuperNovaAsset(cash).mint(cashPool, fundReserve);

        if (fundReserve > 0) {
            // 当前合约批准fund地址,开发者准备金数额
            IERC20(cash).safeApprove(cashPool, fundReserve);
            // 调用fund合约的存款方法存入开发者准备金
            ISimpleERCFund(cashPool).deposit(
                cash,
                fundReserve,
                'Treasury: Desposit CashPool'
            );
            emit DespositCashPool(now, fundReserve);
        }

        seigniorage = seigniorage.sub(fundReserve);

        // boardroom
        uint256 boardroomReserve = seigniorage;
        if (boardroomReserve > 0) {
            IERC20(cash).safeApprove(boardroom, boardroomReserve);
            IBoardroom(boardroom).allocateSeigniorage(boardroomReserve);
            emit BoardroomFunded(now, boardroomReserve);
        }
    }
    
    // GOV
    event Initialized(address indexed executor, uint256 at);
    event Migration(address indexed target);
    event ContributionPoolChanged(address indexed operator, address newFund);
    event ContributionPoolRateChanged(
        address indexed operator,
        uint256 newRate
    );

    // CORE
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);
    event BurnCash(uint256 timestamp, uint256 seigniorage);
    event MintSharePool(uint256 timestamp, uint256 seigniorage);
    event DespositPegPool(uint256 timestamp, uint256 seigniorage);
    event DespositCashPool(uint256 timestamp, uint256 seigniorage);
    event SharePoolFunded(uint256 timestamp, uint256 seigniorage);
    event CashPoolFunded(uint256 timestamp, uint256 seigniorage);
    event PegPoolFunded(uint256 timestamp, uint256 seigniorage);
}
