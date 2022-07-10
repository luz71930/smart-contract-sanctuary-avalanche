// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { AccessControlled, IAuthority } from "./Authority.sol";
import { IWallet } from "./Wallet.sol";
import { ITreasury } from "./Treasury.sol";
import { IDLC } from "./DLC.sol"; 

interface IRouter {
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}

contract BondDepositoryV2 is AccessControlled, ReentrancyGuardUpgradeable {
	using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

	/* ======== STATE VARIABLES ======== */

	IERC20MetadataUpgradeable public dlc; // dlc token
	IERC20MetadataUpgradeable public asset; // asset used to create bond
	ITreasury public treasury; // mints tokens when receives assets

	IRouter router;

	address public wallet; // internal
	bool inited;
	bool enabled;

	struct Bond {
		uint256 amount; 
		uint256 released;
		uint128 startTime;
		uint128 duration;
	}
	mapping(address => mapping(uint256 => Bond)) public bonds;
	struct BondInfo {
		uint256 startIndex;
		uint256 endIndex;
	}
	mapping(address => BondInfo) public bondsInfo;
	mapping(address => uint256) public balances;

	uint256 public totalSold;	
	
	uint256 private constant MULTIPLIER = 1e10;
	struct Terms {		
		uint256 minAmount; // min amount of tokens account can purchase in one transaction
		uint256 maxAmount; // max amount of tokens account can purchase in one transaction
		uint256 capacity; // maximum amount of tokens that could be sold
		uint128 duration; // vest duration
		uint128 maxBonds; // max active vest bonds per account
	}
	Terms public terms;

	/* ======== INITIALIZATION ======== */
	function initialize(
        address dlc_,
		address asset_,
		address treasury_,
		address authority_,
		address router_
    ) public initializer {
        __AccessControlled_init(IAuthority(authority_));
		dlc = IERC20MetadataUpgradeable(dlc_);
		asset = IERC20MetadataUpgradeable(asset_);
		treasury = ITreasury(treasury_);
		router = IRouter(router_);
    }
	
	//
	function setTerms(
		uint256 capacity_,
		uint256 minAmount_,
		uint256 maxAmount_,		
		uint128 duration_,
		uint128 maxBonds_
	) external onlyOperator {		
		require(minAmount_ >= 10**dlc.decimals(), ">");
		require(maxAmount_ >= minAmount_, ">=");
		require(maxAmount_ <= capacity_, "<");
		require(maxBonds_ <= 100, "100");
		terms = Terms({ minAmount: minAmount_, maxAmount: maxAmount_, capacity: capacity_, duration: duration_, maxBonds: maxBonds_ });
		if (!inited) {
			inited = true;			
			emit InitTerms(terms);
			setEnabled(true);
		} else {
			emit SetTerms(terms);
		}
	}

	// set contract for vest	
	// if set to 0 address vest will be disabled and tokens will be sent to personal account wallet
	function setWallet(address wallet_) external onlyOperator {
		wallet = wallet_;
		emit SetWallet(wallet_);
	}

	function setEnabled(bool state_) public onlyOperator {
		enabled = state_;
		emit SetEnabled(state_);
	}

	/* ======== VIEW ======== */

	//
	function contractData()
		public
		view
		returns (
			Terms memory _terms,
			uint256 _price,	
			uint256 _totalSold,			
			address _asset,
			string memory _assetSymbol,
			uint _assetDecimals
		)
	{
		_terms = terms;
		_price = price();
		_totalSold = totalSold;				
		_asset = address(asset);
		_assetSymbol = asset.symbol();
		_assetDecimals = asset.decimals();
	}
	
	//
	function accountData(address account_)
		public
		view
		returns (
			uint256 _balance,
			uint256 _assetAllowance,
			uint256 _assetBalance,
			address _asset,
			string memory _assetSymbol,
			uint _assetDecimals
		)
	{
		_balance = balances[account_];		
		_assetAllowance = asset.allowance(account_, address(this));
		_assetBalance = asset.balanceOf(account_);		
		_asset = address(asset);
		_assetSymbol = asset.symbol();
		_assetDecimals = asset.decimals();
	}

	//
	function price() public view returns (uint256 _price) {
		address[] memory path = new address[](2);
		path[0] = address(asset);
        path[1] = address(dlc);        
        uint256[] memory amountsOut = router.getAmountsIn(10**uint256(dlc.decimals()), path);        
        // Return raw price (without fees)
        _price = amountsOut[0];       	
	}

	function payoutFor(uint256 value_) public view returns (uint256 _payout) {
		_payout = (value_ * (10**dlc.decimals())) / treasury.tokenValue(address(asset), price());		
	}

	function payoutForAsset(uint256 value_) public view returns (uint256 _payout) {
		uint256 tokenAmount = treasury.tokenValue(address(asset), value_);		
		_payout = payoutFor(tokenAmount);	
	}
		
	/* ======== USER ======== */

	//
	function buy(
		uint256 amount_,
		uint256 minPayout_		
	) external onlyInited onlyEnabled nonReentrant returns (uint256 _payout) {
		require(!IDLC(address(dlc)).blackList(msg.sender), "Account blacklisted");			
		
		uint256 tokenAmount = treasury.tokenValue(address(asset), amount_);
		
		_payout = payoutFor(tokenAmount); 

		require(_payout >= minPayout_, "Payout too small"); // ( slippage protection )
		require(_payout >= terms.minAmount, "Bond too small"); // must be >= minAmount ( underflow protection )
		require(_payout <= terms.maxAmount, "Bond too large"); // must be <= maxAmount
				
		asset.safeTransferFrom(msg.sender, address(this), amount_);				
		asset.safeIncreaseAllowance(address(treasury), amount_);
				
		treasury.deposit(address(asset), amount_, _payout);	
		
		// update user vest bonds and release vested
		_release(msg.sender);
		
		if (terms.duration != 0) {
			BondInfo storage bondInfo = bondsInfo[msg.sender];
			require(bondInfo.endIndex < terms.maxBonds, "Too much bonds. Wait until older expire");			
			bonds[msg.sender][bondInfo.endIndex] = Bond({ amount: _payout, startTime: uint128(block.timestamp), released: 0, duration: terms.duration });
			bondInfo.endIndex ++;
			balances[msg.sender] += _payout;			
		} else {
			_sendTokens(msg.sender, _payout);
		}

		totalSold += _payout;
		require(totalSold <= terms.capacity, "Max capacity reached");

		emit Buy(msg.sender, amount_, price(), _payout, terms.duration);
	}
	function release(address account_) public onlyInited nonReentrant returns (uint256 _released, Bond[] memory _bonds) {
		return _release(account_);
	}

	// Update and release currently available locked tokens gradually over duration period
	function _release(address account_) internal returns (uint256 _released, Bond[] memory _bonds) {
		BondInfo storage bondInfo = bondsInfo[account_];
		// return if user has no bonds
		if (bondInfo.endIndex == 0) return (_released, _bonds);
		
		uint256 startIndex = bondInfo.startIndex;
		uint256 endIndex = bondInfo.endIndex;
		_bonds = new Bond[](endIndex - startIndex);	
		
		uint idx;	
		for (uint256 i = startIndex; i < endIndex; i++) {
			Bond storage bond = bonds[account_][i];
			
			uint256 endTime = bond.startTime + bond.duration;
			
			if (endTime <= block.timestamp) {
				_released += (bond.amount - bond.released);
				delete bonds[account_][i];
				bondInfo.startIndex ++;
			} else {
				uint256 amountToRelease = (bond.amount * ((block.timestamp - bond.startTime) * MULTIPLIER) / bond.duration) / MULTIPLIER - bond.released ;
				_released += amountToRelease;
				bond.released += amountToRelease;	
			}	
			_bonds[idx] = bond;
			idx ++;
		}
		
		if (_released != 0) {
			balances[account_] -= _released;
			_sendTokens(account_, _released);
		}

		// if end reached it means no lock found and we can reset startedIndex and clear all bonds array
		if (bondInfo.startIndex >= bondInfo.endIndex) {
			bondInfo.startIndex = 0;
			bondInfo.endIndex = 0;
		}
	}

	/* ======= INTERNAL ======= */
	//
	function _sendTokens(address account_, uint256 amount_) internal {
		if (wallet != address(0)) {
			dlc.safeIncreaseAllowance(wallet, amount_);
			IWallet(wallet).deposit(account_, amount_);
		} else {
			dlc.safeTransfer(account_, amount_);
		}
	}
	
	/* ======== EVENTS ======== */

	event InitTerms(Terms terms);
	event SetTerms(Terms terms);
	event SetEnabled(bool state);
	event SetWallet(address wallet);
		
	event Buy(address indexed account, uint256 assetAmount, uint256 bondPrice, uint256 payoutAmount, uint256 duration);
	
	/* ======== MODIFIERS ======== */

	modifier onlyInited() {
		require(inited, "Not inited");
		_;
	}

	modifier onlyEnabled() {
		require(enabled, "Not enabled");
		_;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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

// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract AccessControlled is Initializable {  
    using SafeERC20Upgradeable for IERC20Upgradeable;  
    IAuthority public authority;
    
    function __AccessControlled_init(IAuthority _authority) internal onlyInitializing {
        __AccessControlled_init_unchained(_authority);
    }

    function __AccessControlled_init_unchained(IAuthority _authority) internal onlyInitializing {
        authority = _authority;
        emit AuthorityUpdated(_authority);
    }
   
    modifier onlyOperator() {
        require(msg.sender == authority.operator(), "Operator!");
        _;
    }

    modifier onlyMinter() {
        require(authority.minters(msg.sender), "Minter!");
        _;
    }

    modifier onlyNftMinter() {
        require(authority.nftMinters(msg.sender), "NftMinter!");
        _;
    }

    function setAuthority(IAuthority _newAuthority) external onlyOperator {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }

    function recover(
		address token_,
		uint256 amount_,
		address recipient_,
        bool nft
	) external onlyOperator {
        if (nft) {
            IERC721Upgradeable(token_).safeTransferFrom(address(this), recipient_, amount_);
        } else if (token_ != address(0)) {
			IERC20Upgradeable(token_).safeTransfer(recipient_, amount_);
		} else {
			(bool success, ) = recipient_.call{ value: amount_ }("");
			require(success, "Can't send ETH");
		}
		emit Recover(token_, amount_, recipient_, nft);		
	}

    event AuthorityUpdated(IAuthority indexed authority);
    event Recover(address token, uint256 amount, address recipient, bool nft);
}

interface IAuthority {
    function operator() external view returns (address);
    function minters(address account) external view returns (bool);
    function nftMinters(address account) external view returns (bool);
    
    event OperatorSet(address indexed from, address indexed to);  
    event MinterSet(address indexed account, bool state);  
    event NftMinterSet(address indexed account, bool state);  
}

contract Authority is Initializable, IAuthority, AccessControlled {
	address public override operator;
    mapping(address => bool) public override minters; 
    address[] public mintersList;

    mapping(address => bool) public override nftMinters; 
    address[] public nftMintersList;

    function initialize(
        address operator_
    ) public initializer {
        __AccessControlled_init(IAuthority(address(this)));
        emit OperatorSet(operator, operator_);
		operator = operator_;
    }
	
	function setOperator(address operator_) public onlyOperator {		
		operator = operator_;
        emit OperatorSet(operator, operator_);
	}	

    function setMinter(address minter_, bool state_) public onlyOperator {		
		minters[minter_] = state_;
        if (state_) {
            mintersList.push(minter_);
        } else {
            for (uint256 i = 0; i < mintersList.length; i++) {
                if (mintersList[i] == minter_) {
                    mintersList[i] = mintersList[mintersList.length - 1];
                    mintersList.pop();
                    break;
                }
            }            
        }
        emit MinterSet(minter_, state_);
	}

    function mintersCount() public view returns (uint256) {
        return mintersList.length;
    }

    function setNftMinter(address minter_, bool state_) public onlyOperator {		
		nftMinters[minter_] = state_;
        if (state_) {
            nftMintersList.push(minter_);
        } else {
            for (uint256 i = 0; i < nftMintersList.length; i++) {
                if (nftMintersList[i] == minter_) {
                    nftMintersList[i] = nftMintersList[nftMintersList.length - 1];
                    nftMintersList.pop();
                    break;
                }
            }            
        }
        emit NftMinterSet(minter_, state_);
	}

    function nftMintersCount() public view returns (uint256) {
        return nftMintersList.length;
    }
}

// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IDLC } from "./DLC.sol";
import { AccessControlled, IAuthority } from "./Authority.sol";
import { IFeeDistributor } from "./FeeDistributor.sol";
import { IGameWallet } from "./GameWallet.sol";

interface IWallet {
	struct LocksInfo {
		uint128 start;
		uint128 length;
	}
	struct Lock {
		uint256 amount;
		uint64 unlockTime;
		uint64 duration;
		uint64 startTime;
	}
	function deposit(address account_, uint256 amount_) external;
}

contract Wallet is IWallet, ReentrancyGuardUpgradeable, AccessControlled {
	using SafeERC20Upgradeable for IERC20Upgradeable;

	string internal constant notAccepted = "Not accepted"; // not accepted
    string internal constant notApproved = "Not approved"; // not approved
	string internal constant notAllowed = "Not allowed"; // not approved	
	string internal constant invalidAmount = "Invalid amount"; // not approved
    string internal constant invalidParam = "Invalid param"; // invalid token	
	string internal constant invalid = "Not valid"; // invalid token

	/* ======== STATE VARIABLES ======== */

	address public dlc;
	address public gameWallet;

	uint64 public lockDuration;
	uint64 public lockDurationMultiplier;	
			
	address public penaltyReceiver;
	uint256 public penalty;
	
	uint256 public totalDeposited;
	mapping(address => uint256) public balances;
	mapping(address => uint256) public withdrawable;
	mapping(address => LocksInfo) public locksInfos;	
	mapping(address => mapping(uint256 => Lock)) public locks;
	
	/* ======== INITIALIZATION ======== */

    function initialize(
        address dlc_,
		address authority_,		
		uint256 penalty_,
		address penaltyReceiver_,		
		uint64 lockDuration_,
		uint64 lockDurationMultiplier_
    ) public initializer {
        __AccessControlled_init(IAuthority(authority_));
        dlc = dlc_;
		setPenalty(penaltyReceiver_, penalty_);			
		setDuration(lockDuration_, lockDurationMultiplier_);
    }

	/* ======== CONFIG ======== */

	function setDuration(uint64 lockDuration_, uint64 lockDurationMultiplier_) public onlyOperator {
		lockDuration = lockDuration_;
		lockDurationMultiplier = lockDurationMultiplier_;
		emit SetDuration(lockDuration_, lockDurationMultiplier_);
	}

	function setPenalty(address penaltyReceiver_, uint256 penalty_) public onlyOperator {
		require(penalty_ <= 99, notAccepted);
		penaltyReceiver = penaltyReceiver_;
		penalty = penalty_;
		emit PenaltySet(penaltyReceiver, penalty);
	}

	function setGameWallet(address gameWallet_) public onlyOperator {
		gameWallet = gameWallet_;
		emit SetGameWallet(gameWallet_);
	}
	
	/* ======== VIEW ======== */

	function lockedBalance(address account_) public view returns (uint256 _amount, Lock[] memory _locks) {
		LocksInfo memory locksInfo = locksInfos[account_];
		_locks = new Lock[](locksInfo.length - locksInfo.start);
		uint256 idx;
		for (uint256 i = locksInfo.start; i < locksInfo.length; i++) {
			if (locks[account_][i].unlockTime > block.timestamp) {
				_amount += locks[account_][i].amount;
				_locks[idx] = locks[account_][i];
				idx++;
			}
		}
	}

	function contractData()
		public
		view
		returns (
			uint256 _totalDeposited, 
			uint256 _lockDuration,
			uint256 _lockDurationMultiplier,			
			uint256 _penalty
		)
	{
		_totalDeposited = totalDeposited;
		_lockDuration = lockDuration;
		_lockDurationMultiplier = lockDurationMultiplier;
		_penalty = penalty;		
	}

	function accountData(address account_)
		public
		view
		returns (
			uint256 _balance,
			uint256 _locked, 
			uint256 _unlocked,
			Lock[] memory _locks, 
			uint256 _withdrawable,
			uint256 _dlcAllowance,
			uint256 _dlcBalance,
			uint256 _timestamp
		)
	{
		_balance = balances[account_];
		(_locked, _locks) = lockedBalance(account_);
		_unlocked = _balance - _locked;
		_dlcAllowance = IERC20Upgradeable(dlc).allowance(account_, address(this));
		_dlcBalance = IERC20Upgradeable(dlc).balanceOf(account_);
		_withdrawable = withdrawable[account_];
		_timestamp = block.timestamp;
	}

	/* ======== USER ======== */
	
	function deposit(address account_, uint256 amount_) external nonReentrant {
		_deposit(account_, amount_, false, false);
	}

	function _deposit(
		address account_,
		uint256 amount_,
		bool lock_,
		bool fromGame
	) internal {
		require(!IDLC(dlc).blackList(account_), notAllowed);

		_updateUserLocks(account_);

		require(amount_ != 0, notAccepted);
		balances[account_] += amount_;

		if (lock_) {
			uint64 unlockTime = ((uint64(block.timestamp) / lockDuration) * lockDuration) + (lockDuration * lockDurationMultiplier);
			
			LocksInfo storage locksInfo = locksInfos[account_];

			if (locksInfo.length == 0 || locks[account_][locksInfo.length - 1].unlockTime < unlockTime) {
				locks[account_][locksInfo.length] = Lock({ 
					amount: amount_, 
					unlockTime: unlockTime,  
					duration: (lockDuration * lockDurationMultiplier),
					startTime: uint64(block.timestamp)
				});
				locksInfo.length ++;
			} else {
				locks[account_][locksInfo.length - 1].amount += amount_;
			}
		} else {
			withdrawable[account_] += amount_;
		}

		if (!fromGame) {
			IERC20Upgradeable(dlc).safeTransferFrom(msg.sender, address(this), amount_);
		}
		
		totalDeposited += amount_;

		emit Deposit(account_, amount_, lock_);
	}

	// Withdraw defined amount of tokens. If amount higher than unlocked we get extra from locks and pay penalty
	function withdraw(uint256 amount_) public nonReentrant returns (uint256 _amount, uint256 _penaltyAmount) {
		require(amount_ != 0, notAccepted);

		_updateUserLocks(msg.sender);

		uint256 balance = balances[msg.sender];		
		require(balance >= amount_, invalidAmount);		
		balances[msg.sender] -= amount_;

		uint256 unlocked = withdrawable[msg.sender];

		_amount = amount_;
		if (amount_ > unlocked) {
			uint256 remaining = amount_ - unlocked;
			
			withdrawable[msg.sender] = 0;

			LocksInfo memory locksInfo = locksInfos[msg.sender];
			for (uint256 i = locksInfo.start; i < locksInfo.length; i++) {								
				Lock storage lock = locks[msg.sender][i];
				
				uint256 timeLeft = lock.unlockTime - block.timestamp; 
				uint256 correctionTime = lock.startTime - (lock.unlockTime - (lockDuration * lockDurationMultiplier));
				uint256 penaltyPercent = (penalty * 1e5 * (timeLeft * 1e10) / (lockDuration * lockDurationMultiplier - correctionTime)) / 1e10;
												
				if (lock.amount <= remaining) {
					remaining -= lock.amount;
					_penaltyAmount += (lock.amount * penaltyPercent) / (100 * 1e5);
					_amount -= _penaltyAmount;
					delete locks[msg.sender][i];
					if (remaining == 0) {
						break;
					}
				} else {
					lock.amount -= remaining;
					_penaltyAmount += (remaining * penaltyPercent) / (100 * 1e5);
					_amount -= _penaltyAmount;
					break;
				}
			}
		} else {
			_amount = amount_;
			withdrawable[msg.sender] -= amount_;
		}

		_sendTokensAndPenalty(_amount, _penaltyAmount);
		emit Withdrawn(msg.sender, _amount);
	}

	function updateUserLocks() public {
		_updateUserLocks(msg.sender);
	}
	
	//
	function deposiToGame(uint128 tokenId, uint256 amount_) public nonReentrant {
		require(!IDLC(dlc).blackList(msg.sender), notApproved);
		require(amount_ != 0, invalidAmount);
		
		_updateUserLocks(msg.sender);

		require(withdrawable[msg.sender] >= amount_, invalidAmount);
						
		withdrawable[msg.sender] -= amount_;
		balances[msg.sender] -= amount_;
		totalDeposited -= amount_;
				
		IGameWallet(gameWallet).deposit(tokenId, amount_);
				
		IDLC(dlc).burn(amount_);

		emit DepositGame(tokenId, amount_, msg.sender);
	}
	
	function withdrawFromGame(IGameWallet.WithdrawFromGame calldata data, bytes calldata signature) public nonReentrant {
		IGameWallet(gameWallet).withdraw(data, signature);

		IDLC(dlc).mint(address(this), data.amount);
		_deposit(msg.sender, data.amount, true, true);
		
		emit WithdrawGame(data.tokenId, data.amount, msg.sender, data.nonce);
	}

	/* ======== INTERNAL HELPER FUNCTIONS ======== */

	/**
	 *  @notice Update all currently locked tokens where the unlock time has passed
	 *  @param account_ address
	 */
	function _updateUserLocks(address account_) internal {
		LocksInfo storage locksInfo = locksInfos[account_];

		// return if user has no locks
		if (locksInfo.length == 0) return;

		// searching for expired locks from stratIndex untill first locked found or end reached
		while (locks[account_][locksInfo.start].unlockTime <= block.timestamp && locksInfo.start < locksInfo.length) {
			withdrawable[account_] += locks[account_][locksInfo.start].amount;
			locksInfo.start++;
		}

		// if end reached it means no lock found and we can reset startedIndex and clear all locks array
		if (locksInfo.start >= locksInfo.length) {
			locksInfo.start = 0;
			locksInfo.length = 0;
		}
	}

	/**
	 *  @notice Transfer tokens to user and penalty to xShade rewards distributor or wallet
	 *  @param tokensAmount_ uint256
	 *  @param penaltyAmount_ uint256
	 */
	function _sendTokensAndPenalty(uint256 tokensAmount_, uint256 penaltyAmount_) internal {
		if (penaltyAmount_ != 0 && penaltyReceiver != address(0)) {
			IERC20Upgradeable(dlc).safeTransfer(msg.sender, tokensAmount_);

			IERC20Upgradeable(dlc).safeIncreaseAllowance(penaltyReceiver, penaltyAmount_);
			IFeeDistributor(penaltyReceiver).notify(dlc, penaltyAmount_);
			
			emit PenaltyPaid(msg.sender, penaltyAmount_);			
		} else {
			IERC20Upgradeable(dlc).safeTransfer(msg.sender, tokensAmount_ + penaltyAmount_);
		}
		totalDeposited -= (tokensAmount_ + penaltyAmount_);
	}
	
	/* ======== EVENTS ======== */

	event Deposit(address indexed user, uint256 amount, bool locked);
	event Withdrawn(address indexed user, uint256 amount);
	event PenaltyPaid(address indexed user, uint256 amount);	
	event PenaltySet(address penaltyReceiver, uint256 penalty);	
	event SetDuration(uint64 duration, uint64 durationMultiplier);
	event SetGameWallet(address gameWallet);

	event DepositGame(uint128 indexed tokenId, uint256 amount, address account);
	event WithdrawGame(uint128 indexed tokenId, uint256 amount, address account, uint128 nonce);
}

// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { IDLC } from "./DLC.sol";
import { IFeeDistributor } from "./FeeDistributor.sol";
import { AccessControlled, IAuthority } from "./Authority.sol";

interface ITreasury {
    function deposit(address _token, uint256 _amount, uint256 _payout) external;
    function withdrawReserves(address _token, uint256 _amount) external;
    function tokenValue(address _token, uint256 _amount) external view returns (uint256 value_);    
    function burnDlcForReserves(address token_, uint256 amount_) external;
    function incurDebt(address token_, uint256 amount_) external;
    function repayDebtWithReserves(address token_, uint256 amount_) external;
}

contract Treasury is ITreasury, ReentrancyGuardUpgradeable, AccessControlled {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum STATUS {
        RESERVE_DEPOSITOR,
        RESERVE_SPENDER,
        RESERVE_TOKEN,
        RESERVE_MANAGER,        
        RESERVE_DEBTOR,
        DEBTOR 
    }
    
    address public dlc;
    address public reservesVault;   
    mapping(address => uint256) public maxHoldReserves;
    
    address[] public reservesRegistry;
    mapping(STATUS => mapping(address => bool)) public permissions;
    
    mapping(address => uint256) public debtLimit;
    mapping(address => uint256) public accountDebt;

    uint256 public totalDebt;
    
    string internal constant notAccepted = "Not accepted"; // not accepted
    string internal constant notApproved = "Not approved"; // not approved
    string internal constant invalidToken = "Invalid token"; // invalid token
    
    address public feeDistributor;    
    uint256 public liqFeePercent;
    uint256 public devTeamFeePercent;
    
    bool public mintDlc;

    /* ======== INITIALIZATION ======== */

    function initialize(
        address dlc_,
        address authority_,
        bool mintToken_,
        address reservesVault_
    ) public initializer {
        __AccessControlled_init(IAuthority(authority_));
        require(dlc_ != address(0));
        dlc = dlc_;
        mintDlc = mintToken_;
        reservesVault = reservesVault_;
    }

    /* ========== CONFIG ========== */
    
    function setFeeDistributor(address feeDistributor_, uint256 liqPercent_, uint256 devTeamFeePercent_) external onlyOperator {
        require(liqPercent_ + devTeamFeePercent_ <= 90, notAccepted);
        feeDistributor = feeDistributor_;
        liqFeePercent = liqPercent_;
        devTeamFeePercent = devTeamFeePercent_;
    }

    function setMintToken(bool state_) external onlyOperator {
        mintDlc = state_;
    }

    function setReservesVault(address reservesVault_) external onlyOperator {
        reservesVault = reservesVault_;
    }

    function setMaxHoldReserve(address token_, uint256 amount_) external onlyOperator {
        maxHoldReserves[token_] = amount_;
    }    

    /**
     * @notice set max debt for address
     * @param account_ address
     * @param limit_ uint256
     */
    function setDebtLimit(address account_, uint256 limit_) external onlyOperator {
        debtLimit[account_] = limit_;
    }

    /**
     * @notice enable permission
     * @param status_ STATUS
     * @param address_ address
     */
    function setPermission(
        STATUS status_,
        address address_,
        bool state_        
    ) external onlyOperator {
        permissions[status_][address_] = state_;

        if (status_ == STATUS.RESERVE_TOKEN) {
            (bool registered, uint256 index) = indexInReservesRegistry(address_);
            if (state_ && !registered) {
                reservesRegistry.push(address_);
            } 
            if (!state_ && registered) {
                reservesRegistry[index] = reservesRegistry[reservesRegistry.length - 1];
                reservesRegistry.pop();
            }             
        }
        emit Permissioned(address_, status_, state_);
    }
   
    /* ========== VIEW FUNCTIONS ========== */

    struct ReserveToken {
        address token;
        string symbol;
        uint8 decimals;
        uint256 balance;
        uint256 vaultBalance;
    }

    function contractData() public view returns (
		address _dlc, 
		bool _mintDlc,
		address _feeDistributor,			
		uint256 _liqFeePercent,
		uint256 _devTeamFeePercent,
		uint256 _balanceOfDLC,
        uint256 _totalReserves,
        uint256 _totalDebt,
        ReserveToken[] memory _reserveTokens
		) {
        _dlc = dlc;
		_mintDlc = mintDlc;
		_feeDistributor = feeDistributor;
		_liqFeePercent = liqFeePercent;
		_devTeamFeePercent = devTeamFeePercent;		
		_balanceOfDLC = balanceOfDLC();			
        _totalDebt = totalDebt;      
        
        _reserveTokens = new ReserveToken[](reservesRegistry.length);
        for (uint256 i = 0; i < reservesRegistry.length; i++) {
            address token = reservesRegistry[i];
            
            uint256 balance = IERC20MetadataUpgradeable(token).balanceOf(address(this));
            uint256 vaultBalance = IERC20Upgradeable(token).balanceOf(reservesVault);
            _totalReserves += tokenValue(token, balance + vaultBalance);

            _reserveTokens[i] = ReserveToken({
                token: token,
                symbol: IERC20MetadataUpgradeable(token).symbol(),
                decimals: IERC20MetadataUpgradeable(token).decimals(),
                balance: balance,
                vaultBalance: vaultBalance                             
            });
        }
	}

    /**
     * @notice check if registry contains address
     * @return (bool, uint256)
     */
    function indexInReservesRegistry(address token_) public view returns (bool, uint256) {        
        for (uint256 i = 0; i < reservesRegistry.length; i++) {
            if (token_ == reservesRegistry[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    function reservesRegistryCount() public view returns (uint256) {
        return reservesRegistry.length;
    }

    function tokenValue(address token_, uint256 amount_) public view returns (uint256 _value) {
        _value = (amount_ * (10**IERC20MetadataUpgradeable(dlc).decimals())) / (10**IERC20MetadataUpgradeable(token_).decimals());
    }

    function balanceOfDLC() public view returns (uint256) {
        return IDLC(dlc).balanceOf(address(this));
    }
    

    /* ========== MUTATIVE ========== */

    /**
     * @notice allow approved address to deposit an asset for DLC
     * @param amount_ uint256
     * @param token_ address
     */
    function deposit(
        address token_,
        uint256 amount_,
        uint256 payout_
    ) external nonReentrant {
        require(permissions[STATUS.RESERVE_TOKEN][token_], invalidToken); 
        require(permissions[STATUS.RESERVE_DEPOSITOR][msg.sender], notApproved);

        IERC20Upgradeable(token_).safeTransferFrom(msg.sender, address(this), amount_);

        uint256 value_ = tokenValue(token_, amount_); 
                               
        _mintDLC(payout_, true);        
        IERC20Upgradeable(dlc).safeTransfer(msg.sender, payout_);
        
        if (value_ >= 100 && amount_ >= 100 && feeDistributor != address(0)) {
            if (devTeamFeePercent != 0) {
                uint256 devTeamFee = (value_ * devTeamFeePercent) / 100;
                _mintDLC(devTeamFee, true);
                IERC20Upgradeable(dlc).safeIncreaseAllowance(feeDistributor, devTeamFee);
                IFeeDistributor(feeDistributor).notify(dlc, devTeamFee);                                
            }    
            if (liqFeePercent != 0) {                
                uint256 liqFee = (amount_ * liqFeePercent) / 100;     
                value_ -= (value_ * liqFeePercent) / 100;                             
                IERC20Upgradeable(token_).safeIncreaseAllowance(feeDistributor, liqFee);
                IFeeDistributor(feeDistributor).notify(token_, liqFee);   
            }            
        }

        _handleMaxHold(token_);

        emit Deposit(token_, amount_, value_);
    }

    /**
     * @notice allow approved address to burn DLC for reserves
     * @param amount_ uint256
     * @param token_ address
     */
    function burnDlcForReserves(address token_, uint256 amount_) external nonReentrant {
        require(permissions[STATUS.RESERVE_TOKEN][token_], notAccepted); 
        require(permissions[STATUS.RESERVE_SPENDER][msg.sender], notApproved);

        uint256 value = tokenValue(token_, amount_);
        IDLC(dlc).burnFrom(msg.sender, value);       

        IERC20Upgradeable(token_).safeTransfer(msg.sender, amount_);

        emit BurnDlcForReserves(token_, amount_, value);
    }

    /**
     * @notice allow approved address to withdraw assets
     * @param token_ address
     * @param amount_ uint256
     */
    function withdrawReserves(address token_, uint256 amount_) external nonReentrant {
        require(permissions[STATUS.RESERVE_TOKEN][token_], notAccepted);
        require(permissions[STATUS.RESERVE_MANAGER][msg.sender], notApproved);
        
        IERC20Upgradeable(token_).safeTransfer(msg.sender, amount_);

        emit WithdrawReserves(token_, amount_);
    }
    
    /**
     * @notice allow approved address to borrow 
     * @param amount_ uint256
     * @param token_ address
     */
    function incurDebt(address token_, uint256 amount_) external nonReentrant {
        uint256 value;
        if (token_ == dlc) {
            require(permissions[STATUS.DEBTOR][msg.sender], notApproved);
            value = amount_;
        } else {
            require(permissions[STATUS.RESERVE_DEBTOR][msg.sender], notApproved);
            require(permissions[STATUS.RESERVE_TOKEN][token_], notAccepted);
            value = tokenValue(token_, amount_);
        }
        require(value != 0, notAccepted);

        accountDebt[msg.sender] += value;
        require(accountDebt[msg.sender] <= debtLimit[msg.sender], "Treasury: exceeds limit");

        totalDebt += value;
        if (token_ == dlc) {            
            IERC20Upgradeable(dlc).safeTransfer(msg.sender, value);             
        } else {
            IERC20Upgradeable(token_).safeTransfer(msg.sender, amount_);
        }
        emit CreateDebt(msg.sender, token_, amount_, value);
    }

    /**
     * @notice allow approved address to repay borrowed reserves with reserves
     * @param amount_ uint256
     * @param token_ address
     */
    function repayDebtWithReserves(address token_, uint256 amount_) external nonReentrant {
        require(permissions[STATUS.RESERVE_DEBTOR][msg.sender], notApproved);
        require(permissions[STATUS.RESERVE_TOKEN][token_], notAccepted);
        
        IERC20Upgradeable(token_).safeTransferFrom(msg.sender, address(this), amount_);
        uint256 value = tokenValue(token_, amount_);

        accountDebt[msg.sender] -= value;
        totalDebt -= value;  

        _handleMaxHold(token_);
              
        emit RepayDebt(msg.sender, token_, amount_, value);
    }

    /**
     * @notice allow approved address to repay borrowed reserves with DLC
     * @param amount_ uint256
     */
    function repayDebtWithDLC(uint256 amount_) external nonReentrant {
        require(permissions[STATUS.RESERVE_DEBTOR][msg.sender] || permissions[STATUS.DEBTOR][msg.sender], notApproved);
        IDLC(dlc).burnFrom(msg.sender, amount_);

        accountDebt[msg.sender] -= amount_;
        totalDebt -= amount_;
       
        emit RepayDebt(msg.sender, dlc, amount_, amount_);
    }

    /* ========== INTERNAL ========== */ 

    function _handleMaxHold(
        address token_
    ) internal {
        uint256 _maxHoldReserve = maxHoldReserves[token_];
        uint256 balance = IERC20Upgradeable(token_).balanceOf(address(this));
        if (_maxHoldReserve != 0 && balance > _maxHoldReserve) {
            IERC20Upgradeable(token_).safeTransfer(reservesVault, balance - _maxHoldReserve); 
        }       
    }

    function _mintDLC(
        uint256 amount_,
        bool mintExtra_
    ) internal {
        if (mintDlc) {
            IDLC(dlc).mint(address(this), amount_);
        } else {
            uint256 balance = balanceOfDLC();
            if (amount_ > balance && mintExtra_) {
                IDLC(dlc).mint(address(this), amount_ - balance);
            }
            require(balanceOfDLC() >= amount_, notAccepted);
        }        
    }
    
    /* ========== EVENTS ========== */  

    event Deposit(address indexed token, uint256 amount, uint256 value);
    event BurnDlcForReserves(address indexed token, uint256 amount, uint256 value);
    event CreateDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
    event RepayDebt(address indexed debtor, address indexed token, uint256 amount, uint256 value);
    event WithdrawReserves(address indexed token, uint256 amount);
    event Permissioned(address addr, STATUS indexed status, bool result);    
}

// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { AccessControlled, IAuthority } from "./Authority.sol";

interface IDLC is IERC20MetadataUpgradeable {
	function mint(address account_, uint256 amount_) external;
	function burn(uint256 amount_) external;
	function burnFrom(address account_, uint256 amount_) external;
	function blackList(address account_) external returns (bool _state);
}

contract DLC is IDLC, ERC20Upgradeable, AccessControlled {
	uint8 private tokenDecimals;

	mapping(address => bool) public blackList;
	address[] public blackListArray;	
    
	function initialize(
        string memory _name, 
		string memory _symbol,
		uint8 _decimals,
		address authority_
    ) public initializer {
        __ERC20_init(_name, _symbol);
		__AccessControlled_init(IAuthority(authority_));
		tokenDecimals = _decimals;
    }
    
	function decimals() public view virtual override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (uint8) {
        return tokenDecimals;
    }

	function mint(address account_, uint256 amount_) external override onlyMinter {
		_mint(account_, amount_);
	}

	function burn(uint256 amount_) external override {
		
		_burn(msg.sender, amount_);
	}

	function burnFrom(address account_, uint256 amount_) external override {
		require(allowance(account_, msg.sender) >= amount_, "ERC20: burn amount exceeds allowance");
		_approve(account_, msg.sender, allowance(account_, msg.sender) - amount_);
		_burn(account_, amount_);
	}

	function blackListAccount(address account_, bool state_) external onlyOperator {
		blackList[account_] = state_;
        if (state_) {
            blackListArray.push(account_);
        } else {
            for (uint256 i = 0; i < blackListArray.length; i++) {
                if (blackListArray[i] == account_) {
                    blackListArray[i] = blackListArray[blackListArray.length - 1];
                    blackListArray.pop();
                    break;
                }
            }            
        }
		emit Blacklisted(account_, state_);
	}

	function blackListedCount() public view returns (uint256) {
		return blackListArray.length;
	}

	function _beforeTokenTransfer(
		address from_,
		address to_,
		uint256 amount_
	) internal override {
		require(!blackList[from_], "Sender blacklisted");
		require(!blackList[to_], "Recipient blacklisted");
		super._beforeTokenTransfer(from_, to_, amount_);
	}
	
	event Blacklisted(address indexed account, bool state);	
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { AccessControlled, IAuthority } from "./Authority.sol";

interface IFeeDistributor {
	function notify(address token, uint256 amount) external;
}

contract FeeDistributor is IFeeDistributor, AccessControlled {     
    using SafeERC20Upgradeable for IERC20Upgradeable;
		  
	function initialize(
        address authority_		
    ) public initializer {
        __AccessControlled_init(IAuthority(authority_));       
    }

    function notify(address token_, uint256 amount_) public {
        IERC20Upgradeable(token_).safeTransferFrom(msg.sender, address(this), amount_);				
    } 

}

// SPDX-License-Identifier: none
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import { INFTToken } from "./nft/NFTToken.sol";
import { AccessControlled, IAuthority } from "./Authority.sol";

interface IGameWallet {
    struct WithdrawFromGame {
		address token;
		uint128 tokenId;		
		uint256 amount; 
		address account;
		uint64 txDeadLine;
		uint64 nonce;
	}
	function deposit(uint128 tokenId, uint256 amount_) external;
    function withdraw(WithdrawFromGame calldata data, bytes calldata signature) external;
}

contract GameWallet is IGameWallet, AccessControlled {
	using SafeERC20Upgradeable for IERC20Upgradeable;

	string internal constant notAccepted = "Not accepted"; // not accepted
    string internal constant notApproved = "Not approved"; // not approved
	string internal constant notAllowed = "Not allowed"; // not approved	
	string internal constant invalidAmount = "Invalid amount"; // not approved
    string internal constant invalidParam = "Invalid param"; // invalid token	
	string internal constant invalid = "Not valid"; // invalid token

	/* ======== STATE VARIABLES ======== */

	address public dlc;
	address public signer;
    address public wallet;
    address public nftToken;
		
	struct GameDepositWithdraw {
		uint128 tokenId;
		uint256 amount;
		address account;
		uint64 nonce;		
	}
	GameDepositWithdraw[] public gameDeposits;
	GameDepositWithdraw[] public gameWithdraws;
	mapping(uint128 => uint256[]) public gameDepositsByTokenId; 
	mapping(uint128 => uint256[]) public gameWithdrawsByTokenId; 
	mapping(uint128 => bool) public gameWithdrawNonces; 

	uint256 public maxWithdrawAmount; 
	uint256 public withdrawDuration; 

	struct LastWitdraw {
		uint256 timestamp;
		uint256 amount;
	}
	mapping(uint128 => LastWitdraw) public lastWitdrawByTokenId; 
		
	/* ======== INITIALIZATION ======== */

    function initialize(
        address dlc_,
		address authority_,
		address signer_,
        address wallet_,
        address nftToken_
    ) public initializer {
        __AccessControlled_init(IAuthority(authority_));
        dlc = dlc_;
		setSigner(signer_);	
        setWallet(wallet_);
        nftToken = nftToken_;
	}

	/* ======== CONFIG ======== */

	function setSigner(address signer_) public onlyOperator {
		signer = signer_;
		emit SetSigner(signer_);
	}

    function setWallet(address wallet_) public onlyOperator {
		wallet = wallet_;
		emit SetWallet(wallet_);
	}

	function setMaxWithdrawPerDuration(uint256 maxWithdrawAmount_, uint256 withdrawDuration_) public onlyOperator {
		maxWithdrawAmount = maxWithdrawAmount_;
		withdrawDuration = withdrawDuration_;
		emit SetMaxWithdrawPerDuration(maxWithdrawAmount_, withdrawDuration_);
	}

	/* ======== VIEW ======== */

	function contractData()
		public
		view
		returns (
			uint256 _gameDepositsCount,
			uint256 _gameWithdrawsCount
		)
	{
		_gameDepositsCount = gameDeposits.length;	
		_gameWithdrawsCount = gameWithdraws.length;
	}

	function tokenData(uint128 tokenId_)
		public
		view
		returns (
			uint256 _depositsCount,
			uint256 _withdrawsCount
		)
	{
		_depositsCount = gameDepositsByTokenId[tokenId_].length;
		_withdrawsCount = gameWithdrawsByTokenId[tokenId_].length;
	}

	/* ======== USER ======== */
		
	//
	function deposit(uint128 tokenId, uint256 amount_) public {
		require(msg.sender == wallet, notApproved);
		require(amount_ != 0, invalidAmount);
        require(INFTToken(nftToken).exists(tokenId), notAllowed);
				
		gameDeposits.push(GameDepositWithdraw(tokenId, amount_, tx.origin, 0));
		gameDepositsByTokenId[tokenId].push(gameDeposits.length - 1);
		
		emit DepositGame(tokenId, amount_, tx.origin);
	}
	
	function withdraw(WithdrawFromGame calldata data, bytes calldata signature) public {
        require(msg.sender == wallet, notApproved);
		require(_isSignatureValid(signature, keccak256(abi.encode(data))), notAccepted);
		
		require(data.account == tx.origin, notApproved);		
		require(data.txDeadLine >= block.timestamp, notAllowed);
		require(!gameWithdrawNonces[data.nonce], invalidParam);
		require(INFTToken(nftToken).ownerOf(data.tokenId) == tx.origin, invalid);

		if (maxWithdrawAmount != 0) {
			if (withdrawDuration != 0) {
				LastWitdraw storage lastWitdraw = lastWitdrawByTokenId[data.tokenId];
				if (lastWitdraw.timestamp + withdrawDuration > block.timestamp) {
					lastWitdraw.amount += data.amount;
					require(lastWitdraw.amount <= maxWithdrawAmount, notAllowed);				
				} else {
					require(data.amount <= maxWithdrawAmount, notApproved);
					lastWitdraw.timestamp = block.timestamp;
					lastWitdraw.amount = data.amount;
				}
			} else {
				require(data.amount <= maxWithdrawAmount, invalidAmount);
			}
		}
				
		gameWithdrawNonces[data.nonce] = true;
		gameWithdraws.push(GameDepositWithdraw(data.tokenId, data.amount, tx.origin, data.nonce));
		gameWithdrawsByTokenId[data.tokenId].push(gameWithdraws.length - 1);

		emit WithdrawGame(data.tokenId, data.amount, tx.origin, data.nonce);
	}
	
	/* ======= AUXILIARY ======= */

	function _isSignatureValid(
		bytes memory signature,
		bytes32 dataHash
	) internal view returns (bool) {
		return ECDSAUpgradeable.recover(ECDSAUpgradeable.toEthSignedMessageHash(dataHash), signature) == signer;
	}
	
	/* ======== EVENTS ======== */
	
	event SetSigner(address signer);
    event SetWallet(address wallet);
	event SetMaxWithdrawPerDuration(uint256 maxWithdrawAmount, uint256 withdrawDuration);
	
	event DepositGame(uint128 indexed tokenId, uint256 amount, address account);
	event WithdrawGame(uint128 indexed tokenId, uint256 amount, address account, uint128 nonce);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../StringsUpgradeable.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", StringsUpgradeable.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: none

pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import { AccessControlled, IAuthority } from ".././Authority.sol";
import { IProxyRegistry } from "./ProxyRegistry.sol";

interface INFTToken is IERC721Upgradeable {
	function mint(address to, uint256 tokenId) external;
	function burn(uint256 tokenId) external;
	function exists(uint256 tokenId) external view returns (bool);
}

contract NFTToken is ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable, AccessControlled {	
	using StringsUpgradeable for uint256;

	IProxyRegistry public proxyRegistry;
			
	string public contractUri;
	string public baseUri;
		
	function initialize(
        string memory _name, 
		string memory _symbol,
		string memory _baseUri,
		address authority_
    ) public virtual initializer {
        __ERC721_init(_name, _symbol);
		__AccessControlled_init(IAuthority(authority_));		
		setBaseURI(_baseUri);		
    }

	function contractData() public view returns (
		string memory _name,
		string memory _symbol,
		string memory _contractUri,
		string memory _baseUri,		
		uint256 _totalSupply
	) {
		_name = name();
		_symbol = symbol();
		_contractUri = contractURI();
		_baseUri = baseURI();		
		_totalSupply = totalSupply();				
	}

	function accountData(address account) public view returns (
		uint256 _total,
		uint256[] memory _tokens		
	) {
		_total = balanceOf(account);
        if (_total != 0) {
            _tokens = new uint256[](_total);
            for (uint256 index = 0; index < _total; index++) {
                _tokens[index] = tokenOfOwnerByIndex(account, index);
            }
        }
	}

	function mint(address to, uint256 tokenId) public onlyNftMinter {
		_mint(to, tokenId);
	}
		
	function setContractURI(string memory uri) public onlyOperator {		
		contractUri = uri;
		emit SetContractURI(uri);
	}

	function contractURI() public view returns (string memory uri) {
		if (bytes(contractUri).length > 0) {
            uri = contractUri;
        }
		uri = baseUri;
	}

	function setBaseURI(string memory uri) public onlyOperator {
		baseUri = uri;
		emit SetBaseURI(uri);
	}

	function baseURI() public view returns (string memory) {
		return baseUri;
	}

	function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
		require(_exists(tokenId), "URI query for nonexistent token");		
		return string(abi.encodePacked(baseUri, tokenId.toString()));			
	}
		
	function setProxyRegistry(address _proxyRegistry) public onlyOperator {
		proxyRegistry = IProxyRegistry(_proxyRegistry);
		emit SetProxyRegistry(_proxyRegistry);
	}	

	function isApprovedForAll(address owner, address operator) public view virtual override(IERC721Upgradeable, ERC721Upgradeable) returns (bool) {
		// allow transfers for proxy contracts (marketplaces)
		if (address(proxyRegistry) != address(0) && proxyRegistry.proxies(owner) == operator) {
			return true;
		}	
		if (authority.nftMinters(operator)) {
			return true;
		}	
		return super.isApprovedForAll(owner, operator);
	}

	function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

	function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

	function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721EnumerableUpgradeable, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
	
	event SetMinter(address minter, bool state);
	event SetProxyRegistry(address proxyRegistry);	
	event SetContractURI(string uri);
	event SetBaseURI(string uri);	
	
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721Upgradeable.sol";
import "./IERC721EnumerableUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721EnumerableUpgradeable is Initializable, ERC721Upgradeable, IERC721EnumerableUpgradeable {
    function __ERC721Enumerable_init() internal onlyInitializing {
    }

    function __ERC721Enumerable_init_unchained() internal onlyInitializing {
    }
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165Upgradeable, ERC721Upgradeable) returns (bool) {
        return interfaceId == type(IERC721EnumerableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Upgradeable.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721EnumerableUpgradeable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721Upgradeable.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721Upgradeable.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC721Upgradeable.sol";
import "../../../utils/ContextUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be irreversibly burned (destroyed).
 */
abstract contract ERC721BurnableUpgradeable is Initializable, ContextUpgradeable, ERC721Upgradeable {
    function __ERC721Burnable_init() internal onlyInitializing {
    }

    function __ERC721Burnable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

interface IProxyRegistry {
	function proxies(address owner_) external view returns (address);
}

contract ProxyRegistry {
    // owner => operator
	mapping (address => address) public proxies;
	
	constructor() {}
		
    
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./extensions/IERC721MetadataUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/StringsUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721Upgradeable, IERC721MetadataUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Upgradeable.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721EnumerableUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721Upgradeable.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721MetadataUpgradeable is IERC721Upgradeable {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
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