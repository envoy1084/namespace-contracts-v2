// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title FixedPricePricing
/// @notice Adds an activation-scoped fixed amount to mint and renewal quotes.
contract FixedPricePricing is NamespaceModule, IPricingModule {
    /// @notice Fixed price params for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param mintAmount Amount added to mint price.
    /// @param renewAmount Amount added to renewal price.
    struct Params {
        address token;
        uint128 mintAmount;
        uint128 renewAmount;
    }

    mapping(bytes32 activationId => Params params) public params;

    error PaymentTokenMismatch(address expected, address actual);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Store fixed price parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        params[activationId] = abi.decode(configData, (Params));
    }

    /// @inheritdoc IPricingModule
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params memory stored = params[ctx.activationId];
        price = _add(currentPrice, stored.token, stored.mintAmount);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params memory stored = params[ctx.activationId];
        price = _add(currentPrice, stored.token, stored.renewAmount);
    }

    function _add(NamespaceTypes.Price calldata currentPrice, address token, uint256 amount)
        private
        pure
        returns (NamespaceTypes.Price memory price)
    {
        if (currentPrice.token != address(0) && currentPrice.token != token) {
            revert PaymentTokenMismatch(currentPrice.token, token);
        }
        price.token = token;
        price.amount = currentPrice.amount + amount;
    }
}
