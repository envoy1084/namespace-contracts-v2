// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {LabelClassPricing} from "src/modules/pricing/LabelClassPricing.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title CompositePricing
/// @notice Gas-optimized bundle for label-class, fixed, and length-based pricing.
contract CompositePricing is NamespaceModule, IPricingModule {
    struct LengthPrice {
        uint16 length;
        uint128 mintAmount;
        uint128 renewAmount;
    }

    struct Params {
        address token;
        LabelClassPricing.LabelClass labelClass;
        uint128 classMintAmount;
        uint128 classRenewAmount;
        uint128 defaultMintAmount;
        uint128 defaultRenewAmount;
        LengthPrice[] lengthPrices;
        uint128[] mintPricePerSecondByLength;
        uint128[] renewPricePerSecondByLength;
    }

    struct StoredParams {
        address token;
        uint8 labelClass;
        uint8 lengthPriceCount;
        uint8 mintRateCount;
        uint8 renewRateCount;
        uint128 classMintAmount;
        uint128 classRenewAmount;
        uint128 defaultMintAmount;
        uint128 defaultRenewAmount;
        address lengthPricesPointer;
        address mintRatesPointer;
        address renewRatesPointer;
    }

    mapping(bytes32 activationId => StoredParams params) private _params;

    error EmptyPricingTable();
    error EmptyLabel();
    error PaymentTokenMismatch(address expected, address actual);
    error DuplicateLengthPrice(bytes32 activationId, uint16 length);
    error PricingTableTooLong(bytes32 activationId, uint256 length);
    error InvalidUtf8Label(string label);

    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        _validateTableLengths(activationId, decoded);
        bytes memory packedLengthPrices = _packLengthPrices(activationId, decoded.lengthPrices);
        uint256 lengthPriceCount = decoded.lengthPrices.length;

        _params[activationId] = StoredParams({
            token: decoded.token,
            labelClass: uint8(decoded.labelClass),
            // forge-lint: disable-next-line(unsafe-typecast)
            lengthPriceCount: uint8(lengthPriceCount),
            // forge-lint: disable-next-line(unsafe-typecast)
            mintRateCount: uint8(decoded.mintPricePerSecondByLength.length),
            // forge-lint: disable-next-line(unsafe-typecast)
            renewRateCount: uint8(decoded.renewPricePerSecondByLength.length),
            classMintAmount: decoded.classMintAmount,
            classRenewAmount: decoded.classRenewAmount,
            defaultMintAmount: decoded.defaultMintAmount,
            defaultRenewAmount: decoded.defaultRenewAmount,
            lengthPricesPointer: lengthPriceCount == 0 ? address(0) : SSTORE2.write(packedLengthPrices),
            mintRatesPointer: SSTORE2.write(_packRates(decoded.mintPricePerSecondByLength)),
            renewRatesPointer: SSTORE2.write(_packRates(decoded.renewPricePerSecondByLength))
        });
    }

    function quoteMint(
        NamespaceTypes.MintContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = _params[ctx.activationId];
        uint256 labelLength = bytes(ctx.label).length;
        if (labelLength == 0) {
            revert EmptyLabel();
        }
        uint256 amount = _matches(ctx.label, LabelClassPricing.LabelClass(stored.labelClass)) ? stored.classMintAmount : 0;
        amount += _fixedAmount(stored, labelLength, true);
        amount += _rateFor(stored.mintRatesPointer, stored.mintRateCount, labelLength) * ctx.duration;
        price = _add(currentPrice, stored.token, amount);
    }

    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        StoredParams memory stored = _params[ctx.activationId];
        uint256 labelLength = bytes(ctx.label).length;
        if (labelLength == 0) {
            revert EmptyLabel();
        }
        uint256 amount =
            _matches(ctx.label, LabelClassPricing.LabelClass(stored.labelClass)) ? stored.classRenewAmount : 0;
        amount += _fixedAmount(stored, labelLength, false);
        amount += _rateFor(stored.renewRatesPointer, stored.renewRateCount, labelLength) * ctx.duration;
        price = _add(currentPrice, stored.token, amount);
    }

    function _validateTableLengths(bytes32 activationId, Params memory decoded) private pure {
        uint256 lengthPriceCount = decoded.lengthPrices.length;
        uint256 mintRateCount = decoded.mintPricePerSecondByLength.length;
        uint256 renewRateCount = decoded.renewPricePerSecondByLength.length;
        if (lengthPriceCount > type(uint8).max || mintRateCount > type(uint8).max || renewRateCount > type(uint8).max) {
            uint256 invalidLength = lengthPriceCount > type(uint8).max
                ? lengthPriceCount
                : mintRateCount > type(uint8).max ? mintRateCount : renewRateCount;
            revert PricingTableTooLong(activationId, invalidLength);
        }
        if (mintRateCount == 0 || renewRateCount == 0) {
            revert EmptyPricingTable();
        }
    }

    function _packLengthPrices(bytes32 activationId, LengthPrice[] memory lengthPrices)
        private
        pure
        returns (bytes memory packedLengthPrices)
    {
        uint256 length = lengthPrices.length;
        packedLengthPrices = new bytes(length * 34);
        for (uint256 i; i < length;) {
            LengthPrice memory lengthPrice = lengthPrices[i];
            _validateUniqueLengthPrice(activationId, lengthPrices, i, lengthPrice.length);
            _packLengthPrice(packedLengthPrices, i, lengthPrice);
            unchecked {
                ++i;
            }
        }
    }

    function _validateUniqueLengthPrice(
        bytes32 activationId,
        LengthPrice[] memory lengthPrices,
        uint256 index,
        uint16 targetLength
    ) private pure {
        for (uint256 i; i < index;) {
            if (lengthPrices[i].length == targetLength) {
                revert DuplicateLengthPrice(activationId, targetLength);
            }
            unchecked {
                ++i;
            }
        }
    }

    function _fixedAmount(StoredParams memory stored, uint256 labelLength, bool mint)
        private
        view
        returns (uint256 amount)
    {
        uint256 length = stored.lengthPriceCount;
        bytes memory prices = length == 0 ? bytes("") : SSTORE2.read(stored.lengthPricesPointer);
        for (uint256 i; i < length;) {
            LengthPrice memory lengthPrice = _unpackLengthPrice(prices, i);
            if (lengthPrice.length == labelLength) {
                return mint ? lengthPrice.mintAmount : lengthPrice.renewAmount;
            }
            unchecked {
                ++i;
            }
        }
        amount = mint ? stored.defaultMintAmount : stored.defaultRenewAmount;
    }

    function _rateFor(address ratesPointer, uint256 rateCount, uint256 labelLength) private view returns (uint256) {
        uint256 index = labelLength - 1;
        if (index >= rateCount) {
            index = rateCount - 1;
        }
        return _rateAt(ratesPointer, index);
    }

    function _matches(string calldata label, LabelClassPricing.LabelClass labelClass) private pure returns (bool) {
        bytes calldata data = bytes(label);
        if (data.length == 0) {
            return false;
        }
        if (labelClass == LabelClassPricing.LabelClass.NUMBER) {
            return _isAsciiNumber(data);
        }
        if (labelClass == LabelClassPricing.LabelClass.LETTER) {
            return _isAsciiLetter(data);
        }
        return _isEmojiLabel(data);
    }

    function _isAsciiNumber(bytes calldata data) private pure returns (bool) {
        uint256 length = data.length;
        for (uint256 i; i < length;) {
            bytes1 char = data[i];
            if (char < 0x30 || char > 0x39) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    function _isAsciiLetter(bytes calldata data) private pure returns (bool) {
        uint256 length = data.length;
        for (uint256 i; i < length;) {
            bytes1 char = data[i];
            bool uppercase = char >= 0x41 && char <= 0x5A;
            bool lowercase = char >= 0x61 && char <= 0x7A;
            if (!uppercase && !lowercase) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    function _isEmojiLabel(bytes calldata data) private pure returns (bool) {
        uint256 offset = 0;
        bool hasEmoji;
        while (offset < data.length) {
            (uint256 codepoint, uint256 nextOffset) = _nextCodepoint(data, offset);
            if (_isEmojiCodepoint(codepoint)) {
                hasEmoji = true;
            } else if (!_isEmojiModifier(codepoint) || !hasEmoji) {
                return false;
            }
            offset = nextOffset;
        }
        return hasEmoji;
    }

    function _nextCodepoint(bytes calldata data, uint256 offset)
        private
        pure
        returns (uint256 codepoint, uint256 nextOffset)
    {
        uint8 first = uint8(data[offset]);
        if (first < 0x80) {
            return (first, offset + 1);
        }
        if (first >= 0xC2 && first <= 0xDF && offset + 1 < data.length) {
            return ((uint256(first & 0x1F) << 6) | uint256(uint8(data[offset + 1]) & 0x3F), offset + 2);
        }
        if (first >= 0xE0 && first <= 0xEF && offset + 2 < data.length) {
            return (
                (uint256(first & 0x0F) << 12) | (uint256(uint8(data[offset + 1]) & 0x3F) << 6)
                    | uint256(uint8(data[offset + 2]) & 0x3F),
                offset + 3
            );
        }
        if (first >= 0xF0 && first <= 0xF4 && offset + 3 < data.length) {
            return (
                (uint256(first & 0x07) << 18) | (uint256(uint8(data[offset + 1]) & 0x3F) << 12)
                    | (uint256(uint8(data[offset + 2]) & 0x3F) << 6) | uint256(uint8(data[offset + 3]) & 0x3F),
                offset + 4
            );
        }
        revert InvalidUtf8Label(string(data));
    }

    function _isEmojiCodepoint(uint256 codepoint) private pure returns (bool) {
        return (codepoint >= 0x1F000 && codepoint <= 0x1FAFF) || (codepoint >= 0x2600 && codepoint <= 0x27BF);
    }

    function _isEmojiModifier(uint256 codepoint) private pure returns (bool) {
        return codepoint == 0xFE0F || codepoint == 0x200D || (codepoint >= 0x1F3FB && codepoint <= 0x1F3FF);
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

    function _rateAt(address ratesPointer, uint256 index) private view returns (uint128 rate) {
        uint256 offset = 1 + index * 16;
        assembly ("memory-safe") {
            extcodecopy(ratesPointer, 0x00, offset, 0x10)
            rate := shr(128, mload(0x00))
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
