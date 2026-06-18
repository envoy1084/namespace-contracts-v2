// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title LabelLengthRule
/// @notice Blocks labels outside configured byte-length bounds.
contract LabelLengthRule is NamespaceRule {
    /// @notice Label length parameters.
    /// @param minLength Minimum label byte length.
    /// @param maxLength Maximum label byte length. Use 0 for no maximum.
    struct Params {
        uint16 minLength;
        uint16 maxLength;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidLengthBounds(uint16 minLength, uint16 maxLength);
    error LabelTooShort(bytes32 activationId, string label, uint256 length, uint16 minLength);
    error LabelTooLong(bytes32 activationId, string label, uint256 length, uint16 maxLength);

    /// @notice Store label length parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.maxLength != 0 && decoded.minLength > decoded.maxLength) {
            revert InvalidLengthBounds(decoded.minLength, decoded.maxLength);
        }
        params[activationId] = decoded;
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        _checkLength(ctx.activationId, ctx.label);
        output = _pass();
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        _checkLength(ctx.activationId, ctx.label);
        output = _pass();
    }

    function _checkLength(bytes32 activationId, string calldata label) private view {
        Params memory stored = params[activationId];
        uint256 length = bytes(label).length;
        if (length < stored.minLength) {
            revert LabelTooShort(activationId, label, length, stored.minLength);
        }
        if (stored.maxLength != 0 && length > stored.maxLength) {
            revert LabelTooLong(activationId, label, length, stored.maxLength);
        }
    }
}
