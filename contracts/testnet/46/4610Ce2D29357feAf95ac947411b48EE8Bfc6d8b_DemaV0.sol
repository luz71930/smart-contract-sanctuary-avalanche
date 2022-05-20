// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IMoonKey {
    function mint(uint256 amount) external payable;
    function getNextBatchPrice(uint256 amount) external view returns (uint256 batchPrice);
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function balanceOf(address owner) external view returns (uint256 balance);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract DemaV0 is Ownable, IERC721Receiver {
    uint256 public mintPrice = 2 ether;

    struct Purchase {
        address buyer;
        string metaHash;
        uint256 paid;
    }
    mapping(uint256 => Purchase) public _purchases;

    IMoonKey public moonkey;
    uint256 internal _currentIndex;

    constructor(address moonkeyAddress_) Ownable() {
        moonkey = IMoonKey(moonkeyAddress_);
    }

    function getNextBatchPrice(uint256 amount) public view returns (uint256 batchPrice) {
        uint256 totalPrice = 0;
        for (uint8 i = 0; i < amount; i++) {
            totalPrice += mintPrice;
        }
        return totalPrice;
    }

    function getBatchPrice(uint256 amountPurchases, uint256 amountMoonkeys) public view returns (uint256 batchPrice) {
        return getNextBatchPrice(amountPurchases) + moonkey.getNextBatchPrice(amountMoonkeys);
    }

    function setPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    function purchase(string[] memory metaHashs, uint256 amountMoonkeys) public payable {
        uint256 total_cost = getBatchPrice(metaHashs.length,amountMoonkeys);
        require(msg.value >= total_cost, "Pay more");
        uint256 excess = msg.value - total_cost;

        for (uint256 i = 0; i < metaHashs.length; i++) {
            _purchases[_currentIndex + i] = Purchase(tx.origin, metaHashs[i], mintPrice);
            _currentIndex++;
        }

        if (amountMoonkeys > 0) {
            moonkey.mint{value:moonkey.getNextBatchPrice(amountMoonkeys)}(amountMoonkeys);
            uint256 balance = moonkey.balanceOf(address(this));
            for (uint256 index = 0; index < balance; index++) {
                uint256 id = moonkey.tokenOfOwnerByIndex(address(this), index);
                moonkey.transferFrom(address(this), msg.sender, id);
            }
        }

        if (excess > 0) {
            payable(tx.origin).transfer(excess);
        }
    }

    function withdrawBalance() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
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