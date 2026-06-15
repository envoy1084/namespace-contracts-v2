// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title LengthBasedPricing
/// @notice Adds per-second prices selected by label byte length.
/// @dev Index `0` prices one-byte labels. Labels longer than the table use the final bucket.
contract LengthBasedPricing is NamespaceModule, IPricingModule {
    /// @notice Length-based pricing params for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param mintPricePerSecondByLength Per-second mint rates by byte length.
    /// @param renewPricePerSecondByLength Per-second renewal rates by byte length.
    struct Params {
        address token;
        uint128[] mintPricePerSecondByLength;
        uint128[] renewPricePerSecondByLength;
    }

    mapping(bytes32 activationId => Params params) private _params;

    error EmptyPricingTable();
    error EmptyLabel();
    error PaymentTokenMismatch(address expected, address actual);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Store length-based pricing parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.mintPricePerSecondByLength.length == 0 || decoded.renewPricePerSecondByLength.length == 0) {
            revert EmptyPricingTable();
        }
        _params[activationId] = decoded;
    }

    /// @inheritdoc IPricingModule
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params storage stored = _params[ctx.activationId];
        uint256 rate = _rateFor(stored.mintPricePerSecondByLength, ctx.label);
        price = _add(currentPrice, stored.token, rate * ctx.duration);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params storage stored = _params[ctx.activationId];
        uint256 rate = _rateFor(stored.renewPricePerSecondByLength, ctx.label);
        price = _add(currentPrice, stored.token, rate * ctx.duration);
    }

    /// @notice Return configured mint pricing table for an activation.
    function mintPricePerSecondByLength(bytes32 activationId) external view returns (uint128[] memory) {
        return _params[activationId].mintPricePerSecondByLength;
    }

    /// @notice Return configured renewal pricing table for an activation.
    function renewPricePerSecondByLength(bytes32 activationId) external view returns (uint128[] memory) {
        return _params[activationId].renewPricePerSecondByLength;
    }

    /// @notice Return configured payment token for an activation.
    function token(bytes32 activationId) external view returns (address) {
        return _params[activationId].token;
    }

    function _rateFor(uint128[] storage rates, string calldata label) private view returns (uint256) {
        uint256 length = bytes(label).length;
        if (length == 0) {
            revert EmptyLabel();
        }

        uint256 index = length - 1;
        if (index >= rates.length) {
            index = rates.length - 1;
        }
        return rates[index];
    }

    function _add(NamespaceTypes.Price calldata currentPrice, address token_, uint256 amount)
        private
        pure
        returns (NamespaceTypes.Price memory price)
    {
        if (currentPrice.token != address(0) && currentPrice.token != token_) {
            revert PaymentTokenMismatch(currentPrice.token, token_);
        }
        price.token = token_;
        price.amount = currentPrice.amount + amount;
    }
}
