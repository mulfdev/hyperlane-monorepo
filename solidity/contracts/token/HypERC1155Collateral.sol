// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import {TokenRouter} from "./libs/TokenRouter.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Hyperlane ERC1155 Token Collateral
 * @notice Enables cross-chain transfers of existing ERC1155 tokens using Hyperlane
 * @dev Holds original tokens as collateral while wrapped versions are minted on other chains
 */
contract HypERC1155Collateral is TokenRouter, ERC1155Holder, OwnableUpgradeable {
    IERC1155 public immutable wrappedToken;
    
    string private _name;
    string private _symbol;

    error InsufficientBalance(address from, uint256 tokenId, uint256 amount);

    event URISet(string newUri);
    event TokensMinted(address indexed to, uint256 id, uint256 amount);
    event TokensBatchMinted(address indexed to, uint256[] ids, uint256[] amounts);

    constructor(address erc1155, address _mailbox) TokenRouter(_mailbox) {
        wrappedToken = IERC1155(erc1155);
    }

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        address _hook,
        address _interchainSecurityModule,
        address _owner
    ) public virtual initializer {
        __Ownable_init();
        _MailboxClient_initialize(_hook, _interchainSecurityModule, _owner);
        _name = tokenName;
        _symbol = tokenSymbol;
        _transferOwnership(_owner);
    }

    /**
     * @notice Transfers tokens to recipient on destination domain 
     * @param destination Domain ID of destination chain
     * @param recipient Address of recipient on destination chain
     * @param tokenId ID of token to transfer, must be <= type(uint128).max
     * @param amount Amount of tokens to transfer, must be <= type(uint128).max 
     * @return messageId ID of dispatched message
     */
    function transferRemote(
        uint32 destination,
        bytes32 recipient,
        uint256 tokenId,
        uint256 amount
    ) external payable returns (bytes32) {
        uint256 packed = _packValues(tokenId, amount);
        return transferRemote(destination, recipient, packed);
    }

    function _transferFromSender(
        uint256 packed
    ) internal virtual override returns (bytes memory) {
        (uint256 tokenId, uint256 amount) = _unpackValues(packed);
        
        if (wrappedToken.balanceOf(msg.sender, tokenId) < amount) {
            revert InsufficientBalance(msg.sender, tokenId, amount);
        }

        wrappedToken.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        return ""; // No additional metadata needed
    }

    function _transferTo(
        address recipient,
        uint256 packed,
        bytes calldata // metadata not used
    ) internal virtual override {
        (uint256 tokenId, uint256 amount) = _unpackValues(packed);
        wrappedToken.safeTransferFrom(address(this), recipient, tokenId, amount, "");
    }

    // Pack tokenId and amount into single uint256
    // Uses top 128 bits for tokenId, bottom 128 bits for amount 
    function _packValues(uint256 tokenId, uint256 amount) internal pure returns (uint256) {
        require(tokenId <= type(uint128).max, "TokenId too large");
        require(amount <= type(uint128).max, "Amount too large");
        return (tokenId << 128) | amount;
    }

    // Unpack uint256 into tokenId and amount
    function _unpackValues(uint256 packed) internal pure returns (uint256 tokenId, uint256 amount) {
        tokenId = packed >> 128;
        amount = packed & type(uint128).max;
    }

    // Token metadata functions
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function uri(uint256 id) public view returns (string memory) {
        return wrappedToken.uri(id);
    }

    // Supply tracking
    function totalSupply(uint256 id) public view returns (uint256) {
        return wrappedToken.balanceOf(address(this), id);
    }

    function exists(uint256 id) public view returns (bool) {
        return wrappedToken.balanceOf(address(this), id) > 0;
    }

    // Mint functions (requires approval/ownership of original tokens)
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        wrappedToken.safeTransferFrom(msg.sender, to, id, amount, data);
        emit TokensMinted(to, id, amount);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        wrappedToken.safeBatchTransferFrom(msg.sender, to, ids, amounts, data);
        emit TokensBatchMinted(to, ids, amounts);
    }

    // Override for TokenRouter
    function balanceOf(address) public pure override(TokenRouter) returns (uint256) {
        revert("Use balanceOf(address,uint256)");
    }
}
