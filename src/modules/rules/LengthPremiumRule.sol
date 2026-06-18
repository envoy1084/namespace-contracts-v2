// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SSTORE2} from "solady/utils/SSTORE2.sol";

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title LengthPremiumRule
/// @notice Adds per-second price premiums selected by label byte length.
/// @dev Index `0` prices one-byte labels. Labels longer than the table use the final bucket.
contract LengthPremiumRule is NamespaceRule {
    /// @notice Length premium params for one activation.
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
    error PricingTableTooLong(bytes32 activationId, uint256 length);

    /// @notice Store length premium parameters for an activation.
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

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        StoredParams memory stored = _params[ctx.activationId];
        output = _premiumOutput(
            stored.token, _rateFor(stored.mintRatesPointer, stored.mintRateCount, ctx.label) * ctx.duration
        );
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        StoredParams memory stored = _params[ctx.activationId];
        output = _premiumOutput(
            stored.token, _rateFor(stored.renewRatesPointer, stored.renewRateCount, ctx.label) * ctx.duration
        );
    }

    function _premiumOutput(address token, uint256 amount)
        private
        pure
        returns (NamespaceTypes.RuleOutput memory output)
    {
        output.decision = NamespaceTypes.Decision.PASS;
        output.priceOp = NamespaceTypes.PriceOp.ADD;
        output.token = token;
        output.amount = amount;
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

    function _rateAt(address ratesPointer, uint256 index) private view returns (uint128 rate) {
        uint256 offset = 1 + index * 16;
        assembly ("memory-safe") {
            extcodecopy(ratesPointer, 0x00, offset, 0x10)
            rate := shr(128, mload(0x00))
        }
    }
}
