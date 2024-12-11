// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import {TokenRouter} from "./libs/TokenRouter.sol";
import {TokenMessage} from "./libs/TokenMessage.sol";

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Unofficial ERC1155 Token Collateral Router
 * @author Based on HypERC721Collateral. For example purposes only
 */
contract HypERC1155Collateral is 
    TokenRouter,
    IERC1155Receiver,
    OwnableUpgradeable 
{
    IERC1155 public immutable wrappedToken;

    constructor(address erc1155, address _mailbox) TokenRouter(_mailbox) {
        wrappedToken = IERC1155(erc1155);
    }

    /**
     * @notice Initializes the Hyperlane router
     * @param _hook The post-dispatch hook contract
     * @param _interchainSecurityModule The interchain security module contract
     * @param _owner The owner of this contract
     */
    function initialize(
        address _hook,
        address _interchainSecurityModule,
        address _owner
    ) public virtual initializer {
        __Ownable_init();
        _MailboxClient_initialize(_hook, _interchainSecurityModule, _owner);
        _transferOwnership(_owner);
    }

    /**
     * @dev Returns balance of token ID for account
     */
    function balanceOf(
        address _account,
        uint256 _id
    ) public view returns (uint256) {
        return wrappedToken.balanceOf(_account, _id);
    }

    /**
     * @dev Transfers tokens from sender for cross-chain transfer
     * @inheritdoc TokenRouter
     */
    function _transferFromSender(
        uint256 _tokenId
    ) internal virtual override returns (bytes memory) {
        uint256 amount = msg.value;
        wrappedToken.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            amount,
            ""
        );
        return abi.encode(amount);
    }

    /**
     * @dev Transfers tokens to recipient on destination chain
     * @inheritdoc TokenRouter
     */
    function _transferTo(
        address _recipient,
        uint256 _tokenId,
        bytes calldata _metadata
    ) internal virtual override {
        uint256 amount = abi.decode(_metadata, (uint256));
        wrappedToken.safeTransferFrom(
            address(this),
            _recipient,
            _tokenId,
            amount,
            ""
        );
    }

    /**
     * @dev Required IERC1155Receiver implementation
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
