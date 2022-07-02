// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../ERC20/interfaces/IERC20ExtendedUpgradeable.sol";

// MasterInvestor is the master investor of whatever investments are available.
contract MasterInvestor is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20ExtendedUpgradeable;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardDebtAtTime; // the last time a user staked.
        uint256 lastWithdrawTime; // the last time a user withdrew.
        uint256 firstDepositTime; // the last time a user deposited.
        uint256 timeDelta; // time passed since withdrawals
        uint256 lastDepositTime;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20ExtendedUpgradeable lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. EVO to distribute per second.
        uint256 lastRewardTime; // Last time that EVO distribution occurs.
        uint256 accGovTokenPerShare; // Accumulated EVO per share, times 1e12. See below.
    }

    // Fixes stack too deep
    struct ConstructorParams {
        IERC20ExtendedUpgradeable govToken;
        IERC20ExtendedUpgradeable rewardToken;
        uint256 rewardPerSecond;
        uint256 startTime;
        uint256 halvingAfterTime;
        uint256 userDepositFee;
        uint256 devDepositFee;
        address devFundAddress;
        address feeShareFundAddress;
        address marketingFundAddress;
        address foundersFundAddress;
        uint256[] rewardMultipliers;
        uint256[] userFeeStages;
        uint256[] devFeeStages;
        uint256[] percentLockBonusReward;
    }

    // The EVO token
    IERC20ExtendedUpgradeable public GOV_TOKEN;
    IERC20ExtendedUpgradeable public REWARD_TOKEN;
    // Dev address.
    address public DEV_FUND_ADDRESS;
    // LP address
    address public FEE_SHARE_FUND_ADDRESS;
    // Community Fund Address
    address public MARKETING_FUND_ADDRESS;
    // Founder Reward
    address public FOUNDERS_FUND_ADDRESS;
    // EVO created per second.
    uint256 public REWARD_PER_SECOND;
    // Bonus multiplier for early EVO makers.
    uint256[] public REWARD_MULTIPLIERS; // init in constructor function
    uint256[] public HALVING_AT_TIMES; // init in constructor function
    uint256[] public USER_FEE_STAGES;
    uint256[] public DEV_FEE_STAGES;
    uint256 public FINISH_BONUS_AT_TIME;
    uint256 public USER_DEP_FEE;
    uint256 public DEV_DEP_FEE;

    // The time when EVO mining starts.
    uint256 public START_TIME;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public TOTAL_ALLOCATION_POINTS;

    uint256[] public PERCENT_LOCK_BONUS_REWARD;
    uint256 public PERCENT_FOR_DEV;
    uint256 public PERCENT_FOR_FEE_SHARE;
    uint256 public PERCENT_FOR_MARKETING;
    uint256 public PERCENT_FOR_FOUNDERS;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    mapping(address => uint256) public poolId;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(IERC20ExtendedUpgradeable => bool) public poolExistence;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SendGovernanceTokenReward(address indexed user, uint256 indexed pid, uint256 amount, uint256 lockAmount);

    modifier nonDuplicated(IERC20ExtendedUpgradeable _lpToken) {
        require(poolExistence[_lpToken] == false, "MasterInvestor::nonDuplicated: duplicated");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(ConstructorParams memory params) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
        _grantRole(CONTRACT_ROLE, _msgSender());

        USER_FEE_STAGES = params.userFeeStages;
        DEV_FEE_STAGES = params.devFeeStages;
        GOV_TOKEN = params.govToken;
        REWARD_TOKEN = params.rewardToken;
        REWARD_PER_SECOND = params.rewardPerSecond;
        START_TIME = params.startTime;
        USER_DEP_FEE = params.userDepositFee;
        DEV_DEP_FEE = params.devDepositFee;
        REWARD_MULTIPLIERS = params.rewardMultipliers;
        DEV_FUND_ADDRESS = params.devFundAddress;
        FEE_SHARE_FUND_ADDRESS = params.feeShareFundAddress;
        MARKETING_FUND_ADDRESS = params.marketingFundAddress;
        FOUNDERS_FUND_ADDRESS = params.foundersFundAddress;
        PERCENT_LOCK_BONUS_REWARD = params.percentLockBonusReward;
        TOTAL_ALLOCATION_POINTS = 0;
        for (uint256 i = 0; i < REWARD_MULTIPLIERS.length - 1; i++) {
            uint256 halvingAtTime = (params.halvingAfterTime * (i+1)) + params.startTime + 1;
            HALVING_AT_TIMES.push(halvingAtTime);
        }
        FINISH_BONUS_AT_TIME = (params.halvingAfterTime * (REWARD_MULTIPLIERS.length - 1)) + params.startTime;
        HALVING_AT_TIMES.push(2**256 - 1);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20ExtendedUpgradeable _lpToken, bool _withUpdate) public onlyRole(ADMIN_ROLE) nonDuplicated(_lpToken) {
        require(poolId[address(_lpToken)] == 0, "MasterInvestor::add: lp is already in pool");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = (block.timestamp > START_TIME) ? block.timestamp : START_TIME;
        TOTAL_ALLOCATION_POINTS += _allocPoint;
        poolId[address(_lpToken)] = (poolInfo.length + 1);
        poolExistence[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardTime: lastRewardTime,
                accGovTokenPerShare: 0
            })
        );
    }

    // Update the given pool's EVO allocation points.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyRole(ADMIN_ROLE) {
        if (_withUpdate) {
            massUpdatePools();
        }
        TOTAL_ALLOCATION_POINTS = TOTAL_ALLOCATION_POINTS - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 GovTokenForDev;
        uint256 GovTokenForFarmer;
        uint256 GovTokenForLP;
        uint256 GovTokenForCom;
        uint256 GovTokenForFounders;
        (
        GovTokenForDev,
        GovTokenForFarmer,
        GovTokenForLP,
        GovTokenForCom,
        GovTokenForFounders
        ) = getPoolReward(pool.lastRewardTime, block.timestamp, pool.allocPoint);
        // Mint some new EVO tokens for the farmer and store them in MasterInvestor.
        GOV_TOKEN.mint(address(this), GovTokenForFarmer);
        pool.accGovTokenPerShare += (GovTokenForFarmer * 1e12) / lpSupply;
        pool.lastRewardTime = block.timestamp;

        if (GovTokenForDev > 0) {
            uint256 cEVOForDev = (block.timestamp <= FINISH_BONUS_AT_TIME)
            ? ((GovTokenForDev * 75) / 100)
            : 0;
            uint256 govTokenForDev = block.timestamp <= FINISH_BONUS_AT_TIME
            ? ((GovTokenForDev * 25) / 100)
            : GovTokenForDev;
            GOV_TOKEN.mint(address(DEV_FUND_ADDRESS), govTokenForDev);
            if (cEVOForDev > 0) {
                REWARD_TOKEN.mint(address(DEV_FUND_ADDRESS), cEVOForDev);
            }
        }
        if (GovTokenForLP > 0) {
            uint256 cEVOForLP = (block.timestamp <= FINISH_BONUS_AT_TIME)
            ? ((GovTokenForLP * 45) / 100)
            : 0;
            uint256 govTokenForLP = block.timestamp <= FINISH_BONUS_AT_TIME
            ? ((GovTokenForLP * 55) / 100)
            : GovTokenForLP;
            GOV_TOKEN.mint(address(FEE_SHARE_FUND_ADDRESS), govTokenForLP);
            if (cEVOForLP > 0) {
                REWARD_TOKEN.mint(address(FEE_SHARE_FUND_ADDRESS), cEVOForLP);
            }
        }
        if (GovTokenForCom > 0) {
            uint256 cEVOForCom = (block.timestamp <= FINISH_BONUS_AT_TIME)
            ? ((GovTokenForCom * 85) / 100)
            : 0;
            uint256 govTokenForCom = block.timestamp <= FINISH_BONUS_AT_TIME
            ? ((GovTokenForCom * 15) / 100)
            : GovTokenForCom;
            GOV_TOKEN.mint(address(MARKETING_FUND_ADDRESS), govTokenForCom);
            if (cEVOForCom > 0) {
                REWARD_TOKEN.mint(address(MARKETING_FUND_ADDRESS), cEVOForCom);
            }
        }
        if (GovTokenForFounders > 0) {
            uint256 cEVOForFounders = (block.timestamp <= FINISH_BONUS_AT_TIME)
            ? ((GovTokenForFounders * 95) / 100)
            : 0;
            uint256 govTokenForFounders = block.timestamp <= FINISH_BONUS_AT_TIME
            ? ((GovTokenForFounders * 5) / 100)
            : GovTokenForFounders;
            GOV_TOKEN.mint(address(FOUNDERS_FUND_ADDRESS), govTokenForFounders);
            if (cEVOForFounders > 0) {
                REWARD_TOKEN.mint(address(FOUNDERS_FUND_ADDRESS), cEVOForFounders);
            }
        }
    }

    // |--------------------------------------|
    // [20, 30, 40, 50, 60, 70, 80, 99999999]
    // Return reward multiplier over the given _from to _to time.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 result = 0;
        if (_from < START_TIME) return 0;

        for (uint256 i = 0; i < HALVING_AT_TIMES.length; i++) {
            uint256 endTime = HALVING_AT_TIMES[i];
            if (i > REWARD_MULTIPLIERS.length - 1) return 0;

            if (_to <= endTime) {
                uint256 m = ((_to - _from) * REWARD_MULTIPLIERS[i]);
                return result + m;
            }

            if (_from < endTime) {
                uint256 m = ((endTime - _from) * REWARD_MULTIPLIERS[i]);
                _from = endTime;
                result += m;
            }
        }

        return result;
    }

    function getLockPercentage(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 result = 0;
        if (_from < START_TIME) return 100;

        for (uint256 i = 0; i < HALVING_AT_TIMES.length; i++) {
            uint256 endTime = HALVING_AT_TIMES[i];
            if (i > PERCENT_LOCK_BONUS_REWARD.length - 1) return 0;

            if (_to <= endTime) {
                return PERCENT_LOCK_BONUS_REWARD[i];
            }
        }

        return result;
    }

    function getPoolReward(uint256 _from, uint256 _to, uint256 _allocPoint) public view
    returns (uint256 forDev, uint256 forFarmer, uint256 forLP, uint256 forCom, uint256 forFounders) {
        uint256 multiplier = getMultiplier(_from, _to);
        uint256 amount = (((multiplier * REWARD_PER_SECOND) * _allocPoint) / TOTAL_ALLOCATION_POINTS);
        uint256 GovernanceTokenCanMint = GOV_TOKEN.cap() - GOV_TOKEN.totalSupply();

        if (GovernanceTokenCanMint < amount) {
            // If there aren't enough governance tokens left to mint before the cap,
            // just give all of the possible tokens left to the farmer.
            forDev = 0;
            forFarmer = GovernanceTokenCanMint;
            forLP = 0;
            forCom = 0;
            forFounders = 0;
        } else {
            // Otherwise, give the farmer their full amount and also give some
            // extra to the dev, LP, com, and founders wallets.
            forDev = ((amount * PERCENT_FOR_DEV) / 100);
            forFarmer = amount;
            forLP = ((amount * PERCENT_FOR_FEE_SHARE) / 100);
            forCom = ((amount * PERCENT_FOR_MARKETING) / 100);
            forFounders = ((amount * PERCENT_FOR_FOUNDERS) / 100);
        }
    }

    // View function to see pending EVO on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accGovTokenPerShare = pool.accGovTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply > 0) {
            uint256 GovTokenForFarmer;
            (, GovTokenForFarmer, , , ) = getPoolReward(pool.lastRewardTime, block.timestamp, pool.allocPoint);
            accGovTokenPerShare += (GovTokenForFarmer * 1e12) / lpSupply;
        }
        return ((user.amount * accGovTokenPerShare) / 1e12) - user.rewardDebt;
    }

    function claimRewards(uint256[] memory _pids) public {
        for (uint256 i = 0; i < _pids.length; i++) {
            claimReward(_pids[i]);
        }
    }

    function claimReward(uint256 _pid) public {
        updatePool(_pid);
        _harvest(_pid);
    }

    // lock a % of reward if it comes from bonus time.
    function _harvest(uint256 _pid) internal {
        _harvestFor(_pid, _msgSender());
    }

    // lock a % of reward if it comes from bonus time.
    function _harvestFor(uint256 _pid, address _address) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_address];

        // Only harvest if the user amount is greater than 0.
        if (user.amount > 0) {
            // Calculate the pending reward. This is the user's amount of LP tokens multiplied by
            // the accGovTokenPerShare of the pool, minus the user's rewardDebt.
            uint256 pending = ((user.amount * pool.accGovTokenPerShare) / 1e12) - user.rewardDebt;

            // Make sure we aren't giving more tokens than we have in the MasterInvestor contract.
            uint256 masterBal = GOV_TOKEN.balanceOf(address(this));

            if (pending > masterBal) {
                pending = masterBal;
            }

            if (pending > 0) {


                uint256 lockAmount = 0;
                if (user.rewardDebtAtTime <= FINISH_BONUS_AT_TIME) {
                    uint256 lockPercentage = getLockPercentage(block.timestamp - 1, block.timestamp);
                    lockAmount = ((pending * lockPercentage) / 100);

                }
                GOV_TOKEN.transfer(_address, pending - lockAmount);
                if (lockAmount > 0) {
                    REWARD_TOKEN.mint(_address, lockAmount);
                }
                // Reset the rewardDebtAtTime to the current time for the user.
                user.rewardDebtAtTime = block.timestamp;

                emit SendGovernanceTokenReward(_address, _pid, pending, lockAmount);
            }
            // Recalculate the rewardDebt for the user.
            user.rewardDebt = (user.amount * pool.accGovTokenPerShare) / 1e12;
        }
    }

    // Deposit LP tokens to MasterInvestor for EVO allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_amount > 0, "MasterInvestor::deposit: amount must be greater than 0");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        UserInfo storage devr = userInfo[_pid][DEV_FUND_ADDRESS];

        // When a user deposits, we need to update the pool and harvest beforehand,
        // since the rates will change.
        updatePool(_pid);
        _harvest(_pid);
        pool.lpToken.safeTransferFrom(_msgSender(), address(this), _amount);
        if (user.amount == 0) {
            user.rewardDebtAtTime = block.timestamp;
        }
        user.amount += _amount - ((_amount * USER_DEP_FEE) / 10000);
        user.rewardDebt = (user.amount * pool.accGovTokenPerShare) / 1e12;
        devr.amount += _amount - ((_amount * DEV_DEP_FEE) / 10000);
        devr.rewardDebt = (devr.amount * pool.accGovTokenPerShare) / 1e12;
        emit Deposit(_msgSender(), _pid, _amount);
        if (user.firstDepositTime > 0) {} else {
            user.firstDepositTime = block.timestamp;
        }
        user.lastDepositTime = block.timestamp;
    }

    // Withdraw LP tokens from MasterInvestor.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount >= _amount, "MasterInvestor::withdraw: not good");
        updatePool(_pid);
        _harvest(_pid);

        if (_amount > 0) {
            user.amount -= _amount;
            if (user.lastWithdrawTime > 0) {
                user.timeDelta = block.timestamp - user.lastWithdrawTime;
            } else {
                user.timeDelta = block.timestamp - user.firstDepositTime;
            }
            uint256 userAmount = 0;
            uint256 devAmount = 0;
            if (block.timestamp == user.lastDepositTime) {
                // 25% fee for withdrawals of LP tokens in the same second. This is to prevent abuse from flash loans
                userAmount = (_amount * USER_FEE_STAGES[0]) / 100;
                devAmount = (_amount * DEV_FEE_STAGES[0]) / 100;
            } else if (user.timeDelta >= 1 && user.timeDelta < 60 minutes) {
                // 8% fee if a user deposits and withdraws in between same second and 60 minutes.
                userAmount = (_amount * USER_FEE_STAGES[1]) / 100;
                devAmount = (_amount * DEV_FEE_STAGES[1]) / 100;
            } else if (user.timeDelta >= 60 minutes && user.timeDelta < 1 days) {
                // 4% fee if a user deposits and withdraws after 1 hour but before 1 day.
                userAmount = (_amount * USER_FEE_STAGES[2]) / 100;
                devAmount = (_amount * DEV_FEE_STAGES[2]) / 100;
            } else if (user.timeDelta >= 1 days && user.timeDelta < 3 days) {
                // 2% fee if a user deposits and withdraws between after 1 day but before 3 days.
                userAmount = (_amount * USER_FEE_STAGES[3]) / 100;
                devAmount = (_amount * DEV_FEE_STAGES[3]) / 100;
            } else if (user.timeDelta >= 3 days && user.timeDelta < 5 days) {
                // 1% fee if a user deposits and withdraws after 3 days but before 5 days.
                userAmount = (_amount * USER_FEE_STAGES[4]) / 100;
                devAmount = (_amount * DEV_FEE_STAGES[4]) / 100;
            } else if (user.timeDelta >= 5 days && user.timeDelta < 2 weeks) {
                //0.5% fee if a user deposits and withdraws if the user withdraws after 5 days but before 2 weeks.
                userAmount = (_amount * USER_FEE_STAGES[5]) / 1000;
                devAmount = (_amount * DEV_FEE_STAGES[5]) / 1000;
            } else if (user.timeDelta >= 2 weeks && user.timeDelta < 4 weeks) {
                //0.25% fee if a user deposits and withdraws after 2 weeks.
                userAmount = (_amount * USER_FEE_STAGES[6]) / 10000;
                devAmount = (_amount * DEV_FEE_STAGES[6]) / 10000;
            } else if (user.timeDelta >= 4 weeks) {
                //0.1% fee if a user deposits and withdraws after 4 weeks
                userAmount = (_amount * USER_FEE_STAGES[7]) / 10000;
                devAmount = (_amount * DEV_FEE_STAGES[7]) / 10000;
            } else {
                revert("Something is very broken");
            }
            pool.lpToken.safeTransfer(_msgSender(), userAmount);
            pool.lpToken.safeTransfer(DEV_FUND_ADDRESS, devAmount);

            user.rewardDebt = (user.amount * pool.accGovTokenPerShare) / 1e12;

            emit Withdraw(_msgSender(), _pid, _amount);

            user.lastWithdrawTime = block.timestamp;
        }
    }

    // Withdraw LP tokens from MasterInvestor.
    function withdraw(uint256 _pid, uint256 _amount, address _address) public nonReentrant onlyRole(CONTRACT_ROLE) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_address];
        require(user.amount >= _amount, "MasterInvestor::withdraw: not good");
        updatePool(_pid);
        _harvestFor(_pid, _address);

        if (_amount > 0) {
            user.amount -= _amount;
            pool.lpToken.safeTransfer(_address, _amount);
            user.rewardDebt = (user.amount * pool.accGovTokenPerShare) / 1e12;
            emit Withdraw(_address, _pid, _amount);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY. This has the same 25% fee as same second withdrawals
    // to prevent abuse of this function.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        //reordered from Sushi function to prevent risk of reentrancy
        uint256 amountToSend = ((user.amount * USER_FEE_STAGES[0]) / 100);
        uint256 devToSend = ((user.amount * DEV_FEE_STAGES[0]) / 100);
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(_msgSender(), amountToSend);
        pool.lpToken.safeTransfer(DEV_FUND_ADDRESS, devToSend);
        emit EmergencyWithdraw(_msgSender(), _pid, amountToSend);
    }

    // Safe GovToken transfer function, just in case if rounding error causes pool to not have enough GovTokens.
    function safeGovTokenTransfer(address _to, uint256 _amount) internal {
        uint256 govTokenBal = GOV_TOKEN.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > govTokenBal) {
            transferSuccess = GOV_TOKEN.transfer(_to, govTokenBal);
        } else {
            transferSuccess = GOV_TOKEN.transfer(_to, _amount);
        }
        require(transferSuccess, "MasterInvestor::safeGovTokenTransfer: transfer failed");
    }

    function getNewRewardPerSecond(uint256 pid1) public view returns (uint256) {
        uint256 multiplier = getMultiplier(block.timestamp - 1, block.timestamp);
        return (((multiplier * REWARD_PER_SECOND) * poolInfo[pid1].allocPoint) / TOTAL_ALLOCATION_POINTS);
    }

    function userDelta(uint256 _pid) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_msgSender()];
        if (user.lastWithdrawTime > 0) {
            return block.timestamp - user.lastWithdrawTime;
        }
        return block.timestamp - user.firstDepositTime;
    }

    function userDeltaOf(uint256 _pid, address _address) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_address];
        if (user.lastWithdrawTime > 0) {
            return block.timestamp - user.lastWithdrawTime;
        }
        return block.timestamp - user.firstDepositTime;
    }

    // Update Finish Bonus Time
    function updateLastRewardTime(uint256 time) public onlyRole(ADMIN_ROLE) {
        FINISH_BONUS_AT_TIME = time;
    }

    // Update Halving At Time
    function updateHalvingAtTimes(uint256[] memory times) public onlyRole(ADMIN_ROLE) {
        HALVING_AT_TIMES = times;
    }

    // Update Reward Per Second
    function updateRewardPerSecond(uint256 reward) public onlyRole(ADMIN_ROLE) {
        REWARD_PER_SECOND = reward;
    }

    // Update Rewards Multiplier Array
    function updateRewardMultipliers(uint256[] memory multipliers) public onlyRole(ADMIN_ROLE) {
        REWARD_MULTIPLIERS = multipliers;
    }

    // Update % lock for general users
    function updateUserLockPercents(uint256[] memory lockPercents) public onlyRole(ADMIN_ROLE) {
        PERCENT_LOCK_BONUS_REWARD = lockPercents;
    }

    // Update START_TIME
    function updateStartTime(uint256 time) public onlyRole(ADMIN_ROLE) {
        START_TIME = time;
    }

    function updateAddress(uint256 kind, address _address) public onlyRole(ADMIN_ROLE) {
        if (kind == 1)  DEV_FUND_ADDRESS = _address;
        else if (kind == 2) FEE_SHARE_FUND_ADDRESS = _address;
        else if (kind == 3) MARKETING_FUND_ADDRESS = _address;
        else if (kind == 4) FOUNDERS_FUND_ADDRESS = _address;
        else revert("Invalid kind identifier");
    }

    function updateLockPercent(uint256 kind, uint256 percent) public onlyRole(ADMIN_ROLE) {
        if (kind == 1) PERCENT_FOR_DEV = percent;
        else if (kind == 2) PERCENT_FOR_FEE_SHARE = percent;
        else if (kind == 3) PERCENT_FOR_MARKETING = percent;
        else if (kind == 4) PERCENT_FOR_FOUNDERS = percent;
        else revert("Invalid kind identifier");
    }

    function updateDepositFee(uint256 kind, uint256 fee) public onlyRole(ADMIN_ROLE) {
        if (kind == 1) USER_DEP_FEE = fee;
        else if (kind == 2) DEV_DEP_FEE = fee;
        else revert("Invalid kind identifier");
    }
    function updateFeeStages(uint256 kind, uint256[] memory feeStages) public onlyRole(ADMIN_ROLE) {
        if (kind == 1) USER_FEE_STAGES = feeStages;
        else if (kind == 2) DEV_FEE_STAGES = feeStages;
        else revert("Invalid kind identifier");
    }

    function reviseWithdraw(uint256 _pid, address _user, uint256 _time) public onlyRole(ADMIN_ROLE) {
        UserInfo storage user = userInfo[_pid][_user];
        user.lastWithdrawTime = _time;
    }

    function reviseDeposit(uint256 _pid, address _user, uint256 _time) public onlyRole(ADMIN_ROLE) {
        UserInfo storage user = userInfo[_pid][_user];
        user.firstDepositTime = _time;
    }

    function correctWithdrawal(uint256 _pid, address _user, uint256 _amount) public onlyRole(ADMIN_ROLE) {
        PoolInfo storage pool = poolInfo[_pid];
        pool.lpToken.safeTransfer(_user, _amount);
        updatePool(_pid);
    }

    function totalAllocPoint() public view returns(uint256) {
        return TOTAL_ALLOCATION_POINTS;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
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
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = _setInitializedVersion(1);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        bool isTopLevelCall = _setInitializedVersion(version);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(version);
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        _setInitializedVersion(type(uint8).max);
    }

    function _setInitializedVersion(uint8 version) private returns (bool) {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, and for the lowest level
        // of initializers, because in other contexts the contract may have been reentered.
        if (_initializing) {
            require(
                version == 1 && !AddressUpgradeable.isContract(address(this)),
                "Initializable: contract is already initialized"
            );
            return false;
        } else {
            require(_initialized < version, "Initializable: contract is already initialized");
            _initialized = version;
            return true;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20ExtendedUpgradeable is IERC20Upgradeable {
    function cap() external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}