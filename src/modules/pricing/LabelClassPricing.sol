// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPricingModule} from "src/interfaces/IPricingModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title LabelClassPricing
/// @notice Base pricing module for exact label character-class premiums.
abstract contract LabelClassPricing is NamespaceModule, IPricingModule {
    enum LabelClass {
        EMOJI,
        NUMBER,
        LETTER
    }

    /// @notice Character-class pricing params for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param mintAmount Amount added to mint price when the label matches.
    /// @param renewAmount Amount added to renewal price when the label matches.
    struct Params {
        address token;
        uint128 mintAmount;
        uint128 renewAmount;
    }

    mapping(bytes32 activationId => Params params) public params;

    error PaymentTokenMismatch(address expected, address actual);
    error InvalidUtf8Label(string label);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Store class pricing parameters for an activation.
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
        price = _add(currentPrice, stored.token, _matches(ctx.label) ? stored.mintAmount : 0);
    }

    /// @inheritdoc IPricingModule
    function quoteRenew(
        NamespaceTypes.RenewContext calldata ctx,
        NamespaceTypes.Price calldata currentPrice,
        bytes calldata
    ) external view returns (NamespaceTypes.Price memory price) {
        Params memory stored = params[ctx.activationId];
        price = _add(currentPrice, stored.token, _matches(ctx.label) ? stored.renewAmount : 0);
    }

    function labelClass() public pure virtual returns (LabelClass);

    function _matches(string calldata label) private pure returns (bool) {
        bytes calldata data = bytes(label);
        if (data.length == 0) {
            return false;
        }

        LabelClass class = labelClass();
        if (class == LabelClass.NUMBER) {
            return _isAsciiNumber(data);
        }
        if (class == LabelClass.LETTER) {
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
