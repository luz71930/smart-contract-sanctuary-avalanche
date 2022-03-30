// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;
pragma experimental ABIEncoderV2;

import "../interfaces/IJoeVoter.sol";
import "../interfaces/IJoeVoterProxy.sol";
import "../interfaces/IJoeChef.sol";
import "../interfaces/IBoostedJoeStrategyForLP.sol";
import "../interfaces/IVeJoeStaking.sol";
import "../lib/SafeERC20.sol";

library SafeProxy {
    function safeExecute(
        IJoeVoter voter,
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool success, bytes memory returnValue) = voter.execute(target, value, data);
        if (!success) revert("JoeVoterProxy::safeExecute failed");
        return returnValue;
    }
}

/**
 * @notice JoeVoterProxy is an upgradable contract.
 * Strategies interact with JoeVoterProxy and
 * JoeVoterProxy interacts with JoeVoter.
 * @dev For accounting reasons, there is one approved
 * strategy per Masterchef PID. In case of upgrade,
 * use a new proxy.
 */
contract JoeVoterProxy is IJoeVoterProxy {
    using SafeMath for uint256;
    using SafeProxy for IJoeVoter;
    using SafeERC20 for IERC20;

    struct FeeSettings {
        uint256 stakerFeeBips;
        uint256 boosterFeeBips;
        address stakerFeeReceiver;
        address boosterFeeReceiver;
    }

    uint256 internal constant BIPS_DIVISOR = 10000;

    uint256 public boosterFee;
    uint256 public stakerFee;
    address public stakerFeeReceiver;
    address public boosterFeeReceiver;
    address private constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address public constant JOE = 0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd;
    address public constant veJoeStaking = 0x25D85E17dD9e544F6E9F8D44F99602dbF5a97341;
    IJoeVoter public immutable voter;
    address public devAddr;

    // staking contract => pid => strategy
    mapping(address => mapping(uint256 => address)) private approvedStrategies;

    modifier onlyDev() {
        require(msg.sender == devAddr, "JoeVoterProxy::onlyDev");
        _;
    }

    modifier onlyStrategy(address _stakingContract, uint256 _pid) {
        require(approvedStrategies[_stakingContract][_pid] == msg.sender, "JoeVoterProxy::onlyStrategy");
        _;
    }

    constructor(
        address _voter,
        address _devAddr,
        FeeSettings memory _feeSettings
    ) {
        devAddr = _devAddr;
        boosterFee = _feeSettings.boosterFeeBips;
        stakerFee = _feeSettings.stakerFeeBips;
        stakerFeeReceiver = _feeSettings.stakerFeeReceiver;
        boosterFeeReceiver = _feeSettings.boosterFeeReceiver;
        voter = IJoeVoter(_voter);
    }

    /**
     * @notice Update devAddr
     * @param newValue address
     */
    function updateDevAddr(address newValue) external onlyDev {
        devAddr = newValue;
    }

    /**
     * @notice Add an approved strategy
     * @dev Very sensitive, restricted to devAddr
     * @dev Can only be set once per PID and staking contract (reported by the strategy)
     * @param _stakingContract address
     * @param _strategy address
     */
    function approveStrategy(address _stakingContract, address _strategy) external override onlyDev {
        uint256 pid = IBoostedJoeStrategyForLP(_strategy).PID();
        require(
            approvedStrategies[_stakingContract][pid] == address(0),
            "JoeVoterProxy::Strategy for PID already added"
        );
        approvedStrategies[_stakingContract][pid] = _strategy;
    }

    /**
     * @notice Update booster fee
     * @dev Restricted to devAddr
     * @param _boosterFeeBips new fee in bips (1% = 100 bips)
     */
    function setBoosterFee(uint256 _boosterFeeBips) external onlyDev {
        boosterFee = _boosterFeeBips;
    }

    /**
     * @notice Update staker fee
     * @dev Restricted to devAddr
     * @param _stakerFeeBips new fee in bips (1% = 100 bips)
     */
    function setStakerFee(uint256 _stakerFeeBips) external onlyDev {
        stakerFee = _stakerFeeBips;
    }

    /**
     * @notice Update booster fee receiver
     * @dev Restricted to devAddr
     * @param _boosterFeeReceiver address
     */
    function setBoosterFeeReceiver(address _boosterFeeReceiver) external onlyDev {
        boosterFeeReceiver = _boosterFeeReceiver;
    }

    /**
     * @notice Update staker fee receiver
     * @dev Restricted to devAddr
     * @param _stakerFeeReceiver address
     */
    function setStakerFeeReceiver(address _stakerFeeReceiver) external onlyDev {
        stakerFeeReceiver = _stakerFeeReceiver;
    }

    /**
     * @notice Deposit function
     * @dev Restricted to strategy with _pid
     * @param _pid PID
     * @param _stakingContract Masterchef
     * @param _token Deposit asset
     * @param _amount deposit amount
     */
    function deposit(
        uint256 _pid,
        address _stakingContract,
        address _token,
        uint256 _amount
    ) external override onlyStrategy(_stakingContract, _pid) {
        IERC20(_token).safeTransfer(address(voter), _amount);
        voter.safeExecute(_token, 0, abi.encodeWithSignature("approve(address,uint256)", _stakingContract, _amount));
        voter.safeExecute(_stakingContract, 0, abi.encodeWithSignature("deposit(uint256,uint256)", _pid, _amount));
        voter.safeExecute(_token, 0, abi.encodeWithSignature("approve(address,uint256)", _stakingContract, 0));
    }

    /**
     * @notice Calculation of reinvest fee (boost + staking)
     * @return reinvest fee
     */
    function reinvestFeeBips() external view override returns (uint256) {
        uint256 boostFee = 0;
        if (boosterFee > 0 && boosterFeeReceiver > address(0) && voter.depositsEnabled()) {
            boostFee = boosterFee;
        }

        uint256 stakingFee = 0;
        if (stakerFee > 0 && stakerFeeReceiver > address(0)) {
            stakingFee = stakerFee;
        }
        return boostFee.add(stakingFee);
    }

    /**
     * @notice Withdraw function
     * @dev Restricted to strategy with _pid
     * @param _pid PID
     * @param _stakingContract Masterchef
     * @param _token Deposit asset
     * @param _amount withdraw amount
     */
    function withdraw(
        uint256 _pid,
        address _stakingContract,
        address _token,
        uint256 _amount
    ) external override onlyStrategy(_stakingContract, _pid) {
        voter.safeExecute(_stakingContract, 0, abi.encodeWithSignature("withdraw(uint256,uint256)", _pid, _amount));
        voter.safeExecute(_token, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _amount));
    }

    /**
     * @notice Emergency withdraw function
     * @dev Restricted to strategy with _pid
     * @param _pid PID
     * @param _stakingContract Masterchef
     * @param _token Deposit asset
     */
    function emergencyWithdraw(
        uint256 _pid,
        address _stakingContract,
        address _token
    ) external override onlyStrategy(_stakingContract, _pid) {
        voter.safeExecute(_stakingContract, 0, abi.encodeWithSignature("emergencyWithdraw(uint256)", _pid));
        uint256 balance = IERC20(_token).balanceOf(address(voter));
        voter.safeExecute(_token, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, balance));
    }

    /**
     * @notice Pending rewards matching interface for strategy
     * @param _stakingContract Masterchef
     * @param _pid PID
     * @return pendingJoe
     * @return bonusTokenAddress
     * @return pendingBonusToken
     */
    function pendingRewards(address _stakingContract, uint256 _pid)
        external
        view
        override
        returns (
            uint256 pendingJoe,
            address bonusTokenAddress,
            uint256 pendingBonusToken
        )
    {
        (pendingJoe, bonusTokenAddress, , pendingBonusToken) = IJoeChef(_stakingContract).pendingTokens(
            _pid,
            address(voter)
        );
        uint256 reinvestFee = pendingJoe.mul(this.reinvestFeeBips()).div(BIPS_DIVISOR);

        return (pendingJoe.sub(reinvestFee), bonusTokenAddress, pendingBonusToken);
    }

    function poolBalance(address _stakingContract, uint256 _pid) external view override returns (uint256 balance) {
        return _poolBalance(_stakingContract, _pid);
    }

    /**
     * @notice Pool balance
     * @param _stakingContract Masterchef
     * @param _pid PID
     * @return balance in depositToken
     */
    function _poolBalance(address _stakingContract, uint256 _pid) internal view returns (uint256 balance) {
        (balance, ) = IJoeChef(_stakingContract).userInfo(_pid, address(voter));
    }

    /**
     * @notice Claim and distribute rewards
     * @dev Restricted to strategy with _pid
     * @param _stakingContract Masterchef
     * @param _pid PID
     */
    function claimReward(
        uint256 _pid,
        address _stakingContract,
        address _extraToken
    ) external override onlyStrategy(_stakingContract, _pid) {
        voter.safeExecute(_stakingContract, 0, abi.encodeWithSignature("deposit(uint256,uint256)", _pid, 0));
        _distributeReward(_extraToken);
    }

    /**
     * @notice Distribute rewards
     * @dev Restricted to strategy with _pid
     * @param _stakingContract Masterchef
     * @param _pid PID
     */
    function distributeReward(
        uint256 _pid,
        address _stakingContract,
        address _extraToken
    ) external override onlyStrategy(_stakingContract, _pid) {
        _distributeReward(_extraToken);
    }

    function _distributeReward(address _extraToken) private {
        if (_extraToken == WAVAX) {
            voter.wrapAvaxBalance();
        }

        uint256 pendingJoe = IERC20(JOE).balanceOf(address(voter));
        uint256 pendingExtraToken = _extraToken > address(0) ? IERC20(_extraToken).balanceOf(address(voter)) : 0;
        if (pendingJoe > 0) {
            uint256 boostFee = 0;
            if (boosterFee > 0 && boosterFeeReceiver > address(0) && voter.depositsEnabled()) {
                boostFee = pendingJoe.mul(boosterFee).div(BIPS_DIVISOR);
                voter.depositFromBalance(boostFee);
                IERC20(address(voter)).safeTransfer(boosterFeeReceiver, boostFee);
            }

            uint256 stakingFee = 0;
            if (stakerFee > 0 && stakerFeeReceiver > address(0)) {
                stakingFee = pendingJoe.mul(stakerFee).div(BIPS_DIVISOR);
                voter.safeExecute(
                    JOE,
                    0,
                    abi.encodeWithSignature("transfer(address,uint256)", stakerFeeReceiver, stakingFee)
                );
            }

            uint256 reward = pendingJoe.sub(boostFee).sub(stakingFee);
            voter.safeExecute(JOE, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, reward));
        }

        if (pendingExtraToken > 0) {
            voter.safeExecute(
                _extraToken,
                0,
                abi.encodeWithSignature("transfer(address,uint256)", msg.sender, pendingExtraToken)
            );
        }

        if (IVeJoeStaking(veJoeStaking).getPendingVeJoe(address(voter)) > 0) {
            voter.claimVeJOE();
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IJoeVoter {
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool, bytes memory);

    function veJOEBalance() external view returns (uint256);

    function wrapAvaxBalance() external returns (uint256);

    function depositsEnabled() external view returns (bool);

    function depositFromBalance(uint256 _value) external;

    function setStakingContract(address _stakingContract) external;

    function setVoterProxy(address _voterProxy) external;

    function claimVeJOE() external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IJoeVoterProxy {
    function withdraw(
        uint256 _pid,
        address _stakingContract,
        address _token,
        uint256 _amount
    ) external;

    function emergencyWithdraw(
        uint256 _pid,
        address _stakingContract,
        address _token
    ) external;

    function deposit(
        uint256 _pid,
        address _stakingContract,
        address _token,
        uint256 _amount
    ) external;

    function pendingRewards(address _stakingContract, uint256 _pid)
        external
        view
        returns (
            uint256,
            address,
            uint256
        );

    function poolBalance(address _stakingContract, uint256 _pid) external view returns (uint256);

    function claimReward(
        uint256 _pid,
        address _stakingContract,
        address _extraToken
    ) external;

    function distributeReward(
        uint256 _pid,
        address _stakingContract,
        address _extraToken
    ) external;

    function approveStrategy(address _stakingContract, address _strategy) external;

    function reinvestFeeBips() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IJoeChef {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function emergencyWithdraw(uint256 _pid) external;

    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 pendingJoe,
            address bonusTokenAddress,
            string memory bonusTokenSymbol,
            uint256 pendingBonusToken
        );

    function userInfo(uint256 pid, address user)
        external
        view
        returns (uint256 amount, uint256 rewardDebt);

    function poolInfo(uint256 pid)
        external
        view
        returns (
            address lpToken,
            uint256 accJoePerShare,
            uint256 lastRewardTimestamp,
            uint256 allocPoint,
            address rewarder
        );
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IBoostedJoeStrategyForLP {
    function PID() external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IVeJoeStaking {
    function deposit(uint256 _amount) external;

    function claim() external;

    function getPendingVeJoe(address _user) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

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
    using SafeMath for uint256;
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
        // solhint-disable-next-line max-line-length
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
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
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
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

// From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/Math.sol
// Subject to the MIT license.

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.8.0;

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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