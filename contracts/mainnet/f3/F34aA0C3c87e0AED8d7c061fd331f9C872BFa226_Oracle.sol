//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "../refs/CoreRef.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

contract Oracle is CoreRef {
    using SignedSafeMath for int256;

    struct Feed {
        address aggregator;
        uint8 baseDecimals;
    }
    // token address => Feed
    mapping(address => Feed) public feeds;

    constructor(
        address _core,
        address[] memory _tokens,
        uint8[] memory _baseDecimals,
        address[] memory _aggregators
    ) public CoreRef(_core) {
        _setFeeds(_tokens, _baseDecimals, _aggregators);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice(address token) public view returns (int256 price) {
        Feed storage feed = feeds[token];
        require(feed.aggregator != address(0), "Oracle:: price feed does not exist");
        (, int256 price, , , ) = AggregatorV3Interface(feed.aggregator).latestRoundData();
        uint8 quoteDecimals = AggregatorV3Interface(feed.aggregator).decimals();
        uint8 baseDecimals = feed.baseDecimals;
        price = scalePrice(price, quoteDecimals, baseDecimals);
        return price;
    }

    function scalePrice(
        int256 _price,
        uint8 _quoteDecimals,
        uint8 _baseDecimals
    ) internal pure returns (int256) {
        if (_quoteDecimals < _baseDecimals) {
            return _price.mul(int256(10**uint256(_baseDecimals - _quoteDecimals)));
        } else if (_quoteDecimals > _baseDecimals) {
            return _price.div(int256(10**uint256(_quoteDecimals - _baseDecimals)));
        }
        return _price;
    }

    function setFeeds(
        address[] memory _tokens,
        uint8[] memory _baseDecimals,
        address[] memory _aggregators
    ) public onlyGovernor {
        _setFeeds(_tokens, _baseDecimals, _aggregators);
    }

    function _setFeeds(
        address[] memory _tokens,
        uint8[] memory _baseDecimals,
        address[] memory _aggregators
    ) internal {
        for (uint256 i = 0; i < _tokens.length; i++) {
            feeds[_tokens[i]] = Feed(_aggregators[i], _baseDecimals[i]);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/ICore.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

abstract contract CoreRef is Pausable {
    event CoreUpdate(address indexed _core);

    ICore private _core;

    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    constructor(address core_) public {
        _core = ICore(core_);
    }

    modifier onlyGovernor() {
        require(_core.isGovernor(msg.sender), "CoreRef::onlyGovernor: Caller is not a governor");
        _;
    }

    modifier onlyGuardian() {
        require(_core.isGuardian(msg.sender), "CoreRef::onlyGuardian: Caller is not a guardian");
        _;
    }

    modifier onlyGuardianOrGovernor() {
        require(
            _core.isGovernor(msg.sender) || _core.isGuardian(msg.sender),
            "CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor"
        );
        _;
    }

    modifier onlyMultistrategy() {
        require(_core.isMultistrategy(msg.sender), "CoreRef::onlyMultistrategy: Caller is not a multistrategy");
        _;
    }

    modifier onlyTimelock() {
        require(_core.hasRole(TIMELOCK_ROLE, msg.sender), "CoreRef::onlyTimelock: Caller is not a timelock");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(_core.hasRole(role, msg.sender), "CoreRef::onlyRole: Not permit");
        _;
    }

    modifier onlyRoleOrOpenRole(bytes32 role) {
        require(
            _core.hasRole(role, address(0)) || _core.hasRole(role, msg.sender),
            "CoreRef::onlyRoleOrOpenRole: Not permit"
        );
        _;
    }

    modifier onlyNonZeroAddress(address targetAddress) {
        require(targetAddress != address(0), "address cannot be set to 0x0");
        _;
    }

    modifier onlyNonZeroAddressArray(address[] calldata targetAddresses) {
        for (uint256 i = 0; i < targetAddresses.length; i++) {
            require(targetAddresses[i] != address(0), "address cannot be set to 0x0");
        }
        _;
    }

    function setCore(address core_) external onlyGovernor {
        _core = ICore(core_);
        emit CoreUpdate(core_);
    }

    function pause() public onlyGuardianOrGovernor {
        _pause();
    }

    function unpause() public onlyGuardianOrGovernor {
        _unpause();
    }

    function core() public view returns (ICore) {
        return _core;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface ICore {
    function isGovernor(address _address) external view returns (bool);

    function isGuardian(address _address) external view returns (bool);

    function isMultistrategy(address _address) external view returns (bool);

    function hasRole(bytes32 role, address account) external view returns (bool);

    function createRole(bytes32 role, bytes32 adminRole) external;

    function grantGovernor(address governor) external;

    function grantGuardian(address guardian) external;

    function grantMultistrategy(address multistrategy) external;

    function grantRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}