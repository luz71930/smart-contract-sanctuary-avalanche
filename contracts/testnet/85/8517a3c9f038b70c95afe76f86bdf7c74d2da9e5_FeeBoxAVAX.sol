/**
 *Submitted for verification at testnet.snowtrace.io on 2022-05-24
*/

// Sources flattened with hardhat v2.9.2 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/[email protected]

// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
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
}


// File @openzeppelin/contracts/token/ERC20/[email protected]

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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


// File @openzeppelin/contracts/utils/[email protected]

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


// File @openzeppelin/contracts/token/ERC20/utils/[email protected]

// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;


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


// File contracts/common/Basic.sol


pragma solidity >=0.8.0 <0.9.0;

abstract contract Basic {
    /**
     * @dev Return ethereum address
     */
    address public constant avaxAddr =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Return Wrapped AVAX address
    address public constant wavaxAddr =
        0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    /// @dev Return call deadline
    uint256 internal constant TIME_INTERVAL = 3600;

    function safeTransferAVAX(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "helper::safeTransferAVAX: AVAX transfer failed");
    }
}


// File contracts/interfaces/IWAVAX.sol


pragma solidity >=0.8.0 <0.9.0;

interface IWAVAX {
    function allowance(address, address) external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function decimals() external view returns (uint8);

    function deposit() external payable;

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);

    function withdraw(uint256 wad) external;
}


// File contracts/adapters/base/AdapterBase.sol


pragma solidity >=0.8.0 <0.9.0;





abstract contract AdapterBase is Basic, Ownable {
    using SafeERC20 for IERC20;

    address public ADAPTER_MANAGER;
    address public immutable ADAPTER_ADDRESS;
    address public immutable TIMELOCK_ADDRESS;
    string public ADAPTER_NAME;
    mapping(address => mapping(address => bool)) private approved;

    fallback() external payable {}

    receive() external payable {}

    modifier onlyAdapterManager() {
        require(
            ADAPTER_MANAGER == msg.sender,
            "Caller is not the adapterManager."
        );
        _;
    }

    modifier onlyDelegation() {
        require(ADAPTER_ADDRESS != address(this), "Only For delegatecall.");
        _;
    }

    modifier onlyTimeLock() {
        require(TIMELOCK_ADDRESS == msg.sender, "Caller is not the timelock.");
        _;
    }

    constructor(
        address _adapterManager,
        address _timeLock,
        string memory _name
    ) {
        ADAPTER_MANAGER = _adapterManager;
        ADAPTER_ADDRESS = address(this);
        TIMELOCK_ADDRESS = _timeLock;
        ADAPTER_NAME = _name;
    }

    function pullTokensIfNeeded(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        if (_amount == 0) return;
        require(_token != address(0) && _token != avaxAddr);
        uint256 balance = IERC20(_token).balanceOf(_from);
        uint256 currentAmount = balance < _amount ? balance : _amount;
        IERC20(_token).safeTransferFrom(_from, address(this), currentAmount);
    }

    function approveToken(
        address _token,
        address _spender,
        uint256 _amount
    ) internal {
        if (_amount == 0) return;
        if (!approved[_token][_spender]) {
            IERC20 token = IERC20(_token);
            token.safeApprove(_spender, 0);
            token.safeApprove(_spender, type(uint256).max);
            approved[_token][_spender] = true;
        }
    }

    /// @dev get the token from sender, and approve to the user in one step
    function pullAndApprove(
        address _token,
        address _from,
        address _spender,
        uint256 _amount
    ) internal {
        pullTokensIfNeeded(_token, _from, _amount);
        approveToken(_token, _spender, _amount);
    }

    function toCallback(
        address _target,
        bytes4 _selector,
        bytes memory _callData
    ) internal {
        (bool success, bytes memory returnData) = _target.call(
            abi.encodeWithSignature(
                "callback(bytes)",
                abi.encodePacked(_selector, _callData)
            )
        );
        require(success, string(returnData));
    }

    //Handle when someone else accidentally transfers assets to this contract
    function sweep(address[] memory tokens, address receiver)
        external
        onlyTimeLock
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == address(0)) continue;
            uint256 amount = IERC20(token).balanceOf(address(this));
            if (amount > 0) {
                IERC20(token).safeTransfer(receiver, amount);
            }
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            safeTransferAVAX(receiver, balance);
        }
    }
}


// File contracts/interfaces/benqi/ISAVAX.sol


pragma solidity >=0.8.0 <0.9.0;

interface ISAVAX {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

    function ROLE_ACCRUE_REWARDS() external view returns (bytes32);

    function ROLE_DEPOSIT() external view returns (bytes32);

    function ROLE_PAUSE() external view returns (bytes32);

    function ROLE_PAUSE_MINTING() external view returns (bytes32);

    function ROLE_RESUME() external view returns (bytes32);

    function ROLE_RESUME_MINTING() external view returns (bytes32);

    function ROLE_SET_TOTAL_POOLED_AVAX_CAP() external view returns (bytes32);

    function ROLE_WITHDRAW() external view returns (bytes32);

    function accrueRewards(uint256 amount) external;

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function cancelPendingUnlockRequests() external;

    function cancelRedeemableUnlockRequests() external;

    function cancelUnlockRequest(uint256 unlockIndex) external;

    function cooldownPeriod() external view returns (uint256);

    function decimals() external pure returns (uint8);

    function deposit() external;

    // function getPaginatedUnlockRequests(
    //     address user,
    //     uint256 from,
    //     uint256 to
    // ) external view returns (tuple[], uint256[]);

    function getPooledAvaxByShares(uint256 shareAmount)
        external
        view
        returns (uint256);

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function getRoleMember(bytes32 role, uint256 index)
        external
        view
        returns (address);

    function getRoleMemberCount(bytes32 role) external view returns (uint256);

    function getSharesByPooledAvax(uint256 avaxAmount)
        external
        view
        returns (uint256);

    function getUnlockRequestCount(address user)
        external
        view
        returns (uint256);

    function grantRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

    function historicalExchangeRateTimestamps(uint256)
        external
        view
        returns (uint256);

    function historicalExchangeRatesByTimestamp(uint256)
        external
        view
        returns (uint256);

    function initialize(uint256 _cooldownPeriod, uint256 _redeemPeriod)
        external;

    function mintingPaused() external view returns (bool);

    function name() external pure returns (string memory);

    function pause() external;

    function pauseMinting() external;

    function paused() external view returns (bool);

    function redeem() external;

    function redeem(uint256 unlockIndex) external;

    function redeemOverdueShares() external;

    function redeemOverdueShares(uint256 unlockIndex) external;

    function redeemPeriod() external view returns (uint256);

    function renounceRole(bytes32 role, address account) external;

    function requestUnlock(uint256 shareAmount) external;

    function resume() external;

    function resumeMinting() external;

    function revokeRole(bytes32 role, address account) external;

    function setCooldownPeriod(uint256 newCooldownPeriod) external;

    // function setHistoricalExchangeRatesByTimestamp(
    //     uint256[] timestamps,
    //     uint256[] exchangeRates
    // ) external;

    function setRedeemPeriod(uint256 newRedeemPeriod) external;

    function setTotalPooledAvaxCap(uint256 newTotalPooledAvaxCap) external;

    function stakerCount() external view returns (uint256);

    function submit() external payable returns (uint256);

    function symbol() external pure returns (string memory);

    function totalPooledAvax() external view returns (uint256);

    function totalPooledAvaxCap() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function userSharesInCustody(address) external view returns (uint256);

    function userUnlockRequests(address, uint256)
        external
        view
        returns (uint256 startedAt, uint256 shareAmount);

    function withdraw(uint256 amount) external;
}


// File contracts/adapters/feeBox/VerifierBasic.sol


pragma solidity >=0.8.0 <0.9.0;


contract VerifierBasic {
    mapping(address => uint256) public nonces;

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
        // implicitly return (r, s, v)
    }

    function getEthBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }
}


// File contracts/adapters/feeBox/FeeBoxAVAX.sol


pragma solidity >=0.8.0 <0.9.0;



/*
Users deposit some avax/wavax as gas fee to support automatic contract calls in the background
*/
contract Verifier is VerifierBasic {
    function getMessageHash(
        address _account,
        uint256 _amount,
        bool _access,
        uint256 _deadline,
        uint256 _nonce
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(_account, _amount, _access, _deadline, _nonce)
            );
    }

    function verify(
        address _signer,
        address _account,
        uint256 _amount,
        bool _access,
        uint256 _deadline,
        bytes memory signature
    ) internal returns (bool) {
        require(_deadline >= block.timestamp, "Signature expired");
        bytes32 messageHash = getMessageHash(
            _account,
            _amount,
            _access,
            _deadline,
            nonces[_account]++
        );
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }
}

contract FeeBoxAVAX is Verifier, AdapterBase {
    using SafeERC20 for IERC20;

    event FeeBoxAVAXDeposit(
        address account,
        uint256 amount,
        uint256 consumedAmount
    );
    event FeeBoxAVAXWithdraw(
        address account,
        uint256 amount,
        uint256 consumedAmount
    );

    address private balanceController;
    address private feeReceiver;

    mapping(address => uint256) public wavaxBlance;

    constructor(address _adapterManager, address _timeLock)
        AdapterBase(_adapterManager, _timeLock, "FeeBoxAVAX")
    {}

    function initialize(address _balanceController, address _feeReceiver)
        external
    {
        balanceController = _balanceController;
        feeReceiver = _feeReceiver;
    }

    modifier onlySigner() {
        require(balanceController == msg.sender, "!Signer");
        _;
    }

    function setAdapterManager(address newAdapterManger) external onlyTimeLock {
        ADAPTER_MANAGER = newAdapterManger;
    }

    function setBalance(address[] memory users, uint256[] memory balance)
        external
        onlySigner
    {
        require(users.length == balance.length, "length error!");
        for (uint256 i = 0; i < users.length; i++) {
            wavaxBlance[users[i]] = balance[i];
        }
    }

    function paymentCheck(address account, uint256 consumedAmount)
        external
        onlySigner
    {
        require(wavaxBlance[account] >= consumedAmount);
        wavaxBlance[account] -= consumedAmount;
        safeTransferAVAX(feeReceiver, consumedAmount);
    }

    function depositWithPermit(address account, bytes calldata encodedData)
        external
        payable
        onlyAdapterManager
    {
        (
            uint256 amount,
            uint256 consumedAmount,
            bool access,
            uint256 deadline,
            bytes memory signature
        ) = abi.decode(encodedData, (uint256, uint256, bool, uint256, bytes));
        require(access, "Not deposit method.");
        require(
            verify(
                balanceController,
                account,
                consumedAmount,
                access,
                deadline,
                signature
            ),
            "Verify failed!"
        );
        if (amount != 0) {
            pullTokensIfNeeded(wavaxAddr, account, amount);
            IWAVAX(wavaxAddr).withdraw(amount);
        }
        require(
            wavaxBlance[account] + amount + msg.value >= consumedAmount,
            "Insolvent!"
        );

        wavaxBlance[account] =
            wavaxBlance[account] +
            amount +
            msg.value -
            consumedAmount;
        if (consumedAmount != 0) {
            safeTransferAVAX(feeReceiver, consumedAmount);
        }
        emit FeeBoxAVAXDeposit(account, amount + msg.value, consumedAmount);
    }

    function withdrawWithPermit(address account, bytes calldata encodedData)
        external
        onlyAdapterManager
    {
        (
            bool isNative,
            uint256 amount,
            uint256 consumedAmount,
            bool access,
            uint256 deadline,
            bytes memory signature
        ) = abi.decode(
                encodedData,
                (bool, uint256, uint256, bool, uint256, bytes)
            );
        require(!access, "Not withdraw method.");
        require(
            verify(
                balanceController,
                account,
                consumedAmount,
                access,
                deadline,
                signature
            ),
            "Verify failed!"
        );

        require(wavaxBlance[account] >= consumedAmount + amount, "Insolvent!");
        wavaxBlance[account] = wavaxBlance[account] - amount - consumedAmount;
        if (isNative) {
            safeTransferAVAX(account, amount);
        } else {
            IWAVAX(wavaxAddr).deposit{value: amount}();
            IERC20(wavaxAddr).safeTransfer(account, amount);
        }
        if (consumedAmount != 0) {
            safeTransferAVAX(feeReceiver, consumedAmount);
        }

        emit FeeBoxAVAXWithdraw(account, amount, consumedAmount);
    }

    function userInfo(address account) external view returns (uint256) {
        return wavaxBlance[account];
    }
}