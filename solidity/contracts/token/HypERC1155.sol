// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import {TokenRouter} from "./libs/TokenRouter.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Unofficial Hyperlane ERC1155 Token Router 
 * @notice Enables cross-chain ERC1155 token transfers using Hyperlane's messaging protocol
 * @dev Compatible with existing Hyperlane protocol deployments by packing tokenId and amount
 * into a single uint256. Uses standard TokenRouter interface without modifications.
 * Limitation: Both tokenId and amount must be <= type(uint128).max
 */

contract HypERC1155 is 
    ERC1155SupplyUpgradeable,
    OwnableUpgradeable,
    TokenRouter 
{
    string private _name;
    string private _symbol;

    error InsufficientBalance(address from, uint256 tokenId, uint256 amount);

    constructor(address _mailbox) TokenRouter(_mailbox) {}

    function initialize(
        string memory _uri,
        string memory tokenName,
        string memory tokenSymbol,
        address _hook,
        address _interchainSecurityModule,
        address _owner
    ) external initializer {
        __ERC1155_init(_uri);
        __ERC1155Supply_init();
        __Ownable_init();
        _MailboxClient_initialize(_hook, _interchainSecurityModule, _owner);
        _name = tokenName;
        _symbol = tokenSymbol;
        _transferOwnership(_owner);
    }

    /**
     * @notice Transfers tokens to recipient on destination domain 
     * @param destination Domain ID of the destination chain
     * @param recipient Address of the recipient on destination chain
     * @param tokenId ID of token to transfer, must be <= type(uint128).max
     * @param amount Amount of tokens to transfer, must be <= type(uint128).max
     * @return messageId ID of the dispatched message
     * @dev Both tokenId and amount are packed into a single uint256 with 128 bits each.
     * Will revert if either value exceeds uint128.max to maintain protocol compatibility.
     */

    function transferRemote(
        uint32 destination,
        bytes32 recipient,
        uint256 tokenId,
        uint256 amount
    ) external payable returns (bytes32) {
        uint256 packed = _packValues(tokenId, amount);
        return super.transferRemote(destination, recipient, packed, msg.value);
    }

    function _transferFromSender(
        uint256 packed
    ) internal virtual override returns (bytes memory) {
        (uint256 tokenId, uint256 amount) = _unpackValues(packed);
        
        if (balanceOf(msg.sender, tokenId) < amount) {
            revert InsufficientBalance(msg.sender, tokenId, amount);
        }
        
        _burn(msg.sender, tokenId, amount);
        return ""; // No additional metadata needed
    }

    function _transferTo(
        address recipient,
        uint256 packed,
        bytes calldata // metadata not used
    ) internal virtual override {
        (uint256 tokenId, uint256 amount) = _unpackValues(packed);
        _mint(recipient, tokenId, amount, "");
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

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function balanceOf(address) public pure override(TokenRouter, ERC1155Upgradeable, IERC1155Upgradeable) returns (uint256) {
        revert("Use balanceOf(address,uint256)");
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }
}
