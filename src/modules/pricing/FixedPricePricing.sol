// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title FixedPricePricing
/// @notice Adds activation-scoped fixed amounts with optional sparse exact-length overrides.
contract FixedPricePricing is NamespaceModule, IPricingModule {
    /// @notice Exact byte-length price override.
    /// @param length Label byte length matched by this price.
    /// @param mintAmount Amount added to mint price when length matches.
    /// @param renewAmount Amount added to renewal price when length matches.
    struct LengthPrice {
        uint16 length;
        uint128 mintAmount;
        uint128 renewAmount;
    }

    /// @notice Fixed price params for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param defaultMintAmount Amount added to mint price when no exact-length override matches.
    /// @param defaultRenewAmount Amount added to renewal price when no exact-length override matches.
    /// @param lengthPrices Sparse exact byte-length price overrides.
    struct Params {
        address token;
        uint128 defaultMintAmount;
        uint128 defaultRenewAmount;
        LengthPrice[] lengthPrices;
    }

    struct StoredParams {
        address token;
        uint128 defaultMintAmount;
        uint128 defaultRenewAmount;
    }

    mapping(bytes32 activationId => StoredParams params) public params;
    mapping(bytes32 activationId => LengthPrice[] lengthPrices) private _lengthPrices;

    error PaymentTokenMismatch(address expected, address actual);
    error DuplicateLengthPrice(bytes32 activationId, uint16 length);
    error EmptyLabel();

    /// @notice Store fixed price parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        params[activationId] = StoredParams({
            token: decoded.token,
            defaultMintAmount: decoded.defaultMintAmount,
            defaultRenewAmount: decoded.defaultRenewAmount
        });

        delete _lengthPrices[activationId];
        uint256 length = decoded.lengthPrices.length;
        for (uint256 i; i < length;) {
            LengthPrice memory lengthPrice = decoded.lengthPrices[i];
            uint256 storedLength = _lengthPrices[activationId].length;
            for (uint256 j; j < storedLength;) {
                if (_lengthPrices[activationId][j].length == lengthPrice.length) {
                    revert DuplicateLengthPrice(activationId, lengthPrice.length);
                }
                unchecked {
                    ++j;
                }
            }
            _lengthPrices[activationId].push(lengthPrice);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IPricingModule
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = params[ctx.activationId];
        (, uint256 mintAmount) = _amountFor(ctx.activationId, ctx.label, true);
        price = _add(currentPrice, stored.token, mintAmount);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = params[ctx.activationId];
        (, uint256 renewAmount) = _amountFor(ctx.activationId, ctx.label, false);
        price = _add(currentPrice, stored.token, renewAmount);
    }

    /// @notice Return configured exact-length price overrides for an activation.
    function lengthPrices(bytes32 activationId) external view returns (LengthPrice[] memory) {
        return _lengthPrices[activationId];
    }

    function _amountFor(bytes32 activationId, string calldata label, bool mint)
        private
        view
        returns (uint256 labelLength, uint256 amount)
    {
        labelLength = bytes(label).length;
        if (labelLength == 0) {
            revert EmptyLabel();
        }

        LengthPrice[] storage prices = _lengthPrices[activationId];
        uint256 length = prices.length;
        for (uint256 i; i < length;) {
            if (prices[i].length == labelLength) {
                return (labelLength, mint ? prices[i].mintAmount : prices[i].renewAmount);
            }
            unchecked {
                ++i;
            }
        }

        StoredParams memory stored = params[activationId];
        amount = mint ? stored.defaultMintAmount : stored.defaultRenewAmount;
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
