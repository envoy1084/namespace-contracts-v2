// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title LabelLengthPolicy
/// @notice Enforces activation-scoped byte-length bounds for labels.
/// @dev This policy intentionally uses byte length. Unicode normalization and grapheme-aware
///      length checks should be implemented as separate specialized policies.
contract LabelLengthPolicy is NamespaceModule, IPolicyModule {
    /// @notice Length bounds for one activation.
    /// @param minLength Minimum byte length. Use 0 for no lower bound.
    /// @param maxLength Maximum byte length. Use 0 for no upper bound.
    struct Params {
        uint16 minLength;
        uint16 maxLength;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidLengthBounds(uint16 minLength, uint16 maxLength);
    error LabelTooShort(bytes32 activationId, string label, uint256 length, uint16 minLength);
    error LabelTooLong(bytes32 activationId, string label, uint256 length, uint16 maxLength);

    /// @notice Store label length bounds for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.maxLength != 0 && decoded.minLength > decoded.maxLength) {
            revert InvalidLengthBounds(decoded.minLength, decoded.maxLength);
        }
        params[activationId] = decoded;
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata) external view {
        _checkLength(ctx.activationId, ctx.label);
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata) external view {
        _checkLength(ctx.activationId, ctx.label);
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
