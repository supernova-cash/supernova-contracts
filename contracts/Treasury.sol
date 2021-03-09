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
import './owner/AdminRole.sol';
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

    // ========== CORE
    address public fund;
    address public cash;
    address public share;
    address public peg;
    address public shareboardroom;
    address public lpboardroom;
    address public sharePool;
    address public cashPool;
    address public pegPool;

    address public oracle;

    // ========== PARAMS
    uint256 public cashPriceOne;
    uint256 public cashPriceCeiling;
    uint256 public cashPriceFloor;
    uint256 public fundAllocationRate = 5; 
    uint256 public inflationPercentCeil;
    uint256 public initShare;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _cash,
        address _share,
        address _peg,
        address _oracle,
        address _shareboardroom,
        address _lpboardroom,
        address _fund,
        address _cashPool,
        address _sharePool,
        address _pegPool,
        uint256 _initShare,
        uint256 _startTime
    ) public Epoch(1 days, _startTime, 0) {
        cash = _cash;
        share = _share;
        peg = _peg;
        oracle = _oracle;
        shareboardroom = _shareboardroom;
        lpboardroom = _lpboardroom;
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

    modifier checkAdmin {
        require(
            AdminRole(cash).isAdmin(address(this)) &&
            AdminRole(share).isAdmin(address(this)) &&
            AdminRole(shareboardroom).isAdmin(address(this)) &&
            AdminRole(lpboardroom).isAdmin(address(this)),

            //AdminRole(SharePool).isAdmin(address(this)) == address(this)&&
            //AdminRole(PegPool).isAdmin(address(this)) == address(this)&&
            //AdminRole(CashPool).isAdmin(address(this)) == address(this),
            'Treasury: need more permission'
        );

        _;
    }

    /* ========== VIEW FUNCTIONS ========== */

    // budget
    function getReserve() public view returns (uint256) {
        return 0;
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

    function migrate(address target) public onlyAdmin checkAdmin {
        require(!migrated, 'Treasury: migrated');

        // cash
        AdminRole(cash).addAdmin(target);
        AdminRole(cash).renounceAdmin();
        IERC20(cash).transfer(target, IERC20(cash).balanceOf(address(this)));

        // share
        AdminRole(share).addAdmin(target);
        AdminRole(share).renounceAdmin();
        IERC20(share).transfer(target, IERC20(share).balanceOf(address(this)));
    
        // peg
        IERC20(peg).transfer(target, IERC20(peg).balanceOf(address(this)));
    
        migrated = true;
        emit Migration(target);
    }

    function setFund(address newFund) public onlyAdmin {
        fund = newFund;
        emit ContributionPoolChanged(msg.sender, newFund);
    }

    function setFundAllocationRate(uint256 rate) public onlyAdmin {
        fundAllocationRate = rate;
        emit ContributionPoolRateChanged(msg.sender, rate);
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function _updateCashPrice() internal {
        try IOracle(oracle).update()  {} catch {}
    }

    function allocateSeigniorage() //每个周期执行一次
        external
        onlyOneBlock
        checkMigration
        checkStartTime
        checkEpoch
        checkAdmin
    {
        //fund里面的cash全部销毁
        uint256 burnAmount= IERC20(cash).balanceOf(fund);
        ISuperNovaAsset(cash).burnFrom(fund, burnAmount);
        emit BurnCash(now, burnAmount);

        _updateCashPrice();
        uint256 cashPrice = _getCashPrice(oracle);
        uint256 percentage = cashPriceOne > cashPrice ? cashPriceOne.sub(cashPrice) : cashPrice.sub(cashPriceOne);
        //当价格<0.95时 
        if (cashPrice <= cashPriceFloor) {
            // 增发share 让用户用cash买share
            uint256 shareAmount = initShare.div(10**2);
            ISuperNovaAsset(share).mint(sharePool, shareAmount);
            emit MintSharePool(block.timestamp, shareAmount);

            // 从fund里拿出peg 回收cash
            uint256 pegAmount= IERC20(peg).balanceOf(fund).mul(percentage).div(cashPriceOne);
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
        uint256 cashSupply = IERC20(cash).totalSupply();

        percentage = Math.min(percentage, inflationPercentCeil);

        uint256 seigniorage = cashSupply.mul(percentage).div(10**18);

        uint256 fundReserve = seigniorage.mul(fundAllocationRate).div(100);

        ISuperNovaAsset(cash).mint(address(this), seigniorage);

        if (fundReserve > 0) {
            IERC20(cash).safeTransfer(cashPool, fundReserve);
            emit DespositCashPool(now, fundReserve);
        }
    
        // boardroom
        uint256 boardroomReserve = seigniorage.sub(fundReserve);
        if (boardroomReserve > 0) {
            // share董事会分到10%
            uint256 shareBoardroomReserve = boardroomReserve.div(10);
            // lp董事会分到90%
            uint256 lpBoardroomReserve = boardroomReserve.sub(shareBoardroomReserve);
            // 批准国库合约储备量数额
            IERC20(cash).safeApprove(shareboardroom, shareBoardroomReserve);
            //调用Boardroom合约的allocateSeigniorage方法,将CASH存入董事会
            IBoardroom(shareboardroom).allocateSeigniorage(shareBoardroomReserve);

            // 批准国库合约储备量数额
            IERC20(cash).safeApprove(lpboardroom, lpBoardroomReserve);
            //调用Boardroom合约的allocateSeigniorage方法,将CASH存入董事会
            IBoardroom(lpboardroom).allocateSeigniorage(lpBoardroomReserve);
            //触发已发放资金至董事会事件
            emit BoardroomFunded(now, boardroomReserve);
        }
    }
    
    // GOV
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
