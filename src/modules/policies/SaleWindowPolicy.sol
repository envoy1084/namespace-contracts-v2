// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPolicyModule} from "src/interfaces/IPolicyModule.sol";
import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceModule} from "src/modules/NamespaceModule.sol";

/// @title SaleWindowPolicy
/// @notice Enforces activation-scoped mint and renewal time windows.
contract SaleWindowPolicy is NamespaceModule, IPolicyModule {
    /// @notice Sale window params for one activation.
    /// @param startTime Inclusive start timestamp. Use 0 for immediate start.
    /// @param endTime Inclusive end timestamp. Use 0 for no end.
    struct Params {
        uint64 startTime;
        uint64 endTime;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidSaleWindow(uint64 startTime, uint64 endTime);
    error SaleNotStarted(bytes32 activationId, uint64 startTime, uint256 currentTime);
    error SaleEnded(bytes32 activationId, uint64 endTime, uint256 currentTime);

    constructor(address controller_) NamespaceModule(controller_) {}

    /// @notice Store sale window parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.endTime != 0 && decoded.startTime > decoded.endTime) {
            revert InvalidSaleWindow(decoded.startTime, decoded.endTime);
        }
        params[activationId] = decoded;
    }

    /// @inheritdoc IPolicyModule
    function checkMint(NamespaceTypes.MintContext calldata ctx, bytes calldata) external view {
        _checkWindow(ctx.activationId);
    }

    /// @inheritdoc IPolicyModule
    function checkRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata) external view {
        _checkWindow(ctx.activationId);
    }

    function _checkWindow(bytes32 activationId) private view {
        Params memory stored = params[activationId];
        uint256 currentTime = block.timestamp;
        if (stored.startTime != 0 && currentTime < stored.startTime) {
            revert SaleNotStarted(activationId, stored.startTime, currentTime);
        }
        if (stored.endTime != 0 && currentTime > stored.endTime) {
            revert SaleEnded(activationId, stored.endTime, currentTime);
        }
    }
}
