// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title LabelClassRule
/// @notice Checks label character classes and can apply class-specific pricing.
contract LabelClassRule is NamespaceRule {
    enum LabelClass {
        EMOJI,
        NUMBER,
        LETTER
    }

    /// @notice Label class parameters for one activation.
    /// @param token Payment token used by the price effect.
    /// @param labelClass Class that the label is matched against.
    /// @param requireMatch Whether non-matching labels should be blocked.
    /// @param mintAmount Mint amount applied when the label matches.
    /// @param renewAmount Renewal amount applied when the label matches.
    /// @param priceOp Price operation. Use NONE for class gating only.
    struct Params {
        address token;
        LabelClass labelClass;
        bool requireMatch;
        uint128 mintAmount;
        uint128 renewAmount;
        NamespaceTypes.PriceOp priceOp;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidUtf8Label(string label);
    error LabelClassMismatch(bytes32 activationId, string label, LabelClass expected);
    error InvalidLabelClassPriceOp(NamespaceTypes.PriceOp priceOp);

    /// @notice Store label class parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        _checkPriceOp(decoded.priceOp);
        params[activationId] = decoded;
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Params memory stored = params[ctx.activationId];
        output = _evaluate(ctx.activationId, ctx.label, stored, true);
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        Params memory stored = params[ctx.activationId];
        output = _evaluate(ctx.activationId, ctx.label, stored, false);
    }

    function _evaluate(bytes32 activationId, string calldata label, Params memory stored, bool mint)
        private
        pure
        returns (NamespaceTypes.RuleOutput memory output)
    {
        bool matches = _matches(label, stored.labelClass);
        if (!matches) {
            if (stored.requireMatch) {
                revert LabelClassMismatch(activationId, label, stored.labelClass);
            }
            output.decision = NamespaceTypes.Decision.PASS;
            return output;
        }

        output.decision = NamespaceTypes.Decision.PASS;
        NamespaceTypes.PriceOp priceOp = stored.priceOp;
        uint256 amount = mint ? stored.mintAmount : stored.renewAmount;
        if (priceOp == NamespaceTypes.PriceOp.NONE || amount == 0) {
            return output;
        }
        output.priceOp = priceOp;
        output.token = stored.token;
        output.amount = amount;
    }

    function _checkPriceOp(NamespaceTypes.PriceOp priceOp) private pure {
        if (
            priceOp != NamespaceTypes.PriceOp.NONE && priceOp != NamespaceTypes.PriceOp.SET_BASE
                && priceOp != NamespaceTypes.PriceOp.ADD && priceOp != NamespaceTypes.PriceOp.OVERRIDE
        ) {
            revert InvalidLabelClassPriceOp(priceOp);
        }
    }

    function _matches(string calldata label, LabelClass class) private pure returns (bool) {
        bytes calldata data = bytes(label);
        if (data.length == 0) {
            return false;
        }
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
            if (!((char >= 0x41 && char <= 0x5A) || (char >= 0x61 && char <= 0x7A))) {
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
            uint8 second = uint8(data[offset + 1]);
            if (!_isContinuation(second)) revert InvalidUtf8Label(string(data));
            return ((uint256(first & 0x1F) << 6) | uint256(second & 0x3F), offset + 2);
        }
        if (first >= 0xE0 && first <= 0xEF && offset + 2 < data.length) {
            uint8 second = uint8(data[offset + 1]);
            uint8 third = uint8(data[offset + 2]);
            if (
                !_isContinuation(second) || !_isContinuation(third) || (first == 0xE0 && second < 0xA0)
                    || (first == 0xED && second > 0x9F)
            ) {
                revert InvalidUtf8Label(string(data));
            }
            return ((uint256(first & 0x0F) << 12) | (uint256(second & 0x3F) << 6) | uint256(third & 0x3F), offset + 3);
        }
        if (first >= 0xF0 && first <= 0xF4 && offset + 3 < data.length) {
            uint8 second = uint8(data[offset + 1]);
            uint8 third = uint8(data[offset + 2]);
            uint8 fourth = uint8(data[offset + 3]);
            if (
                !_isContinuation(second) || !_isContinuation(third) || !_isContinuation(fourth)
                    || (first == 0xF0 && second < 0x90) || (first == 0xF4 && second > 0x8F)
            ) {
                revert InvalidUtf8Label(string(data));
            }
            return (
                (uint256(first & 0x07) << 18) | (uint256(second & 0x3F) << 12) | (uint256(third & 0x3F) << 6)
                    | uint256(fourth & 0x3F),
                offset + 4
            );
        }
        revert InvalidUtf8Label(string(data));
    }

    function _isContinuation(uint8 char) private pure returns (bool) {
        return char >= 0x80 && char <= 0xBF;
    }

    function _isEmojiCodepoint(uint256 codepoint) private pure returns (bool) {
        return (codepoint >= 0x1F000 && codepoint <= 0x1FAFF) || (codepoint >= 0x2600 && codepoint <= 0x27BF);
    }

    function _isEmojiModifier(uint256 codepoint) private pure returns (bool) {
        return codepoint == 0xFE0F || codepoint == 0x200D || (codepoint >= 0x1F3FB && codepoint <= 0x1F3FF);
    }
}
