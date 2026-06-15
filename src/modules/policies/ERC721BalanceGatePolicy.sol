// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title ERC721BalanceGatePolicy
/// @notice Requires the minter or renewal payer to hold a minimum ERC721 balance.
contract ERC721BalanceGatePolicy is NamespaceModule, IPolicyModule {
    /// @notice NFT gate parameters for one activation.
    /// @param token ERC721 token used for gating.
    /// @param minBalance Minimum NFT balance required.
    struct Params {
        IERC721 token;
        uint256 minBalance;
    }

    mapping(bytes32 activationId => Params params) public params;

    error ZeroGateToken(bytes32 activationId);
    error InvalidMinimumBalance(bytes32 activationId);
    error InsufficientERC721Balance(
        bytes32 activationId, address account, address token, uint256 balance, uint256 minBalance
    );

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Store ERC721 gate parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (address(decoded.token) == address(0)) {
            revert ZeroGateToken(activationId);
        }
        if (decoded.minBalance == 0) {
            revert InvalidMinimumBalance(activationId);
        }
        params[activationId] = decoded;
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata) external view {
        _checkBalance(ctx.activationId, ctx.buyer);
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata) external view {
        _checkBalance(ctx.activationId, ctx.payer);
    }

    function _checkBalance(bytes32 activationId, address account) private view {
        Params memory stored = params[activationId];
        uint256 balance = stored.token.balanceOf(account);
        if (balance < stored.minBalance) {
            revert InsufficientERC721Balance(activationId, account, address(stored.token), balance, stored.minBalance);
        }
    }
}
