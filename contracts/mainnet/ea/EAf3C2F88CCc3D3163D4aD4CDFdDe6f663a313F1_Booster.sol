// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;
import "OwnableUpgradeable.sol";
import "IERC20.sol";
import "SafeERC20.sol";
import "ReentrancyGuardUpgradeable.sol";
import "UUPSUpgradeable.sol";
import "Math.sol";
import "IMasterPlatypus.sol";
import "IPlatypusProxy.sol";
import "IRewardFactory.sol";
import "IRewarder.sol";
import "IRewardPool.sol";
import "IMintable.sol";
import "IEcdPtpRewardPool.sol";
import "IVeEcdRewardsPool.sol";
import "IVirtualBalanceRewardPool.sol";
import "IPool.sol";
import "ILpToken.sol";

/** @title The contract that takes care of LPs.
// @dev The entry contract to deposit LPs from platypus.
// deposits are routed trough the PlatypusProxy contract.
 */

contract Booster is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    struct PoolInfo {
        address pool;
        address token;
        address lpToken;
        address rewardPool;
        bool shutdown;
    }

    struct ExtraRewardsPool {
        address token;
        address virtualBalanceRewardPool;
    }

    mapping(uint256 => PoolInfo) public pools;
    uint256[] public existingPools;
    mapping(uint256 => ExtraRewardsPool) public extraRewardsPools;
    IMasterPlatypus public masterPlatypus;
    IPlatypusProxy public depositorProxy;
    IRewardFactory public rewardFactory;
    IERC20 public ptp;

    uint256 public ecdPtpIncentive;
    uint256 public ecdLockedIncentive;
    uint256 public earmarkIncentive;
    uint256 public platformFee;
    uint256 public constant MAX_FEES = 20_000;
    uint256 public constant FEE_DENOMINATOR = 100_000;
    uint256 public constant SLIPPAGE_DENOMINATOR = 100_000;

    address public feeManager;
    address public treasury;
    address public ecdPtpRewardPool;
    address public veEcdRewardPool;

    uint32 public constant DELAY = 1 days;

    event FeeManagerSet(address feeManager);

    event FeeSet(
        uint256 ecdPtpIncentive,
        uint256 ecdLockedIncentive,
        uint256 callerFees,
        uint256 platform
    );

    event SetVeEcdRewardPool(address veEcdRewardPool);

    event SetEcdPtpRewardPool(address ecdPtpRewardPool);

    event SetTreasury(address treasury);

    event SetRewardFactory(address rewardFactory);

    event ClaimRewards(uint256 total);

    event ShutdownPool(uint256 pid);

    event SetExtraRewardPool(uint256 pid);

    event RemoveExtraRewardPool(uint256 pid);

    event ClearExtraRewardPool(address rewardPool);

    event AddNewPool(uint256 pid);

    event SetMasterPlatypus(address masterPlatypus);

    event IncentivesDistributed(
        uint256 callIncentive,
        uint256 platform,
        uint256 ecdPtpIncentive,
        uint256 ecdLockedIncentive
    );

    event RewardsDistributed(
        uint256 pid,
        uint256 amount,
        uint256 extraRewardAmount
    );

    event TokenRewardsCreated(address tokenRewards, address mainRewards);

    function initialize(
        address _masterPlatypus,
        address _depositorProxy,
        address _ptp
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        masterPlatypus = IMasterPlatypus(_masterPlatypus);
        depositorProxy = IPlatypusProxy(_depositorProxy);
        ptp = IERC20(_ptp);
        ecdPtpIncentive = 0;
        ecdLockedIncentive = 7_975;
        platformFee = 11_975;
        earmarkIncentive = 50;

        feeManager = msg.sender;
    }

    function _authorizeUpgrade(address _nextVersion)
        internal
        override
        onlyOwner
    {}

    /// @notice List of avialable pools
    /// @return pids pids of pools
    function listPools() external view returns (uint256[] memory) {
        return existingPools;
    }

    /// @notice Set fee manager
    /// @param _feeM new fee manager
    function setFeeManager(address _feeM) external {
        require(msg.sender == feeManager, "!auth");
        emit FeeManagerSet(feeManager);
        feeManager = _feeM;
    }

    /// @notice Set fees
    /// Total fees are capped to 20%.
    /// Values are per 100_000.
    /// @dev can only be called by fee manager.
    /// @param _ecdLockedIncentive Amount of incentives to distribute to veECD holders
    /// @param _callerFees Amount of incentives to disitribute to function caller.
    /// @param _platform Amount of incentives to disitribute to the platform.
    function setFees(
        uint256 _ecdPtpIncentive,
        uint256 _ecdLockedIncentive,
        uint256 _callerFees,
        uint256 _platform
    ) external {
        require(msg.sender == feeManager, "!auth");

        uint256 total = _ecdPtpIncentive +
            _ecdLockedIncentive +
            _callerFees +
            _platform;
        require(total <= MAX_FEES, ">MAX_FEES");

        require(
            ((_ecdPtpIncentive >= 3000 && _ecdPtpIncentive <= 15000) ||
                ecdPtpRewardPool == address(0x0)) &&
                _ecdLockedIncentive >= 3000 &&
                _ecdLockedIncentive <= 10000 &&
                _callerFees <= 500 &&
                _platform <= 12000,
            "fees out of bounds"
        );
        ecdPtpIncentive = _ecdPtpIncentive;
        ecdLockedIncentive = _ecdLockedIncentive;
        earmarkIncentive = _callerFees;
        platformFee = _platform;
        emit FeeSet(
            _ecdPtpIncentive,
            _ecdLockedIncentive,
            _callerFees,
            _platform
        );
    }

    /// @notice Set the veEcdReward contract
    /// @param _veEcdRewardPool The VeEcdRewardPool contract address
    function setVeEcdRewardPool(address _veEcdRewardPool) external onlyOwner {
        require(veEcdRewardPool == address(0), "!zero");
        veEcdRewardPool = _veEcdRewardPool;
        emit SetVeEcdRewardPool(_veEcdRewardPool);
    }

    /// @notice Set reward contract
    /// @param _ecdPtpRewardPool Contract that distribute rewards to ecdPTP
    function setEcdPtpRewardPool(address _ecdPtpRewardPool) external onlyOwner {
        require(ecdPtpRewardPool == address(0), "!zero");
        ecdPtpRewardPool = _ecdPtpRewardPool;
        emit SetEcdPtpRewardPool(_ecdPtpRewardPool);
    }

    /// @notice Set treasury address
    /// @param _treasury address of treasury
    function setTreasury(address _treasury) external {
        require(msg.sender == feeManager, "!auth");
        treasury = _treasury;
        emit SetTreasury(treasury);
    }

    /// @notice Set masterplatypus address
    /// @param _masterPlatypus address of the new masterPlatypus
    function setMasterPlatypus(address _masterPlatypus) external onlyOwner {
        masterPlatypus = IMasterPlatypus(_masterPlatypus);
        emit SetMasterPlatypus(_masterPlatypus);
    }

    /// @notice Set reward factory address
    /// @param _rewardFactory address of the RewardFactory
    function setRewardFactory(address _rewardFactory) external onlyOwner {
        rewardFactory = IRewardFactory(_rewardFactory);
        emit SetRewardFactory(_rewardFactory);
    }

    /// @notice Deposit tokens
    /// @dev LPs are transfered from msg.sender
    /// @param _pid Platypus pool id
    /// @param _amount Amount of LP to deposit
    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool depositToPlatypus,
        uint256 deadline
    ) external nonReentrant {
        _depositFor(_pid, _amount, msg.sender, depositToPlatypus, deadline);
    }

    /// @notice Deposit tokens on the behalf of an other user
    /// @dev LPs are transfered from msg.sender
    /// @param _pid Platypus pool id
    /// @param _amount Amount of LP to deposit
    /// @param account Beneficiary
    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address account,
        bool depositToPlatypus,
        uint256 deadline
    ) external nonReentrant {
        _depositFor(_pid, _amount, account, depositToPlatypus, deadline);
    }

    function _depositFor(
        uint256 _pid,
        uint256 _amount,
        address account,
        bool depositToPlatypus,
        uint256 deadline
    ) internal {
        PoolInfo storage poolInfo = pools[_pid];
        require(address(poolInfo.lpToken) != address(0x0), "zero");
        require(poolInfo.shutdown == false, "shutdown");

        if (depositToPlatypus) {
            _amount = _depositToPlatypus(poolInfo, _amount, deadline);
        } else {
            IERC20(poolInfo.lpToken).safeTransferFrom(
                msg.sender,
                address(depositorProxy),
                _amount
            );
        }

        (uint256 ptpClaimed, uint256 extraRewardsClaimed) = depositorProxy
            .deposit(
                address(masterPlatypus),
                _pid,
                address(poolInfo.lpToken),
                _amount
            );

        if (ptpClaimed != 0) {
            IERC20(ptp).safeTransferFrom(
                address(depositorProxy),
                address(this),
                ptpClaimed
            );
        }
        ptpClaimed = _distributeIncentives(ptpClaimed);
        _distributeRewards(_pid, ptpClaimed, extraRewardsClaimed);

        IRewardPool(poolInfo.rewardPool).stake(account, _amount);
    }

    function _depositToPlatypus(
        PoolInfo storage poolInfo,
        uint256 amount,
        uint256 deadline
    ) internal returns (uint256) {
        address pool = poolInfo.pool;
        address token = poolInfo.token;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(pool, amount);

        uint256 minted = IPool(pool).deposit(
            token,
            amount,
            address(depositorProxy),
            deadline
        );
        return minted;
    }

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _claim
    ) external nonReentrant {
        _withdraw(
            _pid,
            _amount,
            _claim,
            true,
            (_amount * 995) / 1000,
            block.timestamp
        );
    }

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _claim,
        uint256 minOut
    ) external nonReentrant {
        _withdraw(_pid, _amount, _claim, true, minOut, block.timestamp);
    }

    /// @notice Withdraw LPs from platypus to the user
    /// @param _pid Platypus pool id
    /// @param _amount Amount of LP to deposit
    /// @param _claim claim benefits with the call
    function withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _claim,
        bool unwrap,
        uint256 minOut,
        uint256 deadline
    ) external nonReentrant {
        _withdraw(_pid, _amount, _claim, unwrap, minOut, deadline);
    }

    function withdrawAll(
        uint256 _pid,
        bool _claim,
        bool unwrap,
        uint256 slippage
    ) external nonReentrant {
        uint256 balance = IRewardPool(pools[_pid].rewardPool).balanceOf(
            msg.sender
        );
        _withdraw(
            _pid,
            balance,
            _claim,
            unwrap,
            (balance * slippage) / SLIPPAGE_DENOMINATOR,
            block.timestamp
        );
    }

    function _withdraw(
        uint256 _pid,
        uint256 _amount,
        bool _claim,
        bool _withdrawFromPlatypus,
        uint256 _minAmount,
        uint256 _deadline
    ) internal {
        PoolInfo storage pool = pools[_pid];
        require(address(pool.lpToken) != address(0x0), "zero");

        IRewardPool(pool.rewardPool).unStake(msg.sender, _amount, _claim);

        if (pool.shutdown) {
            if (_withdrawFromPlatypus) {
                _unwrap(
                    msg.sender,
                    pool.pool,
                    pool.lpToken,
                    pool.token,
                    _amount,
                    _minAmount,
                    _deadline
                );
            } else {
                IERC20(pool.lpToken).safeTransfer(msg.sender, _amount);
            }

            return;
        }

        (uint256 ptpClaimed, uint256 extraRewardsClaimed) = depositorProxy
            .withdraw(address(masterPlatypus), _pid, _amount);

        if (_withdrawFromPlatypus) {
            _unwrap(
                msg.sender,
                pool.pool,
                pool.lpToken,
                pool.token,
                _amount,
                _minAmount,
                _deadline
            );
        } else {
            IERC20(pool.lpToken).safeTransferFrom(
                address(depositorProxy),
                msg.sender,
                _amount
            );
        }
        if (ptpClaimed != 0) {
            IERC20(ptp).safeTransferFrom(
                address(depositorProxy),
                address(this),
                ptpClaimed
            );
        }
        ptpClaimed = _distributeIncentives(ptpClaimed);

        _distributeRewards(_pid, ptpClaimed, extraRewardsClaimed);
    }

    function _unwrap(
        address to,
        address pool,
        address lpToken,
        address token,
        uint256 amount,
        uint256 minAmount,
        uint256 deadline
    ) internal {
        IERC20(lpToken).safeTransferFrom(
            address(depositorProxy),
            address(this),
            amount
        );
        IERC20(lpToken).approve(pool, amount);
        IPool(pool).withdraw(token, amount, minAmount, to, deadline);
    }

    /// @notice claimRewards on multiple pools at once
    /// This function claim rewards for the system. Rewards are then sent to multiple reward pools.
    /// @param _pids pool ids
    function claimRewards(uint256[] calldata _pids) external nonReentrant {
        (
            uint256 totalClaimed,
            uint256[] memory claimedPerPool,
            uint256[] memory extraRewardsClaimed
        ) = depositorProxy.getRewards(address(masterPlatypus), _pids);
        emit ClaimRewards(totalClaimed);

        if (totalClaimed != 0) {
            IERC20(ptp).safeTransferFrom(
                address(depositorProxy),
                address(this),
                totalClaimed
            );

            uint256 amountAfterFees = _distributeIncentives(totalClaimed);

            for (uint256 i = 0; i < _pids.length; i++) {
                _distributeRewards(
                    _pids[i],
                    (claimedPerPool[i] * amountAfterFees) / totalClaimed,
                    extraRewardsClaimed[i]
                );
            }
        }
    }

    function _distributeIncentives(uint256 amount) private returns (uint256) {
        if (amount == 0) return (0);

        uint256 _ecdPtpIncentive = (amount * ecdPtpIncentive) / FEE_DENOMINATOR;
        uint256 _ecdLockedIncentive = (amount * ecdLockedIncentive) /
            FEE_DENOMINATOR;
        uint256 _callIncentive = (amount * earmarkIncentive) / FEE_DENOMINATOR;
        uint256 _platform = 0;
        if (
            treasury != address(0) &&
            treasury != address(this) &&
            platformFee > 0
        ) {
            _platform = (amount * platformFee) / FEE_DENOMINATOR;
            amount = amount - _platform;
            IERC20(ptp).safeTransfer(treasury, _platform);
        }

        IERC20(ptp).safeTransfer(msg.sender, _callIncentive);

        //send stakers's share of ptp to reward contract

        if (_ecdPtpIncentive != 0) {
            ptp.approve(ecdPtpRewardPool, _ecdPtpIncentive);
            IEcdPtpRewardPool(ecdPtpRewardPool).queueNewRewards(
                _ecdPtpIncentive
            );
        }
        if (_ecdLockedIncentive != 0) {
            ptp.approve(veEcdRewardPool, _ecdLockedIncentive);
            IVeEcdRewardsPool(veEcdRewardPool).queueNewRewards(
                _ecdLockedIncentive
            );
        }
        emit IncentivesDistributed(
            _callIncentive,
            _platform,
            _ecdPtpIncentive,
            _ecdLockedIncentive
        );

        return amount - _ecdPtpIncentive - _ecdLockedIncentive - _callIncentive;
    }

    function _distributeRewards(
        uint256 _pid,
        uint256 amount,
        uint256 extraRewardAmount
    ) internal {
        if (amount != 0) {
            address rewardPool = pools[_pid].rewardPool;
            ptp.approve(rewardPool, amount);

            IRewardPool(rewardPool).queueNewRewards(amount);
        }

        if (
            extraRewardAmount != 0 &&
            extraRewardsPools[_pid].virtualBalanceRewardPool != address(0x0)
        ) {
            IERC20(extraRewardsPools[_pid].token).safeTransferFrom(
                address(depositorProxy),
                address(this),
                extraRewardAmount
            );

            IERC20(extraRewardsPools[_pid].token).approve(
                extraRewardsPools[_pid].virtualBalanceRewardPool,
                extraRewardAmount
            );

            IVirtualBalanceRewardPool(
                extraRewardsPools[_pid].virtualBalanceRewardPool
            ).queueNewRewards(extraRewardAmount);
        }
        emit RewardsDistributed(_pid, amount, extraRewardAmount);
    }

    /// @notice Increase allowance of booster on PlatypusProxy
    /// @dev only owner
    /// @param token Token to increase allowance
    function setAllowance(address token) external onlyOwner {
        depositorProxy.increaseAllowance(token);
    }

    /// @notice Add a new pool into the sytem
    /// @dev Pool can't be added twice.
    /// Only owner
    /// @param _pid Platypus pool id.
    function addNewPool(uint256 _pid) external onlyOwner {
        require(address(pools[_pid].lpToken) == address(0x0), "zero");
        IMasterPlatypus.PoolInfo memory poolInfo = masterPlatypus.poolInfo(
            _pid
        );

        address pool = ILpToken(poolInfo.lpToken).pool();
        address underlyingToken = ILpToken(poolInfo.lpToken).underlyingToken();

        address newRewardPool = rewardFactory.createPtpRewards(_pid);

        pools[_pid] = PoolInfo({
            lpToken: poolInfo.lpToken,
            rewardPool: newRewardPool,
            pool: pool,
            token: underlyingToken,
            shutdown: false
        });
        existingPools.push(_pid);
        depositorProxy.increaseAllowance(poolInfo.lpToken);

        if (poolInfo.rewarder != address(0x0)) {
            _addExtraRewards(_pid, poolInfo.rewarder);
        }
        emit AddNewPool(_pid);
    }

    /// @notice Shutdown a pool, funds are transfered from platypus to Booster for user to withdraw.
    /// @dev only owner
    /// @param _pid Platypus pool id.
    /// @param distributeRewards Distribute earner rewards.
    function shutdownPool(uint256 _pid, bool distributeRewards)
        external
        onlyOwner
        returns (bool)
    {
        PoolInfo storage pool = pools[_pid];
        address rewardContract = pool.rewardPool;
        uint256 balanceBefore = IERC20(pool.lpToken).balanceOf(address(this));

        uint256 _amount = masterPlatypus
            .userInfo(_pid, address(depositorProxy))
            .amount;

        (uint256 ptpClaimed, uint256 extraRewardsClaimed) = depositorProxy
            .withdraw(address(masterPlatypus), _pid, _amount);

        IERC20(pools[_pid].lpToken).safeTransferFrom(
            address(depositorProxy),
            address(this),
            _amount
        );

        uint256 balanceAfter = IERC20(pool.lpToken).balanceOf(address(this));
        require(
            balanceAfter >=
                (IRewardPool(rewardContract).totalSupply() + balanceBefore),
            "balance didn't increase enough"
        );

        if (distributeRewards) {
            if (ptpClaimed != 0) {
                IERC20(ptp).safeTransferFrom(
                    address(depositorProxy),
                    address(this),
                    ptpClaimed
                );
            }

            ptpClaimed = _distributeIncentives(ptpClaimed);
            _distributeRewards(_pid, ptpClaimed, extraRewardsClaimed);
        }
        pool.shutdown = true;
        emit ShutdownPool(_pid);
        return true;
    }

    /// @notice Add extra reward to a pool
    /// @dev in case rewards started on a pool but not yet setup or if changes.
    /// @param _pid Platypus pool id.
    /// @param amount Send an amount of extra rewards to the extra reward pool.
    function setExtraRewardPool(uint256 _pid, uint256 amount)
        external
        onlyOwner
    {
        IMasterPlatypus.PoolInfo memory poolInfo = masterPlatypus.poolInfo(
            _pid
        );

        require(poolInfo.rewarder != address(0x0), "zero");
        _addExtraRewards(_pid, poolInfo.rewarder);

        if (amount > 0) {
            IERC20 t = IERC20(extraRewardsPools[_pid].token);
            amount = Math.min(amount, t.balanceOf(address(depositorProxy)));

            t.safeTransferFrom(address(depositorProxy), address(this), amount);

            t.approve(extraRewardsPools[_pid].virtualBalanceRewardPool, amount);

            IVirtualBalanceRewardPool(
                extraRewardsPools[_pid].virtualBalanceRewardPool
            ).queueNewRewards(amount);
        }
        emit SetExtraRewardPool(_pid);
    }

    /// @notice Remove extra reward pool when removed from platypus.
    /// @dev onlyOwner
    /// @param _pid Platypus pool id.
    function removeExtraRewardPool(uint256 _pid) external onlyOwner {
        delete extraRewardsPools[_pid];
        emit RemoveExtraRewardPool(_pid);
    }

    /// @notice Clear extra rewardPool on a RewardPool
    /// @dev onlyOwner
    /// @param rewardPool the reward pool address.
    function clearExtraRewards(address rewardPool) external onlyOwner {
        rewardFactory.clearExtraRewards(rewardPool);
        emit ClearExtraRewardPool(rewardPool);
    }

    function _addExtraRewards(uint256 _pid, address rewarder) internal {
        address rewardToken = IRewarder(rewarder).rewardToken();
        address additionalRewards = rewardFactory.createTokenRewards(
            rewardToken,
            pools[_pid].rewardPool
        );
        extraRewardsPools[_pid] = ExtraRewardsPool({
            token: rewardToken,
            virtualBalanceRewardPool: additionalRewards
        });
        depositorProxy.increaseAllowance(rewardToken);
    }

    /// @notice Add an extra reward pool to an existing rewardPool
    /// @dev onlyOwner
    /// @param _tokenRewards token to be distributed.
    /// @param _mainRewards the rewardPool that recive aditional rewards
    function createTokenRewards(address _tokenRewards, address _mainRewards)
        external
        onlyOwner
        returns (address)
    {
        address addr = rewardFactory.createTokenRewards(
            _tokenRewards,
            _mainRewards
        );
        emit TokenRewardsCreated(_tokenRewards, _mainRewards);
        return addr;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "ContextUpgradeable.sol";
import "Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "IERC20.sol";
import "Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "draft-IERC1822.sol";
import "ERC1967Upgrade.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate that the this implementation remains valid after an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "IBeacon.sol";
import "draft-IERC1822.sol";
import "Address.sol";
import "StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

/**
 * @dev Interface of the MasterPlatypus
 */
interface IMasterPlatypus {
    struct PoolInfo {
        address lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. PTPs to distribute per second.
        uint256 lastRewardTimestamp; // Last timestamp that PTPs distribution occurs.
        uint256 accPtpPerShare; // Accumulated PTPs per share, times 1e12.
        address rewarder;
        uint256 sumOfFactors; // the sum of all non dialuting factors by all of the users in the pool
        uint256 accPtpPerFactorShare; // accumulated ptp per factor share
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 factor;
    }

    function poolInfo(uint256) external returns (PoolInfo memory);

    function userInfo(uint256, address) external returns (UserInfo memory);

    function poolLength() external view returns (uint256);

    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 pendingPtp,
            address bonusTokenAddress,
            string memory bonusTokenSymbol,
            uint256 pendingBonusToken
        );

    function rewarderBonusTokenInfo(uint256 _pid)
        external
        view
        returns (address bonusTokenAddress, string memory bonusTokenSymbol);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external;

    function deposit(uint256 _pid, uint256 _amount)
        external
        returns (uint256, uint256);

    function multiClaim(uint256[] memory _pids)
        external
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        );

    function withdraw(uint256 _pid, uint256 _amount)
        external
        returns (uint256, uint256);

    function emergencyWithdraw(uint256 _pid) external;

    function migrate(uint256[] calldata _pids) external;

    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) external;

    function updateFactor(address _user, uint256 _newVePtpBalance) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.12;

interface IPlatypusProxy {
    function deposit(
        address masterplatypus,
        uint256 _pid,
        address token,
        uint256 amount
    ) external returns (uint256, uint256);

    function withdraw(
        address masterplatypus,
        uint256 _pid,
        uint256 amount
    ) external returns (uint256, uint256);

    function getRewards(address masterplatypus, uint256[] memory _pids)
        external
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        );

    function lockPtp(uint256 amount) external;

    function release() external;

    function increaseAllowance(address token) external;

    function claimVePtp() external;

    function donatePtp(uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IRewardFactory {
    function createPtpRewards(uint256) external returns (address);

    function createTokenRewards(address, address) external returns (address);

    function clearExtraRewards(address rewardContract) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IRewarder {
    function onPtpReward(address user, uint256 newLpAmount)
        external
        returns (uint256);

    function pendingTokens(address user)
        external
        view
        returns (uint256 pending);

    function rewardToken() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IRewardPool {
    function balanceOf(address _account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function getReward() external returns (bool);

    function stake(address _account, uint256 _amount) external returns (bool);

    function unStake(
        address _account,
        uint256 _amount,
        bool _claim
    ) external returns (bool);

    function queueNewRewards(uint256 _rewards) external returns (bool);

    function addExtraReward(address _reward) external returns (bool);

    function initialize(
        uint256 pid_,
        address rewardToken_,
        address operator_,
        address rewardManager_,
        address governance_
    ) external;

    function clearExtraRewards() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IMintable {
    function mint(address, uint256) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IEcdPtpRewardPool {
    function balanceOf(address _account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function withdraw(uint256 _amount, bool _claim) external returns (bool);

    function getReward() external returns (bool);

    function stake(uint256 _amount) external returns (bool);

    function stakeFor(address _account, uint256 _amount)
        external
        returns (bool);

    function queueNewRewards(uint256 _rewards) external returns (bool);

    function addExtraReward(address _reward) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IVeEcdRewardsPool {
    function queueNewRewards(uint256 _rewards) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "IERC20.sol";

interface IVirtualBalanceRewardPool {
    function stake(address, uint256) external returns (bool);

    function withdraw(address, uint256) external returns (bool);

    function getReward(address) external returns (bool);

    function queueNewRewards(uint256) external returns (bool);

    function rewardToken() external view returns (IERC20);

    function earned(address account) external view returns (uint256);

    function initialize(
        address deposit_,
        address reward_,
        address owner
    ) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.12;

interface IPool {
    function assetOf(address token) external view returns (address);

    function deposit(
        address token,
        uint256 amount,
        address to,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function withdraw(
        address token,
        uint256 liquidity,
        uint256 minimumAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);

    function withdrawFromOtherAsset(
        address initialToken,
        address wantedToken,
        uint256 liquidity,
        uint256 minimumAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);

    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 actualToAmount, uint256 haircut);

    function quotePotentialSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) external view returns (uint256 potentialOutcome, uint256 haircut);

    function quotePotentialWithdraw(address token, uint256 liquidity)
        external
        view
        returns (
            uint256 amount,
            uint256 fee,
            bool enoughCash
        );

    function quotePotentialWithdrawFromOtherAsset(
        address initialToken,
        address wantedToken,
        uint256 liquidity
    ) external view returns (uint256 amount, uint256 fee);

    function quoteMaxInitialAssetWithdrawable(
        address initialToken,
        address wantedToken
    ) external view returns (uint256 maxInitialAssetAmount);

    function getTokenAddresses() external view returns (address[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface ILpToken {
    function pool() external view returns (address);

    function underlyingToken() external view returns (address);
}