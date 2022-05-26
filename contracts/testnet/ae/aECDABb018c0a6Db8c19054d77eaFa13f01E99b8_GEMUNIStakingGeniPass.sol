pragma solidity ^0.8.0;
import "./GEMUNIStaking.sol";
import "./interfaces/IGENIPassSaleV2.sol";
import "./interfaces/IGENIPass.sol";


contract GEMUNIStakingGeniPass is GEMUNIStaking {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
  
    address public geniPassSale;
    address public geniPass;
    address private vestContract;
    mapping(uint => uint) private vestTime;
    mapping(uint => uint) private priceNFT;

    function _initialize (address _geniPassSale, address _geniPass) external initializer {
        __ReentrancyGuard_init();
        __operatable_init();
        geniPassSale = _geniPassSale;
        geniPass = _geniPass;
    }

    function setVestingContract(address _vesting) public override onlyOwner {
        require(_vesting != address(0), "Farm: invalid address");
        vestContract = _vesting;
    }

    function vestingContract() public override view returns (address) {
        return vestContract;
    }

    function setGeniPassSale(address _geniPassSale) external onlyOwner {
        require(_geniPassSale != address(0), "GS: invalid address");
        geniPassSale = _geniPassSale;
        emit SetGeniPassSale(_geniPassSale);
    }

    function getPriceNFT (address stakedNFT, uint passId) internal override view returns (uint) {
        uint pricePass;
        if (stakedNFT == geniPass) {
            pricePass = IGENIPassSaleV2(geniPassSale).getCurrentPricePass(passId);
        } else {
            revert ("GS: not support");
        }
        return pricePass;
    }

    function getTotalPriceNFT (uint[] memory passIds) internal view returns (uint) {
        uint totalAmountNFT;
        for (uint i = 0; i < passIds.length; i++ ) {
            bool isExistedToken = IGENIPass(geniPass).exists(passIds[i]);
            require(isExistedToken, "GEMUNILending: invalid tokenId");
            totalAmountNFT = totalAmountNFT.add(getPriceNFT(geniPass, passIds[i]));
        }
        return totalAmountNFT;
    }

    function setStake(uint pid, uint passId, uint amount, address staker) external onlyOperator {
        StakeInfo storage stake = NFTStaked[pid][passId];
        stake.user = staker;
        stake.amount = amount;
    }

    function setPriceNFT(uint passId, uint price) internal override {
        priceNFT[passId] = price;
    }

    function amountNFT(uint passId) internal override view returns (uint) {
        return priceNFT[passId];
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract PermissionGroupUpgradeable is OwnableUpgradeable {

    mapping(address => bool) public operators;
    event AddOperator(address newOperator);
    event RemoveOperator(address operator);

    function __operatable_init() internal initializer {
        __Ownable_init();
        operators[owner()] = true;
    }

    modifier onlyOperator {
        require(operators[msg.sender], "Operatable: caller is not the operator");
        _;
    }

    function addOperator(address operator) external onlyOwner {
        operators[operator] = true;
        emit AddOperator(operator);
    }

    function removeOperator(address operator) external onlyOwner {
        operators[operator] = false;
        emit RemoveOperator(operator);
    }
}

pragma solidity ^0.8.0;
import "./IGENIPass.sol";

interface IGENIPassSaleV2 {
    struct SaleInfo {
        uint price;
        IGENIPass.PriceType priceType;
        uint startTime;
        uint expirationTime;
    }
    
    struct CreateSalePasses{
        string serialNumber;
        uint price;
        IGENIPass.PassType passType;
        uint startTime;
        uint expirationTime;
    }

    struct CreateSalePassesWithoutMint{
        uint passId;
        uint price;
        uint startTime;
        uint expirationTime;
    }

    struct ReferalBonus {
        uint referralBonusLv0;
        uint referralBonusLv1;
        uint referralBonusLv2;
        uint referralBonusLv3;
        uint referralBonusLv4;
    }

    struct ReferalLevelParams {
        uint startLv0;
        uint startLv1;
        uint startLv2;
        uint startLv3;
        uint startLv4;
    }

    struct ReferalPointParams {
        uint stonePoint;
        uint topazPoint;
        uint citrinePoint;
        uint rubyPoint;
        uint diamondPoint;
    }

    event SetServer(address newServer);
    event SetTreasury(address newTreasury);
    event SetGeni(address newGeni);
    event SetDiscountRate(uint value);
    event SetExchange(address _exchange);
    event SetReferralLevel(uint startLv0, uint startLv1, uint startLv2, uint startLv3, uint startLv4);
    event SetReferralPoint(uint stonePoint, uint topazPoint, uint citrinePoint, uint rubyPoint, uint diamondPoint);
    event SetReferralBonusLevel0(uint _rate);
    event SetReferralBonusLevel1(uint _rate);
    event SetReferralBonusLevel2(uint _rate);
    event SetReferralBonusLevel3(uint _rate);
    event SetReferralBonusLevel4(uint _rate);

    event PassPutOnSale(uint indexed passId, uint price, uint priceType, address seller, uint startTime, uint expirationTime);
    event PassUpdateSale(uint indexed passId, uint newPrice, address seller);
    event PassRemoveFromSale(uint indexed passId, address seller);
    event PassBought(uint indexed passId, address buyer, address seller, uint256 price, uint discountedPrice);
    event PassBoughtWithReferral(uint indexed passId, address buyer, address seller, address referal, uint nonce, uint256 price, uint discountedPrice, uint referalBonus);
    event WithdrawGeniPass(address seller, address to, uint indexed tokenId);
    event WithdrawToken(address token, address to, uint amount);
    event WithdrawETH(address recipient, uint amount);
    
    function putOnSale(uint passId, uint price, uint startTime, uint expirationTime) external;
    function mintForSale(string memory serialNumber, uint price, IGENIPass.PassType passType, uint startTime, uint expirationTime) external;
    function updateSale(uint passId, uint price) external;
    function removeFromSale(uint passId) external;
    function putOnSaleBatch(CreateSalePassesWithoutMint[] memory input) external;
    function mintForSaleBatch(CreateSalePasses[] memory input) external;
    function purchase(uint passId, uint buyPrice) external;
    function purchaseWithReferral(uint passId, uint buyPrice, address referalAddress, uint nonce, bytes memory signature) external;
    function getPricePass(uint passId, uint price, IGENIPass.PriceType priceType) external view returns(uint);
    function getCurrentPricePass(uint passId) external view returns(uint);
}

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IGENIPass is IERC721Upgradeable {
    enum PassType { Stone, Topaz, Citrine, Ruby, Diamond }
    enum PriceType { BNB, GENI }

    struct GeniPass {
        string serialNumber;
        PassType passType;
        bool isActive;
    }
    
    event SetActive(uint indexed passId, bool isActive);
    event PassCreated(address indexed owner, uint indexed passId, uint passType, string serialNumber);
    event LockPass(uint indexed passId);
    event UnLockPass(uint indexed passId);
    
    function burn(uint tokenId) external;
    
    function mint(address to, string memory serialNumber, PassType passType) external returns(uint tokenId);
    
    function getPass(uint passId) external view returns (GeniPass memory pass);

    function exists(uint passId) external view returns (bool);

    function setActive(uint tokenId, bool _isActive) external;

    function lockPass(uint passId) external;

    function unLockPass(uint passId) external;

    function permit(address owner, address spender, uint tokenId, bytes memory _signature) external;
    
    function isLocked(uint tokenId) external returns(bool);
}

pragma solidity ^0.8.0;

interface IGEMUNIVesting {
    function unlock(address locker, uint pid) external;

    function lock(
        address locker,
        uint pid,
        address _token,
        address _addr,
        uint256 _amount
    ) external;
}

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IGEMUNIStaking {
    struct StakeInfo {
        address user;
        uint amount;
    }

    struct Param {
        uint _pid;
        uint[] tokenIds;
        uint _amountToken;
    }


    struct UserInfoNft {
        uint amount; // How many staked tokens the user has provided
        uint stakeTime; // Time when user deposited.
        uint reward; // Reward debt
        uint rewardClaimed;
        uint currentRewardStored;
    }

    struct TimePoolInfo {
        uint startTime; // The block number when DRAGON mining starts.
        uint endTime;
        uint lastRewardTime; // The block number of the last pool update
        uint stakingPeriod; // The number of blocks that will be added
    }

    struct TokenPoolInfo {
        address stakedNFT;
        IERC20 stakedToken;
        IERC20 rewardToken; // The reward token
    }

    struct PoolInfoNft {
        TokenPoolInfo tokenPoolInfo;
        TimePoolInfo timePoolInfo;
        uint rewardPerSecond;
        uint PRECISION_FACTOR; // The precision factor
        uint accTokenShare;
        uint rewardBalance;
        uint totalStaked;
        uint claimedRewards; // The claimed rewards in all batches
        bool isEarlyClaimAllowed;
        bool isActive;
    }


    //******EVENTS********//
    event DepositNFT(uint indexed pid, address indexed user, uint256[] passId, uint amount);
    event CreatedPoolNft(uint pid, address tokenNFT, address stakedToken, address rewardToken, uint stakingPeriod, bool isEarlyClaimAllowed, uint rewardBalance);
    event LockPoolNft(uint indexed pid);

    event EmergencyRewardWithdraw(uint indexed pid, address indexed user, uint256 amount);
    event IncreaseReward(uint pid, uint256 _amount);
    event WithdrawNFT(uint indexed pid, address indexed user, uint tokenId, uint amount);
    event EmergencyWithdrawNFT(uint indexed  pid, address indexed user, uint[] passIds);
    event ClaimRewardNft(uint pid, address indexed user, uint256 amount);

    event NewStartAndEndBlocks(uint indexed pid, uint256 startBlock, uint256 endBlock);
    event NewStakingPeriod(uint indexed pid, uint256 period);
    event NewRewardPerBlock(uint indexed pid, uint256 rewardPerBlock);
    event SetIsEarlyClaimAllowed(uint pid, bool _isEarlyClaimedAllowed); 
    event SetGeniPassSale(address newGeniPassSale);

    function emergencyRewardWithdraw(uint pid, uint256 _amount, address user) external;
    function increaseReward(uint pid, uint256 _amount) external;
    function depositNFT(Param memory param) external;
    function withdrawNFT(uint pid, uint256 tokenId) external;
    function emergencyWithdrawNFT(uint pid, uint[] memory passIds) external;
    function poolLength() external view returns (uint256); 

}

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/PermissionGroupUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IGEMUNIStaking.sol";
import "./interfaces/IGEMUNIVesting.sol";


abstract contract GEMUNIStaking is PermissionGroupUpgradeable, ReentrancyGuardUpgradeable, IGEMUNIStaking{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
  
    PoolInfoNft[] public poolInfoNfts;

    mapping(uint => mapping(uint => StakeInfo)) public NFTStaked;
    // Info of each user that stakes tokens.
    mapping(uint256 => mapping(address => UserInfoNft)) public userInfoNft;

    modifier onlyTokenOwner(uint pid, uint[] memory tokenIds) {
        PoolInfoNft storage pool = poolInfoNfts[pid];
        for (uint i; i < tokenIds.length; i ++) {
            require(IERC721(pool.tokenPoolInfo.stakedNFT).ownerOf(tokenIds[i]) == msg.sender, "Staking: not pass owner");
        }
        _;
    }

    modifier onlyTokenOwnerStaking(uint pid, uint tokenId) {
        PoolInfoNft storage pool = poolInfoNfts[pid];
        require(NFTStaked[pid][tokenId].user == msg.sender, "Staking: not pass staked owner");
        _;
    }

    modifier notEnded(uint256 _pid) {
        PoolInfoNft storage pool = poolInfoNfts[_pid];
        uint256 endTime = pool.timePoolInfo.endTime;
        require(block.timestamp <= endTime, "Staking: Pool ended");
        _;
    }
    
    modifier validPool(uint pid) {
        uint maxLengthPool = poolInfoNfts.length - 1;
        require(pid <= maxLengthPool, "Staking: invalid pid");
        _;
    }

    modifier activePool(uint pid) {
        PoolInfoNft memory pool = poolInfoNfts[pid];
        require(pool.isActive, "Staking: deactive pool");
        _;
    }

    function poolLength() external override view returns (uint256) {
        return poolInfoNfts.length;
    }

    function setIsEarlyClaimAllowed(uint pid, bool _isEarlyClaimAllowed) external validPool(pid) activePool(pid) onlyOwner {
        PoolInfoNft storage pool = poolInfoNfts[pid];
        pool.isEarlyClaimAllowed = _isEarlyClaimAllowed;
        emit SetIsEarlyClaimAllowed(pid, _isEarlyClaimAllowed);
    }

    // Batch reward withdraw by owner
    function emergencyRewardWithdraw(uint pid, uint256 _amount, address _to) external override validPool(pid) activePool(pid) onlyOperator {

        PoolInfoNft storage pool = poolInfoNfts[pid];
        uint currentBalance = pool.rewardBalance - pool.claimedRewards;
        require(_amount > 0 && _amount <= currentBalance, "Staking: invalid amount");
        require(_to != address(0), "Staking: invalid address");
        uint256 startTime = pool.timePoolInfo.startTime;
        uint256 endTime = pool.timePoolInfo.endTime;
        
        pool.rewardBalance = pool.rewardBalance.sub(_amount);
        pool.rewardPerSecond = pool.rewardBalance.div(endTime.sub(startTime));

        pool.tokenPoolInfo.rewardToken.safeTransfer(_to, _amount);

        emit EmergencyRewardWithdraw(pid, msg.sender, _amount);
    }

    function increaseReward(uint _pid, uint256 _amount) external override notEnded(_pid) activePool(_pid) validPool(_pid) onlyOperator {
        updatePool(_pid);
        PoolInfoNft storage pool = poolInfoNfts[_pid];
        pool.tokenPoolInfo.rewardToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 startTime = pool.timePoolInfo.lastRewardTime;
        uint256 endTime = pool.timePoolInfo.endTime;
        
        pool.rewardBalance = pool.rewardBalance.add(_amount);
        pool.rewardPerSecond = pool.rewardPerSecond.add(
            _amount.div(endTime.sub(startTime))
        );
        emit IncreaseReward(_pid, _amount);
    }

    // Owner update additional blocks per distribution
    function updateStakingPeriod(uint pid, uint256 _period) external nonReentrant onlyOwner {
        uint maxLengthPool = poolInfoNfts.length - 1;
        require(pid <= maxLengthPool, "Staking: invalid pid");
        PoolInfoNft storage pool = poolInfoNfts[pid];
        require(pool.isActive, "Staking: already locked");
        pool.timePoolInfo.stakingPeriod = _period;
        emit NewStakingPeriod(pid, _period);
    }

    // Add pool nft
    function addPoolNft(
        TokenPoolInfo memory tokenPoolInfo,
        uint256 stakingPeriod,
        uint256 rewardBalance,
        uint256 startTime,
        uint256 endTime,
        bool isEarlyClaimAllowed,
        bool _withUpdate
    ) public onlyOperator {
        {
            bool foundToken;
            for (uint256 i = 0; i < poolInfoNfts.length; i++) {
                PoolInfoNft memory pool = poolInfoNfts[i];
                if (pool.tokenPoolInfo.stakedNFT == tokenPoolInfo.stakedNFT && 
                    address(pool.tokenPoolInfo.stakedToken) == address(tokenPoolInfo.stakedToken) && 
                    address(pool.tokenPoolInfo.rewardToken) == address(tokenPoolInfo.rewardToken) && 
                    pool.timePoolInfo.stakingPeriod == stakingPeriod &&
                    block.timestamp < pool.timePoolInfo.endTime &&
                    pool.isActive
                ) {
                    foundToken = true;
                    break;
                }
                foundToken = false;
            }
            require(!foundToken, "Staking: Token exists");
        }
        require(address(tokenPoolInfo.rewardToken) != address(0), "Staking: Token is address(0)");
        require(startTime < endTime, "Staking: Require startTime < endTime");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardTime = block.timestamp > startTime
            ? block.timestamp
            : startTime;
        uint256 rewardPerSecond = rewardBalance.div(endTime.sub(startTime));

        IERC20(tokenPoolInfo.rewardToken).safeTransferFrom(msg.sender, address(this), rewardBalance);
        uint256 decimalsRewardToken = uint256(IERC20Metadata(address(tokenPoolInfo.rewardToken)).decimals());
        poolInfoNfts.push(
            PoolInfoNft({
                tokenPoolInfo: TokenPoolInfo ({
                    stakedNFT: tokenPoolInfo.stakedNFT,
                    stakedToken: IERC20(tokenPoolInfo.stakedToken),
                    rewardToken: IERC20(tokenPoolInfo.rewardToken)
                }),
                timePoolInfo: TimePoolInfo({
                    startTime: startTime == 0 ? block.timestamp : startTime,
                    endTime: endTime,
                    stakingPeriod: stakingPeriod,
                    lastRewardTime: lastRewardTime
                }),
                rewardPerSecond: rewardPerSecond,
                PRECISION_FACTOR: 10 ** (30 - decimalsRewardToken),
                accTokenShare: 0,
                rewardBalance: rewardBalance,
                totalStaked: 0,
                isEarlyClaimAllowed: isEarlyClaimAllowed,
                claimedRewards: 0,
                isActive: true
            })
        );
        uint256 pid = poolInfoNfts.length - 1;
        emit CreatedPoolNft(pid, tokenPoolInfo.stakedNFT, address(tokenPoolInfo.stakedToken), address(tokenPoolInfo.rewardToken), stakingPeriod, isEarlyClaimAllowed, rewardBalance);
    }

    function lockPoolNft(uint pid) external onlyOwner {
        require(poolInfoNfts.length > 0, "Staking: List of token is empty");
        uint maxLengthPool = poolInfoNfts.length - 1;
        require(pid <= maxLengthPool, "Staking: invalid pid");
        PoolInfoNft storage pool = poolInfoNfts[pid];

        require(pool.isActive, "Staking: already locked");
        pool.isActive = false;

        emit LockPoolNft(pid);
    }

    // User deposit NFT
    function depositNFT(Param memory param) external override onlyTokenOwner(param._pid, param.tokenIds) notEnded(param._pid) validPool(param._pid) nonReentrant {
        UserInfoNft storage user = userInfoNft[param._pid][msg.sender];
        PoolInfoNft storage pool = poolInfoNfts[param._pid];
        require(block.timestamp >= pool.timePoolInfo.startTime && block.timestamp <= pool.timePoolInfo.endTime, "Staking: not start yet or already finished");
        require(pool.isActive, "Staking: deactive pool");
        if (address(pool.tokenPoolInfo.stakedToken )== address(0)){
            require(param._amountToken == 0, "Staking: invalid amount");
        } else {
            require(IERC20(pool.tokenPoolInfo.stakedToken).balanceOf(msg.sender) >= param._amountToken, "Staking: Don't have enough geni");
        } 
        updatePool(param._pid);
        if (user.amount > 0) {
            uint256 pending = getPending(user, pool);
            user.currentRewardStored = user.currentRewardStored.add(pending);
        }
        uint totalAmount = getTotalAmount(pool, param);
        if (totalAmount > 0) {
            user.amount = user.amount.add(totalAmount);
            pool.totalStaked = pool.totalStaked.add(totalAmount);
            if (param._amountToken > 0) {
                pool.tokenPoolInfo.stakedToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                param._amountToken);
            }
        }
        user.reward = user.amount.mul(pool.accTokenShare).div(pool.PRECISION_FACTOR);
        user.stakeTime = block.timestamp;

        emit DepositNFT(param._pid, msg.sender, param.tokenIds, totalAmount);
    }

    function getPending(UserInfoNft memory user, PoolInfoNft memory pool) internal pure returns (uint  pending) {
        pending = user.amount
            .mul(pool.accTokenShare)
            .div(pool.PRECISION_FACTOR)
            .sub(user.reward);
    }

    function getTotalAmount(PoolInfoNft storage pool, Param memory param) internal returns (uint totalAmount) {
        for (uint i = 0; i < param.tokenIds.length; i++ ) {
            uint price = getPriceNFT(pool.tokenPoolInfo.stakedNFT, param.tokenIds[i]);
            setPriceNFT(param.tokenIds[i], price);
            totalAmount = totalAmount.add(price);
            uint amountToken;
            if ( i < param.tokenIds.length -1) {
                amountToken = param._amountToken / param.tokenIds.length;
            } else {
                amountToken = param._amountToken / param.tokenIds.length + param._amountToken % param.tokenIds.length;
            }
            IERC721(pool.tokenPoolInfo.stakedNFT).transferFrom(msg.sender, address(this), param.tokenIds[i]);
            NFTStaked[param._pid][param.tokenIds[i]].user = msg.sender;
            NFTStaked[param._pid][param.tokenIds[i]].amount = amountToken + getPriceNFT(pool.tokenPoolInfo.stakedNFT, param.tokenIds[i]);
        }
        totalAmount += param._amountToken;
    }

    // User withdraw
    function withdrawNFT(uint pid, uint256 tokenId) external override validPool(pid) nonReentrant {
        UserInfoNft storage user = userInfoNft[pid][msg.sender];
        PoolInfoNft storage pool = poolInfoNfts[pid];

        require(user.amount > 0, "Staking: not found info");
        require(NFTStaked[pid][tokenId].user == msg.sender, "Staking: not pass staked owner");

        uint _amount = NFTStaked[pid][tokenId].amount;

        uint amountPass = amountNFT(tokenId) > 0 ? amountNFT(tokenId) : getPriceNFT(pool.tokenPoolInfo.stakedNFT, tokenId);

        uint _amountToken = _amount.sub(amountPass); 

        uint256 stakeTime = user.stakeTime < pool.timePoolInfo.startTime ? pool.timePoolInfo.startTime : user.stakeTime;
        require(stakeTime + pool.timePoolInfo.stakingPeriod <= block.timestamp, "Staking: token is locked");

        updatePool(pid);
        
        uint256 pending = user.amount.mul(pool.accTokenShare).div(pool.PRECISION_FACTOR).sub(
            user.reward
        );

        if (_amount > 0) {
            user.currentRewardStored = user.currentRewardStored.add(pending);
            user.amount = user.amount.sub(_amount);
            user.reward = user.amount.mul(pool.accTokenShare).div(pool.PRECISION_FACTOR);
            pool.totalStaked = pool.totalStaked.sub(_amount);
            
            if (user.currentRewardStored > 0) {
                claimRewardNft(pid);
            }

            IERC721(pool.tokenPoolInfo.stakedNFT).transferFrom(address(this), msg.sender, tokenId);
            if (_amountToken > 0) {
                IERC20(pool.tokenPoolInfo.stakedToken).safeTransfer(msg.sender, _amountToken);
            }
            delete NFTStaked[pid][tokenId];
        }

        emit WithdrawNFT(pid, msg.sender, tokenId, _amount);
    }

    function claimRewardNft(uint _pid) internal {
        PoolInfoNft storage pool = poolInfoNfts[_pid];
        UserInfoNft storage user = userInfoNft[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accTokenShare).div(pool.PRECISION_FACTOR).sub(user.reward);
        user.reward = user.amount.mul(pool.accTokenShare).div(pool.PRECISION_FACTOR);
        uint256 currentReward = user.currentRewardStored.add(pending);
        user.currentRewardStored = 0;

        address vesting = vestingContract();

        if (pool.tokenPoolInfo.rewardToken.allowance(address(this), vesting) < currentReward) {
            pool.tokenPoolInfo.rewardToken.approve(vesting, type(uint).max);
        }

        IGEMUNIVesting(vesting).lock(address(this), _pid, address(pool.tokenPoolInfo.rewardToken), msg.sender, currentReward);
       
        user.rewardClaimed = user.rewardClaimed.add(currentReward);
        pool.claimedRewards = pool.claimedRewards.add(currentReward);
        
        emit ClaimRewardNft(_pid, msg.sender, currentReward);
    }

    function emergencyWithdrawNFT(uint pid, uint[] memory passIds) external override validPool(pid) {
        PoolInfoNft storage pool = poolInfoNfts[pid];
        UserInfoNft storage user = userInfoNft[pid][msg.sender];
        require(user.amount > 0, "Staking: not found info");
        uint _totalAmountNFT;
        uint totalAmount;

        updatePool(pid);

        for (uint256 i = 0; i < passIds.length; i++) {
            require(
                NFTStaked[pid][passIds[i]].user == msg.sender && 
                IERC721(pool.tokenPoolInfo.stakedNFT).ownerOf(passIds[i]) == address(this), 
                "Staking: not pass staked owner"
            );

            uint amountNFTToken = amountNFT(passIds[i]) > 0 
                ? amountNFT(passIds[i]) 
                : getPriceNFT(pool.tokenPoolInfo.stakedNFT, passIds[i]);

            _totalAmountNFT = _totalAmountNFT.add(amountNFTToken);

            totalAmount = totalAmount.add(NFTStaked[pid][passIds[i]].amount);
        }

        require(totalAmount == user.amount, "Staking: Need select all passes");

        for (uint256 i = 0; i < passIds.length; i++) {
            IERC721(pool.tokenPoolInfo.stakedNFT).transferFrom(address(this), msg.sender, passIds[i]);
            delete NFTStaked[pid][passIds[i]];
        }

        uint _amount = user.amount;
        uint _amountToken = _amount.sub(_totalAmountNFT);

        if (_amountToken > 0) {
            pool.tokenPoolInfo.stakedToken.safeTransfer(msg.sender, _amountToken);
        }

        pool.totalStaked = pool.totalStaked.sub(user.amount);

        emit EmergencyWithdrawNFT(pid, msg.sender, passIds);
        delete userInfoNft[pid][msg.sender];
    }

    function emergencyWithdrawNFT(address tokenNft, uint tokenId, address _to) external onlyOperator { 
        IERC721(tokenNft).transferFrom(address(this), _to, tokenId);
    }

    function emergencyWithdrawToken(address token, uint amount, address _to) external onlyOperator { 
        IERC20(token).transfer(_to, amount);
    }

    function getPriceNFT(address tokenNFT, uint tokenId) internal virtual view returns (uint);
    function vestingContract() public virtual view returns (address);
    function setVestingContract(address _vesting) public virtual;
    function setPriceNFT(uint passId, uint price) internal virtual;
    function amountNFT(uint passId) internal virtual view returns (uint);

    //**************SUPPORTING FUNCTIONS*******************//
    function getMultiplier(uint256 _from, uint256 _to, uint256 _pid)
        public
        view
        returns (uint256)
    {
        if (_from >= _to) return 0;
        uint256 start = _from;
        uint256 end = _to;
        
        PoolInfoNft memory pool = poolInfoNfts[_pid];
        uint256 startTime = pool.timePoolInfo.startTime;
        uint256 endTime = pool.timePoolInfo.endTime;
        if (start > endTime) return 0;
        if (end < startTime ) return 0;
        
        if (start < startTime) start = startTime;
        if (end > endTime) end = endTime;
        return end - start;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfoNfts.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfoNft memory pool = poolInfoNfts[pid];
            if(pool.isActive){
                updatePool(pid);
            }
        }
    }

    function updatePool(uint256 _pid) validPool(_pid) public {
        PoolInfoNft storage pool = poolInfoNfts[_pid];
        uint256 lastRewardTime = pool.timePoolInfo.lastRewardTime;
        if (block.timestamp <= lastRewardTime) {
            return;
        }
        uint256 totalStaked = pool.totalStaked;
        if (totalStaked == 0) {
            pool.timePoolInfo.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardTime, block.timestamp, _pid);
        uint256 reward = multiplier.mul(pool.rewardPerSecond);

        pool.accTokenShare = pool.accTokenShare.add(
            reward.mul(pool.PRECISION_FACTOR).div(totalStaked)
        );
        pool.timePoolInfo.lastRewardTime = block.timestamp;
    }

    // //**********VIEW FUNCTIONS***********//

    function pendingRewardPoolNft(uint _pid, address _user) public view validPool(_pid) returns (uint256) {
        PoolInfoNft memory pool = poolInfoNfts[_pid];
        UserInfoNft memory user = userInfoNft[_pid][_user];
        uint256 accTokenShare = pool.accTokenShare;
        uint256 totalStaked = pool.totalStaked;
        uint256 lastRewardTime = pool.timePoolInfo.lastRewardTime;
        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 multiplier = getMultiplier(
                lastRewardTime,
                block.timestamp,
                _pid
            );
            uint256 reward = multiplier.mul(pool.rewardPerSecond);
            accTokenShare = accTokenShare.add(
                reward.mul(pool.PRECISION_FACTOR).div(totalStaked)
            );
        }
        return user.amount.mul(accTokenShare).div(pool.PRECISION_FACTOR).sub(user.reward).add(user.currentRewardStored);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT

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
interface IERC165 {
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

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

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT

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
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
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
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

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
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

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

    function __ReentrancyGuard_init() internal initializer {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
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
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
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
    uint256[49] private __gap;
}