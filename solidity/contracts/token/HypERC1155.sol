// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import {TokenRouter} from "./libs/TokenRouter.sol";
import {IERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Unofficial ERC1155 Token Router
 * @author Based on HypERC721. For example purposes only
 */
contract HypERC1155 is 
    ERC1155SupplyUpgradeable,
    OwnableUpgradeable,
    TokenRouter 
{
    string private _name;
    string private _symbol;

    constructor(address _mailbox) TokenRouter(_mailbox) {}

    /**
     * @notice Initializes the Hyperlane router and ERC1155 metadata
     * @param _uri Base URI for token metadata
     * @param tokenName The name of the token collection
     * @param tokenSymbol The symbol of the token collection
     * @param _hook The post-dispatch hook contract
     * @param _interchainSecurityModule The interchain security module contract
     * @param _owner The owner of this contract
     */
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
     * @notice Sets a new URI for all token types
     * @dev Optional _setURI() function to update base URI
     */
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /**
     * @notice Mints tokens to the specified address
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        _mint(to, id, amount, data);
    }

    /**
     * @notice Batch mints tokens to the specified address
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Transfers tokens from sender for cross-chain transfer
     * @inheritdoc TokenRouter
     */
    function _transferFromSender(
        uint256 _tokenId
    ) internal virtual override returns (bytes memory) {
        uint256 amount = msg.value;
        require(
            balanceOf(msg.sender, _tokenId) >= amount,
            "Insufficient balance"
        );
        _burn(msg.sender, _tokenId, amount);
        return abi.encode(amount);
    }

    /**
     * @dev Mints tokens to recipient on destination chain
     * @inheritdoc TokenRouter
     */
    function _transferTo(
        address _recipient,
        uint256 _tokenId,
        bytes calldata _metadata
    ) internal virtual override {
        uint256 amount = abi.decode(_metadata, (uint256));
        _mint(_recipient, _tokenId, amount, "");
    }

    /**
     * @dev Required override to handle supply tracking
     */
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

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }
}
