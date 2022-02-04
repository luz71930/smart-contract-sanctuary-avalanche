/**
 *Submitted for verification at testnet.snowtrace.io on 2022-02-04
*/

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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

// File: contracts/IFungibleToken.sol


pragma solidity ^0.8.2;


interface IFungibleToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

// File: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol


// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
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

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


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

// File: contracts/Points.sol


pragma solidity ^0.8.2;




interface ILottery {
    function checkpoints(uint256) external view returns (uint256);

    function deposits(uint256) external view returns (address);

    function tokensStaked(address staker)
        external
        view
        returns (uint256[] memory);
    
    function nftSupply() external view returns (uint);
}

contract Points is Ownable {
    struct _DateTime {
        uint16 year;
        uint8 month;
        uint8 day;
        uint8 hour;
        uint8 minute;
        uint8 second;
        uint8 weekday;
    }

    struct Leaderboard {
      address holder;
      uint tokenId;
      uint points;
    }

    using SafeMath for uint8;
    using SafeMath for uint16;
    using SafeMath for uint256;

    ILottery public lotteryContract;
    IFungibleToken public tokenContract;

    uint256[] public s4e1;
    uint256[] public s3e1;
    uint256[] public s2e1;
    uint256[] public s1e1;
    uint256[] public s4e2;
    uint256[] public s3e2;
    uint256[] public s2e2;
    uint256[] public s1e2;

    uint256 constant DAY_IN_SECONDS = 86400;
    uint8 constant E1_MULTIPLIER = 2;
    uint8 constant E2_MULTIPLIER = 1;
    uint256 constant LEAP_YEAR_IN_SECONDS = 31622400;
    uint16 constant ORIGIN_YEAR = 1970;
    uint8 constant S1 = 1;
    uint8 constant S2 = 2;
    uint8 constant S3 = 4;
    uint8 constant S4 = 8;
    uint256 constant YEAR_IN_SECONDS = 31536000;

    mapping(uint256 => uint256) public checkpointsRedeemed;
    mapping(uint16 => mapping (uint8 => address)) public winners;

    constructor(address _lotteryContract, address _tokenContract) {
        lotteryContract = ILottery(_lotteryContract);
        tokenContract = IFungibleToken(_tokenContract);
    }

  function convertPointsToTickets(uint16 year, uint8 month) external view returns (address[] memory tickets) {
    Leaderboard[] memory results = getLeaderboard(year, month);
    uint points =  findTotalPoints(results);

    tickets = new address[](points);
    uint z = 0;
    for (uint x = 0; x < results.length; x++) {
      for (uint y = 0; y < results[x].points; y++) {
        tickets[z] = results[x].holder;
        z++;
      }
    }

    return tickets;
  }

    function drawLastMonthWinner(address[] calldata tickets) external onlyOwner returns (address winner) {
      uint timeNow = block.timestamp;
      timeNow = timeNow - (7 * DAY_IN_SECONDS); //draw must take place before the 7th day of the new month
      _DateTime memory lastMonth = parseTimestamp(timeNow);

      require(winners[lastMonth.year][lastMonth.month] == address(0), "The winner has already been drawn for last month");
      
      uint winningIndex = random(tickets.length);
      
      winner = tickets[winningIndex];

      setWinner(lastMonth.year, lastMonth.month, winner);

      return winner;
    } 

    function findTotalPoints(Leaderboard[] memory leaderboard) internal pure returns (uint total) {
      for (uint x = 0; x < leaderboard.length; x++) {
        total += leaderboard[x].points;
      }

      return total;
    }

    function fundLottery() payable external {

    }

    function getLeaderboard(uint16 year, uint8 month) public view returns (Leaderboard[] memory) {
      uint startOfMonth = firstDayOfMonth(year, month);
      month++;
      if (month > 12) year++;
      uint endOfMonth = firstDayOfMonth(year, month);
      uint staked = 0;
      for (uint y = 0; y < lotteryContract.nftSupply(); y++) {
        if (lotteryContract.deposits(y) != address(0)) {
          staked++;
        }
      }

      Leaderboard[] memory results = new Leaderboard[](staked);

      staked = 0;
      for (uint x = 0; x < lotteryContract.nftSupply(); x++) {
        if (lotteryContract.deposits(x) != address(0)) {
          uint timestamp = block.timestamp;
          if (timestamp > endOfMonth) {
            timestamp = endOfMonth;
          }
          uint daysVested;
          if (lotteryContract.checkpoints(x) > startOfMonth) {
            daysVested = (timestamp - lotteryContract.checkpoints(x)).div(DAY_IN_SECONDS);
          } else {
            daysVested = (timestamp - startOfMonth).div(DAY_IN_SECONDS);
          }
          
          //4 star - edition 1
          for (uint s = 0; s < s4e1.length; s++) {
            if (x == s4e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S4).mul(daysVested));
              staked++;
              break;
            }
          }

          //3 star - edition 1
          for (uint s = 0; s < s3e1.length; s++) {
            if (x == s3e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S3).mul(daysVested));
              staked++;
              break;
            }
          }

          //2 star - edition 1
          for (uint s = 0; s < s2e1.length; s++) {
            if (x == s2e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S2).mul(daysVested));
              staked++;
              break;
            }
          }

          //1 star - edition 1
          for (uint s = 0; s < s1e1.length; s++) {
            if (x == s1e1[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E1_MULTIPLIER.mul(S1).mul(daysVested));
              staked++;
              break;
            }
          }

          //4 star - edition 2
          for (uint s = 0; s < s4e2.length; s++) {
            if (x == s4e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S4).mul(daysVested));
              staked++;
              break;
            }
          }

          //3 star - edition 2
          for (uint s = 0; s < s3e2.length; s++) {
            if (x == s3e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S3).mul(daysVested));
              staked++;
              break;
            }
          }

          //2 star - edition 2
          for (uint s = 0; s < s2e2.length; s++) {
            if (x == s2e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S2).mul(daysVested));
              staked++;
              break;
            }
          }

          //1 star - edition 2
          for (uint s = 0; s < s1e2.length; s++) {
            if (x == s1e2[s]) {
              results[staked] = Leaderboard(lotteryContract.deposits(x), x, E2_MULTIPLIER.mul(S1).mul(daysVested));
              staked++;
              break;
            }
          }
        }
      }

      return results;
    }

    function getRedeemable(uint256 tokenId) public view returns (uint256) {
        address holder = lotteryContract.deposits(tokenId);
        require(holder != address(0), "This token has not been staked");
        uint256 lastRedeemed = checkpointsRedeemed[tokenId];
        uint256 lastStaked = lotteryContract.checkpoints(tokenId);
        if (lastStaked > lastRedeemed) {
            lastRedeemed = lastStaked;
        }
        uint256 timeDifference = block.timestamp.sub(lastRedeemed);

        return timeDifference.div(DAY_IN_SECONDS);
    }

    function random(uint max) public view returns (uint) {
        return uint(blockhash(block.number - 1)) % max;
    }

    function redeem(uint256 tokenId) external {
        address holder = lotteryContract.deposits(tokenId);
        require(holder == msg.sender, "You are not the owner of this token");
        uint256 eligible = getRedeemable(tokenId);
        tokenContract.mint(msg.sender, eligible * (uint256(10)**18));
        checkpointsRedeemed[tokenId] = block.timestamp;
    }

    function redeemLottery() external {
      _DateTime memory timeNow = parseTimestamp(block.timestamp);
      uint8 month = timeNow.month;
      uint16 year = timeNow.year;
      month--;
      if (month == 0) {
        month = 12;
        year--;
      }

      require(msg.sender == winners[year][month], "You are not the winner of the last lottery");

      payable(msg.sender).transfer(address(this).balance);
    }

    function redeemLotteryAdmin() external onlyOwner {
      payable(msg.sender).transfer(address(this).balance);
    }

    function set4e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s4e1.push(values[x]);
        }
    }

    function set3e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s3e1.push(values[x]);
        }
    }

    function set2e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s2e1.push(values[x]);
        }
    }

    function set1e1(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s1e1.push(values[x]);
        }
    }

    function set4e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s4e2.push(values[x]);
        }
    }

    function set3e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s3e2.push(values[x]);
        }
    }

    function set2e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s2e2.push(values[x]);
        }
    }

    function set1e2(uint256[] memory values) external onlyOwner {
        for (uint256 x = 0; x < values.length; x++) {
            s1e2.push(values[x]);
        }
    }

    //date functions
    function getYear(uint256 timestamp) public pure returns (uint16) {
        uint256 secondsAccountedFor = 0;
        uint16 year;
        uint256 numLeapYears;

        // Year
        year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
        numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor +=
            YEAR_IN_SECONDS *
            (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > timestamp) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            } else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }
        return year;
    }

    function isLeapYear(uint16 year) public pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function leapYearsBefore(uint256 year) public pure returns (uint256) {
        year -= 1;
        return year / 4 - year / 100 + year / 400;
    }

    function firstDayOfMonth(uint year, uint month) public pure returns (uint) {
      int _year = int(year);
      int _month = int(month);
      int _day = 1;

      int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
        - 2440588; //offset constant from 1970/1/1

      return uint(__days) * DAY_IN_SECONDS;
    }

    function getDaysInMonth(uint8 month, uint16 year)
        public
        pure
        returns (uint8)
    {
        if (
            month == 1 ||
            month == 3 ||
            month == 5 ||
            month == 7 ||
            month == 8 ||
            month == 10 ||
            month == 12
        ) {
            return 31;
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        } else if (isLeapYear(year)) {
            return 29;
        } else {
            return 28;
        }
    }

    function getHour(uint timestamp) public pure returns (uint8) {
      return uint8((timestamp / 60 / 60) % 24);
    }

    function getMinute(uint timestamp) public pure returns (uint8) {
      return uint8((timestamp / 60) % 60);
    }

    function getSecond(uint timestamp) public pure returns (uint8) {
      return uint8(timestamp % 60);
    }

    function parseTimestamp(uint256 timestamp)
        internal
        pure
        returns (_DateTime memory dt)
    {
        uint256 secondsAccountedFor = 0;
        uint256 buf;
        uint8 i;

        // Year
        dt.year = getYear(timestamp);
        buf = leapYearsBefore(dt.year) - leapYearsBefore(ORIGIN_YEAR);

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
        secondsAccountedFor += YEAR_IN_SECONDS * (dt.year - ORIGIN_YEAR - buf);

        // Month
        uint256 secondsInMonth;
        for (i = 1; i <= 12; i++) {
            secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dt.year);
            if (secondsInMonth + secondsAccountedFor > timestamp) {
                dt.month = i;
                break;
            }
            secondsAccountedFor += secondsInMonth;
        }

        // Day
        for (i = 1; i <= getDaysInMonth(dt.month, dt.year); i++) {
            if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
                dt.day = i;
                break;
            }
            secondsAccountedFor += DAY_IN_SECONDS;
        }

        // Hour
        dt.hour = getHour(timestamp);

        // Minute
        dt.minute = getMinute(timestamp);

        // Second
        dt.second = getSecond(timestamp);
    }

    function setWinner(uint16 year, uint8 month, address winner) internal onlyOwner {
      winners[year][month] = winner;
    }
}