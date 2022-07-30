// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CoinFlip is VRFConsumerBaseV2, Ownable, ReentrancyGuard {
    VRFCoordinatorV2Interface COORDINATOR;
    IERC20 private _tokenContract;

    address public TAX_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 public TOTAL_TAX_AMOUNT = 0;

    uint64 private s_subscriptionId;
    address private vrfCoordinator = 0xd5D517aBE5cF79B7e95eC98dB0f0277788aFF634;
    address private linkTokenAddress =
        0x5947BB275c521040051D82396192181b413227A3;
    bytes32 private keyHash =
        0x89630569c9567e43c4fe7b1633258df9f2531b62f2352fa721cf3162ee4ecb46;
    address s_owner;

    struct RequestBatchData {
        uint128 amountBets;
        uint128 blockNumber;
    }

    mapping(uint256 => RequestBatchData) public reqIdToReqData;
    mapping(uint256 => uint256[]) public reqIdToFlipId;

    struct CoinFlipStruct {
        uint256 ID;
        address betStarter;
        uint256 bet;
        uint256 reward;
        uint8 choice;
        uint256 winTax;
        uint256 loseTax;
        bool isSettled;
        uint168 blockPlaced;
    }

    mapping(uint256 => CoinFlipStruct) public flipIdToFlipStructs;

    uint256 public requestId;

    uint256 public coinFlipIDCounter = 1;
    event CoinFlipped(
        uint256 indexed coinFlipID,
        address indexed starter,
        bool isWin,
        uint256 result
    );

    event FlipStarted(
        uint256 indexed coinFlipID,
        address indexed starter,
        uint8 choice,
        uint256 bet,
        uint256 winnableAmount
    );

    event FlipRefunded(
        uint256 indexed coinFlipID,
        address indexed starter,
        uint256 amount
    );

    // Controls
    bool public paused = false;
    uint32 private callbackGasLimit = 200000;
    uint32 public checkFlipGasLimit = 40000;
    uint16 private requestConfirmations = 10;
    uint32 private maxBetsPerBatch = 3;
    uint256 public winTax = 150; // 15% will go tax address rest to winner
    uint256 public loseTax = 150; // 15% will go to tax address rest to this contract

    address public c_owner;

    constructor(
        uint64 subscriptionId,
        address tokenAddress,
        address taxAddress
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        c_owner = msg.sender;
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
        _tokenContract = IERC20(tokenAddress);
        TAX_ADDRESS = address(taxAddress);
    }

    // VRF Functions ====================================================
    function reqRandomness() internal returns (uint256) {
        RequestBatchData memory data = reqIdToReqData[requestId];
        if (
            data.blockNumber + requestConfirmations - 1 <= block.number ||
            data.amountBets >= maxBetsPerBatch
        ) {
            requestId = COORDINATOR.requestRandomWords(
                keyHash,
                s_subscriptionId,
                requestConfirmations,
                callbackGasLimit,
                1
            );
            reqIdToReqData[requestId] = RequestBatchData({
                amountBets: 1,
                blockNumber: uint128(block.number)
            });
        } else {
            reqIdToReqData[requestId].amountBets++;
        }

        return requestId;
    }

    function expand(uint256 randomValue, uint256 n)
        internal
        pure
        returns (uint256[] memory expandedValues)
    {
        expandedValues = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            expandedValues[i] = uint256(keccak256(abi.encode(randomValue, i)));
        }

        return expandedValues;
    }

    function fulfillRandomWords(
        uint256 _requestId, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        checkFlip(
            _requestId,
            expand(randomWords[0], reqIdToFlipId[_requestId].length)
        );
    }

    //  ==============================================================================

    // Choice = 1 | 0 => 1 = Head, 0 = Tail
    function coinFlip(uint256 amountCHRO, uint8 choice) external nonReentrant {
        require(!paused, "Feature paused by admin");

        address theBetStarter = msg.sender;
        uint256 reward = (amountCHRO * (2 * 1000 - winTax)) / 1000;
        uint256 coinFlipID = coinFlipIDCounter;

        // CHECK TOKEN BALANCE
        require(
            _tokenContract.balanceOf(address(theBetStarter)) >= amountCHRO,
            "Not enough balance"
        );
        require(
            _tokenContract.allowance(address(theBetStarter), address(this)) >=
                amountCHRO,
            "Not enough allowance"
        );

        // CHECK TREASURY BALANCE
        require(
            _tokenContract.balanceOf(address(this)) >= reward,
            "Not enough treasury"
        );

        // TF TO THIS ADDRESS FIRST, to prevent user draining their balance after flipping coin, since VRF results are async
        _tokenContract.transferFrom(msg.sender, address(this), amountCHRO);

        reqIdToFlipId[reqRandomness()].push(coinFlipID);

        uint256 _winTax = 0;
        uint256 _loseTax = 0;
        if (winTax > 0) {
            _winTax = amountCHRO * 2 - reward;
        }

        if (loseTax > 0) {
            _loseTax = (amountCHRO / 1000) * loseTax;
        }

        flipIdToFlipStructs[coinFlipID] = CoinFlipStruct(
            coinFlipID,
            msg.sender,
            amountCHRO,
            reward,
            choice,
            _winTax,
            _loseTax,
            false,
            uint168(block.number)
        );

        emit FlipStarted(coinFlipID, msg.sender, choice, amountCHRO, reward);
        coinFlipIDCounter += 1;
    }

    function checkFlip(uint256 _requestId, uint256[] memory randomNumbers)
        internal
    {
        uint256[] memory pendingBetIds = reqIdToFlipId[_requestId];

        uint256 i;
        for (i = 0; i < pendingBetIds.length; i++) {
            // The VRFManager is optimized to prevent this from happening, this check is just to make sure that if it happens the tx will not be reverted, if this result is true the bet will be refunded manually later
            if (gasleft() <= checkFlipGasLimit) {
                return;
            }
            _checkFlip(pendingBetIds[i], randomNumbers[i]);
        }
    }

    function _checkFlip(uint256 flipId, uint256 _randomNumber) internal {
        CoinFlipStruct storage c = flipIdToFlipStructs[flipId];

        uint256 result = _randomNumber % 2; // will be either 1 or 0
        bool isWin = result == c.choice;
        c.isSettled = true;

        if (isWin) {
            // Win Tax
            if (c.winTax > 0) {
                _playTax(c.winTax);
            }

            // TF REWARD
            _tokenContract.transfer(c.betStarter, c.reward);
        } else {
            // Lose Tax
            if (c.loseTax > 0) {
                _playTax(c.loseTax);
            }

            // Rest will stay in this contract
        }

        emit CoinFlipped(c.ID, c.betStarter, isWin, result);
    }

    function _playTax(uint256 _amount) internal {
        require(
            _tokenContract.balanceOf(address(this)) >= _amount,
            "Not enough treasury"
        );

        _tokenContract.transfer(address(TAX_ADDRESS), _amount);
        TOTAL_TAX_AMOUNT += _amount;
    }

    function isRefundable(uint256 flipId)
        public
        view
        returns (bool, string memory)
    {
        CoinFlipStruct storage c = flipIdToFlipStructs[flipId];
        if (c.bet <= 0) return (false, "Flip does not exist");
        if (c.isSettled == true) return (false, "Flip settled");
        if (block.number <= c.blockPlaced + requestConfirmations + 5)
            return (false, "Wait before requesting refund");

        return (true, "");
    }

    function refundBet(uint256 flipId) external nonReentrant {
        CoinFlipStruct storage c = flipIdToFlipStructs[flipId];

        (bool refundable, string memory reason) = isRefundable(flipId);
        require(refundable, reason);

        c.isSettled = true;

        _tokenContract.transfer(c.betStarter, c.bet);
        emit FlipRefunded(flipId, c.betStarter, c.bet);
    }

    // ADMIN FUNCTIONS ===========================================
    function setWinTax(uint256 _winTax) external onlyOwner {
        winTax = _winTax;
    }

    function setloseTax(uint256 _loseTax) external onlyOwner {
        loseTax = _loseTax;
    }

    function setTokenContract(address _tokenAddress) external onlyOwner {
        _tokenContract = IERC20(_tokenAddress);
    }

    function setPaused(bool state) external onlyOwner {
        paused = state;
    }

    function setTaxAddress(address _taxAddress) external onlyOwner {
        TAX_ADDRESS = address(_taxAddress);
    }

    function setCallbackGasLimit(uint32 value) external onlyOwner {
        callbackGasLimit = value;
    }

    function setRequestConfirmations(uint16 value) external onlyOwner {
        requestConfirmations = value;
    }

    function setMaxBetsPerBatch(uint32 value) external onlyOwner {
        maxBetsPerBatch = value;
    }

    function setCheckFlipGasLimit(uint32 value) external onlyOwner {
        checkFlipGasLimit = value;
    }

    function emergencyTransfer(address _contractAddress, uint256 _amount)
        external
        onlyOwner
    {
        if (
            _contractAddress ==
            address(0x0000000000000000000000000000000000000000)
        ) {
            payable(address(c_owner)).transfer(_amount);
        } else {
            IERC20 tokenContract = IERC20(_contractAddress);
            tokenContract.transfer(address(c_owner), _amount);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
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
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
}

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