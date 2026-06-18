// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {NamespaceTypes} from "src/libraries/NamespaceTypes.sol";
import {NamespaceRule} from "src/modules/rules/NamespaceRule.sol";

/// @title SaleWindowRule
/// @notice Blocks mints and renewals outside an activation-scoped time window.
contract SaleWindowRule is NamespaceRule {
    /// @notice Sale window parameters.
    /// @param startTime Earliest timestamp allowed. Use 0 to disable lower bound.
    /// @param endTime Latest timestamp allowed. Use 0 to disable upper bound.
    struct Params {
        uint64 startTime;
        uint64 endTime;
    }

    mapping(bytes32 activationId => Params params) public params;

    error InvalidSaleWindow(uint64 startTime, uint64 endTime);
    error SaleNotStarted(bytes32 activationId, uint64 startTime, uint256 currentTime);
    error SaleEnded(bytes32 activationId, uint64 endTime, uint256 currentTime);

    /// @notice Store sale window parameters for an activation.
    function configure(bytes32 activationId, bytes calldata configData) external onlyController {
        Params memory decoded = abi.decode(configData, (Params));
        if (decoded.endTime != 0 && decoded.startTime > decoded.endTime) {
            revert InvalidSaleWindow(decoded.startTime, decoded.endTime);
        }
        params[activationId] = decoded;
    }

    /// @notice Evaluate rule.
    function evaluateMint(NamespaceTypes.MintContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        _checkWindow(ctx.activationId);
        output = _pass();
    }

    /// @notice Evaluate rule.
    function evaluateRenew(NamespaceTypes.RenewContext calldata ctx, bytes calldata)
        external
        view
        returns (NamespaceTypes.RuleOutput memory output)
    {
        _checkWindow(ctx.activationId);
        output = _pass();
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
