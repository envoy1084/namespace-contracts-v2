// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

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
        uint8 lengthPriceCount;
        address lengthPricesPointer;
    }

    mapping(bytes32 activationId => StoredParams params) private _params;

    error PaymentTokenMismatch(address expected, address actual);
    error DuplicateLengthPrice(bytes32 activationId, uint16 length);
    error EmptyLabel();
    error TooManyLengthPrices(bytes32 activationId, uint256 length);

    /// @notice Store fixed price parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        uint256 length = decoded.lengthPrices.length;
        if (length > type(uint8).max) {
            revert TooManyLengthPrices(activationId, length);
        }

        bytes memory packedPrices = new bytes(length * 34);
        for (uint256 i; i < length;) {
            LengthPrice memory lengthPrice = decoded.lengthPrices[i];
            for (uint256 j; j < i;) {
                if (decoded.lengthPrices[j].length == lengthPrice.length) {
                    revert DuplicateLengthPrice(activationId, lengthPrice.length);
                }
                unchecked {
                    ++j;
                }
            }
            _packLengthPrice(packedPrices, i, lengthPrice);
            unchecked {
                ++i;
            }
        }

        _params[activationId] = StoredParams({
            token: decoded.token,
            defaultMintAmount: decoded.defaultMintAmount,
            defaultRenewAmount: decoded.defaultRenewAmount,
            // casting to `uint8` is safe because `length` is bounded above.
            // forge-lint: disable-next-line(unsafe-typecast)
            lengthPriceCount: uint8(length),
            lengthPricesPointer: length == 0 ? address(0) : SSTORE2.write(packedPrices)
        });
    }

    /// @inheritdoc IPricingModule
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = _params[ctx.activationId];
        (, uint256 mintAmount) = _amountFor(ctx.activationId, ctx.label, true);
        price = _add(currentPrice, stored.token, mintAmount);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = _params[ctx.activationId];
        (, uint256 renewAmount) = _amountFor(ctx.activationId, ctx.label, false);
        price = _add(currentPrice, stored.token, renewAmount);
    }

    /// @notice Return configured default fixed price parameters for an activation.
    function params(bytes32 activationId)
        external
        view
        returns (address token, uint128 defaultMintAmount, uint128 defaultRenewAmount)
    {
        StoredParams memory stored = _params[activationId];
        return (stored.token, stored.defaultMintAmount, stored.defaultRenewAmount);
    }

    /// @notice Return configured exact-length price overrides for an activation.
    function lengthPrices(bytes32 activationId) external view returns (LengthPrice[] memory) {
        StoredParams memory stored = _params[activationId];
        LengthPrice[] memory prices = new LengthPrice[](stored.lengthPriceCount);
        if (stored.lengthPriceCount == 0) {
            return prices;
        }

        bytes memory packedPrices = SSTORE2.read(stored.lengthPricesPointer);
        for (uint256 i; i < stored.lengthPriceCount;) {
            prices[i] = _unpackLengthPrice(packedPrices, i);
            unchecked {
                ++i;
            }
        }
        return prices;
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

        StoredParams memory stored = _params[activationId];
        uint256 length = stored.lengthPriceCount;
        bytes memory prices = length == 0 ? bytes("") : SSTORE2.read(stored.lengthPricesPointer);
        for (uint256 i; i < length;) {
            LengthPrice memory lengthPrice = _unpackLengthPrice(prices, i);
            if (lengthPrice.length == labelLength) {
                return (labelLength, mint ? lengthPrice.mintAmount : lengthPrice.renewAmount);
            }
            unchecked {
                ++i;
            }
        }

        amount = mint ? stored.defaultMintAmount : stored.defaultRenewAmount;
    }

    function _packLengthPrice(bytes memory packedPrices, uint256 index, LengthPrice memory lengthPrice) private pure {
        uint256 offset = 32 + index * 34;
        assembly ("memory-safe") {
            mstore(add(packedPrices, offset), shl(240, mload(lengthPrice)))
            mstore(add(packedPrices, add(offset, 2)), shl(128, mload(add(lengthPrice, 0x20))))
            mstore(add(packedPrices, add(offset, 18)), shl(128, mload(add(lengthPrice, 0x40))))
        }
    }

    function _unpackLengthPrice(bytes memory packedPrices, uint256 index)
        private
        pure
        returns (LengthPrice memory lengthPrice)
    {
        uint256 offset = 32 + index * 34;
        assembly ("memory-safe") {
            mstore(lengthPrice, shr(240, mload(add(packedPrices, offset))))
            mstore(add(lengthPrice, 0x20), shr(128, mload(add(packedPrices, add(offset, 2)))))
            mstore(add(lengthPrice, 0x40), shr(128, mload(add(packedPrices, add(offset, 18)))))
        }
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
