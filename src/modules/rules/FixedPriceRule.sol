// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title FixedPriceRule
/// @notice Sets the base price with optional exact-length overrides.
contract FixedPriceRule is NamespaceRule {
    /// @notice Exact byte-length price override.
    /// @param length Label byte length matched by this price.
    /// @param mintAmount Mint amount used when length matches.
    /// @param renewAmount Renewal amount used when length matches.
    struct LengthPrice {
        uint16 length;
        uint128 mintAmount;
        uint128 renewAmount;
    }

    /// @notice Fixed price params for one activation.
    /// @param token Payment token. Use address(0) for native ETH.
    /// @param defaultMintAmount Mint amount used when no exact-length override matches.
    /// @param defaultRenewAmount Renewal amount used when no exact-length override matches.
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
            _checkDuplicateLength(activationId, decoded.lengthPrices, i, lengthPrice.length);
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

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output = _priceOutput(ctx.activationId, ctx.label, true);
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output = _priceOutput(ctx.activationId, ctx.label, false);
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

    function _priceOutput(bytes32 activationId, string calldata label, bool mint)
        private
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        StoredParams memory stored = _params[activationId];
        output.decision = NamespaceTypes.Decision.PASS;
        output.priceOp = NamespaceTypes.PriceOp.SET_BASE;
        output.token = stored.token;
        output.amount = _amountFor(stored, label, mint);
    }

    function _amountFor(StoredParams memory stored, string calldata label, bool mint)
        private
        view
        returns (uint256 amount)
    {
        uint256 labelLength = bytes(label).length;
        if (labelLength == 0) {
            revert EmptyLabel();
        }

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

    function _checkDuplicateLength(
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
}
