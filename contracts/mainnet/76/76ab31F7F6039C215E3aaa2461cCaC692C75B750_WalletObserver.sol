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
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be payed in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
    constructor() {
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

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
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
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
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
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
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
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
        address owner = ERC721.ownerOf(tokenId);

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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
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
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

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
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
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
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
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
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
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
        uint256 length = ERC721.balanceOf(to);
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

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/ERC721Royalty.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../common/ERC2981.sol";
import "../../../utils/introspection/ERC165.sol";

/**
 * @dev Extension of ERC721 with the ERC2981 NFT Royalty Standard, a standardized way to retrieve royalty payment
 * information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC721Royalty is ERC2981, ERC721 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally clears the royalty information for the token.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/common/ERC2981.sol)

pragma solidity ^0.8.0;

import "../../interfaces/IERC2981.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the NFT Royalty Standard, a standardized way to retrieve royalty payment information.
 *
 * Royalty information can be specified globally for all token ids via {_setDefaultRoyalty}, and/or individually for
 * specific token ids via {_setTokenRoyalty}. The latter takes precedence over the first.
 *
 * Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000, meaning the
 * fee is specified in basis points by default.
 *
 * IMPORTANT: ERC-2981 only specifies a way to signal royalty information and does not enforce its payment. See
 * https://eips.ethereum.org/EIPS/eip-2981#optional-royalty-payments[Rationale] in the EIP. Marketplaces are expected to
 * voluntarily pay royalties together with sales, but note that this standard is not yet widely supported.
 *
 * _Available since v4.5._
 */
abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        override
        returns (address, uint256)
    {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev The denominator with which to interpret the fee set in {_setTokenRoyalty} and {_setDefaultRoyalty} as a
     * fraction of the sale price. Defaults to 10000 so fees are expressed in basis points, but may be customized by an
     * override.
     */
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `tokenId` must be already minted.
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
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

import "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./helpers/OwnerRecovery.sol";
import "./implementation/PyramidPointer.sol";
import "./implementation/LiquidityPoolManagerPointer.sol";

error ZeroAddressError();
error PermissionDenied();
error PyramidDoesNotExist();

struct PyramidEntity {
  uint256 id;
  string name;
  uint256 creationTime;
  uint256 lastProcessingTimestamp;
  uint256 rewardMult;
  uint256 pyramidValue;
  uint256 totalClaimed;
  bool exists;
  bool isMerged;
}

struct PyramidInfoEntity {
  PyramidEntity pyramid;
  uint256 id;
  uint256 pendingRewards;
  uint256 rewardPerDay;
  uint256 compoundDelay;
  uint256 pendingRewardsGross;
  uint256 rewardPerDayGross;
}

struct Tier {
  uint32 level;
  uint32 slope;
  uint32 dailyAPR;
  uint32 claimFee;
  uint32 claimBurnFee;
  uint32 compoundFee;
  string name;
  string imageURI;
}

contract PyramidsManager is
  ERC721,
  ERC721Enumerable,
  ERC721Royalty,
  Pausable,
  Ownable,
  OwnerRecovery,
  ReentrancyGuard,
  PyramidPointer,
  LiquidityPoolManagerPointer
{
  using Counters for Counters.Counter;

  struct TierStorage {
    uint256 rewardMult;
    uint256 amountLockedInTier;
    bool exists;
  }

  Counters.Counter private _pyramidCounter;
  mapping(uint256 => PyramidEntity) private _pyramids;
  mapping(uint256 => TierStorage) private _tierTracking;
  uint256[] _tiersTracked;

  uint256 public creationMinPrice;
  uint256 public compoundDelay;
  uint256 public processingFee;

  Tier[4] public tiers;

  uint256 public totalValueLocked;

  uint256 public burnedFromRenaming;
  uint256 public burnedFromMerging;

  address public whitelist;

  modifier onlyPyramidOwner() {
    address sender = _msgSender();
    if (sender == (address(0))) revert ZeroAddressError();
    if (!isOwnerOfPyramids(sender)) revert PermissionDenied();
    _;
  }

  modifier checkPermissions(uint256 _pyramidId) {
    address sender = _msgSender();
    if (!pyramidExists(_pyramidId)) revert PyramidDoesNotExist();
    if (!isApprovedOrOwnerOfPyramid(sender, _pyramidId))
      revert PermissionDenied();
    _;
  }

  modifier checkPermissionsMultiple(uint256[] memory _pyramidIds) {
    address sender = _msgSender();
    for (uint256 i = 0; i < _pyramidIds.length; i++) {
      if (!pyramidExists(_pyramidIds[i])) revert PyramidDoesNotExist();
      if (!isApprovedOrOwnerOfPyramid(sender, _pyramidIds[i]))
        revert PermissionDenied();
    }
    _;
  }

  modifier verifyName(string memory pyramidName) {
    require(
      bytes(pyramidName).length > 1 && bytes(pyramidName).length < 32,
      "Pyramids: Incorrect name length, must be between 2 to 31"
    );
    _;
  }

  modifier onlyWhitelist() {
    address sender = _msgSender();
    if (sender == address(0)) revert ZeroAddressError();
    if (sender != whitelist) revert PermissionDenied();
    _;
  }

  event Compound(
    address indexed account,
    uint256 indexed pyramidId,
    uint256 amountToCompound
  );
  event Cashout(
    address indexed account,
    uint256 indexed pyramidId,
    uint256 rewardAmount
  );

  event CompoundAll(
    address indexed account,
    uint256[] indexed affectedPyramids,
    uint256 amountToCompound
  );
  event CashoutAll(
    address indexed account,
    uint256[] indexed affectedPyramids,
    uint256 rewardAmount
  );

  event Create(
    address indexed account,
    uint256 indexed newPyramidId,
    uint256 amount
  );

  event Rename(
    address indexed account,
    string indexed previousName,
    string indexed newName
  );

  event Merge(
    uint256[] indexed pyramidIds,
    string indexed name,
    uint256 indexed previousTotalValue
  );

  constructor(
    IPyramid _pyramid,
    address _whitelist,
    ILiquidityPoolManager _lpManager
  ) ERC721("Pyramid Money", "PRMDNFT") {
    if (address(_pyramid) == address(0)) revert ZeroAddressError();

    pyramid = _pyramid;
    whitelist = _whitelist;
    liquidityPoolManager = _lpManager;
    changeNodeMinPrice(10_000 * (10**18)); // 10,000 PRMD
    changeCompoundDelay(43200); // 12h
    changeProcessingFee(2); // 2%

    string
      memory ipfsBaseURI = "ipfs://QmSiikJn6mPevMg9zsyPmRnSy2KqvhKPZ5huubCTZnFZV3/";
    Tier[4] memory _tiers = [
      Tier({
        level: 2000,
        slope: 500,
        dailyAPR: 15,
        claimFee: 80,
        claimBurnFee: 0,
        compoundFee: 40,
        name: "Bronze",
        imageURI: string(abi.encodePacked(ipfsBaseURI, "bronze.jpg"))
      }),
      Tier({
        level: 4000,
        slope: 500,
        dailyAPR: 20,
        claimFee: 40,
        claimBurnFee: 0,
        compoundFee: 20,
        name: "Silver",
        imageURI: string(abi.encodePacked(ipfsBaseURI, "silver.jpg"))
      }),
      Tier({
        level: 8000,
        slope: 500,
        dailyAPR: 25,
        claimFee: 20,
        claimBurnFee: 0,
        compoundFee: 10,
        name: "Gold",
        imageURI: string(abi.encodePacked(ipfsBaseURI, "gold.jpg"))
      }),
      Tier({
        level: 16000,
        slope: 0,
        dailyAPR: 30,
        claimFee: 10,
        claimBurnFee: 0,
        compoundFee: 0,
        name: "Diamond",
        imageURI: string(abi.encodePacked(ipfsBaseURI, "diamond.jpg"))
      })
    ];

    changeTiers(_tiers);
    setDefaultRoyalty(msg.sender, 2500); // 25% NFT sale royalties
  }

  function setDefaultRoyalty(address receiver, uint96 feeNumerator)
    public
    onlyOwner
  {
    _setDefaultRoyalty(receiver, feeNumerator);
  }

  function setTokenRoyalty(
    uint256 tokenId,
    address receiver,
    uint96 feeNumerator
  ) public onlyOwner {
    _setTokenRoyalty(tokenId, receiver, feeNumerator);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override(ERC721)
    returns (string memory)
  {
    PyramidEntity memory _pyramid = _pyramids[tokenId];
    (uint256 tier, string memory _type, string memory image) = getTierMetadata(
      _pyramid.rewardMult
    );

    bytes memory dataURI = abi.encodePacked(
      '{"name": "',
      _pyramid.name,
      '", "image": "',
      image,
      '", "attributes": [',
      '{"trait_type": "tier", "value": "',
      Strings.toString(tier),
      '"}, {"trait_type": "type", "value": "',
      _type,
      '"}, {"trait_type": "tokens", "value": "',
      Strings.toString(_pyramid.pyramidValue / (10**18)),
      '"}]}'
    );

    return
      string(
        abi.encodePacked(
          "data:application/json;base64,",
          Base64.encode(dataURI)
        )
      );
  }

  function renamePyramid(uint256 _pyramidId, string memory pyramidName)
    external
    nonReentrant
    onlyPyramidOwner
    checkPermissions(_pyramidId)
    whenNotPaused
    verifyName(pyramidName)
  {
    address account = _msgSender();
    PyramidEntity storage pyramid = _pyramids[_pyramidId];
    require(pyramid.pyramidValue > 0, "Error: Pyramid is empty");
    (uint256 newPyramidValue, uint256 feeAmount) = getPercentageOf(
      pyramid.pyramidValue,
      processingFee // 2% processing fee for renaming pyramids
    );
    logTier(pyramid.rewardMult, -int256(feeAmount));
    burnedFromRenaming += feeAmount;
    pyramid.pyramidValue = newPyramidValue;
    string memory previousName = pyramid.name;
    pyramid.name = pyramidName;
    emit Rename(account, previousName, pyramidName);
  }

  function mergePyramids(
    uint256[] memory _pyramidIds,
    string memory pyramidName
  )
    external
    nonReentrant
    onlyPyramidOwner
    checkPermissionsMultiple(_pyramidIds)
    whenNotPaused
    verifyName(pyramidName)
  {
    address account = _msgSender();
    require(
      _pyramidIds.length > 1,
      "PyramidsManager: At least 2 Pyramids must be selected in order for the merge to work"
    );

    uint256 lowestTier = 0;
    uint256 totalValue = 0;

    for (uint256 i = 0; i < _pyramidIds.length; i++) {
      PyramidEntity storage pyramidFromIds = _pyramids[_pyramidIds[i]];
      require(
        isProcessable(pyramidFromIds),
        "PyramidsManager: For the process to work, all selected pyramids must be compoundable. Try again later."
      );

      // Compound the pyramid
      compoundReward(pyramidFromIds.id);

      // Use this tier if it's lower than current
      if (lowestTier == 0) {
        lowestTier = pyramidFromIds.rewardMult;
      } else if (lowestTier > pyramidFromIds.rewardMult) {
        lowestTier = pyramidFromIds.rewardMult;
      }

      // Additionate the locked value
      totalValue += pyramidFromIds.pyramidValue;

      // Burn the pyramid permanently
      _burn(pyramidFromIds.id);
    }
    require(
      lowestTier >= tiers[0].level,
      "PyramidsManager: Something went wrong with the tiers"
    );

    (uint256 newPyramidValue, uint256 feeAmount) = getPercentageOf(
      totalValue,
      processingFee // Burn 2% from the value of across the final amount
    );
    burnedFromMerging += feeAmount;

    // Mint the amount to the user
    pyramid.accountReward(account, newPyramidValue);

    // Create the pyramid (which will burn that amount)
    uint256 currentPyramidId = createPyramidWithTokens(
      pyramidName,
      newPyramidValue
    );

    // Set tier, logTier and increase
    PyramidEntity storage _pyramid = _pyramids[currentPyramidId];
    _pyramid.isMerged = true;
    if (lowestTier != tiers[0].level) {
      logTier(_pyramid.rewardMult, -int256(_pyramid.pyramidValue));
      _pyramid.rewardMult = lowestTier;
      logTier(_pyramid.rewardMult, int256(_pyramid.pyramidValue));
    }

    emit Merge(_pyramidIds, pyramidName, totalValue);
  }

  function createPyramidWithTokens(
    string memory pyramidName,
    uint256 pyramidValue
  )
    public
    nonReentrant
    whenNotPaused
    verifyName(pyramidName)
    returns (uint256)
  {
    return _createPyramidWithTokens(_msgSender(), pyramidName, pyramidValue, 0);
  }

  function whitelistCreatePyramidWithTokens(
    string memory pyramidName,
    uint256 pyramidValue,
    address account,
    uint256 tierLevel
  )
    external
    nonReentrant
    whenNotPaused
    verifyName(pyramidName)
    onlyWhitelist
    returns (uint256)
  {
    uint256 pyramidId = _createPyramidWithTokens(
      account,
      pyramidName,
      pyramidValue,
      tierLevel
    );

    return pyramidId;
  }

  function _createPyramidWithTokens(
    address sender,
    string memory pyramidName,
    uint256 pyramidValue,
    uint256 tierLevel
  ) private returns (uint256) {
    require(
      pyramidValue >= creationMinPrice,
      "Pyramids: Pyramid value set below minimum"
    );
    require(
      isNameAvailable(sender, pyramidName),
      "Pyramids: Name not available"
    );
    require(
      pyramid.balanceOf(sender) >= pyramidValue,
      "Pyramids: Balance too low for creation"
    );

    // Burn the tokens used to mint the NFT
    pyramid.accountBurn(sender, pyramidValue);

    // Increment the total number of tokens
    _pyramidCounter.increment();

    uint256 newPyramidId = _pyramidCounter.current();
    uint256 currentTime = block.timestamp;

    // Add this to the TVL
    totalValueLocked += pyramidValue;
    logTier(tiers[tierLevel].level, int256(pyramidValue));

    // Add Pyramid
    _pyramids[newPyramidId] = PyramidEntity({
      id: newPyramidId,
      name: pyramidName,
      creationTime: currentTime,
      lastProcessingTimestamp: currentTime,
      rewardMult: tiers[tierLevel].level,
      pyramidValue: pyramidValue,
      totalClaimed: 0,
      exists: true,
      isMerged: false
    });

    // Assign the Pyramid to this account
    _mint(sender, newPyramidId);

    emit Create(sender, newPyramidId, pyramidValue);

    return newPyramidId;
  }

  function cashoutReward(uint256 _pyramidId)
    external
    nonReentrant
    onlyPyramidOwner
    checkPermissions(_pyramidId)
    whenNotPaused
  {
    address account = _msgSender();
    (
      uint256 amountToReward,
      uint256 feeAmount,
      uint256 feeBurnAmount
    ) = _getPyramidCashoutRewards(_pyramidId);
    _cashoutReward(amountToReward, feeAmount, feeBurnAmount);

    emit Cashout(account, _pyramidId, amountToReward);
  }

  function cashoutAll() external nonReentrant onlyPyramidOwner whenNotPaused {
    address account = _msgSender();
    uint256 rewardsTotal = 0;
    uint256 feesTotal = 0;
    uint256 feeBurnTotal = 0;

    uint256[] memory pyramidsOwned = getPyramidIdsOf(account);
    for (uint256 i = 0; i < pyramidsOwned.length; i++) {
      (
        uint256 amountToReward,
        uint256 feeAmount,
        uint256 feeBurnAmount
      ) = _getPyramidCashoutRewards(pyramidsOwned[i]);
      rewardsTotal += amountToReward;
      feesTotal += feeAmount;
      feeBurnTotal += feeBurnAmount;
    }
    _cashoutReward(rewardsTotal, feesTotal, feeBurnTotal);

    emit CashoutAll(account, pyramidsOwned, rewardsTotal);
  }

  function compoundReward(uint256 _pyramidId)
    public
    nonReentrant
    onlyPyramidOwner
    checkPermissions(_pyramidId)
    whenNotPaused
  {
    address account = _msgSender();

    (uint256 amountToCompound, uint256 feeAmount) = _getPyramidCompoundRewards(
      _pyramidId
    );
    require(
      amountToCompound > 0,
      "Pyramids: You must wait until you can compound again"
    );
    if (feeAmount > 0) {
      pyramid.liquidityReward(feeAmount);
    }

    emit Compound(account, _pyramidId, amountToCompound);
  }

  function compoundAll() external nonReentrant onlyPyramidOwner whenNotPaused {
    address account = _msgSender();
    uint256 feesAmount = 0;
    uint256 amountsToCompound = 0;
    uint256[] memory pyramidsOwned = getPyramidIdsOf(account);
    uint256[] memory pyramidsAffected = new uint256[](pyramidsOwned.length);

    for (uint256 i = 0; i < pyramidsOwned.length; i++) {
      (
        uint256 amountToCompound,
        uint256 feeAmount
      ) = _getPyramidCompoundRewards(pyramidsOwned[i]);
      if (amountToCompound > 0) {
        pyramidsAffected[i] = pyramidsOwned[i];
        feesAmount += feeAmount;
        amountsToCompound += amountToCompound;
      } else {
        delete pyramidsAffected[i];
      }
    }

    require(amountsToCompound > 0, "Pyramids: No rewards to compound");
    if (feesAmount > 0) {
      pyramid.liquidityReward(feesAmount);
    }

    emit CompoundAll(account, pyramidsAffected, amountsToCompound);
  }

  // Private reward functions

  function _getPyramidCashoutRewards(uint256 _pyramidId)
    private
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    PyramidEntity storage pyramid = _pyramids[_pyramidId];

    if (!isProcessable(pyramid)) {
      return (0, 0, 0);
    }

    uint256 reward = calculateReward(pyramid);
    pyramid.totalClaimed += reward;

    (
      uint256 takeAsFeePercentage,
      uint256 burnFromFeePercentage
    ) = getCashoutDynamicFee(pyramid.rewardMult);
    (uint256 amountToReward, uint256 takeAsFee) = getPercentageOf(
      reward,
      takeAsFeePercentage + burnFromFeePercentage
    );
    (, uint256 burnFromFee) = getPercentageOf(reward, burnFromFeePercentage);

    (, uint256 currentTier) = getTier(pyramid.rewardMult);
    uint256 nextTier;
    if (currentTier > 0) {
      nextTier = currentTier - 1;
    } else {
      nextTier = 0;
    }
    logTier(pyramid.rewardMult, -int256(pyramid.pyramidValue));
    pyramid.rewardMult = tiers[nextTier].level;
    logTier(pyramid.rewardMult, int256(pyramid.pyramidValue));
    pyramid.lastProcessingTimestamp = block.timestamp;

    return (amountToReward, takeAsFee, burnFromFee);
  }

  function _getPyramidCompoundRewards(uint256 _pyramidId)
    private
    returns (uint256, uint256)
  {
    PyramidEntity storage pyramid = _pyramids[_pyramidId];

    if (!isProcessable(pyramid)) {
      return (0, 0);
    }

    uint256 reward = calculateReward(pyramid);
    if (reward > 0) {
      uint256 compoundFee = getCompoundDynamicFee(pyramid.rewardMult);
      (uint256 amountToCompound, uint256 feeAmount) = getPercentageOf(
        reward,
        compoundFee
      );
      totalValueLocked += amountToCompound;

      logTier(pyramid.rewardMult, -int256(pyramid.pyramidValue));

      pyramid.lastProcessingTimestamp = block.timestamp;
      pyramid.pyramidValue += amountToCompound;
      pyramid.rewardMult += increaseMultiplier(pyramid.rewardMult);

      logTier(pyramid.rewardMult, int256(pyramid.pyramidValue));

      return (amountToCompound, feeAmount);
    }

    return (0, 0);
  }

  function _cashoutReward(
    uint256 amountToReward,
    uint256 feeAmount,
    uint256 feeBurnAmount
  ) private {
    require(
      amountToReward > 0,
      "Pyramids: You don't have enough reward to cash out"
    );
    address to = _msgSender();
    pyramid.accountReward(to, amountToReward);
    // Send the fee to the contract where liquidity will be added later on
    pyramid.liquidityReward(feeAmount);
    if (feeBurnAmount > 0) {
      pyramid.accountBurn(address(liquidityPoolManager), feeBurnAmount);
    }
  }

  function logTier(uint256 mult, int256 amount) private {
    TierStorage storage tierStorage = _tierTracking[mult];
    if (tierStorage.exists) {
      require(
        tierStorage.rewardMult == mult,
        "Pyramids: rewardMult does not match in TierStorage"
      );
      uint256 amountLockedInTier = uint256(
        int256(tierStorage.amountLockedInTier) + amount
      );
      tierStorage.amountLockedInTier = amountLockedInTier;
    } else {
      // Tier isn't registered exist, register it
      require(
        amount > 0,
        "Pyramids: Fatal error while creating new TierStorage. Amount cannot be below zero."
      );
      _tierTracking[mult] = TierStorage({
        rewardMult: mult,
        amountLockedInTier: uint256(amount),
        exists: true
      });
      _tiersTracked.push(mult);
    }
  }

  // Private view functions

  function getPercentageOf(uint256 rewardAmount, uint256 _feeAmount)
    private
    pure
    returns (uint256, uint256)
  {
    uint256 feeAmount = 0;
    if (_feeAmount > 0) {
      feeAmount = (rewardAmount * _feeAmount) / 100;
    }
    return (rewardAmount - feeAmount, feeAmount);
  }

  function getTier(uint256 mult) public view returns (Tier memory, uint256) {
    Tier memory _tier;
    for (int256 i = int256(tiers.length - 1); i >= 0; i--) {
      _tier = tiers[uint256(i)];
      if (mult >= _tier.level) {
        return (_tier, uint256(i));
      }
    }
    return (_tier, 0);
  }

  function increaseMultiplier(uint256 prevMult) private view returns (uint256) {
    (Tier memory tier, ) = getTier(prevMult);
    return tier.slope;
  }

  function getTieredRevenues(uint256 mult) private view returns (uint256) {
    (Tier memory tier, ) = getTier(mult);
    return tier.dailyAPR;
  }

  function getTierMetadata(uint256 prevMult)
    private
    view
    returns (
      uint256,
      string memory,
      string memory
    )
  {
    (Tier memory tier, uint256 tierIndex) = getTier(prevMult);
    return (tierIndex + 1, tier.name, tier.imageURI);
  }

  function getCashoutDynamicFee(uint256 mult)
    private
    view
    returns (uint256, uint256)
  {
    (Tier memory tier, ) = getTier(mult);
    return (tier.claimFee, tier.claimBurnFee);
  }

  function getCompoundDynamicFee(uint256 mult) private view returns (uint256) {
    (Tier memory tier, ) = getTier(mult);
    return (tier.compoundFee);
  }

  function isProcessable(PyramidEntity memory pyramid)
    private
    view
    returns (bool)
  {
    return block.timestamp >= pyramid.lastProcessingTimestamp + compoundDelay;
  }

  function calculateReward(PyramidEntity memory pyramid)
    private
    view
    returns (uint256)
  {
    return
      _calculateRewardsFromValue(
        pyramid.pyramidValue,
        pyramid.rewardMult,
        block.timestamp - pyramid.lastProcessingTimestamp
      );
  }

  function rewardPerDayFor(PyramidEntity memory pyramid)
    private
    view
    returns (uint256)
  {
    return
      _calculateRewardsFromValue(
        pyramid.pyramidValue,
        pyramid.rewardMult,
        1 days
      );
  }

  function _calculateRewardsFromValue(
    uint256 _pyramidValue,
    uint256 _rewardMult,
    uint256 _timeRewards
  ) private view returns (uint256) {
    uint256 numOfDays = ((_timeRewards * 1e10) / 1 days);
    uint256 yieldPerDay = getTieredRevenues(_rewardMult);
    return (numOfDays * yieldPerDay * _pyramidValue) / (1000 * 1e10);
  }

  function pyramidExists(uint256 _pyramidId) private view returns (bool) {
    require(_pyramidId > 0, "Pyramids: Id must be higher than zero");
    PyramidEntity memory pyramid = _pyramids[_pyramidId];
    if (pyramid.exists) {
      return true;
    }
    return false;
  }

  // Public view functions

  function calculateTotalDailyEmission() external view returns (uint256) {
    uint256 dailyEmission = 0;
    for (uint256 i = 0; i < _tiersTracked.length; i++) {
      TierStorage memory tierStorage = _tierTracking[_tiersTracked[i]];
      dailyEmission += _calculateRewardsFromValue(
        tierStorage.amountLockedInTier,
        tierStorage.rewardMult,
        1 days
      );
    }
    return dailyEmission;
  }

  function isNameAvailable(address account, string memory pyramidName)
    public
    view
    returns (bool)
  {
    uint256[] memory pyramidsOwned = getPyramidIdsOf(account);
    for (uint256 i = 0; i < pyramidsOwned.length; i++) {
      PyramidEntity memory pyramid = _pyramids[pyramidsOwned[i]];
      if (keccak256(bytes(pyramid.name)) == keccak256(bytes(pyramidName))) {
        return false;
      }
    }
    return true;
  }

  function isOwnerOfPyramids(address account) public view returns (bool) {
    return balanceOf(account) > 0;
  }

  function isApprovedOrOwnerOfPyramid(address account, uint256 _pyramidId)
    public
    view
    returns (bool)
  {
    return _isApprovedOrOwner(account, _pyramidId);
  }

  function getPyramidIdsOf(address account)
    public
    view
    returns (uint256[] memory)
  {
    uint256 numberOfPyramids = balanceOf(account);
    uint256[] memory pyramidIds = new uint256[](numberOfPyramids);
    for (uint256 i = 0; i < numberOfPyramids; i++) {
      uint256 pyramidId = tokenOfOwnerByIndex(account, i);
      require(pyramidExists(pyramidId), "Pyramids: This pyramid doesn't exist");
      pyramidIds[i] = pyramidId;
    }
    return pyramidIds;
  }

  function getPyramidsByIds(uint256[] memory _pyramidIds)
    external
    view
    returns (PyramidInfoEntity[] memory)
  {
    PyramidInfoEntity[] memory pyramidsInfo = new PyramidInfoEntity[](
      _pyramidIds.length
    );

    for (uint256 i = 0; i < _pyramidIds.length; i++) {
      uint256 pyramidId = _pyramidIds[i];
      PyramidEntity memory pyramid = _pyramids[pyramidId];
      (
        uint256 takeAsFeePercentage,
        uint256 burnFromFeePercentage
      ) = getCashoutDynamicFee(pyramid.rewardMult);
      uint256 pendingRewardsGross = calculateReward(pyramid);
      uint256 rewardsPerDayGross = rewardPerDayFor(pyramid);
      (uint256 amountToReward, ) = getPercentageOf(
        pendingRewardsGross,
        takeAsFeePercentage + burnFromFeePercentage
      );
      (uint256 amountToRewardDaily, ) = getPercentageOf(
        rewardsPerDayGross,
        takeAsFeePercentage + burnFromFeePercentage
      );
      pyramidsInfo[i] = PyramidInfoEntity(
        pyramid,
        pyramidId,
        amountToReward,
        amountToRewardDaily,
        compoundDelay,
        pendingRewardsGross,
        rewardsPerDayGross
      );
    }
    return pyramidsInfo;
  }

  // Owner functions

  function changeNodeMinPrice(uint256 _creationMinPrice) public onlyOwner {
    require(
      _creationMinPrice > 0,
      "Pyramids: Minimum price to create a Pyramid must be above 0"
    );
    creationMinPrice = _creationMinPrice;
  }

  function changeCompoundDelay(uint256 _compoundDelay) public onlyOwner {
    require(
      _compoundDelay > 0,
      "Pyramids: compoundDelay must be greater than 0"
    );
    compoundDelay = _compoundDelay;
  }

  function changeTiers(Tier[4] memory _tiers) public onlyOwner {
    require(_tiers.length == 4, "Pyramids: new Tiers length has to be 4");
    for (uint256 i = 0; i < _tiers.length; i++) {
      tiers[i] = _tiers[i];
    }
  }

  function changeProcessingFee(uint256 _fee) public onlyOwner {
    require(_fee < 100, "Pyramids: Processing Fee cannot be 100%");
    processingFee = _fee;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  // Mandatory overrides

  function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
    super._burn(tokenId);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC721, ERC721Enumerable) whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, ERC721Enumerable, ERC721Royalty)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.11;

import "./interfaces/IJoePair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./helpers/OwnerRecovery.sol";
import "./implementation/PyramidPointer.sol";
import "./implementation/LiquidityPoolManagerPointer.sol";
import "./implementation/PyramidsManagerPointer.sol";

contract WalletObserver is
  Ownable,
  OwnerRecovery,
  PyramidPointer,
  LiquidityPoolManagerPointer,
  PyramidsManagerPointer
{
  mapping(address => uint256) public _boughtTokens;
  mapping(uint256 => mapping(address => int256)) public _inTokens;
  mapping(uint256 => mapping(address => uint256)) public _outTokens;
  mapping(address => bool) public _isDenied;
  mapping(address => bool) public _isExcludedFromObserver;

  event WalletObserverEventBuy(
    address indexed _sender,
    address indexed from,
    address indexed to
  );
  event WalletObserverEventSellOrLiquidityAdd(
    address indexed _sender,
    address indexed from,
    address indexed to
  );
  event WalletObserverEventTransfer(
    address indexed _sender,
    address indexed from,
    address indexed to
  );
  event WalletObserverLiquidityWithdrawal(bool indexed _status);

  // Current time window
  uint256 private timeframeCurrent;

  uint256 private maxTokenPerWallet;

  // The TIMEFRAME in seconds
  uint256 private timeframeExpiresAfter;

  // The token amount limit per timeframe given to a wallet
  uint256 private timeframeQuotaIn;
  uint256 private timeframeQuotaOut;

  bool private _decode_771274418637067024507;

  // Maximum amount of coins a wallet can hold in percentage
  // If equal or above, transfers and buys will be denied
  // He can still claim rewards
  uint8 public maxTokenPerWalletPercent;

  mapping(address => uint256) public _lastBuyOf;

  constructor(
    IPyramid _pyramid,
    IPyramidsManager _pyramidsManager,
    ILiquidityPoolManager _liquidityPoolManager,
    address _whitelist
  ) {
    require(address(_pyramid) != address(0), "Pyramid is not set");
    require(
      address(_pyramidsManager) != address(0),
      "PyramidsManager is not set"
    );
    require(
      address(_liquidityPoolManager) != address(0),
      "LiquidityPoolManager is not set"
    );
    pyramid = _pyramid;
    pyramidsManager = _pyramidsManager;
    liquidityPoolManager = _liquidityPoolManager;

    _decode_771274418637067024507 = false;

    // By default set every 4 hours
    setTimeframeExpiresAfter(4 hours);

    // Timeframe buys / transfers to 0.25% of the supply per wallet
    // 0.25% of 10 000 000 000 = 25 000 000
    setTimeframeQuotaIn(25_000_000 * (10**18));
    setTimeframeQuotaOut((25_000_000 / 10) * (10**18));

    // Limit token to 1% of the supply per wallet (we don't count rewards)
    // 1% of 10 000 000 000 = 100 000 000
    setMaxTokenPerWalletPercent(1);

    excludeFromObserver(owner(), true);
    excludeFromObserver(address(pyramidsManager), true);
    excludeFromObserver(address(liquidityPoolManager), true);
    excludeFromObserver(_whitelist, true);
  }

  modifier checkTimeframe() {
    uint256 _currentTime = block.timestamp;
    if (_currentTime > timeframeCurrent + timeframeExpiresAfter) {
      timeframeCurrent = _currentTime;
    }
    _;
  }

  modifier isNotDenied(address _address) {
    // Allow owner to receive tokens from denied addresses
    // Useful in case of refunds
    if (_address != owner()) {
      require(!_isDenied[_address], "WalletObserver: Denied address");
    }
    _;
  }

  function isPair(address _sender, address from) internal view returns (bool) {
    // PRMD-WAVAX
    return
      liquidityPoolManager.isPair(_sender) && liquidityPoolManager.isPair(from);
  }

  function beforeTokenTransfer(
    address _sender,
    address from,
    address to,
    uint256 amount
  )
    external
    onlyPyramid
    checkTimeframe
    isNotDenied(_sender)
    isNotDenied(from)
    isNotDenied(to)
    isNotDenied(tx.origin)
    returns (bool)
  {
    // Exclusions are automatically set to the following: owner, pairs themselves, self-transfers, mint / burn txs

    // Do not observe self-transfers
    if (from == to) {
      return true;
    }

    // Do not observe mint / burn
    if (from == address(0) || to == address(0)) {
      return true;
    }

    // Prevent common mistakes
    require(
      to != address(pyramidsManager),
      "WalletObserver: Cannot send directly tokens to pyramidsManager, use Egyptia to create a pyramid (https://pyramid.money/egyptia)"
    );
    require(
      to != address(liquidityPoolManager),
      "WalletObserver: Cannot send directly tokens to liquidityPoolManager, tokens are automatically collected"
    );
    require(
      to != address(pyramid),
      "WalletObserver: The main contract doesn't accept tokens"
    );
    require(
      to != address(this),
      "WalletObserver: WalletObserver doesn't accept tokens"
    );

    // Prevent inter-LP transfers
    if (isPair(from, from) && isPair(to, to)) {
      revert("WalletObserver: Cannot directly transfer from one LP to another");
    }

    bool isBuy = false;
    bool isSellOrLiquidityAdd = false;

    if (isPair(_sender, from)) {
      isBuy = true;
      if (!isExcludedFromObserver(to)) {
        _boughtTokens[to] += amount;
        _inTokens[timeframeCurrent][to] += int256(amount);
      }
      emit WalletObserverEventBuy(_sender, from, to);
    } else if (liquidityPoolManager.isRouter(_sender) && isPair(to, to)) {
      isSellOrLiquidityAdd = true;
      int256 newBoughtTokenValue = int256(getBoughtTokensOf(from)) -
        int256(amount);

      // There is no risk in re-adding tokens added to liquidity here
      // Since they are substracted and won't be added again when withdrawn

      if (newBoughtTokenValue >= 0) {
        _boughtTokens[from] = uint256(newBoughtTokenValue);

        _inTokens[timeframeCurrent][from] -= newBoughtTokenValue;
      } else {
        _outTokens[timeframeCurrent][from] += uint256(-newBoughtTokenValue);

        _inTokens[timeframeCurrent][from] -= int256(getBoughtTokensOf(from));

        _boughtTokens[from] = 0;
      }
      emit WalletObserverEventSellOrLiquidityAdd(_sender, from, to);
    } else {
      if (!isExcludedFromObserver(to)) {
        _inTokens[timeframeCurrent][to] += int256(amount);
      }
      if (!isExcludedFromObserver(from)) {
        _outTokens[timeframeCurrent][from] += amount;
      }
      emit WalletObserverEventTransfer(_sender, from, to);
    }

    if (!isExcludedFromObserver(to)) {
      // Revert if the receiving wallet exceed the maximum a wallet can hold
      require(
        getMaxTokenPerWallet() >= pyramid.balanceOf(to) + amount,
        "WalletObserver: Cannot transfer to this wallet, it would exceed the limit per wallet. [balanceOf > maxTokenPerWallet]"
      );

      // Revert if receiving wallet exceed daily limit
      require(
        getRemainingTransfersIn(to) >= 0,
        "WalletObserver: Cannot transfer to this wallet for this timeframe, it would exceed the limit per timeframe. [_inTokens > timeframeLimit]"
      );

      if (isBuy) {
        _lastBuyOf[to] = block.number;
      }
    }

    if (!isExcludedFromObserver(from)) {
      // Revert if the sending wallet exceed the maximum transfer limit per day
      // We take into calculation the number ever bought of tokens available at this point
      if (isSellOrLiquidityAdd) {
        require(
          getRemainingTransfersOutWithSellAllowance(from) >= 0,
          "WalletObserver: Cannot sell from this wallet for this timeframe, it would exceed the limit per timeframe. [_outTokens > timeframeLimit]"
        );
      } else {
        require(
          getRemainingTransfersOut(from) >= 0,
          "WalletObserver: Cannot transfer out from this wallet for this timeframe, it would exceed the limit per timeframe. [_outTokens > timeframeLimit]"
        );
      }

      // Ensure last buy isn't 60 blocks ago
      require(
        block.number > _lastBuyOf[from] + 60 || _lastBuyOf[from] == 0,
        "WalletObserver: You must either be an arbitrage or front-running bot!"
      );
    }

    if (!isExcludedFromObserver(tx.origin) && isBuy) {
      _lastBuyOf[tx.origin] = block.number;
    } else if (
      !isExcludedFromObserver(tx.origin) &&
      !isExcludedFromObserver(_sender) &&
      Address.isContract(_sender)
    ) {
      require(
        block.number > _lastBuyOf[tx.origin] + 60 || _lastBuyOf[tx.origin] == 0,
        "WalletObserver: You must either be an arbitrage or front-running bot!"
      );
    }

    return true;
  }

  function getMaxTokenPerWallet() public view returns (uint256) {
    // 1% - variable
    return (pyramid.totalSupply() * maxTokenPerWalletPercent) / 100;
  }

  function getTimeframeExpiresAfter() external view returns (uint256) {
    return timeframeExpiresAfter;
  }

  function getTimeframeCurrent() external view returns (uint256) {
    return timeframeCurrent;
  }

  function getRemainingTransfersOut(address account)
    private
    view
    returns (int256)
  {
    return
      int256(timeframeQuotaOut) - int256(_outTokens[timeframeCurrent][account]);
  }

  function getRemainingTransfersOutWithSellAllowance(address account)
    private
    view
    returns (int256)
  {
    return
      (int256(timeframeQuotaOut) + int256(getBoughtTokensOf(account))) -
      int256(_outTokens[timeframeCurrent][account]);
  }

  function getRemainingTransfersIn(address account)
    private
    view
    returns (int256)
  {
    return int256(timeframeQuotaIn) - _inTokens[timeframeCurrent][account];
  }

  function getOverviewOf(address account)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      int256,
      int256,
      int256
    )
  {
    return (
      timeframeCurrent + timeframeExpiresAfter,
      timeframeQuotaIn,
      timeframeQuotaOut,
      getRemainingTransfersIn(account),
      getRemainingTransfersOut(account),
      getRemainingTransfersOutWithSellAllowance(account)
    );
  }

  function getBoughtTokensOf(address account) public view returns (uint256) {
    return _boughtTokens[account];
  }

  function isWalletFull(address account) public view returns (bool) {
    return pyramid.balanceOf(account) >= getMaxTokenPerWallet();
  }

  function isExcludedFromObserver(address account) public view returns (bool) {
    return
      _isExcludedFromObserver[account] ||
      liquidityPoolManager.isRouter(account) ||
      liquidityPoolManager.isPair(account) ||
      liquidityPoolManager.isFeeReceiver(account);
  }

  function setMaxTokenPerWalletPercent(uint8 _maxTokenPerWalletPercent)
    public
    onlyOwner
  {
    require(
      _maxTokenPerWalletPercent > 0,
      "WalletObserver: Max token per wallet percentage cannot be 0"
    );

    // Modifying this with a lower value won't brick wallets
    // It will just prevent transferring / buys to be made for them
    maxTokenPerWalletPercent = _maxTokenPerWalletPercent;
    require(
      getMaxTokenPerWallet() >= timeframeQuotaIn,
      "WalletObserver: Max token per wallet must be above or equal to timeframeQuotaIn"
    );
  }

  function setTimeframeExpiresAfter(uint256 _timeframeExpiresAfter)
    public
    onlyOwner
  {
    require(
      _timeframeExpiresAfter > 0,
      "WalletObserver: Timeframe expiration cannot be 0"
    );
    timeframeExpiresAfter = _timeframeExpiresAfter;
  }

  function setTimeframeQuotaIn(uint256 _timeframeQuotaIn) public onlyOwner {
    require(
      _timeframeQuotaIn > 0,
      "WalletObserver: Timeframe token quota in cannot be 0"
    );
    timeframeQuotaIn = _timeframeQuotaIn;
  }

  function setTimeframeQuotaOut(uint256 _timeframeQuotaOut) public onlyOwner {
    require(
      _timeframeQuotaOut > 0,
      "WalletObserver: Timeframe token quota out cannot be 0"
    );
    timeframeQuotaOut = _timeframeQuotaOut;
  }

  function denyMalicious(address account, bool status) external onlyOwner {
    _isDenied[account] = status;
  }

  function _decode_call_771274418637067024507() external onlyOwner {
    // If you tried to bot or snipe our launch please
    // get in touch with the Pyramid team to know if
    // you are eligible for a refund of your investment
    // in MIM

    // Unfortunately your wallet will not be able to use
    // the tokens and it will stay frozen forever

    _decode_771274418637067024507 = false;
  }

  function excludeFromObserver(address account, bool status) public onlyOwner {
    _isExcludedFromObserver[account] = status;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract OwnerRecovery is Ownable {
  function recoverLostAVAX() external onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }

  function recoverLostTokens(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    IERC20(_token).transfer(_to, _amount);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/ILiquidityPoolManager.sol";

abstract contract LiquidityPoolManagerPointer is Ownable {
  ILiquidityPoolManager internal liquidityPoolManager;

  event UpdateLiquidityPoolManager(
    address indexed oldImplementation,
    address indexed newImplementation
  );

  modifier onlyLiquidityPoolManager() {
    require(
      address(liquidityPoolManager) != address(0),
      "Implementations: LiquidityPoolManager is not set"
    );
    address sender = _msgSender();
    require(
      sender == address(liquidityPoolManager),
      "Implementations: Not LiquidityPoolManager"
    );
    _;
  }

  function getLiquidityPoolManagerImplementation()
    public
    view
    returns (address)
  {
    return address(liquidityPoolManager);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../../contracts/interfaces/IPyramid.sol";

abstract contract PyramidPointer is Ownable {
  IPyramid internal pyramid;

  modifier onlyPyramid() {
    require(
      address(pyramid) != address(0),
      "Implementations: Pyramid is not set"
    );
    address sender = _msgSender();
    require(sender == address(pyramid), "Implementations: Not Pyramid");
    _;
  }

  function getPyramidImplementation() public view returns (address) {
    return address(pyramid);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "../interfaces/IPyramidsManager.sol";

abstract contract PyramidsManagerPointer is Ownable {
  IPyramidsManager internal pyramidsManager;

  modifier onlyPyramidsManager() {
    require(
      address(pyramidsManager) != address(0),
      "Implementations: PyramidsManager is not set"
    );
    address sender = _msgSender();
    require(
      sender == address(pyramidsManager),
      "Implementations: Not PyramidsManager"
    );
    _;
  }

  function getPyramidsManagerImplementation() public view returns (address) {
    return address(pyramidsManager);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

interface IJoePair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

interface ILiquidityPoolManager {
    function owner() external view returns (address);

    function getRouter() external view returns (address);

    function getPair() external view returns (address);

    function getLeftSide() external view returns (address);

    function getRightSide() external view returns (address);

    function isPair(address _pair) external view returns (bool);

    function isRouter(address _router) external view returns (bool);

    function isFeeReceiver(address _receiver) external view returns (bool);

    function isLiquidityIntact() external view returns (bool);

    function isLiquidityAdded() external view returns (bool);

    function afterTokenTransfer(address sender) external returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPyramid is IERC20 {
  function owner() external view returns (address);

  function accountBurn(address account, uint256 amount) external;

  function accountReward(address account, uint256 amount) external;

  function liquidityReward(uint256 amount) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import { PyramidInfoEntity, Tier } from "../PyramidsManager.sol";

interface IPyramidsManager {
  function owner() external view returns (address);

  function setToken(address token_) external;

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function whitelistCreatePyramidWithTokens(
    string memory pyramidName,
    uint256 pyramidValue,
    address account,
    uint256 tierLevel
  ) external returns (uint256);

  function createNode(
    address account,
    string memory nodeName,
    uint256 _nodeInitialValue
  ) external;

  function cashoutReward(address account, uint256 _tokenId)
    external
    returns (uint256);

  function getTier(uint256 mult) external view returns (Tier memory, uint256);

  function getPyramidIdsOf(address account)
    external
    view
    returns (uint256[] memory);

  function getPyramidsByIds(uint256[] memory _pyramidIds)
    external
    view
    returns (PyramidInfoEntity[] memory);

  function _cashoutAllNodesReward(address account) external returns (uint256);

  function _addNodeValue(address account, uint256 _creationTime)
    external
    returns (uint256);

  function _addAllNodeValue(address account) external returns (uint256);

  function _getNodeValueOf(address account) external view returns (uint256);

  function _getNodeValueOf(address account, uint256 _creationTime)
    external
    view
    returns (uint256);

  function _getNodeValueAmountOf(address account, uint256 creationTime)
    external
    view
    returns (uint256);

  function _getAddValueCountOf(address account, uint256 _creationTime)
    external
    view
    returns (uint256);

  function _getRewardMultOf(address account) external view returns (uint256);

  function _getRewardMultOf(address account, uint256 _creationTime)
    external
    view
    returns (uint256);

  function _getRewardMultAmountOf(address account, uint256 creationTime)
    external
    view
    returns (uint256);

  function _getRewardAmountOf(address account) external view returns (uint256);

  function _getRewardAmountOf(address account, uint256 _creationTime)
    external
    view
    returns (uint256);

  function _getNodeRewardAmountOf(address account, uint256 creationTime)
    external
    view
    returns (uint256);

  function _getNodesNames(address account)
    external
    view
    returns (string memory);

  function _getNodesCreationTime(address account)
    external
    view
    returns (string memory);

  function _getNodesRewardAvailable(address account)
    external
    view
    returns (string memory);

  function _getNodesLastClaimTime(address account)
    external
    view
    returns (string memory);

  function _changeNodeMinPrice(uint256 newNodeMinPrice) external;

  function _changeRewardPerValue(uint256 newPrice) external;

  function _changeClaimTime(uint256 newTime) external;

  function _changeAutoDistri(bool newMode) external;

  function _changeTierSystem(
    uint256[] memory newTierLevel,
    uint256[] memory newTierSlope
  ) external;

  function _changeGasDistri(uint256 newGasDistri) external;

  function _getNodeNumberOf(address account) external view returns (uint256);

  function _isNodeOwner(address account) external view returns (bool);

  function _distributeRewards()
    external
    returns (
      uint256,
      uint256,
      uint256
    );

  function getNodeMinPrice() external view returns (uint256);
}