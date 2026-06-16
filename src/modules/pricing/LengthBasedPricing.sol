// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

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

    struct StoredParams {
        address token;
        uint8 mintRateCount;
        uint8 renewRateCount;
        address mintRatesPointer;
        address renewRatesPointer;
    }

    mapping(bytes32 activationId => StoredParams params) private _params;

    error EmptyPricingTable();
    error EmptyLabel();
    error PaymentTokenMismatch(address expected, address actual);
    error PricingTableTooLong(bytes32 activationId, uint256 length);

    /// @notice Store length-based pricing parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.mintPricePerSecondByLength.length == 0 || decoded.renewPricePerSecondByLength.length == 0) {
            revert EmptyPricingTable();
        }
        if (
            decoded.mintPricePerSecondByLength.length > type(uint8).max
                || decoded.renewPricePerSecondByLength.length > type(uint8).max
        ) {
            revert PricingTableTooLong(
                activationId,
                decoded.mintPricePerSecondByLength.length > type(uint8).max
                    ? decoded.mintPricePerSecondByLength.length
                    : decoded.renewPricePerSecondByLength.length
            );
        }

        _params[activationId] = StoredParams({
            token: decoded.token,
            // casting to `uint8` is safe because lengths are bounded above.
            // forge-lint: disable-next-line(unsafe-typecast)
            mintRateCount: uint8(decoded.mintPricePerSecondByLength.length),
            // casting to `uint8` is safe because lengths are bounded above.
            // forge-lint: disable-next-line(unsafe-typecast)
            renewRateCount: uint8(decoded.renewPricePerSecondByLength.length),
            mintRatesPointer: SSTORE2.write(_packRates(decoded.mintPricePerSecondByLength)),
            renewRatesPointer: SSTORE2.write(_packRates(decoded.renewPricePerSecondByLength))
        });
    }

    /// @inheritdoc IPricingModule
    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = _params[ctx.activationId];
        uint256 rate = _rateFor(stored.mintRatesPointer, stored.mintRateCount, ctx.label);
        price = _add(currentPrice, stored.token, rate * ctx.duration);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = _params[ctx.activationId];
        uint256 rate = _rateFor(stored.renewRatesPointer, stored.renewRateCount, ctx.label);
        price = _add(currentPrice, stored.token, rate * ctx.duration);
    }

    /// @notice Return configured mint pricing table for an activation.
    function mintPricePerSecondByLength(bytes32 activationId) external view returns (uint128[] memory) {
        StoredParams memory stored = _params[activationId];
        return _unpackRates(stored.mintRatesPointer, stored.mintRateCount);
    }

    /// @notice Return configured renewal pricing table for an activation.
    function renewPricePerSecondByLength(bytes32 activationId) external view returns (uint128[] memory) {
        StoredParams memory stored = _params[activationId];
        return _unpackRates(stored.renewRatesPointer, stored.renewRateCount);
    }

    /// @notice Return configured payment token for an activation.
    function token(bytes32 activationId) external view returns (address) {
        return _params[activationId].token;
    }

    function _rateFor(address ratesPointer, uint256 rateCount, string calldata label) private view returns (uint256) {
        uint256 length = bytes(label).length;
        if (length == 0) {
            revert EmptyLabel();
        }

        uint256 index = length - 1;
        if (index >= rateCount) {
            index = rateCount - 1;
        }
        return _rateAt(ratesPointer, index);
    }

    function _packRates(uint128[] memory rates) private pure returns (bytes memory packedRates) {
        uint256 length = rates.length;
        packedRates = new bytes(length * 16);
        for (uint256 i; i < length;) {
            uint256 offset = 32 + i * 16;
            uint128 rate = rates[i];
            assembly ("memory-safe") {
                mstore(add(packedRates, offset), shl(128, rate))
            }
            unchecked {
                ++i;
            }
        }
    }

    function _unpackRates(address ratesPointer, uint256 rateCount) private view returns (uint128[] memory rates) {
        rates = new uint128[](rateCount);
        bytes memory packedRates = SSTORE2.read(ratesPointer);
        for (uint256 i; i < rateCount;) {
            rates[i] = _unpackRate(packedRates, i);
            unchecked {
                ++i;
            }
        }
    }

    function _rateAt(address ratesPointer, uint256 index) private view returns (uint128 rate) {
        uint256 offset = 1 + index * 16;
        assembly ("memory-safe") {
            extcodecopy(ratesPointer, 0x00, offset, 0x10)
            rate := shr(128, mload(0x00))
        }
    }

    function _unpackRate(bytes memory packedRates, uint256 index) private pure returns (uint128 rate) {
        uint256 offset = 32 + index * 16;
        assembly ("memory-safe") {
            rate := shr(128, mload(add(packedRates, offset)))
        }
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
